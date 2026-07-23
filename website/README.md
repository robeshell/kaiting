# 开听 website

The static marketing site is published at the GitHub Pages root. The Flutter
Web build is nested under `app/` so the two experiences can be released as one
Pages artifact.

Build the Flutter Web app first, then assemble a local Pages artifact:

```sh
flutter build web --release --base-href /kaiting/app/
bash tool/build_pages.sh
```

The result is written to `build/pages/`. The download buttons query the public
GitHub Releases API at runtime and fall back to the repository releases page
when no published release or matching asset exists.
