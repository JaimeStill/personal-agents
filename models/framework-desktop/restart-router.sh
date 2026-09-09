#!/bin/bash
# Restarts the llama-router service and shows its status. Whether this is
# actually necessary after editing models-preset.ini (versus just
# unloading/reloading the affected model through /llama) hasn't been
# confirmed — use this when in doubt, or after changing [*] defaults that
# apply to already-loaded models.
set -euo pipefail

sudo systemctl restart llama-router
sudo systemctl status llama-router --no-pager
