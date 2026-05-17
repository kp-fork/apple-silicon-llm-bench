#!/usr/bin/env bash
# Measure J/token for the 3 remaining Gemma 4 E2B backends + Apple FM on M4 Max.
# Run this *in your terminal* (sudo needs your tty); takes ~1 min total.
#
# Usage:  bash scripts/measure_energy_gemma_e2b.sh
set -e

PY=/opt/homebrew/bin/python3
SCRIPT=$(dirname "$0")/measure_energy.py

echo "=== 1/4: mlx-swift Gemma 4 E2B (Q4, sustained) ==="
$PY $SCRIPT --task sustained --runtime mlx-swift \
    --model mlx-community/gemma-4-e2b-it-4bit --device m4max

echo "=== 2/4: llama.cpp Gemma 4 E2B (Q4_K_M, sustained) ==="
$PY $SCRIPT --task sustained --runtime llama-cpp \
    --model unsloth/gemma-4-E2B-it-GGUF/Q4_K_M --device m4max

echo "=== 3/4: coreml-llm Gemma 4 E2B (INT4 palettized, sustained) ==="
$PY $SCRIPT --task sustained --runtime coreml-llm \
    --model coreml-llm/gemma4-e2b --device m4max

echo "=== 4/4: apple-fm (sustained) ==="
$PY $SCRIPT --task sustained --runtime apple-fm --device m4max

echo "=== Done. Re-rendering RESULTS.md ==="
$PY $(dirname "$0")/render_results.py
