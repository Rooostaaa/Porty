class_name SettingsSheet
extends Sheet
## Réglages : son, nouvelle partie, aide.

var sound_btn: Button
var _confirm := false
var reset_btn: Button
var sliders: Dictionary = {}      # bus audio -> réglette de volume


func _init() -> void:
	super._init("Réglages")


func build() -> void:
	var c := UI.card()
	content.add_child(c)
	var v := UI.vbox(16)
	c.add_child(v)
	v.add_child(UI.label("Son", 40, UI.VIOLET))
	sound_btn = UI.button("", UI.INDIGO, 34, 100)
	sound_btn.pressed.connect(func() -> void:
		Settings.set_muted(not Settings.muted)
		Sfx.play("click")
		refresh())
	v.add_child(sound_btn)
	# deux réglages : les sons de l'interface et l'ambiance du port (mer, mouettes, cornes, grues, camions)
	sliders.clear()
	for bus in [["Sons", "Sons"], ["Ambiance", "Ambiance du port"]]:
		var h := UI.hbox(14)
		var l := UI.label(String(bus[1]), 30, UI.TEXT)
		l.custom_minimum_size.x = 300
		h.add_child(l)
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 100.0
		sl.step = 5.0
		sl.value = Sfx.get_volume(String(bus[0])) * 100.0
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sl.custom_minimum_size.y = 96
		sl.add_theme_icon_override("grabber", UI.circle_tex(56, UI.VIOLET))
		sl.add_theme_icon_override("grabber_highlight", UI.circle_tex(60, UI.VIOLET.lightened(0.1)))
		sl.add_theme_stylebox_override("slider", UI.flat(UI.GREY, 12, 0, 12))
		sl.add_theme_stylebox_override("grabber_area", UI.flat(UI.VIOLET, 12, 0, 12))
		sl.add_theme_stylebox_override("grabber_area_highlight", UI.flat(UI.VIOLET, 12, 0, 12))
		var bn := String(bus[0])
		# lot E : le volume s'applique à chaque cran, mais n'est écrit sur le disque qu'au relâchement (ou à la fermeture)
		sl.value_changed.connect(func(x: float) -> void:
			Sfx.set_volume(bn, x / 100.0, false)
			if bn == "Sons":
				Sfx.play("click", 0.15))
		sl.drag_ended.connect(func(_changed: bool) -> void: Sfx.save_volumes())
		h.add_child(sl)
		v.add_child(h)
		sliders[bn] = sl
	var c2 := UI.card()
	content.add_child(c2)
	var v2 := UI.vbox(16)
	c2.add_child(v2)
	v2.add_child(UI.label("Partie", 40, UI.VIOLET))
	v2.add_child(UI.wrap_label("La partie est sauvegardée automatiquement toutes les 15 secondes et à la fermeture.", 28))
	reset_btn = UI.button("NOUVELLE PARTIE", UI.BAD, 34, 100)
	reset_btn.pressed.connect(_reset)
	v2.add_child(reset_btn)
	var c3 := UI.card()
	content.add_child(c3)
	var v3 := UI.vbox(10)
	c3.add_child(v3)
	v3.add_child(UI.label("Comment jouer", 40, UI.VIOLET))
	for line in [
		"• Les navires attendent en rade, accostent, sont déchargés par les grues, puis les conteneurs vont au parc et sortent par la gate.",
		"• Le maillon le plus lent est le goulot : anneau rouge dans le port, pastille rouge sur sa carte, conseil en haut de l'écran.",
		"• Améliore le goulot, un autre apparaîtra. Les licences augmentent la valeur de chaque EVP.",
		"• Touche un navire en rade pour le faire accoster en priorité (tant que la Capitainerie n'a pas de responsable).",
	]:
		v3.add_child(UI.wrap_label(line, 28, UI.TEXT))
	if DebugArgs.allowed():      # ligne réservée à la version de débogage
		v3.add_child(UI.wrap_label("• F1 : outils de débogage.", 28, UI.TEXT))


func _reset() -> void:
	if not _confirm:
		_confirm = true
		reset_btn.text = "CONFIRMER (tout effacer)"
		Sfx.play("bad")
		return
	Save.wipe()
	if Hud.main != null and Hud.main.tutorial != null:
		Hud.main.tutorial.restart()
	close()


func close() -> void:
	Sfx.save_volumes()          # un cran posé sans glisser (toucher sur la piste) est écrit à la fermeture
	super.close()


func refresh() -> void:
	if sound_btn:
		sound_btn.text = "Son : COUPÉ" if Settings.muted else "Son : ACTIVÉ"
		sound_btn.icon = UI.icon_tex("sound_off" if Settings.muted else "sound_on")
		sound_btn.add_theme_constant_override("icon_max_width", 52)
