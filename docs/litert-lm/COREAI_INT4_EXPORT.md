# Core AI — matched-INT4 export (decoupling compute unit from quant)

> **Status: OPEN / experiment pending.** This doc states a known limitation of the
> Core AI rows in the comparison and the plan to resolve it. No matched-INT4 result
> exists yet — when one does, it replaces the "pending" rows below and the
> entanglement caveat in the package README is lifted.

## The problem (why the Core AI rows aren't a clean engine A/B)

In Core AI the **compute unit is fixed by the export shape**, and the two shapes
ship **different quantisation**, so the engine axis and the quant axis are entangled:

| Export | Shape | Quant | On disk | Lands on |
| --- | --- | --- | ---: | --- |
| dynamic (`--platform macOS`) | dynamic ctx | **INT4 (dynamic)** | ~327 MB | GPU (`coreai-pipelined`) |
| static (`--platform iOS`) | fixed ctx 4096 | **mixed 4/8-bit palettized** | ~434 MB | ANE (`static-shape`) |

Consequences:

1. **Core AI GPU vs ANE** confounds engine with quant — GPU is both a different
   engine *and* lighter (pure INT4 vs mixed 4/8). The 71→180 (GPU) vs ~50 (ANE)
   gap can't be attributed to the engine alone.
2. **Core AI vs LiteRT-LM** at "4-bit" hides a real byte-budget gap (327 vs 498 MB);
   a raw tok/s headline partly credits Core AI for carrying fewer bytes.

The package README discloses this (per-row quant + on-disk size + an explicit
"shipped-config, not engine A/B" caveat) but does **not** equalise it. Equalising
needs a matched-INT4 export — the experiment below.

## Goal

Produce a Core AI Qwen3-0.6B bundle that runs on the **ANE at pure INT4** (matched
to the GPU export's quant), so that:

- **Core AI GPU(INT4) vs ANE(INT4)** becomes a clean engine A/B (quant held equal), and
- a Core AI **INT4** row is byte-comparable to the LiteRT-LM INT4 row.

…**or** a documented negative result that the ANE path *requires* palettised
mixed-4/8 (with the compiler error as evidence), which establishes the entanglement
as a platform constraint rather than a preset choice — itself a publishable finding.

## Hypotheses to test

- **H1 — preset, not platform.** The mixed-4/8 on the static export comes from the
  export *recipe* (palettisation pass for ANE-friendliness), not a hard ANE
  requirement; a quant override yields a pure-INT4 static export.
- **H2 — platform constraint.** The ANE legaliser requires palettised weights; a
  pure-INT4 static export either fails to compile (`MPS→ANEC failed`, cf.
  [`methodology/coreai-engine-speed.md`](../../methodology/coreai-engine-speed.md))
  or silently falls back to GPU — in which case "ANE + INT4" is not expressible.

## Experiment plan (Mac-side; no device needed until the bench step)

Toolchain: `~/code/coreai/coreai-models` (Apple's `coreai.llm.export` + `xcrun
coreai-build compile`). Pin every artifact (see the lowering instability in
[`coreai-export-lowering.md`](../../methodology/coreai-export-lowering.md) — an
`.aimodel` is a build artifact, not a pure function of the recipe; stamp OS + date).

1. **Inspect the recipe.** Find where the static/iOS export selects mixed-4/8
   palettisation vs the dynamic export's INT4 (registry preset is
   `("qwen3-0.6b", …, "4bit", …)` for both — so the split happens in the
   platform/lowering path, not the bit-width field). Identify any quant/palettise
   override flag.
2. **Attempt a pure-INT4 static export** (H1). Export `--platform iOS` with INT4
   forced (no palettisation). Record the produced quant string + on-disk size.
3. **AOT-compile for the device** and **verify the engine actually used** — do not
   assume. `xcrun coreai-build compile … --preferred-compute neural-engine
   --architecture h18p`; confirm it compiles for ANEC (not a silent GPU fallback)
   and that `EngineFactory` selects `static-shape`.
4. **If ANE rejects INT4 (H2):** capture the exact compiler error, confirm the
   GPU-fallback behaviour, and write it up as the negative result.
5. **Assemble the loadable bundle** (compiled `.aimodelc` + `tokenizer/` +
   `metadata.json` with `assets.main`) ready for side-load, exactly as
   `scripts/bench_coreai_iphone.sh::assemble` does.

## Acceptance criteria

- A bundle whose recorded `quantization` is **INT4** *and* whose verified engine is
  **`static-shape` (ANE)** — or a reproduced compiler-rejection/fallback log proving
  it can't be. Either outcome closes this doc.
- Artifact provenance stamped (OS version, date, wheel versions, `strings main.mlirb`
  op evidence) like the other Core AI artifacts.

## Results

_Pending the separate export session._ When done, add the matched-INT4 row here and
re-run the on-device fair capture (`COREAI_CONFIG=Release scripts/bench_coreai_iphone.sh`,
3 iso-cold launches) so it promotes into the package's Qwen3-0.6B table.
