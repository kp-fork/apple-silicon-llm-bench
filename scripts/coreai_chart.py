#!/usr/bin/env python3
"""Core AI vs MLX vs CoreML — iPhone 17 Pro, Qwen3-0.6B, short-chat.

Two panels: decode tok/s (warm; Core AI GPU's cold value annotated) + peak RAM.
Outputs docs/charts/iphone_coreai_qwen3_0_6b.png.
"""
import json
import statistics
from pathlib import Path

import matplotlib as mpl
import matplotlib.pyplot as plt

REPO = Path(__file__).resolve().parent.parent
RAW = REPO / "results" / "raw"
OUT = REPO / "docs" / "charts"
OUT.mkdir(parents=True, exist_ok=True)

mpl.rcParams.update({
    "font.family": "DejaVu Sans",
    "axes.spines.top": False, "axes.spines.right": False,
    "axes.grid": True, "axes.grid.axis": "x", "grid.alpha": 0.3,
    "axes.titlesize": 13, "axes.titleweight": "bold", "axes.titlepad": 10,
    "figure.dpi": 140, "savefig.dpi": 140, "savefig.bbox": "tight",
})

# id-substring -> (label, color). Order = display order (fastest first).
ENGINES = [
    ("core-ai/qwen3-0.6b-gpu", "Core AI · GPU",  "#e11d48"),
    ("mlx-community/qwen3-0.6b", "MLX · GPU",     "#7c3aed"),
    ("core-ai/qwen3-0.6b-ane", "Core AI · ANE",  "#fb7185"),
    ("coreml-llm/qwen3-0.6b",  "CoreML-LLM · ANE", "#f59e0b"),
]


def med(xs):
    xs = [x for x in xs if x is not None]
    return statistics.median(xs) if xs else 0.0


def collect():
    rows = {}
    for p in sorted(RAW.glob("iphone17pro-*qwen3-0.6b*.jsonl")):
        try:
            d = json.loads(p.read_text())
        except Exception:
            continue
        mid = (d.get("model") or {}).get("id", "").lower()
        m = d.get("metrics") or {}
        rows.setdefault(mid, []).append(
            (m.get("decodeTokensPerSecond"), m.get("memoryPeakDuringDecodeMB"),
             bool(m.get("coldRun"))))
    return rows


def main():
    rows = collect()
    labels, colors, warm, cold, mem = [], [], [], [], []
    for needle, label, color in ENGINES:
        recs = next((v for k, v in rows.items() if needle in k), [])
        if not recs:
            continue
        w = [r[0] for r in recs if not r[2]] or [r[0] for r in recs]
        decs = [r[0] for r in recs if r[0] is not None]
        labels.append(label); colors.append(color)
        # warm = steady-state; first = worst (first-ever) run = the kernel-compile cost
        warm.append(med(w)); cold.append(min(decs) if decs else None); mem.append(med([r[1] for r in recs]))

    y = range(len(labels))[::-1]  # fastest on top
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(11, 4.0), gridspec_kw={"width_ratios": [1.45, 1]})

    # --- decode tok/s ---
    ax1.barh(list(y), warm, color=colors, edgecolor="white", linewidth=0.6, height=0.68)
    for yi, wv, cv in zip(y, warm, cold):
        ax1.text(wv + 3, yi, f"{wv:.0f}", va="center", ha="left", fontsize=11, fontweight="bold", color="#111")
        if cv is not None and abs(cv - wv) / max(wv, 1) > 0.15:
            ax1.plot([cv, cv], [yi - 0.34, yi + 0.34], color="#7f1d1d", lw=1.6, ls=(0, (2, 1)))
            ax1.text(cv - 3, yi, f"1st run {cv:.0f}", va="center", ha="right", fontsize=8, color="#7f1d1d")
    ax1.set_yticks(list(y)); ax1.set_yticklabels(labels, fontsize=10.5)
    ax1.set_xlabel("decode tok/s  (warm; ↑ better)", fontsize=10)
    ax1.set_title("On-device LLM decode speed", loc="left")
    ax1.set_xlim(0, max(warm) * 1.18)

    # --- peak RAM ---
    ax2.barh(list(y), mem, color=colors, edgecolor="white", linewidth=0.6, height=0.68)
    for yi, mv in zip(y, mem):
        ax2.text(mv + max(mem) * 0.02, yi, f"{mv:.0f}", va="center", ha="left", fontsize=10.5, fontweight="bold", color="#111")
    ax2.set_yticks(list(y)); ax2.set_yticklabels([])
    ax2.set_xlabel("peak RAM (MB; ↓ better)", fontsize=10)
    ax2.set_title("Memory footprint", loc="left")
    ax2.set_xlim(0, max(mem) * 1.2)

    fig.suptitle("Apple Core AI vs MLX vs CoreML — iPhone 17 Pro, Qwen3-0.6B",
                 fontsize=14, fontweight="bold", y=1.02, x=0.5)
    fig.text(0.5, -0.04, "github.com/john-rocky/apple-silicon-llm-bench  ·  same harness, greedy, short-chat",
             ha="center", fontsize=8.5, color="#666")
    out = OUT / "iphone_coreai_qwen3_0_6b.png"
    plt.savefig(out)
    plt.close(fig)
    print("wrote", out)


if __name__ == "__main__":
    main()
