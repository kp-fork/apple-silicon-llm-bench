// swift-tools-version: 6.0
// Yardstick — Apple Silicon AI benchmark harness (Mac + iPhone + iPad)

import PackageDescription

let package = Package(
    name: "Yardstick",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        // The bench harness as a reusable library — same code drives the
        // iOS BenchmarkApp and the macOS `yardstick` CLI.
        .library(name: "YardstickKit", targets: ["YardstickKit"]),

        // macOS command-line runner.
        .executable(name: "yardstick", targets: ["YardstickCLI"]),
    ],
    dependencies: [
        // Runtime SDKs — keep this list aligned with ios/BenchmarkApp/project.yml.
        // Phase 1 wires the MLX backend only; other runtimes are added in
        // follow-up commits once their Mac toolchain is verified.
        .package(url: "https://github.com/ml-explore/mlx-swift-lm", branch: "main"),
        .package(url: "https://github.com/huggingface/swift-huggingface", from: "0.8.1"),
        .package(url: "https://github.com/huggingface/swift-transformers", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "YardstickKit",
            dependencies: [
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "HuggingFace", package: "swift-huggingface"),
                .product(name: "Transformers", package: "swift-transformers"),
            ],
            path: "ios/BenchmarkApp/Sources",
            // Keep Benchmark/, Models/, and the MLX-related runtime sources
            // (LLMRuntime protocol, HFDownloader helper, MLXBridges, MLXRuntime).
            // The other adapter files are excluded until their Mac build path
            // is wired up in a follow-up PR (each pulls in a different vendored
            // SDK: AnemllCore, llama.xcframework, CoreMLLLM, executorch,
            // MediaPipeTasksGenAI).
            exclude: [
                "Info.plist",
                "Assets.xcassets",
                "Resources",
                "Views",
                "BenchmarkApp.swift",
                "Runtimes/CoreMLRuntime.swift",
                "Runtimes/AnemllRuntime.swift",
                "Runtimes/LlamaCppRuntime.swift",
                "Runtimes/ExecuTorchRuntime.swift",
                "Runtimes/MediaPipeRuntime.swift",
            ]
        ),

        .executableTarget(
            name: "YardstickCLI",
            dependencies: ["YardstickKit"],
            path: "apple/YardstickCLI/Sources"
        ),
    ]
)
