#!/usr/bin/env bash
fake_home="$(mktemp -d)"
HOME="$fake_home" some-validate "$fake_home/.claude/skills/x"
