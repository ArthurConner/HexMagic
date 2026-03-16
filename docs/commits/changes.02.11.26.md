# feat(database): Add HexChunk persistence and spiral mapping tests

## Summary
Implement database save/load operations for HexChunk with spiral indexing,
along with comprehensive tests for core/halo boundary handling and
version retrieval.

## New Features

### HexChunk Database Operations
- **`GeoStorage.save_chunk()`**: Persist HexChunk to database
  - Stores chunk position, rings, and core_size
  - Saves core hexes only (excludes halo for efficiency)
  - Supports optional `coarse_world_id` for parent world linking
  
- **`GeoStorage.load_chunk()`**: Retrieve HexChunk from database
  - Uses `ORDER BY id DESC` for reliable latest-version retrieval
  - Reconstructs chunk from stored hex positions
  - Restores elevation and plate_id fields

### New Test Methods (GeoStorageDebugger)
- **`test_chunk_spiral_mapping()`**: Validates spiral indexing
  - Verifies spiral size formula: `1 + 3*n*(n+1)`
  - Confirms index 0 is always origin
  - Tests bidirectional idx↔pos mapping
  - Validates core/halo boundary at correct ring distance
  - Tests position-based data preservation through save/load

- **`test_chunk_halo_overlap()`**: Tests adjacent chunk coordination
  - Verifies `copy_from()` correctly transfers overlapping data
  - Confirms halo hexes receive data from adjacent chunk cores

- **`test_load_chunk_gets_latest()`**: Tests version retrieval
  - Ensures most recent chunk is returned when multiple versions exist
  - Uses auto-increment IDs (not timestamps) for reliability

## Technical Notes

### Spiral Indexing System
HexChunk uses spiral indexing where:
- Index 0 = center (origin)
- Indices increase outward in rings
- `core_size` marks the boundary between core and halo
- Adjacent indices are spatially adjacent but direction varies

### Bug Fix
Changed `load_chunk` query from `ORDER BY created DESC` to `ORDER BY id DESC`
because `created` has second-precision timestamps that can cause
non-deterministic ordering for rapid saves.

## Files Changed
- `HexMagic/database.py` - New chunk methods and tests
- `HexMagic/_modidx.py` - Module index updates
- `nbs/11_Database.ipynb` - Source notebook with new implementations
- `nbs/12_LargerScale.ipynb` - Refactored to use test harness

## Note on Diff Size
The large diff in `12_LargerScale.ipynb` includes:
- Removal of `ChunkedTerrainGenerator` class (moved/refactored)
- Cell execution timestamps in metadata
- AI-assisted debugging session content in markdown cells

Co-Authored-By: Warp <agent@warp.dev>
