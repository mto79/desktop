#!/usr/bin/env bash

# The small model desktop-voice asks when a spoken command is not on its list. Optional
# twice over: without Ollama, or without the model, the list still works exactly as it
# did and only free phrasing is lost -- so neither is a reason to stop the install.
# Ollama itself is not installed from here; where it is, the model is fetched.
if command -v ollama >/dev/null 2>&1; then
  ollama pull qwen2.5:3b || echo "desktop-voice: the model was not fetched; commands work from the list only" >&2
else
  echo "desktop-voice: no ollama here; commands work from the list only" >&2
fi
