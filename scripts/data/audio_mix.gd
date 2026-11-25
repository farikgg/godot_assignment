class_name AudioMix
extends Resource
## Audio tuning in one place (resources/audio_mix.tres): per-sound levels, 3D falloff for enemy
## sounds, music crossfade and track gains, pause softening, the variation pitch. Defaults are 0 /
## empty so the numbers live only in the .tres; validate() lists what is unusable.

const PATH: String = "res://resources/audio_mix.tres"
## Godot treats an attenuation filter cutoff at or above this as "no filter".
const FILTER_OFF_HZ: float = 20500.0

@export_group("Effects")
## volume_db per sound file or randomizer path, so recordings made at different levels sit together
## (measured by their loudest 400 ms, aiming at about -14 dBFS). Streams not listed play at 0 dB.
@export var sfx_volume_db: Dictionary[String, float] = {}
## random_pitch every AudioStreamRandomizer in assets/Audio/randomizers must use. The engine picks
## a pitch in [1 / random_pitch, random_pitch]: 1.08 measured as -7.0 % .. +8.4 %.
@export var random_pitch: float = 0.0

@export_group("Enemy sounds in 3D")
## Distance (m) at which a 3D sound plays at its own volume; it halves (-6 dB) at twice that.
@export var spatial_unit_size: float = 0.0
## Beyond this distance (m) from the hero a 3D sound is silent.
@export var spatial_max_distance: float = 0.0
## Loudest a 3D sound may get when the source is closer than unit_size.
@export var spatial_max_db: float = 0.0
## Distance low-pass; FILTER_OFF_HZ keeps far warnings as sharp as near ones.
@export var spatial_filter_cutoff_hz: float = 0.0
## Height (m) of the hero's ears above its origin.
@export var listener_height: float = 0.0

static var _loaded: AudioMix

## The project's mix, loaded once. A missing or broken file gives an empty mix with an error:
## sounds still play (0 dB, no 3D, no variation check) instead of the game stopping.
static func get_mix() -> AudioMix:
	if _loaded != null:
		return _loaded
	var mix: AudioMix = null
	if ResourceLoader.exists(PATH):
		mix = load(PATH) as AudioMix
	if mix == null:
		push_error("AudioMix: %s is missing or not an AudioMix, using an empty mix" % PATH)
		mix = AudioMix.new()
	for problem in mix.validate():
		push_error("AudioMix: %s" % problem)
	_loaded = mix
	return _loaded

## Level for `stream` (0 dB when not listed or null).
func volume_db_for(stream: AudioStream) -> float:
	if stream == null:
		return 0.0
	return sfx_volume_db.get(stream.resource_path, 0.0)

## True when the 3D numbers can be used; otherwise enemy sounds fall back to plain 2D.
func spatial_ok() -> bool:
	return spatial_unit_size > 0.0 and spatial_max_distance > spatial_unit_size

## Human-readable problems; empty when the mix is usable.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	for path in sfx_volume_db:
		if not ResourceLoader.exists(path):
			problems.append("sfx_volume_db lists %s, which does not exist" % path)
	if random_pitch < 1.0:
		problems.append("random_pitch %.3f must be >= 1 (1 = no variation)" % random_pitch)
	if not spatial_ok():
		problems.append("spatial_unit_size %.1f / spatial_max_distance %.1f: need 0 < unit < max"
			% [spatial_unit_size, spatial_max_distance])
	if spatial_filter_cutoff_hz <= 0.0:
		problems.append("spatial_filter_cutoff_hz must be > 0")
	if listener_height < 0.0:
		problems.append("listener_height must be >= 0")
	return problems
