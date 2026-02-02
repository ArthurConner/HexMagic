# HexMagic Project Overview

## Project Summary

HexMagic is a hex-based terrain generation and visualization system designed for creating realistic geographic worlds. The project combines procedural generation, real-world geographic data, climate modeling, and game mechanics.

## Core Architecture

### Layer 1: Foundation (HexMagic/*.py)
**Core Data Structures:**
- `HexPosition` - Cube coordinate system (q, r, s) for universal hex addressing
- `HexGrid` - Grid management with row/col ↔ index ↔ HexPosition conversions
- `HexRegion` - Collections of hexes with spatial operations

**Terrain System:**
- `Terrain` - Elevation data + fields (temperature, precipitation, etc.)
- `Geology` - Tectonic plates, watersheds, basins
- `Climate` - Köppen climate classification, weather patterns
- Real-world data integration via `GeoData` class

**Key Operations:**
- Procedural generation via tectonic plates (`Terrain.fromSeeds`)
- Real-world location loading (`TerraDemo` class with 7+ locations)
- Scale transforms (downsample, crop, regional extraction)
- Climate/weather computation with realistic physics

### Layer 2: Visualization (HexMagic/plots/*.py)
**SVG Rendering:**
- `SVGBuilder` - Pattern-based visualization system
- `TerrainPatterns` - Dots, waves, climate patterns
- Multi-layer rendering (terrain, watersheds, climate, etc.)
- Export to SVG for printing/web display

**Regional Views:**
- `crop_to_centered_grid()` - Extract regions with index mapping
- Viewport management for saved views
- Print templates (letter, A4, poster sizes)

### Layer 3: Game Mechanics (HexMagic/game/*.py)
**Game Objects:**
- `GameBoard` - Complete game state
- `Kingdom` - Player civilizations with territories
- `Piece` - Units/agents with movement, vision, combat (see PieceDesign.md)
- `CountryDetails` - Region management and zoom views

**Data Persistence:**
- FastLite/SQLite database backing
- `store.py` - Database patterns and helpers
- Multi-user support with per-user view states

### Layer 4: Web Interface (HexMagic/game/*.py + future)
**Current:**
- FastHTML-based web routes
- User authentication
- Game/world browsing

**Planned (see TerrainSchema_FastLite.md):**
- Multi-player game hosting
- Interactive viewport controls
- Overlay toggles (climate, trade routes, political borders)

## Database Schemas

### 1. Core Library Schema (schemaMain.md)
**Purpose:** Jupyter notebooks, terrain generation, library usage

**Tables:**
- `TerrainWorld` - Complete terrain+geology pairs
- `HexData` - Optional normalized hex data for spatial queries
- `Plate` / `Watershed` - Geological features
- `WorldTemplate` - Pre-built worlds (7 real-world locations + procedural)
- `Viewport` - Saved region definitions
- `ScaleTransform` - Multi-resolution scale relationships

**Key Features:**
- Template library with Bay Area, California, Maui, Japan/Korea, etc.
- Regional extraction by HexPosition + rings
- Rectangular crops for printing
- Multi-scale transforms (downsample with bidirectional region mapping)

### 2. Web Game Schema (TerrainSchema_FastLite.md)
**Purpose:** Multi-user web games

**Tables:**
- `World` / `Game` - Separate world definition from game state
- `User` / `GamePlayer` - Authentication and player data
- `ViewState` - Per-user UI state (zoom, center, overlays)
- `Kingdom` / `Territory` - Game civilizations
- `Piece` - Game units (see PieceDesign.md)

**Key Features:**
- Multiple games can use same world
- Per-user viewport state persistence
- Save/load game state
- Web route integration with FastHTML

### 3. Game Pieces Schema (PieceDesign.md)
**Purpose:** Unit/agent system for gameplay

**Dataclass:**
- `Piece` with attributes: size, health, sight, memory, movement, goals, personality
- Movement system with terrain costs and pathfinding
- Vision/fog of war with memory decay
- Combat resolution
- Settlement/harvesting/spawning
- AI planning with personality weights

## Key Workflows

### Terrain Generation Workflow
```python
# 1. Generate or load terrain
terrain, plates = Terrain.fromSeeds(bounds, radius=15, num_plates=12)
# OR
terrain = TerraDemo().bayArea_map()

# 2. Compute climate/weather
terrain.compute_temperature()
terrain.compute_precipitation()
terrain.compute_climate()

# 3. Create geology
geology = Geology(terrain, plates=plates, name="World")
geology.compute_watersheds()

# 4. Visualize
terrain.colorMap()
terrain.add_climate_overlay()

# 5. Save to database
db = TerrainDB()
world_id = db.save_world(terrain, geology, name="My World")
```

### Multi-Scale Workflow
```python
# 1. Generate large world
large_terrain, plates = Terrain.fromSeeds(large_bounds, num_plates=25)
large_world_id = db.save_world(large_terrain, name="Large Continent")

# 2. Create downsampled version for climate work
small_world_id, transform_id = db.save_downsampled_world(
    large_world_id, scale=0.25, sample_radius=2
)

# 3. Work with small version
small_terrain, _ = db.load_world(small_world_id)
small_terrain.compute_climate()

# 4. Define regions on small terrain
tropical_hexes = set(np.where(small_terrain.fields['climate'] == 0)[0])

# 5. Map back to large terrain
transform = db.transforms[transform_id]
large_tropical_hexes = db.map_region_from_scale(
    transform, tropical_hexes, expand=True
)
```

### Regional Extraction Workflow
```python
# 1. Load world
terrain, geology = db.get_template(1)  # Bay Area

# 2. Extract centered region
detail_terrain, mapper = db.extract_region(
    world_id=1,
    center_q=10, center_r=-5, center_s=-5,
    rings=20,
    padding=2
)

# 3. OR extract rectangular region for printing
print_terrain, mapper = db.extract_rectangle(
    world_id=1,
    center_q=0, center_r=0, center_s=0,
    width_hexes=60, height_hexes=40,
    orientation='landscape'
)

# 4. Save as viewport
viewport_id = db.create_viewport(
    world_id=1,
    name="Detail View",
    center_q=10, center_r=-5, center_s=-5,
    shape="circle",
    rings=20
)
```

### Web Game Workflow
```python
# 1. Create world (or use template)
world_id = create_world_from_terrain(terrain)

# 2. Create game
game_id = create_game(world_id, name="Epic Campaign")

# 3. Add players
add_player_to_game(game_id, user_id, kingdom_name="Empire")

# 4. Initialize view state
create_view_state(game_id, user_id, center_q=0, center_r=0)

# 5. Game loop
# - Load game state
# - Update pieces (movement, combat, etc.)
# - Save game state
# - Update view states
```

## Coordinate Systems

### HexPosition (q, r, s) - Universal Cube Coordinates
- Used everywhere for hex addressing
- Constraint: q + r + s = 0
- Distance: `abs(q1-q2) + abs(r1-r2) + abs(s1-s2)) / 2`
- Grid-independent (same position works across different grids)

### Grid Index - Linear Array Index
- 0 to len(hexes)-1
- Used for array access (elevations[idx], fields['temp'][idx])
- Grid-specific (index 100 in one grid ≠ index 100 in another)

### Row/Col - Grid Coordinates
- Row: 0 to nRows-1
- Col: 0 to nCols-1 (offset per row)
- Grid-specific
- Useful for rectangular operations

### Conversions
```python
# Index ↔ HexPosition
pos = grid.index_to_hexposition(idx, origin_index=0)
idx = grid.hexposition_to_index(pos, origin_index=0)

# Index ↔ Row/Col
row, col = grid.index_to_row_col(idx)
idx = grid.row_col_to_index(row, col)

# Relative positioning
pos = grid.index_to_hexposition(idx, origin_index=center_idx)  # Relative to center
```

## Important Design Patterns

### Encode/Decode Pattern
All major classes support serialization:
```python
# Encode to string
data = terrain.encode()

# Decode from string
terrain = Terrain.decode(data)
```

Used for:
- Database storage (terrain_data, geology_data columns)
- Network transmission
- File export

### FastLite Database Pattern
```python
from fastlite import database
from dataclasses import dataclass

@dataclass
class MyTable:
    id: int = None
    field1: str = ""
    field2: int = 0

db = database("path/to/db.sqlite")
table = db.create(MyTable, pk='id', if_not_exists=True, transform=True)

# Insert
result = table.insert(MyTable(field1="value", field2=42))

# Query
rows = table.rows_where('field2 > ?', [10])
```

### Patch Pattern (nbdev)
Methods added via `@patch` decorator:
```python
from fastcore.utils import patch

@patch
def new_method(self: Terrain, arg1, arg2):
    """Add method to existing class."""
    pass
```

Allows modular code organization across notebooks.

### Index Mapper Pattern
When cropping/transforming grids, return mapping function:
```python
new_grid, new_region, index_mapper = region.crop_to_centered_grid()

# Map data from old to new
for new_idx in range(len(new_grid.hexes)):
    old_idx = index_mapper(new_idx)
    if old_idx >= 0:
        new_data[new_idx] = old_data[old_idx]
```

## Technology Stack

**Core:**
- Python 3.x
- NumPy (array operations)
- Dataclasses (data structures)
- nbdev (notebook-driven development)

**Database:**
- SQLite (via sqlite-utils)
- FastLite (dataclass ↔ database mapping)

**Web:**
- FastHTML (web framework)
- HTMX (interactivity)

**Visualization:**
- SVG generation (custom SVGBuilder)
- Pattern-based rendering

**Geographic Data:**
- SRTM elevation data
- Real-world coordinate mapping

## File Organization

```
HexMagic/
├── HexMagic/           # Core library
│   ├── core.py         # HexPosition, HexGrid
│   ├── terrain.py      # Terrain class
│   ├── geology.py      # Geology, tectonic plates
│   ├── climate.py      # Climate classification
│   ├── weather.py      # Weather/precipitation
│   ├── water/          # Watersheds, drainage
│   ├── voronoi.py      # Procedural generation
│   ├── plots/          # Visualization
│   │   ├── svg.py      # SVG rendering
│   │   ├── region.py   # HexRegion operations
│   │   └── patterns.py # TerrainPatterns
│   └── game/           # Game mechanics
│       ├── store.py    # Database patterns
│       ├── gameboard.py
│       ├── kingdom.py
│       └── piece.py
├── nbs/                # Jupyter notebooks (source via nbdev)
│   ├── PieceDesign.md
│   ├── TerrainSchema_FastLite.md
│   ├── schemaMain.md
│   └── *.ipynb
├── docs/               # Documentation
├── patterns/           # SVG pattern library
├── tmp/                # Temporary files
├── llms.txt            # AI-friendly project summary
└── .warpindexignore    # Indexing exclusions
```

## Real-World Templates

Pre-built in `WorldTemplate` table:
1. **Bay Area** - San Francisco Bay, coastal, medium complexity
2. **California** - Full coast SD to SF, large, high complexity
3. **Maui** - Hawaiian island, volcanic, simple
4. **Japan & Korea** - Archipelago and peninsula, complex
5. **Normandy** - D-Day beaches, coastal France, medium
6. **Hong Kong** - Pearl River Delta, urban coastal
7. **Sydney** - Sydney Harbor, coastal Australia

All accessible via:
```python
db = TerrainDB()
templates = db.list_templates(featured_only=True)
terrain, geology = db.get_template(template_id)
```

## Common Operations Reference

### Find Hexes by Criteria
```python
# By elevation
coastal = terrain.find_region_at_level(0)  # Sea level
mountains = set(np.where(terrain.elevations > 2000)[0])

# By climate
tropical = set(np.where(terrain.fields['climate'] == Climate.TROPICAL.value)[0])

# By distance from hex
center_pos = HexPosition(0, 0, 0)
nearby = set()
for idx in range(len(grid.hexes)):
    pos = grid.index_to_hexposition(idx)
    if pos.distance(center_pos) <= 10:
        nearby.add(idx)
```

### Regional Operations
```python
region = HexRegion(hexes=hex_set, hexGrid=grid)

# Centroid
center_idx = region.centroid_hex()

# Boundary
boundary_hexes = region.boundary()

# Neighbors
expanded = region.expand(rings=2)

# Crop to new grid
new_grid, new_region, mapper = region.crop_to_centered_grid(padding=1)
```

### Field Operations
```python
# Compute fields
terrain.compute_temperature(base_temp_north=12, base_temp_south=20)
terrain.compute_precipitation(wind_dir=270.0, wind_speed=10.0)
terrain.compute_climate()

# Access fields
temps = terrain.fields['temperature']
precip = terrain.fields['precipitation']

# Query
hot_hexes = set(np.where(temps > 25)[0])
wet_hexes = set(np.where(precip > 1000)[0])
```

## Key Insights for Future Conversations

1. **HexPosition is the Universal Coordinate** - Always use (q,r,s) for cross-grid operations
2. **Index Mapping is Critical** - When transforming grids, always track old→new mappings
3. **Scale Transforms Enable Multi-Resolution** - Large worlds can be downsampled, regions mapped bidirectionally
4. **Database Backing is Optional** - encode/decode still works, database adds querying
5. **Two Schema Worlds** - Core library (schemaMain.md) vs Web game (TerrainSchema_FastLite.md)
6. **FastLite Pattern** - Dataclass + `db.create()` + `transform=True`
7. **Visualization is Pattern-Based** - TerrainPatterns generates SVG patterns, overlays compose them
8. **Real-World + Procedural** - Both workflows supported equally

## Current Development Status

**Completed:**
- Core terrain/geology system
- Climate modeling
- Real-world data integration
- SVG visualization
- Basic game mechanics
- Database schemas designed (3 documents)
- Multi-scale transform system

**In Progress:**
- Full database implementation
- Web game interface
- Piece/unit system integration

**Next Steps:**
1. Implement `TerrainDB` class from schemaMain.md
2. Build `ScaleTransform` table and methods
3. Create Jupyter notebook demonstrating multi-scale workflow
4. Integrate Piece system with GameBoard
5. Build web routes for game hosting
