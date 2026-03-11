# Godot Development Best Practices
# Source: skills.sh/zate/cc-godot/godot-development
# Committed to bug-hunter-d33 for zero-dependency CI

## Overview
Expert guidance for Godot Engine game development with GDScript.

## Scene Tree Architecture

- Scenes are collections of nodes arranged in a tree hierarchy
- Every scene has a root node; nodes inherit from parents
- Scene instances can be nested and reused
- The scene tree is traversed from root to leaves

## Node Types & Usage

### 2D Nodes
- **Node2D**: Base for all 2D (position, rotation, scale)
- **Sprite2D**: Displays 2D textures
- **AnimatedSprite2D**: Sprite animations
- **CollisionShape2D**: Collision areas (child of physics body)
- **Area2D**: Detects overlapping bodies/areas
- **CharacterBody2D**: Physics body with movement functions
- **RigidBody2D**: Physics body affected by forces
- **StaticBody2D**: Immovable physics body
- **TileMap**: Grid-based tile system
- **Camera2D**: 2D camera with follow/zoom
- **CanvasLayer**: UI layer fixed on screen
- **Control**: Base for UI elements (Button, Label, Panel)

### 3D Nodes
- **Node3D**: Base for all 3D
- **MeshInstance3D**: Displays 3D meshes
- **Camera3D**: 3D camera
- **DirectionalLight3D/OmniLight3D/SpotLight3D**: Lighting

### Common Utility Nodes
- **Timer**: Execute code after delay
- **AudioStreamPlayer**: Play sounds
- **AnimationPlayer**: Complex animations
- **Tween**: Smooth property transitions

## GDScript Best Practices

### Node References (Safe Patterns)
```gdscript
# Good: Use @onready for node caching
@onready var sprite = $Sprite2D
@onready var collision = $CollisionShape2D

# Good: Use unique names for stable references
@onready var player = %Player

# Avoid: Hardcoded paths that break on restructure
var player = get_node("/root/Main/Player")
```

### Lifecycle Methods
```gdscript
func _ready():
    # Called when node enters scene tree
    pass

func _process(delta):
    # Called every frame - use for visual updates
    pass

func _physics_process(delta):
    # Called every physics frame - use for movement
    pass
```

### Signals vs Direct Calls
```gdscript
# Good: Use signals for loose coupling
signal health_changed(new_health)

func take_damage(amount):
    health -= amount
    health_changed.emit(health)

# Avoid: Direct parent/child coupling
get_parent().update_health(health)
```

## Project Structure
```
project/
├── project.godot       # Project configuration
├── scenes/             # All .tscn files
│   ├── main/          # Main game scenes
│   ├── ui/            # UI scenes
│   ├── characters/    # Character scenes
│   └── levels/        # Level scenes
├── scripts/           # GDScript files
│   ├── autoload/      # Singletons
│   ├── characters/    # Character logic
│   └── systems/       # Game systems
├── assets/            # Art, audio
└── resources/         # .tres files
```

## Bug Hunter Focus for Godot

1. **Memory Leaks**: Check for circular references, unconnected signals
2. **Node Path Safety**: Verify @onready usage, avoid fragile paths
3. **Physics in _process()**: Movement should be in _physics_process
4. **Signal Connections**: Ensure signals are connected, disconnect on exit
5. **Resource Loading**: Cache loaded resources, don't load every frame
6. **Collision Layers**: Verify proper layer/mask configuration
