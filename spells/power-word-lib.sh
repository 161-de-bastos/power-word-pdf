#!/bin/bash
set -euo pipefail

die() { echo "Error: $*" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command '$1'"
}

activate_venv() {
  local venv="${1:-}"
  if [[ -n "${venv}" ]]; then
    source "${venv}/bin/activate"
  fi
}

cleanup() {
  local dir="$1"
  [[ -d "$dir" ]] && rm -rf "$dir"
}

preprocess() {
  local work_dir="$1"
  local pp_dpi="${2:-150}"
  local pp_resize="${3:-1030x1030}"
  local pp_shave="${4:-30x30}"
  local pp_gravity="${5:-NorthWest}"
  while IFS= read -r -d '' pdf; do
    local tmp_pdf="${pdf%.pdf}.preproc.tmp.pdf"
    magick -density "${pp_dpi}" "$pdf" \
      -colorspace Gray -resize "${pp_resize}" \
      -gravity "${pp_gravity}" -shave "${pp_shave}" \
      "$tmp_pdf"
    mv -f "$tmp_pdf" "$pdf"
  done < <(find "$work_dir" -type f -name '*.pdf' -print0)
}

pdf2jpg() {
  local src_pdf_dir="$1"
  local dst_jpg_dir="$2"
  local dpi="${3:-150}"
  local resize="${4:-}"

  mkdir -p "$dst_jpg_dir"
  while IFS= read -r -d '' pdf; do
    local base
    base="$(basename "$pdf")"
    base="${base%.*}"
    if [[ -n "$resize" ]]; then
      magick -density "${dpi}" "$pdf" -resize "${resize}" "${dst_jpg_dir}/${base}-%d.jpg"
    else
      magick -density "${dpi}" "$pdf" "${dst_jpg_dir}/${base}-%d.jpg"
    fi
  done < <(find "$src_pdf_dir" -type f -name '*.pdf' -print0)
}

ocr() {
  local jpg_dir="$1"
  local ocr_lang="${2:-spa+eng}"
  local ocr_filter="${3:-}"

  require_cmd tesseract
  if [[ -n "${ocr_filter}" ]] && [[ ! -f "${ocr_filter}" ]]; then
    die "Specified ocr_filter not found: ${ocr_filter}"
  fi

  while IFS= read -r -d '' jpg; do
    local stem="${jpg%.jpg}"
    if [[ -n "${ocr_filter}" ]]; then
      tesseract --dpi 300 -l "${ocr_lang}" --oem 1 --psm 1 "$jpg" stdout tsv 2>/dev/null | awk -f "${ocr_filter}" > "${stem}.tsv"
    else
      tesseract --dpi 300 -l "${ocr_lang}" --oem 1 --psm 1 "$jpg" stdout tsv 2>/dev/null > "${stem}.tsv"
    fi
  done < <(find "$jpg_dir" -type f -name '*.jpg' -print0)
}

predict() {
  local predict_py="$1"
  local data_dir="$2"
  local model_path="$3"
  local out_csv="$4"
  local venv="${5:-}"

  [[ -f "${predict_py}" ]] || die "predict script not found at ${predict_py}"
  activate_venv "${venv}"
  python3 "${predict_py}" --data "${data_dir}" --model "${model_path}" --csv "${out_csv}"
}

merge() {
  local merge_py="$1"
  local csv="$2"
  local jpg_dir="$3"
  local out_dir="$4"
  local venv="${5:-}"

  [[ -f "${merge_py}" ]] || die "predict script not found at ${merge_py}"
  activate_venv "${venv}"
  python3 "${merge_py}" --csv "${csv}" --jpg-dir "${jpg_dir}" --out-dir "${out_dir}"
}