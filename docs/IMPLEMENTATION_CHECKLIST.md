# HexMagic Database Implementation Checklist

This document tracks the implementation status of the database system designed in the schema documents.

## Phase 1: Core TerrainDB Implementation

### 1.1 Database Module Setup
- [ ] Create `HexMagic/database.py` or `HexMagic/database/` package
- [ ] Import dependencies (fastlite, dataclasses, datetime, numpy)
- [ ] Define module structure

### 1.2 Dataclass Definitions
- [ ] `TerrainWorld` - Core terrain+geology storage
- [ ] `HexData` - Optional normalized hex data
- [ ] `Plate` - Tectonic plate data
- [ ] `Watershed` - Drainage basin data
- [ ] `WorldTemplate` - Template metadata
- [ ] `Viewport` - Saved viewport definitions
- [ ] `ScaleTransform` - Multi-resolution relationships

### 1.3 TerrainDB Class Core Methods
- [ ] `__init__(db_path)` - Initialize database connection
- [ ] `_get_default_path()` - Default database location
- [ ] `_create_tables()` - Create all tables with FastLite
- [ ] `_create_indices()` - Create database indices
- [ ] `_populate_templates()` - Populate default templates

### 1.4 World Save/Load Operations
- [ ] `save_world(terrain, geology, ...)` - Save terrain+geology pair
- [ ] `_save_plates(world_id, plates, grid)` - Save plate data
- [ ] `_save_watersheds(world_id, basins)` - Save watershed data
- [ ] `load_world(world_id)` - Load complete world
- [ ] `_load_plates(world_id, grid)` - Load plates for world
- [ ] `_load_watersheds(world_id, terrain)` - Load watersheds for world

### 1.5 Template Management
- [ ] `list_templates(category, featured_only)` - List available templates
- [ ] `get_template(template_id)` - Load world from template
- [ ] `search_worlds(search_term, tags)` - Search for worlds

### 1.6 Spatial Queries (Optional)
- [ ] `populate_hex_data(world_id, terrain, fields)` - Populate HexData table
- [ ] `query_region(world_id, center, radius)` - Query hexes in region
- [ ] `_compute_sector(pos)` - Compute angular sector for hex

## Phase 2: Regional Extraction API

### 2.1 Centered Region Extraction
- [ ] `extract_region(world_id, center_q, center_r, center_s, rings, padding)` - Extract centered circular region
  - [ ] Load full world
  - [ ] Find hexes within ring distance
  - [ ] Call `crop_to_centered_grid()`
  - [ ] Map terrain data to new grid
  - [ ] Copy all fields
  - [ ] Return terrain + mapper

### 2.2 Rectangular Region Extraction
- [ ] `extract_rectangle(world_id, center, width, height, orientation)` - Extract rectangular region
  - [ ] Calculate row/col bounds
  - [ ] Collect hexes in rectangle
  - [ ] Create new rectangular grid
  - [ ] Map data with custom mapper
  - [ ] Return terrain + mapper

### 2.3 Viewport Management
- [ ] `create_viewport(world_id, name, center, shape, **kwargs)` - Save viewport definition
- [ ] `load_viewport(viewport_id)` - Load terrain from viewport
  - [ ] Handle circular viewports
  - [ ] Handle rectangular viewports

### 2.4 Print Templates
- [ ] Define `PRINT_TEMPLATES` dictionary
- [ ] `extract_for_print(world_id, center, template)` - Extract with print template

## Phase 3: Multi-Scale Transform System

### 3.1 ScaleTransform Table
- [ ] Add ScaleTransform to `_create_tables()`
- [ ] Create indices for source/target lookups
- [ ] Test basic insert/query

### 3.2 Downsampling Operations
- [ ] `save_downsampled_world(source_id, scale, sample_radius, name)` - Create downsampled version
  - [ ] Load source world
  - [ ] Call `downsample_climate()` or `shrinkWeather()`
  - [ ] Save new world
  - [ ] Create ScaleTransform record
  - [ ] Return (world_id, transform_id)

### 3.3 Region Mapping
- [ ] `map_region_to_scale(transform, source_hexes)` - Forward mapping (large→small)
  - [ ] Load both terrains
  - [ ] Map each source hex to target grid
  - [ ] Return target hex set

- [ ] `map_region_from_scale(transform, target_hexes, expand)` - Reverse mapping (small→large)
  - [ ] Load both terrains
  - [ ] Map each target hex back to source
  - [ ] Optionally expand based on sample_radius
  - [ ] Return source hex set

### 3.4 Position Mapping
- [ ] `map_hexposition_to_scale(transform, source_q, source_r, source_s)` - Map position forward
- [ ] `map_hexposition_from_scale(transform, target_q, target_r, target_s)` - Map position reverse

### 3.5 Helper Classes (Optional)
- [ ] `MultiScaleWorld` - Helper for managing multiple scales
  - [ ] `__init__(db, world_id)`
  - [ ] `ensure_scale(scale, sample_radius)` - Create scale if needed
  - [ ] `map_position(q, r, s, from_scale, to_scale)` - Map between scales

- [ ] `ScaleObserver` - Observer pattern for scale changes
  - [ ] `register(callback)` - Register callback
  - [ ] `notify_scale_change(old, new, region)` - Notify observers

- [ ] `CachedScaleTransform` - Caching wrapper
  - [ ] `forward(source_idx)` - Cached forward mapping
  - [ ] `reverse(target_idx)` - Cached reverse mapping

## Phase 4: Web Game Database (TerrainSchema_FastLite.md)

### 4.1 Game Database Module
- [ ] Create `HexMagic/game/database.py` or separate from TerrainDB
- [ ] Define separation strategy (same DB or different DBs)

### 4.2 Dataclass Definitions
- [ ] `World` - World definition (references TerrainWorld or stores terrain_data)
- [ ] `Game` - Game instance
- [ ] `User` - User authentication
- [ ] `GamePlayer` - Player in game
- [ ] `ViewState` - Per-user viewport state
- [ ] `Kingdom` - Player civilization
- [ ] `Territory` - Kingdom territory
- [ ] `Piece` - Game units (from PieceDesign.md)

### 4.3 GameDB Class
- [ ] `__init__(db_path)` - Initialize game database
- [ ] `_create_tables()` - Create game tables
- [ ] `_create_indices()` - Create game indices

### 4.4 World/Game Management
- [ ] `create_world_from_terrain(terrain, name, ...)` - Create world record
- [ ] `create_game(world_id, name, ...)` - Create game instance
- [ ] `add_player_to_game(game_id, user_id, kingdom_name)` - Add player
- [ ] `load_game(game_id)` - Load complete game state
- [ ] `save_game(game)` - Save game state

### 4.5 ViewState Management
- [ ] `create_view_state(game_id, user_id, center, ...)` - Initialize view
- [ ] `update_view_state(view_id, **kwargs)` - Update view
- [ ] `get_view_state(game_id, user_id)` - Load user's view

### 4.6 Kingdom/Territory
- [ ] `save_kingdom(kingdom)` - Save kingdom data
- [ ] `load_kingdoms(game_id)` - Load all kingdoms in game
- [ ] Territory encode/decode integration

### 4.7 Piece System
- [ ] `save_piece(piece)` - Save piece/unit
- [ ] `load_pieces(game_id)` - Load all pieces in game
- [ ] `update_piece(piece_id, **kwargs)` - Update piece state
- [ ] Piece encode/decode integration

## Phase 5: Web Routes Integration

### 5.1 FastHTML Routes
- [ ] `/worlds` - List/browse worlds
- [ ] `/worlds/{id}` - View world detail
- [ ] `/games` - List games
- [ ] `/games/create` - Create new game
- [ ] `/games/{id}` - Game view
- [ ] `/games/{id}/viewport` - Update viewport for user
- [ ] `/games/{id}/action` - Game actions (move piece, etc.)

### 5.2 HTMX Interactivity
- [ ] Viewport pan/zoom controls
- [ ] Overlay toggles (climate, political, etc.)
- [ ] Piece selection and movement
- [ ] Turn management

## Phase 6: Jupyter Notebook Examples

### 6.1 Core Library Examples
- [ ] `01_terrain_db_basics.ipynb` - TerrainDB intro
  - [ ] Loading templates
  - [ ] Saving custom worlds
  - [ ] Searching worlds

- [ ] `02_regional_extraction.ipynb` - Regional APIs
  - [ ] Centered region extraction
  - [ ] Rectangular crops
  - [ ] Viewport management
  - [ ] Print templates

- [ ] `03_multi_scale_workflow.ipynb` - Scale transforms
  - [ ] Downsampling worlds
  - [ ] Multi-scale climate analysis
  - [ ] Region mapping between scales
  - [ ] MultiScaleWorld usage

### 6.2 Game Examples
- [ ] `04_game_setup.ipynb` - Game database
  - [ ] Creating games
  - [ ] Adding players
  - [ ] Initial kingdom setup

- [ ] `05_piece_system.ipynb` - Unit mechanics
  - [ ] Creating pieces
  - [ ] Movement and pathfinding
  - [ ] Vision and fog of war
  - [ ] Combat resolution

## Phase 7: Testing

### 7.1 Unit Tests
- [ ] `test_terrain_db.py` - TerrainDB operations
  - [ ] Save/load worlds
  - [ ] Template management
  - [ ] Search functionality

- [ ] `test_regional_extraction.py` - Regional APIs
  - [ ] Centered extraction
  - [ ] Rectangular extraction
  - [ ] Viewport management

- [ ] `test_scale_transforms.py` - Multi-scale
  - [ ] Downsampling
  - [ ] Region mapping (forward/reverse)
  - [ ] Position mapping

- [ ] `test_game_db.py` - Game database
  - [ ] Game creation
  - [ ] Player management
  - [ ] ViewState operations

### 7.2 Integration Tests
- [ ] End-to-end world generation → save → load → extract
- [ ] Multi-scale workflow (create → downsample → map regions)
- [ ] Game setup → play → save → load

### 7.3 Performance Tests
- [ ] Large world (100k+ hexes) save/load
- [ ] Spatial query performance with HexData table
- [ ] Downsampling performance at various scales

## Phase 8: Documentation

### 8.1 API Documentation
- [ ] Docstrings for all public methods
- [ ] Type hints throughout
- [ ] Usage examples in docstrings

### 8.2 User Guides
- [ ] "Getting Started with TerrainDB"
- [ ] "Working with Multi-Scale Worlds"
- [ ] "Building Web Games"

### 8.3 Schema Documentation
- [ ] Update schemaMain.md with implementation notes
- [ ] Update TerrainSchema_FastLite.md with web routes
- [ ] Add migration guide for existing code

## Dependencies Tracking

### Required Packages
- [x] fastlite - Database ORM
- [x] sqlite-utils - SQLite utilities
- [x] numpy - Array operations
- [x] dataclasses - Data structures
- [ ] fasthtml - Web framework (for web game routes)
- [ ] python-fasthtml - HTMX integration

### Optional Packages
- [ ] pytest - Testing framework
- [ ] pytest-benchmark - Performance testing

## Implementation Notes

### Critical Design Decisions
1. **Single vs Multiple Databases**: 
   - Option A: Single database with all tables
   - Option B: Separate databases (terrain.db, game.db)
   - **Recommendation**: Start with single DB, can split later if needed

2. **HexData Population**:
   - Optional for most use cases
   - Only populate for very large worlds (>50k hexes) needing spatial queries
   - **Recommendation**: Make it opt-in via explicit method call

3. **ScaleTransform Caching**:
   - Pre-compute common scales (0.5, 0.25, 0.125) for templates
   - Cache transform mappings for frequently used scales
   - **Recommendation**: Lazy creation with caching

4. **Template Generation**:
   - Generate during first database initialization
   - Takes time but only happens once
   - **Recommendation**: Show progress, cache in database

### Migration Path for Existing Code
1. Existing encode/decode continues to work
2. Add database as opt-in feature
3. Gradually migrate notebooks to use TerrainDB
4. Keep both patterns working in parallel

## Current Status Summary

**Designed (100%):**
- ✅ All database schemas (schemaMain.md, TerrainSchema_FastLite.md, PieceDesign.md)
- ✅ Multi-scale transform system
- ✅ Regional extraction API
- ✅ Complete documentation structure

**Implemented (estimated ~40%):**
- ✅ Core terrain/geology classes with encode/decode
- ✅ HexRegion.crop_to_centered_grid()
- ✅ Terrain.downsample_climate() and shrinkWeather()
- ✅ Climate computation system
- ✅ Basic game classes (GameBoard, Kingdom)
- ❌ TerrainDB class (not yet implemented)
- ❌ ScaleTransform table and methods
- ❌ Game database classes
- ❌ Web routes for game hosting

**Next Immediate Steps:**
1. Create `HexMagic/database.py` with TerrainDB class
2. Implement save_world() and load_world()
3. Populate template database
4. Test with existing terrain generation code
5. Create example notebook demonstrating TerrainDB usage
