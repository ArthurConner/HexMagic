# Database Extension Guide

## Overview

This guide explains how to extend the HexMagic database system (`database.py`) with new tables for game mechanics. The current database focuses on terrain storage with temporal versioning. This document covers how to add game-related tables (like `Country`, `Game`, `Move`) while maintaining consistency with the existing patterns.

## Current Database Architecture

### Core Philosophy
1. **Temporal Versioning**: HexData uses `modified` timestamps to track state changes over time
2. **Minimal Core**: `TerrainWorld` and `HexData` store only essential terrain fields
3. **Terrain Fields in DB**: Moving terrain fields (temperature, precipitation, climate) into the database
4. **Universal Coordinates**: All hex data indexed by (q,r,s) HexPosition coordinates

### Existing Tables

#### TerrainWorld
Metadata for stored terrains:
```python
@dataclass
class TerrainWorld:
    id: int = None
    name: str = ""
    hex_radius: float = 25.0
    nrows: int = 0
    ncols: int = 0
    sea_level: float = 0.0
    elevation_delta: float = 90.0
    extras: str = ""  # JSON-encoded extra data
    created: int = 0
    modified: int = 0
```

#### HexData
Individual hex data with temporal versioning:
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
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    distance_from_coast: Optional[float] = None
    modified: int = 0  # Unix timestamp - enables temporal queries
```

**Key Pattern**: The `_latest_hex_subquery()` method queries the most recent state:
```python
def _latest_hex_subquery(self: GeoStorage, world_id: int, as_of: int = None) -> str:
    time_clause = f"AND modified <= {as_of}" if as_of else ""
    return f"""
        SELECT world_id, q, r, s, MAX(modified) as max_mod
        FROM hex_data
        WHERE world_id = {world_id} {time_clause}
        GROUP BY world_id, q, r, s
    """
```

#### User
Basic user tracking:
```python
@dataclass
class User:
    username: str
    email: str
    password: str
    created: int
    sessionID: str
    activeWorld: int  # FK to world_id
    id: int = None
```

## Extending with Game Tables

### Design Principles

1. **Separation of Concerns**
   - Core terrain data: `TerrainWorld`, `HexData`
   - Game mechanics: `Game`, `Country`, `Move`, `Territory`
   - UI state: `ViewState` (per-user, per-game)

2. **Temporal Versioning for Dynamic Data**
   - Use `modified` timestamp pattern for data that changes over time
   - Examples: territory ownership, unit positions, resources
   - Enables: historical queries, replay, undo/redo

3. **Normalized vs Encoded**
   - **Normalize**: Data you need to query/filter (country ownership, unit positions)
   - **Encode**: Complex objects that move together (Kingdom.encode(), Piece.encode())

4. **Auto-Trimming Strategy**
   - Keep recent history (last N turns or last N days)
   - Archive old snapshots to separate table or compressed format
   - Provide manual "save checkpoint" to preserve important states

### Recommended Game Schema

#### Game Table
Top-level game instance:

```python
@dataclass
class Game:
    """A game instance with kingdoms and pieces."""
    id: int = None
    world_id: int = 0  # FK to TerrainWorld
    name: str = ""
    
    # Game configuration (encoded)
    # Contains: initial kingdoms, rules, win conditions
    game_config: str = ""
    
    # Current state
    turn_number: int = 0
    is_active: bool = True
    is_public: bool = False
    
    # Ownership
    created_by: int = 0  # FK to User
    created: int = 0
    modified: int = 0
```

**Why this design:**
- Links to `world_id` instead of embedding terrain
- One world can support multiple games
- `game_config` stores immutable setup (rules, initial conditions)
- Mutable state goes in other tables (Country, Move, Territory)

#### Country Table
Kingdom/civilization data:

```python
@dataclass
class Country:
    """A country/kingdom in a game."""
    id: int = None
    game_id: int = 0  # FK to Game
    country_id: int = 0  # Stable ID within game (0-N)
    
    # Identity
    country_name: str = ""
    flag_data: str = ""  # Encoded CountryFlag
    
    # Ownership
    user_id: Optional[int] = None  # FK to User (None = AI)
    
    # State (encoded Kingdom object or key fields)
    # Option 1: Store full Kingdom.encode()
    kingdom_data: str = ""
    
    # Option 2: Store key fields + separate tables for pieces/settlements
    # capital_hex_q: int = 0
    # capital_hex_r: int = 0
    # capital_hex_s: int = 0
    # treasury: int = 0
    
    # Temporal versioning
    created: int = 0
    modified: int = 0  # Last state change
```

**Design Decision: Encoded vs Normalized**

Choose based on query patterns:

**Option A: Encoded (Simpler, Good for Small Games)**
```python
# Store entire Kingdom as JSON
kingdom_data: str = ""  # Kingdom.encode()

# Pros: Simple, maintains object integrity
# Cons: Can't query "all countries with >1000 gold"
```

**Option B: Normalized (Better for Queries)**
```python
# Split Kingdom into queryable fields
capital_q: int = 0
capital_r: int = 0
treasury: int = 0
# Store complex data (pieces, routes) in separate tables

# Pros: Can query, filter, aggregate
# Cons: More tables, more joins
```

**Recommendation**: Start with Option A, migrate to Option B if you need advanced queries.

#### Territory Table
Hex ownership with temporal versioning:

```python
@dataclass
class Territory:
    """Hex ownership tracking with history."""
    id: int = None
    game_id: int = 0
    
    # Hex position
    q: int = 0
    r: int = 0
    s: int = 0
    
    # Ownership
    country_id: int = 0  # Which country owns this hex
    
    # Temporal versioning
    modified: int = 0  # When ownership changed
```

**Key Features:**
- Enables "who owned this hex at turn 50?"
- Multiple records per (game_id, q, r, s) with different timestamps
- Use similar pattern to `_latest_hex_subquery()`:

```python
def _latest_territory_subquery(self: GeoStorage, game_id: int, as_of: int = None) -> str:
    time_clause = f"AND modified <= {as_of}" if as_of else ""
    return f"""
        SELECT game_id, q, r, s, country_id, MAX(modified) as max_mod
        FROM territory
        WHERE game_id = {game_id} {time_clause}
        GROUP BY game_id, q, r, s
    """
```

**Indices:**
```python
# In createDB()
db.execute("CREATE INDEX IF NOT EXISTS idx_territory_game ON territory(game_id)")
db.execute("CREATE INDEX IF NOT EXISTS idx_territory_coords ON territory(game_id, q, r, s)")
db.execute("CREATE INDEX IF NOT EXISTS idx_territory_temporal ON territory(game_id, q, r, s, modified DESC)")
db.execute("CREATE INDEX IF NOT EXISTS idx_territory_country ON territory(game_id, country_id, modified DESC)")
```

#### Move Table
Player turns/actions:

```python
@dataclass
class Move:
    """A player action/turn."""
    id: int = None
    game_id: int = 0
    turn_number: int = 0
    country_id: int = 0  # Which country made this move
    
    # Move data (encoded action)
    move_type: str = ""  # "settle", "move_unit", "build", "trade"
    move_data: str = ""  # JSON with action details
    
    # Result
    success: bool = True
    result_message: str = ""
    
    # Timing
    created: int = 0  # When move was made
```

**Move Types:**
- `settle`: Found new city
- `move_unit`: Move piece from hex A to hex B
- `build`: Construct building/improvement
- `trade`: Establish trade route
- `combat`: Attack/defend
- `research`: Tech/culture advancement

**Example move_data:**
```json
{
  "type": "move_unit",
  "piece_id": 42,
  "from_q": 10, "from_r": -5, "from_s": -5,
  "to_q": 11, "to_r": -5, "to_s": -6,
  "path": [[10,-5,-5], [11,-5,-6]]
}
```

#### ViewState Table
Per-user UI preferences:

```python
@dataclass
class ViewState:
    """UI state for a user viewing a game."""
    id: int = None
    user_id: int = 0
    game_id: int = 0
    
    # Viewport
    view_mode: str = "world"  # "world", "country", "region"
    focused_country_id: Optional[int] = None
    
    # Camera (for future pan/zoom)
    viewport_center_q: int = 0
    viewport_center_r: int = 0
    viewport_zoom: float = 1.0
    
    # Overlay toggles (JSON)
    active_overlays: str = "{}"  # {"climate": true, "routes": false, ...}
    
    # Temporal
    modified: int = 0
```

**Default overlays:**
```python
{
    "countries": true,
    "settlements": true, 
    "names": true,
    "routes": false,
    "climate": false,
    "watersheds": false
}
```

### Complete Schema Addition

Add to `GeoStorage.createDB()`:

```python
def createDB(self):
    db = database(self.path)
    self.db = db
    
    # Existing tables
    db.create(TerrainWorld, pk='id', if_not_exists=True, transform=True)
    db.create(HexData, pk='id', if_not_exists=True, transform=True)
    db.create(User, pk='id', if_not_exists=True, transform=True)
    
    # NEW: Game tables
    db.create(Game, pk='id', if_not_exists=True, transform=True)
    db.create(Country, pk='id', if_not_exists=True, transform=True)
    db.create(Territory, pk='id', if_not_exists=True, transform=True)
    db.create(Move, pk='id', if_not_exists=True, transform=True)
    db.create(ViewState, pk='id', if_not_exists=True, transform=True)
    
    # Existing indices
    db.execute("CREATE INDEX IF NOT EXISTS idx_hex_world ON hex_data(world_id)")
    db.execute("CREATE INDEX IF NOT EXISTS idx_hex_coords ON hex_data(world_id, q, r, s)")
    db.execute("CREATE INDEX IF NOT EXISTS idx_hex_grid ON hex_data(world_id, grid_index)")
    db.execute("CREATE INDEX IF NOT EXISTS idx_hex_temporal ON hex_data(world_id, q, r, s, modified DESC)")
    
    # NEW: Game indices
    db.execute("CREATE INDEX IF NOT EXISTS idx_game_world ON game(world_id)")
    db.execute("CREATE INDEX IF NOT EXISTS idx_game_active ON game(is_active, created_by)")
    
    db.execute("CREATE INDEX IF NOT EXISTS idx_country_game ON country(game_id)")
    db.execute("CREATE INDEX IF NOT EXISTS idx_country_user ON country(user_id)")
    
    db.execute("CREATE INDEX IF NOT EXISTS idx_territory_game ON territory(game_id)")
    db.execute("CREATE INDEX IF NOT EXISTS idx_territory_coords ON territory(game_id, q, r, s)")
    db.execute("CREATE INDEX IF NOT EXISTS idx_territory_temporal ON territory(game_id, q, r, s, modified DESC)")
    db.execute("CREATE INDEX IF NOT EXISTS idx_territory_country ON territory(game_id, country_id, modified DESC)")
    
    db.execute("CREATE INDEX IF NOT EXISTS idx_move_game_turn ON move(game_id, turn_number)")
    db.execute("CREATE INDEX IF NOT EXISTS idx_move_country ON move(game_id, country_id)")
    
    db.execute("CREATE INDEX IF NOT EXISTS idx_viewstate_user_game ON view_state(user_id, game_id)")
    
    # Store table references
    self.users = db.t.user
    self.hexes = db.t.hex_data
    self.worlds = db.t.terrain_world
    
    # NEW: Game table references
    self.games = db.t.game
    self.countries = db.t.country
    self.territories = db.t.territory
    self.moves = db.t.move
    self.view_states = db.t.view_state
```

## Auto-Trimming Strategy

### Problem
Over time, temporal tables (Territory, Move) can grow very large:
- 1000 hexes changing ownership each turn
- 100 turns = 100K territory records
- Need to balance history vs database size

### Solution: Tiered Retention

```python
@dataclass
class TrimPolicy:
    """Auto-trim configuration."""
    # Recent history: keep everything
    recent_turns: int = 10  # Keep last 10 turns in full detail
    
    # Mid-range: keep snapshots
    snapshot_interval: int = 5  # Keep every 5th turn
    snapshot_depth: int = 50  # For 50 turns back
    
    # Archive old data
    archive_after_turns: int = 100  # Move to archive table
    
    # Manual checkpoints
    preserve_checkpoints: bool = True  # Never delete user-saved states
```

### Implementation

#### Checkpoint Table
```python
@dataclass
class GameCheckpoint:
    """User-saved game states to preserve."""
    id: int = None
    game_id: int = 0
    turn_number: int = 0
    name: str = ""  # "Before big battle", "Turn 50"
    
    # Full game snapshot (encoded)
    game_state: str = ""  # Complete GameBoard.encode()
    
    created_by: int = 0
    created: int = 0
```

#### Auto-Trim Implementation

```python
@patch
def auto_trim_game_history(self: GeoStorage, game_id: int, policy: TrimPolicy):
    """Trim old game history according to policy."""
    from datetime import datetime
    
    # Get current turn
    game = self.games[game_id]
    current_turn = game.turn_number
    
    # Don't trim recent turns
    cutoff_turn = current_turn - policy.recent_turns
    
    if cutoff_turn <= 0:
        return  # Nothing to trim yet
    
    # Trim territories
    self._trim_territories(game_id, cutoff_turn, policy)
    
    # Trim moves
    self._trim_moves(game_id, cutoff_turn, policy)
    
    print(f"✓ Trimmed game {game_id} history (keeping last {policy.recent_turns} turns)")

@patch
def _trim_territories(self: GeoStorage, game_id: int, cutoff_turn: int, policy: TrimPolicy):
    """Trim territory history, keeping snapshots."""
    
    # Find turns to preserve (snapshots + checkpoints)
    checkpoint_turns = set()
    checkpoints = self.db.execute(
        "SELECT DISTINCT turn_number FROM game_checkpoint WHERE game_id = ?",
        [game_id]
    ).fetchall()
    checkpoint_turns = {row['turn_number'] for row in checkpoints}
    
    # Keep every Nth turn as snapshot
    snapshot_turns = set(range(0, cutoff_turn, policy.snapshot_interval))
    
    preserve_turns = checkpoint_turns | snapshot_turns
    
    # Find timestamps for turns to preserve
    preserve_times = []
    for turn in preserve_turns:
        # Get timestamp for this turn (from Move table)
        move = self.db.execute(
            "SELECT MIN(created) as ts FROM move WHERE game_id = ? AND turn_number = ?",
            [game_id, turn]
        ).fetchone()
        if move and move['ts']:
            preserve_times.append(move['ts'])
    
    # Delete territories not in preserve set
    if preserve_times:
        placeholders = ','.join(['?' for _ in preserve_times])
        self.db.execute(f"""
            DELETE FROM territory 
            WHERE game_id = ? 
            AND modified NOT IN ({placeholders})
        """, [game_id] + preserve_times)
    
@patch
def _trim_moves(self: GeoStorage, game_id: int, cutoff_turn: int, policy: TrimPolicy):
    """Trim old move records."""
    # Keep recent + checkpoint turns
    checkpoint_turns = set()
    checkpoints = self.db.execute(
        "SELECT DISTINCT turn_number FROM game_checkpoint WHERE game_id = ?",
        [game_id]
    ).fetchall()
    checkpoint_turns = {row['turn_number'] for row in checkpoints}
    
    # Delete old moves (except checkpoints)
    if checkpoint_turns:
        placeholders = ','.join(['?' for _ in checkpoint_turns])
        self.db.execute(f"""
            DELETE FROM move 
            WHERE game_id = ? 
            AND turn_number < ?
            AND turn_number NOT IN ({placeholders})
        """, [game_id, cutoff_turn] + list(checkpoint_turns))
    else:
        self.db.execute("""
            DELETE FROM move 
            WHERE game_id = ? AND turn_number < ?
        """, [game_id, cutoff_turn])
```

#### Automatic Trigger

Add to `save_game()` or equivalent:

```python
@patch
def save_game_state(self: GeoStorage, game_id: int, board: GameBoard, 
                     auto_trim: bool = True):
    """Save game state and optionally trim old data."""
    from datetime import datetime
    now = int(datetime.now().timestamp())
    
    # Update game record
    self.games.update(game_id,
        turn_number=board.turn_number,
        modified=now
    )
    
    # Save country states
    for kingdom in board.kingdoms:
        self._save_country_state(game_id, kingdom, now)
    
    # Auto-trim if enabled
    if auto_trim and board.turn_number % 10 == 0:  # Every 10 turns
        policy = TrimPolicy(
            recent_turns=10,
            snapshot_interval=5,
            snapshot_depth=50
        )
        self.auto_trim_game_history(game_id, policy)
```

#### Manual Checkpoint

```python
@patch
def create_checkpoint(self: GeoStorage, game_id: int, user_id: int, name: str = ""):
    """Create a manual checkpoint to preserve current game state."""
    from datetime import datetime
    now = int(datetime.now().timestamp())
    
    # Load full game state
    board = self.load_game(game_id)
    
    # Save checkpoint
    self.db.t.game_checkpoint.insert({
        'game_id': game_id,
        'turn_number': board.turn_number,
        'name': name or f"Turn {board.turn_number}",
        'game_state': board.encode(),
        'created_by': user_id,
        'created': now
    })
    
    print(f"✓ Created checkpoint: {name}")
```

## Adding Terrain Fields to Database

### Current Approach
Terrain fields (temperature, precipitation, climate) are currently stored in `Terrain.fields` dict and not in the database.

### Proposed Extension

Add to `HexData`:

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
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    distance_from_coast: Optional[float] = None
    
    # NEW: Terrain fields
    temperature: Optional[float] = None
    precipitation: Optional[float] = None
    climate: Optional[int] = None  # Köppen climate zone
    
    modified: int = 0
```

**Migration Strategy:**

```python
@patch
def save_terrain_fields(self: GeoStorage, world_id: int, terrain: Terrain):
    """Update HexData records with terrain field values."""
    from datetime import datetime
    now = int(datetime.now().timestamp())
    
    grid = terrain.hexGrid
    
    for idx in range(len(grid.hexes)):
        pos = grid.index_to_hexposition(idx)
        
        # Get field values
        temp = terrain.fields.get('temperature', [None])[idx] if 'temperature' in terrain.fields else None
        precip = terrain.fields.get('precipitation', [None])[idx] if 'precipitation' in terrain.fields else None
        climate = terrain.fields.get('climate', [None])[idx] if 'climate' in terrain.fields else None
        
        # Insert new record with updated fields
        self.hexes.insert({
            'world_id': world_id,
            'q': pos.q,
            'r': pos.r,
            's': pos.s,
            'grid_index': idx,
            'elevation': terrain.elevations[idx],
            'temperature': float(temp) if temp is not None else None,
            'precipitation': float(precip) if precip is not None else None,
            'climate': int(climate) if climate is not None else None,
            'distance_from_coast': terrain.fields.get('distance_to_ocean', [None])[idx],
            'modified': now
        })
```

## Usage Examples

### Creating a New Game

```python
from HexMagic.database import GeoStorage
from HexMagic.game.kingdom import GameBoard
from HexMagic.terrain import TerraDemo

# Initialize
db = GeoStorage()

# Create world
terrain = TerraDemo().bayArea_map()
result = db.save_world(terrain, name="Bay Area")
world_id = result.world_id

# Create game
from datetime import datetime
now = int(datetime.now().timestamp())

game_id = db.games.insert({
    'world_id': world_id,
    'name': "Bay Area Campaign",
    'turn_number': 0,
    'is_active': True,
    'created_by': 1,  # user_id
    'created': now,
    'modified': now
})

# Create countries
for i in range(3):
    db.countries.insert({
        'game_id': game_id,
        'country_id': i,
        'country_name': f"Kingdom {i}",
        'flag_data': "",  # CountryFlag.encode()
        'kingdom_data': "",  # Kingdom.encode()
        'created': now,
        'modified': now
    })

print(f"Created game {game_id} with 3 countries")
```

### Querying Territory at Specific Turn

```python
def get_territory_map(db: GeoStorage, game_id: int, turn_number: int):
    """Get territory ownership at a specific turn."""
    
    # Get timestamp for this turn
    move = db.db.execute(
        "SELECT MIN(created) as ts FROM move WHERE game_id = ? AND turn_number = ?",
        [game_id, turn_number]
    ).fetchone()
    
    as_of = move['ts'] if move else None
    
    # Query territories at that time
    query = db._latest_territory_subquery(game_id, as_of=as_of)
    
    territories = db.db.execute(f"""
        SELECT t.* FROM territory t
        INNER JOIN ({query}) latest 
          ON t.game_id = latest.game_id 
          AND t.q = latest.q 
          AND t.r = latest.r 
          AND t.s = latest.s
          AND t.modified = latest.max_mod
    """).fetchall()
    
    # Build ownership map
    ownership = {}
    for row in territories:
        pos = (row['q'], row['r'], row['s'])
        ownership[pos] = row['country_id']
    
    return ownership
```

### Creating Checkpoints

```python
# During gameplay
db.create_checkpoint(
    game_id=1,
    user_id=1,
    name="Before Alliance War"
)

# List checkpoints
checkpoints = db.db.execute("""
    SELECT * FROM game_checkpoint 
    WHERE game_id = ? 
    ORDER BY turn_number DESC
""", [game_id]).fetchall()

for cp in checkpoints:
    print(f"Turn {cp['turn_number']}: {cp['name']}")
```

## Best Practices

1. **Start Simple**: Begin with encoded `kingdom_data`, add normalized tables as query needs emerge

2. **Index Strategically**: Add indices for common queries (game_id + turn, country_id + modified)

3. **Batch Operations**: When saving turn data, use transactions:
   ```python
   with db.db.conn:
       # All inserts here are atomic
       db.territories.insert(...)
       db.moves.insert(...)
   ```

4. **Test Temporal Queries**: Verify `_latest_territory_subquery()` works correctly:
   ```python
   # Should return state at turn 50
   territories = get_territory_map(db, game_id=1, turn_number=50)
   ```

5. **Monitor Database Size**: Check regularly, adjust trim policy:
   ```python
   import os
   size_mb = os.path.getsize(db.path) / (1024 * 1024)
   print(f"Database size: {size_mb:.1f} MB")
   ```

6. **Archive Large Games**: Export completed games to files:
   ```python
   board = db.load_game(game_id)
   with open(f'game_{game_id}_final.json', 'w') as f:
       f.write(board.encode())
   ```

## Summary

This extension maintains the existing database patterns while adding game mechanics:

- **Temporal versioning** for Territory and Move tables
- **Auto-trimming** to control database growth
- **Manual checkpoints** to preserve important states
- **Separation** between world (terrain) and game (kingdoms, moves)
- **Per-user UI state** for multiplayer support

The design is scalable, queryable, and backward-compatible with existing terrain storage.
