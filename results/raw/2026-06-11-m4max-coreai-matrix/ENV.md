# Environment stamp — 2026-06-11 M4 Max official-recipe matrix

## Hardware
- Apple M4 Max, 128 GB RAM
- ProductName:		macOS ProductVersion:		27.0 BuildVersion:		26A5353q 
- Xcode: Xcode 27.0 Build version 27A5194q 

## Stacks
- coreai-core 1.0.0b1 / coreai-torch 0.4.0 / coreai-opt 0.2.0 / coreai-models 0.1.0 (venv installed 2026-06-09)
- coreai-models repo: local checkout @ b1cb71b + session patches (see CAVEAT in summary md); upstream main @ 0c1055f at bench time
- mlx-lm 0.31.3 / mlx 0.31.2 (python 3.14.5)
- torch 2.9.0

## Protocol
- Core AI: swift llm-benchmark release build, -p 512 -g 1024 -n 5 (defaults), greedy temp 0
- MLX: python -m mlx_lm benchmark --model <mlx-community 4bit> -p 512 -g 1024 -n 5
- Load times: llm-runner 'Model Load' line; memory: /usr/bin/time -l max RSS

## Caveat: export-lowering sensitivity
All Core AI artifacts in this directory were exported on macOS 27β (2026-06-11). A macOS-26-era artifact of the same qwen3-0.6b recipe decodes 2.2x faster — see methodology/coreai-export-lowering.md and qwen3-0.6b_artifact_generations_p128g256.log.

## Artifact hashes (macOS-26-era, archived)
- qwen3_0_6b_dynamic main.mlirb (native quantized-Linear lowering, 1116 tok/s): f7a8357f50292f4425591fb0ed2ef4c89c91b658498d89e7e8b516eca0e89554
- qwen3_0_6b_ios main.mlirb (static iOS, same era): 79d4c7602293cd1c0acf82936a5871e8e9a6012e8613027edb027ddfc5097ada
