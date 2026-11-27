class_name JuiceData
extends Resource
## Game-feel tuning in one place (resources/juice.tres): hit stop, the debug FPS overlay and, in
## later stages, shake, particles and post-processing. Defaults are 0 so the numbers live only in
## the .tres; validate() lists what is unusable.

const PATH: String = "res://resources/juice.tres"

@export_group("Hit stop")
## Engine.time_scale while a hit stop runs (0 < scale < 1; near 0 = almost frozen).
@export var hit_stop_time_scale: float = 0.0
## Real-time seconds of the stop when the sword kills an enemy.
@export var hit_stop_enemy_kill_sec: float = 0.0
## Real-time seconds of the stop when the sword hits the boss without killing it.
@export var hit_stop_boss_hit_sec: float = 0.0
## Real-time seconds of the stop when the hero loses HP.
@export var hit_stop_hero_hurt_sec: float = 0.0
## Longest single stop a request may ask for; longer requests are clamped.
@export var hit_stop_max_sec: float = 0.0

@export_group("FPS overlay")
## Seconds between two refreshes of the overlay text (also the averaging window).
@export var overlay_refresh_sec: float = 0.0
## Seconds a finger must rest in the top-left corner to toggle the overlay.
@export var overlay_long_press_sec: float = 0.0
## Side (UI px, 1920 × 1080 base) of the top-left square that takes the long press.
@export var overlay_corner_px: float = 0.0
## A finger that moves further than this (UI px) cancels the long press.
@export var overlay_press_slop_px: float = 0.0

static var _loaded: JuiceData

## The project's tuning, loaded once. A missing or broken file gives an empty resource with an
## error: every effect then stays off instead of the game stopping.
static func get_data() -> JuiceData:
	if _loaded != null:
		return _loaded
	var data: JuiceData = null
	if ResourceLoader.exists(PATH):
		data = load(PATH) as JuiceData
	if data == null:
		push_error("JuiceData: %s is missing or not a JuiceData, effects are off" % PATH)
		data = JuiceData.new()
	for problem in data.validate():
		push_error("JuiceData: %s" % problem)
	_loaded = data
	return _loaded

## True when the hit-stop numbers can be used; otherwise requests are ignored.
func hit_stop_ok() -> bool:
	return hit_stop_time_scale > 0.0 and hit_stop_time_scale < 1.0 and hit_stop_max_sec > 0.0

## True when the overlay numbers can be used; otherwise the overlay stays hidden.
func overlay_ok() -> bool:
	return overlay_refresh_sec > 0.0 and overlay_long_press_sec > 0.0 and overlay_corner_px > 0.0 \
		and overlay_press_slop_px >= 0.0

## Human-readable problems; empty when everything is usable.
func validate() -> Array[String]:
	var problems: Array[String] = []
	if not hit_stop_ok():
		problems.append("hit_stop_time_scale must be in (0, 1) and hit_stop_max_sec > 0")
	for field in [&"hit_stop_enemy_kill_sec", &"hit_stop_boss_hit_sec", &"hit_stop_hero_hurt_sec"]:
		var value: float = get(field)
		if value < 0.0 or value > hit_stop_max_sec:
			problems.append("%s = %s must be in [0, hit_stop_max_sec]" % [field, value])
	if not overlay_ok():
		problems.append("overlay_* values must be > 0 (slop >= 0)")
	return problems
