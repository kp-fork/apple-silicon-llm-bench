import Foundation

public protocol BenchmarkTask: Sendable {
    /// Stable id used for filenames and the result table.
    var id: String { get }

    /// Human-friendly title shown in the UI.
    var title: String { get }

    /// One-sentence description of what this task measures.
    var summary: String { get }

    /// The prompt to feed into the runtime.
    var prompt: String { get }

    /// Generation parameters specific to this task.
    var parameters: GenerationParameters { get }
}

public enum BenchmarkTaskCatalog {
    public static let all: [any BenchmarkTask] = [
        ShortChatTask(),
        LongContextTask(),
        SustainedGenerationTask(),
        AppLifecycleTask(),
    ]

    public static func task(for id: String) -> (any BenchmarkTask)? {
        all.first(where: { $0.id == id })
    }
}
