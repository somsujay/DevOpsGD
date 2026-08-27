#!/usr/bin/env bash
set -euo pipefail

# Creates branch rulesets for the repository.
# Protects: develop, release (and release/*), main
# Usage: bash scripts/setup_rulesets.sh [<owner/repo>]
# Example: bash scripts/setup_rulesets.sh somsujay/DevOpsGD
#
# Prerequisites: gh auth login (with repo admin access)

REPO="${1:-}"
if [[ -z "$REPO" ]]; then
  REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)
  if [[ -z "$REPO" ]]; then
    echo "ERROR: Repository required. Usage: bash scripts/setup_rulesets.sh <owner/repo>"
    exit 1
  fi
  echo "   Auto-detected repo: $REPO"
fi

echo "==> Creating branch ruleset: Protect develop"
gh api "repos/$REPO/rulesets" --method POST --input - <<'EOF'
{
  "name": "Protect develop",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["refs/heads/develop"],
      "exclude": []
    }
  },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    { "type": "pull_request" },
    { "type": "required_status_checks", "parameters": { "required_status_checks": [{ "context": "Enforce Branching Rules" }], "strict_required_status_checks_policy": true } }
  ]
}
EOF
echo "   Done: develop (only feature/* -> develop allowed)"

echo ""
echo "==> Creating branch ruleset: Protect release branches"
gh api "repos/$REPO/rulesets" --method POST --input - <<'EOF'
{
  "name": "Protect release branches",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["refs/heads/release", "refs/heads/release/*"],
      "exclude": []
    }
  },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    { "type": "pull_request" },
    { "type": "required_status_checks", "parameters": { "required_status_checks": [{ "context": "Enforce Branching Rules" }], "strict_required_status_checks_policy": true } }
  ]
}
EOF
echo "   Done: release & release/* (only develop -> release allowed)"

echo ""
echo "==> Creating branch ruleset: Protect main"
gh api "repos/$REPO/rulesets" --method POST --input - <<'EOF'
{
  "name": "Protect main",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["refs/heads/main"],
      "exclude": []
    }
  },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    { "type": "pull_request" },
    { "type": "required_status_checks", "parameters": { "required_status_checks": [{ "context": "Enforce Branching Rules" }], "strict_required_status_checks_policy": true } }
  ]
}
EOF
echo "   Done: main (only release/* or hotfix/* -> main allowed)"

echo ""
echo "==> All rulesets created successfully"
echo ""
echo "Branching flow enforced:"
echo "   feature/*  -> develop"
echo "   develop    -> release / release/*"
echo "   release/*  -> main"
echo "   hotfix/*   -> main"
echo ""
echo "Verify at: https://github.com/$REPO/settings/rules"
