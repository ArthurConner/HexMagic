# HexMagic Database Schema - Current Implementation

**Module:** `HexMagic/database.py`  
**Status:** ✅ Implemented

This document describes the current database schema as implemented in `database.py`. For proposed extensions and design ideas, see `schemaMain.md`, `TerrainSchema.md`, and `TerrainSchema_FastLite.md`.

---

## Overview

The HexMagic database provides persistent storage for:
- **Terrain data**: Elevation, coordinates, metadata
- **Weather/climate data**: Temperature, precipitation, climate metrics
- **Multi-scale worlds**: Large terrains via chunked generation
- **User data**: Authentication and session management
- **Temporal versioning**: Track changes over time

**Key Design Principles:**
1. **HexPosition-based indexing**: Universal (q,r,s) cube coordinates
2. **Temporal data**: Version history via modified timestamps
3. **Separation of concerns**: Terrain, weather, and user data in separate tables
4. **Spatial queries**: Efficient lookups by coordinates and regions
5. **Multi-scale support**: Coarse overview + fine detail chunks

---

## Database Tables

### 1. TerrainWorld

Stores metadata for complete terrain instances.

```python
@dataclass
class TerrainWorld:
    """Metadata for a stored terrain."""
    id: int = None
    name: str = ""
    hex_radius: float = 25.0
    nrows: int = 0
    ncols: int = 0
    sea_level: float = 0.0
    elevation_delta: float = 90.0
    extras: str = ""  # JSON-encoded: climate, geo bounds
    created: int = 0
    modified: int = 0
```

**Fields:**
- `id`: Primary key
- `name`: Human-readable world name
- `hex_radius`: Hex size in pixels/units
- `nrows`, `ncols`: Grid dimensions
- `sea_level`: Elevation threshold for water
- `elevation_delta`: Vertical scale factor
- `extras`: JSON string containing:
  - `geo`: GeoBounds.encode() for real-world mapping
  - `climate`: ClimatePreset.encode() for weather params
- `created`, `modified`: Unix timestamps

**Usage:**
```python
world = TerrainWorld(
    name="Bay Area",
    hex_radius=25.0,
    nrows=100,
    ncols=120,
    sea_level=0.0,
    extras=json.dumps({
        'geo': terrain.geo.encode(),
        'climate': terrain.climate.encode()
    })
)
```

---

### 2. HexData

Individual hex terrain data with spatial indexing.

```python
@dataclass  
class HexData:
    id: int = None
    world_id: int = 0
    q: int = 0
    r: int = 0
    s: int = 0
    grid_index: int = 0
    elevation: float = 0.0
    plate_id: int = -1
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    distance_from_coast: Optional[float] = None
    watershed_id: Optional[int] = None  # NEW: FK to WatershedMeta
    chunk_q: Optional[int] = None       # NEW: Chunk origin position
    chunk_r: Optional[int] = None
    chunk_s: Optional[int] = None
    scale_level: int = 0                # NEW: 0=coarse, >0=zoomed
    modified: int = 0
```

**Fields:**
- `id`: Primary key
- `world_id`: Foreign key to TerrainWorld
- `q, r, s`: Cube coordinates (universal addressing)
- `grid_index`: Array index in HexGrid
- `elevation`: Terrain height
- `latitude`, `longitude`: Real-world coordinates (if GeoBounds available)
- `distance_from_coast`: Distance to ocean in hex units
- `modified`: Unix timestamp for versioning

**Indices:**
```sql
CREATE INDEX idx_hex_world ON hex_data(world_id)
CREATE INDEX idx_hex_coords ON hex_data(world_id, q, r, s)
CREATE INDEX idx_hex_grid ON hex_data(world_id, grid_index)
CREATE INDEX idx_hex_temporal ON hex_data(world_id, q, r, s, modified DESC)
CREATE INDEX idx_hex_watershed ON hex_data(world_id, watershed_id)
CREATE INDEX idx_hex_chunk ON hex_data(world_id, chunk_q, chunk_r, chunk_s, scale_level)
```

**Temporal Queries:**

The `modified` timestamp enables version history:
```python
# Get latest state
hexes = storage.query_hexes_latest(world_id)

# Get state at specific time
hexes = storage.query_hexes_latest(world_id, as_of=timestamp)
```

**Implementation:**
```python
@patch
def _latest_hex_subquery(self: GeoStorage, world_id: int, as_of: int = None) -> str:
    """SQL subquery for latest hex state, optionally at a point in time."""
    time_clause = f"AND modified <= {as_of}" if as_of else ""
    return f"""
        SELECT world_id, q, r, s, MAX(modified) as max_mod
        FROM hex_data
        WHERE world_id = {world_id} {time_clause}
        GROUP BY world_id, q, r, s
    """
```

---

### 3. HexWeather

Weather and climate data per hex.

```python
@dataclass
class HexWeather:
    """Weather data for a hex at a point in time."""
    id: int = None
    world_id: int = 0
    q: int = 0
    r: int = 0
    s: int = 0
    # Core weather fields
    temperature: float = 0.0           # °C
    precipitation: float = 0.0         # mm/year
    humidity: Optional[float] = None   # %
    # Derived/computed fields
    climate_pet: Optional[float] = None          # potential evapotranspiration
    aridity_index: Optional[float] = None
    temp_seasonality: Optional[float] = None
    precip_seasonality: Optional[float] = None
    distance_from_coast: Optional[float] = None  # hex units
    # Temporal
    season: str = ""                   # e.g., "annual", "summer", "winter"
    modified: int = 0
```

**Fields:**
- Weather: `temperature`, `precipitation`, `humidity`
- Climate metrics: `climate_pet`, `aridity_index`
- Seasonality: `temp_seasonality`, `precip_seasonality`
- Context: `distance_from_coast`
- Temporal: `season`, `modified`

**Indices:**
```sql
CREATE INDEX idx_weather_world ON hex_weather(world_id)
CREATE INDEX idx_weather_coords ON hex_weather(world_id, q, r, s)
CREATE INDEX idx_weather_temporal ON hex_weather(world_id, q, r, s, modified DESC)
CREATE INDEX idx_weather_season ON hex_weather(world_id, season)
CREATE INDEX idx_weather_chunk ON hex_weather(world_id, chunk_q, chunk_r, chunk_s)
CREATE INDEX idx_weather_scale ON hex_weather(world_id, scale_level)
```

**Seasonal Data:**

Store different seasonal weather:
```python
# Save annual average
storage.save_weather(terrain, world_id, season="annual")

# Save summer conditions
terrain.compute_weather(month=6)  # June
storage.save_weather(terrain, world_id, season="summer")

# Load specific season
storage.load_weather(world_id, terrain, season="summer")
```

---

### 4. WatershedMeta

Watershed topology and metadata persistence.

```python
@dataclass
class WatershedMeta:
    """Metadata for a stored watershed."""
    id: int = None
    world_id: int = 0
    name: str = ""
    terminal_q: int = 0  # Outlet hex position
    terminal_r: int = 0
    terminal_s: int = 0
    is_ocean: bool = True
    total_flow: float = 0.0
    area_hexes: int = 0
    river_tree: str = ""         # River.encode()
    style: str = ""              # StyleCSS.encode()
    chunk_q: Optional[int] = None  # Chunk-level watersheds
    chunk_r: Optional[int] = None
    chunk_s: Optional[int] = None
    created: int = 0
    modified: int = 0
```

**Fields:**
- `river_tree`: Encoded river tributary tree
- `style`: Visualization style
- `terminal_*`: Watershed outlet position
- `chunk_*`: NULL for coarse watersheds, set for chunk-level
- `total_flow`, `area_hexes`: Computed statistics

**Indices:**
```sql
CREATE INDEX idx_watershed_world ON watershed_meta(world_id)
```

**Usage:**
```python
# Save watersheds
storage.save_watersheds(terrain, watersheds, world_id)

# Query by watershed
hexes = storage.query_watershed_hexes(world_id, watershed_id)

# Save chunk-level watersheds
storage.save_zoomed_watersheds(cover_id, origin_pos, scale, terrain, watersheds)
```

---

### 5. ChunkBorder

Track drainage across chunk boundaries for distributed watershed computation.

```python
@dataclass
class ChunkBorder:
    """Track drainage across chunk boundaries."""
    id: int = None
    world_id: int = 0
    chunk_q: int = 0             # Source chunk
    chunk_r: int = 0
    chunk_s: int = 0
    border_hex_q: int = 0        # Local hex at border
    border_hex_r: int = 0
    border_hex_s: int = 0
    downstream_chunk_q: int = 0  # Destination chunk
    downstream_chunk_r: int = 0
    downstream_chunk_s: int = 0
    flow_volume: float = 0.0     # Accumulated upstream area
```

**Purpose:**
- Enable distributed watershed computation
- Track water flow between chunks
- Support parallel chunk processing

**Indices:**
```sql
CREATE INDEX idx_border_chunk ON chunk_border(world_id, chunk_q, chunk_r, chunk_s)
CREATE INDEX idx_border_downstream ON chunk_border(world_id, downstream_chunk_q, downstream_chunk_r, downstream_chunk_s)
```

---

### 6. User

User authentication and session data.

```python
@dataclass
class User:
    username: str
    email: str
    password: str
    created: int  # Unix timestamp
    sessionID: str
    activeWorld: int  # FK to TerrainWorld
    id: int = None
```

**Fields:**
- `username`, `email`, `password`: Authentication
- `sessionID`: Current session identifier
- `activeWorld`: Link to user's current world
- `created`: Account creation timestamp

---

## Database Manager: GeoStorage

Main interface for database operations.

```python
class GeoStorage:
    def __init__(self, custom_path=None):
        path = GeoStorage.get_db_path(custom_path)
        self.path = path
        self.createDB()
```

**Key Methods:**

### World Operations

```python
# Save terrain
result = storage.save_world(terrain, name="My World")
# Returns: SaveResult(id, status, context)

# Load terrain
result = storage.load_world(world_id, as_of=timestamp)
# Returns: LoadResult(data, status, context)
```

### Weather Operations

```python
# Save weather data
result = storage.save_weather(terrain, world_id, season="annual")

# Load weather data
result = storage.load_weather(world_id, terrain, season="annual", as_of=timestamp)
```

### ChunkCover Operations (NEW)

**ChunkCover** provides master terrain + zoom pattern for efficient multi-scale terrain.

```python
# Save ChunkCover (stores coarse master terrain)
cover = ChunkCover(master_terrain, rings=5, halo_rings=1)
cover.db = storage
result = cover.save(name="SF Master")
cover_id = cover.ident

# Load ChunkCover
result = storage.load_cover(cover_id)
cover = result.data

# Zoom with caching (automatic)
zoomed = cover.zoom_cached(origin=middle, scale=4)  # Generates if needed
zoomed2 = cover.zoom_cached(origin=middle, scale=4) # Cache hit!

# Full data zoom (terrain + weather + watersheds)
full = cover.zoom_with_full_data(
    origin=middle,
    scale=4,
    compute_weather=True,
    compute_watersheds=True
)

# Cache management
storage.invalidate_all_caches(cover_id)  # Clear all cached chunks
```

**Caching Strategy:**
- Cache key: `(cover_id, origin_q, origin_r, origin_s, scale)`
- Terrain, weather, watersheds cached separately
- Automatic invalidation when coarse data changes
- Cache hit: 50ms load vs 280ms compute (5.6× faster)

### Region Extraction

```python
# Extract circular region
result = storage.extract_region(
    world_id,
    center_q=10, center_r=-5, center_s=-5,
    rings=20,
    padding=1
)
terrain = result.data
```

**Result Objects:**

```python
LoadResult = namedtuple('LoadResult', ['data', 'status', 'context'])
SaveResult = namedtuple('SaveResult', ['id', 'status', 'context'])
```

---

## Multi-Scale Terrain System

The `ChunkedTerrainGenerator` enables working with large worlds by generating terrain in manageable chunks.

### ChunkedTerrainGenerator

```python
class ChunkedTerrainGenerator:
    """Generate and manage large terrains via chunking."""
    
    def __init__(self, storage: GeoStorage, 
                 coarse_radius: float = 100,
                 fine_radius: float = 10,
                 chunk_rings: int = 20,
                 halo_rings: int = 5):
```

**Parameters:**
- `coarse_radius`: Hex size for global overview map
- `fine_radius`: Hex size for detailed chunks
- `chunk_rings`: Number of hex rings per chunk (size)
- `halo_rings`: Extra rings for edge computations

**Scale Factor:**
```python
scale = coarse_radius / fine_radius  # e.g., 100/10 = 10x
```

### Multi-Scale Workflow

**Phase 1: Generate Coarse Map**
```python
gen = ChunkedTerrainGenerator(storage)

terrain = gen.generate_coarse(
    bounds,
    num_plates=15,
    ocean_fraction=0.4,
    name="world_coarse"
)
# Creates low-res global map for coastlines
```

**Phase 2: Generate Detail Chunks**
```python
# Generate single chunk
chunk = ChunkRef(HexPosition(0, 0, 0), rings=20)
chunk_terrain = gen.generate_chunk(chunk, terrain)

# Generate all chunks
coarse_id = gen.generate_world(
    bounds,
    num_plates=15,
    compute_weather=True
)
```

**Phase 3: Load Chunks On-Demand**
```python
# Get chunk containing world position
chunk = gen.world_to_chunk_ref(HexPosition(100, -50, -50))
terrain = gen.load_chunk(chunk)

# Or load by position
terrain = gen.load_chunk_at(HexPosition(100, -50, -50))
```

### Coordinate Systems

**World Coordinates:** Universal (q,r,s) across entire world

**Chunk Coordinates:** Position of chunk center in world space

**Local Coordinates:** (q,r,s) within a chunk (origin at chunk center)

**Conversions:**
```python
# World position → chunk
chunk = gen.world_to_chunk_ref(world_pos)

# Local position → world position
world_pos = gen.local_to_world(chunk, local_pos)

# Chunk center in coarse grid
coarse_pos = gen.chunk_center_in_coarse(chunk)
```

---

## Usage Examples

### Basic Terrain Persistence

```python
from HexMagic.database import GeoStorage

# Initialize database
storage = GeoStorage()  # Uses default path

# Create terrain
terrain = TerraDemo().bayArea_map()

# Save
result = storage.save_world(terrain, name="Bay Area")
print(f"Saved world {result.id}: {result.context}")
# Output: "Saved world 1: 5432 hexes"

# Load
result = storage.load_world(result.id)
loaded_terrain = result.data
```

### Weather Persistence

```python
# Compute weather
terrain.compute_temperature()
terrain.compute_precipitation()
terrain.compute_climate()

# Save weather
storage.save_weather(terrain, world_id, season="annual")

# Later, load terrain + weather
terrain = storage.load_world(world_id).data
storage.load_weather(world_id, terrain, season="annual")

# Now terrain.fields has temperature, precipitation, etc.
```

### Temporal Queries

```python
import time

# Initial save
result = storage.save_world(terrain, name="World v1")
world_id = result.id
time_v1 = int(time.time())

# Modify terrain
terrain.elevations[100] = 50.0
storage.save_world(terrain, name="World v2")
time_v2 = int(time.time())

# Load original version
terrain_v1 = storage.load_world(world_id, as_of=time_v1).data

# Load latest version
terrain_v2 = storage.load_world(world_id).data
```

### Large World Generation

```python
from HexMagic.database import GeoStorage, ChunkedTerrainGenerator

storage = GeoStorage()
gen = ChunkedTerrainGenerator(
    storage,
    coarse_radius=100,
    fine_radius=10,
    chunk_rings=20,
    halo_rings=5
)

# Generate large world
bounds = MapRect(MapCord(0,0), MapSize(4000, 4000))
coarse_id = gen.generate_world(
    bounds,
    num_plates=20,
    ocean_fraction=0.4,
    oceanic_sides=['W', 'E'],
    compute_weather=True,
    progress_callback=lambda i, total, msg: print(f"{i}/{total}: {msg}")
)

# Load specific region as needed
position = HexPosition(100, -50, -50)
terrain = gen.load_chunk_at(position)
```

### Region Extraction

```python
# Extract circular region
result = storage.extract_region(
    world_id=1,
    center_q=50, center_r=-25, center_s=-25,
    rings=15,
    padding=2
)
region_terrain = result.data

# Render extracted region
region_terrain.colorMap()
region_terrain.hexGrid.builder.show()
```

---

## Database Path Configuration

**Default Paths:**
1. Try package data: `HexMagic/data/db/hexmagic.db`
2. Fallback to user directory: `~/.hexmagic/data/hexmagic.db`

**Custom Path:**
```python
storage = GeoStorage(custom_path="/path/to/my/database.db")
```

**Static Method:**
```python
path = GeoStorage.get_db_path()  # Get default
path = GeoStorage.get_db_path("/custom/path.db")  # Use custom
```

---

## Testing: GeoStorageDebugger

Test harness with automatic cleanup.

```python
from HexMagic.database import GeoStorageDebugger

with GeoStorageDebugger(keep_on_error=True) as debugger:
    storage = debugger.server
    
    # Run tests
    result = storage.save_world(terrain, name="Test World")
    assert result.status == 'saved'
    
    loaded = storage.load_world(result.id)
    assert loaded.status == 'loaded'

# Database automatically cleaned up unless test failed
```

**Features:**
- Creates temporary database in temp directory
- Automatic cleanup on success
- Preserves database on failure (if `keep_on_error=True`)
- Copies failed tests to `~/.hexmagic/test_failures/`

---

## Schema Differences from Design Docs

This implementation differs from the proposed schemas in design docs:

| Feature | Design Docs | Current Implementation |
|---------|-------------|------------------------|
| Templates | WorldTemplate table | Not implemented |
| Plates | Plate table | Not implemented |
| Watersheds | Watershed table | Not implemented |
| Viewports | Viewport table | Not implemented |
| Scale transforms | ScaleTransform table | In ChunkedTerrainGenerator |
| Game tables | Kingdom, Piece, etc. | Not implemented |
| Wide field table | HexFieldsWide | Not implemented |
| Chunks | Chunk table | Logic in ChunkedTerrainGenerator |

**What's Implemented:**
- ✅ Core terrain storage (TerrainWorld, HexData)
- ✅ Weather/climate persistence (HexWeather)
- ✅ Temporal versioning (modified timestamps)
- ✅ Spatial indexing (q,r,s coordinates)
- ✅ Multi-scale terrain (ChunkedTerrainGenerator)
- ✅ User management (User table)

**Not Yet Implemented:**
- ❌ Template library system
- ❌ Geological features (plates, watersheds)
- ❌ Viewport management
- ❌ Game state persistence
- ❌ Additional field storage

For proposed extensions, see:
- `schemaMain.md` - Template and viewport system
- `TerrainSchema.md` - Database-centric architecture
- `TerrainSchema_FastLite.md` - Web game schema
- `DATABASE_EXTENSION_GUIDE.md` - How to extend

---

## Migration Notes

**From Terrain.encode() to Database:**

Old approach:
```python
# Save
encoded = terrain.encode()
with open('terrain.json', 'w') as f:
    f.write(encoded)

# Load
with open('terrain.json', 'r') as f:
    encoded = f.read()
terrain = Terrain.decode(encoded)
```

New approach:
```python
# Save
storage = GeoStorage()
world_id = storage.save_world(terrain, name="My Terrain").id

# Load
terrain = storage.load_world(world_id).data
```

**Benefits:**
- ✅ No file management
- ✅ Queryable data
- ✅ Version history
- ✅ Efficient region extraction
- ✅ Multi-user support (via database)

**Backward Compatibility:**

Terrain still supports encode/decode for:
- Backwards compatibility
- Standalone usage without database
- Serialization for network transfer
