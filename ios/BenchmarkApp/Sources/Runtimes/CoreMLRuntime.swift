import Foundation
import CoreML
#if canImport(CoreMLLLM)
import CoreMLLLM
#endif

/// CoreML LLM adapter using `john-rocky/CoreML-LLM` (`CoreMLLLM` Swift
/// package). This is the loader the `mlboydaisuke/gemma-4-E2B-coreml`
/// chunked bundle is published for, and it is the only Swift path today
/// that runs Gemma 4 on iPhone via CoreML (swift-transformers'
/// `LanguageModel.loadCompiled` requires a single stateful `.mlpackage`
/// which Gemma 4 does not ship as).
///
/// Auto-downloads the chunked bundle into `Documents/Models/<folderName>/`
/// on first use, then ANE-compiles the chunks (slow on first run, ~1–2 min
/// per the upstream README).
///
/// Requires iOS 18+ / Swift 6.
@available(iOS 18.0, macOS 15.0, *)
public final class CoreMLRuntime: LLMRuntime, @unchecked Sendable {
    public let kind: RuntimeKind = .coreMLLLM
    #if canImport(CoreMLLLM)
    public let isAvailable: Bool = true
    #else
    public let isAvailable: Bool = false
    #endif
    public let supportedModels: [ModelInfo] = ModelCatalog.coreML

    nonisolated(unsafe) private var _loadedModelId: String?
    public var loadedModelId: String? { _loadedModelId }

    #if canImport(CoreMLLLM)
    nonisolated(unsafe) private var llm: CoreMLLLM?
    #endif

    public init() {}

    public func loadModel(
        _ model: ModelInfo,
        progress: @Sendable @escaping (Double) -> Void
    ) async throws {
        guard supportedModels.contains(where: { $0.id == model.id }) else {
            throw LLMRuntimeError.modelNotInCatalog(model.id)
        }

        #if canImport(CoreMLLLM)
        guard let info = Self.downloaderInfo(for: model.id) else {
            throw LLMRuntimeError.loadFailed(
                "Model id \(model.id) is not registered in CoreMLLLM.ModelDownloader.ModelInfo.defaults."
            )
        }

        do {
            let loaded = try await CoreMLLLM.load(model: info, computeUnits: .cpuAndNeuralEngine) { status in
                // CoreMLLLM emits status strings, not a numeric fraction.
                // Surface 0.5 as a coarse "in progress" signal so the UI
                // shows movement; flips to 1.0 once load returns.
                progress(0.5)
                _ = status
            }
            self.llm = loaded
            self._loadedModelId = model.id
            progress(1)
        } catch {
            throw LLMRuntimeError.loadFailed(error.localizedDescription)
        }
        #else
        throw LLMRuntimeError.unsupported("CoreMLLLM SPM product not present.")
        #endif
    }

    public func unloadModel() async {
        #if canImport(CoreMLLLM)
        llm = nil
        #endif
        _loadedModelId = nil
    }

    public func generate(
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
        #if canImport(CoreMLLLM)
        guard let llm else { throw LLMRuntimeError.modelNotLoaded }

        let prefillStart = CFAbsoluteTimeGetCurrent()
        var firstTokenAt: CFAbsoluteTime?
        var tokenCount = 0

        let stream = try await llm.stream(prompt, maxTokens: parameters.maxTokens)
        for await piece in stream {
            try Task.checkCancellation()
            if firstTokenAt == nil { firstTokenAt = CFAbsoluteTimeGetCurrent() }
            if !piece.isEmpty {
                continuation.yield(.chunk(piece))
                tokenCount += 1
            }
        }

        let end = CFAbsoluteTimeGetCurrent()
        let prefillTime = (firstTokenAt ?? end) - prefillStart
        let generateTime = max(end - (firstTokenAt ?? prefillStart), 0.001)

        continuation.yield(.info(GenerationInfo(
            promptTokenCount: 0,
            generationTokenCount: tokenCount,
            promptTime: prefillTime,
            generateTime: generateTime,
            stopReason: tokenCount >= parameters.maxTokens ? .length : .stop
        )))
        continuation.finish()
        #else
        throw LLMRuntimeError.unsupported("CoreMLLLM SPM product not present.")
        #endif
    }

    #if canImport(CoreMLLLM)
    /// Map our `ModelInfo.id` strings to the `CoreMLLLM.ModelDownloader.ModelInfo`
    /// registered defaults.
    private static func downloaderInfo(for id: String) -> ModelDownloader.ModelInfo? {
        switch id {
        case "coreml-llm/gemma4-e2b":         return .gemma4e2b
        case "coreml-llm/gemma4-e4b":         return .gemma4e4b
        case "coreml-llm/qwen3.5-0.8b":       return .qwen35_08b
        case "coreml-llm/qwen3.5-2b":         return .qwen35_2b
        case "coreml-llm/lfm2.5-350m":        return .lfm2_5_350m
        case "coreml-llm/qwen2.5-0.5b":       return .qwen25_05b
        default:                              return nil
        }
    }
    #endif
}
