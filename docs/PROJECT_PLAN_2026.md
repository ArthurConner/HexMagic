# HexMagic Project Plan 2026 - MVC Architecture

**Date:** February 13, 2026  
**Status:** Active Development  
**Architecture:** Model-ViewModel-View-Controller

---

## Executive Summary

HexMagic implements an MVC-like architecture for hex-based terrain generation and gaming:

- **Model (Database)**: Persistent storage with spatial/temporal queries
- **ViewModel (Terrain/ChunkCover)**: Working data structures with on-demand loading
- **View (Visualization)**: SVG rendering with pattern-based styling
- **Controller (Game Logic)**: Game state management and rules

**Key Insight:** ChunkCover provides the "top view" (master terrain), HexChunk provides "viewports" (regional extraction), enabling efficient multi-scale terrain with database caching.

---

## Architecture Overview

### Current Implementation Status

```
┌──────────────────────────────────────────────────────────┐
│                    Model Layer (✓ 90%)                   │
│                   HexMagic/database.py                    │
├──────────────────────────────────────────────────────────┤
│  GeoStorage                                              │
│    ├─ Tables: World, HexData, HexWeather,               │
│    │          WatershedMeta, ChunkBorder, User          │
│    ├─ Chunk Caching (NEW): Terrain/Weather/Watersheds   │
│    ├─ Spatial Queries: (q,r,s) indexing                 │
│    ├─ Temporal Queries: as_of timestamps                │
│    └─ Cache Invalidation: Automatic cleanup             │
└──────────────────────────────────────────────────────────┘
                            ↕
┌──────────────────────────────────────────────────────────┐
│              ViewModel Layer (✓ 85%)                     │
│         HexMagic/core.py, cover.py, primitives.py       │
├──────────────────────────────────────────────────────────┤
│  Terrain (Working Data)                                  │
│    ├─ elevations: np.ndarray                            │
│    ├─ fields: dict[str, np.ndarray]                     │
│    ├─ hexGrid: HexGrid (coordinate system)              │
│    └─ sync: save/load via GeoStorage                    │
│                                                          │
│  ChunkCover (Top View - NEW)                            │
│    ├─ Master terrain (coarse)                           │
│    ├─ zoom_cached(): Generate detail on-demand          │
│    ├─ Database-backed caching                           │
│    └─ ident + db: Persistence integration               │
│                                                          │
│  HexChunk (Viewport)                                     │
│    ├─ Core + Halo regions                               │
│    ├─ Position-based indexing                           │
│    ├─ copy_from(): Share data with neighbors            │
│    └─ Spiral iteration patterns                         │
└──────────────────────────────────────────────────────────┘
                            ↕
┌──────────────────────────────────────────────────────────┐
│                 View Layer (✓ 75%)                       │
│              HexMagic/plots/*.py, styles.py              │
├──────────────────────────────────────────────────────────┤
│  SVGBuilder                                              │
│    ├─ Pattern-based rendering (dots, waves, etc.)       │
│    ├─ Climate overlays                                  │
│    └─ Interactive exports                               │
│                                                          │
│  TerrainPatterns                                         │
│    └─ Procedural pattern generation                     │
└──────────────────────────────────────────────────────────┘
                            ↕
┌──────────────────────────────────────────────────────────┐
│              Controller Layer (⚠ 40%)                    │
│                HexMagic/game/*.py                        │
├──────────────────────────────────────────────────────────┤
│  GameBoard                                               │
│    ├─ Game state management                             │
│    ├─ Turn processing                                   │
│    └─ Rule enforcement                                  │
│                                                          │
│  Kingdom, Piece                                          │
│    ├─ Entity management                                 │
│    ├─ AI agents                                         │
│    └─ Actions → ViewModel updates                       │
└──────────────────────────────────────────────────────────┘
                            ↕
┌──────────────────────────────────────────────────────────┐
│                 Web Layer (⚠ 10%)                        │
│                     FastHTML + HTMX                      │
├──────────────────────────────────────────────────────────┤
│  Multi-user hosting                                      │
│  Per-user viewports (HexChunk-based)                    │
│  Real-time updates: DB → ViewModel → View               │
└──────────────────────────────────────────────────────────┘
```

---

## Completed Features (✓)

### Model Layer
- [x] GeoStorage with SQLite backend
- [x] Spatial indexing (q,r,s coordinates)
- [x] Temporal versioning (modified timestamps)
- [x] HexData, HexWeather, User tables
- [x] **ChunkCover persistence** (World table, cover_data)
- [x] **Chunk caching system** (terrain/weather/watersheds)
- [x] **WatershedMeta table** (topology persistence)
- [x] **ChunkBorder table** (inter-chunk drainage)
- [x] **Cache invalidation** (automatic cleanup)
- [x] Region extraction queries

### ViewModel Layer
- [x] Terrain class with fields system
- [x] HexPosition (q,r,s) universal coordinates
- [x] HexGrid with index↔position conversions
- [x] **ChunkCover** with master terrain + zoom
- [x] **HFFT** for smooth upsampling
- [x] **HexChunk** with core/halo regions
- [x] **Database integration** (.db, .ident, .save(), .load())
- [x] Tectonic plate generation
- [x] Watershed computation
- [x] Climate/weather models
- [x] Real-world geography (GeoBounds)

### View Layer
- [x] SVGBuilder with pattern rendering
- [x] TerrainPatterns (dots, waves, climate)
- [x] Climate overlays (temperature, precipitation)
- [x] Interactive SVG exports
- [x] StyleCSS system

---

## In Progress (⚙)

### Model Layer
- [ ] LRU cache eviction (access tracking needed)
- [ ] Cache statistics and monitoring
- [ ] Transaction safety improvements
- [ ] Error handling refinement

### ViewModel Layer
- [ ] Chunk reconstruction validation
- [ ] Grid metadata storage
- [ ] Background prefetching
- [ ] Adaptive detail levels

### Controller Layer
- [ ] Complete game rules implementation
- [ ] AI agent improvements
- [ ] Multi-player coordination
- [ ] Turn-based mechanics

---

## Planned Features (📋)

### Phase 1: Cache Management (Priority: HIGH)

**Goal:** Production-ready caching with LRU eviction

**Tasks:**
1. Add access tracking to HexData
   ```python
   class HexData:
       last_accessed: int = 0
       access_count: int = 0
   ```

2. Implement LRU eviction
   ```python
   storage.evict_lru_chunks(cover_id, target_size_mb=100)
   ```

3. Cache statistics
   ```python
   stats = storage.get_cache_stats(cover_id)
   # → CacheMetrics(total_chunks, total_hexes, hit_rate, ...)
   ```

4. Background cleanup
   - Periodic cache maintenance
   - Age-based eviction (default: 7 days)

**Timeline:** 2 weeks  
**Dependencies:** None  
**Blocker Risk:** Low

---

### Phase 2: Web Interface (Priority: MEDIUM)

**Goal:** Multi-user web interface with FastHTML + HTMX

**Architecture:**
```
User Browser                Server (FastHTML)           Database
    │                              │                         │
    │──── HTTP Request ───────────>│                         │
    │      (viewport center)       │                         │
    │                              │──── Query chunks ──────>│
    │                              │<─── HexData ────────────│
    │                              │                         │
    │                              │ [Reconstruct Terrain]   │
    │                              │ [Render SVG]            │
    │                              │                         │
    │<──── HTMX Response ──────────│                         │
    │      (SVG fragment)          │                         │
```

**Key Components:**

1. **User Viewport State**
   ```python
   @dataclass
   class UserViewport:
       user_id: int
       cover_id: int
       center_q, center_r, center_s: int
       zoom_scale: int = 1
       visible_layers: list[str]  # ['terrain', 'weather', 'kingdoms']
       last_updated: int
   ```

2. **Viewport Endpoints**
   ```python
   @app.get("/viewport/{user_id}")
   def get_viewport(user_id: int):
       viewport = load_user_viewport(user_id)
       terrain = load_viewport_terrain(viewport)
       return render_svg_fragment(terrain)
   
   @app.post("/viewport/{user_id}/move")
   def move_viewport(user_id: int, dq: int, dr: int, ds: int):
       # Update center, return new SVG fragment
   ```

3. **Multi-User Sync**
   - Per-user viewport state in database
   - Shared ChunkCover (read-only for players)
   - Game actions modify shared ViewModel
   - HTMX polls for changes

**Tasks:**
- [ ] User viewport table
- [ ] FastHTML routes
- [ ] HTMX templates
- [ ] SVG streaming
- [ ] Multi-user coordination

**Timeline:** 6 weeks  
**Dependencies:** Phase 1 (cache management)  
**Blocker Risk:** Medium (HTMX integration complexity)

---

### Phase 3: Distributed Watersheds (Priority: LOW)

**Goal:** Compute watersheds in parallel across chunks

**Current:** O(n²) per chunk  
**Target:** O(n×k²) via ChunkCover projection + ChunkBorder flow

**Architecture:**
```
Coarse Watersheds (Master)
        ↓
    ChunkCover.project_watersheds()
        ↓
Fine Watershed Assignment (per chunk)
        ↓
    Save to WatershedMeta + ChunkBorder
        ↓
    Propagate flow across borders
```

**Tasks:**
- [ ] ChunkBorder flow propagation
- [ ] Parallel chunk processing
- [ ] Border consistency validation
- [ ] Incremental watershed updates

**Timeline:** 4 weeks  
**Dependencies:** ChunkCover (✓ complete)  
**Blocker Risk:** Medium (correctness validation)

---

### Phase 4: Game Mechanics (Priority: MEDIUM)

**Goal:** Complete turn-based game with kingdoms and pieces

**MVC Flow:**
```
Player Action (Web)
    ↓
Controller (GameBoard)
    ↓
ViewModel Update (Terrain.fields, Kingdom state)
    ↓
Model Persistence (GeoStorage)
    ↓
View Refresh (SVG re-render)
    ↓
HTMX Update (partial page)
```

**Tasks:**
- [ ] Complete Piece movement rules
- [ ] Kingdom resource management
- [ ] Combat resolution
- [ ] Victory conditions
- [ ] AI opponent improvements
- [ ] Multiplayer turn queue

**Timeline:** 8 weeks  
**Dependencies:** Phase 2 (web interface)  
**Blocker Risk:** High (game design decisions)

---

### Phase 5: Performance Optimization (Priority: LOW)

**Goal:** Scale to large worlds (10,000+ chunks)

**Optimizations:**

1. **GPU Acceleration**
   ```python
   # Use cupy for FFT operations
   import cupy as cp
   def zoom_chunk_gpu(cover, origin, scale):
       # FFT on GPU: 100× speedup
   ```

2. **Parallel Generation**
   ```python
   from concurrent.futures import ProcessPoolExecutor
   
   def generate_chunks_parallel(cover, origins, scale):
       with ProcessPoolExecutor(max_workers=8) as executor:
           futures = [executor.submit(cover.zoom_cached, o, scale) 
                     for o in origins]
           return [f.result() for f in futures]
   ```

3. **Streaming Progressive Zoom**
   - Return low-res immediately
   - Refine in background
   - HTMX updates as detail arrives

4. **Redis Caching**
   - Shared cache for multi-server deployment
   - Invalidation broadcasting
   - Cache warming strategies

**Timeline:** 6 weeks  
**Dependencies:** Phase 2 (web interface)  
**Blocker Risk:** Low (optional optimizations)

---

## Key Design Decisions

### 1. ChunkCover as "Top View"

**Decision:** Store coarse master terrain, generate detail on-demand

**Rationale:**
- Memory efficient (1 coarse vs. 1000s of fine)
- Fast (cache hits avoid computation)
- Flexible (can zoom to any scale)

**Tradeoffs:**
- First zoom is slow (80-280ms)
- Cache can grow large (needs LRU)
- Invalidation complexity when master changes

### 2. HexChunk as "Viewport"

**Decision:** Extract core+halo regions for local computation

**Rationale:**
- Enables edge computations (watersheds, etc.)
- Natural viewport for web rendering
- Parallelizable across chunks

**Tradeoffs:**
- Coordinate system complexity (world vs local vs chunk)
- Halo overlap requires synchronization
- Border flow tracking needed for watersheds

### 3. Database as "Model"

**Decision:** Persistent storage with automatic caching

**Rationale:**
- Queryable terrain data
- Multi-user support
- Version history
- Efficient region extraction

**Tradeoffs:**
- Cache invalidation complexity
- Storage growth (needs cleanup)
- Query performance (indices critical)

### 4. Terrain as "ViewModel"

**Decision:** Working data structure, not just view-specific

**Rationale:**
- Universal data format
- Bidirectional sync with database
- Fields system for extensibility

**Tradeoffs:**
- Can get large (memory pressure)
- Synchronization overhead
- Grid reconstruction from DB can fail

---

## Risk Assessment

### High Risk

**1. Cache Growth**
- **Issue:** Unbounded cache size
- **Mitigation:** Phase 1 (LRU eviction)
- **Fallback:** Manual cleanup

**2. Multi-User Coordination**
- **Issue:** Concurrent writes to shared terrain
- **Mitigation:** Read-only ChunkCover, per-user viewports
- **Fallback:** Single-player first

### Medium Risk

**3. Web Performance**
- **Issue:** SVG rendering can be slow
- **Mitigation:** Streaming, progressive rendering
- **Fallback:** Simplify visualizations

**4. Watershed Correctness**
- **Issue:** Border flow may be incorrect
- **Mitigation:** Extensive testing, validation
- **Fallback:** Single-chunk watersheds only

### Low Risk

**5. GPU Availability**
- **Issue:** cupy not available everywhere
- **Mitigation:** Graceful fallback to CPU
- **Fallback:** CPU-only deployment

---

## Success Metrics

### Phase 1 (Cache Management)
- [ ] Cache hit rate > 60%
- [ ] LRU eviction maintains size < 100MB
- [ ] No cache-related crashes

### Phase 2 (Web Interface)
- [ ] 5 concurrent users without issues
- [ ] Viewport updates < 500ms
- [ ] HTMX integration working smoothly

### Phase 3 (Distributed Watersheds)
- [ ] Watershed computation < 2s for 1000-hex chunk
- [ ] Border flow validation 100% correct
- [ ] Parallel speedup > 4× on 8 cores

### Phase 4 (Game Mechanics)
- [ ] Complete game playable end-to-end
- [ ] AI opponent competitive
- [ ] No game-breaking bugs

### Phase 5 (Performance)
- [ ] GPU acceleration 100× speedup on FFT
- [ ] Parallel generation 8× speedup
- [ ] Redis caching supports 50+ users

---

## Technical Debt

### Priority: HIGH
1. **Cache Management**
   - No LRU eviction
   - No size limits
   - Generic error handling

2. **Transaction Safety**
   - Invalidation not atomic
   - Some operations lack transactions

### Priority: MEDIUM
3. **Chunk Reconstruction**
   - No validation of reconstructed grids
   - Grid dimensions inferred from data

4. **Error Handling**
   - Generic `except Exception` catches all
   - No retry logic

### Priority: LOW
5. **Documentation**
   - Missing API docs in some modules
   - No user guide yet

6. **Testing**
   - Need more integration tests
   - Performance benchmarks missing

---

## Dependencies

### External
- Python 3.10+
- numpy, scipy (scientific computing)
- fastlite (database)
- fasthtml, htmx (web - planned)
- cupy (GPU - optional)

### Internal Module Graph
```
primitives.py (base)
    ↓
core.py (Terrain)
    ↓
├─ geology.py (Plates, Watersheds)
├─ climate.py (Weather)
├─ cover.py (ChunkCover, HFFT)
└─ database.py (GeoStorage)
    ↓
├─ game/*.py (GameBoard, Kingdom, Piece)
└─ plots/*.py (SVGBuilder, TerrainPatterns)
```

---

## Next Actions (Sprint Planning)

### This Sprint (2 weeks)
1. **Implement LRU eviction** (2 days)
   - Add `last_accessed`, `access_count` to HexData
   - Write `evict_lru_chunks()`
   - Test with cache pressure

2. **Cache statistics** (1 day)
   - Implement `get_cache_stats()`
   - Add monitoring dashboard (CLI)

3. **Transaction safety** (2 days)
   - Wrap `invalidate_all_caches()` in transaction
   - Audit other multi-statement operations

4. **Validation** (2 days)
   - Add chunk reconstruction validation
   - Test with incomplete cache data

5. **Documentation** (1 day)
   - Update change log
   - API docs for new methods

### Next Sprint (2 weeks)
1. **User viewport table**
2. **Basic FastHTML routes**
3. **SVG streaming proof-of-concept**
4. **Multi-user state management**

---

## References

- **Architecture:** `docs/PROJECT_OVERVIEW.md`
- **Database:** `docs/DatabaseSchema.md`, `docs/DATABASE_QUICK_REF.md`
- **ChunkCover:** `docs/ChunkCover_System.md`
- **Changes:** `change.26.02.13.md` (latest)
- **Code Patterns:** `docs/CODE_PATTERNS.md`
- **Implementation:** `HexMagic/database.py`, `HexMagic/cover.py`
