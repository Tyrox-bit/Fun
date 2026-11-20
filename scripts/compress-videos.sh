#!/usr/bin/env bash
# Macht aus deinen Handy-Clips schnelle Web-Videos + Vorschaubilder.
#
#   1. Originale (z. B. .mov vom iPhone) nach  assets/video/raw/  legen
#   2. npm run videos
#   3. Fertige Dateien liegen in  assets/video/  (name.mp4 + name.jpg)
#
# Dateien, die mit "hero" beginnen, werden quadratisch (1080×1080, ohne Ton)
# für das große Produktbild. Alle anderen werden Reels (720×1280, mit Ton).
# Braucht ffmpeg  (Mac: brew install ffmpeg · Windows: winget install ffmpeg)
set -euo pipefail
cd "$(dirname "$0")/.."

RAW="assets/video/raw"
OUT="assets/video"
mkdir -p "$RAW" "$OUT"

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ffmpeg fehlt. Mac: brew install ffmpeg"
  exit 1
fi

shopt -s nullglob nocaseglob
files=("$RAW"/*.mov "$RAW"/*.mp4 "$RAW"/*.m4v)
if [ ${#files[@]} -eq 0 ]; then
  echo "Keine Videos in $RAW gefunden."
  exit 0
fi

for f in "${files[@]}"; do
  name="$(basename "${f%.*}" | tr '[:upper:] ' '[:lower:]-')"
  target="$OUT/$name.mp4"
  echo "→ $name"
  if [[ "$name" == hero* ]]; then
    ffmpeg -y -loglevel error -i "$f" -t 12 \
      -vf "scale=1080:1080:force_original_aspect_ratio=increase,crop=1080:1080,fps=30" \
      -c:v libx264 -preset slow -crf 27 -profile:v high -pix_fmt yuv420p -movflags +faststart -an "$target"
  else
    ffmpeg -y -loglevel error -i "$f" -t 20 \
      -vf "scale=720:1280:force_original_aspect_ratio=increase,crop=720:1280,fps=30" \
      -c:v libx264 -preset slow -crf 26 -profile:v high -pix_fmt yuv420p -movflags +faststart \
      -c:a aac -b:a 96k -ac 2 "$target"
  fi
  # Vorschaubild aus Sekunde 0,5
  ffmpeg -y -loglevel error -ss 0.5 -i "$target" -frames:v 1 -q:v 4 "$OUT/$name.jpg"
  size=$(du -k "$target" | cut -f1)
  echo "   fertig: $target (${size} KB) + $name.jpg"
  if [ "$size" -gt 4000 ]; then echo "   ⚠ über 4 MB – Clip kürzen (ideal 6–10 Sek.)"; fi
done

echo
echo "Jetzt in shop.config.json → media eintragen, z. B.:"
echo '  "reels": [{ "src": "/assets/video/tomate.mp4", "poster": "/assets/video/tomate.jpg", "title": "Tomaten-Test", "captions": [...] }]'
