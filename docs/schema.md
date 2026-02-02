# Database Schema Documentation - Overview

This directory contains several database schema documents at different stages:

## Current Implementation ✅

**`DatabaseSchema.md`** - The actual implemented schema in `HexMagic/database.py`
- Tables: TerrainWorld, HexData, HexWeather, User
- GeoStorage class for database operations
- ChunkedTerrainGenerator for multi-scale terrains
- Temporal versioning with modified timestamps
- Spatial indexing on (q,r,s) coordinates

**Status:** Production-ready, actively used

## Design Documents 📋

These describe proposed extensions and future directions:

### `schemaMain.md` - TerrainDB Design
Proposed template and viewport system:
- WorldTemplate table for pre-built worlds
- Plate and Watershed tables for geology
- Viewport table for saved views
- ScaleTransform table for multi-resolution
- Regional extraction APIs

**Status:** Design document, not implemented

### `TerrainSchema.md` - Database-Centric Architecture
Proposed shift to database-backed Terrain:
- World and HexCell tables
- HexField table for flexible attributes
- Region and Chunk tables
- TerrainView class for lazy loading
- Multi-resolution LOD system

**Status:** Design document, partially implemented in ChunkedTerrainGenerator

### `TerrainSchema_FastLite.md` - Web Game Schema
Proposed schema for multi-user web game:
- Game and GamePlayer tables
- ViewState for per-user UI
- Kingdom and Territory tables
- Piece table for game units

**Status:** Design document, not implemented

## Design Notes 📝

### Original Motivation

Right now we store a database inside a database - Terrain.encode() creates a JSON string that gets stored in the database. The main components of Terrain are:
- `elevations`: numpy array of elevation per hex
- `fields`: dictionary of numpy arrays (temperature, distance_to_ocean, countries, etc.)

With HexRegion, we now have a way of creating smaller terrains from larger ones.

### Key Insight

I still very much like the Terrain as an object to work with, but if we have a database, we could:
1. Store much bigger maps
2. Use universal HexPosition (q,r,s) for all data
3. Load only needed regions for rendering/computation
4. Query spatial data efficiently

### Evolution

**Phase 1 (Implemented):** Basic persistence
- TerrainWorld metadata
- HexData for terrain
- HexWeather for climate
- Save/load entire terrains

**Phase 2 (Implemented):** Multi-scale
- ChunkedTerrainGenerator
- Coarse overview + fine detail chunks
- Region extraction

**Phase 3 (Proposed):** Advanced features
- Template library
- Viewport management
- Game state persistence
- Lazy loading for massive worlds

## Reading Guide

1. **Start here:** `DatabaseSchema.md` - understand what's currently implemented
2. **For extending:** `DATABASE_EXTENSION_GUIDE.md` - how to add new tables
3. **For ideas:** `schemaMain.md`, `TerrainSchema.md` - proposed features
4. **For games:** `TerrainSchema_FastLite.md` - multiplayer game schema

## Implementation Status

| Feature | Design Doc | Current Status |
|---------|-----------|----------------|
| Core terrain storage | All | ✅ TerrainWorld, HexData |
| Weather/climate | TerrainSchema | ✅ HexWeather |
| Temporal versioning | TerrainSchema | ✅ modified timestamps |
| Spatial indexing | All | ✅ (q,r,s) indices |
| Multi-scale chunks | TerrainSchema | ✅ ChunkedTerrainGenerator |
| User management | TerrainSchema_FastLite | ✅ User table |
| Templates | schemaMain | ❌ Not implemented |
| Plates/Watersheds | schemaMain | ❌ Not implemented |
| Viewports | schemaMain | ❌ Not implemented |
| Game tables | TerrainSchema_FastLite | ❌ Not implemented |
| Lazy loading | TerrainSchema | ❌ Not implemented |
| Region table | TerrainSchema | ❌ Not implemented |
