#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DATA_DIR="$ROOT_DIR/data"
DATASET_NAME="yasserh/titanic-dataset"

if ! command -v curl >/dev/null 2>&1; then
  echo "error: curl が見つかりません。"
  exit 1
fi

if ! command -v unzip >/dev/null 2>&1; then
  echo "error: unzip が見つかりません。"
  exit 1
fi

if ! command -v kaggle >/dev/null 2>&1; then
  echo "error: kaggle CLI が見つかりません。"
  echo "hint: pip install kaggle"
  exit 1
fi

mkdir -p "$DATA_DIR"

tmp_dir="$(mktemp -d)"
zip_file="$tmp_dir/titanic-dataset.zip"

cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

echo "Downloading dataset from Kaggle..."
kaggle datasets download -d "$DATASET_NAME" -p "$tmp_dir" -o -q

if [ -f "$tmp_dir/titanic-dataset.zip" ]; then
  zip_file="$tmp_dir/titanic-dataset.zip"
fi

echo "Extracting zip..."
unzip -oq "$zip_file" -d "$tmp_dir/extracted"

csv_count=0
for csv_file in "$tmp_dir"/extracted/*.csv; do
  if [ -f "$csv_file" ]; then
    cp "$csv_file" "$DATA_DIR/"
    csv_count=$((csv_count + 1))
    echo "Copied: $(basename "$csv_file") -> $DATA_DIR"
  fi
done

if [ "$csv_count" -eq 0 ]; then
  echo "error: ZIP 内に CSV が見つかりませんでした。"
  exit 1
fi

echo "Done. $csv_count file(s) copied to $DATA_DIR"
