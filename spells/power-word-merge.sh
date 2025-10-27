#!/bin/bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${DIR}/power-word-lib.sh"

usage() {
  cat <<'USAGE'
Usage:
  powerword merge --pdf-dir DIR --csv PATH --tmp-dir DIR --out-dir DIR
                  [--dpi 150] [--resize 1000x1000]
USAGE
}

DPI=150
VENV=""
TMP_DIR=tmp
MERGE_PY=merge.py
OUT_DIR=outputs

[[ "${1:-}" == "merge" ]] && shift || true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pdf-dir) PDF_DIR="${2:-}"; shift 2;;
    --csv)     CSV_IN="${2:-}"; shift 2;;
    --tmp-dir) TMP_DIR="${2:-}"; shift 2;;
    --out-dir) OUT_DIR="${2:-}"; shift 2;;
    --dpi)     DPI="${2:-}"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1"; usage; exit 1;;
  esac
done

require_cmd magick
require_cmd python3

[[ -n "${PDF_DIR:-}" ]] || die "--pdf-dir is required"
[[ -n "${CSV_IN:-}"  ]] || die "--csv is required"

mkdir -p "${TMP_DIR}" "${OUT_DIR}"
jpg_dir="${TMP_DIR}/jpg"
mkdir -p "${jpg_dir}"

trap 'cleanup_tmp "${TMP_DIR}"' ERR INT TERM

echo "[merge] Render PDFs to JPG (original PDFs remain untouched)"
pdf2jpg "${PDF_DIR}" "${jpg_dir}" "${DPI}"

echo "[merge] Group pages from CSV and create merged PDFs"
merge "${MERGE_PY}" "${CSV_IN}" "${jpg_dir}" "${OUT_DIR}" "${VENV}"

echo "[merge] Cleanup tmp"
cleanup "${TMP_DIR}"

echo "[merge] Done. Output PDFs at: ${OUT_DIR}"