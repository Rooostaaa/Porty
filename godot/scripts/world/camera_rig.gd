class_name CameraRig
extends Node3D
## Caméra orthographique isométrique (inclinaison 35°, rotation 45°) : glisser, pincer/molette, bornes par palier.

signal tapped(world_pos: Vector3, screen_pos: Vector2)

const PITCH := -35.0
const YAW := 45.0
const DIST := 160.0

var cam: Camera3D
## Cadrage de départ (plan de la baie, décision 4) : le vieux port, la passe et un navire au mouillage (place n°1)
## tiennent sous les cartes du HUD en portrait.
const START := Vector3(-45.0, 0.0, -29.0)
## Largeur visible par défaut (unités monde) : 58 u — phare, navire au mouillage n°1 et empreinte du quai tiennent entre la
## carte du tutoriel et le haut de l'écran, et le navire reste sous la carte Goulot quand le tutoriel est fini (revue N3,
## contrôlé par ui_smoke en portrait).
const ZOOM_START := 58.0
var target := START
var goal := START
var zoom := ZOOM_START        # largeur visible (unités monde)
var zoom_goal := ZOOM_START
var zoom_min := 28.0
var zoom_max := 120.0
const ZOOM_MAX := 130.0       # zoom le plus large (lot F2 : bornes du monde habillé)
var bounds := Rect2(-60, -80, 80, 140)   # x, z, largeur, profondeur
## Coupé quand un écran s'ouvre. S'il l'est en plein glissement, le relâchement n'arrivera jamais jusqu'ici :
## on oublie le geste en cours, sinon la caméra resterait « accrochée » au curseur à la fermeture de l'écran.
var input_enabled := true:
	set(v):
		input_enabled = v
		if not v:
			_dragging = false
			_touches.clear()
			_pinch_dist = 0.0
			# lot E (E5) : un relâchement qui suit la fermeture d'un écran n'est jamais un toucher du monde (l'appui a été pris
			# par l'écran : la caméra ne l'a pas vu, et `_press_pos` datait d'un ancien toucher)
			_pressed = false
			_press_pos = OFFSCREEN

const OFFSCREEN := Vector2(-1.0e6, -1.0e6)
var _pressed := false         # un appui gauche a été reçu par la caméra (le relâchement correspondant peut être un toucher)

var _touches: Dictionary = {}
var _drag_from := Vector2.ZERO
var _dragging := false
var _press_pos := Vector2.ZERO
var _pinch_dist := 0.0
var _shake := 0.0


func _ready() -> void:
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.near = 1.0
	cam.far = 600.0
	add_child(cam)
	cam.make_current()
	_apply()


func set_tier_bounds(tier: int) -> void:
	var lx: Array = Layout.LAND_X.get(tier, Layout.LAND_X[1])
	# le port s'étend avec le palier ; l'arrière-pays (village, autoroute) reste accessible dès le départ
	# lot F2 : 60 u de plus vers le large (la rive d'en face paraît en haut de l'écran au zoom le plus large) ; au zoom le plus
	# large, aux quatre coins des bornes, on voit au plus x −320…400, z −340…350 : rives du golfe, forêt (Layout.FOREST_AREA),
	# rive d'en face et eau couvrent tout ce rectangle — jamais le bord du monde (zoom 190 avant)
	bounds = Rect2(-130.0, -150.0, float(lx[1]) + 60.0 + 130.0, 310.0)
	zoom_max = clampf(bounds.size.x * 0.75, 90.0, ZOOM_MAX)


## Verrouillée par une capture avec --look : les recentrages du jeu (premier navire d'une classe, tutoriel) sont ignorés.
var locked := false


func focus(p: Vector3) -> void:
	if locked:
		return
	goal = Vector3(p.x, 0.0, p.z)


func shake(amount: float = 0.6) -> void:
	_shake = maxf(_shake, amount)


func _process(delta: float) -> void:
	goal.x = clampf(goal.x, bounds.position.x, bounds.end.x)
	goal.z = clampf(goal.z, bounds.position.y, bounds.end.y)
	target = target.lerp(goal, 1.0 - exp(-delta * 10.0))
	zoom_goal = clampf(zoom_goal, zoom_min, zoom_max)
	zoom = lerpf(zoom, zoom_goal, 1.0 - exp(-delta * 10.0))
	_shake = maxf(0.0, _shake - delta * 2.0)
	_apply()


const REF_W := 1080.0
const REF_H := 1920.0


## Fenêtre plus large que le portrait de référence : on garde la hauteur visible (le monde garde la même échelle
## et on voit simplement plus de côtés). Plus étroite : on garde la largeur (on voit plus de haut en bas).
func _keep_height(vs: Vector2) -> bool:
	return vs.x / maxf(1.0, vs.y) > REF_W / REF_H + 0.01


func _visible_height(vs: Vector2) -> float:
	return zoom * REF_H / REF_W if _keep_height(vs) else zoom * vs.y / maxf(1.0, vs.x)


func _apply() -> void:
	var basis := Basis.from_euler(Vector3(deg_to_rad(PITCH), deg_to_rad(YAW), 0.0))
	var off := Vector3.ZERO
	if _shake > 0.0:
		off = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * _shake
	var vs := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(REF_W, REF_H)
	cam.global_transform = Transform3D(basis, target + off + basis.z * dist())
	cam.far = dist() + 500.0
	if _keep_height(vs):
		cam.keep_aspect = Camera3D.KEEP_HEIGHT
		cam.size = zoom * REF_H / REF_W
	else:
		cam.keep_aspect = Camera3D.KEEP_WIDTH
		cam.size = zoom


## Recul de la caméra : en orthographique il ne change pas l'image, mais le bas de l'écran
## doit partir au-dessus de l'eau, sinon on voit le fond de ciel quand on dézoome.
func dist() -> float:
	var vs := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(REF_W, REF_H)
	var half_h := _visible_height(vs) * 0.5
	return maxf(DIST, half_h * cos(deg_to_rad(-PITCH)) / sin(deg_to_rad(-PITCH)) + 40.0)


## Projection écran → plan du sol (y = 0).
func screen_to_ground(sp: Vector2) -> Vector3:
	var o := cam.project_ray_origin(sp)
	var d := cam.project_ray_normal(sp)
	if absf(d.y) < 1e-4:
		return o
	var t := -o.y / d.y
	return o + d * t


func _pan_by(screen_delta: Vector2) -> void:
	var a := screen_to_ground(Vector2.ZERO)
	var b := screen_to_ground(screen_delta)
	goal -= (b - a)
	target -= (b - a)


func handle_input(event: InputEvent) -> bool:
	if not input_enabled:
		return false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			zoom_goal *= 0.88
			return true
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			zoom_goal *= 1.12
			return true
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging = true
				_drag_from = mb.position
				_press_pos = mb.position
				_pressed = true
			else:
				_dragging = false
				var was := _pressed
				_pressed = false
				if was and mb.position.distance_to(_press_pos) < 14.0:
					_press_pos = OFFSCREEN
					tapped.emit(screen_to_ground(mb.position), mb.position)
			return true
	elif event is InputEventMouseMotion and _dragging and _touches.size() < 2:
		var mm := event as InputEventMouseMotion
		_pan_by(mm.position - _drag_from)
		_drag_from = mm.position
		return true
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_touches[st.index] = st.position
		else:
			_touches.erase(st.index)
		_pinch_dist = 0.0
		return false
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_touches[sd.index] = sd.position
		if _touches.size() >= 2:
			var pts: Array = _touches.values()
			var d: float = (pts[0] as Vector2).distance_to(pts[1])
			if _pinch_dist > 0.0:
				zoom_goal *= _pinch_dist / maxf(1.0, d)
			_pinch_dist = d
			return true
	elif event is InputEventMagnifyGesture:
		zoom_goal /= (event as InputEventMagnifyGesture).factor
		return true
	return false
