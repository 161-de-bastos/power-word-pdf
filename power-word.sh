#!/bin/bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "${1:-}" in
  segment) exec "${DIR}/spells/power-word-segment.sh" "$@" ;;
  merge)   exec "${DIR}/spells/power-word-merge.sh" "$@" ;;
  -h|--help|"")
    cat <<'USAGE'
Usage:
  powerword segment [args...]   # Preprocess + predict + CSV (cleans tmp)
  powerword merge   [args...]   # Group by CSV and merge into PDFs (cleans tmp)

Use 'powerword segment --help' or 'powerword merge --help' for details.
USAGE
    ;;
  *) echo "Unknown subcommand: $1" ; exit 1 ;;
esac
