class_name TitleBackdrop
extends Node3D
## The title screen's background: one of the arenas, empty, with the camera
## slowly circling it, through the screen filter. Picked at random once per
## launch (going back to the title later shows the same one).

const ARENAS := [
	"res://scenes/arenas/arena_square.tscn",
	"res://scenes/arenas/arena_rock_circle.tscn",
	"res://scenes/arenas/arena_long.tscn",
	"res://scenes/arenas/arena_pit.tscn",
	"res://scenes/arenas/arena_platform.tscn",
	"res://scenes/arenas/arena_grand.tscn",
	"res://scenes/arenas/arena_cliff.tscn",
	"res://scenes/arenas/arena_rock_field.tscn",
]
## Radians per second: a full circle takes about two and a half minutes.
const TURN_SPEED := 0.042
## The camera's height, and how far out it circles beyond the arena's edge.
const HEIGHT := 6.5
const MARGIN := 7.0

static var _pick := ""

var arena: Arena
var _camera: Camera3D
var _angle := 0.0
var _radius := 18.0
var _screen: ColorRect


func _ready() -> void:
	if _pick == "":
		_pick = ARENAS[randi() % ARENAS.size()]
		_angle = randf() * TAU
	arena = load(_pick).instantiate() as Arena
	add_child(arena)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.11, 0.12, 0.17)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45.0, 30.0, 0.0)  # as in a fight
	sun.position = Vector3(0, 10, 0)
	sun.shadow_enabled = true
	add_child(sun)
	if arena.scenery:
		arena.scenery.apply_environment(env, sun)
	_radius = arena.extent() + MARGIN
	_camera = Camera3D.new()
	_camera.fov = 55.0
	add_child(_camera)
	_camera.make_current()
	_place_camera()
	_add_screen_filter()


func _process(delta: float) -> void:
	_angle = fmod(_angle + delta * TURN_SPEED, TAU)
	_place_camera()


func _place_camera() -> void:
	if _camera == null:
		return
	_camera.position = Vector3(sin(_angle) * _radius, HEIGHT, cos(_angle) * _radius)
	_camera.look_at(Vector3(0, 0.5, 0), Vector3.UP)


## The PS1 screen filter (Options), under the menu so the text stays sharp.
func _add_screen_filter() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -1
	add_child(layer)
	_screen = ColorRect.new()
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/ps1_screen.gdshader")
	_screen.material = mat
	layer.add_child(_screen)
	apply_screen_filter()


## Options changed: the filter's look (and the vertex wobble).
func apply_screen_filter() -> void:
	var look: Dictionary = Settings.SCREEN_FILTER_LOOKS[Settings.screen_filter()]
	Figure.set_snap_lines(float(look["snap"]))
	_screen.visible = Settings.screen_filter() != "off"
	var mat := _screen.material as ShaderMaterial
	mat.set_shader_parameter("lines", float(look["lines"]))
	mat.set_shader_parameter("levels", float(look["levels"]))
	mat.set_shader_parameter("dither_strength", float(look["dither"]))
	mat.set_shader_parameter("smooth_pixels", bool(look["smooth"]))
