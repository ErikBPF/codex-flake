default:
    @just --list

check:
    nix flake check

fmt:
    nix fmt

fmt-check:
    alejandra --check .
