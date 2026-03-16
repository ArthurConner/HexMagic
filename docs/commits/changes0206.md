# refactor(chunked): Migrate ChunkedTerrainGenerator from Terrain to HexChunk

## Summary
Major refactoring of `ChunkedTerrainGenerator` to use `HexChunk` as the internal
data structure instead of `Terrain`, with cleaner method organization and
reduced module exports.

## Key Changes

### ChunkedTerrainGenerator API Changes
- **`generate_chunk()`** now returns `HexChunk` instead of `Terrain`
- Removed `chunk_world_ids` tracking dict from class
- Comment clarification: `chunk_rings` is now documented as "core" rings

### New Methods
- **`_build_coarse_lookup()`**: Convert chunk_plates query to lookup dict
- **`_populate_from_coarse()`**: Fill chunk elevations/plate_id by interpolation
- **`_interpolate_fields_to_chunk()`**: Copy additional fields to HexChunk
- **`_add_detail_to_chunk()`**: Add deterministic noise to HexChunk
- **`rect_region_from_chunks()`**: Extract rectangular region from multiple chunks
- **`chunks_to_terrain()`**: Merge HexChunks into Terrain for rendering
- **`_chunks_intersecting_rect()`**: Find chunks overlapping a rectangular bounds

### Removed/De-exported Methods
The following are no longer exported from the module (removed `#| export`):
- `ChunkedTerrainGenerator.__init__`, `scale`, `generate_coarse`, `generate_chunk`
- `_query_chunk_plates`, `_build_chunk_terrain`, `_interpolate_from_coarse`
- `_add_detail`, `_interpolate_fields`, `_trim_to_core`
- `chunk_refs`, `world_to_chunk_ref`, `chunk_to_coarse_region`
- `save_chunk`, `load_chunk`, `overlay_chunk_on_coarse`
- `world_to_chunk` (module-level function)
- `GeoStorage.create_region_index_mapper`

### HexGrid Enhancement
- Added `invalidRegion` set to `HexGrid.__init__()` for tracking skipped hexes
- Modified `styledHexes()` to skip rendering hexes in `invalidRegion`
- Allows selective hex rendering without modifying the grid structure

### Code Consolidation
- Merged multiple `_build_chunk_terrain` implementations into single flow
- Simplified `_interpolate_elevation` docstring (removed verbose explanation)
- Methods now operate on HexChunk's `iter_with_world()` for cleaner iteration

## Technical Notes

### Why HexChunk over Terrain?
- HexChunk uses spiral indexing (core + halo) vs HexGrid's rectangular layout
- Chunks naturally tile without rectangular corner gaps
- More efficient for chunked terrain generation pipeline
- Clear core/halo boundary for edge computation

### Chunk-to-Terrain Conversion
New methods provide output paths:
- `rect_region_from_chunks()` - For rectangular viewport output
- `chunks_to_terrain()` - For hex-shaped multi-chunk output
- Both support `fill_from_coarse` to fill gaps from coarse map

## Files Changed
- `HexMagic/_modidx.py` - Module index cleanup (removed ~40 exports)
- `HexMagic/plot/hex.py` - Added invalidRegion support
- `HexMagic/terrain.py` - Minor whitespace change
- `nbs/03_terrain.ipynb` - Source notebook whitespace
- `nbs/12_LargerScale.ipynb` - Major refactoring of ChunkedTerrainGenerator

## Note on Diff Size
The 54k-line diff includes:
- Massive removal of `??HexChunk` cell output (~500 lines)
- Removed duplicate `_build_chunk_terrain` implementations
- AI conversation markdown cells converted/cleaned
- Cell execution timestamps updated

Co-Authored-By: Warp <agent@warp.dev>
