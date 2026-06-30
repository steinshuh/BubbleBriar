# This script controls one obstacle.
# Obstacles can be sharp plants on the ground or mosquitoes in the air.
extends Area2D

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

# _draw() chooses which obstacle art to draw.
func _draw() -> void:
	# If this obstacle is a plant, draw the sharp plant art.
	if kind == ObstacleKind.PLANT:
		_draw_sharp_plant()
	# Otherwise draw the mosquito art.
	else:
		_draw_mosquito()

# _draw_sharp_plant() draws a dangerous spiked plant from polygons and circles.
func _draw_sharp_plant() -> void:
	# stem is a five-point polygon shaped like a tall pointed leaf.
	var stem := PackedVector2Array([
		Vector2(-24, 0), Vector2(-17, -92), Vector2(0, -132), Vector2(17, -92), Vector2(24, 0)
	])
	# Fill the plant stem with dark green.
	draw_colored_polygon(stem, Color("#1f7a43"))
	# Draw a light outline around the stem polygon.
	draw_polyline(stem + PackedVector2Array([stem[0]]), Color("#b8ff8d"), 3.0)
	# Draw spikes on both sides of the plant.
	for side in [-1, 1]:
		# Draw three spikes on each side.
		for i in range(3):
			# y is the vertical position for this spike.
			var y := -30.0 - i * 26.0
			# spike is a small triangle sticking out of the stem.
			var spike := PackedVector2Array([
				Vector2(side * 8, y),
				Vector2(side * (44 + i * 6), y - 16),
				Vector2(side * 10, y - 24),
			])
			# Fill the spike triangle with a lighter green.
			draw_colored_polygon(spike, Color("#6bbb48"))
	# Draw a pale point at the tip to make the plant look extra sharp.
	draw_circle(Vector2(0, -134), 8.0, Color("#eaffbd"))

# _draw_mosquito() draws a flying obstacle from circles, ellipses, and lines.
func _draw_mosquito() -> void:
	# Draw the mosquito body as a dark circle at the node origin.
	draw_circle(Vector2.ZERO, 15.0, Color("#40313c"))
	# Draw the left translucent wing.
	draw_ellipse(Vector2(-28, -10), 20.0, 16.0, Color(0.85, 0.95, 1.0, 0.48))
	# Draw the right translucent wing.
	draw_ellipse(Vector2(28, -10), 20.0, 16.0, Color(0.85, 0.95, 1.0, 0.48))
	# Draw the mosquito's needle-like mouth part.
	draw_line(Vector2(14, 0), Vector2(48, -9), Color("#261b22"), 3.0)
	# Draw a small red point at the end of the mouth part.
	draw_line(Vector2(48, -9), Vector2(62, -7), Color("#d94f4f"), 2.0)
	# Draw three pairs of legs.
	for leg in range(3):
		# y spaces the legs vertically along the body.
		var y := -6.0 + leg * 8.0
		# Draw one left leg.
		draw_line(Vector2(-7, y), Vector2(-36, y + 18.0), Color("#261b22"), 2.0)
		# Draw one right leg.
		draw_line(Vector2(7, y), Vector2(36, y + 18.0), Color("#261b22"), 2.0)


