#!/bin/bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${DIR}/power-word-lib.sh"

usage() {
  cat <<'USAGE'
Usage:
  powerword segment --pdf-dir DIR --tmp-dir DIR --out-csv PATH --model PATH
                    [--predict PATH] [--venv VENV]
                    [--dpi 150] [--resize 1000x1000]
                    [--ocr-lang spa+eng] [--ocr-filter PATH]
USAGE
}

TMP_DIR=tmp
OUT_CSV=results
PREDICT=predict.py
VENV=".venv"
DPI=150
RESIZE=1000x1000
OCR_LANG="spa+eng"
OCR_FILTER="pdf/utils/ocr_filter.awk"
MODEL="pdf/pagestream/tabme/model_weights/full"

PP_DPI=150
PP_RESIZE=1030x1030
PP_SHAVE=30x30
PP_GRAVITY=NorthWest

[[ "${1:-}" == "segment" ]] && shift || true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pdf-dir) PDF_DIR="${2:-}"; shift 2;;
    --tmp-dir) TMP_DIR="${2:-}"; shift 2;;
    --out-csv) OUT_CSV="${2:-}"; shift 2;;
    --model)   MODEL="${2:-}"; shift 2;;
    --predict) PREDICT="${2:-}"; shift 2;;
    --venv)    VENV="${2:-}"; shift 2;;
    --dpi)     DPI="${2:-}"; shift 2;;
    --resize)  RESIZE="${2:-}"; shift 2;;
    --ocr-lang) OCR_LANG="${2:-}"; shift 2;;
    --ocr-filter) OCR_FILTER="${2:-}"; shift 2;;
    --pp-dpi)      PP_DPI="${2:-}"; shift 2;;
    --pp-resize)   PP_RESIZE="${2:-}"; shift 2;;
    --pp-shave)    PP_SHAVE="${2:-}"; shift 2;;
    --pp-gravity)  PP_GRAVITY="${2:-}"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1"; usage; exit 1;;
  esac
done

require_cmd magick
require_cmd python3

[[ -n "${PDF_DIR:-}" ]] || die "--pdf-dir is required"

mkdir -p "${TMP_DIR}"
work_dir="${TMP_DIR}/work"
jpg_dir="${TMP_DIR}/jpg"
mkdir -p "${work_dir}" "${jpg_dir}"

trap 'cleanup_tmp "${TMP_DIR}"' ERR INT TERM

echo "[segment] Copy PDFs to tmp/work"
rsync -a --include='*/' --include='*.pdf' --exclude='*' "${PDF_DIR}/" "${work_dir}/"

echo "[segment] Preprocess PDFs in-place"
preprocess "${work_dir}" "${PP_DPI}" "${PP_RESIZE}" "${PP_SHAVE}" "${PP_GRAVITY}"

echo "[segment] Render PDFs to JPG"
pdf2jpg "${work_dir}" "${jpg_dir}" "${DPI}" "${RESIZE}"

echo "[segment] OCR JPGs -> TSV"
ocr "${jpg_dir}" "${OCR_LANG}" "${OCR_FILTER}"

echo "[segment] Run predict.py"
predict "${PREDICT}" "${jpg_dir}" "${MODEL}" "${OUT_CSV}" "${VENV}"

echo "[segment] Cleanup tmp"
cleanup "${TMP_DIR}"
cleanup "cache"

echo "[segment] Done. CSV at: ${OUT_CSV}"