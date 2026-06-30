# This script controls one mosquito obstacle.
# It is attached to scenes/Mosquito.tscn.
extends Area2D

# This texture is loaded from a PNG game asset instead of being drawn from code-only shapes.
const MOSQUITO_TEXTURE := preload("res://assets/mosquito.png")

# escaped is a custom signal emitted when the mosquito has moved off the left side.
# main.gd listens for this signal so it can delete the obstacle.
signal escaped(obstacle)

# speed controls how many pixels per second the mosquito moves left.
var speed := 230.0
# passed becomes true after the player earns a point for passing this mosquito.
var passed := false
# viewport_size stores the game window size so the mosquito can be positioned and cleaned up correctly.
var viewport_size := Vector2(1280, 720)

# setup() is called by main.gd right after creating a new mosquito.
func setup(start_x: float, size: Vector2, move_speed: float) -> void:
	# Store the current viewport size.
	viewport_size = size
	# Store the movement speed passed in by the main game.
	speed = move_speed
	# Put the mosquito just off the right side of the screen.
	position.x = start_x
	# Mosquitoes fly at a random air height.
	position.y = randf_range(size.y * 0.24, size.y * 0.62)
	# Ask Godot to call _draw() so the mosquito becomes visible.
	queue_redraw()

# _ready() runs once when the mosquito enters the scene tree.
func _ready() -> void:
	# body_entered is a built-in Area2D signal.
	# It fires when a physics body, like the bubble, enters this mosquito's collision area.
	body_entered.connect(_on_body_entered)

# _process(delta) runs every rendered frame.
func _process(delta: float) -> void:
	# Move the mosquito left by the current forward world speed.
	position.x -= speed * delta
	# Once the mosquito is far enough off the left side, tell main.gd it can be removed.
	if position.x < -120.0:
		escaped.emit(self)

# _on_body_entered() runs when something enters the mosquito's Area2D hitbox.
func _on_body_entered(body: Node) -> void:
	# Check for a pop() method so the mosquito can pop the bubble without depending on its exact class.
	if body.has_method("pop"):
		body.pop()

# _draw() draws the mosquito PNG centered on this node's origin.
func _draw() -> void:
	# The mosquito image is 128x96, so this rectangle centers it around (0, 0).
	var rect := Rect2(Vector2(-64.0, -48.0), Vector2(128.0, 96.0))
	# Draw the loaded mosquito texture into that rectangle.
	draw_texture_rect(MOSQUITO_TEXTURE, rect, false)
