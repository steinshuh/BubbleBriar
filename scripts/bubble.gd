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
# fixed_x is the horizontal screen position where the bubble should stay anchored.
var fixed_x := 0.0
# viewport_size stores the game window size so the bubble can stay inside it.
var viewport_size := Vector2(1280, 720)

# _ready() runs once when the bubble enters the scene tree.
func _ready() -> void:
	# The reusable Bubble scene already contains a CollisionShape2D child.
	var collider := get_node_or_null("CollisionShape2D") as CollisionShape2D
	# If the scene has the expected collision shape, keep its radius matched to the script radius.
	if collider and collider.shape is CircleShape2D:
		collider.shape.radius = radius

# setup() resets the bubble for a new run.
func setup(size: Vector2) -> void:
	# Store the current viewport size.
	viewport_size = size
	# Store the constant x position for the bubble.
	fixed_x = size.x * 0.24
	# Place the bubble at its fixed x position and near the vertical middle.
	position = Vector2(fixed_x, size.y * 0.45)
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
		# Keep the popped bubble horizontally anchored too; the world scrolls instead of the character.
		position.x = fixed_x
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
	# Keep the bubble's x coordinate constant; Left/Right input changes only the world scroll rate.
	position.x = fixed_x

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
