class_name GameEventBus
extends Node
## Autoload GameEvents: gameplay announces what happened, effects (FxDirector, HitStop, shake)
## listen. Emitters never depend on a listener, so a level without effects plays the same.
## Gameplay reaches it through GameEventBus.get_bus() instead of the autoload name, so its scripts
## still compile where autoloads do not exist yet (headless -s tests and tools).

const AUTOLOAD_PATH: NodePath = ^"/root/GameEvents"

## Pickup kinds for pickup_collected.
const PICKUP_COIN: StringName = &"coin"
const PICKUP_KEY: StringName = &"key"
const PICKUP_SWORD: StringName = &"sword"
const PICKUP_POTION: StringName = &"potion"

## The sword took HP from an enemy; `killed` when that hit emptied its health.
signal enemy_hit(position: Vector3, enemy: Enemy, killed: bool)
## An enemy (the boss included) died; emitted once per enemy.
signal enemy_died(position: Vector3, enemy: Enemy)
## The hero lost `amount` HP (any source); also emitted on the killing blow.
signal hero_hurt(position: Vector3, amount: int)
## The hero died (HP to 0 or a pit).
signal hero_died(position: Vector3)
## The hero touched the floor after being airborne; `impact_speed` is the fall speed (m/s, >= 0).
signal hero_landed(position: Vector3, impact_speed: float)
## A pickup was taken; `kind` is one of the PICKUP_* names.
signal pickup_collected(position: Vector3, kind: StringName)
## The level is won (exit with enough gold, or the boss fell); `position` is the hero's.
signal level_won(position: Vector3)
## The level is lost (the hero died); `position` is the hero's.
signal level_lost(position: Vector3)

static var _bus: GameEventBus
static var _missing_reported: bool = false

## The GameEvents autoload; when it is missing, a detached bus (emits reach nobody) and one error.
static func get_bus() -> GameEventBus:
	if is_instance_valid(_bus) and _bus.is_inside_tree():
		return _bus
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var found: GameEventBus = tree.root.get_node_or_null(AUTOLOAD_PATH) as GameEventBus if tree != null else null
	if found != null:
		_bus = found
		return _bus
	if not _missing_reported:
		_missing_reported = true
		push_error("GameEventBus: autoload %s is missing, game events reach nobody" % AUTOLOAD_PATH)
	if not is_instance_valid(_bus):
		_bus = GameEventBus.new()
	return _bus
