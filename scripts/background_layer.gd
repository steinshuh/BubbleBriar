extends Node2D

@export var layer_kind := 0
@export var speed_factor := 0.0
@export var world_speed := 0.0

var viewport_size := Vector2(1280, 720)
var offset_x := 0.0
var tile_width := 1280.0

func setup(kind: int, factor: float, speed: float, size: Vector2) -> void:
	layer_kind = kind
	speed_factor = factor
	world_speed = speed
	viewport_size = size
	tile_width = max(960.0, viewport_size.x)
	queue_redraw()

func _process(delta: float) -> void:
	if speed_factor > 0.0:
		offset_x = fmod(offset_x + world_speed * speed_factor * delta, tile_width)
		queue_redraw()

func _draw() -> void:
	match layer_kind:
		0:
			_draw_stationary_sky()
		1:
			_draw_far_hills()
		2:
			_draw_near_trees()
		3:
			_draw_ground()

func _draw_stationary_sky() -> void:
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color("#9bdcff"))
	draw_circle(Vector2(viewport_size.x * 0.82, viewport_size.y * 0.16), 54.0, Color("#fff1a8"))
	var base_y := viewport_size.y * 0.62
	var mountain_color := Color("#8ab0c3")
	var shade_color := Color("#6f98ad")
	var peaks := [
		Vector2(-120, base_y), Vector2(120, viewport_size.y * 0.28), Vector2(360, base_y),
		Vector2(250, base_y), Vector2(545, viewport_size.y * 0.22), Vector2(880, base_y),
		Vector2(730, base_y), Vector2(1020, viewport_size.y * 0.30), Vector2(1360, base_y)
	]
	for i in range(0, peaks.size(), 3):
		draw_colored_polygon(PackedVector2Array([peaks[i], peaks[i + 1], peaks[i + 2]]), mountain_color)
		draw_colored_polygon(PackedVector2Array([peaks[i + 1], peaks[i + 2], Vector2(peaks[i + 1].x + 60, base_y)]), shade_color)

func _draw_far_hills() -> void:
	for tile in range(-1, 3):
		var x := tile * tile_width - offset_x
		var y := viewport_size.y * 0.66
		var hill := PackedVector2Array([
			Vector2(x - 80, viewport_size.y),
			Vector2(x + 80, y + 30),
			Vector2(x + 260, y - 35),
			Vector2(x + 470, y + 18),
			Vector2(x + 700, y - 52),
			Vector2(x + 970, y + 20),
			Vector2(x + tile_width + 120, viewport_size.y),
		])
		draw_colored_polygon(hill, Color("#79bf83"))
		var back := PackedVector2Array([
			Vector2(x - 120, viewport_size.y),
			Vector2(x + 150, y + 72),
			Vector2(x + 410, y + 8),
			Vector2(x + 740, y + 68),
			Vector2(x + 1060, y + 5),
			Vector2(x + tile_width + 160, viewport_size.y),
		])
		draw_colored_polygon(back, Color("#5ba874"))

func _draw_near_trees() -> void:
	for tile in range(-1, 3):
		var x0 := tile * tile_width - offset_x
		for i in range(8):
			var x := x0 + i * 180.0 + 35.0
			var trunk_h := 92.0 + float((i * 29) % 52)
			var base_y := viewport_size.y * 0.86
			draw_rect(Rect2(Vector2(x - 9, base_y - trunk_h), Vector2(18, trunk_h)), Color("#6d5136"))
			draw_circle(Vector2(x, base_y - trunk_h - 18.0), 46.0, Color("#26734d"))
			draw_circle(Vector2(x - 30.0, base_y - trunk_h + 6.0), 32.0, Color("#2d8a58"))
			draw_circle(Vector2(x + 32.0, base_y - trunk_h + 10.0), 34.0, Color("#1f6845"))
			_draw_leaf_cluster(x + 84.0, base_y - 22.0, 0.8)

func _draw_leaf_cluster(x: float, y: float, scale: float) -> void:
	for j in range(4):
		var p := Vector2(x + j * 22.0 * scale, y + sin(float(j)) * 8.0)
		draw_circle(p, 22.0 * scale, Color("#2f995f"))

func _draw_ground() -> void:
	var ground_y := viewport_size.y - 88.0
	draw_rect(Rect2(Vector2(0, ground_y), Vector2(viewport_size.x, 88.0)), Color("#326242"))
	for tile in range(-1, 3):
		var x0 := tile * tile_width - offset_x
		for i in range(16):
			var x := x0 + i * 82.0
			var blade_h := 18.0 + float((i * 17) % 32)
			draw_line(Vector2(x, ground_y + 8.0), Vector2(x + 15.0, ground_y - blade_h), Color("#54b35f"), 4.0)
			draw_line(Vector2(x + 28.0, ground_y + 10.0), Vector2(x + 17.0, ground_y - blade_h * 0.75), Color("#79ca67"), 3.0)
		for i in range(7):
			var x := x0 + i * 210.0 + 35.0
			draw_circle(Vector2(x, ground_y + 28.0), 18.0, Color("#254c35"))
