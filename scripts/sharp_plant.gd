# This script controls one sharp plant obstacle.
# It is attached to scenes/SharpPlant.tscn.
extends Area2D

# This texture is loaded from a PNG game asset instead of being drawn from code-only shapes.
const PLANT_TEXTURE := preload("res://assets/sharp_plant.png")

# escaped is a custom signal emitted when the plant has moved off the left side.
# main.gd listens for this signal so it can delete the obstacle.
signal escaped(obstacle)

# speed controls how many pixels per second the plant moves left.
var speed := 230.0
# passed becomes true after the player earns a point for passing this plant.
var passed := false
# viewport_size stores the game window size so the plant can be positioned and cleaned up correctly.
var viewport_size := Vector2(1280, 720)

# setup() is called by main.gd right after creating a new plant.
func setup(start_x: float, size: Vector2, move_speed: float) -> void:
	# Store the current viewport size.
	viewport_size = size
	# Store the movement speed passed in by the main game.
	speed = move_speed
	# Put the plant just off the right side of the screen.
	position.x = start_x
	# Plants sit on the ground.
	position.y = size.y - 118.0
	# Ask Godot to call _draw() so the plant becomes visible.
	queue_redraw()

# _ready() runs once when the plant enters the scene tree.
func _ready() -> void:
	# body_entered is a built-in Area2D signal.
	# It fires when a physics body, like the bubble, enters this plant's collision area.
	body_entered.connect(_on_body_entered)

# _process(delta) runs every rendered frame.
func _process(delta: float) -> void:
	# Move the plant left by the current forward world speed.
	position.x -= speed * delta
	# Once the plant is far enough off the left side, tell main.gd it can be removed.
	if position.x < -120.0:
		escaped.emit(self)

# _on_body_entered() runs when something enters the plant's Area2D hitbox.
func _on_body_entered(body: Node) -> void:
	# Check for a pop() method so the plant can pop the bubble without depending on its exact class.
	if body.has_method("pop"):
		body.pop()

# _draw() draws the plant PNG with its base near this node's origin.
func _draw() -> void:
	# The plant image is 128x160. Drawing it from y=-150 leaves its base at y=0.
	var rect := Rect2(Vector2(-64.0, -150.0), Vector2(128.0, 160.0))
	# Draw the loaded plant texture into that rectangle.
	draw_texture_rect(PLANT_TEXTURE, rect, false)
