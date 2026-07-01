#!/usr/bin/env bash
set -euo pipefail

readonly UPSTREAM_REPO="openai/codex"
readonly UPSTREAM_API="https://api.github.com/repos/${UPSTREAM_REPO}/releases/latest"

log() { printf '[codex-update] %s\n' "$*" >&2; }
die() { printf '[codex-update] ERROR: %s\n' "$*" >&2; exit 2; }

usage() {
  cat <<'USAGE'
Usage: scripts/update-codex.sh [OPTIONS]

Options:
  --check          Exit 1 if an upstream Codex release is newer
  --version VER    Update to a specific version, e.g. 0.142.4
  --help           Show this help
USAGE
}

need() {
  command -v "$1" >/dev/null 2>&1 || die "$1 is required"
}

current_version() {
  nix eval --raw .#codex.version
}

latest_release_json() {
  if [ -n "${GH_TOKEN:-}" ]; then
    gh api "repos/${UPSTREAM_REPO}/releases/latest"
  elif command -v gh >/dev/null 2>&1; then
    gh api "repos/${UPSTREAM_REPO}/releases/latest" 2>/dev/null || curl -fsSL "$UPSTREAM_API"
  else
    curl -fsSL "$UPSTREAM_API"
  fi
}

latest_version() {
  latest_release_json | jq -r '.tag_name' | sed -n 's/^rust-v//p'
}

release_url() {
  latest_release_json | jq -r '.html_url'
}

restore_on_failure() {
  local status=$?
  if [ "$status" -ne 0 ] && [ -n "${TMPDIR_UPDATE:-}" ] && [ -d "$TMPDIR_UPDATE" ]; then
    cp "$TMPDIR_UPDATE/package.nix" packages/codex/package.nix
  fi
  exit "$status"
}

main() {
  local check_only=false
  local target=""

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --check) check_only=true; shift ;;
      --version) target="$2"; shift 2 ;;
      --help) usage; exit 0 ;;
      *) die "unknown option: $1" ;;
    esac
  done

  [ -f flake.nix ] && [ -f packages/codex/package.nix ] || die "run from codex-flake root"
  need nix
  need nix-update
  need jq
  need cp

  local current latest url
  current="$(current_version)"
  if [ -n "$target" ]; then
    latest="$target"
    url="https://github.com/${UPSTREAM_REPO}/releases/tag/rust-v${target}"
  else
    latest="$(latest_version)"
    url="$(release_url)"
  fi

  [[ "$latest" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "latest version is malformed: $latest"

  log "current: $current"
  log "latest:  $latest"
  log "release: $url"

  if [ "$current" = "$latest" ]; then
    log "already up to date"
    exit 0
  fi

  if [ "$check_only" = true ]; then
    log "update available: $current -> $latest"
    exit 1
  fi

  TMPDIR_UPDATE="$(mktemp -d)"
  export TMPDIR_UPDATE
  trap restore_on_failure EXIT
  cp packages/codex/package.nix "$TMPDIR_UPDATE/package.nix"

  nix-update codex --version "$latest" --flake --override-filename packages/codex/package.nix
  nix build .#codex --no-link --print-build-logs
  nix run .#codex -- --version | grep -F "$latest"

  trap - EXIT
  rm -rf "$TMPDIR_UPDATE"
  git diff --stat packages/codex/package.nix 2>/dev/null || true
}

main "$@"
