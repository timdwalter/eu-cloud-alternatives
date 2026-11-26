# Shared helpers for deploy.sh / teardown.sh / push-images.sh. Sourced, not executed.
set -euo pipefail
export MSYS_NO_PATHCONV=1 # Git Bash on Windows: do not rewrite /paths in arguments

# pwd -W (Git Bash) gives C:/... paths that Windows binaries like terraform.exe understand
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && (pwd -W 2>/dev/null || pwd))"
PROVIDER="${1:?usage: $0 <provider>   (e.g. azure)}"
PROVIDER_FILE="$ROOT/scripts/providers/$PROVIDER.sh"
[[ -f "$PROVIDER_FILE" ]] || { echo "unknown provider: $PROVIDER" >&2; exit 1; }

NAMESPACE=textlib

tf_output() { terraform -chdir="$ROOT/terraform" output -raw "$1"; }

load_config() {
  local cfg="$ROOT/platform/config.local.env"
  [[ -f "$cfg" ]] || { echo "missing $cfg – copy it from config.local.env.example" >&2; exit 1; }
  set -a
  # shellcheck disable=SC1090,SC1091
  source "$ROOT/platform/versions.env"
  source "$cfg"
  set +a
  grep -q 'change-me' "$cfg" && { echo "replace every change-me in $cfg first" >&2; exit 1; }
  return 0
}

HELM_ARGS=() # providers may add flags
# shellcheck disable=SC1090
source "$PROVIDER_FILE"

log() { printf '\n==> %s\n' "$*"; }
