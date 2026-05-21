#!/bin/bash
# Build Local LLM Game – Love2D + bundled llama-server

winFileName="LocalLLMGame"
love_exe="C:\Program Files\LOVE\love.exe"
winrar="C:\Program Files\WinRAR\WinRAR.exe"

# ── Create .love file ─────────────────────────────────────────────────────────
echo "# Creating game.love ..."
rm -f game.love
"$winrar" a -afzip -r -ep1 "game.love" main.lua conf.lua config.lua lib llm ui

# ── Fuse into standalone exe ──────────────────────────────────────────────────
echo "# Building $winFileName.exe ..."
rm -rf build/win
mkdir -p "build/win/$winFileName"
cat "$love_exe" "game.love" > "build/win/$winFileName/$winFileName.exe"

# ── Copy Love2D runtime DLLs ──────────────────────────────────────────────────
for dll in SDL2.dll OpenAL32.dll love.dll lua51.dll mpg123.dll msvcp120.dll msvcr120.dll; do
    src="C:/Program Files/LOVE/$dll"
    [ -f "$src" ] && cp "$src" "build/win/$winFileName/"
done

# ── Bundle llama-server + model ───────────────────────────────────────────────
if [ ! -d "ollama" ]; then
    echo "ERROR: ollama/ folder not found – cannot build Steam zip without llama-server runtime"
    read -n 1 -s -r -p "Press any key to exit..."
    exit 1
fi
cp -r ollama "build/win/$winFileName/ollama"
[ -f "model.gguf" ]  && cp model.gguf     "build/win/$winFileName/"

echo "# Done! -> build/win/$winFileName/"

# ── Zip for Steam upload ──────────────────────────────────────────────────────
echo "# Zipping for Steam upload ..."
rm -f "build/${winFileName}.zip"
"$winrar" a -afzip -r -ep1 "build/${winFileName}.zip" "build/win/$winFileName/"

echo "# Steam zip -> build/${winFileName}.zip"

read -n 1 -s -r -p "Press any key to exit..."
