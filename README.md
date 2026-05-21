# Deploy Local LLM

A Love2D game that runs a local LLM via a bundled `llama-server.exe` (llama.cpp). The LLM binary and model file are large and not included in this repository — follow the steps below to set them up.

---

## Prerequisites

- [Love2D](https://love2d.org/) (for running in dev mode) or a fused `.exe` build
- Windows (the server launcher uses `llama-server.exe`)

---

## Setup

### 1. Download the llama.cpp binaries

The `ollama/` folder must contain `llama-server.exe` and its companion DLLs.

1. Go to the [llama.cpp releases page](https://github.com/ggml-org/llama.cpp/releases/latest).
2. Download the Windows release archive that matches your hardware, for example:
   - `llama-<version>-bin-win-vulkan-x64.zip` — for GPUs with Vulkan support
   - `llama-<version>-bin-win-cpu-x64.zip` — CPU-only fallback
3. Extract the archive and copy its contents into the `ollama/` folder at the root of this repo so that `ollama/llama-server.exe` exists.

### 2. Download a GGUF model

The game expects a file named `model.gguf` placed at the root of the repo (next to `main.lua`).

1. Browse models on [Hugging Face](https://huggingface.co/models?library=gguf&sort=trending).
2. Download any GGUF-format model. A good starting point for low-end hardware is a **Q4_K_M** quantized model around 3–8 B parameters, for example:
   - [Llama-3.2-3B-Instruct-Q4_K_M.gguf](https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF)
   - [Qwen2.5-7B-Instruct-Q4_K_M.gguf](https://huggingface.co/Qwen/Qwen2.5-7B-Instruct-GGUF)
3. Rename the downloaded file to `model.gguf` and place it at the repo root.

You can change the model path, context size, port, and other settings in `config.lua`.

---

## Running (dev mode)

```
love .
```

The game will automatically launch `ollama/llama-server.exe` with the configured model on startup.

---

## Building a standalone `.exe`

Run `build.sh` (requires Git Bash or WSL, WinRAR, and Love2D installed):

```bash
bash build.sh
```

Output is placed in `build/win/LocalLLMGame/`. The `ollama/` folder and `model.gguf` are copied into the build automatically.
