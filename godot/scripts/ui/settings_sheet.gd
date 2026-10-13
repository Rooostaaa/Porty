class_name SettingsSheet
extends Sheet
## Réglages : son, nouvelle partie, aide.

var sound_btn: Button
var _confirm := false
var reset_btn: Button


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


func refresh() -> void:
	if sound_btn:
		sound_btn.text = "Son : COUPÉ" if Settings.muted else "Son : ACTIVÉ"
		sound_btn.icon = UI.icon_tex("sound_off" if Settings.muted else "sound_on")
		sound_btn.add_theme_constant_override("icon_max_width", 52)
