#!/usr/bin/env bash
set -euo pipefail

LAB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UTC_NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

mkdir -p "$LAB_ROOT/evidencias"

