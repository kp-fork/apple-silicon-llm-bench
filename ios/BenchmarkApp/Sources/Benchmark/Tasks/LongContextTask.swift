import Foundation

public struct LongContextTask: BenchmarkTask {
    public let id = "long-context"
    public let title = "Long-context prefill"
    public let summary = "~2K-token prompt, 64-token output. Measures prefill throughput."

    public let parameters = GenerationParameters(maxTokens: 64, temperature: 0.0, topP: 1.0)

    public init() {}

    public var prompt: String {
        Self.cachedPrompt
    }

    private static let cachedPrompt: String = {
        var pieces: [String] = []
        pieces.reserveCapacity(220)
        let lorem = """
        Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus bibendum velit non augue \
        ultricies, a vestibulum ipsum porttitor. Sed at nulla a justo viverra dictum. Vivamus blandit \
        velit at lectus pulvinar pellentesque. Mauris dictum massa ut nisi tristique consequat.
        """
        for index in 0 ..< 220 {
            pieces.append("[\(index)] \(lorem)")
        }
        pieces.append("\n\nFinish with one sentence: what on-device AI lets a phone do that a cloud model cannot.")
        return pieces.joined(separator: "\n")
    }()
}
