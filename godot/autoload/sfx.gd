extends Node
## Sons placeholders synthétisés (aucun fichier audio) : clic, achat, cloche, klaxon, palier, pièce, erreur.

const RATE := 22050

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last: Dictionary = {}
var _sea_player: AudioStreamPlayer
var _next_gull := 10.0


func _ready() -> void:
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_streams["click"] = _tone([[900.0, 0.035]], 0.25, "sine")
	_streams["buy"] = _tone([[523.0, 0.06], [659.0, 0.06], [784.0, 0.1]], 0.3, "triangle")
	_streams["coin"] = _tone([[988.0, 0.05], [1319.0, 0.12]], 0.22, "square")
	_streams["bell"] = _bell(880.0, 0.9)
	_streams["horn"] = _tone([[196.0, 0.18], [0.0, 0.05], [196.0, 0.25]], 0.25, "square")
	_streams["tier"] = _tone([[523.0, 0.09], [659.0, 0.09], [784.0, 0.09], [1047.0, 0.09], [784.0, 0.06], [1047.0, 0.35]], 0.3, "triangle")
	_streams["bad"] = _tone([[392.0, 0.1], [311.0, 0.22]], 0.25, "square")
	# ambiance : horn de navire, claquement de grue, klaxon de camion, mouettes
	_streams["ship_horn"] = _horn(98.0, 1.1)
	_streams["clank"] = _clank()
	_streams["truck_honk"] = _tone([[420.0, 0.12], [0.0, 0.05], [420.0, 0.18]], 0.12, "square")
	_streams["gull"] = _gull()
	# mer en boucle, très basse
	_sea_player = AudioStreamPlayer.new()
	_sea_player.stream = _sea()
	_sea_player.volume_db = -17.0
	add_child(_sea_player)
	Settings.changed.connect(_apply_mute)
	_apply_mute()
	_next_gull = randf_range(6.0, 14.0)


func _apply_mute() -> void:
	if Settings.muted:
		_sea_player.stop()
	elif not _sea_player.playing:
		_sea_player.play()


func _process(delta: float) -> void:
	if Settings.muted:
		return
	_next_gull -= delta
	if _next_gull <= 0.0:
		_next_gull = randf_range(9.0, 24.0)
		play("gull", 1.0)


func play(name: String, min_gap: float = 0.05) -> void:
	if Settings.muted or not _streams.has(name):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last.get(name, -10.0)) < min_gap:
		return
	_last[name] = now
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[name]
	p.play()


func _wave(kind: String, ph: float) -> float:
	match kind:
		"square":
			return 0.6 if fmod(ph, 1.0) < 0.5 else -0.6
		"triangle":
			return 4.0 * absf(fmod(ph, 1.0) - 0.5) - 1.0
	return sin(ph * TAU)


func _tone(notes: Array, vol: float, kind: String) -> AudioStreamWAV:
	var data := PackedByteArray()
	for n in notes:
		var f: float = n[0]
		var d: float = n[1]
		var count := int(d * RATE)
		var ph := 0.0
		for i in count:
			var env := minf(1.0, i / (RATE * 0.004)) * (1.0 - float(i) / count)
			var s := 0.0 if f <= 0.0 else _wave(kind, ph) * env * vol
			ph += f / RATE
			var v := clampi(int(s * 32767.0), -32768, 32767)
			data.append(v & 0xFF)
			data.append((v >> 8) & 0xFF)
	return _wav(data)


func _bell(f: float, d: float) -> AudioStreamWAV:
	var data := PackedByteArray()
	var count := int(d * RATE)
	for i in count:
		var t := float(i) / RATE
		var env := exp(-t * 5.0) * minf(1.0, i / (RATE * 0.003))
		var s := (sin(TAU * f * t) + 0.5 * sin(TAU * f * 2.01 * t) + 0.25 * sin(TAU * f * 3.02 * t)) * 0.18 * env
		var v := clampi(int(s * 32767.0), -32768, 32767)
		data.append(v & 0xFF)
		data.append((v >> 8) & 0xFF)
	return _wav(data)


## Corne de navire : fondamentale grave + harmoniques, attaque douce, extinction lente.
func _horn(f: float, d: float) -> AudioStreamWAV:
	var data := PackedByteArray()
	var count := int(d * RATE)
	for i in count:
		var t := float(i) / RATE
		var env := minf(1.0, t / 0.08) * pow(1.0 - t / d, 1.4)
		var s := (sin(TAU * f * t) + 0.55 * sin(TAU * f * 2.0 * t) + 0.3 * sin(TAU * f * 3.01 * t) + 0.12 * sin(TAU * f * 5.0 * t)) * 0.2 * env
		var v := clampi(int(s * 32767.0), -32768, 32767)
		data.append(v & 0xFF)
		data.append((v >> 8) & 0xFF)
	return _wav(data)


## Claquement de conteneur posé : bruit court + coup grave.
func _clank() -> AudioStreamWAV:
	var data := PackedByteArray()
	var count := int(0.16 * RATE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in count:
		var t := float(i) / RATE
		var env := exp(-t * 28.0)
		var s := (rng.randf_range(-1.0, 1.0) * 0.5 + sin(TAU * 140.0 * t) * 0.8 + sin(TAU * 310.0 * t) * 0.3) * 0.22 * env
		var v := clampi(int(s * 32767.0), -32768, 32767)
		data.append(v & 0xFF)
		data.append((v >> 8) & 0xFF)
	return _wav(data)


## Mouette : deux glissandos descendants avec vibrato.
func _gull() -> AudioStreamWAV:
	var data := PackedByteArray()
	var count := int(0.62 * RATE)
	var ph := 0.0
	for i in count:
		var t := float(i) / RATE
		var seg := fmod(t, 0.28)
		var active := t < 0.56 and seg < 0.2
		var f := lerpf(2100.0, 1250.0, seg / 0.2) * (1.0 + 0.03 * sin(TAU * 38.0 * t))
		ph += f / RATE
		var env := (sin(PI * seg / 0.2)) if active else 0.0
		var s := (sin(TAU * ph) + 0.4 * sin(TAU * ph * 2.0)) * 0.10 * env
		var v := clampi(int(s * 32767.0), -32768, 32767)
		data.append(v & 0xFF)
		data.append((v >> 8) & 0xFF)
	return _wav(data)


## Houle : bruit filtré dont l'amplitude gonfle et retombe, bouclé sans raccord (fondu enchaîné).
func _sea() -> AudioStreamWAV:
	var n := int(8.0 * RATE)
	var fade := int(0.8 * RATE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var raw := PackedFloat32Array()
	raw.resize(n + fade)
	var lp := 0.0
	var lp2 := 0.0
	for i in n + fade:
		var white := rng.randf_range(-1.0, 1.0)
		lp += (white - lp) * 0.06
		lp2 += (lp - lp2) * 0.25
		raw[i] = lp2
	var data := PackedByteArray()
	for i in n:
		var t := float(i) / RATE
		var swell := 0.55 + 0.45 * sin(TAU * t / 8.0 * 1.0) * sin(TAU * t / 8.0 * 2.0 + 0.7)
		var x := raw[i]
		if i < fade:                                     # début : fondu avec la queue du bruit
			var k := float(i) / fade
			x = raw[i] * k + raw[n + i] * (1.0 - k)
		var s := x * 3.2 * swell
		var v := clampi(int(s * 32767.0 * 0.5), -32768, 32767)
		data.append(v & 0xFF)
		data.append((v >> 8) & 0xFF)
	var w := _wav(data)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w


func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
