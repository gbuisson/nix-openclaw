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

# === MATRIX EXTENSION SUPPORT ===
# Copy matrix-sdk-crypto native binary if provided (needed because pnpm postinstall is skipped)
if [ -n "${MATRIX_CRYPTO_LIB_SRC:-}" ] && [ -n "${MATRIX_CRYPTO_LIB_NAME:-}" ]; then
  # Find the actual pnpm path for matrix-sdk-crypto-nodejs
  CRYPTO_DIR="$(find node_modules/.pnpm -type d -name "matrix-sdk-crypto-nodejs" | grep "@matrix-org" | head -n 1)"
  if [ -n "$CRYPTO_DIR" ]; then
    echo "Installing matrix-sdk-crypto native binary to: $CRYPTO_DIR/$MATRIX_CRYPTO_LIB_NAME"
    cp "$MATRIX_CRYPTO_LIB_SRC" "$CRYPTO_DIR/$MATRIX_CRYPTO_LIB_NAME"
    chmod 755 "$CRYPTO_DIR/$MATRIX_CRYPTO_LIB_NAME"
  else
    echo "WARNING: matrix-sdk-crypto-nodejs directory not found in node_modules/.pnpm"
  fi
fi
# === END MATRIX EXTENSION SUPPORT ===

# node-llama-cpp postinstall attempts to download/compile llama.cpp (network blocked in Nix).
NODE_LLAMA_CPP_SKIP_DOWNLOAD=1 pnpm rebuild
bash -e -c ". \"$STDENV_SETUP\"; patchShebangs node_modules/.bin"
pnpm build
pnpm ui:build
CI=true pnpm prune --prod
rm -rf node_modules/.pnpm/node_modules
