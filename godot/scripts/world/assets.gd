class_name Assets
extends RefCounted
## Chargement des modèles .glb (Blender) avec le matériau couleur-de-sommet partagé.
## Chargeur tolérant : un modèle absent est ignoré (nœud vide, avertissement unique dans la console), le monde se construit quand même.

const DIR := "res://assets/models/"
## Résultat du test du nuancier (voir docs/DECISIONS.md) : couleurs glTF déjà en linéaire.
const VERTEX_IS_SRGB := 0.0
## Marge au-dessus du sommet d'un modèle quand assets_meta.json ne donne pas d'anchor_y.
const ANCHOR_MARGIN := 0.4

static var _scenes: Dictionary = {}
static var _meshes: Dictionary = {}
static var _meta: Dictionary = {}
static var _palette: Dictionary = {}
static var _aabb: Dictionary = {}          # nom -> AABB du modèle (toutes pièces réunies)
static var missing: Array[String] = []     # modèles absents déjà signalés (un avertissement chacun)
static var vcol_material: ShaderMaterial
static var tint_material: ShaderMaterial


static func _ensure() -> void:
	if vcol_material != null:
		return
	vcol_material = ShaderMaterial.new()
	vcol_material.shader = load("res://assets/vcol.gdshader")
	vcol_material.set_shader_parameter("vertex_is_srgb", VERTEX_IS_SRGB)
	tint_material = ShaderMaterial.new()
	tint_material.shader = load("res://assets/vcol_tint.gdshader")
	tint_material.set_shader_parameter("vertex_is_srgb", VERTEX_IS_SRGB)
	var m: Variant = DataDB.load_json(DIR + "assets_meta.json")
	_meta = m if m is Dictionary else {}
	var p: Variant = DataDB.load_json("res://data/palette.json")
	_palette = p if p is Dictionary else {}


static func meta(name: String) -> Dictionary:
	_ensure()
	return _meta.get(name, {})


## Couleur de palette (sRGB, pour l'UI).
static func color(key: String) -> Color:
	_ensure()
	return Color(String(_palette.get(key, "#ff00ff")))


## Le modèle existe-t-il (fichier ou cache d'import) ?
static func exists(name: String) -> bool:
	return ResourceLoader.exists(DIR + name + ".glb")


static func scene(name: String) -> PackedScene:
	if not _scenes.has(name):
		if not exists(name):
			if not missing.has(name):
				missing.append(name)
				push_warning("Modèle absent, ignoré : %s.glb (en attente de la livraison Blender)" % name)
			_scenes[name] = null
		else:
			_scenes[name] = load(DIR + name + ".glb")
	return _scenes[name]


## Instancie un modèle et remplace ses matériaux par le matériau partagé.
## Modèle absent : nœud vide (le décor se construit sans lui).
static func instance(name: String, mat: Material = null) -> Node3D:
	_ensure()
	var ps := scene(name)
	if ps == null:
		var empty := Node3D.new()
		empty.name = "absent_" + name
		return empty
	var n: Node3D = ps.instantiate()
	apply_material(n, mat if mat != null else vcol_material)
	return n


static func apply_material(n: Node, mat: Material) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_override = mat
	for c in n.get_children():
		apply_material(c, mat)


## Maillage d'un asset à pièce unique (pour MultiMesh). null si le modèle est absent.
static func mesh(name: String) -> Mesh:
	if _meshes.has(name):
		return _meshes[name]
	var n := instance(name)
	var found: Mesh = null
	var stack: Array[Node] = [n]
	while not stack.is_empty() and found == null:
		var cur: Node = stack.pop_back()
		if cur is MeshInstance3D:
			found = (cur as MeshInstance3D).mesh
		for c in cur.get_children():
			stack.append(c)
	n.free()
	_meshes[name] = found
	return found


## Boîte englobante du modèle (toutes les pièces, dans le repère du modèle). Vide si le modèle est absent.
static func aabb(name: String) -> AABB:
	if _aabb.has(name):
		return _aabb[name]
	var n := instance(name)
	var box := AABB()
	var first := true
	var stack: Array[Node] = [n]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is MeshInstance3D and (cur as MeshInstance3D).mesh != null:
			var mi := cur as MeshInstance3D
			# transformation locale cumulée jusqu'à la racine du modèle
			var xf := Transform3D.IDENTITY
			var p: Node = mi
			while p != null and p != n:
				if p is Node3D:
					xf = (p as Node3D).transform * xf
				p = p.get_parent()
			var b := xf * mi.mesh.get_aabb()
			box = b if first else box.merge(b)
			first = false
		for c in cur.get_children():
			stack.append(c)
	n.free()
	_aabb[name] = box
	return box


## Sommet du modèle (y maximal), 0 s'il est absent. Sert à poser un objet dessus (mouette sur un bollard).
static func top_y(name: String) -> float:
	var b := aabb(name)
	return b.end.y if b.size.y > 0.0 else 0.0


## Hauteur d'ancrage des bulles d'information : anchor_y de assets_meta.json si présent,
## sinon le sommet de la boîte englobante + ANCHOR_MARGIN.
static func anchor_y(name: String) -> float:
	var m := meta(name)
	if m.has("anchor_y"):
		return float(m.anchor_y)
	return top_y(name) + ANCHOR_MARGIN


## Pièce nommée d'un asset multi-pièces (ex. « boom » d'une grue).
static func part(root: Node, part_name: String) -> Node3D:
	var n := root.find_child(part_name, true, false)
	return n as Node3D
