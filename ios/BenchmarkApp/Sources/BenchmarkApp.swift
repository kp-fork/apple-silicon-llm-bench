import SwiftUI

@main
struct BenchmarkApp: App {
    @StateObject private var session = AppSession()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
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
