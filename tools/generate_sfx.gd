extends SceneTree
## Writes the four synthesized effects that had no recording in assets/Audio (UI click, win, lose,
## enemy death) as 16-bit mono WAV files. Deterministic (fixed noise seed), so rerunning gives
## the same files. Run from the project folder:
##   Godot --headless --path . -s res://tools/generate_sfx.gd
## These are placeholders made in code for this project; swap in real recordings any time
## (keep the file names, or point the exports at the new files).

const OUT_DIR: String = "res://assets/Audio/generated"
const RATE: int = 44100
const PEAK: float = 0.7          # of full scale, leaves headroom before the mix table
const EDGE_FADE_SEC: float = 0.004  # fade-in/out on every file so no clip starts or ends with a click
const NOISE_SEED: int = 12

# note frequencies, Hz
const C5: float = 523.25
const E5: float = 659.25
const G5: float = 783.99
const C6: float = 1046.5
const G4: float = 392.0
const FS4: float = 369.99
const F4: float = 349.23
const E4: float = 329.63

var _rng := RandomNumberGenerator.new()

func _initialize() -> void:
	_rng.seed = NOISE_SEED
	var dir_error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	if dir_error != OK:
		push_error("generate_sfx: cannot create %s (%s)" % [OUT_DIR, error_string(dir_error)])
		quit(1)
		return
	var failures: int = 0
	failures += _write("ui_click.wav", _click())
	failures += _write("win.wav", _arpeggio([C5, E5, G5, C6], 0.11, 0.45))
	failures += _write("lose.wav", _arpeggio([G4, FS4, F4, E4], 0.22, 0.7))
	failures += _write("enemy_death.wav", _poof())
	quit(1 if failures > 0 else 0)

# 30 ms tick: a 1.8 kHz sine and a little noise, both decaying fast
func _click() -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	var count: int = int(0.03 * RATE)
	for i in count:
		var t: float = float(i) / RATE
		var env: float = exp(-t * 180.0)
		samples.append((sin(TAU * 1800.0 * t) * 0.8 + _rng.randf_range(-1.0, 1.0) * 0.2) * env)
	return samples

# soft chiptune notes (sine + a quiet 3rd harmonic); the last note rings longer
func _arpeggio(notes: Array[float], note_sec: float, last_sec: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	for n in notes.size():
		var length: float = last_sec if n == notes.size() - 1 else note_sec
		var count: int = int(length * RATE)
		for i in count:
			var t: float = float(i) / RATE
			var env: float = minf(t / 0.005, 1.0) * exp(-t * (3.0 / length))
			var f: float = notes[n]
			samples.append((sin(TAU * f * t) + 0.25 * sin(TAU * 3.0 * f * t)) * env)
	return samples

# 0.45 s: a falling 220 -> 60 Hz thump under filtered noise
func _poof() -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	var count: int = int(0.45 * RATE)
	var phase: float = 0.0
	var smooth: float = 0.0
	for i in count:
		var t: float = float(i) / RATE
		var f: float = lerpf(220.0, 60.0, minf(t / 0.3, 1.0))
		phase += TAU * f / RATE
		smooth = lerpf(smooth, _rng.randf_range(-1.0, 1.0), 0.15)  # one-pole low-pass on the noise
		var env: float = exp(-t * 9.0)
		samples.append((sin(phase) * 0.7 + smooth * 0.9) * env)
	return samples

func _write(file_name: String, samples: PackedFloat32Array) -> int:
	_normalize_and_fade(samples)
	var pcm := PackedByteArray()
	pcm.resize(samples.size() * 2)
	for i in samples.size():
		pcm.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var path: String = OUT_DIR + "/" + file_name
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("generate_sfx: cannot write %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return 1
	# RIFF/WAVE header, PCM, mono, 16 bit
	file.store_buffer("RIFF".to_ascii_buffer())
	file.store_32(36 + pcm.size())
	file.store_buffer("WAVEfmt ".to_ascii_buffer())
	file.store_32(16)
	file.store_16(1)
	file.store_16(1)
	file.store_32(RATE)
	file.store_32(RATE * 2)
	file.store_16(2)
	file.store_16(16)
	file.store_buffer("data".to_ascii_buffer())
	file.store_32(pcm.size())
	file.store_buffer(pcm)
	file.close()
	print("generate_sfx: %s (%.2f s)" % [path, float(samples.size()) / RATE])
	return 0

func _normalize_and_fade(samples: PackedFloat32Array) -> void:
	var peak: float = 0.0
	for s in samples:
		peak = maxf(peak, absf(s))
	var gain: float = PEAK / peak if peak > 0.0 else 0.0
	var fade: int = mini(int(EDGE_FADE_SEC * RATE), samples.size() / 2)
	for i in samples.size():
		var edge: float = 1.0
		if i < fade:
			edge = float(i) / fade
		elif i >= samples.size() - fade:
			edge = float(samples.size() - 1 - i) / fade
		samples[i] = samples[i] * gain * edge
