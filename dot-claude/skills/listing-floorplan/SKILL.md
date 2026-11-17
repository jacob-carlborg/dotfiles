---
name: listing-floorplan
description: Pin a housing listing's photos onto its floor plans as an interactive Artifact with a location map, one pin per room, optionally with a room-allocation proposal for a household. Use when given a property listing (Booli, Fastighetsbyrån, Hemnet, a broker's page) and asked to match photos to rooms or plan who sleeps/works where.
---

# Listing floor plan

Output: a published Artifact with each floor plan, a photo **pin** on every room (click → lightbox with all that room's photos), a location section with two static maps, an outside/area strip, and a full gallery grouped by room. `example.html` in this folder is a finished page (Nämndemansbacken 130, Booli 1804576): copy it and replace the data; do not rebuild from scratch. Write page copy in the listing's language.

## 1. Fetch the listing

Each site keeps its data in a different place. Read the source file for the listing's site before fetching anything:

- Booli: `sources/booli.md`
- Fastighetsbyrån: `sources/fastighetsbyran.md`

Another site: look for a JSON state blob in the page (an inline `<script>` assigning `window.__…STATE__`, Apollo or Next data, sometimes base64-encoded) that holds the image list, the facts and the coordinates. Try plain `curl` first and use Safari only if `curl` gets a challenge page. Once a run works, add a `sources/<site>.md` in the same shape.

Done when you have every image id, which ids are plans, the facts, the sales text, and latitude/longitude.

## 2. Download images and render maps

Download from the CDN URL in the source file. Plain `curl` works; extra headers (User-Agent, Referer) get the call denied in auto mode, so send none. Put downloads in their own scratchpad dir.

Gotchas, each hit in practice:
- Name files by **full id**. Stripping a shared prefix breaks when ids cross a hundred boundary.
- `montage` has no default font: pass `-font /System/Library/Fonts/Supplemental/Arial.ttf -label '%t'` **before** the file list, `-tile 4x3 -geometry 400x267+6+6`, 12 images per sheet. The Bash tool runs zsh, where `${arr[@]:k:12}` fails, so batch the files with `split`:
  ```sh
  sed 's|^|dl/|;s|$|.jpg|' ids.txt | split -l 12 - grp_
  for g in grp_*; do magick montage -font /System/Library/Fonts/Supplemental/Arial.ttf -label '%t' $(cat $g) -tile 4x3 -geometry 400x267+6+6 sheets/$g.jpg; done; rm grp_*
  ```

Then make page assets: `img/l/<id>.jpg` (`magick -resize 1200x1200\> -quality 78 -strip`), `img/t/<id>.jpg` (420px, q72), and each plan cropped to its drawn content as `img/plan-<floor>.jpg` (`-crop WxH+X+Y +repage`). Record each crop rectangle. Check the crops on one montage before moving on.

Maps: the listing's own map can't be reused (sites draw vector tiles; artifacts block external images and iframes), so render two static OpenStreetMap images with the address at the exact centre:

```sh
~/.claude/skills/listing-floorplan/static-map.sh LAT LON 16 960 600 site/img/map-nara.png   scratch/tiles   # ~1.2 km wide
~/.claude/skills/listing-floorplan/static-map.sh LAT LON 13 960 600 site/img/map-omrade.png scratch/tiles  # ~9 km wide
```

Width in metres = 960 × 156543 × cos(lat) / 2^zoom; put it in each map's `scale` caption. Read both images: they must show streets, not grey "Access blocked" tiles. The script sends its own identifying User-Agent because OSM's tile policy requires one; keep it, and keep the tile count to these two maps. CARTO basemaps now need an API key.

## 3. Map the rooms

Read each plan image. For every room write its name and the pixel centre in the **original** plan image; the page converts to percentages through the crop. Pins are 22% of the plan width (26% with `wide: true`); check neighbouring pins don't overlap and move a centre off-axis where they would. Keep pins off the plan's own text labels (on a patio or garden area the label sits right at the centre).

When a name repeats (three "Sovrum" on one floor), number the rooms across the whole house (Sovrum 1–5) so pins and gallery headings are distinguishable. A room with no photos gets no pin; mention it in the floor's `note` instead.

## 4. Match every photo

Read the contact sheets and assign each photo to exactly one room, or to the outside/area list. Evidence, strongest first: windows and doors visible vs. the plan, what's outside the window (terrace, street, balcony rail), stair direction, wallpaper or floor continuing through a doorway, objects that recur (a lamp, a picture) across shots, and for a sloped ceiling, which side of the roof it is on. The sales text says which floor holds which rooms, and fixtures settle a choice between two bathrooms (shower vs. bathtub, window vs. none). Listings often mix two shoots (seasons, furniture), so one room can look different between photos. Some images are two-photo collages: one image, one id.

Put the best photo first in each room's list: it becomes the pin. Note every match you are unsure of, for the report.

Done when a script confirms the ids in the page data equal the downloaded ids, with no duplicates:

```sh
grep -oE 'photos: \[[^]]*\]' page.html | grep -oE '"[0-9]+"' | tr -d '"' | sort > used.txt
ls img/l | sed 's/.jpg//' | sort > all.txt; comm -3 used.txt all.txt; uniq -d used.txt   # both empty
```

## 5. Build and publish

In the copy of `example.html`, replace: `<title>`, header facts, lede source link, `LOCATION` (address, lat, lon, map scales), `FLOORS` (name, note, src, crop, rooms), `OUTSIDE`. Remove the proposal section and every `use` unless step 6 applies. Keep the OpenStreetMap attribution line under the maps. Publish with `root` set to the site dir and `files` mapping every `img/**.jpg` and both `img/map-*.png` to itself. Generate the map with `(cd site && ls img/*.* img/l/* img/t/*)`, not by hand. One local look before publishing: open the file in Safari and take one full-page screenshot.

## 6. Room allocation (when the user gives a household)

Add `use: { label, order, size, where?, why }` to the chosen rooms; the page renders the list and blue labels from that.

- **Sizes**: plans rarely carry a scale. Derive px/m from the listing: sum the outer footprint of all floors in px², take boarea + biarea × ~1.13 as gross m², scale = √(px²/m²). Cross-check that the room estimates add up to near the boarea. Always label them approximate.
- **Count**: Swedish *rum* excludes the kitchen; a second living room (hobbyrum, allrum) is the usual spare room.
- **Placement**: parents in the largest bedroom; the youngest child closest to the parents and a WC; an older child can sit next to the living room; an office away from the bedrooms, ideally with its own entrance.
- When rooms run short, give three options in the reply: partition a large room (check both halves get a window), a desk corner, a garden building (friggebod/attefallshus, subject to the detaljplan and samfällighet).

## Report

Link the page, give a per-room photo count table, list the uncertain matches with the evidence used, and say which version you actually looked at.
