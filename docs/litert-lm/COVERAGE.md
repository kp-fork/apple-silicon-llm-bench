# On-device coverage matrix (iPhone 17 Pro) — verified from artifacts

> **Authoritative, evidence-checked status of every model × runtime cell.** Each cell is
> derived from an actual artifact (raw JSONL, HF repo, local bundle, Core AI export, or
> catalog entry) — not inferred. Verified 2026-06-18. Re-verify with the inventory commands
> at the bottom before trusting any cell.

## Legend

- **DATA** — already benched on iPhone 17 Pro (`results/raw/iphone17pro-*` exists)
- **READY** — artifact in hand, only needs a device run
- **DL** — catalog entry + public HF repo; needs `hf download` then run
- **EXPORT** — no artifact; needs a Mac-side export/assemble (parallel session)
- **—** — not wired / not applicable (no artifact path today)

## Matrix

| Model | litert-lm | mlx-swift | llama.cpp | coreml-llm (ANE) | Core AI GPU (lin-INT4) | Core AI ANE (palettized) |
|---|---|---|---|---|---|---|
| **Qwen3-0.6B** | **DATA** (short-chat; energy missing) | **DATA** +energy | — ¹ | **DATA** +energy | **DATA** (Debug — re-capture Release) | **DATA** (Debug — re-capture Release) |
| **Qwen3-4B** | DL ² | DL | DL | — ³ | **EXPORT** | **EXPORT** |
| **Qwen3-8B** | DL (may jetsam=record) | DL | DL | — ³ | **EXPORT** | **EXPORT** |
| **Gemma4-E2B** | **DATA** +energy | **DATA** +energy | **DATA** | **DATA** +energy | EXPORT (assemble ⁴) | EXPORT (assemble+verify ⁴) |
| **Gemma4-E4B** | DL ² | DL | DL | **DL** ⁵ | EXPORT (assemble ⁶) | EXPORT (assemble+verify) |

Mac-tier (separate, `MACOS_DESKTOP.md`): Qwen3-14B, Gemma4-12B — litert + mlx (catalog ✅, Mac has partial data).

### Evidence / footnotes

1. **llama.cpp Qwen3-0.6B**: no Qwen3-0.6B GGUF in `ModelCatalog.swift` (unsloth Qwen3 GGUF starts at 4B). Add an entry only if a 0.6B Q4_K_M GGUF is wanted.
2. **litert-community** publishes `Qwen3-{4B,8B}` and `gemma-4-E4B-it-litert-lm` (catalog L390/400/430) — public, `hf download` on run.
3. **coreml-llm Qwen3-4B/8B**: no catalog entry; CoreML at 4B/8B on ANE is impractical (memory). Left out unless explicitly wanted.
4. **Core AI Gemma4-E2B**: raw exports exist (`~/code/coreai/coreai-models/exports/gemma4_e2b_decode_int4lin{,_aotc,_tbl}`) but **no assembled gpu/ane loadable bundle** yet. Needs the assemble+engine-verify step (`coreai-matrix-completion-task.md`).
5. **CoreML Gemma4-E4B**: catalog entry **exists** (`coreml-llm/gemma4-e4b`, L514); bundle published at **`mlboydaisuke/gemma-4-E4B-coreml`** (iPhone-fitting per `ModelDownloader.swift`), not in local cache → `hf download` + side-load. **NOT a conversion task.**
6. **Core AI Gemma4-E4B**: `exports/gemma4_e4b_qat_decode_int4lin_aotc/` already has `…h18p.aimodelc` (GPU candidate); ANE-palettized variant + assemble still needed.

## What can bench NOW on iPhone (no export session needed)

Runnable today (DATA re-capture or DL+run), in parallel with the Core AI export session:

- **Qwen3-0.6B** — litert (add energy), mlx, coreml, core-ai gpu+ane (Release re-capture)
- **Qwen3-4B / 8B** — litert · mlx · llama (DL; 8B may jetsam = recorded)
- **Gemma4-E2B** — litert · mlx · llama · coreml (DATA; re-capture if conditions changed)
- **Gemma4-E4B** — litert · mlx · llama · **coreml** (DL `mlboydaisuke/gemma-4-E4B-coreml`)

## What waits on the parallel Core AI export session (`~/Downloads/coreai-matrix-completion-task.md`)

- **Core AI Qwen3-4B, Qwen3-8B** — from-scratch export (GPU dynamic linear-INT4 + ANE static palettized)
- **Core AI Gemma4-E2B, E4B** — raw exports exist; assemble GPU(linear) + ANE(palettized) bundles, verify engine, wire `core-ai/{gemma-4-e2b,gemma-4-e4b}-{gpu,ane}` into the catalog

## Re-verify (don't trust, check)

```bash
# benched already:
ls results/raw/iphone17pro-* | sed -E 's/-run[0-9]+//;s/\.jsonl$//' | sort -u
# Core AI assembled bundles (need .aimodelc + metadata.json + tokenizer):
ls ~/code/coreai/coreai-models/exports/*_{gpu,ane,ane_pure4bit}/metadata.json 2>/dev/null
# CoreML local bundles vs catalog ids:
ls ~/Documents/Models/ ; grep 'coreml-llm/' ios/BenchmarkApp/Sources/Models/ModelCatalog.swift
# catalog model ids:
grep 'id: "' ios/BenchmarkApp/Sources/Models/ModelCatalog.swift
```
