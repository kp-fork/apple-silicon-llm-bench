#!/usr/bin/env bash
#
# comprehensive_bench.sh — drive the full comparable-model × runtime matrix for
# speed + memory (short-chat, plugged-in OK) and energy (sustained, UNPLUGGED).
# Reads results/raw/2026-06-25-comprehensive/manifest.tsv.
#
# Usage:
#   comprehensive_bench.sh stage              # side-load all CoreAI + LiteRT bundles
#   comprehensive_bench.sh speed [family]     # short-chat 3x each → speed+mem+TTFT JSONL
#   comprehensive_bench.sh energy <model_id> <runtime> [sustain=600] [maxtok=2048]
#   comprehensive_bench.sh collect            # pull Documents/results off device (energy JSON)
#
# Speed/memory: USB plugged is fine. Energy: device MUST be unplugged (see runbook).
set -uo pipefail

DEV="${DEV:-A6F3E849-1947-5202-9AD1-9C881CA58EEF}"   # devicectl identifier (override via env)
APP=com.iosllmbenchmark.benchmarkapp
ROOT=~/Downloads/ios-llm-benchmark
MAN="$ROOT/results/raw/2026-06-25-comprehensive/manifest.tsv"
OUT="$ROOT/results/raw/2026-06-25-comprehensive"
EX=~/code/coreai/coreai-models/exports
O=~/code/litertlm-convert/out
SCR="${TMPDIR:-/tmp}/cbench_stage"; mkdir -p "$SCR" "$OUT"
resolve() { echo "$1" | sed "s#^EX/#$EX/#; s#^O/#$O/#"; }
rows() { grep -vE '^\s*#|^\s*$' "$MAN"; }   # data rows only

dev_ok() { xcrun devicectl list devices 2>/dev/null | grep -qiE "$DEV.*(connected|available)" || \
  { echo "⚠ device $DEV not connected"; return 1; }; }

cmd_stage() {
  dev_ok || return 1
  rows | while IFS=$'\t' read -r fam params rt mid src dest; do
    [ "$src" = "-" ] && { echo "skip (download): $mid"; continue; }
    src="$(resolve "$src")"
    if [ -d "$src" ]; then                      # CoreAI bundle dir
      [ -d "$src" ] || { echo "✗ missing $src"; continue; }
      echo "stage CoreAI $mid → Documents/$dest"
      xcrun devicectl device copy to --device "$DEV" --domain-type appDataContainer \
        --domain-identifier "$APP" --source "$src" --destination "Documents/$dest" 2>&1 | tail -1
    elif [ -f "$src" ]; then                     # LiteRT .litertlm file → dest/model.litertlm
      local stg="$SCR/$(basename "$dest")"; rm -rf "$stg"; mkdir -p "$stg"; cp "$src" "$stg/model.litertlm"
      echo "stage LiteRT $mid → Documents/$dest"
      xcrun devicectl device copy to --device "$DEV" --domain-type appDataContainer \
        --domain-identifier "$APP" --source "$stg" --destination "Documents/$dest" 2>&1 | tail -1
    else echo "✗ missing source for $mid: $src"; fi
  done
}

cmd_speed() {  # [family filter]
  dev_ok || return 1
  local filt="${1:-}" jsonl="$OUT/speed_mem.jsonl"
  echo "writing → $jsonl"
  rows | while IFS=$'\t' read -r fam params rt mid src dest; do
    [ -n "$filt" ] && [ "$fam" != "$filt" ] && continue
    echo "##### $mid ($rt) #####"
    for run in 1 2 3; do
      line=$(timeout 420 xcrun devicectl device process launch --console --terminate-existing \
        --device "$DEV" "$APP" -- --yardstick-autorun --runtime "$rt" --model-id "$mid" \
        --task short-chat --runs 1 </dev/null 2>&1 \
        | grep -oE "decode_tok_s=[0-9.]+ ttft_ms=[0-9]+ peak_mb=[0-9]+|YARDSTICK_RUN_FAIL[^\"]{0,50}|Cannot allocate memory")
      echo "  run$run :: ${line:-<no verdict>}"
      d=$(echo "$line" | grep -oE "decode_tok_s=[0-9.]+" | cut -d= -f2)
      t=$(echo "$line" | grep -oE "ttft_ms=[0-9]+" | cut -d= -f2)
      p=$(echo "$line" | grep -oE "peak_mb=[0-9]+" | cut -d= -f2)
      [ -n "$d" ] && echo "{\"family\":\"$fam\",\"params\":\"$params\",\"runtime\":\"$rt\",\"model_id\":\"$mid\",\"run\":$run,\"decode_tps\":$d,\"ttft_ms\":${t:-null},\"peak_mb\":${p:-null}}" >> "$jsonl"
      sleep 5
    done
  done
  echo "DONE → $jsonl"
}

cmd_energy() {  # <model_id> <runtime> [sustain=600] [maxtok=2048]
  local mid="$1" rt="$2" sustain="${3:-600}" maxtok="${4:-2048}"
  cat <<EOF
=== ENERGY run: $mid ($rt), sustain=${sustain}s maxtok=$maxtok ===
PRE-FLIGHT (must all be true): unplugged-or-about-to-unplug · Low Power Mode OFF ·
  brightness fixed + auto-brightness OFF · battery 80–95% · no other foreground apps.
Launching detached (no --console) so you can UNPLUG immediately after launch.
EOF
  xcrun devicectl device process launch --terminate-existing --device "$DEV" "$APP" -- \
    --yardstick-autorun --runtime "$rt" --model-id "$mid" --task energy \
    --sustain-seconds "$sustain" --max-tokens "$maxtok" </dev/null 2>&1 | tail -2
  echo ">>> UNPLUG USB NOW. Leave it ~$((sustain+90))s, then: $0 collect"
}

cmd_collect() {
  dev_ok || return 1
  local dst="$OUT/device_results"; mkdir -p "$dst"
  xcrun devicectl device copy from --device "$DEV" --domain-type appDataContainer \
    --domain-identifier "$APP" --source "Documents/results" --destination "$dst" 2>&1 | tail -1
  echo "=== energy rows (joules != null = battery actually dropped) ==="
  grep -rhoE '"energyJoules":[0-9.]+[^}]*"energyJoulesPerToken":[0-9.]+' "$dst" 2>/dev/null | tail -20 || \
    find "$dst" -name '*.json' | tail -5
}

case "${1:-}" in
  stage) cmd_stage ;;
  speed) cmd_speed "${2:-}" ;;
  energy) shift; cmd_energy "$@" ;;
  collect) cmd_collect ;;
  *) sed -n '2,20p' "$0" ;;
esac
