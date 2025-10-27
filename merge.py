import os
import csv
import sys
import img2pdf
from pathlib import Path
import argparse

def predicts(csv_path):
    rows = []
    with csv_path.open(newline='', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        if 'stem' not in reader.fieldnames or 'prediction' not in reader.fieldnames:
            raise SystemExit("CSV must contain 'stem' and 'prediction' columns")
        for r in reader:
            try:
                pred = int(r['prediction'])
            except Exception:
                pred = int(float(r['prediction']))
            rows.append((r['stem'], pred))
    return rows

def build_groups(rows):
    groups, current = [], []
    for stem, pred in rows:
        if pred == 1:
            if current:
                groups.append(current)
            current = [stem]
        else:
            current.append(stem)
    
    if current:
        groups.append(current)
    return groups

def image_paths(stems, jpg_dir):
    for stem in stems:
        yield os.path.join(jpg_dir, f'{stem}.jpg')

def pdfing(image_paths, out_pdf: Path):
    paths = [p for p in image_paths if Path(p).exists()]
    if not paths:
        return False
    out_pdf.parent.mkdir(parents=True, exist_ok=True)
    with out_pdf.open("wb") as f:
        f.write(img2pdf.convert(paths))
    return True

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", required=True, type=Path, help="CSV con columnas stem,prediction")
    ap.add_argument("--jpg-dir", required=True, type=Path, help="Directorio donde están las imágenes")
    ap.add_argument("--out-dir", required=True, type=Path, help="Directorio de salida para los PDFs")
    args = ap.parse_args()

    rows = predicts(args.csv)
    groups = build_groups(rows)
    if not groups:
        print("[merge] No groups found (no prediction==1). Nothing to do.")
        sys.exit()
    
    created = 0
    for idx, stems in enumerate(groups, 1):
        img_iter = image_paths(stems, args.jpg_dir)

        safe_first = stems[0].replace(os.sep, "_")
        out_name = f"{idx:04d}_{safe_first}.pdf"
        out_pdf = args.out_dir / out_name

        ok = pdfing(img_iter, out_pdf)
        if ok:
            created += 1
            print(f"[merge] Created {out_pdf}")
        else:
            print(f"[merge] Skipped group {idx}: no images found")