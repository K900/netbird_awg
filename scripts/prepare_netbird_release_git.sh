#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/version_vars.sh"

WORKDIR="${WORKDIR:-$ROOT_DIR/workdir}"
NETBIRD_DIR="${NETBIRD_DIR:-$WORKDIR/repos/netbird}"

if [[ ! -d "$NETBIRD_DIR/.git" ]]; then
  echo "[error] netbird git repo not found: $NETBIRD_DIR"
  exit 1
fi

pushd "$NETBIRD_DIR" >/dev/null

git config user.name "${GIT_AUTHOR_NAME:-github-actions[bot]}"
git config user.email "${GIT_AUTHOR_EMAIL:-41898282+github-actions[bot]@users.noreply.github.com}"
git config commit.gpgsign false
git config tag.gpgsign false

if ! git diff --quiet || ! git diff --cached --quiet || [[ -n "$(git ls-files --others --exclude-standard)" ]]; then
  git add -A
  git commit -m "release: ${NETBIRD_RELEASE_TAG}"
fi

if git rev-parse -q --verify "refs/tags/${NETBIRD_RELEASE_TAG}" >/dev/null; then
  git tag -d "${NETBIRD_RELEASE_TAG}"
fi
git tag -a "${NETBIRD_RELEASE_TAG}" -m "${NETBIRD_RELEASE_TAG}"

if [[ -n "${GITHUB_SERVER_URL:-}" && -n "${GITHUB_REPOSITORY:-}" ]]; then
  git remote set-url origin "${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}.git"
fi

echo "[ok] prepared git state for release tag ${NETBIRD_RELEASE_TAG}"

git --no-pager log --oneline -n 2

git --no-pager tag --list "${NETBIRD_RELEASE_TAG}"

popd >/dev/null
