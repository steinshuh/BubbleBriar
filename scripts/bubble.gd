# This script controls the player character: the bubble.
# CharacterBody2D gives us velocity and move_and_slide(), which are useful for movement.
extends CharacterBody2D

# popped is a custom signal.
# Other scripts can connect to it and react when the bubble pops.
signal popped

# GRAVITY is how quickly the bubble accelerates downward.
const GRAVITY := 920.0
# BOUNCE_VELOCITY is the upward speed applied when the player presses the bounce button.
# It is negative because in Godot 2D, smaller y values are higher on the screen.
const BOUNCE_VELOCITY := -420.0
# FLOOR_BOUNCE is the stronger upward speed applied when the bubble hits the floor.
const FLOOR_BOUNCE := -520.0
# MAX_FALL prevents the bubble from falling infinitely faster over time.
const MAX_FALL := 650.0

# radius controls both the drawn bubble size and the collision circle size.
var radius := 31.0
# alive is true during active play and false after the bubble pops.
var alive := true
# viewport_size stores the game window size so the bubble can stay inside it.
var viewport_size := Vector2(1280, 720)

# _ready() runs once when the bubble enters the scene tree.
func _ready() -> void:
	# Create a circular collision shape resource.
	var shape := CircleShape2D.new()
	# Match the collision circle radius to the visible bubble radius.
	shape.radius = radius
	# CollisionShape2D is the node that holds the collision shape in the scene tree.
	var collider := CollisionShape2D.new()
	# Assign the circular shape to the collision node.
	collider.shape = shape
	# Add the collision node as a child of the bubble so physics can detect hits.
	add_child(collider)
	# Ask Godot to call _draw() so the bubble becomes visible.
	queue_redraw()

# setup() resets the bubble for a new run.
func setup(size: Vector2) -> void:
	# Store the current viewport size.
	viewport_size = size
	# Place the bubble about one quarter from the left and near the vertical middle.
	position = Vector2(size.x * 0.24, size.y * 0.45)
	# Stop all previous movement from an old run.
	velocity = Vector2.ZERO
	# Mark the bubble alive again.
	alive = true
	# Restore full opacity in case it was faded after popping.
	modulate.a = 1.0

# _physics_process(delta) runs on Godot's fixed physics tick.
# Physics movement belongs here because it stays stable even when frame rate changes.
func _physics_process(delta: float) -> void:
	# If the bubble has popped, it no longer accepts input or bounces off bounds.
	if not alive:
		# Still apply gravity so the faded bubble falls away after popping.
		velocity.y += GRAVITY * delta
		# Move according to the current velocity.
		move_and_slide()
		# Stop here so the living-bubble logic below does not run.
		return

	# Check whether the player pressed the bounce action during this physics tick.
	if Input.is_action_just_pressed("bounce") or Input.is_action_just_pressed("ui_accept"):
		# Set upward velocity, creating the bounce/flap feeling.
		velocity.y = BOUNCE_VELOCITY

	# Add gravity to the vertical velocity, but do not let it exceed MAX_FALL.
	velocity.y = min(velocity.y + GRAVITY * delta, MAX_FALL)
	# Move the CharacterBody2D using Godot's built-in sliding movement.
	move_and_slide()

	# floor_y is the highest y position the bubble's bottom edge may touch.
	var floor_y := viewport_size.y - 118.0
	# If the bubble's bottom edge has gone below the floor, push it back up.
	if position.y + radius > floor_y:
		# Place the bubble exactly on top of the floor.
		position.y = floor_y - radius
		# Bounce upward from the floor.
		velocity.y = FLOOR_BOUNCE
	# If the bubble's top edge goes above the screen, clamp it inside the screen.
	if position.y - radius < 0.0:
		# Put the bubble exactly at the top boundary.
		position.y = radius
		# Give it a small downward velocity so it does not stick to the top.
		velocity.y = 90.0

# pop() is called by obstacles when they collide with the bubble.
func pop() -> void:
	# If pop() is called again after the bubble is already dead, do nothing.
	if not alive:
		return
	# Mark the bubble as no longer alive.
	alive = false
	# Fade the bubble to show it has popped.
	modulate.a = 0.38
	# Tell any connected script, such as main.gd, that the bubble popped.
	popped.emit()

# _draw() creates the bubble's visual appearance using simple 2D drawing commands.
func _draw() -> void:
	# Draw the transparent blue body of the bubble.
	draw_circle(Vector2.ZERO, radius, Color(0.55, 0.9, 1.0, 0.38))
	# Draw a bright outline around the bubble.
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 80, Color("#dbfbff"), 4.0, true)
	# Draw a small white highlight near the upper-left side.
	draw_circle(Vector2(-10, -12), 8.0, Color(1.0, 1.0, 1.0, 0.72))
	# Draw a curved lower highlight to make the bubble feel glossy.
	draw_arc(Vector2(5, 9), 16.0, 0.35, 2.55, 28, Color(1.0, 1.0, 1.0, 0.36), 3.0, true)
