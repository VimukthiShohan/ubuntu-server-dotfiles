#!/usr/bin/env zsh

NVIM_DIR="$HOME/.config/nvim"
STABLE_DIR="$HOME/.config/nvim-stable"
NIGHTLY_DIR="$HOME/.config/nvim-nightly"

if [[ -d "$NIGHTLY_DIR" ]]; then
    # Currently using stable → switch to nightly
    mv "$NVIM_DIR" "$STABLE_DIR"
    mv "$NIGHTLY_DIR" "$NVIM_DIR"
    echo "Switched to nightly config"
elif [[ -d "$STABLE_DIR" ]]; then
    # Currently using nightly → switch to stable
    mv "$NVIM_DIR" "$NIGHTLY_DIR"
    mv "$STABLE_DIR" "$NVIM_DIR"
    echo "Switched to stable config"
else
    echo "Error: Neither $STABLE_DIR nor $NIGHTLY_DIR exists"
    exit 1
fi
