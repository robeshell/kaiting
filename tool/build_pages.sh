#!/usr/bin/env bash

set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_dir="${1:-$root_dir/build/pages}"
web_build_dir="$root_dir/build/web"
app_icon_source="$root_dir/assets/branding/app_icon_master-v7.png"

if [[ ! -f "$app_icon_source" ]]; then
  app_icon_source="$root_dir/web/icons/Icon-512.png"
fi

if [[ ! -f "$web_build_dir/index.html" ]]; then
  echo "Flutter Web build not found at $web_build_dir" >&2
  echo "Run: flutter build web --release --base-href /kaiting/app/" >&2
  exit 1
fi

rm -rf "$output_dir"
mkdir -p "$output_dir/assets" "$output_dir/app"

cp "$root_dir/website/index.html" "$output_dir/index.html"
cp "$root_dir/website/404.html" "$output_dir/404.html"
cp "$root_dir/website/styles.css" "$output_dir/styles.css"
cp "$root_dir/website/app.js" "$output_dir/app.js"

cp "$app_icon_source" "$output_dir/assets/app-icon.png"
cp "$root_dir/web/favicon.png" "$output_dir/assets/favicon.png"
cp "$root_dir/website/assets/app-settings-light.jpg" "$output_dir/assets/app-settings-light.jpg"
cp "$root_dir/website/assets/app-library-light.jpg" "$output_dir/assets/app-library-light.jpg"

cp -R "$web_build_dir/." "$output_dir/app/"
touch "$output_dir/.nojekyll"

echo "GitHub Pages artifact assembled at $output_dir"
