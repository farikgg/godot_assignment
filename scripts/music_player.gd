extends Node
## Autoload MusicPlayer: background music for every screen on the Music bus.
## Menu and win screen: the menu track; levels: levels_music; the boss arena: final_round_music
## (levels_music when that file is missing). A change crossfades over AudioMix.music_fade_time with
## an equal-power curve (no loudness dip in the middle, no click: every player starts and stops at
## silence). Asking for the track that is playing, or one still fading out, never restarts it, so a
## level reload or the next level keeps the music going. Plays during the pause too. The volume
## setting is the Music bus level (SaveGame), not the per-track gain here.
## The pause menu softens the music (set_pause_softened): the Music bus carries a low-pass and an
## Amplify (default_bus_layout.tres, disabled); they are enabled and tweened only while paused and
## disabled again on resume, scene change, menu and quit.

const MENU_TRACK: String = "res://assets/Audio/8-bit_sound.ogg"
const LEVEL_TRACK: String = "res://assets/Audio/levels_music.wav"
const BOSS_TRACK: String = "res://assets/Audio/final_round_music.wav"
const BUS: StringName = &"Music"
## Below this linear gain a player counts as silent and is released.
const SILENT_GAIN: float = 0.001
## A track starts this many frames after it is asked for (see play_track).
const START_DELAY_FRAMES: int = 2
## Names of the pause effects on the Music bus in default_bus_layout.tres (disabled by default).
const PAUSE_LOWPASS: String = "Paused LowPass"
const PAUSE_AMPLIFY: String = "Paused Amplify"

## Number of play() calls on a new playback since the start (tests: a no-restart adds none).
var starts: int = 0

var _mix: AudioMix
## Every music player still audible; at most one is _active, the rest are fading out.
var _players: Array[AudioStreamPlayer] = []
var _active: AudioStreamPlayer
var _requested: String = ""
var _gain: Dictionary[AudioStreamPlayer, float] = {}
var _fade_from: Dictionary[AudioStreamPlayer, float] = {}
var _track_db: Dictionary[AudioStreamPlayer, float] = {}
var _path_of: Dictionary[AudioStreamPlayer, String] = {}
var _tween: Tween
var _serial: int = 0
# pause softening: the two permanent Music bus effects (found by name), their slots, 0..1 strength
var _soft_filter: AudioEffectLowPassFilter
var _soft_amp: AudioEffectAmplify
var _soft_filter_index: int = -1
var _soft_amp_index: int = -1
var _warned_soft_missing: bool = false
var _soft_amount: float = 0.0
var _soft_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_mix = AudioMix.get_mix()
	if AudioServer.get_bus_index(BUS) == -1:
		push_warning("MusicPlayer: bus '%s' not found, music plays on Master and the pause leaves it alone" % BUS)
	else:
		_find_soft_effects()  # warns now when the layout lacks them
		clear_pause_softening()  # whatever the layout says, start disabled at "no change"

func play_menu() -> void:
	play_track(MENU_TRACK)

## Level music; `boss` picks the arena track when it exists.
func play_level(boss: bool = false) -> void:
	play_track(BOSS_TRACK if boss and ResourceLoader.exists(BOSS_TRACK) else LEVEL_TRACK)

## Crossfades to `path` (looped). The track already asked for is a no-op; a missing file fades to
## silence (with one warning from Sfx.load_stream).
func play_track(path: String) -> void:
	if path == _requested:
		return
	_requested = path
	# A playback is only released by the audio thread a few frames after stop(); one still alive
	# when the engine exits leaks («ObjectDB instances leaked»). Starting a moment later means a
	# run that quits on its first frame (`--quit`) never starts one. Unnoticeable in play.
	for i in START_DELAY_FRAMES:
		await get_tree().process_frame
	if path != _requested:
		return  # another track was asked for meanwhile
	var keep: AudioStreamPlayer = _player_with(path)
	if keep != null:
		# back to a track that is still playing (it was fading out, or A -> B -> A before B started)
		_active = keep
	else:
		_active = _start_player(path)
	_crossfade()

## The track last asked for ("" after stop_all).
func current_track() -> String:
	return _requested

## The player playing (or fading in) the current track; null when it is silent.
func active_player() -> AudioStreamPlayer:
	return _active

## Players still audible, active one included (tests).
func player_count() -> int:
	return _players.size()

## Pause menu open (true) or closed (false): fades the softening in or out over pause_fade_time.
## Runs while the tree is paused. The two effects are enabled before the fade-in and disabled
## again after the fade-out, so outside the pause they cost nothing and change nothing.
func set_pause_softened(on: bool) -> void:
	if not _mix.pause_ok() or not _find_soft_effects():
		return  # the problem was reported once; music stays as it is
	if not on and not is_pause_softened():
		return  # nothing to undo
	if on and not is_pause_softened():
		_apply_soft(0.0)  # enabled at "no change", so switching them on is inaudible
		_set_soft_enabled(true)
	if _soft_tween != null and _soft_tween.is_valid():
		_soft_tween.kill()
	_soft_tween = create_tween()
	_soft_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var target: float = 1.0 if on else 0.0
	# the remaining distance only, so a quick pause/resume does not jump
	var time: float = _mix.pause_fade_time * absf(target - _soft_amount)
	_soft_tween.tween_method(_apply_soft, _soft_amount, target, time)
	if not on:
		_soft_tween.tween_callback(clear_pause_softening)

## Turns the pause softening off at once (scene change, back to menu, restart, quit): values back to
## "no change", both effects disabled. Safe to call any time.
func clear_pause_softening() -> void:
	if _soft_tween != null and _soft_tween.is_valid():
		_soft_tween.kill()
	_soft_tween = null
	if not _find_soft_effects():
		_soft_amount = 0.0
		return
	_apply_soft(0.0)
	_set_soft_enabled(false)

## True while either pause effect is enabled on the Music bus (tests).
func is_pause_softened() -> bool:
	if not _find_soft_effects():
		return false
	var bus: int = AudioServer.get_bus_index(BUS)
	return AudioServer.is_bus_effect_enabled(bus, _soft_filter_index) 		or AudioServer.is_bus_effect_enabled(bus, _soft_amp_index)

# Looks up the two effects of default_bus_layout.tres by name (once; again only after a failure).
# False, with one warning, when the bus or either effect is missing.
func _find_soft_effects() -> bool:
	var bus: int = AudioServer.get_bus_index(BUS)
	if bus == -1:
		return false  # warned in _ready
	if _soft_filter != null and _soft_amp != null 			and _soft_filter_index < AudioServer.get_bus_effect_count(bus) 			and AudioServer.get_bus_effect(bus, _soft_filter_index) == _soft_filter 			and _soft_amp_index < AudioServer.get_bus_effect_count(bus) 			and AudioServer.get_bus_effect(bus, _soft_amp_index) == _soft_amp:
		return true
	_soft_filter = null
	_soft_amp = null
	for i in AudioServer.get_bus_effect_count(bus):
		var effect: AudioEffect = AudioServer.get_bus_effect(bus, i)
		if effect is AudioEffectLowPassFilter and effect.resource_name == PAUSE_LOWPASS:
			_soft_filter = effect as AudioEffectLowPassFilter
			_soft_filter_index = i
		elif effect is AudioEffectAmplify and effect.resource_name == PAUSE_AMPLIFY:
			_soft_amp = effect as AudioEffectAmplify
			_soft_amp_index = i
	if _soft_filter == null or _soft_amp == null:
		_soft_filter = null
		_soft_amp = null
		if not _warned_soft_missing:
			_warned_soft_missing = true
			push_warning("MusicPlayer: bus '%s' lacks the '%s' / '%s' effects (default_bus_layout.tres), the pause leaves the music alone"
				% [BUS, PAUSE_LOWPASS, PAUSE_AMPLIFY])
		return false
	return true

func _set_soft_enabled(on: bool) -> void:
	var bus: int = AudioServer.get_bus_index(BUS)
	AudioServer.set_bus_effect_enabled(bus, _soft_filter_index, on)
	AudioServer.set_bus_effect_enabled(bus, _soft_amp_index, on)

# cutoff moves on a log scale (as the ear hears it), the drop linearly in dB
func _apply_soft(amount: float) -> void:
	_soft_amount = amount
	if _soft_filter == null or _soft_amp == null:
		return
	var open: float = log(_mix.pause_lowpass_open_hz)
	var shut: float = log(_mix.pause_lowpass_cutoff_hz)
	_soft_filter.cutoff_hz = exp(lerpf(open, shut, amount))
	_soft_amp.volume_db = _mix.pause_volume_drop_db * amount

## Stops all music at once (before quitting; GameFlow.quit_game waits for the audio thread).
func stop_all() -> void:
	clear_pause_softening()
	_requested = ""
	_active = null
	if _tween != null and _tween.is_valid():
		_tween.kill()
	for player in _players.duplicate():
		_release(player)

func _exit_tree() -> void:
	stop_all()

func _player_with(path: String) -> AudioStreamPlayer:
	for player in _players:
		if _path_of[player] == path and player.playing:
			return player
	return null

# a new player at silence; null when the file cannot be loaded
func _start_player(path: String) -> AudioStreamPlayer:
	var stream: AudioStream = Sfx.load_stream(path)
	if stream == null:
		return null
	_set_loop(stream)
	_serial += 1
	var player := AudioStreamPlayer.new()
	player.name = "Track%d" % _serial
	player.bus = BUS
	player.stream = stream
	add_child(player)
	_players.append(player)
	_path_of[player] = path
	_track_db[player] = _mix.music_track_gain_db.get(path, 0.0)
	_set_gain(player, 0.0)
	player.play()
	starts += 1
	return player

# every player fades from where it is now: the active one up to full, the rest down to silence
func _crossfade() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	for player in _players:
		_fade_from[player] = _gain[player]
	_tween = create_tween()
	# keeps running while the tree is paused (the pause menu changes tracks too)
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_method(_apply_fade, 0.0, 1.0, maxf(_mix.music_fade_time, 0.0))
	_tween.tween_callback(_release_silent)

# equal power: sin / cos of the progress keep the summed loudness level through the fade
func _apply_fade(progress: float) -> void:
	var rise: float = sin(progress * PI * 0.5)
	var fall: float = cos(progress * PI * 0.5)
	for player in _players:
		var from: float = _fade_from.get(player, 0.0)
		if player == _active:
			_set_gain(player, from + (1.0 - from) * rise)
		else:
			_set_gain(player, from * fall)

func _set_gain(player: AudioStreamPlayer, gain: float) -> void:
	_gain[player] = gain
	if gain <= SILENT_GAIN:
		player.volume_db = linear_to_db(SILENT_GAIN) + _track_db[player]
	else:
		player.volume_db = linear_to_db(gain) + _track_db[player]

func _release_silent() -> void:
	for player in _players.duplicate():
		if player != _active and _gain[player] <= SILENT_GAIN:
			_release(player)

func _release(player: AudioStreamPlayer) -> void:
	player.stop()
	player.stream = null
	_players.erase(player)
	_gain.erase(player)
	_fade_from.erase(player)
	_track_db.erase(player)
	_path_of.erase(player)
	player.queue_free()

func _set_loop(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamWAV:
		# the music WAVs are imported with a forward loop; this only covers one that is not
		var wav: AudioStreamWAV = stream as AudioStreamWAV
		if wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			wav.loop_begin = 0
			wav.loop_end = int(wav.get_length() * wav.mix_rate)
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
