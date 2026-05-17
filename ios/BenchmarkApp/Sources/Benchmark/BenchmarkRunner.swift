import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Holds the iOS background-task assertion + idle-timer override that we
/// need while a (potentially multi-GB) model is being downloaded. iOS will
/// suspend a foreground URLSession the moment the screen locks or the app
/// backgrounds, which silently freezes HF downloads at whatever byte count
/// they happened to reach. We hold both for the duration of `loadModel`.
@MainActor
final class DownloadActivityScope {
    #if canImport(UIKit)
    private var bgTask: UIBackgroundTaskIdentifier = .invalid
    #endif

    init() {
        #if canImport(UIKit)
        UIApplication.shared.isIdleTimerDisabled = true
        bgTask = UIApplication.shared.beginBackgroundTask(withName: "ModelDownload") {
            // Expiration handler — iOS gave up. Best-effort end.
            UIApplication.shared.endBackgroundTask(self.bgTask)
            self.bgTask = .invalid
        }
        #endif
    }

    func end() {
        #if canImport(UIKit)
        UIApplication.shared.isIdleTimerDisabled = false
        if bgTask != .invalid {
            UIApplication.shared.endBackgroundTask(bgTask)
            bgTask = .invalid
        }
        #endif
    }

    deinit {
        #if canImport(UIKit)
        // Best-effort cleanup if end() wasn't called.
        Task { @MainActor [bgTask] in
            UIApplication.shared.isIdleTimerDisabled = false
            if bgTask != .invalid {
                UIApplication.shared.endBackgroundTask(bgTask)
            }
        }
        #endif
    }
}

/// Orchestrates one benchmark run: load model (if needed), drive a task to completion,
/// gather memory/thermal samples, and produce a `BenchmarkResult`.
public actor BenchmarkRunner {
    public enum Phase: Sendable {
        case idle
        case loadingModel(progress: Double)
        case generating(tokens: Int, partialOutput: String)
        case finalizing
        case done
        case failed(String)
    }

    public struct Snapshot: Sendable {
        public let phase: Phase
        public let elapsed: TimeInterval
    }

    public struct Configuration: Sendable {
        public var runtime: any LLMRuntime
        public var model: ModelInfo
        public var task: any BenchmarkTask
        public var coldRun: Bool

        public init(runtime: any LLMRuntime, model: ModelInfo, task: any BenchmarkTask, coldRun: Bool) {
            self.runtime = runtime
            self.model = model
            self.task = task
            self.coldRun = coldRun
        }
    }

    private var snapshotContinuation: AsyncStream<Snapshot>.Continuation?
    private var generationTask: Task<Void, Never>?

    public init() {}

    /// Subscribe to phase changes for UI updates.
    public func snapshots() -> AsyncStream<Snapshot> {
        AsyncStream { continuation in
            self.snapshotContinuation = continuation
        }
    }

    /// Cancel the in-flight run, if any.
    public func cancel() {
        generationTask?.cancel()
    }

    public func run(_ configuration: Configuration) async throws -> BenchmarkResult {
        let device = DeviceSnapshot.capture()
        let memorySampler = MemorySampler()
        let thermalSampler = ThermalSampler()
        let energyMonitor = EnergyMonitor()

        let baselineMB = MemoryMonitor.residentMB()
        await thermalSampler.start()

        // 1. Load model (if not already loaded).
        var loadTime: Double?
        let currentLoaded = await configuration.runtime.loadedModelId
        if currentLoaded != configuration.model.id {
            emit(.loadingModel(progress: 0))
            let loadStart = CFAbsoluteTimeGetCurrent()
            // Keep iOS from auto-locking + suspending the URLSession mid-download.
            let scope = await MainActor.run { DownloadActivityScope() }
            defer { Task { @MainActor in scope.end() } }
            try await configuration.runtime.loadModel(configuration.model) { fraction in
                Task { await self.emit(.loadingModel(progress: fraction)) }
            }
            loadTime = CFAbsoluteTimeGetCurrent() - loadStart
        }

        let memoryAfterLoad = MemoryMonitor.residentMB()
        await memorySampler.start()
        await energyMonitor.start()

        // 2. Run generation, accumulating chunks and timing.
        let generationStart = CFAbsoluteTimeGetCurrent()
        var firstTokenAt: CFAbsoluteTime?
        var tokenWindow: [(t: CFAbsoluteTime, n: Int)] = []
        var collectedOutput = ""
        var tokenCount = 0
        var info: GenerationInfo?
        var capturedError: Error?

        let stream = configuration.runtime.generate(
            prompt: configuration.task.prompt,
            parameters: configuration.task.parameters
        )

        do {
            for try await event in stream {
                switch event {
                case .chunk(let text):
                    if firstTokenAt == nil {
                        firstTokenAt = CFAbsoluteTimeGetCurrent()
                    }
                    tokenCount += 1
                    collectedOutput.append(text)
                    let now = CFAbsoluteTimeGetCurrent()
                    tokenWindow.append((t: now, n: tokenCount))
                    let preview = String(collectedOutput.prefix(80))
                    emit(.generating(tokens: tokenCount, partialOutput: preview))
                case .info(let i):
                    info = i
                }
            }
        } catch {
            capturedError = error
        }

        emit(.finalizing)
        await memorySampler.stop()
        await thermalSampler.stop()
        let memoryPeakMB = await memorySampler.peakMB
        let energy = await energyMonitor.snapshot()

        // Wait briefly for transient buffers to drop.
        try? await Task.sleep(nanoseconds: 200_000_000)
        let memoryAfterMB = MemoryMonitor.residentMB()

        if let error = capturedError {
            emit(.failed(error.localizedDescription))
            throw error
        }

        let finalInfo = info ?? GenerationInfo(
            promptTokenCount: 0,
            generationTokenCount: tokenCount,
            promptTime: 0,
            generateTime: max(CFAbsoluteTimeGetCurrent() - generationStart, 0.001),
            stopReason: .stop
        )

        let firstTokenLatency = firstTokenAt.map { ($0 - generationStart) * 1000 } ?? 0
        let totalTime = CFAbsoluteTimeGetCurrent() - generationStart

        let metrics = Metrics(
            coldRun: configuration.coldRun,
            loadTimeSeconds: loadTime,
            downloadTimeSeconds: nil,
            firstTokenLatencyMS: Int(firstTokenLatency.rounded()),
            promptTokensPerSecond: finalInfo.promptTokensPerSecond,
            decodeTokensPerSecond: finalInfo.tokensPerSecond,
            promptTokenCount: finalInfo.promptTokenCount,
            generatedTokenCount: finalInfo.generationTokenCount,
            totalGenerationTimeSeconds: totalTime,
            cancellationLatencyMS: nil,
            stopReason: finalInfo.stopReason.rawValue,
            memoryBaselineMB: baselineMB,
            memoryAfterLoadMB: memoryAfterLoad,
            memoryPeakDuringDecodeMB: memoryPeakMB,
            memoryAfterGenerationMB: memoryAfterMB,
            initialThermalState: ThermalMonitor.describe(await thermalSampler.initialState),
            peakThermalState: ThermalMonitor.describe(await thermalSampler.peakState),
            finalThermalState: ThermalMonitor.describe(await thermalSampler.finalState),
            decodeRateRollingWindow: rollingDecodeRate(window: tokenWindow, windowSeconds: 5),
            interTokenLatencyP50MS: Self.percentileMS(tokenWindow: tokenWindow, percentile: 0.50),
            interTokenLatencyP95MS: Self.percentileMS(tokenWindow: tokenWindow, percentile: 0.95),
            interTokenLatencyP99MS: Self.percentileMS(tokenWindow: tokenWindow, percentile: 0.99),
            energyJoules: energy.joules,
            batteryDeltaPercent: energy.batteryDeltaPercent,
            energyJoulesPerToken: {
                guard let j = energy.joules,
                      finalInfo.generationTokenCount > 0 else { return nil }
                return j / Double(finalInfo.generationTokenCount)
            }()
        )

        emit(.done)

        return BenchmarkResult(
            device: device,
            runtime: configuration.runtime.kind.rawValue,
            model: configuration.model,
            task: configuration.task.id,
            parameters: configuration.task.parameters,
            metrics: metrics,
            outputSample: String(collectedOutput.prefix(200))
        )
    }

    private func emit(_ phase: Phase) {
        snapshotContinuation?.yield(Snapshot(phase: phase, elapsed: 0))
    }

    /// Compute a percentile of the inter-token latency distribution (ms).
    /// `tokenWindow` holds one entry per emitted `.chunk` event; the gap
    /// between consecutive entries is the inter-token latency that a chat
    /// UI sees. Returns `nil` when fewer than two tokens were captured —
    /// percentiles of a one-element sample are meaningless.
    static func percentileMS(
        tokenWindow: [(t: CFAbsoluteTime, n: Int)],
        percentile: Double
    ) -> Double? {
        guard tokenWindow.count >= 2 else { return nil }
        var gaps: [Double] = []
        gaps.reserveCapacity(tokenWindow.count - 1)
        for i in 1..<tokenWindow.count {
            let dt = tokenWindow[i].t - tokenWindow[i - 1].t
            gaps.append(dt * 1000.0)
        }
        gaps.sort()
        // Nearest-rank percentile — matches what most engineers eyeball,
        // doesn't depend on a numpy-style interpolation choice.
        let rank = max(1, Int((percentile * Double(gaps.count)).rounded(.up)))
        return gaps[min(rank - 1, gaps.count - 1)]
    }

    private func rollingDecodeRate(
        window: [(t: CFAbsoluteTime, n: Int)],
        windowSeconds: Double
    ) -> [Double] {
        guard window.count >= 2 else { return [] }
        let start = window.first!.t
        let end = window.last!.t
        let stepSeconds = 1.0
        var samples: [Double] = []
        var cursor = start + windowSeconds
        while cursor <= end + 0.01 {
            let lower = cursor - windowSeconds
            let inWindow = window.filter { $0.t >= lower && $0.t <= cursor }
            if let first = inWindow.first, let last = inWindow.last, last.t > first.t {
                let dn = Double(last.n - first.n)
                let dt = last.t - first.t
                samples.append(dt > 0 ? dn / dt : 0)
            } else {
                samples.append(0)
            }
            cursor += stepSeconds
        }
        return samples
    }
}
