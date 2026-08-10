#!/bin/bash
set -e

print_help() {
  cat << EOF
Usage:
  $(basename "$0") [OPTIONS] <input_folder> <max_size>

Description:
  Compress all JPG/JPEG files in <input_folder> using ImageMagick,
  preserving resolution, optionally stripping metadata, and limiting
  each file to <max_size>. Processes files in parallel (default 8 jobs).

Arguments:
  input_folder
      Folder containing JPG/JPEG files

  max_size
      Maximum allowed size per image.
      Supported units: KB, MB, GB
      Examples: 500KB, 2MB, 1.5MB

Options:
  -o, --output <folder>
      Output directory (created if it does not exist)
      Default: <input_folder>_compressed

  --strip-all
      Remove all metadata (EXIF, GPS, etc.)

  -j, --jobs N
      Number of parallel compression jobs (default 8)

  -h, --help
      Show this help and exit

Examples:
  Compress to max 1MB (default 8 jobs):
    $(basename "$0") photos 1MB

  Compress to 750KB, custom output folder, strip metadata:
    $(basename "$0") photos 750KB -o ~/Desktop/web_ready --strip-all

Requirements:
  brew install imagemagick
EOF
}

# --------- DEFAULTS ----------
OUTPUT_DIR=""
STRIP_ALL=false
PARALLEL_JOBS=8
POSITIONAL=()

# --------- ARG PARSING ----------
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--output)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --strip-all)
      STRIP_ALL=true
      shift
      ;;
    -j|--jobs)
      PARALLEL_JOBS="$2"
      shift 2
      ;;
    -h|--help)
      print_help
      exit 0
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

set -- "${POSITIONAL[@]}"

if [ $# -ne 2 ]; then
  echo "Error: missing required arguments"
  echo
  print_help
  exit 1
fi

INPUT_DIR="${1%/}"
SIZE_RAW="$2"

# --------- validate size format ----------
if ! echo "$SIZE_RAW" | grep -E -q '^[0-9]+(\.[0-9]+)?(KB|MB|GB|kb|mb|gb)$'; then
  echo "Error: invalid size format: $SIZE_RAW"
  echo "Use KB, MB, or GB (e.g. 500KB, 2MB)"
  exit 1
fi

# Separate number and unit
VALUE=$(echo "$SIZE_RAW" | sed -E 's/([0-9.]+).*/\1/')
UNIT=$(echo "$SIZE_RAW" | sed -E 's/[0-9.]+(.*)/\1/')
UNIT=$(echo "$UNIT" | tr '[:lower:]' '[:upper:]')

# Convert size to bytes
case "$UNIT" in
  KB)
    MAX_BYTES=$(echo "$VALUE*1024" | bc | cut -d. -f1)
    ;;
  MB)
    MAX_BYTES=$(echo "$VALUE*1024*1024" | bc | cut -d. -f1)
    ;;
  GB)
    MAX_BYTES=$(echo "$VALUE*1024*1024*1024" | bc | cut -d. -f1)
    ;;
  *)
    echo "Unknown unit: $UNIT"
    exit 1
    ;;
esac

# --------- OUTPUT DIR ----------
if [ -z "$OUTPUT_DIR" ]; then
  OUTPUT_DIR="${INPUT_DIR}_compressed"
fi
mkdir -p "$OUTPUT_DIR"

echo "Input folder : $INPUT_DIR"
echo "Output folder: $OUTPUT_DIR"
echo "Max size     : $SIZE_RAW (~$MAX_BYTES bytes)"
echo "Parallel jobs: $PARALLEL_JOBS"
echo

# --------- COLLECT FILES ----------
shopt -s nullglob
FILES=( "$INPUT_DIR"/*.{jpg,jpeg,JPG,JPEG} )
FILES=( "${FILES[@]}" )

if [ ${#FILES[@]} -eq 0 ]; then
  echo "No JPG/JPEG files found in $INPUT_DIR"
  exit 1
fi

echo "Compressing files (original resolution preserved)..."

# --------- PARALLEL COMPRESSION ---------
compress_file() {
  f="$1"
  BASENAME=$(basename "$f")
  OUT="$OUTPUT_DIR/$BASENAME"

  STRIP_ARG=""
  if [ "$STRIP_ALL" = true ]; then
    STRIP_ARG="-strip"
  fi

  magick "$f" $STRIP_ARG -sampling-factor 4:2:0 -define jpeg:extent="$SIZE_RAW" "$OUT"

  BEFORE=$(stat -f%z "$f")
  AFTER=$(stat -f%z "$OUT")
  echo "$BASENAME: $((BEFORE/1024))KB → $((AFTER/1024))KB"
}

export -f compress_file
export OUTPUT_DIR SIZE_RAW STRIP_ALL

# Run in parallel (limit to PARALLEL_JOBS)
printf "%s\n" "${FILES[@]}" | xargs -n 1 -P "$PARALLEL_JOBS" -I {} bash -c 'compress_file "$@"' _ {}

echo
echo "Done ✔"
