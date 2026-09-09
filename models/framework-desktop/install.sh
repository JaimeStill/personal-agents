#!/bin/bash
# Symlinks this directory's models.ini into the location the llama-router
# systemd unit reads it from. Re-run any time after pulling changes to this
# repo; safe to run repeatedly.
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
target_dir="/etc/llama-router"

sudo mkdir -p "$target_dir"
sudo ln -sfn "$repo_dir/models.ini" "$target_dir/models.ini"

echo "Linked $repo_dir/models.ini -> $target_dir/models.ini"
echo "Run restart-router.sh to apply the change."
