# LiteRT-LM / MediaPipe LLM Inference

Google's mobile-optimized on-device LLM runtime (formerly TFLite + MediaPipe).

- Reference: <https://github.com/google-ai-edge/LiteRT-LM> and the MediaPipe LLM Inference task
- License: Apache 2.0
- Backend: GPU / CPU on iOS

## Strengths

- Strong Gemma family support (it's Google's own).
- Cross-platform parity with Android, useful for teams shipping both.
- Active development by Google AI Edge team.

## Weaknesses

- iOS support has historically lagged Android.
- Heavier dependency footprint than llama.cpp or MLX.
- Model formats are runtime-specific (`.task` packages) — model availability depends on Google publishing conversions.

## iOS integration notes (planned, not yet implemented)

Pull the iOS XCFramework for MediaPipe Tasks LLM Inference, vendor it into the project, and call through the Objective-C / Swift API surface.

## Models targeted

- `gemma-3n-E2B-it` (if a `.task` is published)
- `gemma-2-2b-it`

## Status

Stub adapter only.
