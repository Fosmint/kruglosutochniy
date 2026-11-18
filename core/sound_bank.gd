extends Node

## Autoload SoundBank (без class_name)
## Полностью процедурная генерация всех звуков в AudioStreamWAV (16-bit mono, 22050 Hz)

const MIX_RATE: int = 22050

signal generation_finished()

var _cache: Dictionary = {}
var _is_ready: bool = false
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_idx: int = 0
var _voice_player: AudioStreamPlayer = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 19981119
	_setup_buses()
	_setup_players()
	generate_all()
	apply_volumes()


func _setup_buses() -> void:
	_ensure_bus("SFX")
	_ensure_bus("Ambience")
	_ensure_bus("Voice")


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	var idx: int = AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


func _setup_players() -> void:
	for i in range(8):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_pool.append(p)
	_voice_player = AudioStreamPlayer.new()
	_voice_player.bus = "Voice"
	add_child(_voice_player)


func apply_volumes() -> void:
	_set_bus_linear("Master", SaveSystem.vol_master)
	_set_bus_linear("SFX", SaveSystem.vol_sfx)
	_set_bus_linear("Ambience", SaveSystem.vol_ambience)
	_set_bus_linear("Voice", SaveSystem.vol_voice)


func _set_bus_linear(bus_name: String, lin: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	if lin <= 0.001:
		AudioServer.set_bus_mute(idx, true)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(lin))


func is_bank_ready() -> bool:
	return _is_ready


func get_stream(sound_id: String) -> AudioStreamWAV:
	if _cache.has(sound_id):
		return _cache[sound_id] as AudioStreamWAV
	return null


func play_sfx(sound_id: String, pitch_scale: float = 1.0, volume_db: float = 0.0) -> void:
	var stream: AudioStreamWAV = get_stream(sound_id)
	if stream == null:
		return
	var p: AudioStreamPlayer = _sfx_pool[_sfx_idx]
	_sfx_idx = (_sfx_idx + 1) % _sfx_pool.size()
	p.stream = stream
	p.pitch_scale = clampf(pitch_scale, 0.35, 2.5)
	p.volume_db = volume_db
	p.play()


func play_voice_blip(pitch_scale: float = 1.0, volume_db: float = -4.0) -> void:
	var stream: AudioStreamWAV = get_stream("voice_blip")
	if stream == null or _voice_player == null:
		return
	_voice_player.stream = stream
	_voice_player.pitch_scale = clampf(pitch_scale, 0.45, 2.2)
	_voice_player.volume_db = volume_db
	_voice_player.play()


func generate_all() -> void:
	if _is_ready:
		return
	_cache["fluorescent_hum"] = _gen_fluorescent_hum()
	_cache["fridge_hum"] = _gen_fridge_hum()
	_cache["door_bell"] = _gen_door_bell()
	_cache["scanner_beep"] = _gen_scanner_beep()
	_cache["coin_clink"] = _gen_coin_clink()
	_cache["cash_register"] = _gen_cash_register()
	_cache["footstep"] = _gen_footstep()
	_cache["voice_blip"] = _gen_voice_blip()
	_cache["whisper"] = _gen_whisper()
	_cache["heartbeat"] = _gen_heartbeat()
	_cache["vhs_hiss"] = _gen_vhs_hiss()
	_cache["stinger"] = _gen_stinger()
	_cache["static_burst"] = _gen_static_burst()
	_cache["ui_click"] = _gen_ui_click()
	_cache["jingle_win"] = _gen_jingle_win()
	_cache["jingle_fail"] = _gen_jingle_fail()
	_cache["tension_drone"] = _gen_tension_drone()
	_cache["road_ambience"] = _gen_road_ambience()
	_cache["alarm_siren"] = _gen_alarm_siren()
	_cache["power_down"] = _gen_power_down()
	_is_ready = true
	generation_finished.emit()


func _make_wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var count: int = samples.size()
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(count * 2)
	for i in range(count):
		var v: int = clampi(int(samples[i] * 32767.0), -32768, 32767)
		bytes.encode_s16(i * 2, v)
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = count
	else:
		wav.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return wav


func _gen_fluorescent_hum() -> AudioStreamWAV:
	var n: int = int(MIX_RATE * 2.5)
	var s: PackedFloat32Array = PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t: float = float(i) / float(MIX_RATE)
		var base: float = sin(TAU * 50.0 * t) * 0.25 + sin(TAU * 100.0 * t) * 0.18 + sin(TAU * 150.0 * t) * 0.08
		var flicker: float = 1.0
		if (t > 1.1 and t < 1.18) or (t > 1.24 and t < 1.29):
			flicker = 0.35 + _rng.randf() * 0.6
		s[i] = (base + (_rng.randf() * 2.0 - 1.0) * 0.025) * 0.35 * flicker
	return _make_wav(s, true)


func _gen_fridge_hum() -> AudioStreamWAV:
	var n: int = int(MIX_RATE * 3.0)
	var s: PackedFloat32Array = PackedFloat32Array()
	s.resize(n)
	var lp: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(MIX_RATE)
		var raw: float = sin(TAU * 58.0 * t) * 0.35 + sin(TAU * 116.0 * t) * 0.2 + (_rng.randf() * 2.0 - 1.0) * 0.08
		lp = lp * 0.88 + raw * 0.12
		s[i] = lp * 0.45
	return _make_wav(s, true)


func _gen_door_bell() -> AudioStreamWAV:
	var n: int = int(MIX_RATE * 0.85)
	var s: PackedFloat32Array = PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t: float = float(i) / float(MIX_RATE)
		var env1: float = exp(-t * 5.2)
		var env2: float = 0.0
		if t > 0.18:
			env2 = exp(-(t - 0.18) * 4.5)
		var tone1: float = (sin(TAU * 1318.0 * t) + 0.4 * sin(TAU * 2636.0 * t)) * env1
		var tone2: float = (sin(TAU * 1046.0 * t) + 0.4 * sin(TAU * 2092.0 * t)) * env2
		s[i] = clampf((tone1 + tone2) * 0.38, -0.95, 0.95)
	return _make_wav(s, false)


func _gen_scanner_beep() -> AudioStreamWAV:
	var n: int = int(MIX_RATE * 0.085)
	var s: PackedFloat32Array = PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t: float = float(i) / float(MIX_RATE)
		var sq: float = 1.0 if sin(TAU * 1820.0 * t) >= 0.0 else -1.0
		var env: float = 1.0
		if i < 80:
			env = float(i) / 80.0
		elif i > n - 120:
			env = float(n - i) / 120.0
		s[i] = sq * env * 0.32
	return _make_wav(s, false)


func _gen_coin_clink() -> AudioStreamWAV:
	var n: int = int(MIX_RATE * 0.24)
	var s: PackedFloat32Array = PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t: float = float(i) / float(MIX_RATE)
		var env: float = exp(-t * 18.0)
		var v: float = sin(TAU * 3150.0 * t) * 0.5 + sin(TAU * 4720.0 * t) * 0.35 + sin(TAU * 6890.0 * t) * 0.2
		s[i] = v * env * 0.45
	return _make_wav(s, false)


func _gen_cash_register() -> AudioStreamWAV:
	var n: int = int(MIX_RATE * 0.50)
	var s: PackedFloat32Array = PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t: float = float(i) / float(MIX_RATE)
		var v: float = 0.0
		if t < 0.08:
			v = (_rng.randf() * 2.0 - 1.0) * exp(-t * 40.0) * 0.5
		else:
			var dt: float = t - 0.08
			var env: float = exp(-dt * 7.0)
			v = (sin(TAU * 2240.0 * dt) * 0.6 + sin(TAU * 4480.0 * dt) * 0.3 + sin(TAU * 6720.0 * dt) * 0.15) * env * 0.55
		s[i] = clampf(v, -0.95, 0.95)
	return _make_wav(s, false)


func _gen_footstep() -> AudioStreamWAV:
	var n: int = int(MIX_RATE * 0.14)
	var s: PackedFloat32Array = PackedFloat32Array()
	s.resize(n)
	var lp: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(MIX_RATE)
		var env: float = exp(-t * 28.0)
		var noise: float = _rng.randf() * 2.0 - 1.0
		lp = lp * 0.82 + noise * 0.18
		var thump: float = sin(TAU * (95.0 - t * 250.0) * t) * 0.45
		s[i] = (lp * 0.9 + thump) * env * 0.55
	return _make_wav(s, false)


func _gen_voice_blip() -> AudioStreamWAV:
	var n: int = int(MIX_RATE * 0.075)
	var s: PackedFloat32Array = PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t: float = float(i) / float(MIX_RATE)
		var env: float = sin(PI * float(i) / float(n))
		var v: float = sin(TAU * 185.0 * t) * 0.55 + sin(TAU * 370.0 * t) * 0.25 + sin(TAU * 555.0 * t) * 0.12
		s[i] = v * env * 0.45
	return _make_wav(s, false)


func _gen_whisper() -> AudioStreamWAV:
	var n: int = int(MIX_RATE * 1.4)
	var s: PackedFloat32Array = PackedFloat32Array()
	s.resize(n)
	var lp1: float = 0.0
	var lp2: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(MIX_RATE)
		var env: float = sin(PI * t / 1.4) * (0.65 + 0.35 * sin(TAU * 4.2 * t))
		var noise: float = _rng.randf() * 2.0 - 1.0
		lp1 = lp1 * 0.65 + noise * 0.35
		lp2 = lp2 * 0.92 + lp1 * 0.08
		var bp: float = lp1 - lp2
		s[i] = bp * env * 0.55
	return _make_wav(s, false)


func _gen_heartbeat() -> AudioStreamWAV:
	var n: int = int(MIX_RATE * 1.2)
	var s: PackedFloat32Array = PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t: float = float(i) / float(MIX_RATE)
		var v: float = 0.0
		if t < 0.22:
			v += sin(TAU * 52.0 * t) * exp(-t * 16.0) * 0.85
		if t > 0.26 and t < 0.50:
			var dt: float = t - 0.26
			v += sin(TAU * 45.0 * dt) * exp(-dt * 18.0) * 0.65
		s[i] = clampf(v, -0.95, 0.95)
	return _make_wav(s, true)


func _gen_vhs_hiss() -> AudioStreamWAV:
	var n: int = int(MIX_RATE * 2.5)
	var s: PackedFloat32Array = PackedFloat32Array()
	s.resize(n)
	var prev: float = 0.0
	for i in range(n):
		var noise: float = _rng.randf() * 2.0 - 1.0
		var hp: float = noise - prev * 0.65
		prev = noise
		s[i] = clampf(hp * 0.075, -0.5, 0.5)
	return _make_wav(s, true)


func _gen_stinger() -> AudioStreamWAV:
	var n: int = int(MIX_RATE * 1.25)
	var s: PackedFloat32Array = PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t: float = float(i) / float(MIX_RATE)
		var env: float = exp(-t * 2.4)
		var cluster: float = sin(TAU * 110.0 * t) + sin(TAU * 116.5 * t) + sin(TAU * 233.0 * t) + sin(TAU * 622.0 * t) * 0.5
		var noise: float = (_rng.randf() * 2.0 - 1.0) * exp(-t * 6.0) * 0.9
		s[i] = clampf((cluster * 0.22 + noise * 0.55) * env, -0.95, 0.95)
	return _make_wav(s, false)


func _gen_static_burst() -> AudioStreamWAV:
	var n: int = int(MIX_RATE * 0.65)
	var s: PackedFloat32Array = PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t: float = float(i) / float(MIX_RATE)
		var env: float = 1.0 - (t / 0.65)
		s[i] = (_rng.randf() * 2.0 - 1.0) * env * 0.45
	return _make_wav(s, false)


func _gen_ui_click() -> AudioStreamWAV:
	var n: int = int(MIX_RATE * 0.045)
	var s: PackedFloat32Array = PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t: float = float(i) / float(MIX_RATE)
		var env: float = exp(-t * 90.0)
		s[i] = (sin(TAU * 950.0 * t) * 0.6 + (_rng.randf() * 2.0 - 1.0) * 0.4) * env * 0.4
	return _make_wav(s, false)


func _gen_jingle_win() -> AudioStreamWAV:
	var n: int = int(MIX_RATE * 1.1)
	var s: PackedFloat32Array = PackedFloat32Array()
	s.resize(n)
	var notes: Array[float] = [523.25, 659.25, 783.99, 1046.5]
	for i in range(n):
		var t: float = float(i) / float(MIX_RATE)
		var idx: int = clampi(int(t / 0.22), 0, 3)
		var nt: float = t - float(idx) * 0.22
		var env: float = exp(-nt * 4.5)
		s[i] = (sin(TAU * notes[idx] * t) * 0.6 + sin(TAU * notes[idx] * 2.0 * t) * 0.15) * env * 0.42
	return _make_wav(s, false)


func _gen_jingle_fail() -> AudioStreamWAV:
	var n: int = int(MIX_RATE * 1.3)
	var s: PackedFloat32Array = PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t: float = float(i) / float(MIX_RATE)
		var freq: float = lerpf(240.0, 110.0, clampf(t / 1.1, 0.0, 1.0))
		var env: float = exp(-t * 1.8)
		s[i] = (sin(TAU * freq * t) * 0.5 + sin(TAU * (freq * 1.414) * t) * 0.35) * env * 0.45
	return _make_wav(s, false)


func _gen_tension_drone() -> AudioStreamWAV:
	var n: int = int(MIX_RATE * 3.5)
	var s: PackedFloat32Array = PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t: float = float(i) / float(MIX_RATE)
		var mod: float = 0.75 + 0.25 * sin(TAU * (1.0 / 3.5) * t)
		var v: float = sin(TAU * 46.0 * t) * 0.5 + sin(TAU * 47.4 * t) * 0.35 + sin(TAU * 69.0 * t) * 0.2
		s[i] = v * mod * 0.38
	return _make_wav(s, true)


func _gen_road_ambience() -> AudioStreamWAV:
	var n: int = int(MIX_RATE * 4.0)
	var s: PackedFloat32Array = PackedFloat32Array()
	s.resize(n)
	var lp: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(MIX_RATE)
		var swell: float = 0.65 + 0.35 * sin(TAU * (1.0 / 4.0) * t)
		var noise: float = _rng.randf() * 2.0 - 1.0
		lp = lp * 0.94 + noise * 0.06
		s[i] = lp * swell * 0.32
	return _make_wav(s, true)


func _gen_alarm_siren() -> AudioStreamWAV:
	var n: int = int(MIX_RATE * 1.6)
	var s: PackedFloat32Array = PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t: float = float(i) / float(MIX_RATE)
		var freq: float = 880.0 if fmod(t, 0.4) < 0.2 else 660.0
		var sq: float = 1.0 if sin(TAU * freq * t) >= 0.0 else -1.0
		var env: float = 1.0 - maxf(0.0, (t - 1.3) / 0.3)
		s[i] = sq * env * 0.30
	return _make_wav(s, false)


func _gen_power_down() -> AudioStreamWAV:
	var n: int = int(MIX_RATE * 0.9)
	var s: PackedFloat32Array = PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t: float = float(i) / float(MIX_RATE)
		var freq: float = lerpf(160.0, 28.0, t / 0.9)
		var env: float = exp(-t * 2.5)
		s[i] = (sin(TAU * freq * t) * 0.7 + (_rng.randf() * 2.0 - 1.0) * 0.15) * env * 0.55
	return _make_wav(s, false)
