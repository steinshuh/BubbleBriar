extends CharacterBody2D

signal popped

const GRAVITY := 920.0
const BOUNCE_VELOCITY := -420.0
const FLOOR_BOUNCE := -520.0
const MAX_FALL := 650.0

var radius := 31.0
var alive := true
var viewport_size := Vector2(1280, 720)

func _ready() -> void:
	var shape := CircleShape2D.new()
	shape.radius = radius
	var collider := CollisionShape2D.new()
	collider.shape = shape
	add_child(collider)
	queue_redraw()

func setup(size: Vector2) -> void:
	viewport_size = size
	position = Vector2(size.x * 0.24, size.y * 0.45)
	velocity = Vector2.ZERO
	alive = true
	modulate.a = 1.0

func _physics_process(delta: float) -> void:
	if not alive:
		velocity.y += GRAVITY * delta
		move_and_slide()
		return

	if Input.is_action_just_pressed("bounce") or Input.is_action_just_pressed("ui_accept"):
		velocity.y = BOUNCE_VELOCITY

	velocity.y = min(velocity.y + GRAVITY * delta, MAX_FALL)
	move_and_slide()

	var floor_y := viewport_size.y - 118.0
	if position.y + radius > floor_y:
		position.y = floor_y - radius
		velocity.y = FLOOR_BOUNCE
	if position.y - radius < 0.0:
		position.y = radius
		velocity.y = 90.0

func pop() -> void:
	if not alive:
		return
	alive = false
	modulate.a = 0.38
	popped.emit()

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(0.55, 0.9, 1.0, 0.38))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 80, Color("#dbfbff"), 4.0, true)
	draw_circle(Vector2(-10, -12), 8.0, Color(1.0, 1.0, 1.0, 0.72))
	draw_arc(Vector2(5, 9), 16.0, 0.35, 2.55, 28, Color(1.0, 1.0, 1.0, 0.36), 3.0, true)
