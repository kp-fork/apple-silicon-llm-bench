# Gap-fill / bench-continuation session — rebuild + measure the new Core AI bundles

**Status (2026-06-25 export pass): the wiring is DONE.** The export session produced bundles; this repo already has
the catalog entries + bundleSpec cases + manifest rows for all 9 ready cells. **Your job is just: rebuild (keep
entitlements) → side-load → measure → update the report.** iPhone 17 Pro must be connected.

## What's ready (verified bundles in `~/code/coreai/coreai-models/exports/`)
| Model | Core AI GPU | Core AI ANE | model-ids to measure |
|---|---|---|---|
| Ministral-3-3B | ✅ | ✗ pending | `core-ai/ministral-3b-gpu` |
| Gemma3-1B | ✅ | ✗ pending | `core-ai/gemma3-1b-gpu` |
| Phi-4-mini | ✅ | ✗ pending | `core-ai/phi-4-mini-gpu` |
| Llama-3.2-3B | ✅ | ✅ | `core-ai/llama-3.2-3b-gpu` + `…-ane` |
| OLMo-2-1B | ✅ | ✅ | `core-ai/olmo2-1b-gpu` + `…-ane` |
| SmolLM3-3B | ✅ | ✅ | `core-ai/smollm3-3b-gpu` + `…-ane` |

→ **9 new iPhone cells (6 GPU + 3 ANE).** The 3 missing ANE (Ministral / Gemma3 / Phi) need a follow-up export
pass (their `_ane_pure4bit` bundle wasn't compiled) — leave those iPhone-ANE cells blank for now.

## ⚠ Critical (don't repeat past mistakes)
- **The app build MUST keep the memory entitlements** (`increased-memory-limit` + `extended-virtual-addressing`).
  Without them the ≳2 GB bundles (Llama/SmolLM3 ANE 2.3 GB, Phi GPU 2.0 GB) will *falsely* OOM. Capabilities are
  registered on the App ID. If a CLI build fails on provisioning, rebuild once from **Xcode GUI**, then CLI works.
- **Never run an iOS bundle on the Mac** — measure on-device only.
- **ANE cold-load compiles on-device** (slow first run, warms after) → run 3× cold, take the median.

## Steps
1. **Rebuild + install** (keep entitlements):
   ```
   xcodebuild -project ios/BenchmarkApp/BenchmarkApp.xcodeproj -scheme BenchmarkApp -configuration Release \
     -destination 'generic/platform=iOS' -allowProvisioningUpdates DEVELOPMENT_TEAM=MFN25KNUGJ \
     -jobs 6 -derivedDataPath ~/bench-dd build
   ```
   then install the `.app`. (Xcode GUI if provisioning balks.)
2. **Side-load** the new bundles (manifest rows are already in place):
   ```
   scripts/comprehensive_bench.sh stage          # picks up the 9 new core-ai rows
   ```
3. **Measure iPhone** (short-chat 3× cold each):
   ```
   scripts/comprehensive_bench.sh speed Ministral ; … Gemma3-1B ; … Phi-4-mini ; … Llama-3.2 ; … OLMo-2 ; … SmolLM3
   ```
   (or just `scripts/comprehensive_bench.sh speed` for the whole matrix). Record decode_tok_s / ttft_ms / peak_mb.
4. **Mac column:** bench the **macOS** Core AI bundle for each via coreai-models' `llm-benchmark` (allowed on Mac;
   the macOS dynamic exports `<name>_dynamic` are in `exports/`). Fills the Mac Core AI cells for Phi/OLMo/SmolLM3
   (Gemma3 327.2, Llama 198.3, Ministral were Mac-blocked before — re-check with the new classes).

## Update the report + data
- `docs/litert-community-vs-mlx-coreai.md` **and** `~/code/litertlm-convert/reports/litert-community-vs-mlx-coreai.md`:
  fill the Core AI cells (Mac + iPhone) for these models; replace the `✗ no iOS class` / `✗ no wrapper` notes with
  the measured numbers (leave Ministral/Gemma3/Phi iPhone-**ANE** as ✗ until the follow-up export).
- Append rows to `results/raw/2026-06-24-coreai-iphone/results.jsonl` (or a new dated dir).
- **Commit + push** (no "claude" in committer/message; don't commit model/build files).

## Done when
The 6 models show Core AI numbers (GPU + the 3 ANE) in the report. Remaining blanks: 3 Core AI iPhone-ANE
(Ministral/Gemma3/Phi — follow-up export) + the 3 permanent MLX cells (Ministral iPhone-MLX hard block;
VibeThinker/OLMo MLX = no repo). Update `next-session-brief.md` status.

## (Reference) wiring pattern — for the 3 pending ANE or any FUTURE export
For a new bundle `<name>_gpu` / `<name>_ane`: add a `ModelInfo` in `ModelCatalog.swift` + a bundleSpec case in
`CoreAIRuntime.swift` (`-ane` → `("<name>_ane","static-shape")`, `-gpu` → `("<name>_gpu","coreai-pipelined")`) +
a `manifest.tsv` row (src = `EX/<name>_{gpu|ane_pure4bit}`, dest = `CoreAIModels/<name>_{gpu|ane}`). Mirror the
2026-06-25 entries (search the dated comment in each file).
