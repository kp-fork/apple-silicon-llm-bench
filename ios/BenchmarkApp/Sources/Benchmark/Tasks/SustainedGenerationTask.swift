import Foundation

public struct SustainedGenerationTask: BenchmarkTask {
    public let id = "sustained-generation"
    public let title = "Sustained generation"
    public let summary = "512-token output. Measures thermal stability and decode degradation."

    public let prompt = "Write a detailed explanation of how local LLM inference works on mobile devices."

    public let parameters = GenerationParameters(maxTokens: 512, temperature: 0.7, topP: 0.9)

    public init() {}
}
