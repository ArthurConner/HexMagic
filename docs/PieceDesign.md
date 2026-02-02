# Piece Design Document

## Overview
This document details the design and implementation of game pieces (units/troops) for the HexMagic strategy game system. Pieces are autonomous agents that can move, explore, harvest resources, engage in combat, and establish settlements across the hex-based terrain.

## Core Data Structure

### Piece Class Definition

```python
from dataclasses import dataclass, field
from typing import Optional, List, Set
from enum import Enum
import uuid

class PieceGoal(Enum):
    """Available goals for pieces"""
    EXPLORE = "explore"
    HARVEST = "harvest"
    ATTACK = "attack"
    MOVE = "move"
    SETTLE = "settle"
    DEFEND = "defend"
    PATROL = "patrol"

class PersonalityTrait(Enum):
    """Personality tendencies when acting autonomously"""
    AGGRESSIVE = "aggressive"      # Prefers attack/explore
    DEFENSIVE = "defensive"        # Prefers defend/settle
    ECONOMIC = "economic"          # Prefers harvest/settle
    EXPLORER = "explorer"          # Prefers explore/move
    BALANCED = "balanced"          # No strong preference

@dataclass
class Piece:
    """A game piece representing a group of units."""
    
    # Identity
    id: str = field(default_factory=lambda: str(uuid.uuid4()))
    owner_id: int = 0  # Kingdom/country ID
    parent_id: Optional[str] = None  # ID of piece that spawned this
    
    # Core attributes
    size: int = 100  # Number of units in this piece
    health: int = 100  # Hit points (0-100 scale)
    max_health: int = 100
    
    # Vision and intelligence
    sight: int = 3  # How many hex rings they can see
    memory: float = 0.8  # Retention rate (0-1, higher = better memory)
    
    # Movement
    movement_range: int = 4  # Max weighted hexes per turn
    current_position: int = -1  # Current hex index
    
    # Goals and targeting
    goal: PieceGoal = PieceGoal.EXPLORE
    target_position: Optional[int] = None  # Target hex index
    target_piece: Optional[str] = None  # Target piece UUID
    
    # Behavior
    personality: PersonalityTrait = PersonalityTrait.BALANCED
    
    # Relationships
    spawned_pieces: List[str] = field(default_factory=list)  # UUIDs of children
    
    # Knowledge (what hexes this piece knows about)
    known_hexes: Set[int] = field(default_factory=set)
    knowledge_freshness: dict = field(default_factory=dict)  # hex_idx -> turn_last_seen
    
    # Settlement state
    is_settled: bool = False
    settle_progress: int = 0  # Turns spent settling (settlement complete at threshold)
    settle_threshold: int = 3
    
    # Visual representation
    pattern_id: Optional[str] = None  # SVGDef pattern for rendering
```

**Suggestions:**
- Consider adding `morale` attribute (0-100) that affects combat and desertion
- Add `supply_level` to track logistics and supply lines
- Consider `experience` that improves combat effectiveness over time
- Add `cargo` field for carrying resources or trade goods

---

## Movement System

### Movement Costs
Movement should account for terrain difficulty, elevation changes, and visibility.

```python
@patch
def movement_cost(self: Piece, from_hex: int, to_hex: int, terrain: Terrain, weather: Optional = None) -> float:
    """Calculate cost to move from one hex to another.
    
    Returns:
        float: Movement cost (1.0 = normal, inf = impassable)
    """
    from_elev = terrain.elevations[from_hex]
    to_elev = terrain.elevations[to_hex]
    
    # Water is impassable (unless we add naval units later)
    if to_elev < terrain.seaLevel:
        return float('inf')
    
    base_cost = 1.0
    
    # Elevation change penalty
    elev_diff = to_elev - from_elev
    if elev_diff > 0:  # Uphill
        base_cost += elev_diff * 1.5
    elif elev_diff < 0:  # Downhill (easier)
        base_cost += abs(elev_diff) * 0.3
    
    # Terrain type modifiers (if climate/biome data available)
    if hasattr(terrain, 'climate'):
        climate_zone = terrain.climate.zones[to_hex]
        if climate_zone in ['forest', 'jungle']:
            base_cost *= 1.5
        elif climate_zone in ['swamp']:
            base_cost *= 2.0
        elif climate_zone in ['road', 'grassland']:
            base_cost *= 0.8
    
    # Weather modifiers (future enhancement)
    if weather:
        base_cost *= weather.movement_modifier(to_hex)
    
    return base_cost
```

**Suggestions:**
- Implement road/route system that reduces movement costs along established paths
- Add terrain familiarity bonus (pieces move faster in known territory)
- Consider seasonal effects (snow, rain) that modify movement
- Add support for river crossings (higher cost or special requirements)

### Pathfinding

```python
@patch
def find_path(self: Piece, goal_hex: int, terrain: Terrain, 
              max_cost: Optional[float] = None) -> Optional[List[HexPosition]]:
    """Find optimal path using A* or Dijkstra.
    
    Reuses GameBoard.find_path_dijkstra but filters by movement_range.
    """
    # Use existing pathfinding from kingdom.py
    path = terrain.hexGrid.find_path_dijkstra(self.current_position, goal_hex)
    
    if path is None:
        return None
    
    # Calculate total cost and check against movement range
    if max_cost is None:
        max_cost = self.movement_range
    
    total_cost = sum(
        self.movement_cost(terrain.hexGrid.hexposition_to_index(path[i], self.current_position),
                          terrain.hexGrid.hexposition_to_index(path[i+1], self.current_position),
                          terrain)
        for i in range(len(path) - 1)
    )
    
    if total_cost > max_cost:
        # Truncate path to what we can afford
        path = self._truncate_path(path, max_cost, terrain)
    
    return path
```

**Suggestions:**
- Cache paths that are frequently used
- Add waypoint system for complex multi-turn movements
- Consider "retreating" behavior when health is low
- Implement formation movement for groups of pieces

---

## Vision and Knowledge System

### Vision Range and Fog of War

```python
@patch
def update_vision(self: Piece, terrain: Terrain, current_turn: int) -> Set[int]:
    """Update what this piece can currently see.
    
    Returns:
        Set of hex indices that are currently visible
    """
    grid = terrain.hexGrid
    visible = set()
    
    # Get all hexes within sight range
    center_pos = grid.index_to_hexposition(self.current_position)
    
    for ring in range(self.sight + 1):
        ring_positions = center_pos.ring(ring)
        for pos in ring_positions:
            hex_idx = grid.hexposition_to_index(pos, origin_index=self.current_position)
            
            # Check if valid and apply line-of-sight rules
            if hex_idx >= 0 and hex_idx < len(terrain.elevations):
                if self._has_line_of_sight(self.current_position, hex_idx, terrain):
                    visible.add(hex_idx)
                    self.known_hexes.add(hex_idx)
                    self.knowledge_freshness[hex_idx] = current_turn
    
    return visible

@patch
def _has_line_of_sight(self: Piece, from_hex: int, to_hex: int, terrain: Terrain) -> bool:
    """Check if there's line of sight between two hexes.
    
    Accounts for elevation and terrain blocking.
    """
    grid = terrain.hexGrid
    from_pos = grid.index_to_hexposition(from_hex)
    to_pos = grid.index_to_hexposition(to_hex, origin_index=from_hex)
    
    # Get hexes along the line
    line = from_pos.line_to(to_pos)
    
    from_elev = terrain.elevations[from_hex]
    to_elev = terrain.elevations[to_hex]
    
    # Check each hex in between
    for i, pos in enumerate(line[1:-1], 1):  # Skip endpoints
        hex_idx = grid.hexposition_to_index(pos, origin_index=from_hex)
        if hex_idx < 0:
            continue
            
        blocking_elev = terrain.elevations[hex_idx]
        
        # Simple elevation blocking (can be made more sophisticated)
        progress = i / len(line)
        expected_elev = from_elev + (to_elev - from_elev) * progress
        
        if blocking_elev > expected_elev + terrain.elevationDelta:
            return False  # Blocked by high terrain
    
    return True
```

**Suggestions:**
- Add terrain types that block vision (dense forest, fog)
- Implement shared vision between allied pieces
- Add watchtowers or high ground bonuses to sight range
- Consider time-of-day effects (night reduces vision)

### Memory and Knowledge Decay

```python
@patch
def decay_knowledge(self: Piece, current_turn: int, decay_rate: Optional[float] = None):
    """Forget old information based on memory stat.
    
    Lower memory = faster forgetting
    """
    if decay_rate is None:
        decay_rate = 1.0 - self.memory
    
    to_forget = set()
    for hex_idx, last_seen in self.knowledge_freshness.items():
        turns_ago = current_turn - last_seen
        
        # Probability of forgetting increases with time and decay rate
        forget_prob = min(turns_ago * decay_rate * 0.05, 0.95)
        
        if random.random() < forget_prob:
            to_forget.add(hex_idx)
    
    # Remove forgotten hexes
    for hex_idx in to_forget:
        self.known_hexes.discard(hex_idx)
        del self.knowledge_freshness[hex_idx]

@patch
def share_knowledge(self: Piece, other: 'Piece', share_rate: float = 0.5):
    """Share knowledge with another piece (same owner).
    
    Used when pieces meet or communicate along supply routes.
    """
    if self.owner_id != other.owner_id:
        return  # Don't share with enemies
    
    # Transfer a subset of knowledge
    to_share = random.sample(list(self.known_hexes), 
                            int(len(self.known_hexes) * share_rate))
    
    for hex_idx in to_share:
        other.known_hexes.add(hex_idx)
        # Use older timestamp to represent second-hand knowledge
        turn_seen = self.knowledge_freshness.get(hex_idx, 0)
        other.knowledge_freshness[hex_idx] = turn_seen - 1
```

**Suggestions:**
- Implement "scout" pieces with better memory and sight
- Add knowledge transfer to parent/child pieces (spawning)
- Create a kingdom-level knowledge map (aggregated from all pieces)
- Consider "rumor" system for inaccurate second-hand knowledge

---

## Combat System

### Combat Resolution

```python
@dataclass
class CombatResult:
    """Result of a combat encounter"""
    attacker_casualties: int
    defender_casualties: int
    attacker_retreated: bool
    defender_retreated: bool
    winner: Optional[str]  # piece_id or None for draw

@patch
def engage_combat(self: Piece, defender: 'Piece', terrain: Terrain) -> CombatResult:
    """Resolve combat between two pieces.
    
    Uses simple model based on size, health, and terrain.
    """
    # Calculate combat strength
    attacker_str = self.size * (self.health / 100.0)
    defender_str = defender.size * (defender.health / 100.0)
    
    # Terrain modifiers
    def_hex = defender.current_position
    def_elev = terrain.elevations[def_hex]
    atk_elev = terrain.elevations[self.current_position]
    
    # Defender gets bonus for high ground
    if def_elev > atk_elev:
        defender_str *= 1.3
    
    # Defender gets bonus for fortified/settled position
    if defender.is_settled:
        defender_str *= 1.5
    
    # Calculate casualties (simplified model)
    atk_casualty_rate = defender_str / (attacker_str + defender_str)
    def_casualty_rate = attacker_str / (attacker_str + defender_str)
    
    # Add randomness
    atk_casualties = int(self.size * atk_casualty_rate * random.uniform(0.1, 0.3))
    def_casualties = int(defender.size * def_casualty_rate * random.uniform(0.1, 0.3))
    
    # Apply casualties
    self.size = max(0, self.size - atk_casualties)
    defender.size = max(0, defender.size - def_casualties)
    
    # Health damage
    self.health = max(0, self.health - int(30 * atk_casualty_rate))
    defender.health = max(0, defender.health - int(30 * def_casualty_rate))
    
    # Determine winner
    winner = None
    attacker_retreated = False
    defender_retreated = False
    
    if defender.size == 0 or defender.health < 20:
        winner = self.id
        defender_retreated = True
    elif self.size == 0 or self.health < 20:
        winner = defender.id
        attacker_retreated = True
    
    return CombatResult(
        attacker_casualties=atk_casualties,
        defender_casualties=def_casualties,
        attacker_retreated=attacker_retreated,
        defender_retreated=defender_retreated,
        winner=winner
    )
```

**Suggestions:**
- Add unit types with rock-paper-scissors relationships (infantry, cavalry, archers)
- Implement flanking bonuses for attacking from multiple directions
- Add morale system that can cause early retreat
- Consider siege mechanics for attacking settlements
- Add battle logs/history for replay and analysis
- Implement experience system (veteran units fight better)

---

## Harvesting and Spawning

### Settlement and Resource Generation

```python
@patch
def attempt_settle(self: Piece, terrain: Terrain) -> bool:
    """Try to settle at current location.
    
    Returns True if settlement action taken.
    """
    if self.is_settled:
        return False
    
    # Can't settle on poor terrain
    current_elev = terrain.elevations[self.current_position]
    if current_elev < terrain.seaLevel or current_elev > terrain.elevationDelta * 8:
        return False
    
    self.settle_progress += 1
    
    if self.settle_progress >= self.settle_threshold:
        self.is_settled = True
        self.goal = PieceGoal.HARVEST
        return True
    
    return False

@patch
def harvest_and_spawn(self: Piece, terrain: Terrain, current_turn: int) -> Optional['Piece']:
    """Generate new pieces from a settled location.
    
    Returns newly spawned piece or None.
    """
    if not self.is_settled:
        return None
    
    # Calculate harvest rate based on terrain quality
    harvest_rate = self._calculate_harvest_rate(terrain)
    
    # Can spawn if size is sufficient and enough turns have passed
    min_spawn_size = 200
    spawn_cooldown = int(10 / harvest_rate)  # Better terrain = faster spawning
    
    if self.size >= min_spawn_size:
        # Check if enough time has passed since last spawn
        last_spawn_turn = getattr(self, '_last_spawn_turn', current_turn - spawn_cooldown)
        
        if current_turn - last_spawn_turn >= spawn_cooldown:
            # Create new piece
            spawn_size = self.size // 3
            self.size -= spawn_size
            
            new_piece = Piece(
                owner_id=self.owner_id,
                parent_id=self.id,
                size=spawn_size,
                health=100,
                sight=self.sight,
                memory=self.memory,
                movement_range=self.movement_range,
                current_position=self.current_position,
                personality=self.personality,
                pattern_id=self.pattern_id
            )
            
            # Share knowledge with child
            self.share_knowledge(new_piece, share_rate=0.3)
            
            self.spawned_pieces.append(new_piece.id)
            self._last_spawn_turn = current_turn
            
            return new_piece
    
    # Natural growth when not spawning
    growth = int(self.size * harvest_rate * 0.05)
    self.size = min(self.size + growth, 500)  # Cap at max size
    
    return None

@patch
def _calculate_harvest_rate(self: Piece, terrain: Terrain) -> float:
    """Calculate resource generation rate based on terrain.
    
    Returns value 0.1 to 1.0
    """
    hex_idx = self.current_position
    elevation = terrain.elevations[hex_idx]
    
    # Best elevation range
    ideal_low = terrain.seaLevel + terrain.elevationDelta
    ideal_high = terrain.seaLevel + terrain.elevationDelta * 4
    
    if ideal_low <= elevation <= ideal_high:
        base_rate = 1.0
    else:
        base_rate = 0.3
    
    # Climate bonuses (if available)
    if hasattr(terrain, 'climate'):
        climate_zone = terrain.climate.zones[hex_idx]
        if climate_zone in ['temperate', 'grassland']:
            base_rate *= 1.2
        elif climate_zone in ['desert', 'tundra']:
            base_rate *= 0.5
    
    # Proximity to water (rivers/coast) bonus
    if hasattr(terrain, 'geo') and hasattr(terrain.geo, 'basins'):
        # Check if near water
        nearby_water = any(
            terrain.elevations[n] < terrain.seaLevel 
            for n in terrain.hexGrid.neighbors(hex_idx)
        )
        if nearby_water:
            base_rate *= 1.3
    
    return min(base_rate, 1.0)
```

**Suggestions:**
- Add different resource types (food, minerals, wood)
- Implement diminishing returns (overharvesting depletes terrain)
- Add trade system where excess resources can be transported
- Consider population happiness/loyalty mechanics
- Implement "upgrade" system for settlements (village → town → city)

---

## AI Planning and Decision Making

### Goal Selection

```python
@patch
def plan_next_action(self: Piece, terrain: Terrain, all_pieces: List['Piece'], 
                     current_turn: int) -> PieceGoal:
    """Decide what to do next based on knowledge and personality.
    
    Uses weighted decision tree based on personality.
    """
    # Update vision first
    visible = self.update_vision(terrain, current_turn)
    
    # Check for immediate threats
    enemies_nearby = [
        p for p in all_pieces 
        if p.owner_id != self.owner_id and p.current_position in visible
    ]
    
    if enemies_nearby and self.personality != PersonalityTrait.ECONOMIC:
        # React to threats
        if self.size < min(e.size for e in enemies_nearby) * 0.7:
            self.goal = PieceGoal.DEFEND  # Or retreat
        else:
            self.goal = PieceGoal.ATTACK
            self.target_piece = enemies_nearby[0].id
        return self.goal
    
    # No immediate threat - decide based on personality and state
    weights = self._get_goal_weights()
    
    # Modify weights based on current state
    if self.size < 50:
        weights[PieceGoal.SETTLE] *= 0.1  # Too small to settle
    if not self.is_settled:
        weights[PieceGoal.HARVEST] = 0.0  # Can't harvest without settling
    if len(self.known_hexes) > self.sight * 20:
        weights[PieceGoal.EXPLORE] *= 0.5  # Already explored a lot
    
    # Select goal probabilistically
    goals, probs = zip(*[(g, w) for g, w in weights.items() if w > 0])
    total = sum(probs)
    probs = [p/total for p in probs]
    
    self.goal = random.choices(goals, weights=probs)[0]
    return self.goal

@patch
def _get_goal_weights(self: Piece) -> dict[PieceGoal, float]:
    """Get goal weights based on personality."""
    base_weights = {
        PieceGoal.EXPLORE: 1.0,
        PieceGoal.HARVEST: 1.0,
        PieceGoal.ATTACK: 0.5,
        PieceGoal.SETTLE: 1.0,
        PieceGoal.DEFEND: 0.3,
        PieceGoal.PATROL: 0.5,
    }
    
    personality_modifiers = {
        PersonalityTrait.AGGRESSIVE: {
            PieceGoal.ATTACK: 3.0,
            PieceGoal.EXPLORE: 2.0,
            PieceGoal.SETTLE: 0.3,
        },
        PersonalityTrait.DEFENSIVE: {
            PieceGoal.DEFEND: 3.0,
            PieceGoal.SETTLE: 2.0,
            PieceGoal.PATROL: 2.0,
        },
        PersonalityTrait.ECONOMIC: {
            PieceGoal.HARVEST: 3.0,
            PieceGoal.SETTLE: 2.5,
            PieceGoal.EXPLORE: 0.5,
        },
        PersonalityTrait.EXPLORER: {
            PieceGoal.EXPLORE: 4.0,
            PieceGoal.MOVE: 2.0,
        },
    }
    
    modifiers = personality_modifiers.get(self.personality, {})
    for goal, modifier in modifiers.items():
        base_weights[goal] *= modifier
    
    return base_weights

@patch
def execute_goal(self: Piece, terrain: Terrain, all_pieces: List['Piece'], 
                 current_turn: int) -> bool:
    """Execute current goal. Returns True if action taken."""
    
    if self.goal == PieceGoal.SETTLE:
        return self.attempt_settle(terrain)
    
    elif self.goal == PieceGoal.HARVEST:
        spawn = self.harvest_and_spawn(terrain, current_turn)
        return spawn is not None
    
    elif self.goal == PieceGoal.EXPLORE:
        # Move toward unknown hexes
        unknown_nearby = self._find_unknown_frontier()
        if unknown_nearby:
            path = self.find_path(unknown_nearby[0], terrain)
            if path and len(path) > 1:
                self._move_along_path(path, terrain)
                return True
    
    elif self.goal == PieceGoal.ATTACK:
        if self.target_piece:
            target = next((p for p in all_pieces if p.id == self.target_piece), None)
            if target:
                # Move toward enemy
                path = self.find_path(target.current_position, terrain)
                if path and len(path) > 1:
                    self._move_along_path(path, terrain)
                    # Check if adjacent
                    if self._is_adjacent(target, terrain):
                        self.engage_combat(target, terrain)
                    return True
    
    elif self.goal == PieceGoal.DEFEND:
        # Stay put or move to defensive position
        return False
    
    elif self.goal == PieceGoal.PATROL:
        # Move along kingdom borders
        return self._patrol_borders(terrain)
    
    return False

@patch
def _find_unknown_frontier(self: Piece) -> List[int]:
    """Find hexes on the edge of known territory."""
    frontier = []
    for hex_idx in self.known_hexes:
        neighbors = self.terrain.hexGrid.neighbors(hex_idx)
        unknown_neighbors = [n for n in neighbors if n not in self.known_hexes]
        if unknown_neighbors:
            frontier.extend(unknown_neighbors)
    return list(set(frontier))
```

**Suggestions:**
- Add strategic layer: pieces coordinate with each other
- Implement "mission" system where player can assign explicit goals
- Add difficulty/aggression settings for AI behavior
- Consider emotional states (fear, anger) that modify decision-making
- Implement learning/adaptation based on past successes/failures

---

## Serialization and Storage

### Encoding/Decoding

```python
@patch
def encode(self: Piece) -> str:
    """Encode piece to string format for storage."""
    lines = [
        f"id:{self.id}",
        f"owner_id:{self.owner_id}",
        f"parent_id:{self.parent_id or ''}",
        f"size:{self.size}",
        f"health:{self.health}",
        f"max_health:{self.max_health}",
        f"sight:{self.sight}",
        f"memory:{self.memory}",
        f"movement_range:{self.movement_range}",
        f"current_position:{self.current_position}",
        f"goal:{self.goal.value}",
        f"target_position:{self.target_position or ''}",
        f"target_piece:{self.target_piece or ''}",
        f"personality:{self.personality.value}",
        f"spawned_pieces:{','.join(self.spawned_pieces)}",
        f"known_hexes:{','.join(str(h) for h in sorted(self.known_hexes))}",
        f"is_settled:{self.is_settled}",
        f"settle_progress:{self.settle_progress}",
        f"pattern_id:{self.pattern_id or ''}",
    ]
    
    # Knowledge freshness
    if self.knowledge_freshness:
        kf_str = ';'.join(f"{h}={t}" for h, t in self.knowledge_freshness.items())
        lines.append(f"knowledge_freshness:{kf_str}")
    
    return '\n'.join(lines)

@staticmethod
def decode(s: str) -> 'Piece':
    """Decode piece from string format."""
    piece = Piece()
    
    for line in s.strip().split('\n'):
        if ':' not in line:
            continue
        key, val = line.split(':', 1)
        
        if key == 'id':
            piece.id = val
        elif key == 'owner_id':
            piece.owner_id = int(val)
        elif key == 'parent_id':
            piece.parent_id = val if val else None
        elif key == 'size':
            piece.size = int(val)
        elif key == 'health':
            piece.health = int(val)
        elif key == 'max_health':
            piece.max_health = int(val)
        elif key == 'sight':
            piece.sight = int(val)
        elif key == 'memory':
            piece.memory = float(val)
        elif key == 'movement_range':
            piece.movement_range = int(val)
        elif key == 'current_position':
            piece.current_position = int(val)
        elif key == 'goal':
            piece.goal = PieceGoal(val)
        elif key == 'target_position':
            piece.target_position = int(val) if val else None
        elif key == 'target_piece':
            piece.target_piece = val if val else None
        elif key == 'personality':
            piece.personality = PersonalityTrait(val)
        elif key == 'spawned_pieces':
            piece.spawned_pieces = val.split(',') if val else []
        elif key == 'known_hexes':
            piece.known_hexes = {int(h) for h in val.split(',') if h}
        elif key == 'is_settled':
            piece.is_settled = val == 'True'
        elif key == 'settle_progress':
            piece.settle_progress = int(val)
        elif key == 'pattern_id':
            piece.pattern_id = val if val else None
        elif key == 'knowledge_freshness':
            piece.knowledge_freshness = {
                int(h): int(t) for h, t in 
                (pair.split('=') for pair in val.split(';') if pair)
            }
    
    return piece
```

**Suggestions:**
- Use JSON or binary format for more efficient serialization
- Compress knowledge data (can be very large)
- Add version field for backward compatibility
- Implement delta encoding for turn-by-turn changes

---

## Visualization

### SVG Rendering

```python
@patch
def render(self: Piece, terrain: Terrain, style_name: Optional[str] = None) -> str:
    """Render piece as SVG element at current position."""
    if self.current_position < 0:
        return ""
    
    grid = terrain.hexGrid
    hex_obj = grid.hexes[self.current_position]
    cx, cy = hex_obj.center.x, hex_obj.center.y
    
    # Size visualization (scale by piece size)
    radius = max(5, min(20, 5 + self.size / 50))
    
    # Health indicator (color)
    health_pct = self.health / 100.0
    if health_pct > 0.7:
        health_color = "#00ff00"
    elif health_pct > 0.3:
        health_color = "#ffff00"
    else:
        health_color = "#ff0000"
    
    # Create style if needed
    if style_name is None:
        style_name = f"piece_{self.id}"
        style = StyleCSS(
            style_name,
            fill=health_color,
            stroke="#000",
            stroke_width=1.5,
            opacity=0.8
        )
        grid.builder.add_style(style)
    
    # Use pattern if available
    if self.pattern_id:
        svg = f'<circle cx="{cx}" cy="{cy}" r="{radius}" fill="url(#{self.pattern_id})" class="{style_name}"/>'
    else:
        svg = f'<circle cx="{cx}" cy="{cy}" r="{radius}" class="{style_name}"/>'
    
    # Add goal indicator
    if self.goal == PieceGoal.ATTACK:
        # Draw small red arrow
        svg += f'<path d="M {cx-3} {cy-10} L {cx} {cy-13} L {cx+3} {cy-10}" stroke="red" stroke-width="2" fill="none"/>'
    elif self.goal == PieceGoal.SETTLE:
        # Draw small house icon
        svg += f'<rect x="{cx-4}" y="{cy-10}" width="8" height="6" fill="#8b4513"/>'
    
    return svg

@patch
def render_vision_overlay(self: Piece, terrain: Terrain, turn: int) -> str:
    """Render fog of war / vision overlay."""
    grid = terrain.hexGrid
    overlay = ""
    
    visible = self.update_vision(terrain, turn)
    known_but_not_visible = self.known_hexes - visible
    
    # Style for fog
    fog_style = StyleCSS("fog", fill="#000", opacity=0.6, stroke="none")
    stale_style = StyleCSS("stale", fill="#000", opacity=0.3, stroke="none")
    
    grid.builder.add_style(fog_style)
    grid.builder.add_style(stale_style)
    
    # Render fog over unknown hexes
    all_hexes = set(range(len(terrain.elevations)))
    unknown = all_hexes - self.known_hexes
    
    for hex_idx in unknown:
        hex_obj = grid.hexes[hex_idx]
        overlay += f'{hex_obj.svg(style=fog_style)}\n'
    
    # Render lighter fog over known but not currently visible
    for hex_idx in known_but_not_visible:
        hex_obj = grid.hexes[hex_idx]
        overlay += f'{hex_obj.svg(style=stale_style)}\n'
    
    return overlay
```

**Suggestions:**
- Add animation for movement (SVG animate elements)
- Show planned path as dotted line
- Add unit count numbers overlaid on pieces
- Create distinctive icons for different personality types
- Implement selection highlighting for player-controlled pieces

---

## Integration with Existing Systems

### Kingdom Integration

Pieces should be tracked at the Kingdom level:

```python
@dataclass
class Kingdom:
    # ... existing fields ...
    pieces: List[Piece] = field(default_factory=list)
    
    def spawn_initial_pieces(self, count: int = 3):
        """Create starting pieces at capital."""
        for i in range(count):
            piece = Piece(
                owner_id=self.countryId,
                size=100,
                current_position=self.settlements[0],
                sight=3,
                movement_range=4,
                personality=random.choice(list(PersonalityTrait)),
                pattern_id=f"{self.flag.name}_pattern"
            )
            self.pieces.append(piece)
```

### GameBoard Integration

```python
@patch
def process_turn(self: GameBoard, turn_number: int):
    """Process one turn for all kingdoms."""
    all_pieces = []
    for kingdom in self.kingdoms:
        all_pieces.extend(kingdom.pieces)
    
    # Each piece plans and acts
    for kingdom in self.kingdoms:
        for piece in kingdom.pieces:
            # Decay knowledge
            piece.decay_knowledge(turn_number)
            
            # Plan
            piece.plan_next_action(self.terrain, all_pieces, turn_number)
            
            # Execute
            piece.execute_goal(self.terrain, all_pieces, turn_number)
            
            # Spawn new pieces
            new_piece = piece.harvest_and_spawn(self.terrain, turn_number)
            if new_piece:
                kingdom.pieces.append(new_piece)
    
    # Remove destroyed pieces
    for kingdom in self.kingdoms:
        kingdom.pieces = [p for p in kingdom.pieces if p.size > 0]
```

**Suggestions:**
- Add turn limit/timeout to prevent infinite loops
- Implement simultaneous movement resolution (all pieces plan, then all execute)
- Add event system for important happenings (battles, settlements)
- Create turn summary/report for player review

---

## Database Schema

Add new table for pieces:

```python
@dataclass
class PieceRecord:
    game_id: int
    piece_data: str  # Encoded piece
    turn_number: int
    created: int
    id: int = None
```

This allows tracking piece history over turns and enables replay functionality.

**Suggestions:**
- Store only changed pieces per turn (delta storage)
- Add indices for fast querying by game_id and turn
- Consider separate tables for piece_events (battles, spawns)
- Implement periodic checkpoints to speed up game loading

---

## Next Steps

1. **Implementation Priority:**
   - Core Piece dataclass and basic movement
   - Vision and knowledge system
   - Simple combat mechanics
   - Settlement and spawning
   - AI planning (basic version)
   - Visualization overlays

2. **Testing Strategy:**
   - Unit tests for movement costs and pathfinding
   - Combat simulation with various scenarios
   - AI behavior testing (do pieces behave reasonably?)
   - Integration tests with existing Kingdom/GameBoard code

3. **Performance Considerations:**
   - Cache pathfinding results
   - Limit knowledge set size per piece
   - Use spatial indexing for piece lookups
   - Consider async processing for AI planning

4. **Future Enhancements:**
   - Naval units
   - Air reconnaissance
   - Supply lines and logistics
   - Diplomacy between AI-controlled pieces
   - Hero units with unique abilities
   - Technology/upgrades system
