# This script controls one obstacle.
# Obstacles can be sharp plants on the ground or mosquitoes in the air.
extends Area2D

# These textures are loaded from PNG game assets instead of being drawn from code-only shapes.
const PLANT_TEXTURE := preload("res://assets/sharp_plant.png")
const MOSQUITO_TEXTURE := preload("res://assets/mosquito.png")

# escaped is a custom signal emitted when the obstacle has moved off the left side.
# main.gd listens for this signal so it can delete the obstacle.
signal escaped(obstacle)

# An enum gives readable names to numeric obstacle types.
# PLANT is 0 and MOSQUITO is 1.
enum ObstacleKind { PLANT, MOSQUITO }

# kind stores whether this specific obstacle is a plant or a mosquito.
var kind := ObstacleKind.PLANT
# speed controls how many pixels per second the obstacle moves left.
var speed := 230.0
# passed becomes true after the player earns a point for passing this obstacle.
var passed := false
# viewport_size stores the game window size so obstacles can be positioned correctly.
var viewport_size := Vector2(1280, 720)

# setup() is called by main.gd right after creating a new obstacle.
func setup(obstacle_kind: int, start_x: float, size: Vector2, move_speed: float) -> void:
	# Store the selected type, either PLANT or MOSQUITO.
	kind = obstacle_kind
	# Store the current viewport size.
	viewport_size = size
	# Store the movement speed passed in by the main game.
	speed = move_speed
	# Put the obstacle just off the right side of the screen.
	position.x = start_x
	# Plants sit on the ground, while mosquitoes appear at a random air height.
	position.y = size.y - 118.0 if kind == ObstacleKind.PLANT else randf_range(size.y * 0.24, size.y * 0.62)
	# Build the collision shape that matches this obstacle type.
	_make_collision()
	# Ask Godot to call _draw() so the obstacle becomes visible.
	queue_redraw()

# _ready() runs once when the obstacle enters the scene tree.
func _ready() -> void:
	# body_entered is a built-in Area2D signal.
	# It fires when a physics body, like the bubble, enters this obstacle's collision area.
	body_entered.connect(_on_body_entered)

# _process(delta) runs every rendered frame.
func _process(delta: float) -> void:
	# Move the obstacle left for positive speed or right for negative speed. Multiplying by delta makes movement frame-rate independent.
	position.x -= speed * delta
	# Once the obstacle is far enough off either horizontal side, tell main.gd it can be removed.
	# The right-side check matters when the player accelerates backward and the world scrolls right.
	if position.x < -120.0 or position.x > viewport_size.x + 240.0:
		# Emit the escaped signal and pass this obstacle node as the argument.
		escaped.emit(self)

# _make_collision() creates the collision shape for either a plant or mosquito.
func _make_collision() -> void:
	# Remove any old CollisionShape2D children before creating a new one.
	# This makes setup() safe to call more than once.
	for child in get_children():
		# Check whether this child is a collision shape node.
		if child is CollisionShape2D:
			# Delete the old collision shape safely.
			child.queue_free()

	# Create the collision node that will hold the shape resource.
	var collider := CollisionShape2D.new()
	# Plants use a tall capsule so the stem/spikes have a vertical hit area.
	if kind == ObstacleKind.PLANT:
		# CapsuleShape2D is rounded at both ends and works well for a tall plant hitbox.
		var shape := CapsuleShape2D.new()
		# Set the capsule radius, which controls its width.
		shape.radius = 24.0
		# Set the capsule height, which controls its total vertical size.
		shape.height = 116.0
		# Move the collision shape upward because the plant is drawn above its origin.
		collider.position = Vector2(0, -58)
		# Assign the capsule shape to the collision node.
		collider.shape = shape
	# Mosquitoes use a circle because their body and wings form a compact flying hazard.
	else:
		# Create a circular collision shape.
		var shape := CircleShape2D.new()
		# Set the circle's radius.
		shape.radius = 31.0
		# Assign the circular shape to the collision node.
		collider.shape = shape
	# Add the finished collision node to this obstacle.
	add_child(collider)

# _on_body_entered() runs when something enters the obstacle's Area2D hitbox.
func _on_body_entered(body: Node) -> void:
	# Check for a pop() method instead of checking a specific class.
	# This keeps the obstacle simple: anything that knows how to pop can be popped.
	if body.has_method("pop"):
		# Call pop() on the body, which is normally the bubble.
		body.pop()

# _draw() chooses which obstacle PNG asset to draw.
func _draw() -> void:
	# If this obstacle is a plant, draw the sharp plant sprite.
	if kind == ObstacleKind.PLANT:
		_draw_sharp_plant()
	# Otherwise draw the mosquito sprite.
	else:
		_draw_mosquito()

# _draw_sharp_plant() draws the plant PNG with its base near this node's origin.
func _draw_sharp_plant() -> void:
	# The plant image is 128x160. Drawing it from y=-150 leaves its base at y=0.
	var rect := Rect2(Vector2(-64.0, -150.0), Vector2(128.0, 160.0))
	# Draw the loaded plant texture into that rectangle.
	draw_texture_rect(PLANT_TEXTURE, rect, false)

# _draw_mosquito() draws the mosquito PNG centered on this node's origin.
func _draw_mosquito() -> void:
	# The mosquito image is 128x96, so this rectangle centers it around (0, 0).
	var rect := Rect2(Vector2(-64.0, -48.0), Vector2(128.0, 96.0))
	# Draw the loaded mosquito texture into that rectangle.
	draw_texture_rect(MOSQUITO_TEXTURE, rect, false)
