#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: moltbot-reload [test|prod|both]

Re-render Moltbot config via Home Manager (no sudo) and restart gateway(s).

Defaults to: test
EOF
}

instance="${1:-test}"

case "$instance" in
  test) labels=("com.steipete.moltbot.gateway.nix-test") ;;
  prod) labels=("com.steipete.moltbot.gateway.nix") ;;
  both) labels=("com.steipete.moltbot.gateway.nix" "com.steipete.moltbot.gateway.nix-test") ;;
  -h|--help) usage; exit 0 ;;
  *) usage; exit 1 ;;
esac

if command -v hm-apply >/dev/null 2>&1; then
  hm-apply
elif [[ -n "${MOLTBOT_RELOAD_HM_CMD:-}" ]]; then
  eval "$MOLTBOT_RELOAD_HM_CMD"
else
  echo "[moltbot-reload] no Home Manager command available." >&2
  echo "[moltbot-reload] install hm-apply or set MOLTBOT_RELOAD_HM_CMD." >&2
  exit 1
fi

for label in "${labels[@]}"; do
  /bin/launchctl kickstart -k "gui/$UID/$label"
done
