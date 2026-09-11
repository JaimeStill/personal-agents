#!/bin/bash
# Symlinks every outpost command in bin/ into ~/.local/bin, so `outpost` and
# its subcommands are callable from anywhere. Re-run any time after pulling a
# change that adds or renames a command; safe to run repeatedly.
set -euo pipefail

self="$(readlink -f -- "${BASH_SOURCE[0]}")"
bin_dir="$(cd -- "$(dirname -- "$self")/bin" && pwd)"
target_dir="$HOME/.local/bin"

mkdir -p "$target_dir"

for script in "$bin_dir"/outpost*; do
  name="${script##*/}"
  ln -sfn "$script" "$target_dir/$name"
  echo "Linked $target_dir/$name -> $script"
done

case ":$PATH:" in
  *":$target_dir:"*) ;;
  *) echo "Note: $target_dir isn't on your PATH — add it to use these commands directly." ;;
esac
