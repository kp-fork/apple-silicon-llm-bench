#if canImport(MediaPipeTasksGenAI) && canImport(MediaPipeTasksGenAIC)
import Foundation
import MediaPipeTasksGenAI
import MediaPipeTasksGenAIC

/// MediaPipe LLM Inference (a.k.a. LiteRT-LM) adapter.
///
/// Wraps Google's `LlmInference.Session` + `generateResponseAsync()`.
/// Loads `.task` model bundles downloaded from `litert-community/*` on HF.
///
/// Note: The Google framework is distributed as a CocoaPod
/// (`MediaPipeTasksGenAI`) or via `paescebu/SwiftTasksGenAI` added through
/// the Xcode UI. This file is gated by `#if canImport(...)` so it builds
/// cleanly when neither is added; once added, it lights up.
public actor MediaPipeRuntime: LLMRuntime {
    public let kind: RuntimeKind = .mediaPipe
    public let isAvailable: Bool = true
    public nonisolated let supportedModels: [ModelInfo] = ModelCatalog.mediaPipe

    public private(set) var loadedModelId: String?

    private var inference: LlmInference?
    private var modelPath: String?

    public init() {}

    public func loadModel(
        _ model: ModelInfo,
        progress: @Sendable @escaping (Double) -> Void
    ) async throws {
        guard supportedModels.contains(where: { $0.id == model.id }) else {
            throw LLMRuntimeError.modelNotInCatalog(model.id)
        }

        let snapshot = try await HFDownloader.snapshot(for: model, runtime: kind, progress: progress)
        let taskFile = try locateTaskFile(in: snapshot, expected: model.primaryFile)

        let options = LlmInference.Options(modelPath: taskFile.path)
        options.maxTokens = 2048
        do {
            self.inference = try LlmInference(options: options)
            self.modelPath = taskFile.path
            self.loadedModelId = model.id
        } catch {
            throw LLMRuntimeError.loadFailed(error.localizedDescription)
        }
    }

    public func unloadModel() async {
        inference = nil
        modelPath = nil
        loadedModelId = nil
    }

    public nonisolated func generate(
        prompt: String,
        parameters: GenerationParameters
    ) -> AsyncThrowingStream<GenerationEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await self.runGenerate(prompt: prompt, parameters: parameters, continuation: continuation)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func runGenerate(
        prompt: String,
        parameters: GenerationParameters,
        continuation: AsyncThrowingStream<GenerationEvent, Error>.Continuation
    ) async throws {
        guard let inference else { throw LLMRuntimeError.modelNotLoaded }

        let sessionOptions = LlmInference.Session.Options()
        sessionOptions.topk = 40
        sessionOptions.topp = parameters.topP
        sessionOptions.temperature = parameters.temperature
        let session = try LlmInference.Session(llmInference: inference, options: sessionOptions)

        let promptTokenCount = (try? session.sizeInTokens(text: prompt)) ?? 0

        let prefillStart = CFAbsoluteTimeGetCurrent()
        try session.addQueryChunk(inputText: prompt)
        var firstTokenAt: CFAbsoluteTime?
        var tokenCount = 0

        let stream = session.generateResponseAsync()
        for try await partial in stream {
            try Task.checkCancellation()
            if firstTokenAt == nil { firstTokenAt = CFAbsoluteTimeGetCurrent() }
            if !partial.isEmpty {
                continuation.yield(.chunk(partial))
                tokenCount += 1
            }
            if tokenCount >= parameters.maxTokens { break }
        }
        let end = CFAbsoluteTimeGetCurrent()
        let prefillTime = (firstTokenAt ?? end) - prefillStart
        let generateTime = max(end - (firstTokenAt ?? prefillStart), 0.001)

        continuation.yield(.info(GenerationInfo(
            promptTokenCount: promptTokenCount,
            generationTokenCount: tokenCount,
            promptTime: prefillTime,
            generateTime: generateTime,
            stopReason: tokenCount >= parameters.maxTokens ? .length : .stop
        )))
        continuation.finish()
    }

    private func locateTaskFile(in dir: URL, expected: String) throws -> URL {
        let direct = dir.appendingPathComponent(expected)
        if FileManager.default.fileExists(atPath: direct.path) { return direct }
        let contents = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        if let task = contents.first(where: { $0.pathExtension == "task" }) {
            return task
        }
        throw LLMRuntimeError.loadFailed("No .task file found in \(dir.path)")
    }
}
#else
import Foundation

/// Compile-time-disabled MediaPipe runtime. Add `MediaPipeTasksGenAI` via
/// CocoaPods or `paescebu/SwiftTasksGenAI` (Xcode → Add Package Dependency)
/// to enable. See `runtimes/litert-lm.md` for the integration steps.
public final class MediaPipeRuntime: LLMRuntime, @unchecked Sendable {
    public let kind: RuntimeKind = .mediaPipe
    public let isAvailable: Bool = false
    public nonisolated let supportedModels: [ModelInfo] = ModelCatalog.mediaPipe
    public var loadedModelId: String? { nil }

    public init() {}

    public func loadModel(_ model: ModelInfo, progress: @Sendable @escaping (Double) -> Void) async throws {
        throw LLMRuntimeError.unsupported("MediaPipeTasksGenAI not added to the project. See runtimes/litert-lm.md.")
    }

    public func unloadModel() async {}

    public func generate(prompt: String, parameters: GenerationParameters) -> AsyncThrowingStream<GenerationEvent, Error> {
        AsyncThrowingStream { c in
            c.finish(throwing: LLMRuntimeError.unsupported("MediaPipeTasksGenAI not added — see runtimes/litert-lm.md."))
        }
    }
}
#endif
