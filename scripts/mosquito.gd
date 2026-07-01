# This script controls one mosquito obstacle.
# It is attached to scenes/Mosquito.tscn.
extends Area2D

# MOSQUITO_ANIMATION_FRAME_COUNT is the number of pictures in mosquito_sheet.png.
# The sheet has 2 rows and 4 columns, so 2 * 4 = 8 animation frames.
const MOSQUITO_ANIMATION_FRAME_COUNT := 8
# MOSQUITO_ANIMATION_FRAME_TIME is how long one frame stays visible before moving to the next frame.
# Smaller numbers flap faster; 0.08 seconds gives about 12.5 frames per second.
const MOSQUITO_ANIMATION_FRAME_TIME := 0.08
# MOSQUITO_MAX_VOLUME_DB is the loudest mosquito sound volume when it is very close to the bubble.
const MOSQUITO_MAX_VOLUME_DB := -3.0
# MOSQUITO_MIN_VOLUME_DB is the quietest mosquito sound volume when it is far away from the bubble.
const MOSQUITO_MIN_VOLUME_DB := -36.0
# MOSQUITO_MAX_AUDIBLE_DISTANCE is the distance, in pixels, where the mosquito reaches minimum volume.
const MOSQUITO_MAX_AUDIBLE_DISTANCE := 720.0

# escaped is a custom signal emitted when the mosquito has moved off the left side.
# main.gd listens for this signal so it can delete the obstacle.
signal escaped(obstacle)

# speed controls how many pixels per second the mosquito moves left.
var speed := 230.0
# passed becomes true after the player earns a point for passing this mosquito.
var passed := false
# viewport_size stores the game window size so the mosquito can be positioned and cleaned up correctly.
var viewport_size := Vector2(1280, 720)
# bubble_target stores the player bubble node so this mosquito can measure distance to it.
var bubble_target: Node2D
# animation_time stores how many seconds have accumulated toward the next animation frame.
var animation_time := 0.0
# animation_frame stores which frame number from the sprite sheet is currently showing.
var animation_frame := 0
# sprite points to the Sprite2D child in scenes/Mosquito.tscn.
# The texture itself is assigned in the scene, so this script does not load any image files.
@onready var sprite := $Sprite2D as Sprite2D
# mosquito_sound points to the AudioStreamPlayer2D child in scenes/Mosquito.tscn.
# The WAV file is assigned in the scene, so this script does not load audio files.
@onready var mosquito_sound := $MosquitoSound as AudioStreamPlayer2D

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

# set_bubble_target() is called by main.gd after this mosquito is created.
# The mosquito uses the target position to make its looping sound louder when it is closer.
func set_bubble_target(target: Node2D) -> void:
	# Store the bubble reference for later distance checks in _update_sound_volume().
	bubble_target = target
	# If this node is already ready, update the volume immediately.
	# During spawning, main.gd calls this before _ready(), so the sound node may not exist yet.
	if is_node_ready():
		_update_sound_volume()

# _ready() runs once when the mosquito enters the scene tree.
func _ready() -> void:
	# Start the mosquito animation on the first frame whenever a mosquito is created.
	animation_frame = 0
	# Show the first frame immediately so the mosquito does not wait for the first timer step.
	sprite.frame = animation_frame
	# body_entered is a built-in Area2D signal.
	# It fires when a physics body, like the bubble, enters this mosquito's collision area.
	body_entered.connect(_on_body_entered)
	# Connect the sound's finished signal so the mosquito sound loops for this mosquito instance.
	mosquito_sound.finished.connect(_on_mosquito_sound_finished)
	# Start the mosquito sound loop as soon as this mosquito enters the scene.
	mosquito_sound.play()
	# Set the starting volume before the first sound frame is heard.
	_update_sound_volume()

# _process(delta) runs every rendered frame.
func _process(delta: float) -> void:
	# Advance the wing-flap animation before moving the mosquito this frame.
	_advance_animation(delta)
	# Move the mosquito left by the current forward world speed.
	position.x -= speed * delta
	# Update the loop volume after movement so distance matches the mosquito's current position.
	_update_sound_volume()
	# Once the mosquito is far enough off the left side, tell main.gd it can be removed.
	if position.x < -120.0:
		escaped.emit(self)

# _update_sound_volume() changes this mosquito's loop volume based on distance to the bubble.
func _update_sound_volume() -> void:
	# If main.gd has not assigned the bubble yet, keep the mosquito quiet instead of erroring.
	if bubble_target == null:
		# Use the minimum volume until a target exists.
		mosquito_sound.volume_db = MOSQUITO_MIN_VOLUME_DB
		# Stop here because there is no distance to calculate.
		return
	# If the bubble was freed or is no longer valid, keep the mosquito quiet.
	if not is_instance_valid(bubble_target):
		# Use the minimum volume because the target is gone.
		mosquito_sound.volume_db = MOSQUITO_MIN_VOLUME_DB
		# Stop here because the old target cannot be used.
		return
	# distance_to_bubble is the current distance in pixels between this mosquito and the bubble.
	var distance_to_bubble: float = global_position.distance_to(bubble_target.global_position)
	# closeness is 1.0 when the mosquito is on top of the bubble and 0.0 at max audible distance.
	var closeness: float = 1.0 - clampf(distance_to_bubble / MOSQUITO_MAX_AUDIBLE_DISTANCE, 0.0, 1.0)
	# Convert closeness into decibels, using quiet volume far away and loud volume nearby.
	mosquito_sound.volume_db = lerpf(MOSQUITO_MIN_VOLUME_DB, MOSQUITO_MAX_VOLUME_DB, closeness)

# _on_mosquito_sound_finished() restarts the mosquito sound so it loops for this mosquito instance.
func _on_mosquito_sound_finished() -> void:
	# Play the same stream again from the beginning.
	mosquito_sound.play()

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
