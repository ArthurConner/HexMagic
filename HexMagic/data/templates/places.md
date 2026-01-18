# Interesting Geographic Locations for Hex Maps

This document contains commands to generate hex maps of geographically interesting locations with notable terrain, elevation changes, and strategic features.

## Coastal Cities with Dramatic Terrain

### Rio de Janeiro, Brazil
**Features:** Dramatic mountains meeting ocean, Sugarloaf Mountain, Corcovado, favelas on hillsides, Guanabara Bay, tropical coastline

```bash
./generate_geo_grid_with_elevation.swift --rows 60 --cols 60 --min-lat -23.1 --max-lat -22.7 --min-lon -43.5 --max-lon -43.0 --radius 15.0 --output rio_60x60.txt --delay 200
```

### Vancouver, British Columbia
**Features:** Coast Mountains, Pacific Ocean, fjords, North Shore mountains, Vancouver Island views, dramatic elevation changes from sea level to mountains

```bash
./generate_geo_grid_with_elevation.swift --rows 60 --cols 60 --min-lat 49.1 --max-lat 49.5 --min-lon -123.3 --max-lon -122.8 --radius 15.0 --output vancouver_60x60.txt --delay 200
```

### San Francisco Bay Area, California
**Features:** Hills (Twin Peaks, Telegraph Hill), San Francisco Bay, Golden Gate strait, Peninsula, East Bay hills, dramatic fog patterns

```bash
./generate_geo_grid_with_elevation.swift --rows 70 --cols 70 --min-lat 37.4 --max-lat 38.0 --min-lon -122.6 --max-lon -121.9 --radius 15.0 --output san_francisco_70x70.txt --delay 200
```

### Hong Kong & Kowloon
**Features:** Victoria Peak, Kowloon Peak, Victoria Harbour, dense urban development on steep terrain, islands

```bash
./generate_geo_grid_with_elevation.swift --rows 50 --cols 50 --min-lat 22.15 --max-lat 22.57 --min-lon 113.83 --max-lon 114.31 --radius 15.0 --output hong_kong_50x50.txt --delay 200
```

### Sydney, Australia
**Features:** Sydney Harbour, North Shore, Eastern Suburbs cliffs, Blue Mountains foothills, Botany Bay, coastal headlands

```bash
./generate_geo_grid_with_elevation.swift --rows 60 --cols 60 --min-lat -34.1 --max-lat -33.6 --min-lon 150.9 --max-lon 151.4 --radius 15.0 --output sydney_60x60.txt --delay 200
```

### Cape Town, South Africa
**Features:** Table Mountain (iconic flat-topped mountain), Cape Peninsula, Atlantic and Indian Ocean convergence, dramatic cliffs

```bash
./generate_geo_grid_with_elevation.swift --rows 60 --cols 60 --min-lat -34.3 --max-lat -33.7 --min-lon 18.2 --max-lon 18.8 --radius 15.0 --output cape_town_60x60.txt --delay 200
```

### Bergen, Norway
**Features:** Seven mountains, deep fjords, dramatic Norwegian coastline, steep valleys, North Sea access

```bash
./generate_geo_grid_with_elevation.swift --rows 50 --cols 50 --min-lat 60.2 --max-lat 60.6 --min-lon 4.9 --max-lon 5.5 --radius 15.0 --output bergen_50x50.txt --delay 200
```

## Mountain Cities

### Denver, Colorado (Front Range)
**Features:** Rocky Mountains, dramatic elevation rise from plains to peaks, mountain passes, continental divide

```bash
./generate_geo_grid_with_elevation.swift --rows 70 --cols 70 --min-lat 39.4 --max-lat 40.2 --min-lon -105.5 --max-lon -104.6 --radius 15.0 --output denver_70x70.txt --delay 200
```

### Kathmandu Valley, Nepal
**Features:** Himalayan foothills, dramatic elevation changes, valley surrounded by high peaks, historic mountain passes

```bash
./generate_geo_grid_with_elevation.swift --rows 60 --cols 60 --min-lat 27.5 --max-lat 27.9 --min-lon 85.1 --max-lon 85.6 --radius 15.0 --output kathmandu_60x60.txt --delay 200
```

### Innsbruck, Austria (Alps)
**Features:** Alpine valley, surrounded by high peaks, mountain passes, Inn River valley, ski areas

```bash
./generate_geo_grid_with_elevation.swift --rows 50 --cols 50 --min-lat 47.1 --max-lat 47.4 --min-lon 11.2 --max-lon 11.6 --radius 15.0 --output innsbruck_50x50.txt --delay 200
```

### Queenstown, New Zealand
**Features:** Lake Wakatipu, The Remarkables mountain range, Southern Alps, dramatic glacial valleys

```bash
./generate_geo_grid_with_elevation.swift --rows 50 --cols 50 --min-lat -45.3 --max-lat -44.9 --min-lon 168.4 --max-lon 168.9 --radius 15.0 --output queenstown_50x50.txt --delay 200
```

## Island Regions

### Hawaiian Islands - Oahu
**Features:** Diamond Head crater, Ko'olau Range, volcanic peaks, dramatic windward cliffs, Pearl Harbor

```bash
./generate_geo_grid_with_elevation.swift --rows 60 --cols 60 --min-lat 21.2 --max-lat 21.7 --min-lon -158.3 --max-lon -157.6 --radius 15.0 --output oahu_60x60.txt --delay 200
```

### Hawaiian Islands - Big Island (Kilauea)
**Features:** Active volcanoes (Mauna Loa, Kilauea), lava flows, dramatic elevation from sea level to 13,000+ ft

```bash
./generate_geo_grid_with_elevation.swift --rows 70 --cols 70 --min-lat 19.2 --max-lat 19.9 --min-lon -155.7 --max-lon -154.8 --radius 15.0 --output big_island_70x70.txt --delay 200
```

### Iceland - Reykjavik Region
**Features:** Volcanic terrain, geothermal areas, lava fields, coastal features, dramatic North Atlantic scenery

```bash
./generate_geo_grid_with_elevation.swift --rows 60 --cols 60 --min-lat 63.9 --max-lat 64.4 --min-lon -22.3 --max-lon -21.5 --radius 15.0 --output reykjavik_60x60.txt --delay 200
```

### Santorini, Greece
**Features:** Volcanic caldera, dramatic cliffs, Aegean Sea, ancient volcanic crater

```bash
./generate_geo_grid_with_elevation.swift --rows 40 --cols 40 --min-lat 36.3 --max-lat 36.5 --min-lon 25.3 --max-lon 25.5 --radius 15.0 --output santorini_40x40.txt --delay 200
```

## Strategic Locations

### Strait of Gibraltar
**Features:** Europe-Africa crossing, Mediterranean-Atlantic connection, Rock of Gibraltar, strategic naval chokepoint

```bash
./generate_geo_grid_with_elevation.swift --rows 50 --cols 70 --min-lat 35.8 --max-lat 36.2 --min-lon -5.6 --max-lon -5.0 --radius 15.0 --output gibraltar_50x70.txt --delay 200
```

### Dardanelles (Turkey)
**Features:** Historic strait, Mediterranean-Black Sea connection, Gallipoli Peninsula, ancient Troy region

```bash
./generate_geo_grid_with_elevation.swift --rows 60 --cols 50 --min-lat 39.9 --max-lat 40.5 --min-lon 26.2 --max-lon 26.8 --radius 15.0 --output dardanelles_60x50.txt --delay 200
```

### Panama Canal Zone
**Features:** Caribbean-Pacific connection, hills, Gatun Lake, historic canal route, tropical terrain

```bash
./generate_geo_grid_with_elevation.swift --rows 60 --cols 40 --min-lat 8.8 --max-lat 9.5 --min-lon -80.0 --max-lon -79.4 --radius 15.0 --output panama_60x40.txt --delay 200
```

### Singapore & Strait of Malacca
**Features:** Strategic maritime chokepoint, island city-state, tropical terrain, major shipping lanes

```bash
./generate_geo_grid_with_elevation.swift --rows 50 --cols 50 --min-lat 1.15 --max-lat 1.50 --min-lon 103.6 --max-lon 104.1 --radius 15.0 --output singapore_50x50.txt --delay 200
```

## Desert & Canyon Regions

### Grand Canyon, Arizona
**Features:** Massive canyon, Colorado River, stratified rock layers, dramatic elevation changes (rim to river ~5000ft)

```bash
./generate_geo_grid_with_elevation.swift --rows 70 --cols 70 --min-lat 36.0 --max-lat 36.5 --min-lon -112.5 --max-lon -111.8 --radius 15.0 --output grand_canyon_70x70.txt --delay 200
```

### Petra, Jordan
**Features:** Desert canyons, rock-cut architecture region, Wadi Musa valley, ancient trade routes

```bash
./generate_geo_grid_with_elevation.swift --rows 50 --cols 50 --min-lat 30.2 --max-lat 30.5 --min-lon 35.3 --max-lon 35.6 --radius 15.0 --output petra_50x50.txt --delay 200
```

### Atacama Desert Coast, Chile
**Features:** World's driest desert, coastal cliffs, Pacific Ocean, dramatic arid landscape

```bash
./generate_geo_grid_with_elevation.swift --rows 60 --cols 60 --min-lat -23.9 --max-lat -23.3 --min-lon -70.6 --max-lon -70.0 --radius 15.0 --output atacama_60x60.txt --delay 200
```

## Historic Battle Sites & Strategic Terrain

### Thermopylae, Greece
**Features:** Historic mountain pass, narrow coastal passage, mountains to sea, ancient defensive position

```bash
./generate_geo_grid_with_elevation.swift --rows 40 --cols 40 --min-lat 38.7 --max-lat 38.9 --min-lon 22.4 --max-lon 22.7 --radius 15.0 --output thermopylae_40x40.txt --delay 200
```

### Normandy Beaches (D-Day)
**Features:** Coastal cliffs, beaches, bocage country, historic invasion site, Channel crossing point

```bash
./generate_geo_grid_with_elevation.swift --rows 50 --cols 70 --min-lat 49.2 --max-lat 49.5 --min-lon -1.3 --max-lon -0.5 --radius 15.0 --output normandy_50x70.txt --delay 200
```

### Gettysburg, Pennsylvania
**Features:** Rolling hills, ridgelines (Cemetery Ridge, Seminary Ridge), strategic high ground, farmland terrain

```bash
./generate_geo_grid_with_elevation.swift --rows 50 --cols 50 --min-lat 39.7 --max-lat 40.0 --min-lon -77.4 --max-lon -77.1 --radius 15.0 --output gettysburg_50x50.txt --delay 200
```

### Agincourt, France
**Features:** Muddy fields between forests, historic battle terrain, gentle rolling landscape

```bash
./generate_geo_grid_with_elevation.swift --rows 40 --cols 40 --min-lat 50.4 --max-lat 50.6 --min-lon 2.0 --max-lon 2.3 --radius 15.0 --output agincourt_40x40.txt --delay 200
```

## Lake Regions

### Lake Geneva (Switzerland/France)
**Features:** Alpine lake, mountains surrounding, Swiss and French Alps, Rhine drainage

```bash
./generate_geo_grid_with_elevation.swift --rows 60 --cols 80 --min-lat 46.2 --max-lat 46.6 --min-lon 6.1 --max-lon 6.9 --radius 15.0 --output lake_geneva_60x80.txt --delay 200
```

### Lake Tahoe (California/Nevada)
**Features:** High-altitude alpine lake, Sierra Nevada mountains, crystal clear water, ski areas

```bash
./generate_geo_grid_with_elevation.swift --rows 60 --cols 60 --min-lat 38.9 --max-lat 39.3 --min-lon -120.2 --max-lon -119.8 --radius 15.0 --output lake_tahoe_60x60.txt --delay 200
```

### Lake Baikal, Russia
**Features:** World's deepest lake, mountains, Siberian terrain, unique geography

```bash
./generate_geo_grid_with_elevation.swift --rows 80 --cols 60 --min-lat 51.5 --max-lat 53.0 --min-lon 103.8 --max-lon 105.0 --radius 15.0 --output lake_baikal_80x60.txt --delay 200
```

## River Valleys & Gorges

### Columbia River Gorge (Oregon/Washington)
**Features:** Dramatic gorge, waterfalls, elevation transition from Cascades to coast, wind gap

```bash
./generate_geo_grid_with_elevation.swift --rows 50 --cols 80 --min-lat 45.5 --max-lat 45.8 --min-lon -122.2 --max-lon -121.2 --radius 15.0 --output columbia_gorge_50x80.txt --delay 200
```

### Rhine Gorge, Germany
**Features:** Steep vineyard slopes, medieval castles, narrow river valley, dramatic cliffs

```bash
./generate_geo_grid_with_elevation.swift --rows 70 --cols 40 --min-lat 50.0 --max-lat 50.5 --min-lon 7.5 --max-lon 7.9 --radius 15.0 --output rhine_gorge_70x40.txt --delay 200
```

### Three Gorges, China (Yangtze)
**Features:** Massive gorges, dam site, dramatic river valley, steep mountains

```bash
./generate_geo_grid_with_elevation.swift --rows 80 --cols 60 --min-lat 30.5 --max-lat 31.3 --min-lon 110.0 --max-lon 111.0 --radius 15.0 --output three_gorges_80x60.txt --delay 200
```

## Polar Regions

### Ushuaia, Argentina (Tierra del Fuego)
**Features:** Southernmost city, Beagle Channel, mountains meeting sea, Drake Passage proximity

```bash
./generate_geo_grid_with_elevation.swift --rows 50 --cols 60 --min-lat -55.0 --max-lat -54.6 --min-lon -68.5 --max-lon -67.9 --radius 15.0 --output ushuaia_50x60.txt --delay 200
```

### Svalbard, Norway
**Features:** Arctic archipelago, glaciers, fjords, polar terrain, midnight sun/polar night

```bash
./generate_geo_grid_with_elevation.swift --rows 60 --cols 60 --min-lat 78.0 --max-lat 78.5 --min-lon 14.0 --max-lon 15.0 --radius 15.0 --output svalbard_60x60.txt --delay 200
```

## Usage Tips

### Grid Size Recommendations
- **Small detailed areas** (cities, straits): 40x40 to 50x50
- **Medium regions** (metro areas, valleys): 60x60 to 70x70
- **Large regions** (countries, mountain ranges): 80x80 to 100x100

### Delay Parameter
- `--delay 200`: Standard (recommended for most uses)
- `--delay 100`: Faster (risk of API throttling)
- `--delay 300`: Slower (more respectful to API, use for large grids)

### Radius Parameter
- `--radius 10`: High detail, many small hexes
- `--radius 15`: Standard detail (recommended)
- `--radius 20`: Lower detail, larger hexes (good for continental scale)
- `--radius 25`: Very low detail, largest hexes

### Custom Regions
To create your own region:
1. Find coordinates on Google Maps (right-click → coordinates)
2. Determine bounding box (min/max lat/lon)
3. Choose appropriate grid size based on area
4. Use formula: ~0.5° per 50km (rough approximation)

### Coordinate Tips
- **Latitude**: Positive = North, Negative = South (range: -90 to +90)
- **Longitude**: Positive = East, Negative = West (range: -180 to +180)
- **Order matters**: min < max for both lat and lon
- **Aspect ratio**: Adjust rows/cols to match geographic shape
  - Taller regions: more rows than cols
  - Wider regions: more cols than rows

## Map Collection Ideas

### "Seven Continents" Collection
Generate representative terrain from each continent showing unique geographic features.

### "Historic Battles" Collection
All the famous battle sites with strategic terrain features.

### "Coastal Capitals" Collection
Major world capitals on coastlines with dramatic harbor geography.

### "Mountain Passes" Collection
Historic and strategic mountain passes throughout history.

### "Island Nations" Collection
Island geography from around the world (UK, Japan, Philippines, Indonesia, etc.).

---

*Generated maps are in the HexMagic terrain format and can be loaded directly into the visualization system.*
