# Quality parity — correctness + degeneracy guardrail

> Scored by [`scripts/quality_check.py`](../../scripts/quality_check.py) from the `quality` task (8 fixed checkable questions, greedy). **Not** a perplexity/MMLU eval — a guardrail that catches quantization-induced quality *collapse* so the decode-tok/s tables compare runtimes at roughly equal quality, not speed-at-any-quality. Each runtime uses its native 4-bit quant (disclosed).

| Device | Runtime | Model | Quant | Correct | Degenerate? |
|---|---|---|---|---:|:--:|
| m4max-litert-lm-gemma-4-e2b | litert-lm | Gemma 4 E2B (.litertlm) | INT4 (QAT) | 8/8 | no |
| m4max-litert-lm-minicpm5-1b | litert-lm | MiniCPM5-1B (.litertlm, local) | INT4 (ekv1024) | 0/8 | ⚠️ yes |
| m4max-litert-lm-qwen3-0.6b | litert-lm | Qwen3 0.6B (.litertlm) | INT4 (mixed, blockwise gs32) | 7/8 | no |
| m4max-litert-lm-qwen3-4b | litert-lm | Qwen3 4B (.litertlm) | INT4 (mixed, blockwise gs32) | 7/8 | no |
| m4max-mlx-gemma-4-e2b | mlx-swift | Gemma 4 E2B (4-bit) | Q4 | 7/8 | no |
| m4max-mlx-lfm2.5-350m | mlx-swift | LFM2-350M (4-bit) | Q4 | 7/8 | no |
| m4max-mlx-minicpm5-1b | mlx-swift | MiniCPM5-1B (4-bit) | Q4 | 7/8 | no |
| m4max-mlx-qwen3-0.6b | mlx-swift | Qwen3-0.6B (4-bit) | Q4 | 6/8 | no |
| m4max-mlx-qwen3-4b | mlx-swift | Qwen3-4B (4-bit) | Q4 | 7/8 | no |

## Per-question hits

`17+25=42  capital=Tokyo  opp(hot)=cold  days/week=7  thanks(fr)=merci  8*7=56  0.9>0.11  rhyme=blue`

- **litert-lm Gemma 4 E2B (.litertlm)** (m4max-litert-lm-gemma-4-e2b): `✓✓✓✓✓✓✓✓`  — “42 Tokyo Cold Seven Merci 56 0.9 0.11 blue”
- **litert-lm MiniCPM5-1B (.litertlm, local)** (m4max-litert-lm-minicpm5-1b): `········`  — “<|fim_prefix|><|fim_prefix|><|fim_prefix|><|fim_prefix|><|fim_prefix|><|fim_prefix|><|fim_prefix|><|fim_prefix|><|fim_prefix|><|fim_prefix|><|fim_prefix|><|fim_prefix|><|fim_prefix|><|fim_prefix|><|fim_prefix|><|fim_prefix|><|fim_prefix|><|fim_prefix|><|fim_prefix|><|fim_prefix|><|fim_prefix|><|fim_”
- **litert-lm Qwen3 0.6B (.litertlm)** (m4max-litert-lm-qwen3-0.6b): `✓✓✓✓✓✓✓·`  — “<think> Okay, let's tackle each question one by one. 1. What is 17 + 25? Well, 17 plus 25... let me add them. 17 + 25 is 42. That's straightforward. 2. The capital of Japan is Tokyo. Yeah, I remember that from my studies. 3. The opposite of "hot" is "cold". That makes sense because heat and cold are”
- **litert-lm Qwen3 4B (.litertlm)** (m4max-litert-lm-qwen3-4b): `✓✓✓✓✓✓✓·`  — “<think> Okay, let's tackle these questions one by one. First, 17 plus 25. That's straightforward addition. 17 plus 25... 17 + 20 is 37, then plus 5 more is 42. So the answer should be 42. Next, the capital of Japan. I remember that Tokyo is the capital, but wait, isneyer, isn't Tokyo the capital? Ye”
- **mlx-swift Gemma 4 E2B (4-bit)** (m4max-mlx-gemma-4-e2b): `✓✓✓✓✓✓✓·`  — “42 Tokyo Cold Seven Merci 56 0.9 0.11”
- **mlx-swift LFM2-350M (4-bit)** (m4max-mlx-lfm2.5-350m): `✓✓✓✓✓✓✓·`  — “1. 17 + 25 = 42 2. The capital of Japan is Tokyo. 3. The opposite of "hot" is "cold". 4. There are 7 days in a week. 5. "Thank you" in French is "Merci". 6. 8 * 7 = 56 7. 0.9 is larger than 0.11. 8. "Roses are red, violets are purple."”
- **mlx-swift MiniCPM5-1B (4-bit)** (m4max-mlx-minicpm5-1b): `✓✓✓✓✓✓✓·`  — “<think> First, I need to answer each question on its own line, but the instruction says "Answer each question on its own line, as briefly as possible — just the answer, no explanation." So I should provide the answer for each question directly. Let's go through each: 1. What is 17 + 25? That's 42. 2”
- **mlx-swift Qwen3-0.6B (4-bit)** (m4max-mlx-qwen3-0.6b): `✓✓✓✓✓✓··`  — “<think> Okay, let's tackle each question one by one. Starting with question 1: "What is 17 + 25?" Well, addition is straightforward. 17 plus 25 is 42. So the answer is 42. Next, question 2: What is the capital of Japan? I remember that Japan's capital is Tokyo. So the answer is Tokyo. For question 3”
- **mlx-swift Qwen3-4B (4-bit)** (m4max-mlx-qwen3-4b): `✓✓✓✓✓✓✓·`  — “<think> Okay, let's tackle these questions one by one. First, the user wants each answer on its own line, brief, no explanations. So I need to make sure each answer is straightforward. 1. What is 17 + 25? That's a simple addition. 17 plus 25. Let me calculate: 17 + 20 is 37, plus 5 is 42. So 42. 2. ”
