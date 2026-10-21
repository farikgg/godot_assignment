extends Node
## Autoload MusicPlayer: background music for every screen on the Music bus.
## Menu and win screen — the menu track (A3); levels — music_level; the arena — music_boss
## (falls back to music_level when the file is missing). Changes crossfade over fade_time;
## asking for the track that is already playing changes nothing, so moving between levels
## does not restart it. Plays during the pause too.

const MENU_TRACK: String = "res://assets/Audio/8-bit_sound.ogg"
const LEVEL_TRACK: String = "res://assets/Audio/music/music_level.ogg"
const BOSS_TRACK: String = "res://assets/Audio/music/music_boss.ogg"
const BUS: StringName = &"Music"
const SILENT_DB: float = -80.0
## A track starts this many frames after it is asked for (see play_track).
const START_DELAY_FRAMES: int = 2

@export var fade_time: float = 1.0

var _players: Array[AudioStreamPlayer] = []
var _active: int = 0
var _current_path: String = ""
var _volume_linear: float = 1.0
var _tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.name = "Track%d" % i
		player.bus = BUS
		player.volume_db = SILENT_DB
		add_child(player)
		_players.append(player)

func play_menu() -> void:
	play_track(MENU_TRACK)

## Level music; `boss` picks the arena track when it exists.
func play_level(boss: bool = false) -> void:
	play_track(BOSS_TRACK if boss and ResourceLoader.exists(BOSS_TRACK) else LEVEL_TRACK)

## Crossfades to `path` (looped). The same path again is a no-op; a missing file fades to silence.
func play_track(path: String) -> void:
	if path == _current_path:
		return
	_current_path = path
	# A playback is only released by the audio thread a few frames after stop(); one still alive
	# when the engine exits leaks («ObjectDB instances leaked»). Starting a moment later means a
	# run that quits on its first frame (`--quit`) never starts one. Unnoticeable in play.
	for i in START_DELAY_FRAMES:
		await get_tree().process_frame
	if path != _current_path:
		return  # another track was asked for meanwhile
	var stream: AudioStream = Sfx.load_stream(path)
	_set_loop(stream)
	var old: AudioStreamPlayer = _players[_active]
	_active = 1 - _active
	var next: AudioStreamPlayer = _players[_active]
	next.stream = stream
	next.volume_db = SILENT_DB
	if stream != null:
		next.play()
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(next, "volume_db", _target_db(), fade_time)
	_tween.tween_property(old, "volume_db", SILENT_DB, fade_time)
	_tween.chain().tween_callback(_release.bind(old))

func current_track() -> String:
	return _current_path

## The player currently fading in or playing (for tests).
func active_player() -> AudioStreamPlayer:
	return _players[_active]

## Settings slider: 0..1 on top of the Music bus level.
func set_volume_linear(value: float) -> void:
	_volume_linear = clampf(value, 0.0, 1.0)
	if _tween != null and _tween.is_valid():
		_tween.kill()
		_release(_players[1 - _active])
	_players[_active].volume_db = _target_db()

func get_volume_linear() -> float:
	return _volume_linear

func _target_db() -> float:
	return linear_to_db(_volume_linear) if _volume_linear > 0.0 else SILENT_DB

func _set_loop(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD

func _release(player: AudioStreamPlayer) -> void:
	player.stop()
	player.stream = null

## Stops all music at once (before quitting; GameFlow.quit_game waits for the audio thread).
func stop_all() -> void:
	_current_path = ""
	if _tween != null and _tween.is_valid():
		_tween.kill()
	for player in _players:
		_release(player)

func _exit_tree() -> void:
	stop_all()
