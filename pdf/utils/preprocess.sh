#!/bin/bash

echo make a copy of raw data
mkdir -p work
cp -r 'TOMO 0001.pdf' 'work/TOMO 0001.pdf'

echo resize pdfs and remove id information
find work -name '*.pdf' -exec sh -c "magick -density 150 '{}' -colorspace Gray -resize 1030x1030 -gravity NorthWest -shave 30x30 '{}'" \;

mkdir -p jpg

echo convert pdfs to jpg folders
while read -r pdf_path; do
    pdf_name=$(basename "$pdf_path")
    pdf_name="${pdf_name%.*}"
    magick -density 150 "$pdf_path" -resize 1000x1000 "jpg/$pdf_name.jpg"
    rm "$pdf_path"
done < <(find work -name "*.pdf")

echo get OCR using tesseract
export filter="ocr_filter.awk"
while read -r pdf_path; do
    pdf_name="${pdf_path%.*}"
    tesseract --dpi 300 -l spa+eng --oem 1 --psm 1 "$pdf_path" stdout tsv 2> /dev/null | awk -f $filter > "$pdf_name.tsv"
done < <(find jpg -name "*.jpg")