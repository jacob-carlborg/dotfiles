# Fastighetsbyrån

Listing URL: `https://www.fastighetsbyran.com/sv/sverige/till-salu/.../objekt/?objektID=<objektID>`. Verified on Sockenvägen 556, objektID 3489970.

## Fetch

No Cloudflare: plain `curl` of the listing URL returns the full page, no Safari needed. Everything sits in one inline script, `window.__PRELOADED_STATE__ = '<base64>'`: base64 of UTF-8 JSON. Decode it to `state.json` and print what step 1 needs:

```sh
curl -s -o page.html "$URL"
python3 -I - page.html 3489970 <<'EOF'
import re, sys, base64, json
h = open(sys.argv[1]).read()
s = json.loads(base64.b64decode(re.search(r"__PRELOADED_STATE__ = '([^']+)'", h).group(1)))
json.dump(s, open('state.json', 'w'), ensure_ascii=False, indent=1)
m = s['maeklarObjekt']['objektInfo'][sys.argv[2]]['data']['maeklarObjekt']
idof = lambda b: b['url'].rsplit('/', 1)[1].removesuffix('.jpg')
open('ids.txt', 'w').write('\n'.join(map(idof, m['bilderObjekt']['bilder'])) + '\n')
open('plans.txt', 'w').write('\n'.join(map(idof, m['bilderObjekt']['planritning'])) + '\n')
print(json.dumps(m['basfakta'], ensure_ascii=False, indent=1))
print('lat', m['karta']['kartbildXKoordinat'], 'lon', m['karta']['kartbildYKoordinat'])
print(m['beskrivningKort'])
EOF
```

Fields under `data.maeklarObjekt`:

- `bilderObjekt.bilder[]`: the photos. `bilderObjekt.planritning[]`: the plans, one image per floor, kept apart from the photos, so `ids.txt` holds photos only. `motivText` is null, so there are no room labels to start from. `harPlanritning` can be `false` even when plans exist; go by the array.
- `basfakta`: `gatuadress`, `zon` (area), `bostadsTyp`, `area` as `"boarea/biarea kvm"`, `antalRum` (e.g. "6 rum varav 4 - 5 sovrum"), `tomtArea`, `byggnadsAar`.
- `karta.kartbildXKoordinat` is the **latitude** and `kartbildYKoordinat` the **longitude**.
- `beskrivningKort`: the sales text. It names the rooms on each floor ("Inredd vind med ett ytterligare sovrum"), which is good evidence for step 4.
- `fakta.detaljer[]`: building details (byggnadstyp, fasad, uppvärmning), running costs, property designation.

## Download

CDN: `https://media.fastighetsbyran.se/<id>.jpg?Bredd=1680`, plain `curl`, no headers. Photos come back 1680×1259, plans 1152×1152.

## Plans

Each plan is a square image with wide white margins, the floor name drawn as a title above the plan, and a disclaimer line ("Viss avvikelse kan förekomma…") below it. Crop to the drawing, leaving out the title and the disclaimer. Use the drawn titles (Entréplan, Övre plan, Vindsplan, Källarplan) as the floor names.
