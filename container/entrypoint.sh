#!/bin/bash

set -e
sudo chown -R anvil:anvil /workspace/Anvil-Experiments/out 2>/dev/null || true
exec "$@"

