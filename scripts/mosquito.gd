# This script controls one mosquito obstacle.
# It is attached to scenes/Mosquito.tscn.
extends Area2D

# MOSQUITO_ANIMATION_FRAME_COUNT is the number of pictures in mosquito_sheet.png.
# The sheet has 2 rows and 4 columns, so 2 * 4 = 8 animation frames.
const MOSQUITO_ANIMATION_FRAME_COUNT := 8
# MOSQUITO_ANIMATION_FRAME_TIME is how long one frame stays visible before moving to the next frame.
# Smaller numbers flap faster; 0.08 seconds gives about 12.5 frames per second.
const MOSQUITO_ANIMATION_FRAME_TIME := 0.08

# escaped is a custom signal emitted when the mosquito has moved off the left side.
# main.gd listens for this signal so it can delete the obstacle.
signal escaped(obstacle)

# speed controls how many pixels per second the mosquito moves left.
var speed := 230.0
# passed becomes true after the player earns a point for passing this mosquito.
var passed := false
# viewport_size stores the game window size so the mosquito can be positioned and cleaned up correctly.
var viewport_size := Vector2(1280, 720)
# animation_time stores how many seconds have accumulated toward the next animation frame.
var animation_time := 0.0
# animation_frame stores which frame number from the sprite sheet is currently showing.
var animation_frame := 0
# sprite points to the Sprite2D child in scenes/Mosquito.tscn.
# The texture itself is assigned in the scene, so this script does not load any image files.
@onready var sprite := $Sprite2D as Sprite2D

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

# _ready() runs once when the mosquito enters the scene tree.
func _ready() -> void:
	# Start the mosquito animation on the first frame whenever a mosquito is created.
	animation_frame = 0
	# Show the first frame immediately so the mosquito does not wait for the first timer step.
	sprite.frame = animation_frame
	# body_entered is a built-in Area2D signal.
	# It fires when a physics body, like the bubble, enters this mosquito's collision area.
	body_entered.connect(_on_body_entered)

# _process(delta) runs every rendered frame.
func _process(delta: float) -> void:
	# Advance the wing-flap animation before moving the mosquito this frame.
	_advance_animation(delta)
	# Move the mosquito left by the current forward world speed.
	position.x -= speed * delta
	# Once the mosquito is far enough off the left side, tell main.gd it can be removed.
	if position.x < -120.0:
		escaped.emit(self)

# _advance_animation() moves the Sprite2D to the next frame when enough time has passed.
func _advance_animation(delta: float) -> void:
	# Add this frame's elapsed time to the animation timer.
	animation_time += delta
	# Use a while loop so very slow frames can catch up by advancing more than one animation frame.
	while animation_time >= MOSQUITO_ANIMATION_FRAME_TIME:
		# Remove one frame's worth of time from the timer.
		animation_time -= MOSQUITO_ANIMATION_FRAME_TIME
		# Move to the next frame number, then wrap back to 0 after the last frame.
		animation_frame = (animation_frame + 1) % MOSQUITO_ANIMATION_FRAME_COUNT
		# Tell Sprite2D which cell of the 4-by-2 sprite sheet to draw.
		sprite.frame = animation_frame

# _on_body_entered() runs when something enters the mosquito's Area2D hitbox.
func _on_body_entered(body: Node) -> void:
	# Check for a pop() method so the mosquito can pop the bubble without depending on its exact class.
	if body.has_method("pop"):
		body.pop()

