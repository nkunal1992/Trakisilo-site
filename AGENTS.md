# Trakisilo-site — public marketing site

Static site published to GitHub Pages: https://nkunal1992.github.io/Trakisilo-site/

`index.html` = Home, `features.html` = feature deep-dives. Shared design system in
`assets/site.css` + `assets/site.js`. Source for all product media is the private
app repo `../Trakisilo` — never hand-edit videos/screenshots here; regenerate them.

## Deploy

```
git add -A && git commit -m "..." && git push
# Pages rebuilds within ~1 min; verify with curl -sI <url>
```

## Regenerating assets

All capture tooling lives in the Trakisilo repo (`../Trakisilo`).

```
# Loops + hero + tour (dark theme, no captions on loops, no macOS window chrome)
cd ../Trakisilo
for n in f-hero f-kanban f-card f-clips f-quickpaste f-time f-calendar \
         f-chronicle f-bdoc f-editor f-process f-search f-themes; do
  E2E_THEME=dark TRAILER_CAPTIONS=0 TRAILER_OUT=$PWD/store-assets/site \
    TRAILER=$n bash packaging/record-trailer.sh $n
done
E2E_THEME=dark TRAILER_OUT=$PWD/store-assets/site TRAILER=tour \
  bash packaging/record-trailer.sh tour

# Screenshots (dark)
E2E_THEME=dark npx wdio run wdio.conf.ts --spec e2e/shots/store-shots.e2e.ts

# Convert + publish into this repo (reads ../Trakisilo/store-assets/{site,dark})
cd ../Trakisilo-site
bash tools/build-assets.sh
```

Env vars on `record-trailer.sh`: `TRAILER_OUT` (output dir), `TRAILER_CAPTIONS=0`
(no baked caption overlay), `TRAILER_KEEP_CHROME=1` (skip the traffic-light
delogo pass), `E2E_THEME=dark|light` (forces app theme via localStorage).

## Rules

- Keep the OS cursor off the app window while recording — it gets captured.
- Every capability claim on the site must be verifiable in the app — check code
  or `../Trakisilo/src/lib/guide.tsx` before writing copy.
- All media is dark theme; loops are silent, 1280px, poster = first frame.
- Links on the site must never point to the private `nkunal1992/Trakisilo` repo.
- After deploy: `curl -sI` every referenced asset; all must return 200.

## Link check

```
cd tools && bash check-links.sh    # lints both pages against the live site
```
