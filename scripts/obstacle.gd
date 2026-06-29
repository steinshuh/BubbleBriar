extends Area2D

signal escaped(obstacle)

enum ObstacleKind { PLANT, MOSQUITO }

var kind := ObstacleKind.PLANT
var speed := 230.0
var passed := false
var viewport_size := Vector2(1280, 720)

func setup(obstacle_kind: int, start_x: float, size: Vector2, move_speed: float) -> void:
	kind = obstacle_kind
	viewport_size = size
	speed = move_speed
	position.x = start_x
	position.y = size.y - 118.0 if kind == ObstacleKind.PLANT else randf_range(size.y * 0.24, size.y * 0.62)
	_make_collision()
	queue_redraw()

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	position.x -= speed * delta
	if position.x < -120.0:
		escaped.emit(self)

func _make_collision() -> void:
	for child in get_children():
		if child is CollisionShape2D:
			child.queue_free()

	var collider := CollisionShape2D.new()
	if kind == ObstacleKind.PLANT:
		var shape := CapsuleShape2D.new()
		shape.radius = 24.0
		shape.height = 116.0
		collider.position = Vector2(0, -58)
		collider.shape = shape
	else:
		var shape := CircleShape2D.new()
		shape.radius = 31.0
		collider.shape = shape
	add_child(collider)

func _on_body_entered(body: Node) -> void:
	if body.has_method("pop"):
		body.pop()

func _draw() -> void:
	if kind == ObstacleKind.PLANT:
		_draw_sharp_plant()
	else:
		_draw_mosquito()

func _draw_sharp_plant() -> void:
	var stem := PackedVector2Array([
		Vector2(-24, 0), Vector2(-17, -92), Vector2(0, -132), Vector2(17, -92), Vector2(24, 0)
	])
	draw_colored_polygon(stem, Color("#1f7a43"))
	draw_polyline(stem + PackedVector2Array([stem[0]]), Color("#b8ff8d"), 3.0)
	for side in [-1, 1]:
		for i in range(3):
			var y := -30.0 - i * 26.0
			var spike := PackedVector2Array([
				Vector2(side * 8, y),
				Vector2(side * (44 + i * 6), y - 16),
				Vector2(side * 10, y - 24),
			])
			draw_colored_polygon(spike, Color("#6bbb48"))
	draw_circle(Vector2(0, -134), 8.0, Color("#eaffbd"))

func _draw_mosquito() -> void:
	draw_circle(Vector2.ZERO, 15.0, Color("#40313c"))
	draw_ellipse(Vector2(-28, -10), 20.0, 16.0, Color(0.85, 0.95, 1.0, 0.48))
	draw_ellipse(Vector2(28, -10), 20.0, 16.0, Color(0.85, 0.95, 1.0, 0.48))
	draw_line(Vector2(14, 0), Vector2(48, -9), Color("#261b22"), 3.0)
	draw_line(Vector2(48, -9), Vector2(62, -7), Color("#d94f4f"), 2.0)
	for leg in range(3):
		var y := -6.0 + leg * 8.0
		draw_line(Vector2(-7, y), Vector2(-36, y + 18.0), Color("#261b22"), 2.0)
		draw_line(Vector2(7, y), Vector2(36, y + 18.0), Color("#261b22"), 2.0)
