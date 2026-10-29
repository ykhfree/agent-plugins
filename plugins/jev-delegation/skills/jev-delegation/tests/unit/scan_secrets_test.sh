#!/usr/bin/env bash
# Unit test: scan_secrets.py reports secret-like content as path:line: pattern,
# never prints the value, and exits 0 (clean) / 1 (hits) / 2 (bad input).
# Secret-like values are built at run time, so the repository holds none.
set -euo pipefail

skill_root="$(cd "$(dirname "$0")/../.." && pwd)"
scan="$skill_root/scripts/scan_secrets.py"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cd "$work"

# run <expected-exit> <args...>: stores stdout in $out, fails on a wrong exit code.
run() {
  local want="$1" got=0
  shift
  out="$("$scan" "$@" 2>/dev/null)" || got=$?
  if [[ "$got" != "$want" ]]; then
    echo "expected exit $want, got $got for: $*" >&2
    exit 1
  fi
}
has() {
  [[ "$out" == *"$1"* ]] || { echo "missing '$1' in: $out" >&2; exit 1; }
}

fill="$(printf 'A%.0s' {1..40})"   # 40 letters
gh_token="ghp_${fill:0:36}"
aws_key="AKIA${fill:0:16}"
pem_header="-----BEGIN OPENSSH PRIV""ATE KEY-----"

# 1) happy path: code that reads secrets from the environment is clean.
printf 'import os\nTOKEN = os.environ["TOKEN"]\ntoken = request.headers.get("x")\nTIMEOUT = 30\n' > clean.py
run 0 clean.py
[[ -z "$out" ]] || { echo "clean file must print nothing: $out" >&2; exit 1; }

# 2) hits: each pattern is named with its line, and the value never appears.
printf 'line one\nkey = "%s"\n%s\nid = %s\n' "$gh_token" "$pem_header" "$aws_key" > leak.txt
run 1 leak.txt
has "leak.txt:2: github-token"
has "leak.txt:3: private-key"
has "leak.txt:4: aws-access-key-id"
[[ "$out" != *"$gh_token"* && "$out" != *"$aws_key"* ]] || { echo "value printed: $out" >&2; exit 1; }

# 3) boundary: an assignment value of 7 characters passes; 8 characters is a hit.
printf 'DB_PASSWORD=abc1234\n' > short.env
run 0 short.env
printf 'DB_PASSWORD=abc12345\n' > long.env
run 1 long.env
has "long.env:1: secret-assignment"

# 4) boundary: a directory walk scans hidden files and hidden directories (jev search sends
#    .github/ from a git work tree), skips .git, and lists binaries as unscanned.
mkdir -p tree/.git tree/.github tree/sub
printf 'API_KEY=%s\n' "${fill:0:12}" > tree/.env
printf 'deploy_token: %s\n' "${fill:0:12}" > tree/.github/ci.yml
printf 'API_KEY=%s\n' "${fill:0:12}" > tree/.git/config
printf '\x89PNG\r\n\x1a\n\x00\x00' > tree/sub/shot.png
printf 'hello\n' > tree/sub/readme.md
run 1 tree
has "tree/.env:1: secret-assignment"
has "tree/.github/ci.yml:1: secret-assignment"
has "tree/sub/shot.png: unscanned (binary)"
[[ "$out" != *".git/config"* ]] || { echo ".git must be skipped: $out" >&2; exit 1; }
rm tree/.env tree/.github/ci.yml
run 0 tree
has "unscanned (binary)"

# 5) stdin with "-".
out="$(printf 'sk-ant-%s\n' "$fill" | "$scan" - || true)"
has "<stdin>:1: anthropic-api-key"
[[ "$out" != *"openai-api-key"* ]] || { echo "sk-ant- must not count as an OpenAI key: $out" >&2; exit 1; }

# 6) hits: token formats and assignment values that the first version missed.
dollar_pw='Fake$Passw0rd123'
{
  printf 'DB_PASSWORD=%s\n' "$dollar_pw"
  printf 'DATABASE_URL=postgres://admin:%s@db.example.com:5432/app\n' "${fill:0:12}"
  printf 'GITLAB=glpat-%s\n' "${fill:0:20}"
  printf 'STRIPE=sk_live_%s\n' "${fill:0:24}"
  printf 'HF=hf_%s\n' "${fill:0:34}"
  printf 'NPM=npm_%s\n' "${fill:0:36}"
  printf 'Authorization: Bearer %s\n' "${fill:0:32}"
} > formats.txt
run 1 formats.txt
has "formats.txt:1: secret-assignment"
has "formats.txt:2: url-credentials"
has "formats.txt:3: gitlab-token"
has "formats.txt:4: stripe-key"
has "formats.txt:5: huggingface-token"
has "formats.txt:6: npm-token"
has "formats.txt:7: bearer-token"
[[ "$out" != *"$dollar_pw"* && "$out" != *"$fill"* ]] || { echo "value printed: $out" >&2; exit 1; }

# 7) boundary: variable references, URLs without a password, short bearer values, and prose stay clean.
{
  printf 'TOKEN=$GITHUB_TOKEN\n'
  printf 'password: "${{ secrets.DB_PASSWORD }}"\n'
  printf 'DATABASE_URL=postgres://admin:${DB_PASSWORD}@db.example.com/app\n'
  printf 'clone git@github.com:owner/repo.git or ssh://git@host:22/repo\n'
  printf 'Authorization: Bearer short\n'
  printf 'password_hint = "see the team vault"\n'
  printf '"    fresh.token = freshToken\\n"\n'
} > refs.txt
run 0 refs.txt

# 8) failure: a missing path or no arguments exits 2 with no stdout.
run 2 no-such-file.txt
[[ -z "$out" ]] || { echo "bad input must print nothing on stdout" >&2; exit 1; }
run 2

echo "scan_secrets_test: ok"
