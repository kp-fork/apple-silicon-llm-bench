import Foundation

/// Long-context prefill + decode-at-depth. Parameterised by an approximate prompt
/// length so a sweep (2K → 8K → 32K) can show how prefill throughput and decode
/// rate hold up as the KV cache grows — the "does decode stay flat under long
/// context" question. The nominal length is approximate; the *actual* prompt token
/// count is recorded as `promptTokenCount` in the JSONL, and the report plots the
/// real count, so the `-8k` / `-32k` ids are just labels.
public struct LongContextTask: BenchmarkTask {
    public let id: String
    public let title: String
    public let summary: String
    public let parameters: GenerationParameters
    private let blocks: Int

    /// One filler block ≈ this many tokens (a ~40-word lorem paragraph + an index
    /// tag). Used only to turn a nominal target into a block count; ground truth is
    /// the runtime-recorded `promptTokenCount`.
    private static let tokensPerBlock = 55

    /// - Parameters:
    ///   - id: stable task id (e.g. `long-context`, `long-context-8k`).
    ///   - targetTokens: approximate prompt length to build toward.
    ///   - maxTokens: decode budget after prefill (held equal across the sweep so
    ///     decode-rate-at-depth is comparable).
    public init(id: String = "long-context", targetTokens: Int = 2048, maxTokens: Int = 128) {
        self.id = id
        self.blocks = max(1, targetTokens / Self.tokensPerBlock)
        let approx = targetTokens >= 1000 ? "~\(targetTokens / 1000)K" : "~\(targetTokens)"
        self.title = "Long-context prefill (\(approx) tok)"
        self.summary = "\(approx)-token prompt, \(maxTokens)-token output. "
            + "Prefill throughput (TTFT, prefill tok/s) and decode rate at depth."
        self.parameters = GenerationParameters(maxTokens: maxTokens, temperature: 0.0, topP: 1.0)
    }

    public var prompt: String {
        let lorem = """
        Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus bibendum velit non augue \
        ultricies, a vestibulum ipsum porttitor. Sed at nulla a justo viverra dictum. Vivamus blandit \
        velit at lectus pulvinar pellentesque. Mauris dictum massa ut nisi tristique consequat.
        """
        var pieces: [String] = []
        pieces.reserveCapacity(blocks + 1)
        for index in 0 ..< blocks {
            pieces.append("[\(index)] \(lorem)")
        }
        pieces.append("\n\nFinish with one sentence: what on-device AI lets a phone do that a cloud model cannot.")
        return pieces.joined(separator: "\n")
    }
}
