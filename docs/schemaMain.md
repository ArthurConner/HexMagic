# HexMagic Core Database Schema

## Overview

This document defines the database schema for the core HexMagic system - the foundational terrain generation and geological modeling. This focuses on `Terrain`, `Geology`, and spatial data structures, designed for use in Jupyter notebooks and library usage.

**Scope:**
- Core terrain and geology data
- HexPosition-based spatial indexing
- Template/preset management
- **Excludes**: Game mechanics (kingdoms, pieces) - see TerrainSchema_FastLite.md
- **Drops**: Terraform class (animation-focused, not core data)

**Key Principle**: Terrain + Geology pair is the fundamental unit. Everything builds on this foundation.

---

## Design Philosophy

1. **Terrain + Geology = World**: These two classes work together to describe a complete world
2. **Hybrid Storage**: Keep encode/decode for portability, add database for spatial queries
3. **Template-Centric**: Worlds are often created from templates (real-world locations)
4. **Notebook-Friendly**: Database backing enables working with larger worlds in Jupyter
5. **Spatial Indexing**: HexPosition (q,r,s) as universal coordinate system

---

## Core Tables

### 1. TerrainWorld

Stores complete terrain data with geological features.

```python
from fastlite import *
from dataclasses import dataclass
from typing import Optional

@dataclass
class TerrainWorld:
    """A complete world with terrain and geology."""
    id: int = None
    name: str = ""
    description: str = ""
    
    # Core data (encoded)
    terrain_data: str = ""  # Terrain.encode()
    geology_data: str = ""  # Geology.encode() 
    
    # World parameters (for quick access without decoding)
    hex_count: int = 0
    nrows: int = 0
    ncols: int = 0
    hex_radius: float = 25.0
    elevation_delta: float = 90.0
    sea_level: float = 0.0
    
    # Geographic bounds (if real-world location)
    geo_lat_min: Optional[float] = None
    geo_lat_max: Optional[float] = None
    geo_lon_min: Optional[float] = None
    geo_lon_max: Optional[float] = None
    geo_location_name: Optional[str] = None  # "San Francisco Bay", "Maui", etc.
    
    # Climate preset (encoded)
    climate_preset: Optional[str] = None  # ClimatePreset.encode()
    climate_name: Optional[str] = None  # "tropical", "mediterranean", etc.
    
    # Generation parameters (for reproducibility)
    num_plates: int = 0
    seed: Optional[int] = None
    formation_type: Optional[str] = None  # "ridge", "volcanic", etc.
    
    # Tags for searching
    tags: str = ""  # Comma-separated: "real-world,bay,coastal"
    
    # Metadata
    created: int = 0
    modified: int = 0
    created_by: str = ""  # User or system
    is_template: bool = False
```

**Usage:**
- Primary storage for Terrain + Geology pairs
- Templates are `is_template=True`
- Can be searched by tags, location, or parameters

### 2. HexData (Optional - For Spatial Queries)

Normalized hex-level data for efficient spatial queries.

```python
@dataclass
class HexData:
    """Individual hex data for spatial queries."""
    id: int = None
    world_id: int = 0  # FK to TerrainWorld
    
    # Universal coordinates
    q: int = 0
    r: int = 0
    s: int = 0
    
    # Grid coordinates (for reference)
    grid_index: int = 0
    row: int = 0
    col: int = 0
    
    # Core terrain fields
    elevation: float = 0.0
    
    # Spatial indexing helpers
    ring: int = 0  # Distance from origin
    sector: int = 0  # Angular sector (0-5)
    
    # Common fields (can be NULL)
    temperature: Optional[float] = None
    precipitation: Optional[float] = None
    distance_to_ocean: Optional[float] = None
    watershed_id: Optional[int] = None
    plate_id: Optional[int] = None
    soil_type: Optional[int] = None
    biome: Optional[str] = None
```

**When to Populate:**
- Large worlds (>50k hexes) where spatial queries are needed
- Real-time exploration/editing scenarios
- Analysis notebooks that need to query specific regions

**Indices:**
```python
db.execute("CREATE INDEX IF NOT EXISTS idx_hex_coords ON hex_data(world_id, q, r, s)")
db.execute("CREATE INDEX IF NOT EXISTS idx_hex_ring ON hex_data(world_id, ring)")
db.execute("CREATE INDEX IF NOT EXISTS idx_hex_elevation ON hex_data(world_id, elevation)")
db.execute("CREATE INDEX IF NOT EXISTS idx_hex_watershed ON hex_data(world_id, watershed_id)")
```

### 3. Plate

Tectonic plates for procedural generation.

```python
@dataclass
class Plate:
    """Tectonic plate data."""
    id: int = None
    world_id: int = 0
    
    plate_index: int = 0  # Plate number in this world
    kind: str = "continental"  # "continental", "oceanic"
    
    # Region data (encoded HexRegion)
    region_data: str = ""
    
    # Plate properties
    center_q: int = 0
    center_r: int = 0
    center_s: int = 0
    hex_count: int = 0
    
    # Formation parameters
    age: str = "mature"  # "young", "mature", "ancient"
    elevation_scale: float = 1.0
```

### 4. Watershed

Drainage basins for hydrology.

```python
@dataclass
class Watershed:
    """Watershed/drainage basin."""
    id: int = None
    world_id: int = 0
    
    watershed_index: int = 0
    
    # Region data (encoded HexRegion)
    region_data: str = ""
    
    # Properties
    terminal_hex_q: int = 0
    terminal_hex_r: int = 0
    terminal_hex_s: int = 0
    is_ocean: bool = False
    
    # Flow statistics
    max_flow: float = 0.0
    total_flow: float = 0.0
    hex_count: int = 0
```

### 5. WorldTemplate

Pre-built worlds for quick starts.

```python
@dataclass
class WorldTemplate:
    """Template linking to a TerrainWorld."""
    id: int = None
    world_id: int = 0  # FK to TerrainWorld
    
    # Template metadata
    category: str = "real-world"  # "real-world", "procedural", "fantasy"
    display_name: str = ""
    description: str = ""
    preview_image: Optional[str] = None  # Path to preview SVG/PNG
    
    # Usage hints
    recommended_for: str = ""  # "coastal,islands,tutorial"
    difficulty: str = "medium"  # "easy", "medium", "hard"
    
    # Ordering
    sort_order: int = 0
    is_featured: bool = False
    
    created: int = 0
```

**Pre-populated Templates:**
- Bay Area
- California coast
- Maui
- Japan & Korea
- Normandy
- Hong Kong
- Sydney
- + Procedural examples (volcanic island, archipelago, continent)

### 6. Viewport

Saved viewport/region definitions for quick access.

```python
@dataclass
class Viewport:
    """Saved viewport for quick access to regions."""
    id: int = None
    world_id: int = 0
    name: str = ""
    description: str = ""
    
    # Center position (universal coordinates)
    center_q: int = 0
    center_r: int = 0
    center_s: int = 0
    
    # Shape
    shape: str = "circle"  # 'circle' or 'rectangle'
    
    # For circular viewports
    rings: int = 10
    
    # For rectangular viewports
    width_hexes: int = 0
    height_hexes: int = 0
    orientation: str = "landscape"  # 'landscape' or 'portrait'
    
    # Metadata
    created: int = 0
    tags: str = ""
```

**Usage:**
- Save regions of interest ("Bay Area Detail", "Print Region")
- Quick access to frequently used sub-regions
- Print-ready rectangular extracts

---

## Database Manager

### TerrainDB Class

```python
from fastlite import *
from pathlib import Path
import numpy as np

class TerrainDB:
    """Database manager for HexMagic core data."""
    
    def __init__(self, db_path: Optional[str] = None):
        if db_path is None:
            db_path = self._get_default_path()
        
        self.path = db_path
        self.db = database(self.path)
        self._create_tables()
    
    @staticmethod
    def _get_default_path() -> str:
        """Get default database path."""
        try:
            from importlib import resources
            db_dir = resources.files('HexMagic').joinpath('data/db')
            db_path = Path(db_dir) / 'terrain.db'
            db_path.parent.mkdir(parents=True, exist_ok=True)
            return str(db_path)
        except (PermissionError, OSError):
            data_dir = Path.home() / '.hexmagic' / 'terrain'
            data_dir.mkdir(parents=True, exist_ok=True)
            return str(data_dir / 'terrain.db')
    
    def _create_tables(self):
        """Create all tables."""
        self.worlds = self.db.create(TerrainWorld, pk='id', if_not_exists=True, transform=True)
        self.hex_data = self.db.create(HexData, pk='id', if_not_exists=True, transform=True)
        self.plates = self.db.create(Plate, pk='id', if_not_exists=True, transform=True)
        self.watersheds = self.db.create(Watershed, pk='id', if_not_exists=True, transform=True)
        self.templates = self.db.create(WorldTemplate, pk='id', if_not_exists=True, transform=True)
        self.viewports = self.db.create(Viewport, pk='id', if_not_exists=True, transform=True)
        
        self._create_indices()
        self._populate_templates()
    
    def _create_indices(self):
        """Create database indices."""
        # World queries
        self.db.execute("CREATE INDEX IF NOT EXISTS idx_world_template ON terrain_world(is_template)")
        self.db.execute("CREATE INDEX IF NOT EXISTS idx_world_tags ON terrain_world(tags)")
        self.db.execute("CREATE INDEX IF NOT EXISTS idx_world_location ON terrain_world(geo_location_name)")
        
        # Hex data spatial queries
        self.db.execute("CREATE INDEX IF NOT EXISTS idx_hex_coords ON hex_data(world_id, q, r, s)")
        self.db.execute("CREATE INDEX IF NOT EXISTS idx_hex_ring ON hex_data(world_id, ring)")
        self.db.execute("CREATE INDEX IF NOT EXISTS idx_hex_spatial ON hex_data(world_id, ring, sector)")
        
        # Plate/watershed lookups
        self.db.execute("CREATE INDEX IF NOT EXISTS idx_plate_world ON plate(world_id)")
        self.db.execute("CREATE INDEX IF NOT EXISTS idx_watershed_world ON watershed(world_id)")
        
        # Template queries
        self.db.execute("CREATE INDEX IF NOT EXISTS idx_template_category ON world_template(category)")
        self.db.execute("CREATE INDEX IF NOT EXISTS idx_template_featured ON world_template(is_featured)")
        
        # Viewport queries
        self.db.execute("CREATE INDEX IF NOT EXISTS idx_viewport_world ON viewport(world_id)")
        self.db.execute("CREATE INDEX IF NOT EXISTS idx_viewport_tags ON viewport(tags)")
    
    def _populate_templates(self):
        """Populate default templates if empty."""
        # Check if templates exist
        count = self.db.execute("SELECT COUNT(*) FROM world_template").fetchone()[0]
        if count > 0:
            return
        
        # Create default templates
        from datetime import datetime
        from ..terrain import TerraDemo
        
        now = int(datetime.now().timestamp())
        td = TerraDemo()
        
        template_configs = [
            {
                'method': 'bayArea_map',
                'name': 'Bay Area',
                'description': 'San Francisco Bay region with realistic topography',
                'category': 'real-world',
                'tags': 'coastal,bay,california,real-world',
                'location': 'San Francisco Bay Area',
                'difficulty': 'medium',
                'featured': True,
                'order': 1
            },
            {
                'method': 'california_map',
                'name': 'California',
                'description': 'Full California coast from San Diego to San Francisco',
                'category': 'real-world',
                'tags': 'coastal,california,real-world,large',
                'location': 'California Coast',
                'difficulty': 'hard',
                'featured': True,
                'order': 2
            },
            {
                'method': 'maui_map',
                'name': 'Maui',
                'description': 'Hawaiian island with volcanic features',
                'category': 'real-world',
                'tags': 'island,volcanic,hawaii,real-world',
                'location': 'Maui, Hawaii',
                'difficulty': 'easy',
                'featured': True,
                'order': 3
            },
            {
                'method': 'japan_korea_map',
                'name': 'Japan & Korea',
                'description': 'East Asian archipelago and peninsula',
                'category': 'real-world',
                'tags': 'island,archipelago,asia,real-world',
                'location': 'Japan & Korea',
                'difficulty': 'hard',
                'featured': False,
                'order': 4
            },
            {
                'method': 'normandy_map',
                'name': 'Normandy',
                'description': 'D-Day beaches and coastal France',
                'category': 'real-world',
                'tags': 'coastal,europe,real-world,historical',
                'location': 'Normandy, France',
                'difficulty': 'medium',
                'featured': False,
                'order': 5
            },
            {
                'method': 'hong_kong_map',
                'name': 'Hong Kong',
                'description': 'Hong Kong and Pearl River Delta',
                'category': 'real-world',
                'tags': 'coastal,urban,asia,real-world',
                'location': 'Hong Kong',
                'difficulty': 'medium',
                'featured': False,
                'order': 6
            },
            {
                'method': 'sydney_map',
                'name': 'Sydney',
                'description': 'Sydney Harbor and surrounding area',
                'category': 'real-world',
                'tags': 'coastal,harbor,australia,real-world',
                'location': 'Sydney, Australia',
                'difficulty': 'easy',
                'featured': False,
                'order': 7
            }
        ]
        
        for config in template_configs:
            # Generate terrain
            terrain = getattr(td, config['method'])()
            
            # Create world record
            world_id = self.save_world(
                terrain=terrain,
                geology=None,  # Templates don't need full geology initially
                name=config['name'],
                description=config['description'],
                tags=config['tags'],
                geo_location_name=config['location'],
                is_template=True,
                created_by='system'
            )
            
            # Create template record
            self.templates.insert(WorldTemplate(
                world_id=world_id,
                category=config['category'],
                display_name=config['name'],
                description=config['description'],
                recommended_for=config['tags'],
                difficulty=config['difficulty'],
                is_featured=config['featured'],
                sort_order=config['order'],
                created=now
            ))
```

---

## Core Operations

### Saving Worlds

```python
@patch
def save_world(self: TerrainDB, terrain: Terrain, geology: Geology = None,
               name: str = "", description: str = "", tags: str = "",
               geo_location_name: str = "", is_template: bool = False,
               created_by: str = "") -> int:
    """Save a Terrain + Geology pair to database."""
    from datetime import datetime
    now = int(datetime.now().timestamp())
    
    # Extract world parameters
    grid = terrain.hexGrid
    
    world = TerrainWorld(
        name=name,
        description=description,
        terrain_data=terrain.encode(),
        geology_data=geology.encode() if geology else "",
        hex_count=len(terrain.elevations),
        nrows=grid.nRows,
        ncols=grid.nCols,
        hex_radius=grid.radius,
        elevation_delta=terrain.elevationDelta,
        sea_level=terrain.seaLevel.properties.get('fill', '#81b1e1ff'),
        tags=tags,
        geo_location_name=geo_location_name,
        is_template=is_template,
        created=now,
        modified=now,
        created_by=created_by
    )
    
    # Geographic bounds
    if terrain.geo:
        world.geo_lat_min = terrain.geo.lat_min
        world.geo_lat_max = terrain.geo.lat_max
        world.geo_lon_min = terrain.geo.lon_min
        world.geo_lon_max = terrain.geo.lon_max
    
    # Climate preset
    if terrain.climate:
        world.climate_preset = terrain.climate.encode()
        world.climate_name = terrain.climate.name
    
    # Generation parameters (if available)
    if geology and geology.plates:
        world.num_plates = len(geology.plates)
    
    result = self.worlds.insert(world)
    world_id = result.id if hasattr(result, 'id') else result['id']
    
    # Optionally populate hex data table for spatial queries
    # self._populate_hex_data(world_id, terrain)
    
    # Save plates if present
    if geology and geology.plates:
        self._save_plates(world_id, geology.plates, grid)
    
    # Save watersheds if present
    if geology and hasattr(geology, 'basins') and geology.basins:
        self._save_watersheds(world_id, geology.basins)
    
    return world_id

@patch
def _save_plates(self: TerrainDB, world_id: int, plates: list, grid: HexGrid):
    """Save plate data."""
    for i, plate in enumerate(plates):
        center_pos = grid.index_to_hexposition(plate.center)
        
        self.plates.insert(Plate(
            world_id=world_id,
            plate_index=i,
            kind=plate.kind.value if hasattr(plate.kind, 'value') else str(plate.kind),
            region_data=plate.region.encode(),
            center_q=center_pos.q,
            center_r=center_pos.r,
            center_s=center_pos.s,
            hex_count=len(plate.region.hexes)
        ))

@patch
def _save_watersheds(self: TerrainDB, world_id: int, basins: DrainageBasins):
    """Save watershed data."""
    for i, watershed in enumerate(basins.sheds):
        terminal_pos = basins.terrain.hexGrid.index_to_hexposition(watershed.terminal_hex)
        
        max_flow_hex, max_flow = watershed.max_flow_hex()
        
        self.watersheds.insert(Watershed(
            world_id=world_id,
            watershed_index=i,
            region_data=watershed.region.encode(),
            terminal_hex_q=terminal_pos.q,
            terminal_hex_r=terminal_pos.r,
            terminal_hex_s=terminal_pos.s,
            is_ocean=watershed.is_ocean,
            max_flow=max_flow,
            hex_count=len(watershed.region.hexes)
        ))
```

### Loading Worlds

```python
@patch
def load_world(self: TerrainDB, world_id: int) -> tuple[Terrain, Geology]:
    """Load a world by ID."""
    world = self.worlds[world_id]
    
    # Decode terrain
    terrain = Terrain.decode(world.terrain_data)
    
    # Decode geology if present
    geology = None
    if world.geology_data:
        geology = Geology.decode(world.geology_data)
    else:
        # Create basic geology from terrain
        plates = self._load_plates(world_id, terrain.hexGrid)
        geology = Geology(terrain, plates=plates, name=world.name)
    
    return terrain, geology

@patch
def _load_plates(self: TerrainDB, world_id: int, grid: HexGrid) -> list:
    """Load plates for a world."""
    from ..voronoi import Plate, PlateKind
    
    plate_records = list(self.plates.rows_where('world_id = ?', [world_id]))
    plates = []
    
    for record in plate_records:
        region = HexRegion.decode(record.region_data, grid)
        center_idx = grid.hexposition_to_index(
            HexPosition(record.center_q, record.center_r, record.center_s)
        )
        
        plate = Plate(
            center=center_idx,
            region=region,
            kind=PlateKind(record.kind)
        )
        plates.append(plate)
    
    return plates

@patch
def _load_watersheds(self: TerrainDB, world_id: int, terrain: Terrain) -> list:
    """Load watersheds for a world."""
    from ..water.watershed import Watershed as WatershedObj
    
    ws_records = list(self.watersheds.rows_where('world_id = ?', [world_id]))
    watersheds = []
    
    for record in ws_records:
        region = HexRegion.decode(record.region_data, terrain.hexGrid)
        terminal_idx = terrain.hexGrid.hexposition_to_index(
            HexPosition(record.terminal_hex_q, record.terminal_hex_r, record.terminal_hex_s)
        )
        
        ws = WatershedObj(
            terminal_hex=terminal_idx,
            region=region,
            terrain=terrain,
            is_ocean=record.is_ocean
        )
        watersheds.append(ws)
    
    return watersheds
```

### Template Management

```python
@patch
def list_templates(self: TerrainDB, category: str = None, featured_only: bool = False) -> list:
    """List available templates."""
    query = "SELECT * FROM world_template"
    params = []
    
    conditions = []
    if category:
        conditions.append("category = ?")
        params.append(category)
    if featured_only:
        conditions.append("is_featured = 1")
    
    if conditions:
        query += " WHERE " + " AND ".join(conditions)
    
    query += " ORDER BY sort_order, display_name"
    
    results = self.db.execute(query, params).fetchall()
    return [dict(row) for row in results]

@patch
def get_template(self: TerrainDB, template_id: int) -> tuple[Terrain, Geology]:
    """Load a world from a template."""
    template = self.templates[template_id]
    return self.load_world(template.world_id)

@patch
def search_worlds(self: TerrainDB, search_term: str = "", tags: list = None) -> list:
    """Search for worlds by name, description, or tags."""
    query = """
        SELECT * FROM terrain_world
        WHERE (name LIKE ? OR description LIKE ? OR tags LIKE ?)
    """
    params = [f"%{search_term}%"] * 3
    
    if tags:
        tag_conditions = " OR ".join(["tags LIKE ?" for _ in tags])
        query += f" AND ({tag_conditions})"
        params.extend([f"%{tag}%" for tag in tags])
    
    query += " ORDER BY is_template DESC, modified DESC"
    
    results = self.db.execute(query, params).fetchall()
    return [dict(row) for row in results]
```

---

## Optional: Spatial Queries with HexData

For large worlds, populate the HexData table for efficient spatial queries:

```python
@patch
def populate_hex_data(self: TerrainDB, world_id: int, terrain: Terrain, 
                      include_fields: list = None):
    """Populate HexData table for spatial queries.
    
    Args:
        world_id: World ID
        terrain: Terrain object
        include_fields: List of field names to include (None = all)
    """
    grid = terrain.hexGrid
    
    # Batch insert for performance
    batch = []
    batch_size = 1000
    
    for idx, hex_obj in enumerate(grid.hexes):
        pos = grid.index_to_hexposition(idx)
        row = idx // grid.nCols
        col = idx % grid.nCols
        
        hex_data = HexData(
            world_id=world_id,
            q=pos.q, r=pos.r, s=pos.s,
            grid_index=idx,
            row=row, col=col,
            elevation=terrain.elevations[idx],
            ring=abs(pos),
            sector=self._compute_sector(pos)
        )
        
        # Add optional fields
        if include_fields is None or 'temperature' in include_fields:
            if 'temperature' in terrain.fields:
                hex_data.temperature = terrain.fields['temperature'][idx]
        
        if include_fields is None or 'precipitation' in include_fields:
            if 'precipitation' in terrain.fields:
                hex_data.precipitation = terrain.fields['precipitation'][idx]
        
        if include_fields is None or 'distance_to_ocean' in include_fields:
            if 'distance_to_ocean' in terrain.fields:
                hex_data.distance_to_ocean = terrain.fields['distance_to_ocean'][idx]
        
        batch.append(hex_data)
        
        if len(batch) >= batch_size:
            self.hex_data.insert_all(batch)
            batch = []
    
    # Insert remaining
    if batch:
        self.hex_data.insert_all(batch)

@patch
def query_region(self: TerrainDB, world_id: int, 
                 center_q: int, center_r: int, center_s: int,
                 radius: int) -> list[HexData]:
    """Query hexes within a radius of a center point."""
    results = self.db.execute("""
        SELECT * FROM hex_data
        WHERE world_id = ? AND ring <= ?
    """, [world_id, radius]).fetchall()
    
    # Filter to actual ring distance from center
    center = HexPosition(center_q, center_r, center_s)
    filtered = []
    
    for row in results:
        pos = HexPosition(row['q'], row['r'], row['s'])
        if center.distance(pos) <= radius:
            filtered.append(HexData(**dict(row)))
    
    return filtered

@staticmethod
def _compute_sector(pos: HexPosition) -> int:
    """Compute angular sector (0-5) for a hex position."""
    import math
    if pos.q == 0 and pos.r == 0:
        return 0
    angle = math.atan2(pos.r, pos.q)
    sector = int((angle + math.pi) / (math.pi / 3)) % 6
    return sector
```

---

## Jupyter Notebook Usage

### Example: Working with Templates

```python
# Initialize database
from HexMagic.core import TerrainDB

db = TerrainDB()

# List available templates
templates = db.list_templates(featured_only=True)
for t in templates:
    print(f"{t['id']}: {t['display_name']} - {t['description']}")

# Load a template
terrain, geology = db.get_template(template_id=1)  # Bay Area

# Modify and save as new world
# ... make changes ...

new_world_id = db.save_world(
    terrain=terrain,
    geology=geology,
    name="Modified Bay Area",
    description="Bay Area with custom features",
    tags="coastal,bay,custom",
    created_by="notebook_user"
)
```

### Example: Creating Procedural World

```python
from HexMagic.terrain import Terrain
from HexMagic.voronoi import generate_plate_terrain
from HexMagic.geology import Geology

# Generate procedural terrain
mySize = MapSize(800, 800)
myBounds = MapRect(MapCord(0,0), mySize)

terrain, plates = Terrain.fromSeeds(
    myBounds,
    radius=15,
    num_plates=12,
    seed=42
)

# Create geology
geology = Geology(terrain, plates=plates, name="Procedural World")

# Save to database
world_id = db.save_world(
    terrain=terrain,
    geology=geology,
    name="Archipelago 42",
    description="Procedurally generated archipelago",
    tags="procedural,island,archipelago",
    created_by="generator"
)

print(f"Saved world {world_id}")
```

### Example: Spatial Queries

```python
# Populate spatial index for large world
db.populate_hex_data(world_id, terrain, include_fields=['temperature', 'elevation'])

# Query a region
center_pos = HexPosition(0, 0, 0)
hexes = db.query_region(
    world_id=world_id,
    center_q=0, center_r=0, center_s=0,
    radius=10
)

# Analyze the region
avg_elevation = np.mean([h.elevation for h in hexes])
avg_temp = np.mean([h.temperature for h in hexes if h.temperature is not None])

print(f"Region stats: avg elevation={avg_elevation}, avg temp={avg_temp}")
```

---

## Regional Lookup and Viewport APIs

### Centered Region Extraction

One of the most powerful features is extracting a sub-region centered on a HexPosition:

```python
@patch
def extract_region(self: TerrainDB, world_id: int, 
                   center_q: int, center_r: int, center_s: int,
                   rings: int, padding: int = 1) -> tuple[Terrain, callable]:
    """Extract a region centered on a HexPosition.
    
    Args:
        world_id: World to extract from
        center_q, center_r, center_s: Center position in universal coordinates
        rings: Number of rings to include around center
        padding: Extra rings for context
    
    Returns:
        (terrain, mapper) where:
        - terrain: New Terrain object with cropped region
        - mapper: Function to map new indices back to original world
    """
    # Load full world
    full_terrain, geology = self.load_world(world_id)
    grid = full_terrain.hexGrid
    
    # Get center index in full grid
    center_idx = grid.hexposition_to_index(HexPosition(center_q, center_r, center_s))
    if center_idx < 0:
        raise ValueError(f"Center position ({center_q},{center_r},{center_s}) not in world")
    
    # Create region around center
    region_hexes = set()
    center_pos = HexPosition(0, 0, 0)  # Origin for distance calculation
    
    for idx in range(len(grid.hexes)):
        hex_pos = grid.index_to_hexposition(idx, origin_index=center_idx)
        if hex_pos.distance(center_pos) <= rings:
            region_hexes.add(idx)
    
    region = HexRegion(hexes=region_hexes, hexGrid=grid)
    
    # Crop to centered grid
    new_grid, new_region, index_mapper = region.crop_to_centered_grid(padding=padding)
    
    # Create new terrain with mapped data
    new_terrain = Terrain(
        bounds=new_grid.bounds,
        radius=new_grid.radius,
        colorLevels=full_terrain.colorLevels,
        seaLevel=full_terrain.seaLevel,
        elevationDelta=full_terrain.elevationDelta,
        geo=full_terrain.geo,
        climate=full_terrain.climate
    )
    
    new_terrain.hexGrid = new_grid
    new_terrain.elevations = np.zeros(len(new_grid.hexes))
    
    # Copy field data
    for field_name in full_terrain.fields.keys():
        new_terrain.fields[field_name] = np.zeros(len(new_grid.hexes))
    
    # Map data from full terrain to new terrain
    for new_idx in range(len(new_grid.hexes)):
        old_idx = index_mapper(new_idx)
        if old_idx >= 0:
            new_terrain.elevations[new_idx] = full_terrain.elevations[old_idx]
            for field_name, field_data in full_terrain.fields.items():
                new_terrain.fields[field_name][new_idx] = field_data[old_idx]
    
    return new_terrain, index_mapper
```

### Rectangular Crop for Printing

Extract a rectangular region suitable for landscape/portrait printing:

```python
@patch
def extract_rectangle(self: TerrainDB, world_id: int,
                      center_q: int, center_r: int, center_s: int,
                      width_hexes: int, height_hexes: int,
                      orientation: str = 'landscape') -> tuple[Terrain, callable]:
    """Extract a rectangular region for printing.
    
    Args:
        world_id: World to extract from
        center_q, center_r, center_s: Center position
        width_hexes: Width in hex columns
        height_hexes: Height in hex rows
        orientation: 'landscape' or 'portrait'
    
    Returns:
        (terrain, mapper) tuple
    """
    # Load full world
    full_terrain, geology = self.load_world(world_id)
    grid = full_terrain.hexGrid
    
    # Get center index
    center_idx = grid.hexposition_to_index(HexPosition(center_q, center_r, center_s))
    if center_idx < 0:
        raise ValueError(f"Center position not in world")
    
    # Get center row/col
    center_row, center_col = grid.index_to_row_col(center_idx)
    
    # Calculate bounds based on orientation
    if orientation == 'landscape':
        w, h = max(width_hexes, height_hexes), min(width_hexes, height_hexes)
    else:
        w, h = min(width_hexes, height_hexes), max(width_hexes, height_hexes)
    
    min_row = max(0, center_row - h // 2)
    max_row = min(grid.nRows - 1, center_row + h // 2)
    min_col = max(0, center_col - w // 2)
    max_col = min(grid.nCols - 1, center_col + w // 2)
    
    # Collect hexes in rectangle
    region_hexes = set()
    for row in range(min_row, max_row + 1):
        for col in range(min_col, max_col + 1):
            idx = grid.row_col_to_index(row, col)
            if idx >= 0:
                region_hexes.add(idx)
    
    region = HexRegion(hexes=region_hexes, hexGrid=grid)
    
    # Create rectangular grid
    new_nrows = max_row - min_row + 1
    new_ncols = max_col - min_col + 1
    
    bounds = MapRect(
        MapCord(0, 0),
        MapSize(new_ncols * grid.radius * 1.5, new_nrows * grid.radius * math.sqrt(3))
    )
    
    new_grid = HexGrid.from_bounds(bounds, radius=grid.radius, style=grid.style)
    new_grid.nRows = new_nrows
    new_grid.nCols = new_ncols
    new_grid._build_hexes()
    
    # Create new terrain
    new_terrain = Terrain(
        bounds=bounds,
        radius=grid.radius,
        colorLevels=full_terrain.colorLevels,
        seaLevel=full_terrain.seaLevel,
        elevationDelta=full_terrain.elevationDelta,
        geo=full_terrain.geo,
        climate=full_terrain.climate
    )
    
    new_terrain.hexGrid = new_grid
    new_terrain.elevations = np.zeros(len(new_grid.hexes))
    
    # Copy fields
    for field_name in full_terrain.fields.keys():
        new_terrain.fields[field_name] = np.zeros(len(new_grid.hexes))
    
    # Index mapper
    def rect_mapper(new_idx: int) -> int:
        """Map new rectangular grid index to original grid index."""
        new_row, new_col = new_grid.index_to_row_col(new_idx)
        old_row = min_row + new_row
        old_col = min_col + new_col
        return grid.row_col_to_index(old_row, old_col)
    
    # Map data
    for new_idx in range(len(new_grid.hexes)):
        old_idx = rect_mapper(new_idx)
        if old_idx >= 0:
            new_terrain.elevations[new_idx] = full_terrain.elevations[old_idx]
            for field_name, field_data in full_terrain.fields.items():
                new_terrain.fields[field_name][new_idx] = field_data[old_idx]
    
    return new_terrain, rect_mapper
```

### Viewport Management

Store and retrieve viewport definitions:

```python
@dataclass
class Viewport:
    """Saved viewport for quick access to regions."""
    id: int = None
    world_id: int = 0
    name: str = ""
    description: str = ""
    
    # Center position
    center_q: int = 0
    center_r: int = 0
    center_s: int = 0
    
    # Shape
    shape: str = "circle"  # 'circle' or 'rectangle'
    
    # For circular viewports
    rings: int = 10
    
    # For rectangular viewports
    width_hexes: int = 0
    height_hexes: int = 0
    orientation: str = "landscape"
    
    # Metadata
    created: int = 0
    tags: str = ""

@patch
def create_viewport(self: TerrainDB, world_id: int, name: str,
                    center_q: int, center_r: int, center_s: int,
                    shape: str = "circle", **kwargs) -> int:
    """Save a viewport definition."""
    from datetime import datetime
    now = int(datetime.now().timestamp())
    
    viewport = Viewport(
        world_id=world_id,
        name=name,
        center_q=center_q,
        center_r=center_r,
        center_s=center_s,
        shape=shape,
        created=now,
        **kwargs
    )
    
    result = self.viewports.insert(viewport)
    return result.id if hasattr(result, 'id') else result['id']

@patch
def load_viewport(self: TerrainDB, viewport_id: int) -> Terrain:
    """Load a terrain from a saved viewport."""
    viewport = self.viewports[viewport_id]
    
    if viewport.shape == "circle":
        terrain, _ = self.extract_region(
            viewport.world_id,
            viewport.center_q,
            viewport.center_r,
            viewport.center_s,
            rings=viewport.rings
        )
    else:  # rectangle
        terrain, _ = self.extract_rectangle(
            viewport.world_id,
            viewport.center_q,
            viewport.center_r,
            viewport.center_s,
            width_hexes=viewport.width_hexes,
            height_hexes=viewport.height_hexes,
            orientation=viewport.orientation
        )
    
    return terrain
```

### Usage Examples

```python
# Example 1: Centered region for detail view
db = TerrainDB()

# Load full world
full_terrain, geology = db.get_template(1)  # Bay Area

# Extract 20-ring region around specific hex
detail_terrain, mapper = db.extract_region(
    world_id=1,
    center_q=10, center_r=-5, center_s=-5,
    rings=20,
    padding=2
)

# Render detail map
detail_terrain.colorMap()
detail_terrain.hexGrid.builder.show()

# Example 2: Rectangular crop for landscape print
print_terrain, mapper = db.extract_rectangle(
    world_id=1,
    center_q=0, center_r=0, center_s=0,
    width_hexes=50,
    height_hexes=30,
    orientation='landscape'
)

# Export for printing
print_terrain.export("landscape_map.svg")

# Example 3: Save viewport for reuse
viewport_id = db.create_viewport(
    world_id=1,
    name="Bay Area Detail",
    center_q=10, center_r=-5, center_s=-5,
    shape="circle",
    rings=15,
    description="Focused view of bay area",
    tags="detail,bay,exploration"
)

# Later, load saved viewport
view_terrain = db.load_viewport(viewport_id)
```

### Print Templates

Create print-ready templates with standard sizes:

```python
PRINT_TEMPLATES = {
    'letter_landscape': {'width': 60, 'height': 40, 'orientation': 'landscape'},
    'letter_portrait': {'width': 40, 'height': 60, 'orientation': 'portrait'},
    'a4_landscape': {'width': 65, 'height': 45, 'orientation': 'landscape'},
    'a4_portrait': {'width': 45, 'height': 65, 'orientation': 'portrait'},
    'poster_24x36': {'width': 100, 'height': 150, 'orientation': 'portrait'},
}

@patch
def extract_for_print(self: TerrainDB, world_id: int,
                      center_q: int, center_r: int, center_s: int,
                      template: str = 'letter_landscape') -> Terrain:
    """Extract region using standard print template."""
    if template not in PRINT_TEMPLATES:
        raise ValueError(f"Unknown template: {template}")
    
    params = PRINT_TEMPLATES[template]
    terrain, _ = self.extract_rectangle(
        world_id, center_q, center_r, center_s,
        width_hexes=params['width'],
        height_hexes=params['height'],
        orientation=params['orientation']
    )
    
    return terrain
```

---

## Scale and Multi-Resolution Transforms

One of the most powerful features for working with large worlds is the ability to transform between different resolutions. This enables:
- Large world generation at high resolution, then downsampling for climate simulation
- Zooming into regions while preserving the relationship to the original world
- Mapping regions defined at one scale to another scale

### Core Scale Operations

#### Downsampling

Two primary methods downsample terrain data:

**1. Climate Downsampling (`Terrain.downsample_climate`)**
```python
@patch
def downsample_climate(self: Terrain, scale=0.5, sample_radius=1):
    """Downsample terrain with all climate data preserved.
    
    Args:
        scale: Fraction of original size (0.5 = half, 0.33 = third)
        sample_radius: Number of rings to sample around each target hex
    
    Returns:
        New terrain at reduced resolution with climate data
    """
    new_terrain = self.shrinkWeather(scale=scale, sample_radius=sample_radius)
    new_terrain.geo = self.geo
    new_terrain.compute_climate()
    return new_terrain
```

**2. Weather Downsampling (`Terrain.shrinkWeather`)**
```python
@patch
def shrinkWeather(self: Terrain, scale=0.5, sample_radius=1):
    """Downsample terrain with all weather data preserved.
    
    Uses intelligent field-specific sampling:
    - Elevation: max (preserve peaks)
    - Temperature: weighted average
    - Precipitation: weighted average  
    - Distance to coast: min (closest coast matters)
    - Geographic coordinates: weighted average
    """
    # ... implementation uses convolution with hex ring patterns
```

**Usage:**
```python
# Generate large terrain
large_terrain, plates = Terrain.fromSeeds(
    MapRect(MapCord(0,0), MapSize(2000, 2000)),
    radius=10,
    num_plates=25
)

large_terrain.compute_temperature()
large_terrain.compute_precipitation()

# Downsample for climate simulation (faster)
small_terrain = large_terrain.downsample_climate(scale=0.25)  # 1/4 size

# Work with downsampled version
small_terrain.compute_climate()
small_terrain.add_climate_overlay()
```

#### Regional Cropping

Extract a sub-region while maintaining coordinate relationships:

```python
# Extract region centered on specific hex
region_hexes = set()
for idx in range(len(terrain.hexGrid.hexes)):
    pos = terrain.hexGrid.index_to_hexposition(idx, origin_index=center_idx)
    if pos.distance(HexPosition.origin()) <= 20:  # 20 rings
        region_hexes.add(idx)

region = HexRegion(hexes=region_hexes, hexGrid=terrain.hexGrid)

# Crop to centered grid with index mapping
new_grid, new_region, index_mapper = region.crop_to_centered_grid(padding=2)
```

### Scale Transform System

When working across scales, we need bidirectional transforms:

#### ScaleTransform Dataclass

```python
from dataclasses import dataclass
from typing import Callable, Optional
import numpy as np

@dataclass
class ScaleTransform:
    """Transforms for mapping between different scale versions of terrain."""
    
    # Scale relationship
    source_world_id: int  # Original/larger world
    target_world_id: int  # Downsampled/smaller world
    scale_factor: float   # target_size / source_size (e.g., 0.5)
    sample_radius: int    # Sampling radius used in downsampling
    
    # Grid relationships
    source_nrows: int
    source_ncols: int
    target_nrows: int
    target_ncols: int
    
    # Transform data (optional, for non-uniform transforms)
    # Maps source hex indices to target hex indices
    source_to_target_map: Optional[str] = None  # Encoded as JSON array
    target_to_source_map: Optional[str] = None  # Encoded as JSON array
    
    # Transform type
    transform_type: str = "downsample"  # "downsample", "crop", "crop_downsample"
    
    # For cropped regions
    crop_center_q: Optional[int] = None
    crop_center_r: Optional[int] = None
    crop_center_s: Optional[int] = None
    
    # Metadata
    created: int = 0
    description: str = ""
```

#### Region Mapping Utilities

**Forward Mapping: Large → Small**

```python
@patch
def map_region_to_scale(self: TerrainDB, 
                         transform: ScaleTransform,
                         source_hexes: set[int]) -> set[int]:
    """Map a region from source (large) world to target (small) world.
    
    Args:
        transform: ScaleTransform describing the relationship
        source_hexes: Set of hex indices in source world
    
    Returns:
        Set of hex indices in target world that correspond to source region
    """
    source_terrain, _ = self.load_world(transform.source_world_id)
    target_terrain, _ = self.load_world(transform.target_world_id)
    
    source_grid = source_terrain.hexGrid
    target_grid = target_terrain.hexGrid
    
    target_hexes = set()
    
    # For each source hex, find corresponding target hex
    for source_idx in source_hexes:
        # Get row/col in source grid
        source_row, source_col = source_grid.index_to_row_col(source_idx)
        
        # Map to target grid (simple scaling)
        target_row = int(source_row * transform.scale_factor)
        target_col = int(source_col * transform.scale_factor)
        
        # Convert to target index
        target_idx = target_grid.row_col_to_index(target_row, target_col)
        if target_idx >= 0:
            target_hexes.add(target_idx)
    
    return target_hexes
```

**Reverse Mapping: Small → Large**

```python
@patch
def map_region_from_scale(self: TerrainDB,
                           transform: ScaleTransform,
                           target_hexes: set[int],
                           expand: bool = True) -> set[int]:
    """Map a region from target (small) world back to source (large) world.
    
    Args:
        transform: ScaleTransform describing the relationship
        target_hexes: Set of hex indices in target world
        expand: If True, include all source hexes that contributed to target hexes
    
    Returns:
        Set of hex indices in source world
    """
    source_terrain, _ = self.load_world(transform.source_world_id)
    target_terrain, _ = self.load_world(transform.target_world_id)
    
    source_grid = source_terrain.hexGrid
    target_grid = target_terrain.hexGrid
    
    source_hexes = set()
    
    for target_idx in target_hexes:
        # Get position in target grid
        target_row, target_col = target_grid.index_to_row_col(target_idx)
        
        # Map back to source grid
        source_row = int(target_row / transform.scale_factor)
        source_col = int(target_col / transform.scale_factor)
        
        if expand:
            # Include all hexes that contributed to this downsampled hex
            # Based on sample_radius used in downsampling
            radius = int(1.0 / transform.scale_factor * transform.sample_radius)
            
            for dr in range(-radius, radius + 1):
                for dc in range(-radius, radius + 1):
                    check_row = source_row + dr
                    check_col = source_col + dc
                    check_idx = source_grid.row_col_to_index(check_row, check_col)
                    if check_idx >= 0:
                        source_hexes.add(check_idx)
        else:
            # Just the center hex
            source_idx = source_grid.row_col_to_index(source_row, source_col)
            if source_idx >= 0:
                source_hexes.add(source_idx)
    
    return source_hexes
```

**HexPosition-Based Mapping**

For more precise mapping using universal coordinates:

```python
@patch
def map_hexposition_to_scale(self: TerrainDB,
                              transform: ScaleTransform,
                              source_q: int, source_r: int, source_s: int) -> tuple[int, int, int]:
    """Map a HexPosition from source to target scale.
    
    Returns:
        (target_q, target_r, target_s) in target world coordinates
    """
    # Simple scaling of cube coordinates
    target_q = int(source_q * transform.scale_factor)
    target_r = int(source_r * transform.scale_factor)
    target_s = int(source_s * transform.scale_factor)
    
    # Ensure cube coordinate constraint
    if target_q + target_r + target_s != 0:
        # Adjust s to maintain constraint
        target_s = -target_q - target_r
    
    return target_q, target_r, target_s

@patch
def map_hexposition_from_scale(self: TerrainDB,
                                transform: ScaleTransform,
                                target_q: int, target_r: int, target_s: int) -> tuple[int, int, int]:
    """Map a HexPosition from target back to source scale.
    
    Returns:
        (source_q, source_r, source_s) in source world coordinates
    """
    inv_scale = 1.0 / transform.scale_factor
    
    source_q = int(target_q * inv_scale)
    source_r = int(target_r * inv_scale)
    source_s = int(target_s * inv_scale)
    
    if source_q + source_r + source_s != 0:
        source_s = -source_q - source_r
    
    return source_q, source_r, source_s
```

### Database Integration

Store scale transforms in the database:

```python
# Add to TerrainDB._create_tables()
self.transforms = self.db.create(ScaleTransform, pk='id', if_not_exists=True, transform=True)

# Create indices
self.db.execute("CREATE INDEX IF NOT EXISTS idx_transform_source ON scale_transform(source_world_id)")
self.db.execute("CREATE INDEX IF NOT EXISTS idx_transform_target ON scale_transform(target_world_id)")
```

**Saving Downsampled Worlds with Transforms:**

```python
@patch
def save_downsampled_world(self: TerrainDB, 
                           source_world_id: int,
                           scale: float = 0.5,
                           sample_radius: int = 1,
                           name: str = "") -> tuple[int, int]:
    """Downsample a world and save with transform relationship.
    
    Returns:
        (new_world_id, transform_id)
    """
    # Load source world
    source_terrain, source_geology = self.load_world(source_world_id)
    
    # Downsample
    target_terrain = source_terrain.downsample_climate(scale=scale, sample_radius=sample_radius)
    
    # Save new world
    source_world = self.worlds[source_world_id]
    if not name:
        name = f"{source_world.name} ({int(scale*100)}% scale)"
    
    target_world_id = self.save_world(
        terrain=target_terrain,
        geology=None,
        name=name,
        description=f"Downsampled from world {source_world_id} at {scale}x scale",
        tags=source_world.tags + ",downsampled",
        created_by="downsample_transform"
    )
    
    # Create transform record
    from datetime import datetime
    now = int(datetime.now().timestamp())
    
    transform = ScaleTransform(
        source_world_id=source_world_id,
        target_world_id=target_world_id,
        scale_factor=scale,
        sample_radius=sample_radius,
        source_nrows=source_terrain.hexGrid.nRows,
        source_ncols=source_terrain.hexGrid.nCols,
        target_nrows=target_terrain.hexGrid.nRows,
        target_ncols=target_terrain.hexGrid.nCols,
        transform_type="downsample",
        created=now,
        description=f"Downsample at {scale}x with radius {sample_radius}"
    )
    
    result = self.transforms.insert(transform)
    transform_id = result.id if hasattr(result, 'id') else result['id']
    
    return target_world_id, transform_id
```

### Workflow Examples

#### Example 1: Multi-Scale Analysis

```python
db = TerrainDB()

# Create large world
large_terrain, plates = Terrain.fromSeeds(
    MapRect(MapCord(0,0), MapSize(2000, 2000)),
    radius=10,
    num_plates=25
)

large_terrain.compute_temperature()
large_terrain.compute_precipitation()

large_world_id = db.save_world(
    large_terrain,
    name="Large Continent",
    tags="procedural,large"
)

# Create downsampled versions for faster climate work
small_world_id, transform_id = db.save_downsampled_world(
    large_world_id,
    scale=0.25,
    sample_radius=2
)

# Work with small version
small_terrain, _ = db.load_world(small_world_id)
small_terrain.compute_climate()

# Define region on small terrain (e.g., tropical zone)
tropical_mask = small_terrain.fields['climate'] == Climate.TROPICAL.value
tropical_hexes = set(np.where(tropical_mask)[0])

# Map back to large terrain
transform = db.transforms[transform_id]
large_tropical_hexes = db.map_region_from_scale(
    transform,
    tropical_hexes,
    expand=True  # Include all contributing hexes
)

print(f"Tropical zone: {len(tropical_hexes)} hexes at small scale")
print(f"Tropical zone: {len(large_tropical_hexes)} hexes at large scale")
```

#### Example 2: Crop Then Downsample

```python
# Extract large region from world
center_terrain, mapper = db.extract_region(
    world_id=1,
    center_q=100, center_r=-50, center_s=-50,
    rings=50
)

# Save cropped region
crop_world_id = db.save_world(
    center_terrain,
    name="Cropped Region",
    tags="cropped,detail"
)

# Downsample the cropped region for climate analysis
small_crop_id, _ = db.save_downsampled_world(
    crop_world_id,
    scale=0.5
)

# Now we have: original → crop → downsampled crop
# Can trace regions through the full chain
```

#### Example 3: Interactive Scale Navigation

```python
class MultiScaleWorld:
    """Helper for working with multi-scale world versions."""
    
    def __init__(self, db: TerrainDB, world_id: int):
        self.db = db
        self.world_id = world_id
        self.scales = {}  # scale_factor -> (world_id, transform_id)
        
    def ensure_scale(self, scale: float, sample_radius: int = 1):
        """Ensure a downsampled version exists at given scale."""
        if scale in self.scales:
            return self.scales[scale][0]
        
        # Create it
        new_id, trans_id = self.db.save_downsampled_world(
            self.world_id,
            scale=scale,
            sample_radius=sample_radius
        )
        
        self.scales[scale] = (new_id, trans_id)
        return new_id
    
    def map_position(self, q: int, r: int, s: int, 
                     from_scale: float, to_scale: float) -> tuple[int, int, int]:
        """Map a position between two scales."""
        # Get transform
        if from_scale == 1.0:
            source_id = self.world_id
        else:
            source_id = self.scales[from_scale][0]
        
        target_id = self.ensure_scale(to_scale)
        
        # Find transform (may need to query)
        transforms = list(self.db.transforms.rows_where(
            'source_world_id = ? AND target_world_id = ?',
            [source_id, target_id]
        ))
        
        if not transforms:
            # Try reverse
            transforms = list(self.db.transforms.rows_where(
                'source_world_id = ? AND target_world_id = ?',
                [target_id, source_id]
            ))
            if transforms:
                # Reverse transform
                return self.db.map_hexposition_from_scale(transforms[0], q, r, s)
        else:
            return self.db.map_hexposition_to_scale(transforms[0], q, r, s)
        
        raise ValueError(f"No transform between {from_scale} and {to_scale}")

# Usage:
msw = MultiScaleWorld(db, world_id=1)

# Create scales
msw.ensure_scale(0.5)
msw.ensure_scale(0.25)

# Map position from full to quarter scale
q_quarter, r_quarter, s_quarter = msw.map_position(
    100, -50, -50,
    from_scale=1.0,
    to_scale=0.25
)
```

### Transform Callbacks

For real-time applications, register callbacks when scales change:

```python
class ScaleObserver:
    """Observer pattern for scale changes."""
    
    def __init__(self):
        self.callbacks = []
    
    def register(self, callback: Callable):
        """Register callback(old_scale, new_scale, region_hexes)."""
        self.callbacks.append(callback)
    
    def notify_scale_change(self, old_scale: float, new_scale: float, region: set[int]):
        """Notify all observers of scale change."""
        for cb in self.callbacks:
            cb(old_scale, new_scale, region)

# Example usage in web application
observer = ScaleObserver()

def update_viewport(old_scale, new_scale, region_hexes):
    """Update web viewport when user zooms."""
    print(f"Zooming from {old_scale}x to {new_scale}x")
    print(f"Region contains {len(region_hexes)} hexes")
    # Trigger re-render with new scale data

observer.register(update_viewport)
```

### Performance Considerations

**Pre-compute Scale Versions:**
```python
# For production, pre-compute common scales
SCALE_LEVELS = [1.0, 0.5, 0.25, 0.125]  # Full, half, quarter, eighth

for scale in SCALE_LEVELS[1:]:
    db.save_downsampled_world(world_id, scale=scale)
```

**Caching:**
```python
class CachedScaleTransform:
    """Cache region mappings for performance."""
    
    def __init__(self, transform: ScaleTransform):
        self.transform = transform
        self._forward_cache = {}  # source_idx -> target_idx
        self._reverse_cache = {}  # target_idx -> set[source_idx]
    
    def forward(self, source_idx: int) -> int:
        if source_idx not in self._forward_cache:
            # Compute and cache
            self._forward_cache[source_idx] = self._compute_forward(source_idx)
        return self._forward_cache[source_idx]
    
    def reverse(self, target_idx: int) -> set[int]:
        if target_idx not in self._reverse_cache:
            self._reverse_cache[target_idx] = self._compute_reverse(target_idx)
        return self._reverse_cache[target_idx]
```

---

## Migration Strategy

### Phase 1: Add Database (Non-Breaking)

```python
# Existing code continues to work
terrain = TerraDemo().bayArea_map()
terrain.export("my_map.svg")

# New: Also save to database
db = TerrainDB()
world_id = db.save_world(terrain, name="Bay Area")
```

### Phase 2: Template System

```python
# Old way: manually call TerraDemo methods
td = TerraDemo()
terrain = td.maui_map()

# New way: load from database
db = TerrainDB()
terrain, geology = db.get_template(3)  # Maui template
```

### Phase 3: Notebook Integration

```python
# Work with larger worlds
db = TerrainDB()

# Generate large world
large_terrain, plates = Terrain.fromSeeds(
    MapRect(MapCord(0,0), MapSize(2000, 2000)),
    radius=10,
    num_plates=30
)

# Save (too big for memory in some operations)
world_id = db.save_world(large_terrain, name="Large Continent")

# Populate spatial index
db.populate_hex_data(world_id, large_terrain)

# Query specific regions as needed
region_hexes = db.query_region(world_id, 100, -50, -50, radius=20)
```

---

## Benefits

1. **Template Library**: Pre-built worlds accessible by ID
2. **Search/Discovery**: Find worlds by tags, location, or features
3. **Large Worlds**: Store worlds too large for memory
4. **Regional Extraction**: Extract centered regions by HexPosition + rings
5. **Print-Ready Crops**: Rectangular extracts for landscape/portrait printing
6. **Viewport Management**: Save and reuse favorite regions/views
7. **Spatial Queries**: Efficiently query hex data by coordinates
8. **Reproducibility**: Save generation parameters
9. **Jupyter-Friendly**: Interactive exploration of world library
10. **Backward Compatible**: Existing encode/decode still works

## Next Steps for Implementation

1. Create `TerrainDB` class in new module `HexMagic/database.py`
2. Add dataclass definitions for all tables
3. Implement template population in `TerraDemo`
4. Create Jupyter notebook demonstrating usage
5. Add spatial query utilities
6. Optional: Add preview image generation for templates
