#!/usr/bin/env bash
set -euo pipefail
cd /workspace/f_application
export npm_config_cache=/workspace/.cache/npm
export XDG_CACHE_HOME=/workspace/.cache
npm ci --no-fund
npm run setup:local
npm run db:up
npm run db:deploy
npm run build
