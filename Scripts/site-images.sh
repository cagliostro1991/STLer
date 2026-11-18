#!/bin/bash
# Rebuilds the site pictures (site/*.webp, site/share.jpg) from the full-size screenshots in icons/.
# Needs ImageMagick and cwebp (brew install imagemagick webp). The screenshots themselves are not committed.
set -euo pipefail
cd "$(dirname "$0")/.."

webp() { # source, output, width
    magick "$1" -trim +repage -resize "$3"x /tmp/site-image.png 2>/dev/null
    cwebp -quiet -q 86 -alpha_q 90 /tmp/site-image.png -o "$2"
}

webp icons/Screenshot-2.png site/preview.webp 1520
webp icons/Screenshot-1.png site/list-view.webp 1520
webp icons/Screenshot-config-main.png site/settings-general.webp 760
for type in stl 3mf step; do webp "icons/Screenshot-config-$type.png" "site/settings-$type.webp" 640; done

# 1200x630 card for link previews: the icon area of the icon view
sips -c 504 960 --cropOffset 170 410 icons/Screenshot-2.png --out /tmp/site-share.png >/dev/null
sips -z 630 1200 -s format jpeg -s formatOptions 85 /tmp/site-share.png --out site/share.jpg >/dev/null
rm -f /tmp/site-image.png /tmp/site-share.png
echo "site pictures rebuilt"
