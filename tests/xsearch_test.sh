#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

mkdir -p "$TEMP_DIR/bin"
cat > "$TEMP_DIR/bin/grok" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$XR_TEST_CAPTURE"
EOF
chmod +x "$TEMP_DIR/bin/grok"

export PATH="$TEMP_DIR/bin:$PATH"
export XR_SCRATCH="$TEMP_DIR/scratch"
export XR_TEST_CAPTURE="$TEMP_DIR/arguments"

bash "$ROOT/x-research/scripts/xsearch.sh" "recent posts about testing"

grep -Fx -- "--cwd" "$XR_TEST_CAPTURE" >/dev/null
grep -Fx -- "$XR_SCRATCH" "$XR_TEST_CAPTURE" >/dev/null
grep -Fx -- "--no-subagents" "$XR_TEST_CAPTURE" >/dev/null
grep -F -- "Current date (UTC): $(date -u +%F)" "$XR_TEST_CAPTURE" >/dev/null
grep -F -- "recent posts about testing" "$XR_TEST_CAPTURE" >/dev/null

if XR_MAX_TURNS=invalid bash "$ROOT/x-research/scripts/xsearch.sh" "test" \
  >"$TEMP_DIR/stdout" 2>"$TEMP_DIR/stderr"; then
  echo "invalid XR_MAX_TURNS unexpectedly succeeded" >&2
  exit 1
fi
grep -F -- "XR_MAX_TURNS must be a positive integer." \
  "$TEMP_DIR/stderr" >/dev/null
