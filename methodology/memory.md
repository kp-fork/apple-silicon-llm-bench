# Memory methodology

iOS will jetsam an app that uses too much memory. For LLM runtimes this is the dominant failure mode after thermal throttling.

## Sampling

We use the Mach `task_info` call to read `mach_task_basic_info.resident_size`, which gives the process's resident memory in bytes:

```swift
var info = mach_task_basic_info()
var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size)
let result = withUnsafeMutablePointer(to: &info) {
    $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
    }
}
```

Sampled every 100 ms on a background queue during a run.

## Reported values

- `baseline_mb` — before the model is loaded
- `after_load_mb` — once the runtime reports model ready
- `peak_during_prefill_mb` — peak during prompt processing
- `peak_during_decode_mb` — peak during generation
- `after_generation_mb` — sampled 200 ms after generation completes
- `after_unload_mb` — only when the runtime exposes an unload API

The interesting deltas:

- `after_load_mb - baseline_mb` ≈ model + runtime overhead
- `peak_during_decode_mb - after_load_mb` ≈ KV cache + transient buffers
- `after_generation_mb - after_load_mb` ≈ steady-state cost of an idle loaded model

## Why not `os_proc_available_memory()`?

It exists, but its semantics changed across iOS versions. Resident size is the number jetsam looks at, and it is comparable across iOS versions.

## Jetsam budget

The actual jetsam threshold depends on the device, foreground/background state, and what other apps are doing — Apple does not publish exact numbers. As a rule of thumb on a 6 GB iPhone:

- Foreground app, screen on: ~3 GB before jetsam risk
- Background app: ~200-500 MB

We do not enforce a budget in the benchmark. If a runtime gets jetsam'd, that is the result.

## Wired-memory ticket (MLX)

MLX Swift exposes `WiredMemoryTicket` for coordinating concurrent generations. We do **not** use it in the standalone benchmark, because the benchmark only runs one generation at a time. A separate "concurrent inference" task may be added later.
