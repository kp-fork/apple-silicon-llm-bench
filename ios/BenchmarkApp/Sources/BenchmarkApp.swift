import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(Darwin)
import Darwin   // exit(), fflush(), stdout
#endif

@main
struct BenchmarkApp: App {
    @StateObject private var session = AppSession()
    private let autoRun = HeadlessAutoRun.specFromLaunchArgs()

    var body: some Scene {
        WindowGroup {
            if let autoRun {
                HeadlessRunnerView(spec: autoRun)
                    .environmentObject(session)
            } else {
                RootView()
                    .environmentObject(session)
            }
        }
    }
}

@MainActor
final class AppSession: ObservableObject {
    @Published var selectedRuntime: RuntimeKind = .mlxSwift
    @Published var selectedModel: ModelInfo = ModelCatalog.defaultModel
    @Published var history: [BenchmarkResult] = []

    private(set) var runtimes: [RuntimeKind: any LLMRuntime] = [:]

    init() {
        for kind in RuntimeKind.allCases {
            runtimes[kind] = makeRuntime(for: kind)
        }
        Task { await reloadHistory() }
    }

    func runtime(for kind: RuntimeKind) -> any LLMRuntime {
        runtimes[kind]!
    }

    /// Models the currently-selected runtime can load.
    func availableModels() -> [ModelInfo] {
        runtime(for: selectedRuntime).supportedModels
    }

    /// Ensure the selected model is one the current runtime supports;
    /// if not, fall back to the runtime's first model.
    func reconcileSelectedModel() {
        let supported = availableModels()
        if !supported.contains(where: { $0.id == selectedModel.id }), let first = supported.first {
            selectedModel = first
        }
    }

    func reloadHistory() async {
        if let loaded = try? await ResultStore.shared.load() {
            await MainActor.run { self.history = loaded }
        }
    }

    func record(_ result: BenchmarkResult) async {
        _ = try? await ResultStore.shared.save(result)
        await reloadHistory()
    }

    private func makeRuntime(for kind: RuntimeKind) -> any LLMRuntime {
        switch kind {
        case .mlxSwift:
            return MLXRuntime()
        case .llamaCpp:
            return LlamaCppRuntime()
        case .mediaPipe:
            return MediaPipeRuntime()
        case .executorch:
            return ExecuTorchRuntime()
        case .coreMLLLM:
            if #available(iOS 18, *) {
                return CoreMLRuntime()
            } else {
                return UnavailableRuntime(kind: kind, reason: "Requires iOS 18.")
            }
        case .anemll:
            if #available(iOS 18, *) {
                return AnemllRuntime()
            } else {
                return UnavailableRuntime(kind: kind, reason: "Requires iOS 18.")
            }
        case .appleFM:
            if #available(iOS 26, *) {
                return AppleFMRuntime()
            } else {
                return UnavailableRuntime(
                    kind: kind,
                    reason: "Apple Foundation Models requires iOS 26 + an Apple-Intelligence-eligible device."
                )
            }
        }
    }
}

/// Used when a runtime can never become available at this iOS version.
public final class UnavailableRuntime: LLMRuntime, @unchecked Sendable {
    public let kind: RuntimeKind
    public let isAvailable: Bool = false
    public let supportedModels: [ModelInfo] = []
    private let reason: String
    public var loadedModelId: String? { nil }

    public init(kind: RuntimeKind, reason: String) {
        self.kind = kind
        self.reason = reason
    }

    public func loadModel(_ model: ModelInfo, progress: @Sendable @escaping (Double) -> Void) async throws {
        throw LLMRuntimeError.unsupported(reason)
    }

    public func unloadModel() async {}

    public func generate(prompt: String, parameters: GenerationParameters) -> AsyncThrowingStream<GenerationEvent, Error> {
        AsyncThrowingStream { c in c.finish(throwing: LLMRuntimeError.unsupported(reason)) }
    }
}

// MARK: - Headless auto-run (CLI-drivable benchmark, no UI taps)

/// Parses the launch arguments that put the app into automated benchmark mode.
///
/// An external driver launches the app with, e.g.:
///
///     xcrun devicectl device process launch --terminate-existing \
///         --device <udid> com.iosllmbenchmark.benchmarkapp -- \
///         --yardstick-autorun --runtime llama.cpp \
///         --model-id "unsloth/Qwen3.5-2B-GGUF/Q4_K_M" \
///         --task short-chat --runs 1
///
/// Each completed run is saved to `Documents/results/` via the same
/// `ResultStore` the interactive path uses, so the export / import pipeline
/// picks it up unchanged. The process prints `YARDSTICK_*` sentinel lines and
/// `exit(0)`s when finished, so the driver can detect completion.
enum HeadlessAutoRun {
    struct Spec {
        var runtime: RuntimeKind
        var modelId: String
        var taskId: String
        var runs: Int
    }

    static func specFromLaunchArgs(_ args: [String] = CommandLine.arguments) -> Spec? {
        guard args.contains("--yardstick-autorun") else { return nil }
        func value(_ flag: String) -> String? {
            guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
            return args[i + 1]
        }
        guard let runtimeRaw = value("--runtime"),
              let runtime = RuntimeKind(rawValue: runtimeRaw),
              let modelId = value("--model-id") else { return nil }
        let taskId = value("--task") ?? "short-chat"
        let runs = max(1, Int(value("--runs") ?? "1") ?? 1)
        return Spec(runtime: runtime, modelId: modelId, taskId: taskId, runs: runs)
    }
}

/// UI-less driver view. Shows a scrolling log on-device (handy when watching
/// the phone) while running the benchmark and emitting machine-readable
/// sentinel lines to stdout for the external driver.
struct HeadlessRunnerView: View {
    let spec: HeadlessAutoRun.Spec
    @EnvironmentObject private var session: AppSession
    @State private var lines: [String] = ["yardstick headless: starting…"]
    @State private var started = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text(line).font(.system(.footnote, design: .monospaced))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .task {
            guard !started else { return }
            started = true
            #if canImport(UIKit)
            UIApplication.shared.isIdleTimerDisabled = true   // don't let the screen lock mid-run
            #endif
            await runAll()
        }
    }

    @MainActor
    private func log(_ line: String) {
        print(line)
        fflush(stdout)
        lines.append(line)
    }

    private func finish(_ code: Int32) async {
        // Give stdout + the on-disk JSON write a moment to flush before tearing down.
        try? await Task.sleep(nanoseconds: 600_000_000)
        exit(code)
    }

    private func runAll() async {
        let runtime = session.runtime(for: spec.runtime)
        guard runtime.isAvailable else {
            await log("YARDSTICK_FATAL runtime=\(spec.runtime.rawValue) not_available")
            await finish(2)
            return
        }
        guard let model = runtime.supportedModels.first(where: { $0.id == spec.modelId }) else {
            await log("YARDSTICK_FATAL model=\(spec.modelId) not_in_catalog runtime=\(spec.runtime.rawValue)")
            await finish(3)
            return
        }
        guard let task = BenchmarkTaskCatalog.task(for: spec.taskId) else {
            await log("YARDSTICK_FATAL task=\(spec.taskId) unknown")
            await finish(4)
            return
        }

        await log("YARDSTICK_BEGIN runtime=\(spec.runtime.rawValue) model=\(model.id) task=\(task.id) runs=\(spec.runs)")
        for i in 1...spec.runs {
            let runner = BenchmarkRunner()
            let cold = (await runtime.loadedModelId) != model.id
            do {
                let result = try await runner.run(
                    .init(runtime: runtime, model: model, task: task, coldRun: cold)
                )
                _ = try? await ResultStore.shared.save(result)
                await log(String(
                    format: "YARDSTICK_RUN_OK run=%d cold=%d decode_tok_s=%.2f ttft_ms=%d peak_mb=%.0f tokens=%d",
                    i, cold ? 1 : 0,
                    result.metrics.decodeTokensPerSecond,
                    result.metrics.firstTokenLatencyMS,
                    result.metrics.memoryPeakDuringDecodeMB,
                    result.metrics.generatedTokenCount
                ))
            } catch {
                await log("YARDSTICK_RUN_FAIL run=\(i) error=\(error.localizedDescription)")
            }
        }
        await log("YARDSTICK_ALL_DONE")
        await finish(0)
    }
}
