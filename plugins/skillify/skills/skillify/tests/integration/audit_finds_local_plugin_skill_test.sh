#!/usr/bin/env bash
# Integration test: audit_duplicates.sh detects collisions inside a plugin
# marketplace source tree (where skills live at <repo>/skills/<name>/, not
# under .claude/skills/), and honors the SKILLIFY_AUDIT_EXTRA_ROOTS override.
set -euo pipefail

skill_root="$(cd "$(dirname "$0")/../.." && pwd)"
audit="$skill_root/scripts/audit_duplicates.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Build a synthetic marketplace layout:
#   $work/repo/.claude-plugin/marketplace.json
#   $work/repo/skills/foo/SKILL.md
make_marketplace() {
  local repo="$work/repo"
  rm -rf "$repo"
  mkdir -p "$repo/.claude-plugin" "$repo/skills/foo"
  cat > "$repo/.claude-plugin/marketplace.json" <<'JSON'
{ "name": "synthetic", "plugins": [] }
JSON
  cat > "$repo/skills/foo/SKILL.md" <<'MD'
---
name: foo
description: Use when running skillify's audit-detects-local-plugin-skill integration test.
---
MD
  echo "$repo"
}

# (1) Auto-detect: with CWD inside the marketplace, auditing "foo" must collide.
repo="$(make_marketplace)"
(
  cd "$repo"
  if "$audit" "foo" >/dev/null 2>&1; then
    echo "expected auto-detected marketplace skill 'foo' to collide" >&2
    exit 1
  fi
)

# (2) Auto-detect via subdirectory: walking up should find .claude-plugin/.
(
  cd "$repo/skills"
  if "$audit" "foo" >/dev/null 2>&1; then
    echo "expected upward-walk to find marketplace from a subdirectory" >&2
    exit 1
  fi
)

# (3) Codex plugin marker also enables auto-detection.
rm -rf "$repo/.claude-plugin"
mkdir -p "$repo/.codex-plugin"
cat > "$repo/.codex-plugin/plugin.json" <<'JSON'
{ "name": "synthetic", "skills": "./skills/" }
JSON
(
  cd "$repo"
  if "$audit" "foo" >/dev/null 2>&1; then
    echo "expected .codex-plugin marker to expose marketplace skill 'foo'" >&2
    exit 1
  fi
)

# (4) No marketplace marker: same fixture relocated outside the marketplace
# layout (no .claude-plugin/ in the ancestry, CWD also outside) means audit
# does NOT detect the collision via the auto-detection path.
plain_dir="$work/plain"
mkdir -p "$plain_dir/skills/foo"
cp "$repo/skills/foo/SKILL.md" "$plain_dir/skills/foo/SKILL.md"
(
  cd "$work"
  if ! "$audit" "foo" >/dev/null 2>&1; then
    echo "expected no collision when CWD is outside any marketplace and no extra roots are set" >&2
    exit 1
  fi
)

# (5) Explicit override via SKILLIFY_AUDIT_EXTRA_ROOTS catches the collision
# even without a marketplace marker.
(
  cd "$work"
  if SKILLIFY_AUDIT_EXTRA_ROOTS="$plain_dir/skills" "$audit" "foo" >/dev/null 2>&1; then
    echo "expected SKILLIFY_AUDIT_EXTRA_ROOTS to surface the collision" >&2
    exit 1
  fi
)

# (6) Multiple roots in the env var, only one of which holds the collision.
empty_root="$work/empty"
mkdir -p "$empty_root"
(
  cd "$work"
  if SKILLIFY_AUDIT_EXTRA_ROOTS="$empty_root:$plain_dir/skills" "$audit" "foo" >/dev/null 2>&1; then
    echo "expected colon-separated env var to be parsed and the populated root to surface the collision" >&2
    exit 1
  fi
)

echo "audit_finds_local_plugin_skill_test ok"
