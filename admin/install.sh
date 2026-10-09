#!/bin/bash
# Symlinks every outpost command in bin/ into ~/.local/bin, so `outpost` and
# its subcommands are callable from anywhere, and removes the links of commands
# that no longer exist. Re-run any time after pulling a change that adds,
# renames, or retires a command; safe to run repeatedly.
set -euo pipefail

self="$(readlink -f -- "${BASH_SOURCE[0]}")"
bin_dir="$(cd -- "$(dirname -- "$self")/bin" && pwd)"
target_dir="$HOME/.local/bin"

mkdir -p "$target_dir"

# A retired or renamed command leaves its old link dangling; remove only
# outpost links that point into this bin/ and no longer resolve.
for link in "$target_dir"/outpost*; do
  [ -L "$link" ] && [ ! -e "$link" ] || continue
  case "$(readlink -- "$link")" in
    "$bin_dir"/*)
      rm -- "$link"
      echo "Removed stale $link"
      ;;
  esac
done

for script in "$bin_dir"/outpost*; do
  name="${script##*/}"
  ln -sfn "$script" "$target_dir/$name"
  echo "Linked $target_dir/$name -> $script"
done

case ":$PATH:" in
  *":$target_dir:"*) ;;
  *) echo "Note: $target_dir isn't on your PATH — add it to use these commands directly." ;;
esac
