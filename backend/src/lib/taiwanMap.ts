// Server-side helper that loads the letswritetw Taiwan counties GeoJSON
// (19 counties, lon 120.03~121.97, lat 21.93~25.30) and projects each
// polygon to SVG path data on a 0..100 viewBox so we can overlay city
// bubbles using the SAME projection — bubbles always land on the right
// county.

import { readFileSync } from "node:fs";
import { join } from "node:path";

export const TW_BOUNDS = {
  lonMin: 120.03,
  lonMax: 121.97,
  latMin: 21.93,
  latMax: 25.30,
};
const LON_RANGE = TW_BOUNDS.lonMax - TW_BOUNDS.lonMin;       // ≈ 1.94
const LAT_RANGE = TW_BOUNDS.latMax - TW_BOUNDS.latMin;       // ≈ 3.37
const LAT_CENTER = (TW_BOUNDS.latMin + TW_BOUNDS.latMax) / 2; // ≈ 23.6
const COS_LAT = Math.cos((LAT_CENTER * Math.PI) / 180);       // ≈ 0.916

// Equirectangular projection with cosine-latitude correction so 1° lon ≈
// 1° lat in screen distance at Taiwan's latitude. Fits the projected map
// inside a fixed-height viewBox; width derives from Taiwan's natural aspect.
export const VB_HEIGHT = 100;
export const VB_WIDTH =
  Math.round(((LON_RANGE * COS_LAT) / LAT_RANGE) * VB_HEIGHT * 100) / 100;
// → ≈ 52.7 (Taiwan is naturally ~1.9× as tall as it is wide)

export function projectLonLat(lon: number, lat: number): [number, number] {
  const x = ((lon - TW_BOUNDS.lonMin) * COS_LAT * VB_HEIGHT) / LAT_RANGE;
  const y = ((TW_BOUNDS.latMax - lat) * VB_HEIGHT) / LAT_RANGE;
  return [x, y];
}

export type CountyPath = {
  id: string;
  name: string;
  nameEn: string;
  d: string;
};

type Coords = number[] | Coords[];
type GeoFeature = {
  properties: { COUNTYID: string; COUNTYNAME: string; COUNTYENG: string };
  geometry: { type: "Polygon" | "MultiPolygon"; coordinates: Coords };
};

let cache: CountyPath[] | null = null;

export function loadCountyPaths(): CountyPath[] {
  if (cache) return cache;
  const path = join(
    process.cwd(),
    "public",
    "taiwan-counties.geojson",
  );
  const raw = readFileSync(path, "utf-8");
  const geo = JSON.parse(raw) as { features: GeoFeature[] };

  cache = geo.features.map((f) => ({
    id: f.properties.COUNTYID,
    name: f.properties.COUNTYNAME,
    nameEn: f.properties.COUNTYENG,
    d: geometryToPath(f.geometry),
  }));
  return cache;
}

function geometryToPath(geom: GeoFeature["geometry"]): string {
  const ringsToPath = (rings: number[][][]): string =>
    rings
      .map((ring) =>
        ring
          .map((pt, i) => {
            const [x, y] = projectLonLat(pt[0], pt[1]);
            return `${i === 0 ? "M" : "L"}${x.toFixed(3)},${y.toFixed(3)}`;
          })
          .join(" ") + " Z",
      )
      .join(" ");

  if (geom.type === "Polygon") {
    return ringsToPath(geom.coordinates as unknown as number[][][]);
  }
  // MultiPolygon — flatten each polygon's rings
  return (geom.coordinates as unknown as number[][][][])
    .map((poly) => ringsToPath(poly))
    .join(" ");
}
