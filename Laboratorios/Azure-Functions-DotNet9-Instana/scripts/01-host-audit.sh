#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
OUT="$LAB_ROOT/evidencias/phase00"
mkdir -p "$OUT"
{
  echo '$ uname -a'; uname -a
  echo '$ cat /etc/os-release'; cat /etc/os-release
  echo '$ uname -m'; uname -m
  echo '$ df -h'; df -h
  echo '$ free -h'; free -h
  echo '$ docker version'; docker version
  echo '$ docker info'; docker info
  echo '$ docker compose version'; docker compose version
  echo '$ git --version'; git --version
} >"$OUT/host-audit.txt" 2>&1
echo "$OUT/host-audit.txt"

