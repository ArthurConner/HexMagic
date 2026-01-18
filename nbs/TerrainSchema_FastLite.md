# Terrain Schema Design with FastLite

## Overview

This document proposes a FastLite-based database architecture for HexMagic that:
- **Stores larger worlds**: Use database instead of memory for terrain data
- **Supports multi-user gameplay**: Multiple users can play/view same GameBoard
- **Persists UI state**: Remember what each user is viewing (country zoom, overlay toggles)
- **Efficient queries**: Load only needed regions using HexPosition coordinates
- **Leverages existing code**: Uses your encode/decode methods where appropriate

## Key Design Principles

1. **Hybrid Approach**: Keep existing encode/decode for complex objects (GameBoard, Kingdom), add normalized tables for spatial queries
2. **FastLite Integration**: Use `database()` and dataclass decorators from fastlite
3. **Web-Friendly**: Designed for FastHTML web interface with session management
4. **Incremental Migration**: Can adopt gradually without breaking existing code

---

## Database Schema

### 1. World Table
Stores world metadata and terrain data.

```python
from fastlite import *
from dataclasses import dataclass
from typing import Optional

@dataclass
class World:
    """World contains the terrain and geological features."""
    id: int = None
    name: str = ""
    created: int = 0  # Unix timestamp
    modified: int = 0
    
    # Terrain data (encoded using existing Terrain.encode())
    terrain_data: str = ""
    
    # Geology data (plates, basins)
    geology_data: str = ""
    
    # World parameters
    hex_radius: float = 25.0
    elevation_delta: float = 90.0
    sea_level: float = 0.0
    
    # Optional geographic bounds
    geo_lat_min: Optional[float] = None
    geo_lat_max: Optional[float] = None
    geo_lon_min: Optional[float] = None
    geo_lon_max: Optional[float] = None
    
    # Climate preset (encoded)
    climate_preset: Optional[str] = None
    
    # Metadata
    hex_count: int = 0  # Total hexes in world
    extent_rings: int = 100  # Spatial extent
```

**Design Notes:**
- Stores terrain as encoded string (using existing `Terrain.encode()`)
- One world can be shared by multiple games
- Can add normalized hex tables later for spatial queries

### 2. Game Table (Modified from existing)
Represents a game instance with kingdoms and pieces.

```python
@dataclass
class Game:
    """A game instance played by users."""
    id: int = None
    world_id: int = 0  # FK to World
    name: str = ""
    
    # Game state (encoded using GameBoard.encode())
    # Contains: kingdoms, pieces, turn number, etc.
    game_state: str = ""
    
    # Current turn
    turn_number: int = 0
    
    # Ownership
    created_by: int = 0  # User ID
    last_modified_by: int = 0
    
    # Status
    is_active: bool = True
    is_public: bool = False  # Can others view?
    
    # Timestamps
    created: int = 0
    modified: int = 0
```

**Key Changes from Original:**
- `world_id` separates terrain from game state
- `game_state` contains kingdoms, pieces, routes (encoded)
- `is_public` allows read-only viewing by other users

### 3. User Table
Player accounts and sessions.

```python
@dataclass
class User:
    """User account."""
    id: int = None
    username: str = ""
    email: str = ""
    session_id: str = ""  # Current session token
    
    # Preferences (encoded dict)
    preferences: str = "{}"  # JSON: {theme, default_overlays, etc}
    
    # Timestamps
    created: int = 0
    last_login: int = 0
```

### 4. GamePlayer Table
Many-to-many: which users can access which games.

```python
@dataclass
class GamePlayer:
    """Links users to games they can play/view."""
    id: int = None
    game_id: int = 0
    user_id: int = 0
    
    # Access level
    role: str = "player"  # 'owner', 'player', 'viewer'
    
    # Which kingdom does this player control?
    kingdom_id: Optional[int] = None  # References kingdom within game_state
    
    # Joined
    created: int = 0
```

**Usage:**
- Game owner: `role='owner'`, can modify everything
- Active player: `role='player'`, controls a kingdom
- Spectator: `role='viewer'`, read-only access

### 5. ViewState Table
**NEW**: Persists UI state per user per game.

```python
@dataclass
class ViewState:
    """UI state for a user viewing a game."""
    id: int = None
    user_id: int = 0
    game_id: int = 0
    
    # Viewport settings
    view_mode: str = "world"  # 'world', 'country', 'region'
    
    # If zoomed to a country
    focused_country_id: Optional[int] = None
    
    # If viewing a specific region (encoded HexRegion)
    focused_region: Optional[str] = None
    
    # Overlay toggles (JSON dict)
    # {"countries": true, "routes": false, "climate": true, "watersheds": false}
    active_overlays: str = "{}"
    
    # Camera position (for future pan/zoom)
    viewport_center_q: int = 0
    viewport_center_r: int = 0
    viewport_zoom: float = 1.0
    
    # Last updated
    modified: int = 0
```

**Purpose:**
- Remembers what each user was viewing when they left
- Enables per-user UI customization
- Allows multiple users to view same game differently

### 6. GlobalField Table
**NEW**: Normalized storage for frequently-queried hex data.

```python
@dataclass
class GlobalField:
    """Field values for hexes in a world (normalized for queries)."""
    id: int = None
    world_id: int = 0
    
    # Hex position (universal coordinates)
    q: int = 0
    r: int = 0
    s: int = 0
    
    # Field name and value
    field_name: str = ""  # 'elevation', 'temperature', 'country_id', etc.
    value: float = 0.0
    
    # Spatial indexing helpers
    ring: int = 0  # Distance from origin
    sector: int = 0  # Angular sector (0-5)
```

**Indices:**
```python
# When creating table
db.create(GlobalField, pk='id', if_not_exists=True, transform=True)
db.execute("CREATE INDEX IF NOT EXISTS idx_field_lookup ON global_field(world_id, q, r, s, field_name)")
db.execute("CREATE INDEX IF NOT EXISTS idx_field_spatial ON global_field(world_id, field_name, ring, sector)")
db.execute("CREATE INDEX IF NOT EXISTS idx_field_value ON global_field(world_id, field_name, value)")
```

**Usage:**
- Query "which hexes have country_id=5?"
- Query "all elevations in ring 10-20"
- Enables spatial filtering without deserializing entire terrain
- **Optional**: Populate only when needed for performance

### 7. Autosave Table (Keep existing)
Unchanged from current implementation.

```python
@dataclass
class Autosave:
    """Historical snapshots of game state."""
    id: int = None
    game_id: int = 0
    user_id: int = 0
    turn_number: int = 0
    
    # Game state at this turn
    game_state: str = ""
    
    created: int = 0
```

### 8. Template Table (Keep existing)
Unchanged - stores starting worlds.

```python
@dataclass
class Template:
    """Starting world templates."""
    id: int = None
    name: str = ""
    description: str = ""
    
    # Points to a World record
    world_id: int = 0
    
    created: int = 0
```

---

## HexServer Implementation

### Database Initialization

```python
from fastlite import *
from pathlib import Path

class HexServer:
    """Enhanced HexServer using FastLite."""
    
    def __init__(self, custom_path=None):
        self.path = self.get_db_path(custom_path)
        self.db = database(self.path)
        self.create_tables()
        self.populate_templates()
    
    def create_tables(self):
        """Create all tables using FastLite."""
        # Existing tables
        self.users = self.db.create(User, pk='id', if_not_exists=True, transform=True)
        self.autosaves = self.db.create(Autosave, pk='id', if_not_exists=True, transform=True)
        
        # New tables
        self.worlds = self.db.create(World, pk='id', if_not_exists=True, transform=True)
        self.games = self.db.create(Game, pk='id', if_not_exists=True, transform=True)
        self.game_players = self.db.create(GamePlayer, pk='id', if_not_exists=True, transform=True)
        self.view_states = self.db.create(ViewState, pk='id', if_not_exists=True, transform=True)
        self.templates = self.db.create(Template, pk='id', if_not_exists=True, transform=True)
        
        # Optional: GlobalField for spatial queries
        self.global_fields = self.db.create(GlobalField, pk='id', if_not_exists=True, transform=True)
        
        # Create indices
        self._create_indices()
    
    def _create_indices(self):
        """Create database indices for performance."""
        # Game access
        self.db.execute("CREATE INDEX IF NOT EXISTS idx_game_world ON game(world_id)")
        self.db.execute("CREATE INDEX IF NOT EXISTS idx_game_active ON game(is_active, created_by)")
        
        # Player access
        self.db.execute("CREATE INDEX IF NOT EXISTS idx_player_game ON game_player(game_id, user_id)")
        self.db.execute("CREATE INDEX IF NOT EXISTS idx_player_user ON game_player(user_id)")
        
        # View state
        self.db.execute("CREATE INDEX IF NOT EXISTS idx_view_user_game ON view_state(user_id, game_id)")
        
        # GlobalField (if using)
        self.db.execute("CREATE INDEX IF NOT EXISTS idx_field_lookup ON global_field(world_id, q, r, s, field_name)")
        self.db.execute("CREATE INDEX IF NOT EXISTS idx_field_spatial ON global_field(world_id, field_name, ring)")
    
    @staticmethod
    def get_db_path(custom_path=None):
        """Get database path (same as before)."""
        if custom_path:
            return custom_path
        
        try:
            from importlib import resources
            db_dir = resources.files('HexMagic').joinpath('data/db')
            db_path = Path(db_dir) / 'hexmagic.db'
            db_path.parent.mkdir(parents=True, exist_ok=True)
            db_path.touch(exist_ok=True)
            return str(db_path)
        except (PermissionError, OSError):
            data_dir = Path.home() / '.hexmagic' / 'data'
            data_dir.mkdir(parents=True, exist_ok=True)
            return str(data_dir / 'hexmagic.db')
```

---

## Core Operations

### World Management

```python
@patch
def create_world_from_terrain(self: HexServer, terrain: Terrain, geology: Geology, name: str = "") -> int:
    """Create a new world from existing Terrain and Geology objects."""
    from datetime import datetime
    now = int(datetime.now().timestamp())
    
    world = World(
        name=name or "Unnamed World",
        terrain_data=terrain.encode(),
        geology_data=geology.encode() if geology else "",
        hex_radius=terrain.hexGrid.radius,
        elevation_delta=terrain.elevationDelta,
        sea_level=terrain.seaLevel.properties.get('fill', '#81b1e1ff'),
        hex_count=len(terrain.elevations),
        created=now,
        modified=now
    )
    
    # Add geographic bounds if present
    if terrain.geo:
        world.geo_lat_min = terrain.geo.lat_min
        world.geo_lat_max = terrain.geo.lat_max
        world.geo_lon_min = terrain.geo.lon_min
        world.geo_lon_max = terrain.geo.lon_max
    
    # Add climate preset if present
    if terrain.climate:
        world.climate_preset = terrain.climate.encode()
    
    result = self.worlds.insert(world)
    world_id = result.id if hasattr(result, 'id') else result['id']
    
    # Optionally populate GlobalField table for spatial queries
    # self._populate_global_fields(world_id, terrain)
    
    return world_id

@patch
def load_world(self: HexServer, world_id: int) -> tuple[Terrain, Geology]:
    """Load terrain and geology from world record."""
    world = self.worlds[world_id]
    
    # Decode terrain
    terrain = Terrain.decode(world.terrain_data)
    
    # Decode geology if present
    geology = None
    if world.geology_data:
        geology = Geology.decode(world.geology_data)
    
    return terrain, geology

@patch
def update_world(self: HexServer, world_id: int, terrain: Terrain, geology: Geology = None):
    """Update world with modified terrain/geology."""
    from datetime import datetime
    now = int(datetime.now().timestamp())
    
    update_data = {
        'terrain_data': terrain.encode(),
        'modified': now,
        'hex_count': len(terrain.elevations)
    }
    
    if geology:
        update_data['geology_data'] = geology.encode()
    
    self.worlds.update(world_id, **update_data)
```

### Game Management

```python
@patch
def create_game_from_world(self: HexServer, user_id: int, world_id: int, 
                           game_name: str = "", **board_params) -> int:
    """Create a new game from an existing world."""
    from datetime import datetime
    now = int(datetime.now().timestamp())
    
    # Load world
    terrain, geology = self.load_world(world_id)
    
    # Create GameBoard
    board = GameBoard(terrain, **board_params)
    
    # Create game record
    game = Game(
        world_id=world_id,
        name=game_name or f"Game from {self.worlds[world_id].name}",
        game_state=board.encode(),
        turn_number=0,
        created_by=user_id,
        last_modified_by=user_id,
        is_active=True,
        created=now,
        modified=now
    )
    
    result = self.games.insert(game)
    game_id = result.id if hasattr(result, 'id') else result['id']
    
    # Make creator the owner
    self.game_players.insert(GamePlayer(
        game_id=game_id,
        user_id=user_id,
        role='owner',
        created=now
    ))
    
    # Create default view state
    self._create_default_view_state(user_id, game_id)
    
    return game_id

@patch
def load_game(self: HexServer, game_id: int) -> GameBoard:
    """Load a game as a GameBoard object."""
    game = self.games[game_id]
    
    # Load the world to get terrain
    terrain, geology = self.load_world(game.world_id)
    
    # Decode game state
    board = GameBoard.decode(game.game_state)
    
    # Ensure board has correct terrain reference
    board.terrain = terrain
    board.world = geology
    
    return board

@patch
def save_game(self: HexServer, game_id: int, board: GameBoard, user_id: int, 
              create_autosave: bool = True):
    """Save game state."""
    from datetime import datetime
    now = int(datetime.now().timestamp())
    
    game = self.games[game_id]
    
    # Create autosave if requested
    if create_autosave and game.game_state:
        self.autosaves.insert(Autosave(
            game_id=game_id,
            user_id=user_id,
            turn_number=game.turn_number,
            game_state=game.game_state,
            created=now
        ))
        
        # Keep only last 10 autosaves
        self._cleanup_autosaves(game_id)
    
    # Update game
    self.games.update(game_id, 
        game_state=board.encode(),
        turn_number=board.turn_number if hasattr(board, 'turn_number') else game.turn_number,
        last_modified_by=user_id,
        modified=now
    )

@patch
def _cleanup_autosaves(self: HexServer, game_id: int, keep: int = 10):
    """Keep only the most recent autosaves."""
    self.db.execute("""
        DELETE FROM autosave 
        WHERE game_id = ? 
        AND id NOT IN (
            SELECT id FROM autosave 
            WHERE game_id = ? 
            ORDER BY turn_number DESC, created DESC
            LIMIT ?
        )
    """, [game_id, game_id, keep])
```

### User Access Control

```python
@patch
def can_access_game(self: HexServer, user_id: int, game_id: int) -> bool:
    """Check if user can access a game."""
    # Check if public
    game = self.games[game_id]
    if game.is_public:
        return True
    
    # Check GamePlayer table
    access = list(self.game_players.rows_where(
        'game_id = ? AND user_id = ?', 
        [game_id, user_id]
    ))
    return len(access) > 0

@patch
def get_user_role(self: HexServer, user_id: int, game_id: int) -> Optional[str]:
    """Get user's role in a game."""
    access = list(self.game_players.rows_where(
        'game_id = ? AND user_id = ?', 
        [game_id, user_id]
    ))
    return access[0].role if access else None

@patch
def add_player_to_game(self: HexServer, game_id: int, user_id: int, 
                       role: str = 'viewer', kingdom_id: int = None):
    """Add a player to a game."""
    from datetime import datetime
    now = int(datetime.now().timestamp())
    
    self.game_players.insert(GamePlayer(
        game_id=game_id,
        user_id=user_id,
        role=role,
        kingdom_id=kingdom_id,
        created=now
    ))
    
    # Create view state for new player
    self._create_default_view_state(user_id, game_id)
```

### View State Management

```python
@patch
def _create_default_view_state(self: HexServer, user_id: int, game_id: int):
    """Create default view state for a user."""
    from datetime import datetime
    import json
    now = int(datetime.now().timestamp())
    
    default_overlays = {
        "countries": True,
        "routes": False,
        "climate": False,
        "watersheds": False,
        "settlements": True,
        "names": True
    }
    
    self.view_states.insert(ViewState(
        user_id=user_id,
        game_id=game_id,
        view_mode='world',
        active_overlays=json.dumps(default_overlays),
        viewport_zoom=1.0,
        modified=now
    ))

@patch
def get_view_state(self: HexServer, user_id: int, game_id: int) -> ViewState:
    """Get user's view state for a game."""
    states = list(self.view_states.rows_where(
        'user_id = ? AND game_id = ?',
        [user_id, game_id]
    ))
    
    if not states:
        self._create_default_view_state(user_id, game_id)
        states = list(self.view_states.rows_where(
            'user_id = ? AND game_id = ?',
            [user_id, game_id]
        ))
    
    return states[0]

@patch
def update_view_state(self: HexServer, user_id: int, game_id: int, **updates):
    """Update user's view state."""
    from datetime import datetime
    import json
    now = int(datetime.now().timestamp())
    
    view_state = self.get_view_state(user_id, game_id)
    
    # Handle overlay updates
    if 'overlays' in updates:
        current = json.loads(view_state.active_overlays)
        current.update(updates.pop('overlays'))
        updates['active_overlays'] = json.dumps(current)
    
    updates['modified'] = now
    
    self.view_states.update(view_state.id, **updates)
```

---

## Web Integration

### FastHTML Route Helpers

```python
# In web.py or similar

def get_user_id(session) -> int:
    """Get or create user ID from session."""
    if 'user_id' not in session:
        # Create anonymous user
        from datetime import datetime
        now = int(datetime.now().timestamp())
        
        user = server.users.insert(User(
            username=f"user_{now}",
            session_id=session.get('session_id', ''),
            created=now,
            last_login=now
        ))
        session['user_id'] = user.id if hasattr(user, 'id') else user['id']
    
    return session['user_id']

def get_active_game(session, server: HexServer) -> Optional[int]:
    """Get user's active game ID."""
    user_id = get_user_id(session)
    
    # Get most recent game user has access to
    games = list(server.db.execute("""
        SELECT g.id FROM game g
        JOIN game_player gp ON g.id = gp.game_id
        WHERE gp.user_id = ? AND g.is_active = 1
        ORDER BY g.modified DESC
        LIMIT 1
    """, [user_id]))
    
    return games[0]['id'] if games else None

def get_or_create_game(session, server: HexServer) -> int:
    """Get active game or create new one."""
    game_id = get_active_game(session, server)
    
    if game_id is None:
        user_id = get_user_id(session)
        # Create from first template
        templates = list(server.templates())
        if templates:
            template = templates[0]
            game_id = server.create_game_from_world(
                user_id=user_id,
                world_id=template.world_id,
                game_name="My Game",
                top_n=3
            )
    
    return game_id
```

### Updated showMap Route

```python
@rt
def showMap(session):
    """Show the map with user's view state."""
    user_id = get_user_id(session)
    game_id = get_or_create_game(session, server)
    
    if game_id is None:
        return RedirectResponse('/newgame', status_code=303)
    
    # Check access
    if not server.can_access_game(user_id, game_id):
        return Div("You don't have access to this game")
    
    # Load game
    board = server.load_game(game_id)
    
    # Get user's view state
    view_state = server.get_view_state(user_id, game_id)
    
    # Build map based on view mode
    terrain = board.terrain
    grid = terrain.hexGrid
    builder = grid.builder
    
    terrain.colorMap()
    grid.update()
    
    builder.layers = []
    terrain.terrainCream()
    
    # Apply overlays based on view state
    import json
    overlays = json.loads(view_state.active_overlays)
    
    if overlays.get('climate', False):
        terrain.compute_climate()
        builder.adjust("climates", terrain.dottedClimate())
    
    if overlays.get('settlements', True):
        builder.adjust("settlement", board.settlements_overlay())
    
    if overlays.get('countries', True):
        builder.adjust("countries", board.countries_overlay())
    
    if overlays.get('watersheds', False):
        builder.adjust("water", board.world.basins.draw_watersheds())
    
    if overlays.get('routes', False):
        builder.adjust("routes", board.trade_overlay())
    
    if overlays.get('names', True):
        builder.adjust("names", board.names_overlay())
    
    # Handle view mode
    if view_state.view_mode == 'country' and view_state.focused_country_id:
        # Zoom to specific country
        country = next((k for k in board.kingdoms if k.countryId == view_state.focused_country_id), None)
        if country:
            # Use CountryDetails to create zoomed view
            from HexMagic.game.country import CountryDetails
            details = CountryDetails(country)
            terrain = details.countryMap
            builder = terrain.hexGrid.builder
    
    mapText = P(NotStr(terrain.html()), id="map")
    
    # Create overlay toggle buttons
    overlay_controls = create_overlay_controls(overlays)
    
    return Titled("Hex Map",
        Div(
            Div(
                H4("Menu", cls="text-lg font-bold mb-4"),
                overlay_controls,
                create_game_info(board, game_id),
                cls="w-64 p-4 overflow-auto"
            ),
            Div(
                Div(mapText, id="map-area", cls="p-4 overflow-auto flex-1"),
                cls="flex-1 flex flex-col overflow-hidden", 
                height=800
            ),
            cls="flex h-screen"
        )
    )

def create_overlay_controls(overlays: dict) -> Div:
    """Create toggle buttons for overlays."""
    buttons = []
    for name, enabled in overlays.items():
        btn = Button(
            name.title(),
            hx_post=f"/toggle_overlay/{name}",
            hx_target="#map",
            cls="btn btn-sm mb-2 " + ("btn-primary" if enabled else "btn-outline")
        )
        buttons.append(btn)
    
    return Div(*buttons, cls="space-y-2")

def create_game_info(board: GameBoard, game_id: int) -> Div:
    """Display game information."""
    return Div(
        H5("Game Info", cls="font-bold mt-4"),
        P(f"Turn: {getattr(board, 'turn_number', 0)}"),
        P(f"Kingdoms: {len(board.kingdoms)}"),
        P(f"Game ID: {game_id}"),
        cls="mt-4"
    )
```

### Overlay Toggle Route

```python
@rt
def toggle_overlay(session, overlay_name: str):
    """Toggle an overlay on/off."""
    user_id = get_user_id(session)
    game_id = get_active_game(session, server)
    
    if game_id is None:
        return P("No active game")
    
    # Get current state
    view_state = server.get_view_state(user_id, game_id)
    import json
    overlays = json.loads(view_state.active_overlays)
    
    # Toggle
    overlays[overlay_name] = not overlays.get(overlay_name, False)
    
    # Update
    server.update_view_state(user_id, game_id, overlays=overlays)
    
    # Redirect to refresh map
    return RedirectResponse('/showMap', status_code=303)
```

### Country Zoom Route

```python
@rt
def zoom_to_country(session, country_id: int):
    """Zoom view to a specific country."""
    user_id = get_user_id(session)
    game_id = get_active_game(session, server)
    
    if game_id is None:
        return P("No active game")
    
    # Update view state
    server.update_view_state(
        user_id, 
        game_id,
        view_mode='country',
        focused_country_id=country_id
    )
    
    return RedirectResponse('/showMap', status_code=303)

@rt
def zoom_to_world(session):
    """Zoom out to world view."""
    user_id = get_user_id(session)
    game_id = get_active_game(session, server)
    
    if game_id is None:
        return P("No active game")
    
    # Update view state
    server.update_view_state(
        user_id,
        game_id,
        view_mode='world',
        focused_country_id=None
    )
    
    return RedirectResponse('/showMap', status_code=303)
```

---

## Optional: GlobalField Population

For large worlds where you need efficient spatial queries:

```python
@patch
def _populate_global_fields(self: HexServer, world_id: int, terrain: Terrain):
    """Populate GlobalField table for spatial queries."""
    grid = terrain.hexGrid
    
    # Batch insert elevations
    records = []
    for i, hex_obj in enumerate(grid.hexes):
        pos = grid.index_to_hexposition(i)
        
        records.append(GlobalField(
            world_id=world_id,
            q=pos.q, r=pos.r, s=pos.s,
            field_name='elevation',
            value=terrain.elevations[i],
            ring=abs(pos),
            sector=self._compute_sector(pos)
        ))
        
        # Batch insert fields
        for field_name, values in terrain.fields.items():
            records.append(GlobalField(
                world_id=world_id,
                q=pos.q, r=pos.r, s=pos.s,
                field_name=field_name,
                value=values[i],
                ring=abs(pos),
                sector=self._compute_sector(pos)
            ))
        
        # Insert in batches of 1000
        if len(records) >= 1000:
            self.global_fields.insert_all(records)
            records = []
    
    # Insert remaining
    if records:
        self.global_fields.insert_all(records)

@patch
def query_field_in_region(self: HexServer, world_id: int, field_name: str, 
                          min_ring: int, max_ring: int) -> list:
    """Query field values in a ring range."""
    results = self.db.execute("""
        SELECT q, r, s, value FROM global_field
        WHERE world_id = ? AND field_name = ?
        AND ring BETWEEN ? AND ?
    """, [world_id, field_name, min_ring, max_ring]).fetchall()
    
    return [(r['q'], r['r'], r['s'], r['value']) for r in results]

@staticmethod
def _compute_sector(pos: HexPosition) -> int:
    """Compute angular sector (0-5) for a hex position."""
    import math
    angle = math.atan2(pos.r, pos.q)
    sector = int((angle + math.pi) / (math.pi / 3)) % 6
    return sector
```

---

## Migration from Current System

### Phase 1: Add New Tables (Non-Breaking)

```python
# Add to HexServer.__init__
def create_tables(self):
    # Existing tables stay as-is
    self.users = self.db.create(User, pk='id', if_not_exists=True)
    self.games_old = self.db.t.game  # Keep old table
    self.autosaves = self.db.create(Autosave, pk='id', if_not_exists=True)
    
    # Add new tables
    self.worlds = self.db.create(World, pk='id', if_not_exists=True)
    self.games_new = self.db.create(Game, pk='id', if_not_exists=True)
    self.game_players = self.db.create(GamePlayer, pk='id', if_not_exists=True)
    self.view_states = self.db.create(ViewState, pk='id', if_not_exists=True)
```

### Phase 2: Migration Script

```python
@patch
def migrate_games_to_new_schema(self: HexServer):
    """Migrate existing games to new world/game split."""
    from datetime import datetime
    
    # Get all old games
    old_games = list(self.db.t.game())
    
    for old_game in old_games:
        # Decode board
        board = GameBoard.decode(old_game['board_data'])
        
        # Extract world (create new world record)
        world_id = self.create_world_from_terrain(
            terrain=board.terrain,
            geology=board.world,
            name=f"World from {old_game['name']}"
        )
        
        # Create new game record
        new_game = Game(
            world_id=world_id,
            name=old_game['name'],
            game_state=board.encode(),
            turn_number=0,
            created_by=old_game['user_id'],
            last_modified_by=old_game.get('last_modified_by', old_game['user_id']),
            is_active=old_game.get('is_active', True),
            created=old_game['created'],
            modified=old_game.get('modified', old_game['created'])
        )
        
        result = self.db.create(Game).insert(new_game)
        new_game_id = result.id if hasattr(result, 'id') else result['id']
        
        # Create game_player entry
        self.game_players.insert(GamePlayer(
            game_id=new_game_id,
            user_id=old_game['user_id'],
            role='owner',
            created=old_game['created']
        ))
        
        # Create default view state
        self._create_default_view_state(old_game['user_id'], new_game_id)
        
        print(f"Migrated game {old_game['id']} -> {new_game_id}")
```

---

## Benefits of This Design

1. **Multi-User Support**: GamePlayer table enables collaborative games
2. **Persistent UI State**: Users resume where they left off
3. **World Reuse**: Multiple games can share the same world
4. **Incremental Adoption**: Can migrate gradually
5. **FastLite Integration**: Uses your existing database pattern
6. **Web-Friendly**: Designed for FastHTML routes and HTMX
7. **Backward Compatible**: Keeps existing encode/decode methods

## Trade-offs

1. **Still Using Encoded Strings**: Not fully normalized (but simpler migration)
2. **GlobalField Optional**: Can add later if needed for performance
3. **Session Management**: Need to handle user sessions carefully
4. **Migration Complexity**: Requires careful testing when migrating existing games

## Next Steps

1. Add new tables to HexServer
2. Implement view state management
3. Update web routes to use view states
4. Add overlay toggle functionality
5. Test multi-user access
6. Optional: Add GlobalField for spatial queries
