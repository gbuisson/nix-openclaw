#!/bin/sh
set -e

log_step() {
  if [ "${OPENCLAW_NIX_TIMINGS:-1}" != "1" ]; then
    "$@"
    return
  fi

  name="$1"
  shift

  start=$(date +%s)
  printf '>> [timing] %s...\n' "$name" >&2
  "$@"
  end=$(date +%s)
  printf '>> [timing] %s: %ss\n' "$name" "$((end - start))" >&2
}

check_no_broken_symlinks() {
  root="$1"
  if [ ! -d "$root" ]; then
    return 0
  fi

  broken_tmp="$(mktemp)"
  # Portable and faster than `find ... -exec test -e {} \;` on large trees.
  find "$root" -type l -print | while IFS= read -r link; do
    [ -e "$link" ] || printf '%s\n' "$link"
  done > "$broken_tmp"
  if [ -s "$broken_tmp" ]; then
    echo "dangling symlinks found under $root" >&2
    cat "$broken_tmp" >&2
    rm -f "$broken_tmp"
    return 1
  fi
  rm -f "$broken_tmp"
}

mkdir -p "$out/lib/openclaw" "$out/bin"

# Build dir is ephemeral in Nix; moving avoids an expensive deep copy of node_modules.
log_step "move build outputs" mv dist node_modules package.json "$out/lib/openclaw/"
if [ -d extensions ]; then
  log_step "copy extensions" cp -r extensions "$out/lib/openclaw/"
fi

# Gateway plugin discovery looks under dist/extensions/*/openclaw.plugin.json.
# Upstream's build emits JS into dist/extensions but leaves manifests in extensions/.
if [ -d "$out/lib/openclaw/extensions" ] && [ -d "$out/lib/openclaw/dist/extensions" ]; then
  for manifest in "$out/lib/openclaw/extensions"/*/openclaw.plugin.json; do
    [ -f "$manifest" ] || continue
    name="$(basename "$(dirname "$manifest")")"
    dist_ext="$out/lib/openclaw/dist/extensions/$name"
    if [ -d "$dist_ext" ] && [ ! -f "$dist_ext/openclaw.plugin.json" ]; then
      cp "$manifest" "$dist_ext/openclaw.plugin.json"
    fi
  done
fi

if [ -d docs/reference/templates ]; then
  mkdir -p "$out/lib/openclaw/docs/reference"
  log_step "copy reference templates" cp -r docs/reference/templates "$out/lib/openclaw/docs/reference/"
fi

if [ -z "${STDENV_SETUP:-}" ]; then
  echo "STDENV_SETUP is not set" >&2
  exit 1
fi
if [ ! -f "$STDENV_SETUP" ]; then
  echo "STDENV_SETUP not found: $STDENV_SETUP" >&2
  exit 1
fi

log_step "patchShebangs node_modules/.bin" bash -e -c '. "$STDENV_SETUP"; patchShebangs "$out/lib/openclaw/node_modules/.bin"'

# Work around missing dependency declaration in pi-coding-agent (strip-ansi).
# Ensure it is resolvable at runtime without changing upstream.
pi_pkg="$(find "$out/lib/openclaw/node_modules/.pnpm" -path "*/node_modules/@mariozechner/pi-coding-agent" -print | head -n 1)"
strip_ansi_src="$(find "$out/lib/openclaw/node_modules/.pnpm" -path "*/node_modules/strip-ansi" -print | head -n 1)"

if [ -n "$strip_ansi_src" ]; then
  if [ -n "$pi_pkg" ] && [ ! -e "$pi_pkg/node_modules/strip-ansi" ]; then
    mkdir -p "$pi_pkg/node_modules"
    ln -s "$strip_ansi_src" "$pi_pkg/node_modules/strip-ansi"
  fi

  if [ ! -e "$out/lib/openclaw/node_modules/strip-ansi" ]; then
    mkdir -p "$out/lib/openclaw/node_modules"
    ln -s "$strip_ansi_src" "$out/lib/openclaw/node_modules/strip-ansi"
  fi
fi

if [ -n "${PATCH_CLIPBOARD_SH:-}" ]; then
  "$PATCH_CLIPBOARD_SH" "$out/lib/openclaw" "$PATCH_CLIPBOARD_WRAPPER"
fi

# Work around missing combined-stream dependency for form-data in pnpm layout.
combined_stream_src="$(find "$out/lib/openclaw/node_modules/.pnpm" -path "*/combined-stream@*/node_modules/combined-stream" -print | head -n 1)"
form_data_pkgs="$(find "$out/lib/openclaw/node_modules/.pnpm" -path "*/node_modules/form-data" -print)"
if [ -n "$combined_stream_src" ]; then
  if [ ! -e "$out/lib/openclaw/node_modules/combined-stream" ]; then
    ln -s "$combined_stream_src" "$out/lib/openclaw/node_modules/combined-stream"
  fi
  if [ -n "$form_data_pkgs" ]; then
    for pkg in $form_data_pkgs; do
      if [ ! -e "$pkg/node_modules/combined-stream" ]; then
        mkdir -p "$pkg/node_modules"
        ln -s "$combined_stream_src" "$pkg/node_modules/combined-stream"
      fi
    done
  fi
fi

# Work around missing hasown dependency for form-data in pnpm layout.
hasown_src="$(find "$out/lib/openclaw/node_modules/.pnpm" -path "*/hasown@*/node_modules/hasown" -print | head -n 1)"
if [ -n "$hasown_src" ]; then
  if [ ! -e "$out/lib/openclaw/node_modules/hasown" ]; then
    ln -s "$hasown_src" "$out/lib/openclaw/node_modules/hasown"
  fi
  if [ -n "$form_data_pkgs" ]; then
    for pkg in $form_data_pkgs; do
      if [ ! -e "$pkg/node_modules/hasown" ]; then
        mkdir -p "$pkg/node_modules"
        ln -s "$hasown_src" "$pkg/node_modules/hasown"
      fi
    done
  fi
fi

# === MATRIX EXTENSION SUPPORT ===
# Link matrix extension dependencies to node_modules (pnpm hoists these
# under .pnpm but the matrix extension expects them at the top level).
matrix_ext="$out/lib/openclaw/extensions/matrix"
if [ -d "$matrix_ext" ]; then
  log_step "link matrix extension dependencies"

  # matrix-bot-sdk
  matrix_bot_sdk_src="$(find "$out/lib/openclaw/node_modules/.pnpm" -type d -name "matrix-bot-sdk" | grep "@vector-im" | head -n 1)"
  if [ -n "$matrix_bot_sdk_src" ]; then
    mkdir -p "$matrix_ext/node_modules/@vector-im" "$out/lib/openclaw/node_modules/@vector-im"
    ln -sfn "$matrix_bot_sdk_src" "$matrix_ext/node_modules/@vector-im/matrix-bot-sdk"
    ln -sfn "$matrix_bot_sdk_src" "$out/lib/openclaw/node_modules/@vector-im/matrix-bot-sdk"
  fi

  # matrix-sdk-crypto-nodejs
  matrix_crypto_src="$(find "$out/lib/openclaw/node_modules/.pnpm" -type d -name "matrix-sdk-crypto-nodejs" | grep "@matrix-org" | head -n 1)"
  if [ -n "$matrix_crypto_src" ]; then
    mkdir -p "$matrix_ext/node_modules/@matrix-org" "$out/lib/openclaw/node_modules/@matrix-org"
    ln -sfn "$matrix_crypto_src" "$matrix_ext/node_modules/@matrix-org/matrix-sdk-crypto-nodejs"
    ln -sfn "$matrix_crypto_src" "$out/lib/openclaw/node_modules/@matrix-org/matrix-sdk-crypto-nodejs"

    # Copy pre-fetched native binary if available
    if [ -n "$MATRIX_CRYPTO_LIB_SRC" ] && [ -n "$MATRIX_CRYPTO_LIB_NAME" ]; then
      native_dir="$matrix_crypto_src/node_modules/@aspect-build"
      if [ -d "$matrix_crypto_src" ]; then
        cp "$MATRIX_CRYPTO_LIB_SRC" "$matrix_crypto_src/$MATRIX_CRYPTO_LIB_NAME" 2>/dev/null || true
      fi
    fi
  fi

  # music-metadata (audio file handling)
  music_metadata_src="$(find "$out/lib/openclaw/node_modules/.pnpm" -type d -name "music-metadata" | head -n 1)"
  if [ -n "$music_metadata_src" ]; then
    ln -sfn "$music_metadata_src" "$matrix_ext/node_modules/music-metadata"
    ln -sfn "$music_metadata_src" "$out/lib/openclaw/node_modules/music-metadata"
  fi
fi
# === END MATRIX EXTENSION SUPPORT ===

log_step "validate node_modules symlinks" check_no_broken_symlinks "$out/lib/openclaw/node_modules"

bash -e -c '. "$STDENV_SETUP"; makeWrapper "$NODE_BIN" "$out/bin/openclaw" --add-flags "$out/lib/openclaw/dist/index.js" --set-default OPENCLAW_NIX_MODE "1"'
