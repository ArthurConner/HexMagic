# Terrain Schema Design Document

## Overview

This document proposes a database-centric architecture for terrain storage that enables:
- **Larger worlds**: Store massive maps beyond memory limits
- **Efficient queries**: Load only needed regions for rendering/computation
- **Universal coordinates**: Use HexPosition as universal addressing system
- **Terrain as view**: Keep convenient Terrain object for working, backed by database
- **Multi-resolution**: Support downsampling and different detail levels

## Current State Analysis

### Current Architecture
Currently, Terrain is a monolithic object holding all data in memory:
- `elevations`: numpy array with elevation per hex
- `fields`: dictionary of numpy arrays (temperature, country, soil_type, etc.)
- `hexGrid`: Grid managing hex layout and rendering

**Problems:**
1. All data must fit in memory
2. Loading/saving entire terrain at once is slow
3. No spatial indexing for efficient queries
4. Difficult to stream data for large worlds
5. Redundant storage (database stores encoded string of entire terrain)

### Desired Architecture
- Database stores hex data in normalized tables
- HexPosition serves as universal coordinate system
- Terrain object becomes a "viewport" into the database
- Query by region, load on-demand
- Support multi-resolution levels of detail

---

## Database Schema Design

### Core Tables

#### 1. World Table
Stores world-level metadata and configuration.

```python
@dataclass
class World:
    """Top-level world container."""
    id: int = None
    name: str = ""
    created: int = 0  # Unix timestamp
    modified: int = 0
    
    # World bounds (in universal hex coordinates)
    origin_q: int = 0  # World origin in cube coords
    origin_r: int = 0
    origin_s: int = 0
    extent_rings: int = 100  # How many rings from origin
    
    # Physical/rendering parameters
    hex_radius: float = 25.0  # Default hex size in pixels
    elevation_delta: float = 90.0  # Elevation per level
    sea_level: float = 0.0
    
    # Geographic bounds (optional)
    geo_lat_min: Optional[float] = None
    geo_lat_max: Optional[float] = None
    geo_lon_min: Optional[float] = None
    geo_lon_max: Optional[float] = None
    
    # Climate data (encoded string)
    climate_preset: Optional[str] = None
```

**Suggestions:**
- Add `version` field for schema evolution
- Consider `parent_world_id` for multi-resolution hierarchies
- Add `locked` flag to prevent modification
- Store default color palette references

#### 2. HexCell Table
Core spatial data - one row per hex in the world.

```python
@dataclass
class HexCell:
    """Individual hex cell data."""
    id: int = None
    world_id: int = 0
    
    # Universal coordinates (cube system)
    q: int = 0
    r: int = 0
    s: int = 0
    
    # Core terrain data
    elevation: float = 0.0
    
    # Indexing fields for fast spatial queries
    ring: int = 0  # Distance from origin (for range queries)
    sector: int = 0  # Angular sector (0-5, for directional queries)
```

**Key Design Decisions:**
- Use (world_id, q, r, s) as composite unique key
- Pre-compute `ring` and `sector` for indexing
- Keep core data lean (just elevation)
- Additional fields in separate tables

**Indices:**
```sql
CREATE INDEX idx_hex_coords ON hex_cell(world_id, q, r, s);
CREATE INDEX idx_hex_ring ON hex_cell(world_id, ring);
CREATE INDEX idx_hex_sector ON hex_cell(world_id, sector, ring);
```

**Suggestions:**
- Consider spatial database extensions (PostGIS, SpatiaLite)
- Add `chunk_id` for tiled storage
- Include `modified` timestamp for cache invalidation

#### 3. HexField Table
Flexible key-value storage for arbitrary hex attributes.

```python
@dataclass
class HexField:
    """Named field values for hexes."""
    id: int = None
    hex_id: int = 0  # Foreign key to HexCell
    field_name: str = ""
    value: float = 0.0
```

**Alternative: Wide Table Approach**
For better performance, use typed columns:

```python
@dataclass
class HexFieldsWide:
    """Pre-defined fields for hex data."""
    hex_id: int = None  # FK to HexCell
    
    # Climate/weather
    temperature: Optional[float] = None
    precipitation: Optional[float] = None
    humidity: Optional[float] = None
    
    # Hydrology
    watershed_id: Optional[int] = None
    flow_accumulation: Optional[float] = None
    distance_to_ocean: Optional[float] = None
    soil_type: Optional[int] = None
    
    # Political
    country_id: Optional[int] = None
    province_id: Optional[int] = None
    
    # Vegetation/biome
    biome_type: Optional[int] = None
    forest_density: Optional[float] = None
    
    # Resources
    mineral_richness: Optional[float] = None
    fertility: Optional[float] = None
```

**Trade-offs:**
- **Narrow (HexField)**: Flexible, easy to add fields, slower queries
- **Wide (HexFieldsWide)**: Fast queries, fixed schema, NULL overhead

**Recommendation**: Start with wide table, add extension table for custom fields.

**Indices:**
```sql
-- For wide approach
CREATE INDEX idx_hex_country ON hex_fields_wide(country_id);
CREATE INDEX idx_hex_watershed ON hex_fields_wide(watershed_id);
CREATE INDEX idx_hex_biome ON hex_fields_wide(biome_type);
```

#### 4. Region Table
Named regions for efficient bulk queries.

```python
@dataclass
class Region:
    """Named collection of hexes."""
    id: int = None
    world_id: int = 0
    name: str = ""
    region_type: str = ""  # 'kingdom', 'watershed', 'biome', 'viewport'
    
    # Bounding info for quick rejection
    min_q: int = 0
    max_q: int = 0
    min_r: int = 0
    max_r: int = 0
    min_ring: int = 0
    max_ring: int = 0
    
    # Metadata
    created: int = 0
    modified: int = 0
```

```python
@dataclass
class RegionMember:
    """Many-to-many: regions contain hexes."""
    id: int = None
    region_id: int = 0
    hex_id: int = 0
```

**Suggestions:**
- Pre-compute centroids for fast lookups
- Store perimeter hex list for rendering borders
- Add region hierarchy (provinces in kingdoms)

#### 5. Chunk Table (Optional - For Tiled Storage)
Divide world into fixed-size chunks for better I/O.

```python
@dataclass
class Chunk:
    """Spatial tile containing multiple hexes."""
    id: int = None
    world_id: int = 0
    
    # Chunk addressing
    chunk_q: int = 0  # Chunk coordinates
    chunk_r: int = 0
    chunk_size: int = 32  # Hexes per chunk edge
    
    # Cached bounds
    min_q: int = 0
    max_q: int = 0
    min_r: int = 0
    max_r: int = 0
    
    # Data storage
    elevation_blob: bytes = None  # Compressed numpy array
    fields_blob: bytes = None  # Compressed dict of arrays
    
    # Cache metadata
    loaded: bool = False
    modified: int = 0
```

**Benefits:**
- Load/save chunks instead of individual hexes
- Compress chunk data for storage
- Better cache locality
- Parallel chunk loading

**Trade-offs:**
- More complex query logic
- Must decompose regions into chunks
- Update granularity is chunk-level

---

## Modified Game Tables

### GameBoard Extension

```python
@dataclass
class Game:
    """Existing game table with terrain reference."""
    id: int = None
    user_id: int = 0
    name: str = ""
    
    # Replace board_data string with world reference
    world_id: int = 0  # FK to World
    
    # Game state (kingdoms, turn, etc.) as before
    game_state: str = ""  # Encoded kingdoms, pieces, etc.
    
    is_active: bool = True
    last_modified_by: int = 0
    created: int = 0
    modified: int = 0
```

**Key Change**: Separate terrain data from game state.
- `world_id` points to shared terrain
- Multiple games can share the same world
- `game_state` stores kingdoms, pieces, turn number

### Kingdom Table Extensions

```python
@dataclass
class Kingdom:
    """Kingdom with spatial references."""
    id: int = None
    game_id: int = 0
    country_id: int = 0
    
    # Spatial data now references regions
    region_id: int = 0  # FK to Region table
    
    # Capital hex coordinates (universal)
    capital_q: int = 0
    capital_r: int = 0
    capital_s: int = 0
    
    # Rest as before: name, flag, settlements, etc.
    # ...
```

**Benefits:**
- Kingdom regions stored efficiently in database
- Can query "which kingdom owns hex (q,r,s)?"
- Spatial operations via SQL

### Piece Table (From PieceDesign.md)

```python
@dataclass
class Piece:
    """Game piece with universal coordinates."""
    id: str = ""  # UUID
    game_id: int = 0
    owner_id: int = 0  # Kingdom ID
    
    # Position in universal coordinates
    position_q: int = 0
    position_r: int = 0
    position_s: int = 0
    
    # Attributes as before
    size: int = 100
    health: int = 100
    # ...
```

---

## Terrain Object as Database View

### New Terrain Architecture

The Terrain class becomes a "viewport" that loads data from database on-demand:

```python
class TerrainView:
    """Lightweight terrain viewport backed by database."""
    
    def __init__(self, db: HexServer, world_id: int, 
                 bounds: Optional[HexRegion] = None,
                 cache_size: int = 10000):
        self.db = db
        self.world_id = world_id
        self.bounds = bounds  # None = entire world
        
        # Load world metadata
        self.world = db.get_world(world_id)
        
        # Create hex grid for rendering (doesn't load data yet)
        self.hexGrid = self._create_grid()
        
        # LRU cache for loaded hex data
        self._cache = {}
        self._cache_size = cache_size
        
        # Loaded region tracking
        self._loaded_hexes = set()  # Set of (q,r,s) tuples
        
    def _create_grid(self):
        """Create HexGrid based on world params."""
        # Determine grid size from bounds or world extent
        if self.bounds:
            # Calculate grid size from region
            pass
        else:
            # Use world extent
            size = self.world.extent_rings * 2 * self.world.hex_radius
            bounds = MapRect(MapCord(0,0), MapSize(size, size))
        
        return HexGrid.from_bounds(bounds, radius=self.world.hex_radius)
    
    def load_region(self, region: HexRegion) -> None:
        """Load hex data for a region into cache."""
        hex_positions = region.to_positions()
        
        # Query database for hex data
        hex_data = self.db.query_hexes(
            world_id=self.world_id,
            positions=hex_positions
        )
        
        # Update cache
        for hex_cell in hex_data:
            key = (hex_cell.q, hex_cell.r, hex_cell.s)
            self._cache[key] = hex_cell
            self._loaded_hexes.add(key)
        
        # Evict old entries if cache is full
        self._evict_cache()
    
    def load_ring(self, center: HexPosition, radius: int) -> None:
        """Load all hexes within radius of center."""
        positions = []
        for ring in range(radius + 1):
            positions.extend(center.ring(ring))
        
        region = HexRegion(
            hexes={self.hexGrid.hexposition_to_index(p) for p in positions},
            hexGrid=self.hexGrid
        )
        self.load_region(region)
    
    def get_elevation(self, q: int, r: int, s: int) -> float:
        """Get elevation at hex coordinates (loads if needed)."""
        key = (q, r, s)
        
        if key not in self._cache:
            # Load single hex from database
            hex_data = self.db.query_hexes(
                world_id=self.world_id,
                positions=[HexPosition(q, r, s)]
            )
            if hex_data:
                self._cache[key] = hex_data[0]
            else:
                return 0.0  # Not in world
        
        return self._cache[key].elevation
    
    def set_elevation(self, q: int, r: int, s: int, elevation: float) -> None:
        """Set elevation at hex coordinates."""
        key = (q, r, s)
        
        # Update cache
        if key in self._cache:
            self._cache[key].elevation = elevation
        else:
            # Create new hex cell
            hex_cell = HexCell(
                world_id=self.world_id,
                q=q, r=r, s=s,
                elevation=elevation,
                ring=abs(HexPosition(q, r, s)),
                sector=self._compute_sector(q, r, s)
            )
            self._cache[key] = hex_cell
        
        # Mark as dirty for write-back
        self._mark_dirty(key)
    
    def flush(self) -> None:
        """Write cached changes back to database."""
        dirty_hexes = self._get_dirty()
        self.db.update_hexes(dirty_hexes)
        self._clear_dirty()
    
    def to_numpy_arrays(self) -> tuple[np.ndarray, dict]:
        """Convert loaded region to numpy arrays (for compatibility)."""
        # Extract elevations in grid order
        elevations = np.zeros(len(self.hexGrid.hexes))
        fields = {}
        
        for i, hex_obj in enumerate(self.hexGrid.hexes):
            pos = self.hexGrid.index_to_hexposition(i)
            key = (pos.q, pos.r, pos.s)
            
            if key in self._cache:
                elevations[i] = self._cache[key].elevation
                # Load fields similarly
        
        return elevations, fields
    
    def _evict_cache(self):
        """Evict least recently used entries if cache is full."""
        if len(self._cache) > self._cache_size:
            # Simple FIFO eviction (could use LRU)
            to_evict = len(self._cache) - self._cache_size
            keys = list(self._cache.keys())[:to_evict]
            for key in keys:
                del self._cache[key]
                self._loaded_hexes.discard(key)
```

**Backward Compatibility Layer:**

```python
class Terrain(TerrainView):
    """Backward-compatible Terrain class."""
    
    @property
    def elevations(self) -> np.ndarray:
        """Legacy array access - loads all data if needed."""
        if not self._loaded_hexes:
            self.load_all()
        return self.to_numpy_arrays()[0]
    
    @elevations.setter
    def elevations(self, values: np.ndarray):
        """Legacy array setter."""
        for i, val in enumerate(values):
            pos = self.hexGrid.index_to_hexposition(i)
            self.set_elevation(pos.q, pos.r, pos.s, val)
    
    @property
    def fields(self) -> dict:
        """Legacy fields access."""
        if not self._loaded_hexes:
            self.load_all()
        return self.to_numpy_arrays()[1]
    
    def load_all(self):
        """Load entire world into memory (for legacy code)."""
        # Query all hexes for this world
        all_hexes = self.db.query_hexes(self.world_id)
        for hex_cell in all_hexes:
            key = (hex_cell.q, hex_cell.r, hex_cell.s)
            self._cache[key] = hex_cell
            self._loaded_hexes.add(key)
```

---

## Database Operations

### HexServer Extensions

```python
@patch
def create_world(self: HexServer, name: str, **params) -> int:
    """Create a new world and return world_id."""
    now = int(datetime.now().timestamp())
    
    world = World(
        name=name,
        created=now,
        modified=now,
        **params
    )
    
    result = self.db.t.world.insert(world)
    return result['id']

@patch
def query_hexes(self: HexServer, world_id: int, 
                positions: Optional[List[HexPosition]] = None,
                region_id: Optional[int] = None,
                bounds: Optional[dict] = None) -> List[HexCell]:
    """Query hex cells by various criteria."""
    
    if positions:
        # Direct coordinate query
        conditions = " OR ".join([
            f"(q={p.q} AND r={p.r} AND s={p.s})"
            for p in positions
        ])
        query = f"""
            SELECT * FROM hex_cell 
            WHERE world_id = ? AND ({conditions})
        """
        results = self.db.execute(query, [world_id]).fetchall()
    
    elif region_id:
        # Query by region
        query = """
            SELECT hc.* FROM hex_cell hc
            JOIN region_member rm ON hc.id = rm.hex_id
            WHERE hc.world_id = ? AND rm.region_id = ?
        """
        results = self.db.execute(query, [world_id, region_id]).fetchall()
    
    elif bounds:
        # Query by bounding box
        query = """
            SELECT * FROM hex_cell
            WHERE world_id = ?
            AND q BETWEEN ? AND ?
            AND r BETWEEN ? AND ?
        """
        results = self.db.execute(query, [
            world_id,
            bounds['min_q'], bounds['max_q'],
            bounds['min_r'], bounds['max_r']
        ]).fetchall()
    
    else:
        # Query entire world
        query = "SELECT * FROM hex_cell WHERE world_id = ?"
        results = self.db.execute(query, [world_id]).fetchall()
    
    return [HexCell(**dict(row)) for row in results]

@patch
def update_hexes(self: HexServer, hexes: List[HexCell]) -> None:
    """Bulk update hex cells."""
    with self.db.conn:
        for hex_cell in hexes:
            self.db.execute("""
                INSERT OR REPLACE INTO hex_cell
                (world_id, q, r, s, elevation, ring, sector)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            """, [
                hex_cell.world_id,
                hex_cell.q, hex_cell.r, hex_cell.s,
                hex_cell.elevation,
                hex_cell.ring, hex_cell.sector
            ])

@patch
def create_region(self: HexServer, world_id: int, name: str, 
                 hex_positions: List[HexPosition]) -> int:
    """Create a named region from hex positions."""
    now = int(datetime.now().timestamp())
    
    # Compute bounds
    min_q = min(p.q for p in hex_positions)
    max_q = max(p.q for p in hex_positions)
    min_r = min(p.r for p in hex_positions)
    max_r = max(p.r for p in hex_positions)
    min_ring = min(abs(p) for p in hex_positions)
    max_ring = max(abs(p) for p in hex_positions)
    
    region = Region(
        world_id=world_id,
        name=name,
        min_q=min_q, max_q=max_q,
        min_r=min_r, max_r=max_r,
        min_ring=min_ring, max_ring=max_ring,
        created=now, modified=now
    )
    
    result = self.db.t.region.insert(region)
    region_id = result['id']
    
    # Add members
    for pos in hex_positions:
        # Get hex_id from coordinates
        hex_cell = self.query_hexes(world_id, positions=[pos])[0]
        self.db.t.region_member.insert({
            'region_id': region_id,
            'hex_id': hex_cell.id
        })
    
    return region_id
```

---

## Migration Strategy

### Phase 1: Parallel Implementation
Keep both systems running side-by-side:
1. Add new database tables
2. Implement TerrainView alongside Terrain
3. Write migration utilities
4. Test with small worlds

### Phase 2: Hybrid Approach
Use database for large worlds, memory for small:
```python
def load_terrain(world_id: int, strategy: str = 'auto'):
    world = db.get_world(world_id)
    
    if strategy == 'auto':
        # Decide based on world size
        hex_count = db.count_hexes(world_id)
        if hex_count > 100000:
            return TerrainView(db, world_id)
        else:
            return Terrain.from_database(db, world_id)
    elif strategy == 'database':
        return TerrainView(db, world_id)
    else:
        return Terrain.from_database(db, world_id)
```

### Phase 3: Full Migration
Deprecate old Terrain.encode() format:
1. Migrate existing saved games to new schema
2. Update all code to use TerrainView API
3. Remove legacy encode/decode

---

## Multi-Resolution Support

### Level-of-Detail Hierarchy

```python
@dataclass
class WorldLOD:
    """Level of detail for a world."""
    id: int = None
    world_id: int = 0
    parent_lod_id: Optional[int] = None  # Finer detail level
    
    lod_level: int = 0  # 0 = full detail, 1 = 2x downsampled, etc.
    downsample_factor: int = 1  # 1, 2, 4, 8...
    hex_count: int = 0
```

**Downsampling Strategy:**
- LOD 0: Full resolution (every hex)
- LOD 1: 2x downsample (average 4 hexes → 1)
- LOD 2: 4x downsample (average 16 hexes → 1)
- LOD 3: 8x downsample (average 64 hexes → 1)

```python
@patch
def create_lod(self: HexServer, world_id: int, downsample: int) -> int:
    """Create a downsampled LOD for a world."""
    # Query source hexes
    source_hexes = self.query_hexes(world_id)
    
    # Group hexes by downsample grid
    lod_hexes = {}
    for hex_cell in source_hexes:
        # Map to LOD coordinates
        lod_q = hex_cell.q // downsample
        lod_r = hex_cell.r // downsample
        lod_s = hex_cell.s // downsample
        
        key = (lod_q, lod_r, lod_s)
        if key not in lod_hexes:
            lod_hexes[key] = []
        lod_hexes[key].append(hex_cell)
    
    # Average each LOD cell
    for (q, r, s), cell_group in lod_hexes.items():
        avg_elevation = sum(c.elevation for c in cell_group) / len(cell_group)
        
        lod_hex = HexCell(
            world_id=world_id,
            q=q, r=r, s=s,
            elevation=avg_elevation,
            ring=abs(HexPosition(q, r, s)),
            sector=compute_sector(q, r, s)
        )
        
        self.update_hexes([lod_hex])
    
    # Record LOD metadata
    lod = WorldLOD(
        world_id=world_id,
        lod_level=int(math.log2(downsample)),
        downsample_factor=downsample,
        hex_count=len(lod_hexes)
    )
    return self.db.t.world_lod.insert(lod)['id']
```

---

## Performance Optimizations

### 1. Spatial Indexing

Use R-tree or quadtree indexes for fast spatial queries:
```python
# SpatiaLite extension
self.db.execute("SELECT load_extension('mod_spatialite')")

# Create spatial index
self.db.execute("""
    SELECT CreateSpatialIndex('hex_cell', 'geom')
""")
```

### 2. Chunked Storage

Store hex data in compressed chunks:
```python
def store_chunk(self, chunk_q: int, chunk_r: int, hex_data: dict):
    """Store compressed chunk data."""
    import zlib
    import pickle
    
    # Serialize and compress
    data_bytes = pickle.dumps(hex_data)
    compressed = zlib.compress(data_bytes, level=9)
    
    self.db.t.chunk.insert({
        'world_id': self.world_id,
        'chunk_q': chunk_q,
        'chunk_r': chunk_r,
        'elevation_blob': compressed
    })
```

### 3. Caching Strategy

- Keep recently accessed hexes in memory
- Use LRU eviction when cache is full
- Pre-load adjacent chunks (spatial locality)
- Batch writes to reduce transaction overhead

### 4. Parallel Loading

Load multiple chunks in parallel:
```python
from concurrent.futures import ThreadPoolExecutor

def load_chunks_parallel(self, chunk_ids: List[int]):
    with ThreadPoolExecutor(max_workers=4) as executor:
        futures = [
            executor.submit(self.load_chunk, chunk_id)
            for chunk_id in chunk_ids
        ]
        return [f.result() for f in futures]
```

---

## Example Usage

### Creating a Large World

```python
# Create world metadata
world_id = server.create_world(
    name="Massive Continent",
    origin_q=0, origin_r=0, origin_s=0,
    extent_rings=500,  # 500 rings = ~785,000 hexes
    hex_radius=25.0
)

# Generate terrain procedurally and stream to database
for chunk_q in range(-20, 20):
    for chunk_r in range(-20, 20):
        # Generate chunk data
        chunk_hexes = generate_terrain_chunk(
            chunk_q, chunk_r, size=32
        )
        
        # Write to database
        server.update_hexes(chunk_hexes)
        
        print(f"Wrote chunk ({chunk_q}, {chunk_r})")

# Create downsampled LODs for overview
server.create_lod(world_id, downsample=4)
server.create_lod(world_id, downsample=16)
```

### Loading a Region for Gameplay

```python
# Create terrain view for a specific region
terrain = TerrainView(
    db=server,
    world_id=world_id,
    cache_size=50000
)

# Load player's viewport (10 rings around capital)
capital_pos = HexPosition(50, -25, -25)
terrain.load_ring(capital_pos, radius=10)

# Now terrain acts like normal Terrain object
# but only has loaded hexes in memory
elevation = terrain.get_elevation(50, -25, -25)
terrain.set_elevation(51, -25, -26, 100.0)

# Write changes back
terrain.flush()
```

### Multi-Player Shared World

```python
# Multiple games share same world
world_id = server.create_world(name="Shared World")

# Player 1's game
game1_id = server.start_from_world(
    session_id="player1",
    world_id=world_id,
    starting_position=(0, 0, 0)
)

# Player 2's game
game2_id = server.start_from_world(
    session_id="player2",
    world_id=world_id,
    starting_position=(100, -50, -50)
)

# Both games reference same terrain database
# Game-specific data (kingdoms, pieces) in separate tables
```

---

## Benefits Summary

1. **Scalability**: Store worlds with millions of hexes
2. **Memory efficiency**: Load only needed regions
3. **Performance**: Spatial indices for fast queries
4. **Flexibility**: Universal coordinate system enables sub-regions
5. **Multi-resolution**: LOD support for overview/detail
6. **Sharing**: Multiple games can share same world
7. **Streaming**: Generate terrain on-demand
8. **Persistence**: No more giant encoded strings

## Trade-offs

1. **Complexity**: More moving parts than monolithic Terrain
2. **Query overhead**: Database calls slower than memory access
3. **Caching needed**: Must manage cache carefully
4. **Migration effort**: Requires updating existing code
5. **Testing burden**: More scenarios to test

## Recommended Implementation Order

1. ✅ Design schema (this document)
2. Create database tables in HexServer
3. Implement HexCell, Region CRUD operations
4. Build TerrainView with caching
5. Add backward-compatible Terrain wrapper
6. Migrate one existing system (e.g., Kingdom regions)
7. Test with small and large worlds
8. Implement chunked storage
9. Add LOD support
10. Full migration of GameBoard/Kingdom
