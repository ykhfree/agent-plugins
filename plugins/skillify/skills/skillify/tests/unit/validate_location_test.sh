#!/usr/bin/env bash
# Unit test: validate.sh accepts user, project, and plugin-cache paths for
# Claude Code and Codex, and rejects anything else.
#
# Constraint: validate.sh also enforces `name == basename(dir)`, so every
# candidate location must end in `/valid-skill` (the fixture's frontmatter
# name). Uniqueness across concurrent runs is provided by intermediate
# path segments, not by the leaf basename.
set -euo pipefail

skill_root="$(cd "$(dirname "$0")/../.." && pwd)"
validate="$skill_root/scripts/validate.sh"
fixture="$skill_root/tests/fixtures/valid-skill"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# (1) Plugin install cache: <anywhere>/.claude/plugins/cache/<m>/<p>/<v>/skills/<name>
cache_target="$work/.claude/plugins/cache/some-marketplace/some-plugin/0.1.0/skills/valid-skill"
mkdir -p "$(dirname "$cache_target")"
cp -R "$fixture" "$cache_target"
if ! "$validate" "$cache_target" >/dev/null 2>&1; then
  echo "expected plugin cache path to pass location gate: $cache_target" >&2
  exit 1
fi

# (2) Repo-local skills tree: <anywhere>/.claude/skills/<name>
repo_target="$work/some-repo/.claude/skills/valid-skill"
mkdir -p "$(dirname "$repo_target")"
cp -R "$fixture" "$repo_target"
if ! "$validate" "$repo_target" >/dev/null 2>&1; then
  echo "expected repo-local .claude/skills path to pass location gate: $repo_target" >&2
  exit 1
fi

# (3) Home skills tree: $HOME/.claude/skills/<unique-parent>/valid-skill.
# Inject a fake HOME under $work so the `"$HOME/.claude/skills/"*` prefix
# pattern is exercised without touching the real $HOME (sandbox-safe and
# matches the "no $HOME pollution" invariant the rest of the suite enforces).
fake_home="$work/fake-home"
home_parent="$fake_home/.claude/skills/__skillify_loc_test_$$"
home_target="$home_parent/valid-skill"
mkdir -p "$home_parent"
cp -R "$fixture" "$home_target"
if ! HOME="$fake_home" "$validate" "$home_target" >/dev/null 2>&1; then
  echo "expected home .claude/skills path to pass location gate: $home_target" >&2
  exit 1
fi

# (4) Codex plugin install cache.
codex_cache_target="$work/.codex/plugins/cache/some-marketplace/some-plugin/0.1.0/skills/valid-skill"
mkdir -p "$(dirname "$codex_cache_target")"
cp -R "$fixture" "$codex_cache_target"
if ! "$validate" "$codex_cache_target" >/dev/null 2>&1; then
  echo "expected Codex plugin cache path to pass location gate: $codex_cache_target" >&2
  exit 1
fi

# (5) Codex project skills trees.
for codex_project_dir in .agents .codex; do
  codex_repo_target="$work/some-repo/$codex_project_dir/skills/valid-skill"
  mkdir -p "$(dirname "$codex_repo_target")"
  cp -R "$fixture" "$codex_repo_target"
  if ! "$validate" "$codex_repo_target" >/dev/null 2>&1; then
    echo "expected project $codex_project_dir/skills path to pass location gate: $codex_repo_target" >&2
    exit 1
  fi
done

# (6) Codex user skills trees.
for codex_home_dir in .agents .codex; do
  codex_home_target="$fake_home/$codex_home_dir/skills/valid-skill"
  mkdir -p "$(dirname "$codex_home_target")"
  cp -R "$fixture" "$codex_home_target"
  if ! HOME="$fake_home" "$validate" "$codex_home_target" >/dev/null 2>&1; then
    echo "expected home $codex_home_dir/skills path to pass location gate: $codex_home_target" >&2
    exit 1
  fi
done

# (7) Unrelated path must fail. Path lacks all accepted substrings.
bad_target="$work/not-under-claude/skills-but-fake/valid-skill"
mkdir -p "$(dirname "$bad_target")"
cp -R "$fixture" "$bad_target"
if "$validate" "$bad_target" >/dev/null 2>&1; then
  echo "expected non-recognized path to fail location gate: $bad_target" >&2
  exit 1
fi

echo "validate_location_test ok"
