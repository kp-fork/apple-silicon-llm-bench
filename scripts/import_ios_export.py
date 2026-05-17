#!/usr/bin/env python3
"""
Yardstick — split a single iOS in-app export (.jsonl) into one
`results/raw/<device>-<runtime>-<model>-<task>-run<N>.jsonl` per run.

The iOS app's HistoryView → "Export all (JSONL)" writes one JSON object
per line into a file like:

    yardstick-iphone17,1-export-2026-05-17T14-22-09Z.jsonl

This script parses the bundle, picks a device label that
`scripts/render_results.py::DEVICE_DISPLAY` already understands (or
prints a hint if it doesn't), and writes one pretty-printed JSON file
per run into `results/raw/`. Already-existing run files for the same
`(device, runtime, model, task)` are NOT overwritten; the next
unused `-runN` index is picked instead, so re-importing is idempotent
in the worst case (creates `-run4`, `-run5`, ...).

Usage:
    python scripts/import_ios_export.py <path/to/export.jsonl>
    python scripts/import_ios_export.py <path/to/export.jsonl> --device iphone17pro
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
RAW_DIR = REPO / "results" / "raw"

# Match the keys in scripts/render_results.py::DEVICE_DISPLAY so the
# auto-imported rows show up correctly in the rendered tables. The
# iOS app captures `device.modelIdentifier`, which is the raw
# `iPhone17,3` / `iPad14,5` style string — we normalize it here.
DEVICE_NORMALIZE = {
    # iPhone 15 (A16) and iPhone 15 Pro (A17 Pro)
    "iphone15,4": "iphone15",
    "iphone15,5": "iphone15plus",
    "iphone16,1": "iphone15pro",
    "iphone16,2": "iphone15promax",
    # iPhone 16 (A18) and iPhone 16 Pro (A18 Pro)
    "iphone17,1": "iphone16",
    "iphone17,2": "iphone16plus",
    "iphone17,3": "iphone16pro",
    "iphone17,4": "iphone16promax",
    # iPhone 17 generation — Apple usually bumps the major identifier;
    # confirm by running the app once and reading the JSONL's
    # device.modelIdentifier before adding rows in bulk. Override with
    # `--device iphone17pro` if these guesses don't match.
    "iphone18,3": "iphone17pro",
    "iphone18,4": "iphone17promax",
    # iPad Pro
    "ipad14,5": "ipadprom2",
    "ipad14,6": "ipadprom2",
    "ipad16,3": "ipadprom4",
    "ipad16,4": "ipadprom4",
}


def normalize_device(raw_or_label: str) -> str:
    needle = raw_or_label.lower().replace("-", "").replace("_", "")
    return DEVICE_NORMALIZE.get(needle, raw_or_label.lower().replace(",", "-"))


def shortname_for_runtime(runtime: str) -> str:
    """Compact, filesystem-safe runtime token used in the JSONL filename."""
    return {
        "mlx-swift": "mlx",
        "llama.cpp": "llama-cpp",
        "coreml-llm": "coreml-llm",
        "executorch": "executorch",
        "anemll": "anemll",
        "litert-lm": "litert-lm",
        "apple-fm": "apple-fm",
    }.get(runtime, runtime.replace(".", "-"))


def shortname_for_model(model_id: str) -> str:
    """Strip the HF org prefix and any HuggingFace path slashes."""
    tail = model_id.split("/", 1)[-1]
    return (
        tail.lower()
        .replace("_", "-")
        .replace(".gguf", "")
    )


def next_run_index(base: str) -> int:
    used = set()
    for path in RAW_DIR.glob(f"{base}-run*.jsonl"):
        m = re.search(r"-run(\d+)\.jsonl$", path.name)
        if m:
            used.add(int(m.group(1)))
    i = 1
    while i in used:
        i += 1
    return i


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("export", type=Path, help="The .jsonl file from the iOS share sheet.")
    parser.add_argument(
        "--device",
        default=None,
        help="Override the device label (must match DEVICE_DISPLAY in render_results.py).",
    )
    args = parser.parse_args()

    if not args.export.exists():
        print(f"error: no such file: {args.export}", file=sys.stderr)
        return 1

    RAW_DIR.mkdir(parents=True, exist_ok=True)

    raw = args.export.read_text(encoding="utf-8").strip()
    written = 0
    for line_no, line in enumerate(raw.split("\n"), 1):
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError as exc:
            print(f"warn: line {line_no} is not valid JSON: {exc}", file=sys.stderr)
            continue

        runtime = obj.get("runtime", "unknown")
        task = obj.get("task", "unknown")
        model_id = (obj.get("model") or {}).get("id", "unknown")
        device_raw = (obj.get("device") or {}).get("modelIdentifier", "device")

        device = args.device or normalize_device(device_raw)
        base = "-".join([
            device,
            shortname_for_runtime(runtime),
            shortname_for_model(model_id),
            task,
        ])
        idx = next_run_index(base)
        out = RAW_DIR / f"{base}-run{idx}.jsonl"
        out.write_text(json.dumps(obj, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        print(f"wrote {out.relative_to(REPO)}", file=sys.stderr)
        written += 1

    print(
        f"\nDone — imported {written} run(s) under {RAW_DIR.relative_to(REPO)}/.",
        file=sys.stderr,
    )
    print(
        "Re-render the tables with: python scripts/render_results.py",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
