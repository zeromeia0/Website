#!/usr/bin/env bash
# Rebuilds the optimized images in media/ from the originals in this folder.
# Neocities free accounts can't host mp4/webm, so animations become
# animated AVIF (primary) + animated WebP (fallback for older browsers).
# Usage: ./optimize-media.sh   (needs ffmpeg with libsvtav1 + libwebp)
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p media

# Cards are ~500px wide, so 960px covers 2x (retina) screens; 15fps is plenty
VF="fps=15,scale='min(960,iw)':-2:flags=lanczos"

encode() {
  local gif="$1" name="${1%.gif}"
  ffmpeg -y -loglevel error -i "$gif" -vf "$VF" -pix_fmt yuv420p \
    -c:v libsvtav1 -crf 36 -preset 6 -svtav1-params "enable-overlays=1" \
    -f avif "media/$name.avif" 2>/dev/null
  ffmpeg -y -loglevel error -i "$gif" -vf "$VF" \
    -c:v libwebp_anim -quality 65 -compression_level 4 -loop 0 \
    "media/$name.webp"
  printf '%-28s gif %6s -> avif %6s, webp %6s\n' "$gif" \
    "$(du -h "$gif" | cut -f1)" \
    "$(du -h "media/$name.avif" | cut -f1)" \
    "$(du -h "media/$name.webp" | cut -f1)"
}

for gif in *.gif; do
  encode "$gif" &
done
wait

# Profile picture is shown at max 260px; 520px covers 2x screens
# (AVIF stores transparency as a second, grayscale stream)
ffmpeg -y -loglevel error -i pfp.png \
  -filter_complex "[0]scale=520:-2:flags=lanczos,format=yuva420p,split[c][a];[a]alphaextract[al]" \
  -map "[c]" -map "[al]" -c:v libaom-av1 -crf 30 -still-picture 1 -f avif media/pfp.avif
ffmpeg -y -loglevel error -i pfp.png -vf "scale=520:-2:flags=lanczos" \
  -c:v libwebp -quality 82 -pix_fmt yuva420p media/pfp.webp
printf '%-28s png %6s -> avif %6s, webp %6s\n' pfp.png \
  "$(du -h pfp.png | cut -f1)" "$(du -h media/pfp.avif | cut -f1)" "$(du -h media/pfp.webp | cut -f1)"
