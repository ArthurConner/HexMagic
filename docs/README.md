# HexMagic Documentation

This directory contains comprehensive documentation for the HexMagic project.

## Documentation Files

### PROJECT_OVERVIEW.md
**Complete project reference for future conversations**

Contains:
- Full architecture (4 layers: Foundation, Visualization, Game, Web)
- Database schemas (Core Library + Web Game)
- Key workflows with code examples
- Coordinate systems and conversions
- Design patterns (encode/decode, FastLite, index mapper, patch)
- Technology stack
- File organization
- Real-world templates
- Common operations reference

**When to use:** Understanding project structure, finding workflows, learning patterns

### CODE_PATTERNS.md
**Quick reference guide for common operations**

Contains:
- Coordinate system conversions
- Terrain creation patterns (procedural, real-world, database)
- Climate and weather workflows
- Region extraction (circular, rectangular)
- Database operations (save/load, multi-scale, viewports)
- Finding hexes by criteria
- HexRegion operations
- Visualization patterns
- Encode/decode examples
- FastLite database patterns
- Field computations
- Game object patterns
- Performance patterns

**When to use:** Writing code, need quick examples, implementing features

### IMPLEMENTATION_CHECKLIST.md
**Development roadmap and status tracker**

Contains:
- Phase-by-phase implementation tasks
- Checkbox tracking for completion
- Critical design decisions
- Dependencies tracking
- Current status summary
- Next immediate steps

**When to use:** Planning implementation, tracking progress, understanding what's done

## Schema Documents (../nbs/)

### schemaMain.md
**Core library database schema**

Purpose: Jupyter notebooks, terrain generation, library usage

Key tables:
- TerrainWorld (terrain + geology storage)
- WorldTemplate (7+ real-world locations)
- ScaleTransform (multi-resolution relationships)
- Viewport (saved region definitions)
- HexData (optional spatial queries)

Key features:
- Template library
- Regional extraction APIs
- Multi-scale transforms with bidirectional region mapping
- Print templates

### TerrainSchema_FastLite.md
**Web game database schema**

Purpose: Multi-user web games

Key tables:
- World/Game (separate definition from state)
- User/GamePlayer (authentication)
- ViewState (per-user UI state)
- Kingdom/Territory (civilizations)
- Piece (game units)

Key features:
- Multi-player support
- Per-user viewport persistence
- Save/load game state
- FastHTML route integration

### PieceDesign.md
**Game unit/agent system**

Purpose: Unit mechanics for gameplay

Key features:
- Movement (terrain costs, pathfinding)
- Vision (fog of war, memory)
- Combat resolution
- Settlement/harvesting
- AI planning with personality
- Encode/decode for persistence

## Quick Navigation

**I need to...**

- Understand the overall architecture → PROJECT_OVERVIEW.md
- Write code for a specific task → CODE_PATTERNS.md
- See what's implemented vs planned → IMPLEMENTATION_CHECKLIST.md
- Design database tables → ../nbs/schemaMain.md or TerrainSchema_FastLite.md
- Implement game units → ../nbs/PieceDesign.md
- Get a quick project summary → ../llms.txt

## File Relationships

```
docs/
├── README.md (this file)          # Documentation guide
├── PROJECT_OVERVIEW.md            # Complete reference
├── CODE_PATTERNS.md               # Quick code guide
└── IMPLEMENTATION_CHECKLIST.md    # Roadmap

../nbs/
├── schemaMain.md                  # Core DB schema
├── TerrainSchema_FastLite.md      # Web game schema
└── PieceDesign.md                 # Unit system

../llms.txt                        # AI-friendly summary
```

## For AI/LLM Assistants

When starting a new conversation about HexMagic:

1. **Read llms.txt first** - Quick overview and key insights
2. **Then read PROJECT_OVERVIEW.md** - Full architecture understanding
3. **Refer to CODE_PATTERNS.md** - For code examples
4. **Check IMPLEMENTATION_CHECKLIST.md** - For current status
5. **Reference schema docs** - For database design details

## Document Maintenance

### When to Update

**PROJECT_OVERVIEW.md:**
- New major features added
- Architecture changes
- New workflows discovered
- Design patterns established

**CODE_PATTERNS.md:**
- New common operations identified
- Better code patterns discovered
- API changes

**IMPLEMENTATION_CHECKLIST.md:**
- Tasks completed
- New phases added
- Status changes

**Schema documents:**
- Database design changes
- New tables added
- Field modifications

### Update Process

1. Make changes to relevant document
2. Update related documents for consistency
3. Update llms.txt summary if major changes
4. Update this README if documentation structure changes

## Contributing

When contributing documentation:
- Keep examples focused and practical
- Include code comments for clarity
- Update all related documents
- Maintain consistent formatting
- Test code examples before committing

## Version History

- **v1.0** (2026-02-01): Initial comprehensive documentation set created
  - PROJECT_OVERVIEW.md
  - CODE_PATTERNS.md
  - IMPLEMENTATION_CHECKLIST.md
  - Updated llms.txt
  - This README

## Related Files

- `../HexMagic/` - Core library source code
- `../nbs/` - Jupyter notebooks (nbdev source)
- `../patterns/` - SVG pattern library
- `../.warpindexignore` - Files to exclude from indexing
