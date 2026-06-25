# Gap-fill / bench-continuation session — rebuild + measure the new Core AI bundles

**Status (2026-06-25 export pass): the wiring is DONE.** The export session produced bundles; this repo already has
the catalog entries + bundleSpec cases + manifest rows for all 9 ready cells. **Your job is just: rebuild (keep
entitlements) → side-load → measure → update the report.** iPhone 17 Pro must be connected.

## What's ready (verified bundles in `~/code/coreai/coreai-models/exports/`)
| Model | Core AI GPU | Core AI ANE | model-ids to measure |
|---|---|---|---|
| Ministral-3-3B | ✅ | ✗ blocked | `core-ai/ministral-3b-gpu` |
| Gemma3-1B | ✅ | ✗ blocked | `core-ai/gemma3-1b-gpu` |
| Phi-4-mini | ✅ | ✗ blocked | `core-ai/phi-4-mini-gpu` |
| Llama-3.2-3B | ✅ | ✅ | `core-ai/llama-3.2-3b-gpu` + `…-ane` |
| OLMo-2-1B | ✅ | ✅ | `core-ai/olmo2-1b-gpu` + `…-ane` |
| SmolLM3-3B | ✅ | ✅ | `core-ai/smollm3-3b-gpu` + `…-ane` |

→ **9 new iPhone cells (6 GPU + 3 ANE)**, all bundles verified (aimodelc + tokenizer + assets.main). Plus: the
export session wrote macOS classes for phi3/olmo2/smollm3/ministral (all macOS-parity PASS) → **the Mac Core AI
column is now 10/10** (bench those via coreai-models' `llm-benchmark`).

**The 3 missing iPhone-ANE cells are CONFIRMED technical walls, not pending work — leave them blank and document
the reason in the report** (these are legitimate Core AI iOS-ANE pipeline coverage findings):
- **Phi-4-mini ANE:** `coreai-build --preferred-compute neural-engine` SIGSEGVs deterministically (idle, 2×); GPU
  compiles fine. Upstream-compiler crash on the partial-rotary slice+cat graph (intrinsic; can't reformulate
  without breaking HF parity). iOS class is bit-exact vs HF — the *bundle* is blocked, not the model.
- **Ministral-3-3B ANE:** the iOS/ANE path needs `Mistral3ForConditionalGeneration.from_pretrained` (multimodal +
  FP8) → effectively unloadable. GPU bundle ships via the macOS shim path.
- **Gemma3-1B ANE:** the standard iOS pipeline can't express alternating sliding/full attention + dual
  local/global RoPE (single-mask / single-RoPE contract). Would need a gemma4-style custom decode core + exporter
  (deferred — high effort, low success, and short-context-only approximation would compromise the long-context cells).

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
4. **Mac column (use the iso protocol):** bench the **macOS** Core AI bundle for each via coreai-models'
   `llm-benchmark` — **same 512-token prompt + 512 decode greedy as MLX/LiteRT** (see the *Mac iso protocol* section
   in `comprehensive-bench-runbook.md`). Fills the Mac Core AI cells for Phi/OLMo/SmolLM3/Ministral (Gemma3 327.2,
   Llama 198.3 already done). Re-measure MLX/LiteRT Mac with the same 512-token prompt so prefill is iso too.

## Update the report + data
- `docs/litert-community-vs-mlx-coreai.md` **and** `~/code/litertlm-convert/reports/litert-community-vs-mlx-coreai.md`:
  fill the Core AI cells (Mac + iPhone) for these models; replace the `✗ no iOS class` / `✗ no wrapper` notes with
  the measured numbers (leave Ministral/Gemma3/Phi iPhone-**ANE** as ✗ until the follow-up export).
- Append rows to `results/raw/2026-06-24-coreai-iphone/results.jsonl` (or a new dated dir).
- **Commit + push** (no "claude" in committer/message; don't commit model/build files).

## Done when
All 10 models show **Mac Core AI** numbers, and the 6 export-pass models show **iPhone Core AI** (6 GPU + the 3
ANE: Llama/OLMo-2/SmolLM3). Permanently-blank cells, each with a documented reason in the report:
- **Core AI iPhone-ANE ×3** — Phi (compiler SIGSEGV), Ministral (multimodal-fp8 loader), Gemma3 (dual-RoPE/sliding
  not expressible). Confirmed upstream/architectural walls, not pending work.
- **MLX ×3** — Ministral iPhone (MLX-Swift arch hard block); VibeThinker & OLMo-2 (no mlx-community repo).

Update `next-session-brief.md` status when the matrix is closed.

## (Reference) wiring pattern — for the 3 pending ANE or any FUTURE export
For a new bundle `<name>_gpu` / `<name>_ane`: add a `ModelInfo` in `ModelCatalog.swift` + a bundleSpec case in
`CoreAIRuntime.swift` (`-ane` → `("<name>_ane","static-shape")`, `-gpu` → `("<name>_gpu","coreai-pipelined")`) +
a `manifest.tsv` row (src = `EX/<name>_{gpu|ane_pure4bit}`, dest = `CoreAIModels/<name>_{gpu|ane}`). Mirror the
2026-06-25 entries (search the dated comment in each file).
