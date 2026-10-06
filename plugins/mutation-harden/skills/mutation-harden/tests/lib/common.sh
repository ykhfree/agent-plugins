# Shared helpers for mutation-harden tests. Source it after setting skill_root.
set -euo pipefail

mh="$skill_root/scripts/mh.py"
fixtures="$skill_root/tests/fixtures"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# expect <exit-code> <command...>: runs the command, keeps stdout in $out, fails on another exit code.
expect() {
  local want="$1" got=0
  shift
  out="$("$@" 2>"$work/stderr")" || got=$?
  if [[ "$got" != "$want" ]]; then
    echo "expected exit $want, got $got: $*" >&2
    cat "$work/stderr" >&2
    echo "stdout: $out" >&2
    exit 1
  fi
}

# check <python expression over d, the JSON in $out>
check() {
  if ! printf '%s' "$out" | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if ($1) else 1)"; then
    echo "assertion failed: $1" >&2
    echo "output: $out" >&2
    exit 1
  fi
}

# new_repo <dir>: git repo with a local identity, so it works under an isolated HOME.
new_repo() {
  git init -q "$1"
  git -C "$1" config user.email test@example.com
  git -C "$1" config user.name test
}

commit_all() {
  git -C "$1" add -A
  git -C "$1" commit -qm "$2"
}
