# HexMagic Code Patterns Quick Reference

## Coordinate System Conversions

### HexPosition ↔ Index
```python
# Grid index to HexPosition (relative to origin)
pos = grid.index_to_hexposition(idx, origin_index=0)

# HexPosition to grid index (relative to origin)
idx = grid.hexposition_to_index(pos, origin_index=0)

# Relative positioning (useful for regional extraction)
pos = grid.index_to_hexposition(idx, origin_index=center_idx)
idx = grid.hexposition_to_index(pos, origin_index=center_idx)
```

### Index ↔ Row/Col
```python
# Index to row/col
row, col = grid.index_to_row_col(idx)

# Row/col to index
idx = grid.row_col_to_index(row, col)
```

### Distance Calculations
```python
# Between two HexPositions
dist = pos1.distance(pos2)

# Between two indices
pos1 = grid.index_to_hexposition(idx1)
pos2 = grid.index_to_hexposition(idx2)
dist = pos1.distance(pos2)
```

## Terrain Creation Patterns

### From Procedural Generation
```python
from HexMagic.terrain import Terrain
from HexMagic.core import MapRect, MapCord, MapSize

bounds = MapRect(MapCord(0, 0), MapSize(800, 800))
terrain, plates = Terrain.fromSeeds(
    bounds,
    radius=15,           # Hex radius in pixels
    num_plates=12,       # Number of tectonic plates
    seed=42              # Random seed for reproducibility
)
```

### From Real-World Location
```python
from HexMagic.terrain import TerraDemo

td = TerraDemo()

# Available methods
terrain = td.bayArea_map()
terrain = td.california_map()
terrain = td.maui_map()
terrain = td.japan_korea_map()
terrain = td.normandy_map()
terrain = td.hong_kong_map()
terrain = td.sydney_map()
```

### From Database Template
```python
from HexMagic.database import TerrainDB

db = TerrainDB()

# List templates
templates = db.list_templates(featured_only=True)

# Load template
terrain, geology = db.get_template(template_id=1)
```

## Climate and Weather Patterns

### Complete Climate Workflow
```python
# 1. Compute temperature
terrain.compute_temperature(
    base_temp_north=12,   # °C at northern edge
    base_temp_south=20,   # °C at southern edge
    lapse_rate=6.5        # °C per 1000m elevation
)

# 2. Compute precipitation
terrain.compute_precipitation(
    wind_dir=270.0,       # Wind direction (degrees)
    wind_speed=10.0,      # Wind speed (m/s)
    precip_base=0.15      # Base precipitation rate
)

# 3. Classify climate
terrain.compute_climate()

# 4. Add visualization
terrain.add_climate_overlay(layer_name="climate", showLegend=True)
```

### Downsampling for Performance
```python
# Downsample with climate data preserved
small_terrain = terrain.downsample_climate(
    scale=0.5,            # 50% of original size
    sample_radius=1       # Rings to sample around each target hex
)

# Downsample weather only
small_terrain = terrain.shrinkWeather(
    scale=0.33,           # 33% of original size
    sample_radius=2
)
```

## Region Extraction Patterns

### Centered Circular Region
```python
# Define center position
center_q, center_r, center_s = 10, -5, -5
center_idx = grid.hexposition_to_index(HexPosition(center_q, center_r, center_s))

# Collect hexes within radius
region_hexes = set()
for idx in range(len(grid.hexes)):
    pos = grid.index_to_hexposition(idx, origin_index=center_idx)
    if pos.distance(HexPosition.origin()) <= 20:  # 20 rings
        region_hexes.add(idx)

# Create region
region = HexRegion(hexes=region_hexes, hexGrid=grid)

# Crop to centered grid
new_grid, new_region, index_mapper = region.crop_to_centered_grid(padding=2)

# Map data to new grid
new_terrain = Terrain(...)
new_terrain.hexGrid = new_grid
new_terrain.elevations = np.zeros(len(new_grid.hexes))

for new_idx in range(len(new_grid.hexes)):
    old_idx = index_mapper(new_idx)
    if old_idx >= 0:
        new_terrain.elevations[new_idx] = terrain.elevations[old_idx]
```

### Rectangular Region (for Printing)
```python
# Define center
center_row, center_col = grid.index_to_row_col(center_idx)

# Calculate bounds
width_hexes, height_hexes = 60, 40
min_row = max(0, center_row - height_hexes // 2)
max_row = min(grid.nRows - 1, center_row + height_hexes // 2)
min_col = max(0, center_col - width_hexes // 2)
max_col = min(grid.nCols - 1, center_col + width_hexes // 2)

# Collect hexes
region_hexes = set()
for row in range(min_row, max_row + 1):
    for col in range(min_col, max_col + 1):
        idx = grid.row_col_to_index(row, col)
        if idx >= 0:
            region_hexes.add(idx)

region = HexRegion(hexes=region_hexes, hexGrid=grid)
```

## Database Operations

### Save World
```python
from HexMagic.database import TerrainDB
from datetime import datetime

db = TerrainDB()

world_id = db.save_world(
    terrain=terrain,
    geology=geology,
    name="My World",
    description="A procedurally generated world",
    tags="procedural,large,archipelago",
    geo_location_name="",
    is_template=False,
    created_by="user"
)
```

### Load World
```python
# By ID
terrain, geology = db.load_world(world_id=1)

# By template
terrain, geology = db.get_template(template_id=1)

# Search
results = db.search_worlds(search_term="bay", tags=["coastal"])
```

### Multi-Scale Operations
```python
# Create downsampled version
small_world_id, transform_id = db.save_downsampled_world(
    source_world_id=world_id,
    scale=0.25,
    sample_radius=2,
    name="Quarter Scale Version"
)

# Map regions between scales
transform = db.transforms[transform_id]

# Forward: large → small
small_hexes = db.map_region_to_scale(transform, large_hexes)

# Reverse: small → large (with expansion)
large_hexes = db.map_region_from_scale(
    transform, 
    small_hexes, 
    expand=True  # Include all contributing hexes
)

# Map individual positions
target_q, target_r, target_s = db.map_hexposition_to_scale(
    transform, source_q, source_r, source_s
)
```

### Viewport Management
```python
# Create viewport
viewport_id = db.create_viewport(
    world_id=world_id,
    name="Bay Area Detail",
    center_q=10, center_r=-5, center_s=-5,
    shape="circle",
    rings=20,
    description="Focused view of bay area",
    tags="detail,bay"
)

# Load terrain from viewport
terrain = db.load_viewport(viewport_id)
```

## Finding Hexes by Criteria

### By Elevation
```python
# Sea level hexes
ocean_hexes = terrain.find_region_at_level(0)

# Mountains (above threshold)
mountain_mask = terrain.elevations > 2000
mountain_hexes = set(np.where(mountain_mask)[0])

# Elevation range
mid_elevation = set(np.where(
    (terrain.elevations > 500) & (terrain.elevations < 1500)
)[0])
```

### By Climate/Weather Fields
```python
from HexMagic.climate import Climate

# By climate type
tropical_mask = terrain.fields['climate'] == Climate.TROPICAL.value
tropical_hexes = set(np.where(tropical_mask)[0])

# By temperature
hot_hexes = set(np.where(terrain.fields['temperature'] > 25)[0])

# By precipitation
wet_hexes = set(np.where(terrain.fields['precipitation'] > 1000)[0])

# Combined conditions
hot_wet = set(np.where(
    (terrain.fields['temperature'] > 25) & 
    (terrain.fields['precipitation'] > 1000)
)[0])
```

### By Distance from Feature
```python
# Distance from coast
if 'distance_to_coast' in terrain.fields:
    coastal_hexes = set(np.where(terrain.fields['distance_to_coast'] <= 2)[0])
    inland_hexes = set(np.where(terrain.fields['distance_to_coast'] > 5)[0])

# Distance from specific hex
center_pos = HexPosition(0, 0, 0)
nearby_hexes = set()
for idx in range(len(grid.hexes)):
    pos = grid.index_to_hexposition(idx)
    if pos.distance(center_pos) <= 10:
        nearby_hexes.add(idx)
```

## HexRegion Operations

### Creation and Basic Operations
```python
from HexMagic.plot.region import HexRegion

# Create region
region = HexRegion(hexes=hex_set, hexGrid=grid)

# Centroid
center_idx = region.centroid_hex()

# Boundary hexes
boundary = region.boundary()

# Expand by rings
expanded_region = region.expand(rings=2)

# Contract by rings
contracted_region = region.contract(rings=1)
```

### Region Algebra
```python
# Union
combined = region1.union(region2)

# Intersection
overlap = region1.intersection(region2)

# Difference
remaining = region1.difference(region2)
```

### Region Analysis
```python
# Size
hex_count = len(region.hexes)

# Compactness (0-1, higher = more circular)
compactness = region.compactness()

# Perimeter
perimeter_count = len(region.boundary())
```

## Visualization Patterns

### Basic Terrain Map
```python
# Color by elevation
terrain.colorMap()

# Show
terrain.hexGrid.builder.show()

# Export
terrain.hexGrid.builder.export("output.svg")
```

### Climate Overlay
```python
# Ensure climate computed
if 'climate' not in terrain.fields:
    terrain.compute_climate()

# Add overlay
terrain.add_climate_overlay(
    layer_name="climate",
    showLegend=True,
    tile_size=300,
    background=None
)

terrain.hexGrid.builder.show()
```

### Custom Overlays
```python
from HexMagic.plot.patterns import TerrainPatterns
from HexMagic.plot.svg import StyleCSS

# Create patterns
patGen = TerrainPatterns(terrain)
patterns = patGen.ballDensity(n=5, fills=colors, prefix="custom")

# Add to builder
for pattern in patterns:
    terrain.hexGrid.builder.add_definition(pattern)

# Apply to regions
for region in regions:
    overlay = region.draw()
    terrain.hexGrid.builder.adjust("custom_layer", overlay)
```

### Watershed Visualization
```python
from HexMagic.geology import Geology

geology = Geology(terrain, plates=plates, name="World")
geology.compute_watersheds()

# Draw watersheds
basins = geology.basins
overlay = basins.draw_watersheds()
terrain.hexGrid.builder.adjust("watersheds", overlay)
```

## Encode/Decode Pattern

### Terrain
```python
# Encode
terrain_data = terrain.encode()

# Decode
terrain = Terrain.decode(terrain_data)
```

### Geology
```python
# Encode
geology_data = geology.encode()

# Decode
geology = Geology.decode(geology_data)
```

### HexRegion
```python
# Encode
region_data = region.encode()

# Decode
region = HexRegion.decode(region_data, hexGrid=grid)
```

### ClimatePreset
```python
# Encode
preset_data = climate_preset.encode()

# Decode
preset = ClimatePreset.decode(preset_data)
```

## FastLite Database Pattern

### Define Dataclass Table
```python
from dataclasses import dataclass
from fastlite import database

@dataclass
class MyTable:
    id: int = None
    name: str = ""
    value: int = 0
    data: str = ""  # Can store encoded objects
    created: int = 0
```

### Create Database and Tables
```python
db = database("path/to/db.sqlite")
my_table = db.create(MyTable, pk='id', if_not_exists=True, transform=True)
```

### Insert Data
```python
from datetime import datetime

record = MyTable(
    name="Example",
    value=42,
    data=terrain.encode(),
    created=int(datetime.now().timestamp())
)

result = my_table.insert(record)
record_id = result.id if hasattr(result, 'id') else result['id']
```

### Query Data
```python
# By ID
record = my_table[record_id]

# Where clause
records = list(my_table.rows_where('value > ?', [10]))

# All records
all_records = list(my_table.rows)

# Count
count = db.execute("SELECT COUNT(*) FROM my_table").fetchone()[0]
```

### Update Data
```python
# Update fields
my_table.update(record_id, value=100)

# Or modify and re-insert
record = my_table[record_id]
record.value = 100
my_table.update(record_id, **record.__dict__)
```

## Common Field Computations

### Distance from Coast
```python
terrain.compute_distance_from_coast()
# Adds 'distance_to_coast' field
```

### Latitude/Longitude
```python
# Only works if terrain has GeoData
if terrain.geo:
    # Adds 'latitude' and 'longitude' fields
    # Used automatically by temperature/precipitation
```

### Temperature
```python
terrain.compute_temperature(
    base_temp_north=12.0,
    base_temp_south=20.0,
    lapse_rate=6.5  # °C per 1000m
)
# Adds 'temperature' field
```

### Precipitation
```python
terrain.compute_precipitation(
    wind_dir=270.0,      # West wind
    wind_speed=10.0,
    precip_base=0.15,
    nm=0.01,             # Moisture capacity
    hw=2500.0,           # Height scale
    cw=0.004,            # Condensation rate
    conv_time=1200.0,    # Convection time
    fall_time=1200.0     # Fall time
)
# Adds 'precipitation' and 'precip_rate_mmh' fields
```

### Climate Classification
```python
# Requires temperature and precipitation
terrain.compute_temperature()
terrain.compute_precipitation()
terrain.compute_climate()
# Adds 'climate' field (Köppen classification)
```

## Game Object Patterns

### GameBoard Creation
```python
from HexMagic.game.gameboard import GameBoard

board = GameBoard(
    terrain=terrain,
    name="My Game"
)

# Add kingdoms
kingdom = board.add_kingdom(
    name="Empire",
    color="#ff0000",
    capital_hex=center_idx
)
```

### Kingdom Territory Management
```python
# Add territory
kingdom.add_territory(hex_set)

# Remove territory
kingdom.remove_territory(hex_set)

# Check ownership
if kingdom.owns_hex(idx):
    # ...
```

### Piece (Unit) Creation
```python
from HexMagic.game.piece import Piece

piece = Piece(
    id="unit_001",
    hex_position=idx,
    size=10,
    health=100,
    sight=5,           # Vision range
    memory=10,         # Memory duration
    movement=3,        # Movement points
    goals={"explore": 0.5, "defend": 0.3},
    personality={"aggressive": 0.7}
)

# Movement
path = piece.find_path(target_idx, terrain)
piece.move_along_path(path, terrain)

# Vision
visible_hexes = piece.compute_visible_hexes(terrain)
piece.update_memory(visible_hexes)
```

## Performance Patterns

### Large World Handling
```python
# 1. Generate at full resolution
large_terrain, plates = Terrain.fromSeeds(large_bounds, num_plates=30)

# 2. Save to database
db = TerrainDB()
world_id = db.save_world(large_terrain, name="Large World")

# 3. Create downsampled versions
db.save_downsampled_world(world_id, scale=0.5)
db.save_downsampled_world(world_id, scale=0.25)

# 4. Work with appropriate scale
small_terrain, _ = db.load_world(small_world_id)
small_terrain.compute_climate()  # Faster on small version
```

### Spatial Query Optimization
```python
# For very large worlds, populate HexData table
db.populate_hex_data(
    world_id, 
    terrain, 
    include_fields=['temperature', 'elevation']
)

# Query specific regions efficiently
hexes = db.query_region(
    world_id=world_id,
    center_q=0, center_r=0, center_s=0,
    radius=20
)
```

### Batch Operations
```python
# Batch insert
records = [MyTable(name=f"item_{i}", value=i) for i in range(1000)]
my_table.insert_all(records)

# Batch hex data processing
batch = []
batch_size = 1000
for idx in range(len(grid.hexes)):
    # Process hex
    batch.append(hex_data)
    if len(batch) >= batch_size:
        hex_table.insert_all(batch)
        batch = []
if batch:
    hex_table.insert_all(batch)
```
