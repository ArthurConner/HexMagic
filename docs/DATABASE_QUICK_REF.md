# HexMagic Database Quick Reference

Quick reference for common database operations. For complete documentation, see `DatabaseSchema.md`.

---

## Setup

```python
from HexMagic.database import GeoStorage

# Use default path (~/.hexmagic/data/hexmagic.db)
storage = GeoStorage()

# Use custom path
storage = GeoStorage(custom_path="/path/to/db.sqlite")
```

---

## Basic Operations

### Save Terrain
```python
result = storage.save_world(terrain, name="My World")
world_id = result.id
print(f"Status: {result.status}, {result.context}")
# Output: "Status: saved, 5000 hexes"
```

### Load Terrain
```python
result = storage.load_world(world_id)
terrain = result.data
print(f"Status: {result.status}, {result.context}")
# Output: "Status: loaded, 5000 hexes"
```

### Save Weather
```python
# Compute weather first
terrain.compute_temperature()
terrain.compute_precipitation()
terrain.compute_climate()

# Save to database
result = storage.save_weather(terrain, world_id, season="annual")
```

### Load Weather
```python
# Load terrain
terrain = storage.load_world(world_id).data

# Load weather into terrain
storage.load_weather(world_id, terrain, season="annual")

# Now terrain.fields has: temperature, precipitation, etc.
```

---

## Temporal Queries

### Save Versions
```python
import time

# Version 1
result = storage.save_world(terrain, name="World v1")
world_id = result.id
time_v1 = int(time.time())

time.sleep(1)  # Wait a bit

# Modify and save version 2
terrain.elevations[100] = 50.0
storage.save_world(terrain, name="World v2")
time_v2 = int(time.time())
```

### Load Specific Version
```python
# Load version 1 (as it was at time_v1)
terrain_v1 = storage.load_world(world_id, as_of=time_v1).data

# Load latest version
terrain_latest = storage.load_world(world_id).data

# Load weather at specific time
storage.load_weather(world_id, terrain, season="annual", as_of=time_v1)
```

---

## Region Extraction

### Extract Circular Region
```python
result = storage.extract_region(
    world_id=1,
    center_q=10,
    center_r=-5,
    center_s=-5,
    rings=20,     # 20 hex rings around center
    padding=1     # Extra ring for context
)
region_terrain = result.data

# Render region
region_terrain.colorMap()
```

---

## Multi-Scale Terrain

### Setup Generator
```python
from HexMagic.database import ChunkedTerrainGenerator

storage = GeoStorage()
gen = ChunkedTerrainGenerator(
    storage,
    coarse_radius=100,   # Overview hex size
    fine_radius=10,      # Detail hex size
    chunk_rings=20,      # Hexes per chunk
    halo_rings=5         # Extra for edges
)
```

### Generate Large World
```python
from HexMagic.primitives import MapRect, MapCord, MapSize

bounds = MapRect(MapCord(0,0), MapSize(4000, 4000))

# Generate world in phases (coarse + chunks)
coarse_id = gen.generate_world(
    bounds,
    num_plates=20,
    ocean_fraction=0.4,
    oceanic_sides=['W', 'E'],
    compute_weather=True,
    progress_callback=lambda i, total, msg: print(f"{i}/{total}")
)
```

### Load Chunks
```python
from HexMagic.primitives import HexPosition

# Load chunk at position
position = HexPosition(100, -50, -50)
terrain = gen.load_chunk_at(position)

# Or get chunk reference first
chunk = gen.world_to_chunk_ref(position)
terrain = gen.load_chunk(chunk)
```

---

## Result Objects

All database operations return named tuples:

### SaveResult
```python
SaveResult(id, status, context)
```
- `id`: World ID (or record count for weather)
- `status`: `'saved'`, `'error'`
- `context`: Human-readable message

### LoadResult
```python
LoadResult(data, status, context)
```
- `data`: Loaded Terrain object (or None)
- `status`: `'loaded'`, `'empty'`, `'not_found'`, `'error'`, `'extracted'`
- `context`: Human-readable message

---

## Database Schema

### Tables

**TerrainWorld** - Metadata for terrain instances
```python
id, name, hex_radius, nrows, ncols, 
sea_level, elevation_delta, extras, created, modified
```

**HexData** - Individual hex terrain data
```python
id, world_id, q, r, s, grid_index, elevation,
latitude, longitude, distance_from_coast, modified
```

**HexWeather** - Weather/climate data
```python
id, world_id, q, r, s, temperature, precipitation,
humidity, climate_pet, aridity_index, 
temp_seasonality, precip_seasonality, season, modified
```

**User** - User accounts
```python
id, username, email, password, created, 
sessionID, activeWorld
```

---

## Indices

**Spatial lookups:**
```sql
idx_hex_coords ON hex_data(world_id, q, r, s)
idx_weather_coords ON hex_weather(world_id, q, r, s)
```

**Temporal queries:**
```sql
idx_hex_temporal ON hex_data(world_id, q, r, s, modified DESC)
idx_weather_temporal ON hex_weather(world_id, q, r, s, modified DESC)
```

**Season filtering:**
```sql
idx_weather_season ON hex_weather(world_id, season)
```

---

## Testing

### Use Temporary Database
```python
from HexMagic.database import GeoStorageDebugger

with GeoStorageDebugger(keep_on_error=True) as debugger:
    storage = debugger.server
    
    # Run tests
    result = storage.save_world(terrain, name="Test")
    assert result.status == 'saved'
    
    # Database auto-cleaned on success
    # Preserved on failure (if keep_on_error=True)
```

---

## Common Patterns

### Create → Save → Load → Modify → Save
```python
# Create
terrain = TerraDemo().bayArea_map()

# Save
world_id = storage.save_world(terrain, name="Bay Area").id

# Load
terrain = storage.load_world(world_id).data

# Modify
terrain.elevations[100] = 50.0

# Save again (creates new version)
storage.save_world(terrain, name="Bay Area v2")
```

### Terrain + Weather Workflow
```python
# Create and save terrain
terrain = TerraDemo().bayArea_map()
world_id = storage.save_world(terrain, name="Bay Area").id

# Compute and save weather
terrain.compute_temperature()
terrain.compute_precipitation()
terrain.compute_climate()
storage.save_weather(terrain, world_id, season="annual")

# Later: Load terrain + weather
terrain = storage.load_world(world_id).data
storage.load_weather(world_id, terrain, season="annual")

# terrain.fields now has all weather data
```

### Multi-Season Weather
```python
# Annual average
terrain.compute_weather()
storage.save_weather(terrain, world_id, season="annual")

# Summer (month=6)
terrain.compute_weather(month=6)
storage.save_weather(terrain, world_id, season="summer")

# Winter (month=12)
terrain.compute_weather(month=12)
storage.save_weather(terrain, world_id, season="winter")

# Load specific season
storage.load_weather(world_id, terrain, season="summer")
```

---

## Coordinate Systems

**Cube Coordinates (q, r, s):**
- Universal addressing across all grids
- `q + r + s = 0` (constraint)
- Used for database keys

**Grid Index:**
- Array index (0 to len(hexes)-1)
- Grid-specific
- Used for numpy arrays

**Conversions:**
```python
# Grid index → HexPosition
pos = terrain.hexGrid.index_to_hexposition(idx)

# HexPosition → Grid index
idx = terrain.hexGrid.hexposition_to_index(pos)

# Database stores both for efficiency
```

---

## Error Handling

```python
result = storage.load_world(world_id)

if result.status == 'loaded':
    terrain = result.data
    # Use terrain
elif result.status == 'not_found':
    print(f"World {world_id} not found")
elif result.status == 'error':
    print(f"Error: {result.context}")
```

---

## See Also

- `DatabaseSchema.md` - Complete schema documentation
- `DATABASE_EXTENSION_GUIDE.md` - How to add new tables
- `schema.md` - Overview of all schema documents
- `HexMagic/database.py` - Source code
