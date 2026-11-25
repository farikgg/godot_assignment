extends SceneTree
## Headless check of the audio setup. Run from the project folder:
##   Godot --headless --path . -s res://tests/test_audio.gd
## Nothing here listens to the sound (a headless run has no ears): it checks the mixer, the
## numbers and the state the code leaves behind. Uses user://test_audio_save.json.

const TEST_SAVE: String = "user://test_audio_save.json"
const LEVEL_1: String = "res://scenes/levels/level_1.tscn"
const MAIN_MENU: String = "res://scenes/main_menu.tscn"
## Already failed to load before this assignment (scripts/main.gd is missing, see DECISIONS).
const KNOWN_BROKEN: Array[String] = ["res://scenes/map.tscn"]
const RANDOMIZER_DIR: String = "res://assets/Audio/randomizers"
## Frames that let a scene change and its _ready run.
const SETTLE_FRAMES: int = 6
## linear_to_db(0.5) = -6.0206 dB.
const HALF_DB: float = -6.0206
const DB_TOLERANCE: float = 0.01
## The permanent pause effects on the Music bus (default_bus_layout.tres).
const PAUSE_LOWPASS: String = "Paused LowPass"
const PAUSE_AMPLIFY: String = "Paused Amplify"

var _failures: int = 0
var _music: Node
var _flow: Node
var _save: Node

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	_music = root.get_node("MusicPlayer")
	_flow = root.get_node("GameFlow")
	_save = root.get_node("SaveGame")
	_save.save_path = TEST_SAVE
	_test_mix()
	_test_bus_layout()
	_test_randomizers()
	_test_readme_sources()
	await _test_scene_players()
	_test_sliders()
	await _test_music()
	await _test_pause_softening()
	_music.stop_all()
	_flow.stop_all_sounds()
	print("Audio tests: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await create_timer(0.2).timeout
	DirAccess.remove_absolute(TEST_SAVE)
	quit(1 if _failures > 0 else 0)

func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   ", label)
	else:
		_failures += 1
		print("  FAIL ", label)

func _frames(count: int) -> void:
	for i in count:
		await process_frame

func _wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout

# --- mix resource ----------------------------------------------------------------------------

func _test_mix() -> void:
	print("audio_mix.tres")
	var mix: AudioMix = load(AudioMix.PATH) as AudioMix
	_check(mix != null, "resources/audio_mix.tres loads as AudioMix")
	if mix != null:
		_check(mix.validate().is_empty(), "AudioMix validates (%s)" % ", ".join(mix.validate()))

# --- buses -----------------------------------------------------------------------------------

func _test_bus_layout() -> void:
	print("bus layout")
	var music: int = AudioServer.get_bus_index(&"Music")
	var sfx: int = AudioServer.get_bus_index(&"SFX")
	_check(AudioServer.get_bus_name(0) == "Master", "bus 0 is Master")
	_check(music > 0 and sfx > 0, "Music and SFX buses exist")
	if music > 0 and sfx > 0:
		_check(AudioServer.get_bus_send(music) == &"Master", "Music sends to Master")
		_check(AudioServer.get_bus_send(sfx) == &"Master", "SFX sends to Master")

func _test_randomizers() -> void:
	print("variation")
	var mix: AudioMix = AudioMix.get_mix()
	for file in DirAccess.get_files_at(RANDOMIZER_DIR):
		if not file.ends_with(".tres"):
			continue
		var rnd: AudioStreamRandomizer = load(RANDOMIZER_DIR + "/" + file) as AudioStreamRandomizer
		_check(rnd != null and is_equal_approx(rnd.random_pitch, mix.random_pitch),
			"%s random_pitch = %.2f" % [file, mix.random_pitch])
	var low: float = 1.0 / mix.random_pitch
	_check(low < 0.93 and mix.random_pitch > 1.07, "pitch range %.3f .. %.3f is about +-8 %%" % [low, mix.random_pitch])

# every recording under assets/Audio is named in the README "Audio sources" section
func _test_readme_sources() -> void:
	print("README audio sources")
	var readme: String = FileAccess.get_file_as_string("res://README.md")
	var start: int = readme.find("## Audio sources")
	_check(start != -1, "README has an Audio sources section")
	if start == -1:
		return
	var end: int = readme.find("
## ", start + 1)
	var section: String = readme.substr(start, end - start if end != -1 else -1)
	var files: Array[String] = []
	_collect_audio("res://assets/Audio", files)
	for path in files:
		_check(section.contains(path.get_file().get_basename()), "README lists %s" % path.trim_prefix("res://"))

func _collect_audio(dir: String, out: Array[String]) -> void:
	for file in DirAccess.get_files_at(dir):
		if file.get_extension() in ["wav", "ogg", "mp3"]:
			out.append(dir + "/" + file)
	for sub in DirAccess.get_directories_at(dir):
		_collect_audio(dir + "/" + sub, out)

# every AudioStreamPlayer / 3D in every scene (and the ones the game creates in level 1) is on
# Music or SFX, never on Master
func _test_scene_players() -> void:
	print("routing")
	var scenes: Array[String] = []
	_collect_scenes("res://scenes", scenes)
	var checked: int = 0
	for path in scenes:
		if KNOWN_BROKEN.has(path):
			continue
		var packed: PackedScene = load(path) as PackedScene
		if packed == null:
			_check(false, "%s loads" % path)
			continue
		var state: SceneState = packed.get_state()
		for i in state.get_node_count():
			var type: StringName = state.get_node_type(i)
			if type != &"AudioStreamPlayer" and type != &"AudioStreamPlayer3D" and type != &"AudioStreamPlayer2D":
				continue
			checked += 1
			var bus: StringName = &"Master"
			for p in state.get_node_property_count(i):
				if state.get_node_property_name(i, p) == &"bus":
					bus = state.get_node_property_value(i, p)
			_check(bus == &"SFX" or bus == &"Music", "%s:%s on %s" % [path.get_file(), state.get_node_name(i), bus])
	_check(checked > 0, "found %d players in scenes" % checked)
	# the players made at runtime (Sfx.play, MusicPlayer) only exist in a running level
	change_scene_to_file(LEVEL_1)
	await _frames(SETTLE_FRAMES)
	var hero: Node3D = get_first_node_in_group("player") as Node3D
	Sfx.play(load("res://assets/Audio/randomizers/pickup.tres") as AudioStream, hero)
	Sfx.play_3d(load("res://assets/Audio/randomizers/enemy_windup.tres") as AudioStream, hero)
	var on_master: Array[String] = []
	for node in root.find_children("*", "AudioStreamPlayer", true, false):
		if (node as AudioStreamPlayer).bus == &"Master":
			on_master.append(str(node.get_path()))
	for node in root.find_children("*", "AudioStreamPlayer3D", true, false):
		if (node as AudioStreamPlayer3D).bus == &"Master":
			on_master.append(str(node.get_path()))
	_check(on_master.is_empty(), "no live player on Master in level 1 %s" % str(on_master))
	var listener: AudioListener3D = hero.get_node_or_null("HeroListener") as AudioListener3D
	_check(listener != null and listener.is_current(), "the hero's AudioListener3D is current")
	var mix: AudioMix = AudioMix.get_mix()
	for enemy in get_nodes_in_group("enemy"):
		var d: float = (enemy as Node3D).global_position.distance_to(listener.global_position)
		_check(d < mix.spatial_max_distance, "%s at %.1f m is inside the %.0f m hearing range" % [enemy.name, d, mix.spatial_max_distance])
	_flow.stop_all_sounds()

func _collect_scenes(dir: String, out: Array[String]) -> void:
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".tscn"):
			out.append(dir + "/" + file)
	for sub in DirAccess.get_directories_at(dir):
		_collect_scenes(dir + "/" + sub, out)

# --- sliders ---------------------------------------------------------------------------------

func _test_sliders() -> void:
	print("volume sliders")
	var music: int = AudioServer.get_bus_index(&"Music")
	var sfx: int = AudioServer.get_bus_index(&"SFX")
	var music_base: float = _save.get("_bus_base_db")[&"Music"]
	var sfx_base: float = _save.get("_bus_base_db")[&"SFX"]
	_save.set_music_volume(0.5)
	_check(absf(AudioServer.get_bus_volume_db(music) - (music_base + HALF_DB)) < DB_TOLERANCE,
		"music 0.5 -> %.2f dB (bus base %.1f %+.2f)" % [AudioServer.get_bus_volume_db(music), music_base, HALF_DB])
	_save.set_sfx_volume(0.5)
	_check(absf(AudioServer.get_bus_volume_db(sfx) - (sfx_base + HALF_DB)) < DB_TOLERANCE,
		"sfx 0.5 -> %.2f dB (about -6 dB)" % AudioServer.get_bus_volume_db(sfx))
	_save.set_sfx_volume(0.0)
	_check(AudioServer.is_bus_mute(sfx), "sfx 0 mutes the bus")
	_save.set_sfx_volume(1.0)
	_check(not AudioServer.is_bus_mute(sfx) and absf(AudioServer.get_bus_volume_db(sfx) - sfx_base) < DB_TOLERANCE,
		"sfx 1 -> unmuted at the bus base")
	# startup: SaveGame applies the saved volumes in its _ready, before MusicPlayer and UiSounds exist
	var order: Array[String] = []
	for prop in ProjectSettings.get_property_list():
		var name: String = prop["name"]
		if name.begins_with("autoload/"):
			order.append(name.trim_prefix("autoload/"))
	_check(order.find("SaveGame") != -1 and order.find("SaveGame") < order.find("MusicPlayer")
		and order.find("SaveGame") < order.find("UiSounds"), "SaveGame autoloads before MusicPlayer and UiSounds %s" % str(order))
	_save.set_music_volume(1.0)

# --- music -----------------------------------------------------------------------------------

func _test_music() -> void:
	print("music")
	var mix: AudioMix = AudioMix.get_mix()
	_music.stop_all()
	_music.play_menu()
	await _frames(MusicPlayerFrames.START)
	await _wait(mix.music_fade_time + 0.1)
	var menu_player: AudioStreamPlayer = _music.active_player()
	_check(menu_player != null and menu_player.playing, "menu track plays")
	var starts: int = _music.starts
	_music.play_menu()
	await _frames(MusicPlayerFrames.START)
	_check(_music.starts == starts and _music.active_player() == menu_player, "menu again: no restart")

	# menu -> level: two players mid-fade, equal power keeps the summed power near 1
	_music.play_level()
	await _frames(MusicPlayerFrames.START)
	await _wait(mix.music_fade_time * 0.5)
	_check(_music.player_count() == 2, "mid-crossfade: 2 players")
	var power: float = 0.0
	for player in _music.get("_players"):
		power += pow(_music.get("_gain")[player], 2.0)
	_check(power > 0.9 and power < 1.1, "mid-crossfade summed power %.2f (no dip)" % power)
	await _wait(mix.music_fade_time * 0.5 + 0.1)
	_check(_music.player_count() == 1, "after the fade the menu player is released")
	var level_player: AudioStreamPlayer = _music.active_player()
	var position: float = level_player.get_playback_position()
	starts = _music.starts

	# level reload and the next level ask for the same track
	_flow.call("register_level", LEVEL_1)
	change_scene_to_file(LEVEL_1)
	await _frames(SETTLE_FRAMES)
	_check(_music.starts == starts and _music.active_player() == level_player, "level reload: same player, no restart")
	_check(level_player.get_playback_position() >= position, "level reload: playback position kept going")

	# race: level -> menu -> level inside the start delay never touches the level player
	_music.play_menu()
	_music.play_level()
	await _frames(MusicPlayerFrames.START + 1)
	_check(_music.starts == starts and _music.active_player() == level_player, "level -> menu -> level at once: no restart")

	# back to a track that is still fading out: it is picked up, not restarted
	_music.play_menu()
	await _frames(MusicPlayerFrames.START)
	await _wait(mix.music_fade_time * 0.3)
	starts = _music.starts
	_music.play_level()
	await _frames(MusicPlayerFrames.START)
	_check(_music.starts == starts and _music.active_player() == level_player, "level picked up while fading out, no restart")
	await _wait(mix.music_fade_time + 0.1)
	_check(_music.player_count() == 1 and _music.get("_gain")[level_player] > 0.99, "level back at full gain, menu released")

	# a missing file fades to silence instead of failing
	_music.play_track("res://assets/Audio/does_not_exist.ogg")
	await _frames(MusicPlayerFrames.START)
	await _wait(mix.music_fade_time + 0.1)
	_check(_music.active_player() == null and _music.player_count() == 0, "missing track: silence, players released")
	_music.stop_all()

# --- pause -----------------------------------------------------------------------------------

func _test_pause_softening() -> void:
	print("pause softening")
	var mix: AudioMix = AudioMix.get_mix()
	var bus: int = AudioServer.get_bus_index(&"Music")
	var filter_index: int = _effect_index(bus, PAUSE_LOWPASS)
	var amp_index: int = _effect_index(bus, PAUSE_AMPLIFY)
	_check(filter_index != -1 and AudioServer.get_bus_effect(bus, filter_index) is AudioEffectLowPassFilter,
		"bus layout: Music has '%s' (low-pass)" % PAUSE_LOWPASS)
	_check(amp_index != -1 and AudioServer.get_bus_effect(bus, amp_index) is AudioEffectAmplify,
		"bus layout: Music has '%s' (Amplify)" % PAUSE_AMPLIFY)
	if filter_index == -1 or amp_index == -1:
		return
	var base_effects: int = AudioServer.get_bus_effect_count(bus)
	_check(_pause_effects_off(bus, filter_index, amp_index), "pause effects disabled by default")
	var filter: AudioEffectLowPassFilter = AudioServer.get_bus_effect(bus, filter_index)
	var amp: AudioEffectAmplify = AudioServer.get_bus_effect(bus, amp_index)

	var menu: CanvasLayer = await _open_level_and_pause()
	_check(paused and _music.is_pause_softened() and AudioServer.is_bus_effect_enabled(bus, filter_index)
		and AudioServer.is_bus_effect_enabled(bus, amp_index), "pause: both effects enabled")
	_check(AudioServer.get_bus_effect_count(bus) == base_effects, "pause: no effect added (still %d)" % base_effects)
	await _wait(mix.pause_fade_time * 0.5)
	var halfway: float = filter.cutoff_hz
	_check(halfway < mix.pause_lowpass_open_hz * 0.9 and halfway > mix.pause_lowpass_cutoff_hz * 1.1,
		"tween runs while paused: cutoff %.0f Hz halfway" % halfway)
	await _wait(mix.pause_fade_time * 0.5 + 0.1)
	_check(absf(filter.cutoff_hz - mix.pause_lowpass_cutoff_hz) < 1.0 and is_equal_approx(amp.volume_db, mix.pause_volume_drop_db),
		"fully softened: %.0f Hz, %.1f dB" % [filter.cutoff_hz, amp.volume_db])

	# resume: fades back, then both are disabled at "no change"
	menu.call("set_paused", false)
	await _wait(mix.pause_fade_time + 0.1)
	_check(not paused and _pause_effects_off(bus, filter_index, amp_index), "resume: effects disabled")
	_check(absf(filter.cutoff_hz - mix.pause_lowpass_open_hz) < 1.0 and is_zero_approx(amp.volume_db),
		"resume: values back to %.0f Hz, 0 dB" % mix.pause_lowpass_open_hz)

	# quick toggling ends disabled and never changes the bus
	for i in 4:
		menu.call("set_paused", i % 2 == 0)
		await _frames(2)
	menu.call("set_paused", false)
	await _wait(mix.pause_fade_time + 0.1)
	_check(_pause_effects_off(bus, filter_index, amp_index) and AudioServer.get_bus_effect_count(bus) == base_effects,
		"pause/resume x4: effects disabled, bus unchanged")

	# every way out of a paused level
	await _open_level_and_pause()
	_flow.restart_level()
	await _frames(SETTLE_FRAMES)
	_check(_pause_effects_off(bus, filter_index, amp_index), "restart: effects disabled")
	await _open_level_and_pause()
	_flow.go_to_menu()
	await _frames(SETTLE_FRAMES)
	_check(_pause_effects_off(bus, filter_index, amp_index), "back to menu: effects disabled")
	await _open_level_and_pause()
	paused = false
	change_scene_to_file(MAIN_MENU)  # bypasses GameFlow: the pause menu's _exit_tree cleans up
	await _frames(SETTLE_FRAMES)
	_check(_pause_effects_off(bus, filter_index, amp_index), "plain scene change: effects disabled")
	# quit: GameFlow.quit_game calls MusicPlayer.stop_all (the real quit would end this test)
	await _open_level_and_pause()
	_music.stop_all()
	_check(_pause_effects_off(bus, filter_index, amp_index), "quit path (stop_all): effects disabled")
	_check(AudioServer.get_bus_effect_count(bus) == base_effects, "bus never gained or lost an effect")
	paused = false

# index of the Music bus effect with this resource name, -1 when absent
func _effect_index(bus: int, effect_name: String) -> int:
	if bus == -1:
		return -1
	for i in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus, i).resource_name == effect_name:
			return i
	return -1

# both pause effects disabled, and MusicPlayer agrees
func _pause_effects_off(bus: int, filter_index: int, amp_index: int) -> bool:
	return not AudioServer.is_bus_effect_enabled(bus, filter_index) 		and not AudioServer.is_bus_effect_enabled(bus, amp_index) and not _music.is_pause_softened()

# loads level 1, opens its pause menu and returns it
func _open_level_and_pause() -> CanvasLayer:
	_flow.call("register_level", LEVEL_1)
	change_scene_to_file(LEVEL_1)
	await _frames(SETTLE_FRAMES)
	var menu: CanvasLayer = null
	for node in current_scene.find_children("*", "CanvasLayer", true, false):
		if node.has_method("set_paused"):
			menu = node as CanvasLayer
	if menu == null:
		_check(false, "level 1 has a pause menu")
		return null
	menu.call("set_paused", true)
	await _frames(1)
	return menu

class MusicPlayerFrames:
	## MusicPlayer.START_DELAY_FRAMES plus one for the tween to start.
	const START: int = 3
