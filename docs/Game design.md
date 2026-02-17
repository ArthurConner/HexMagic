# Game Design

> Strategy game mechanics for HexMagic - turn-based gameplay, autonomous units, territorial control

## Architecture Overview

The game follows an **MVC-like pattern**:
- **Model**: GeoStorage database (persistent game state)
- **ViewModel**: Terrain, HexRegion, Kingdom (working data structures)
- **View**: SVG visualization with overlays
- **Controller**: GameBoard, Piece AI (game logic)

See `docs/PROJECT_OVERVIEW.md` for complete architecture and `docs/PieceDesign.md` for detailed unit specifications.

## Core Concepts

### Multi-Scale Gameplay

The game leverages the **ChunkCover** system for efficient multi-scale gameplay:

1. **Master World**: Coarse-resolution terrain (e.g., 100×120 hexes) stored in database
2. **Regional Zoom**: Fine-detail chunks generated on-demand using HFFT upsampling (4× resolution)
3. **Country Views**: Each kingdom operates on a cropped region extracted via `crop_to_centered_grid()`

**Benefits:**
- Large worlds without massive memory/compute costs
- Players see high detail only in their active regions
- Database caching speeds up repeated regional access
- Natural "fog of war" boundary at region edges

### Territory Control

Control is **watershed-based** rather than hex-by-hex:
- Conquering a capital city conquers its entire watershed region
- Watersheds are natural strategic units (valleys, river basins)
- Pieces move within regions; battles occur at region boundaries
- More like **Risk** than **Civilization** (region-level, not hex-level commands)

## Resources

### Health
Each piece has health points (0-100). When health drops below threshold:
- Piece may retreat automatically
- Combat effectiveness decreases
- Risk of piece destruction

### Food & Population
Food drives population growth and piece spawning:
- **Types**: Grains (farms), Meat (pastures), Fruits (orchards)
- **Production**: Based on terrain quality, climate, and proximity to water
- **Storage**: Cities store food reserves for lean seasons
- **Transport**: Trade routes move food between settlements

**Future Enhancement**: Different terrain hexes could be converted to specific farm types based on climate (temperate → grains, tropical → fruits).

## Pieces (Game Units)

**See `docs/PieceDesign.md` for complete specification.**

Pieces are autonomous agents representing military units/populations. Key features:

### Core Attributes
- **Size**: Number of units (affects combat strength)
- **Health**: Hit points (0-100)
- **Sight**: Vision range in hex rings
- **Memory**: Knowledge retention rate (affects fog of war)
- **Movement Range**: Max hexes per turn (terrain-weighted)
- **Goal**: Current objective (explore, settle, attack, defend, harvest)
- **Personality**: AI behavior weights (aggressive, defensive, economic, explorer)

### Key Behaviors
1. **Movement**: Pathfinding with terrain costs (elevation, forests, roads)
2. **Vision**: Line-of-sight with fog of war and knowledge decay
3. **Combat**: Strength-based resolution with terrain modifiers
4. **Settlement**: Multi-turn process to establish bases
5. **Harvesting**: Spawn new pieces at rate based on terrain quality
6. **AI Planning**: Personality-driven goal selection and execution

### Visualization
Pieces render as SVG circles on the map:
- Size scaled by unit count
- Color indicates health (green → yellow → red)
- Icons show current goal (arrow for attack, house for settle)
- Pattern fills use kingdom flag colors

**Note**: Full implementation details (methods, combat system, knowledge sharing, etc.) are in PieceDesign.md to avoid duplication.

## Movement & Trade Routes

### Movement Costs

Movement accounts for multiple terrain factors:

1. **Elevation Changes**:
   - Uphill: Significant penalty (steep = expensive)
   - Downhill: Minor penalty (controlled descent)
   - Flat: Base cost

2. **Terrain Types**:
   - Forests/Jungles: 1.5× cost (reduced visibility, difficult terrain)
   - Swamps: 2× cost (extremely slow)
   - Roads: 0.8× cost (improved infrastructure)
   - Water: Impassable (unless naval units added later)

3. **Weather/Season** (future):
   - Snow, rain, fog modify movement and visibility

4. **Visibility**:
   - Line-of-sight blocked by high terrain and dense forests
   - Pieces have memory that decays over time (old intel becomes stale)

### Trade Routes

Trade routes connect settlements and enable faster movement/resource transport:

```python
class TradeRoute:
    """Path between settlements with movement bonuses."""
    
    def __init__(self, path: List[HexPosition], origin: int = 0, 
                 cost: float = 0, name: str = ""):
        self.path = path  # List of HexPosition waypoints
        self.cost = cost  # Construction/maintenance cost
        self.name = name  # Route identifier
        self.origin = origin  # Origin hex index for coordinate conversion
        self.level = 1  # Route quality (1=path, 2=road, 3=highway)
    
    def destination(self) -> HexPosition:
        return self.path[-1]
    
    def movement_multiplier(self) -> float:
        """Movement speed bonus on this route."""
        return {1: 0.8, 2: 0.6, 3: 0.4}[self.level]
```

**Route Mechanics**:
- Routes between parent settlements and spawned children form naturally
- Route capacity limited by distance (longer = lower capacity)
- Upgrading routes (path → road → highway) costs resources but increases speed
- Enemy pieces can cut/raid supply routes

**Implementation Note**: Movement cost calculation is in `GameBoard.movement_cost()` and `Piece.movement_cost()` (see PieceDesign.md).

### Pathfinding

Uses **Dijkstra's algorithm** with terrain-weighted costs:
- Accounts for elevation, terrain type, weather
- Prefers established roads when available  
- Can compute partial paths if full path exceeds movement range
- Caches frequently-used paths for performance

## Cities & Settlements

### City Placement

Cities are strategically located within **watersheds**:
- **Ideal location**: Computed based on terrain quality, water access, defensibility
- **Capital per watershed**: One major city controls each watershed region
- **Conquest**: Capturing a capital conquers the entire watershed

**Placement Algorithm**:
1. Identify watershed boundaries via `Geology.compute_watersheds()`
2. Score hexes by: elevation (not too high/low), water proximity, flat terrain
3. Place capital at highest-scoring hex
4. Secondary settlements at strategic points (mountain passes, river crossings)

### City Functions

**Resource Storage**:
- Cities accumulate food from surrounding tiles
- Reserves sustain population during lean seasons
- Can trade excess food to other cities via routes

**Piece Spawning**:
- Settled pieces spawn new pieces at cities
- Spawn rate based on: terrain quality, food reserves, city size
- Newly spawned pieces inherit partial knowledge from parent

**Defense**:
- Cities provide defensive bonuses in combat (1.5× defender strength)
- Fortifications can be built to increase defense further
- Siege mechanics for attacking fortified positions (future)

### Country/Kingdom Structure

**CountryFlag** - Visual identity:
```python
class CountryFlag:
    def __init__(self, color, name, year):
        self.primary = color  # Main color
        self.comp = complementary(color)  # Complementary color
        self.tri1, self.tri2 = triadic(color)  # Triadic colors
        self.name = name
        self.year = year
        self.countryPrefix = generate_country_name(name)
        self.capital = generate_city_name(name)
```

**Kingdom/Country** - Playable faction:
```python
class Kingdom:
    """Territory controlled by a single government."""
    def __init__(self, capital_hex: int, region: HexRegion, 
                 world: Geology, countryId: int = 0, flag: CountryFlag = None):
        self.settlements: List[int] = [capital_hex]  # Hex indices
        self.region: HexRegion = region  # Controlled territory
        self.world: Geology = world  # Reference to world data
        self.countryId: int = countryId
        self.captured: List[Watershed] = []  # Conquered watersheds
        self.routes: List[TradeRoute] = []  # Trade network
        self.flag: CountryFlag = flag  # Visual identity
        self.countryName: str = ""
        self.pieces: List[Piece] = []  # Military units
        self.personality: PersonalityTrait = None  # AI behavior
        self.food_reserves: Dict[str, int] = {}  # Stored resources
```

**Territory Management** via `CountryDetails`:
```python
class CountryDetails:
    """Manages regional view of a kingdom using crop_to_centered_grid()."""
    def __init__(self, country: Kingdom):
        self.country = country
        self.updateParent(country.world.terrain)
    
    def updateParent(self, parent: Terrain):
        """Extract kingdom region from master terrain."""
        # Use crop_to_centered_grid for efficient regional extraction
        grid, subregion, regionMapper = self.country.region.crop_to_centered_grid(
            style=StyleCSS("base", fill="lightgray", stroke="blue")
        )
        
        self.subregion = subregion
        self.regionMapper = regionMapper  # Maps local → master grid indices
        
        # Create terrain view for this kingdom
        self.countryMap = Terrain(
            bounds=grid.bounds,
            radius=grid.radius,
            colorLevels=parent.colorLevels,
            seaLevel=parent.seaLevel,
            elevationDelta=parent.elevationDelta,
            geo=parent.geo,
            climate=parent.climate
        )
        self.countryMap.hexGrid = grid
        
        # Copy relevant data from master terrain
        numHexes = len(grid.hexes)
        self.countryMap.elevations = np.zeros(numHexes)
        for field_name in parent.fields.keys():
            self.countryMap.fields[field_name] = np.zeros(numHexes)
        
        # Map data using regionMapper
        self.mapper = {}
        for dest in range(numHexes):
            source = regionMapper(dest)
            if source >= 0:
                self.countryMap.elevations[dest] = parent.elevations[source]
                self.mapper[source] = dest
                for field_name in parent.fields.keys():
                    self.countryMap.fields[field_name][dest] = parent.fields[field_name][source]
```

**Key Insight**: `crop_to_centered_grid()` enables efficient kingdom-level views:
- Each player sees only their region at high detail
- Index mapper allows syncing changes back to master terrain
- Reduces memory and rendering costs
- Natural mechanism for "fog of war" at region boundaries

## Database Storage

**See `docs/DatabaseSchema.md` for current implementation.**

The game uses **GameStorage** (extends GeoStorage with FastLite + SQLite) for persistence.

### Implementation Status

**✅ Implemented** (in `nbs/game/property.ipynb`):
- `PieceRecord` - Full piece state with location, health, size, goals
- `SettlementRecord` - Cities with population and fortification
- `KingdomRecord` - Kingdom metadata and flag
- `KingdomHex` - Territory ownership (hex-level, not watershed-level)
- Cascade save/load pattern (GameBoard → Kingdom → Settlement → Piece)
- Overlay methods for visualization

**❌ Not Yet Implemented**:
- `Game` table for multi-game support
- Turn history/replay
- `TradeRouteRecord` (routes still use Kingdom.encode())

### Actual Schema (Implemented)

**PieceRecord** - Game units:
```python
@dataclass
class PieceRecord:
    id: str = ""              # UUID primary key
    kingdom_id: int = 0       # Owning kingdom
    settlement_id: str = ""   # If stationed at a settlement
    location: int = 0         # Current hex grid_index
    owner_id: int = 0
    size: int = 100
    health: int = 100
    max_health: int = 100
    sight: int = 3
    memory: float = 0.8
    movement_range: int = 4
    harvest_goal: str = ""    # Resources enum value
    settle_progress: int = 0
    settle_threshold: int = 3
    world_id: int = 0
```

**SettlementRecord** - Cities:
```python
@dataclass
class SettlementRecord:
    id: str = ""
    kingdom_id: int = 0
    location: int = 0
    name: str = ""
    size: int = 100
    health: int = 100
    world_id: int = 0
```

**KingdomRecord** - Player civilizations:
```python
@dataclass  
class KingdomRecord:
    id: int = None            # Auto-increment pk
    world_id: int = 0
    country_id: int = 0       # countryId within this world
    country_name: str = ""
    flag_data: str = ""       # CountryFlag.encode()
    capital_settlement_id: str = ""
```

**KingdomHex** - Territory ownership:
```python
@dataclass
class KingdomHex:
    id: int = None
    world_id: int = 0
    kingdom_id: int = 0       # Matches country_id
    grid_index: int = 0       # Fast terrain array access
    q: int = 0                # Cube coordinates for spatial queries
    r: int = 0
    s: int = 0
```

### Ownership Tracking (Implemented)

The implementation chose **hex-level** ownership via `KingdomHex` table:
- Each hex in a kingdom's region gets a row in `KingdomHex`
- Dual indexing: `grid_index` for array access, `(q,r,s)` for spatial queries
- Query ownership: `storage.hex_owner(world_id, grid_index)`
- Rebuild terrain field: `storage.load_country_field(terrain, world_id)`

**Design Choice**: While the original design proposed watershed-level ownership, hex-level provides:
- More flexible territory boundaries
- Easier border visualization (windy edges)
- Support for gradual conquest (not all-or-nothing)

### Save/Load Pattern

```python
# Save entire game state
game_board.save(db=storage, world_id=cover.ident)

# Load game state
board = storage.gameboard(world_id, terrain)

# Save single piece
piece.db = storage
piece.save(world_id=cover.ident)
```

**Performance Notes**:
- Uses `asdict()` for dataclass → dict conversion
- Atomic transactions via `with db.db.conn:`
- Region hex replacement: DELETE old + INSERT new (not per-hex upsert)

### GeoStorage Implementation Example

```python
class GeoStorage:
    """Database interface for HexMagic worlds and games."""
    
    def __init__(self, custom_path=None):
        path = GeoStorage.get_db_path(custom_path)
        self.path = path
        self.createDB()
    
    def createDB(self):
        db = database(self.path)
        self.db = db
        
        # Core terrain tables
        db.create(TerrainWorld, pk='id', if_not_exists=True, transform=True)
        db.create(HexData, pk='id', if_not_exists=True, transform=True)
        db.create(HexWeather, pk='id', if_not_exists=True, transform=True)
        db.create(WatershedMeta, pk='id', if_not_exists=True, transform=True)
        db.create(ChunkBorder, pk='id', if_not_exists=True, transform=True)
        
        # User/game tables
        db.create(User, pk='id', if_not_exists=True, transform=True)
        db.create(Game, pk='id', if_not_exists=True, transform=True)
        db.create(KingdomRecord, pk='id', if_not_exists=True, transform=True)
        db.create(PieceRecord, pk='id', if_not_exists=True, transform=True)
        db.create(TradeRouteRecord, pk='id', if_not_exists=True, transform=True)
        
        # Spatial indices
        db.execute("CREATE INDEX IF NOT EXISTS idx_hex_coords ON hex_data(world_id, q, r, s)")
        db.execute("CREATE INDEX IF NOT EXISTS idx_hex_watershed ON hex_data(world_id, watershed_id)")
        db.execute("CREATE INDEX IF NOT EXISTS idx_weather_coords ON hex_weather(world_id, q, r, s)")
        
        # Game indices
        db.execute("CREATE INDEX IF NOT EXISTS idx_kingdom_game ON kingdom_record(game_id)")
        db.execute("CREATE INDEX IF NOT EXISTS idx_piece_game ON piece_record(game_id, turn_number)")
        db.execute("CREATE INDEX IF NOT EXISTS idx_piece_kingdom ON piece_record(kingdom_id)")
        
        # Store table references
        self.worlds = db.t.terrain_world
        self.hexes = db.t.hex_data
        self.weather = db.t.hex_weather
        self.watersheds = db.t.watershed_meta
        self.users = db.t.user
        self.games = db.t.game
        self.kingdoms = db.t.kingdom_record
        self.pieces = db.t.piece_record
```

## Turn System

### Game Flow

The game uses **region-based, Risk-style turns** rather than hex-by-hex micromanagement:

1. **Strategic Phase** (Player Input):
   - Issue high-level orders: "Attack Region X", "Settle in Region Y"
   - Set piece goals and priorities
   - Manage trade routes and resource allocation

2. **Execution Phase** (AI/Automated):
   - Each piece executes its assigned goal
   - Pieces use AI planning for tactical decisions within strategic goals
   - Movement, combat, settlement happen automatically

3. **Resolution Phase**:
   - Combat results calculated
   - Territory control updated
   - Resources harvested and distributed
   - New pieces spawned

4. **End Phase**:
   - Knowledge decays (fog of war)
   - Turn number increments
   - Game state saved to database

### Turn Processing

```python
@patch
def process_turn(self: GameBoard, turn_number: int):
    """Execute one complete turn for all kingdoms."""
    all_pieces = []
    for kingdom in self.kingdoms:
        all_pieces.extend(kingdom.pieces)
    
    # Phase 1: Knowledge decay
    for kingdom in self.kingdoms:
        for piece in kingdom.pieces:
            piece.decay_knowledge(turn_number)
    
    # Phase 2: Planning
    for kingdom in self.kingdoms:
        for piece in kingdom.pieces:
            piece.plan_next_action(self.terrain, all_pieces, turn_number)
    
    # Phase 3: Execution (simultaneous movement)
    for kingdom in self.kingdoms:
        for piece in kingdom.pieces:
            piece.execute_goal(self.terrain, all_pieces, turn_number)
    
    # Phase 4: Combat resolution
    self.resolve_all_combat(turn_number)
    
    # Phase 5: Harvesting and spawning
    for kingdom in self.kingdoms:
        new_pieces = []
        for piece in kingdom.pieces:
            spawned = piece.harvest_and_spawn(self.terrain, turn_number)
            if spawned:
                new_pieces.append(spawned)
        kingdom.pieces.extend(new_pieces)
    
    # Phase 6: Cleanup
    for kingdom in self.kingdoms:
        kingdom.pieces = [p for p in kingdom.pieces if p.size > 0]  # Remove destroyed
    
    # Phase 7: Save state
    self.save_turn_state(turn_number)
```

### Region-Based Operations with HexRegion

**HexRegion** provides powerful region manipulation:

```python
# Extract kingdom's view
grid, subregion, mapper = kingdom.region.crop_to_centered_grid(
    style=StyleCSS("base", fill="lightgray", stroke="blue"),
    padding=5  # Extra rings for border context
)

# mapper(local_idx) -> master_idx allows bidirectional sync
for local_idx in range(len(grid.hexes)):
    master_idx = mapper(local_idx)
    if master_idx >= 0:
        # Sync changes back to master terrain
        master_terrain.elevations[master_idx] = kingdom_terrain.elevations[local_idx]
```

**Benefits of HexRegion approach**:
- Players operate on manageable regional views
- Changes propagate back to master world via index mapper
- Natural "fog of war" boundary at region edges
- Efficient rendering (only draw active regions)
- Database queries scoped to relevant regions

## Web Interface

### Layout (5-Panel Design)

```
┌─────────────┬───────────────────────────┬──────────────┐
│   Menu      │                           │   Debug      │
│   Panel     │       Map Viewport        │   Console    │
│   (Top)     │                           │              │
├─────────────┤                           │              │
│   Detail    │                           │              │
│   Panel     │                           │              │
│  (Bottom)   │                           │              │
└─────────────┴───────────────────────────┴──────────────┘
               Overlay Toggles
```

#### 1. Menu Panel (Left Top)
**File Operations**:
- New Game / Load Game / Save Game
- Duplicate World
- Export Map (SVG, PNG)

**Navigation**:
- Kingdom selector dropdown
- Jump to capital / settlements
- Center on selected piece

**Piece Management**:
- List unmoved pieces (clickable)
- Filter by goal type (explore, attack, settle)
- Batch assign goals

#### 2. Detail Panel (Left Bottom)
**Context-Sensitive Display**:
- **Kingdom Selected**: Territory size, food reserves, piece count, trade routes
- **Piece Selected**: Size, health, goal, position, known hexes count
- **Hex Selected**: Elevation, climate, watershed, owner, resources
- **City Selected**: Population, food storage, production rate, defensive bonus

**Quick Actions**:
- Set piece goal
- Build trade route
- Upgrade settlement

#### 3. Map Viewport (Center)
**Primary Game View**:
- SVG-rendered terrain with zoom/pan
- Pieces rendered as circles with health colors
- Selected piece highlighted
- Fog of war overlay (gray out unknown hexes)

**Interactions**:
- Click hex: Show details, move piece
- Click piece: Select and show details
- Right-click: Context menu (attack, settle, etc.)
- Drag: Pan map
- Scroll: Zoom in/out

#### 4. Overlay Toggles (Below Map)
**Checkboxes to show/hide**:
- [ ] Climate zones (color overlay)
- [ ] Watersheds (boundary lines)
- [ ] Trade routes (lines with thickness = level)
- [ ] Elevation contours
- [ ] Piece vision ranges (circles)
- [ ] Territory borders
- [ ] Fog of war

**Rendering**:
Each overlay is an SVG layer that can be toggled on/off via CSS class.

#### 5. Debug Console (Right Side)
**Log Output**:
- Turn events ("Piece A23 settled", "Kingdom 1 conquered Watershed 5")
- Combat results ("Battle: Attacker 45 → 30, Defender 50 → 20")
- AI decisions ("Piece A23: Goal EXPLORE → SETTLE (size threshold)")
- Errors and warnings

**Dev Tools** (if debug mode enabled):
- Database query inspector
- Terrain field values at cursor
- Performance metrics (render time, turn time)

### Web Routes (FastHTML)

```python
# Game management
GET  /games                    # List all games
GET  /games/{game_id}          # Game view (main interface)
POST /games/new                # Create new game
POST /games/{game_id}/save     # Save current state
POST /games/{game_id}/turn     # Process turn

# Kingdom operations
GET  /games/{game_id}/kingdoms/{kingdom_id}  # Kingdom details
POST /games/{game_id}/kingdoms/{kingdom_id}/goal  # Set kingdom-wide goal

# Piece operations
GET  /games/{game_id}/pieces/{piece_id}           # Piece details
POST /games/{game_id}/pieces/{piece_id}/move      # Move piece
POST /games/{game_id}/pieces/{piece_id}/goal      # Set piece goal

# Map rendering
GET  /games/{game_id}/map           # Full map SVG
GET  /games/{game_id}/region        # Regional crop (query params: q, r, s, rings)
GET  /games/{game_id}/overlays/{type}  # Climate, watersheds, routes, etc.

# User
GET  /login
POST /login
GET  /logout
```

### HTMX Integration

**Real-Time Updates**:
```html
<!-- Piece list updates when turn processes -->
<div hx-get="/games/{game_id}/pieces" 
     hx-trigger="every 5s" 
     hx-swap="innerHTML">
  <!-- Piece list here -->
</div>

<!-- Detail panel updates on click -->
<div hx-get="/games/{game_id}/pieces/123" 
     hx-trigger="click from:#piece-123" 
     hx-target="#detail-panel">
</div>
```

**Overlay Toggles**:
```html
<input type="checkbox" 
       hx-post="/games/{game_id}/toggle-overlay" 
       hx-vals='{"layer": "climate"}'
       hx-target="#map-viewport"
       hx-swap="outerHTML">
Show Climate
```

### Performance Considerations

1. **Viewport Culling**: Only render hexes in visible region
2. **Overlay Caching**: Pre-generate overlay SVGs, toggle via CSS
3. **Incremental Updates**: Use HTMX to update only changed elements
4. **Progressive Loading**: Load base terrain first, overlays async
5. **Database Queries**: Use spatial indices for fast hex lookups

### Multi-User Support

**Per-User View State** (stored in database):
```python
@dataclass
class ViewState:
    user_id: int
    game_id: int
    center_q: int  # Current viewport center
    center_r: int
    center_s: int
    zoom_level: float
    overlays_visible: str  # JSON list: ["climate", "routes"]
    selected_piece_id: Optional[str]
```

**Benefits**:
- Each player has independent viewport
- Return to exact view on reconnect
- Spectators can browse without affecting players
	
	