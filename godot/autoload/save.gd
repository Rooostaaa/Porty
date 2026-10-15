extends Node
## Sauvegarde JSON versionnée dans user:// : écriture atomique, copie de secours, migration, hors-ligne.

const PATH := "user://save.json"
const BACKUP := "user://save.bak.json"
const VERSION := 8            # 2 : révélation progressive, gabarits de quai (PortSim._upgrade_legacy_save)
                              # 3 : commerce, armateurs démarchés (PortSim._upgrade_commerce_save)
                              # 4 : licences plafonnées par palier, excédent remboursé (PortSim._clamp_licences)
                              # 5 : instants des révélations (« features » : dictionnaire id -> instant ; la liste d'avant se
                              #     charge comme « révélé depuis toujours »), dernière révélation (PortSim.from_dict)
                              # 6 : lot F3 — la pêche de l'anse et l'acte 0 (clé « act0 » de la partie ; absente : acte 0
                              #     fait, cinq achats, pêche passive — PortSim.from_dict, Fishing.migrate_done)
                              # 7 : lot G1 — la Crique (cartes à niveaux, bâtiments, Marcel, Concession) ; une partie v6 en cours
                              #     d'acte 0 recommence la Crique, une partie v6 au T1+ se charge Crique finie (Fishing.from_dict)
                              # 8 : lot G2 — le terre-plein à la main (clé « g2 » : friche, gestes, offres des responsables) ;
                              #     absente : port complet (six pièces du départ bâties), sauf une partie v7 en pleine Crique
const AUTOSAVE := 15.0
const AWAY_MIN := 60.0       # absence (s) à partir de laquelle on crédite du hors-ligne

var _timer: float = 0.0
var _last_unix: float = 0.0   # horloge murale de l'image précédente
var enabled: bool = true


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	# Les tests tournent en --headless : ils ne doivent ni lire ni réécrire la vraie sauvegarde du joueur
	# (l'autoload la chargeait puis la réenregistrait à la sortie, en y créditant le hors-ligne au passage).
	if DisplayServer.get_name() == "headless":
		enabled = false
		return
	# Partie de test (--fresh) : décidé ici et pas seulement dans main.gd. Si main.gd ne se charge pas (erreur de script),
	# la vraie partie était chargée, jouée en arrière-plan et réenregistrée par la sauvegarde automatique.
	if OS.get_cmdline_user_args().has("--fresh"):
		enabled = false
		return
	load_game()


func _process(delta: float) -> void:
	# Mise en veille ou application passée en arrière-plan sans être tuée : plus aucune image n'est produite, et la
	# simulation (pas plafonné à 0,25 s) ne rattrape pas ce temps. Un trou d'horloge entre deux images = une absence.
	var now := Time.get_unix_time_from_system()
	var gap := now - _last_unix if _last_unix > 0.0 else 0.0   # 1re image : on arme seulement l'horloge
	_last_unix = now
	if enabled and gap > AWAY_MIN and GameState.sim != null:
		GameState.credit_offline(gap)
	_timer += delta
	if _timer >= AUTOSAVE:
		_timer = 0.0
		save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		save_game()


func save_game() -> void:
	if not enabled or GameState.sim == null:
		return
	var d := {"version": VERSION, "saved_at": Time.get_unix_time_from_system(), "sim": GameState.sim.to_dict()}
	var tmp := PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Sauvegarde impossible : %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(d))
	f.close()
	var dir := DirAccess.open("user://")
	if dir.file_exists("save.json"):
		dir.copy(PATH, BACKUP)
	dir.rename(tmp, PATH)


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var txt := FileAccess.get_file_as_string(path)
	var d: Variant = JSON.parse_string(txt)
	return d if d is Dictionary else {}


func load_game() -> void:
	var d := _read(PATH)
	if not (d.get("sim") is Dictionary):      # fichier absent, tronqué ou d'un autre format : on tente la copie de secours
		d = _read(BACKUP)
	if not (d.get("sim") is Dictionary):
		return
	d = _migrate(d)
	GameState.load_from(d.sim)
	var away := Time.get_unix_time_from_system() - float(d.get("saved_at", 0.0))
	if away > AWAY_MIN:
		GameState.offline_report = GameState.sim.apply_offline(away)


func _migrate(d: Dictionary) -> Dictionary:
	var v := int(d.get("version", 0))
	if v < VERSION:
		d.version = VERSION   # la partie elle-même est mise à niveau par PortSim.from_dict (clés « features », « owners_on » absentes)
	return d


func wipe() -> void:
	enabled = false
	for p in [PATH, BACKUP]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	GameState.new_game()
	enabled = true
	save_game()


func _exit_tree() -> void:
	save_game()
