#!/bin/sh
set -e

if [ -z "${GATEWAY_PREBUILD_SH:-}" ]; then
  echo "GATEWAY_PREBUILD_SH is not set" >&2
  exit 1
fi
. "$GATEWAY_PREBUILD_SH"
if [ -z "${STDENV_SETUP:-}" ]; then
  echo "STDENV_SETUP is not set" >&2
  exit 1
fi
if [ ! -f "$STDENV_SETUP" ]; then
  echo "STDENV_SETUP not found: $STDENV_SETUP" >&2
  exit 1
fi

store_path_file="${PNPM_STORE_PATH_FILE:-.pnpm-store-path}"
if [ ! -f "$store_path_file" ]; then
  echo "pnpm store path file missing: $store_path_file" >&2
  exit 1
fi
store_path="$(cat "$store_path_file")"
export PNPM_STORE_DIR="$store_path"
export PNPM_STORE_PATH="$store_path"
export NPM_CONFIG_STORE_DIR="$store_path"
export NPM_CONFIG_STORE_PATH="$store_path"
export HOME="$(mktemp -d)"

pnpm install --offline --frozen-lockfile --ignore-scripts --store-dir "$store_path"
chmod -R u+w node_modules
rm -rf node_modules/.pnpm/sharp@*/node_modules/sharp/src/build
pnpm rebuild
bash -e -c ". \"$STDENV_SETUP\"; patchShebangs node_modules/.bin"
pnpm build
pnpm ui:build

# Copy matrix extension dependencies before pruning removes them
# The matrix extension is a workspace package but not a root prod dependency,
# so pnpm prune --prod will remove its dependencies
if [ -d extensions/matrix ]; then
  echo "Preserving matrix extension dependencies..."
  mkdir -p .matrix-deps
  # Copy the matrix extension's dependencies from node_modules
  # Handle scoped packages (@scope/pkg) by preserving directory structure
  for dep in "@vector-im/matrix-bot-sdk" "@matrix-org/matrix-sdk-crypto-nodejs" "markdown-it" "music-metadata" "zod"; do
    dep_dir="node_modules/$dep"
    if [ -d "$dep_dir" ] || [ -L "$dep_dir" ]; then
      # For scoped packages, create the scope directory first
      case "$dep" in
        @*/*)
          scope_dir=$(dirname "$dep")
          mkdir -p ".matrix-deps/$scope_dir"
          ;;
      esac
      # Resolve symlink and copy actual files, preserving path
      cp -rL "$dep_dir" ".matrix-deps/$dep" 2>/dev/null || true
    fi
  done
fi

CI=true pnpm prune --prod
rm -rf node_modules/.pnpm/node_modules

# Restore matrix extension dependencies after prune
if [ -d .matrix-deps ] && [ -d extensions/matrix ]; then
  echo "Restoring matrix extension dependencies..."
  mkdir -p extensions/matrix/node_modules
  cp -r .matrix-deps/* extensions/matrix/node_modules/ 2>/dev/null || true
  rm -rf .matrix-deps
fi
