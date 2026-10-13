#!/usr/bin/env bash
# old: target="$HOME/.claude/skills/legacy" — kept here to document migration
tmp_root="$(mktemp -d)"
mkdir -p "$tmp_root/.claude/skills/legacy"
