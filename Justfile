default:
    @just --list

check:
    nix flake check

build:
    nix build .#codex --print-build-logs

update-check:
    ./scripts/update-codex.sh --check

update:
    ./scripts/update-codex.sh

update-to VERSION:
    ./scripts/update-codex.sh --version {{VERSION}}

fmt:
    nix fmt -- .

fmt-check:
    alejandra --check .
