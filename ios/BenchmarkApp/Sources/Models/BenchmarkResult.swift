import Foundation

public struct BenchmarkResult: Codable, Sendable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let device: DeviceSnapshot
    public let runtime: String
    public let model: ModelInfo
    public let task: String
    public let parameters: GenerationParameters
    public let metrics: Metrics
    public let outputSample: String

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        device: DeviceSnapshot,
        runtime: String,
        model: ModelInfo,
        task: String,
        parameters: GenerationParameters,
        metrics: Metrics,
        outputSample: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.device = device
        self.runtime = runtime
        self.model = model
        self.task = task
        self.parameters = parameters
        self.metrics = metrics
        self.outputSample = outputSample
    }
}

public struct GenerationParameters: Codable, Sendable, Hashable {
    public var maxTokens: Int
    public var temperature: Float
    public var topP: Float
    public var seed: UInt64?

    public init(maxTokens: Int, temperature: Float = 0.7, topP: Float = 0.9, seed: UInt64? = nil) {
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.topP = topP
        self.seed = seed
    }

    public static let greedy = GenerationParameters(maxTokens: 128, temperature: 0.0, topP: 1.0)
    public static let chat = GenerationParameters(maxTokens: 512, temperature: 0.7, topP: 0.9)
}

public struct Metrics: Codable, Sendable {
    public let coldRun: Bool
    public let loadTimeSeconds: Double?
    public let downloadTimeSeconds: Double?

    public let firstTokenLatencyMS: Int
    public let promptTokensPerSecond: Double
    public let decodeTokensPerSecond: Double
    public let promptTokenCount: Int
    public let generatedTokenCount: Int
    public let totalGenerationTimeSeconds: Double
    public let cancellationLatencyMS: Int?
    public let stopReason: String

    public let memoryBaselineMB: Double
    public let memoryAfterLoadMB: Double?
    public let memoryPeakDuringDecodeMB: Double
    public let memoryAfterGenerationMB: Double

    public let initialThermalState: String
    public let peakThermalState: String
    public let finalThermalState: String

    public let decodeRateRollingWindow: [Double]

    /// Estimated joules used during the run, derived from battery-level delta.
    /// `nil` when the run was too short for a 1% battery step to register.
    public let energyJoules: Double?
    /// Battery percentage drop observed during the run (e.g. 1.5 means -1.5%).
    public let batteryDeltaPercent: Float
    /// Joules per generated token, when both `energyJoules` and a token
    /// count are available.
    public let energyJoulesPerToken: Double?

    public init(
        coldRun: Bool,
        loadTimeSeconds: Double?,
        downloadTimeSeconds: Double?,
        firstTokenLatencyMS: Int,
        promptTokensPerSecond: Double,
        decodeTokensPerSecond: Double,
        promptTokenCount: Int,
        generatedTokenCount: Int,
        totalGenerationTimeSeconds: Double,
        cancellationLatencyMS: Int?,
        stopReason: String,
        memoryBaselineMB: Double,
        memoryAfterLoadMB: Double?,
        memoryPeakDuringDecodeMB: Double,
        memoryAfterGenerationMB: Double,
        initialThermalState: String,
        peakThermalState: String,
        finalThermalState: String,
        decodeRateRollingWindow: [Double],
        energyJoules: Double?,
        batteryDeltaPercent: Float,
        energyJoulesPerToken: Double?
    ) {
        self.coldRun = coldRun
        self.loadTimeSeconds = loadTimeSeconds
        self.downloadTimeSeconds = downloadTimeSeconds
        self.firstTokenLatencyMS = firstTokenLatencyMS
        self.promptTokensPerSecond = promptTokensPerSecond
        self.decodeTokensPerSecond = decodeTokensPerSecond
        self.promptTokenCount = promptTokenCount
        self.generatedTokenCount = generatedTokenCount
        self.totalGenerationTimeSeconds = totalGenerationTimeSeconds
        self.cancellationLatencyMS = cancellationLatencyMS
        self.stopReason = stopReason
        self.memoryBaselineMB = memoryBaselineMB
        self.memoryAfterLoadMB = memoryAfterLoadMB
        self.memoryPeakDuringDecodeMB = memoryPeakDuringDecodeMB
        self.memoryAfterGenerationMB = memoryAfterGenerationMB
        self.initialThermalState = initialThermalState
        self.peakThermalState = peakThermalState
        self.finalThermalState = finalThermalState
        self.decodeRateRollingWindow = decodeRateRollingWindow
        self.energyJoules = energyJoules
        self.batteryDeltaPercent = batteryDeltaPercent
        self.energyJoulesPerToken = energyJoulesPerToken
    }
}
