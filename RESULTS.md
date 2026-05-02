# RESULTS

Real on-device measurements live here. Until they are filled in, every cell shows `TBD`.

Each row corresponds to a `(runtime, model, device, build)` tuple. Raw JSON dumps from the iOS app live in [`results/raw/`](results/raw/); the tables here are generated summaries.

## Format

| Column          | Definition |
|-----------------|------------|
| Runtime         | mlx-swift / llama.cpp / coreml-llm / litert-lm / executorch / anemll |
| Model           | HF repo id or original name |
| Device          | e.g. `iPhone 17 Pro` |
| iOS             | OS version |
| Build           | Debug / Release / TestFlight / App-Store-equivalent Release |
| Quant           | FP16 / Q8 / Q4 / mixed |
| Context         | tokens |
| Load            | seconds, cold model load (excludes download) |
| TTFT            | milliseconds, time to first token |
| Prefill tok/s   | prompt-processing throughput |
| Decode tok/s    | generation throughput |
| Peak Mem        | MB, peak resident memory during generation |
| Thermal         | nominal / fair / serious / critical (final state) |
| Notes           | failures, caveats, special configuration |

## Task A — Short chat (128 tokens)

| Runtime    | Model            | Device         | iOS  | Build   | Quant | Context | Load | TTFT | Prefill tok/s | Decode tok/s | Peak Mem | Thermal | Notes |
|------------|------------------|----------------|------|---------|-------|--------:|-----:|-----:|--------------:|-------------:|---------:|---------|-------|
| mlx-swift  | Qwen3-0.6B-4bit  | iPhone 17 Pro  |  TBD | Release | Q4    |    2048 |  TBD |  TBD |           TBD |          TBD |      TBD | TBD     | TBD   |

## Task B — Long-context prefill (2K prompt, 64-token output)

| Runtime    | Model            | Device         | iOS  | Build   | Quant | Context | Load | TTFT | Prefill tok/s | Decode tok/s | Peak Mem | Thermal | Notes |
|------------|------------------|----------------|------|---------|-------|--------:|-----:|-----:|--------------:|-------------:|---------:|---------|-------|
| mlx-swift  | Qwen3-0.6B-4bit  | iPhone 17 Pro  |  TBD | Release | Q4    |    2048 |  TBD |  TBD |           TBD |          TBD |      TBD | TBD     | TBD   |

## Task C — Sustained generation (512 tokens)

| Runtime    | Model            | Device         | iOS  | Build   | Quant | Context | Load | TTFT | Avg tok/s | Min tok/s | Speed drop | Peak Mem | Thermal | Completed |
|------------|------------------|----------------|------|---------|-------|--------:|-----:|-----:|----------:|----------:|-----------:|---------:|---------|-----------|
| mlx-swift  | Qwen3-0.6B-4bit  | iPhone 17 Pro  |  TBD | Release | Q4    |    2048 |  TBD |  TBD |       TBD |       TBD |        TBD |      TBD | TBD     | TBD       |

## Task D — App-lifecycle loop

| Runtime    | Model            | Device         | iOS  | Build   | Cancellation | Background recovery | Repeated-gen stability | Notes |
|------------|------------------|----------------|------|---------|--------------|---------------------|------------------------|-------|
| mlx-swift  | Qwen3-0.6B-4bit  | iPhone 17 Pro  |  TBD | Release | TBD          | TBD                 | TBD                    | TBD   |

## Failed runs

Failure is signal — keep them visible.

| Runtime    | Model            | Device         | Result | Reason |
|------------|------------------|----------------|--------|--------|
| _none yet_ |                  |                |        |        |
