#!/bin/bash
set -euo pipefail

BAR_WIDTH="${BAR_WIDTH:-40}"

die() { echo "Error: $*" >&2; exit 1; }
disable_cursor() { tput civis 2>/dev/null || printf '\033[?25l'; }
enable_cursor()  { tput cnorm 2>/dev/null || printf '\033[?25h'; }
fmt_hms() { local s=$1; printf "%02d:%02d:%02d" $((s/3600)) $(((s%3600)/60)) $((s%60)); }

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

print_progress() {
  local cur="$1" total="$2" start="$3"
  local now elapsed pct done eta=0
  now=$(date +%s); elapsed=$((now-start))
  pct=$(( total>0 ? cur*100/total : 100 )); ((pct>100)) && pct=100
  if (( cur>0 && cur<total )); then eta=$(( elapsed*(total-cur)/cur )); fi
  done=$(( pct*BAR_WIDTH/100 ))
  printf "\r[%.*s%*s] %3d%% (%d/%d) ETA %s %s" \
    "$done" "########################################" \
    $((BAR_WIDTH-done)) "" \
    "$pct" "$cur" "$total" "$(fmt_hms "$eta")"
}

preprocess() {
  local work_dir="$1"
  local pp_dpi="${2:-150}"
  local pp_resize="${3:-1030x1030}"
  local pp_shave="${4:-30x30}"
  local pp_gravity="${5:-NorthWest}"

  local total i=0 start_ts
  total=$(find "$work_dir" -type f -name '*.pdf' -print0 | tr -cd '\0' | wc -c)
  start_ts=$(date +%s)
  disable_cursor

  while IFS= read -r -d '' pdf; do
    i=$((i+1))
    local tmp_pdf="${pdf%.pdf}.preproc.tmp.pdf"
    magick -density "${pp_dpi}" "$pdf" \
      -colorspace Gray -resize "${pp_resize}" \
      -gravity "${pp_gravity}" -shave "${pp_shave}" \
      "$tmp_pdf"
    mv -f "$tmp_pdf" "$pdf"
    print_progress "$i" "$total" "$start_ts"
  done < <(find "$work_dir" -type f -name '*.pdf' -print0)
  printf \n; enable_cursor
}

pdf2jpg() {
  local src_pdf_dir="$1"
  local dst_jpg_dir="$2"
  local dpi="${3:-150}"
  local resize="${4:-}"

  mkdir -p "$dst_jpg_dir"

  local total i=0 start_ts
  total=$(find "$src_pdf_dir" -type f -name '*.pdf' -print0 | tr -cd '\0' | wc -c)
  start_ts=$(date +%s)
  disable_cursor

  while IFS= read -r -d '' pdf; do
    i=$((i+1))
    local base
    base="$(basename "$pdf")"
    base="${base%.*}"
    if [[ -n "$resize" ]]; then
      magick -density "${dpi}" "$pdf" -resize "${resize}" "${dst_jpg_dir}/${base}-%d.jpg"
    else
      magick -density "${dpi}" "$pdf" "${dst_jpg_dir}/${base}-%d.jpg"
    fi
    print_progress "$i" "$total" "$start_ts"
  done < <(find "$src_pdf_dir" -type f -name '*.pdf' -print0)
  printf \n; enable_cursor
}

ocr() {
  local jpg_dir="$1"
  local ocr_lang="${2:-spa+eng}"
  local ocr_filter="${3:-}"

  require_cmd tesseract
  if [[ -n "${ocr_filter}" ]] && [[ ! -f "${ocr_filter}" ]]; then
    die "Specified ocr_filter not found: ${ocr_filter}"
  fi

  local total i=0 start_ts
  total=$(find "$jpg_dir" -type f -name '*.jpg' -print0 | tr -cd '\0' | wc -c)
  start_ts=$(date +%s)
  disable_cursor

  while IFS= read -r -d '' jpg; do
    i=$((i+1))
    local stem="${jpg%.jpg}"
    if [[ -n "${ocr_filter}" ]]; then
      tesseract --dpi 300 -l "${ocr_lang}" --oem 1 --psm 1 "$jpg" stdout tsv 2>/dev/null | awk -f "${ocr_filter}" > "${stem}.tsv"
    else
      tesseract --dpi 300 -l "${ocr_lang}" --oem 1 --psm 1 "$jpg" stdout tsv 2>/dev/null > "${stem}.tsv"
    fi
    print_progress "$i" "$total" "$start_ts"
  done < <(find "$jpg_dir" -type f -name '*.jpg' -print0)
  printf \n; enable_cursor
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