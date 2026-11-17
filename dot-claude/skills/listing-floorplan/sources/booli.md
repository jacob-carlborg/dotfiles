# Booli

## Fetch

Booli sits behind Cloudflare, so `curl` gets a challenge page. Open the listing in Safari (`mcp__safari-mcp__create_tab`), then read the image list from the embedded Apollo state:

```js
const html = document.documentElement.outerHTML.replace(/\\"/g, '"');
const arr = JSON.parse('[' + html.match(/"images":\[(\{"__typename":"Image".*?)\]/)[1] + ']');
return arr.map(i => `${i.id} ${i.primaryLabel} ${i.alt}`).join('\n');
```

`primaryLabel: "floorplan"` marks the plans; the other labels (kitchen, bathroom, interior…) are hints, often wrong. Grab the facts (boarea, biarea, rum, tomt, byggår) from `document.body.innerText`, and the coordinates from the same unescaped HTML: `html.match(/"(latitude|longitude)":[^,}]+/g)`.

## Download

CDN: `https://bcdn.se/images/cache/<id>_1440x0.jpg`, plain `curl`, no headers.

Ids are 8-digit numbers. macOS `seq` prints them in exponent form, so use `seq -f %.0f` if you need it. Ids can skip numbers, so download from the id list, not a range.
