extends Node
## Sons synthétisés (aucun fichier audio). Lot D-UI :
## - sons distincts : clic, achat, pièce, cloche, klaxon, erreur, **construction**, **embauche**, **palier de niveau**
##   (milestone), **Heures sup**, **coffre** ; « tier » et les jingles « tier2 », « tier3 », « finale », « prestige » sont
##   réservés aux paliers du port ;
## - hauteur légèrement aléatoire (±4 %) à chaque lecture ; `step` monte d'autant de demi-tons (appui long : +1 toutes les
##   3 répétitions) ;
## - 10 voix avec priorité : la corne des navires et les jingles de palier ne sont jamais volés ; un son ne prend pas la voix
##   d'un son plus important (avant : 6 voix tournantes, volées par la grue) ;
## - deux bus, « Sons » et « Ambiance » (mer, mouettes, cornes, grues, camions), réglables dans Réglages (user://audio.cfg).

const RATE := 22050
const VOICES := 10
const AUDIO_CFG := "user://audio.cfg"
const BUS_SFX := "Sons"
const BUS_AMB := "Ambiance"
## Sons d'ambiance (bus « Ambiance ») ; tous les autres vont sur « Sons ».
const AMBIENT := ["ship_horn", "clank", "truck_honk", "gull"]
## Priorité : 3 = jamais volé ; un son ne prend que la voix d'un son de priorité inférieure ou égale.
const PRIORITY := {
	"ship_horn": 3, "tier": 3, "tier2": 3, "tier3": 3, "finale": 3, "prestige": 3,
	"milestone": 2, "build": 2, "hire": 2, "boost": 2, "chest": 2, "horn": 2, "bad": 2, "bell": 2,
	"buy": 1, "coin": 1, "click": 1,
	"clank": 0, "truck_honk": 0, "gull": 0,
}

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _prio: Array[int] = []
var _last: Dictionary = {}
var _sea_player: AudioStreamPlayer
var _next_gull := 10.0
var volumes := {BUS_SFX: 1.0, BUS_AMB: 0.8}
var played := 0                    # sons joués (tests)
var dropped := 0                   # sons abandonnés faute de voix (tests)


func _ready() -> void:
	_make_buses()
	_load_volumes()
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
		_prio.append(-1)
	_streams["click"] = _tone([[900.0, 0.035]], 0.25, "sine")
	_streams["buy"] = _tone([[523.0, 0.06], [659.0, 0.06], [784.0, 0.1]], 0.3, "triangle")
	_streams["coin"] = _tone([[988.0, 0.05], [1319.0, 0.12]], 0.22, "square")
	_streams["bell"] = _bell(880.0, 0.9)
	_streams["horn"] = _tone([[196.0, 0.18], [0.0, 0.05], [196.0, 0.25]], 0.25, "square")
	_streams["bad"] = _tone([[392.0, 0.1], [311.0, 0.22]], 0.25, "square")
	# moments distincts (lot D-UI) : « tier » ne sert plus qu'aux paliers du port
	_streams["build"] = _mix([_clank_data(), _tone_data([[0.0, 0.08], [392.0, 0.07], [523.0, 0.07], [659.0, 0.16]], 0.26, "triangle")])
	_streams["hire"] = _tone([[659.0, 0.08], [784.0, 0.08], [988.0, 0.2]], 0.26, "sine")
	_streams["milestone"] = _tone([[784.0, 0.06], [988.0, 0.06], [1175.0, 0.06], [1568.0, 0.22]], 0.26, "triangle")
	_streams["boost"] = _sweep(300.0, 1200.0, 0.45, 0.22)
	_streams["chest"] = _mix([_bell_data(1320.0, 0.8), _tone_data([[523.0, 0.08], [784.0, 0.08], [1047.0, 0.3]], 0.2, "triangle")])
	_streams["tier"] = _tone([[523.0, 0.09], [659.0, 0.09], [784.0, 0.09], [1047.0, 0.09], [784.0, 0.06], [1047.0, 0.35]], 0.3, "triangle")
	_streams["tier2"] = _tone([[392.0, 0.12], [523.0, 0.12], [659.0, 0.12], [784.0, 0.12], [659.0, 0.08], [784.0, 0.08], [1047.0, 0.5]], 0.3, "triangle")
	_streams["tier3"] = _tone([[440.0, 0.1], [554.0, 0.1], [659.0, 0.1], [880.0, 0.14], [0.0, 0.05], [880.0, 0.08], [1109.0, 0.08], [1319.0, 0.55]], 0.3, "triangle")
	_streams["finale"] = _mix([_tone_data([[523.0, 0.16], [659.0, 0.16], [784.0, 0.16], [1047.0, 0.24], [988.0, 0.12], [1047.0, 0.7]], 0.28, "triangle"), _bell_data(523.0, 1.6)])
	_streams["prestige"] = _mix([_tone_data([[349.0, 0.12], [440.0, 0.12], [523.0, 0.12], [698.0, 0.12], [880.0, 0.6]], 0.27, "triangle"), _bell_data(1047.0, 1.2)])
	# ambiance : horn de navire, claquement de grue, klaxon de camion, mouettes
	_streams["ship_horn"] = _horn(98.0, 1.1)
	_streams["clank"] = _clank()
	_streams["truck_honk"] = _tone([[420.0, 0.12], [0.0, 0.05], [420.0, 0.18]], 0.12, "square")
	_streams["gull"] = _gull()
	# mer en boucle, très basse
	_sea_player = AudioStreamPlayer.new()
	_sea_player.stream = _sea()
	_sea_player.volume_db = -17.0
	_sea_player.bus = BUS_AMB
	add_child(_sea_player)
	Settings.changed.connect(_apply_mute)
	_apply_mute()
	_next_gull = randf_range(6.0, 14.0)


func _make_buses() -> void:
	for b in [BUS_SFX, BUS_AMB]:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")


func _load_volumes() -> void:
	var cf := ConfigFile.new()
	if cf.load(AUDIO_CFG) == OK:
		for b in volumes.keys():
			volumes[b] = clampf(float(cf.get_value("volume", b, volumes[b])), 0.0, 1.0)
	for b in volumes.keys():
		_apply_volume(b)


## Volume d'un bus (0 à 1). `save` : écrit aussi `user://audio.cfg` — lot E : Réglages n'écrit qu'au relâchement de la
## réglette (`save_volumes`), plus à chaque cran.
func set_volume(bus: String, v: float, save: bool = true) -> void:
	volumes[bus] = clampf(v, 0.0, 1.0)
	_apply_volume(bus)
	_dirty = true
	if save:
		save_volumes()


## Écrit les volumes s'ils ont changé (rien si `persist` est faux : tests).
func save_volumes() -> void:
	if not _dirty:
		return
	_dirty = false
	saves += 1
	if not persist:
		return
	var cf := ConfigFile.new()
	for b in volumes.keys():
		cf.set_value("volume", b, volumes[b])
	cf.save(AUDIO_CFG)


var persist := true                # faux pendant les tests : `user://audio.cfg` du joueur n'est jamais réécrit
var saves := 0                     # enregistrements des volumes (tests ; avec `persist` faux, rien n'est écrit)
var _dirty := false


func get_volume(bus: String) -> float:
	return float(volumes.get(bus, 1.0))


func _apply_volume(bus: String) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		return
	var v := float(volumes[bus])
	AudioServer.set_bus_mute(i, v <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.001)))


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


## Joue un son. `min_gap` : pas deux fois le même en moins de `min_gap` s ; `step` : demi-tons de plus (appui long).
func play(name: String, min_gap: float = 0.05, step: int = 0) -> void:
	if Settings.muted or not _streams.has(name):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last.get(name, -10.0)) < min_gap:
		return
	var pr := int(PRIORITY.get(name, 1))
	var vi := _voice_for(pr)
	if vi < 0:
		dropped += 1
		return
	_last[name] = now
	var p := _players[vi]
	p.stream = _streams[name]
	p.bus = BUS_AMB if AMBIENT.has(name) else BUS_SFX
	p.pitch_scale = pow(2.0, float(step) / 12.0) * randf_range(0.96, 1.04)
	_prio[vi] = pr
	p.play()
	played += 1


## Voix libre, sinon celle du son en cours le moins prioritaire (jamais une voix de priorité 3, jamais celle d'un son plus
## prioritaire que le nouveau), -1 s'il n'y en a pas.
func _voice_for(pr: int) -> int:
	var busy: Array[bool] = []
	for p in _players:
		busy.append(p.playing)
	return pick_voice(_prio, busy, pr)


## Règle de vol des voix, sans lecteur audio (testable : lot E, le contrôle des priorités vérifie vraiment la règle) :
## une voix libre, sinon celle du son en cours le moins prioritaire, jamais une voix de priorité 3 ni un son plus prioritaire.
static func pick_voice(prio: Array[int], busy: Array[bool], pr: int) -> int:
	var best := -1
	var best_pr := 99
	for i in prio.size():
		if not busy[i]:
			return i
		var q := prio[i]
		if q < 3 and q <= pr and q < best_pr:
			best = i
			best_pr = q
	return best


## Son en cours sur une voix (tests) : -1 si elle est libre.
func voice_priority(i: int) -> int:
	return _prio[i] if _players[i].playing else -1


func _wave(kind: String, ph: float) -> float:
	match kind:
		"square":
			return 0.6 if fmod(ph, 1.0) < 0.5 else -0.6
		"triangle":
			return 4.0 * absf(fmod(ph, 1.0) - 0.5) - 1.0
	return sin(ph * TAU)


func _tone(notes: Array, vol: float, kind: String) -> AudioStreamWAV:
	return _to_wav(_tone_data(notes, vol, kind))


func _tone_data(notes: Array, vol: float, kind: String) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for n in notes:
		var f: float = n[0]
		var d: float = n[1]
		var count := int(d * RATE)
		var ph := 0.0
		for i in count:
			var env := minf(1.0, i / (RATE * 0.004)) * (1.0 - float(i) / count)
			out.append(0.0 if f <= 0.0 else _wave(kind, ph) * env * vol)
			ph += f / RATE
	return out


func _bell(f: float, d: float) -> AudioStreamWAV:
	var out := PackedFloat32Array()
	var count := int(d * RATE)
	for i in count:
		var t := float(i) / RATE
		var env := exp(-t * 5.0) * minf(1.0, i / (RATE * 0.003))
		out.append((sin(TAU * f * t) + 0.5 * sin(TAU * f * 2.01 * t) + 0.25 * sin(TAU * f * 3.02 * t)) * 0.18 * env)
	return _to_wav(out)


func _bell_data(f: float, d: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var count := int(d * RATE)
	for i in count:
		var t := float(i) / RATE
		var env := exp(-t * 4.0) * minf(1.0, i / (RATE * 0.003))
		out.append((sin(TAU * f * t) + 0.5 * sin(TAU * f * 2.01 * t) + 0.25 * sin(TAU * f * 3.02 * t)) * 0.16 * env)
	return out


## Corne de navire : fondamentale grave + harmoniques, attaque douce, extinction lente.
func _horn(f: float, d: float) -> AudioStreamWAV:
	var out := PackedFloat32Array()
	var count := int(d * RATE)
	for i in count:
		var t := float(i) / RATE
		var env := minf(1.0, t / 0.08) * pow(1.0 - t / d, 1.4)
		out.append((sin(TAU * f * t) + 0.55 * sin(TAU * f * 2.0 * t) + 0.3 * sin(TAU * f * 3.01 * t) + 0.12 * sin(TAU * f * 5.0 * t)) * 0.2 * env)
	return _to_wav(out)


## Claquement de conteneur posé : bruit court + coup grave.
func _clank() -> AudioStreamWAV:
	return _to_wav(_clank_data())


func _clank_data() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var count := int(0.16 * RATE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in count:
		var t := float(i) / RATE
		var env := exp(-t * 28.0)
		out.append((rng.randf_range(-1.0, 1.0) * 0.5 + sin(TAU * 140.0 * t) * 0.8 + sin(TAU * 310.0 * t) * 0.3) * 0.22 * env)
	return out


## Mouette : deux glissandos descendants avec vibrato.
func _gull() -> AudioStreamWAV:
	var out := PackedFloat32Array()
	var count := int(0.62 * RATE)
	var ph := 0.0
	for i in count:
		var t := float(i) / RATE
		var seg := fmod(t, 0.28)
		var active := t < 0.56 and seg < 0.2
		var f := lerpf(2100.0, 1250.0, seg / 0.2) * (1.0 + 0.03 * sin(TAU * 38.0 * t))
		ph += f / RATE
		var env := (sin(PI * seg / 0.2)) if active else 0.0
		out.append((sin(TAU * ph) + 0.4 * sin(TAU * ph * 2.0)) * 0.10 * env)
	return _to_wav(out)


## Glissando montant (Heures sup : le port accélère).
func _sweep(f0: float, f1: float, d: float, vol: float) -> AudioStreamWAV:
	var out := PackedFloat32Array()
	var count := int(d * RATE)
	var ph := 0.0
	for i in count:
		var k := float(i) / count
		ph += lerpf(f0, f1, k * k) / RATE
		var env := minf(1.0, i / (RATE * 0.01)) * (1.0 - k * 0.6)
		out.append((_wave("triangle", ph) * 0.7 + _wave("square", ph * 0.5) * 0.15) * vol * env)
	return _to_wav(out)


## Superpose des pistes (échantillons flottants) en un son.
func _mix(tracks: Array) -> AudioStreamWAV:
	var n := 0
	for t in tracks:
		n = maxi(n, (t as PackedFloat32Array).size())
	var out := PackedFloat32Array()
	out.resize(n)
	for t in tracks:
		var a: PackedFloat32Array = t
		for i in a.size():
			out[i] += a[i]
	return _to_wav(out)


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
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var swell := 0.55 + 0.45 * sin(TAU * t / 8.0 * 1.0) * sin(TAU * t / 8.0 * 2.0 + 0.7)
		var x := raw[i]
		if i < fade:                                     # début : fondu avec la queue du bruit
			var k := float(i) / fade
			x = raw[i] * k + raw[n + i] * (1.0 - k)
		out[i] = x * 3.2 * swell * 0.5
	var w := _to_wav(out)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w


func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var v := clampi(int(clampf(samples[i], -1.0, 1.0) * 32767.0), -32768, 32767)
		data[i * 2] = v & 0xFF
		data[i * 2 + 1] = (v >> 8) & 0xFF
	return _wav(data)


func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
