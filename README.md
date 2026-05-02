# iOS On-device LLM Benchmark

A practical benchmark for running local LLMs on iPhone.

This project compares **MLX Swift, llama.cpp, CoreML (swift-transformers), MediaPipe / LiteRT-LM, ExecuTorch, and ANEMLL** under real iOS app constraints.

Instead of focusing only on raw tokens/sec, this benchmark also tracks **memory usage, app/package size, model loading time, thermal behavior, energy per token, app lifecycle stability, streaming, cancellation, and integration difficulty**.

The goal is simple:

> Which local LLM runtime is actually practical for shipping inside an iOS app?

## Status

The included iOS app (`ios/BenchmarkApp`) builds cleanly for iOS 18 and integrates **all six** runtimes end-to-end:

| Runtime | Adapter | Wire-up |
|---|---|---|
| MLX Swift | `MLXRuntime.swift` | SPM (`mlx-swift-lm`) |
| llama.cpp | `LlamaCppRuntime.swift` | vendored `llama.xcframework` (downloaded by `bootstrap.sh`) |
| CoreML (swift-transformers) | `CoreMLRuntime.swift` | SPM (`swift-transformers` `Models` + `Generation`) |
| MediaPipe / LiteRT-LM | `MediaPipeRuntime.swift` | `canImport`-gated; add `paescebu/SwiftTasksGenAI` via Xcode UI |
| ExecuTorch | `ExecuTorchRuntime.swift` | SPM (`pytorch/executorch` swiftpm-* branch) |
| ANEMLL | `AnemllRuntime.swift` | local SPM via vendored `Anemll/` (cloned by `bootstrap.sh`) |

All adapters are real implementations — nothing is stubbed. Adapters whose framework is not yet present in the build are gated with `#if canImport(...)` so they fall back to a clear "not added" error rather than failing the build.

## Quick start (run on your iPhone)

```bash
# 1. fetch the binary deps (llama.xcframework, Anemll source)
cd ios/BenchmarkApp
./scripts/bootstrap.sh

# 2. open and run
open BenchmarkApp.xcodeproj
# Set your Team in Signing & Capabilities, select your iPhone, ⌘R
```

The `BenchmarkApp.xcodeproj` is committed — no `xcodegen` install required for normal use. (If you edit `project.yml` to add a runtime or change build settings, install `brew install xcodegen` and run `REGEN_XCODEPROJ=1 ./scripts/bootstrap.sh`.)

First launch downloads the default model (`mlx-community/gemma-4-e2b-it-4bit`, ~1.3 GB) into the app's Documents directory. Use the picker to swap to any other model from the per-runtime catalog.

To enable the **MediaPipe / LiteRT-LM** runtime (optional):

1. In Xcode → File → Add Package Dependencies…
2. URL: `https://github.com/paescebu/SwiftTasksGenAI`
3. Add `SwiftTasksGenAI` to the `BenchmarkApp` target.
4. Rebuild — the `#if canImport(MediaPipeTasksGenAI)` block lights up.

## Benchmark metrics

For every run we record:

- **Performance** — model load time, time-to-first-token, prefill tok/s, decode tok/s, total time
- **Memory** — baseline, after model load, peak during decode, after generation (`task_info` resident size)
- **Thermal** — `ProcessInfo.thermalState` initial/peak/final + decode-rate degradation curve
- **Energy** — joules used and **joules per generated token**, derived from battery-level delta × per-device pack capacity (see [methodology/energy.md](methodology/energy.md))
- **Storage** — app binary delta, model file size, total installed footprint
- **Lifecycle** — cancellation latency, background/foreground recovery (Task D)
- **Integration** — Swift API quality, build complexity, App Store practicality (scored separately, never folded into raw numbers)

## Default model: Gemma 4 E2B

Recent releases of Gemma 4 (E2B / E4B) target on-device deployment specifically and are well-supported across MLX and llama.cpp. The other runtimes default to the strongest model their format ecosystem currently publishes:

| Runtime | Default model | Format |
|---|---|---|
| MLX Swift | `mlx-community/gemma-4-e2b-it-4bit` | MLX safetensors |
| llama.cpp | `unsloth/gemma-4-E2B-it-GGUF` | GGUF Q4_K_M |
| CoreML (swift-transformers) | `smpanaro/Llama-3.2-1B-Instruct-CoreML` | `.mlpackage` (no Gemma 4 .mlpackage published yet) |
| MediaPipe | `litert-community/Gemma3-1B-IT` | `.task` (Gemma 4 ships only as `.litertlm`, not yet loadable in MediaPipeTasksGenAI 0.10.x) |
| ExecuTorch | `executorch-community/Llama-3.2-1B-Instruct-SpinQuant_INT4_EO8-ET` | `.pte` (no official Gemma 4 .pte) |
| ANEMLL | `anemll/anemll-google-gemma-3-1b-it-ctx4096_0.3.5` | multi-`.mlmodelc` ANE bundle |

Model coverage gaps are documented per runtime in [`runtimes/`](runtimes/).

## Sample result table

The README will be updated as real numbers come in. Until then, this is the schema:

| Runtime | Model | Device | Quant | Load (s) | TTFT (ms) | Decode tok/s | Peak Mem (MB) | J/token | Thermal |
|---|---|---|---|---:|---:|---:|---:|---:|---|
| MLX Swift | Gemma 4 E2B 4-bit | iPhone 17 Pro | Q4 | TBD | TBD | TBD | TBD | TBD | nominal |
| llama.cpp | Gemma 4 E2B Q4_K_M | iPhone 17 Pro | Q4_K_M | TBD | TBD | TBD | TBD | TBD | nominal |
| CoreML | Llama 3.2 1B | iPhone 17 Pro | mixed | TBD | TBD | TBD | TBD | TBD | nominal |
| MediaPipe | Gemma 3 1B | iPhone 17 Pro | INT4 | TBD | TBD | TBD | TBD | TBD | nominal |
| ExecuTorch | Llama 3.2 1B SpinQuant | iPhone 17 Pro | INT4 | TBD | TBD | TBD | TBD | TBD | nominal |
| ANEMLL (ANE) | Gemma 3 1B | iPhone 17 Pro | Q4 | TBD | TBD | TBD | TBD | TBD | nominal |

Filled-in results live in [`RESULTS.md`](RESULTS.md) and [`results/`](results/).

## What this benchmark does **not** do

- Does **not** rank model intelligence (use MMLU, GSM8K, MT-Bench for that)
- Does **not** benchmark server inference
- Does **not** compare a 4-bit GGUF and an FP16 CoreML model as if they were the same thing
- Does **not** hide failures — out-of-memory, crashes, and unsupported context lengths stay in the table
- Does **not** focus on Android in the initial version

## Repository layout

```
ios-llm-benchmark/
├── README.md, DESIGN.md, RESULTS.md
├── devices/      one .md per phone we test on
├── runtimes/     one .md per runtime we evaluate (integration notes + caveats)
├── models/       one .md per model family
├── prompts/      the four fixed benchmark prompts
├── methodology/  measurement, fairness, thermal, memory, energy definitions
├── results/      raw/ JSON dumps, summary/ generated tables
└── ios/          on-device benchmark app (XcodeGen project)
```

## Contributing

Real measurements from real devices are the most valuable contribution. To submit a result:

1. Run the iOS app on your device, open a result, hit the share button.
2. AirDrop or share the JSON to your Mac.
3. Drop it into `results/raw/`.
4. Open a PR. Please include the device, iOS version, build configuration, and whether the device was charging / in low-power mode.

## License

MIT — see [LICENSE](LICENSE).
