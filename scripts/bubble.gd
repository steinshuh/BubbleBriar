# This script controls the player character: the bubble.
# CharacterBody2D gives us velocity and move_and_slide(), which are useful for movement.
extends CharacterBody2D

# popped is a custom signal.
# Other scripts can connect to it and react when the bubble pops.
signal popped
# ground_bounced is a custom signal.
# Main listens for it and awards one point when the bubble bounces off the ground.
signal ground_bounced

# GRAVITY is how quickly the bubble accelerates downward.
const GRAVITY := 920.0
# BOUNCE_VELOCITY is the upward speed applied when the player presses the bounce button.
# It is negative because in Godot 2D, smaller y values are higher on the screen.
const BOUNCE_VELOCITY := -420.0
# FLOOR_BOUNCE is the stronger upward speed applied when the bubble hits the floor.
const FLOOR_BOUNCE := -520.0
# MAX_FALL prevents the bubble from falling infinitely faster over time.
const MAX_FALL := 650.0
# POP_ANIMATION_FRAME_COUNT is the number of frames in bubble_sheet.png.
# The sheet has 2 rows and 4 columns, so it contains 8 frames.
const POP_ANIMATION_FRAME_COUNT := 8
# POP_ANIMATION_FRAME_TIME is how long each pop frame stays visible.
# Smaller numbers make the pop animation finish faster.
const POP_ANIMATION_FRAME_TIME := 0.07
# POP_FRAME_SCALE_MULTIPLIER controls how much larger each pop frame is than the previous frame.
# 1.10 means frame 1 is 10% larger than frame 0, frame 2 is 10% larger than frame 1, and so on.
const POP_FRAME_SCALE_MULTIPLIER := 1.3

# radius controls both the drawn bubble size and the collision circle size.
var radius := 31.0
# alive is true during active play and false after the bubble pops.
var alive := true
# fixed_x is the horizontal screen position where the bubble should stay anchored.
var fixed_x := 0.0
# viewport_size stores the game window size so the bubble can stay inside it.
var viewport_size := Vector2(1280, 720)
# pop_animation_time stores how much time has accumulated toward the next pop frame.
var pop_animation_time := 0.0
# pop_animation_frame stores which frame of the bubble sheet is currently visible.
var pop_animation_frame := 0
# pop_animation_playing is true only while the bubble is playing its pop animation.
var pop_animation_playing := false
# normal_sprite_scale remembers the Sprite2D scale from the Bubble scene.
# The pop animation grows from this size and setup() restores this size for normal play.
var normal_sprite_scale := Vector2.ONE
# sprite points to the Sprite2D child in scenes/Bubble.tscn.
# The texture is assigned in the scene, so this script does not load image files.
@onready var sprite := $Sprite2D as Sprite2D
# pop_sound points to the AudioStreamPlayer2D child that plays the bubble pop sound.
# The WAV file is assigned in scenes/Bubble.tscn, so this script does not load audio files.
@onready var pop_sound := $PopSound as AudioStreamPlayer2D
# breeze_sound points to the AudioStreamPlayer2D child that plays when the player bounces.
# The WAV file is assigned in scenes/Bubble.tscn, so this script does not load audio files.
@onready var breeze_sound := $BreezeSound as AudioStreamPlayer2D

# _ready() runs once when the bubble enters the scene tree.
func _ready() -> void:
	# The reusable Bubble scene already contains a CollisionShape2D child.
	var collider := get_node_or_null("CollisionShape2D") as CollisionShape2D
	# If the scene has the expected collision shape, keep its radius matched to the script radius.
	if collider and collider.shape is CircleShape2D:
		collider.shape.radius = radius
	# Remember the normal scene scale before any pop animation changes it.
	normal_sprite_scale = sprite.scale
	# Frame 0 is the full bubble frame used during normal play.
	sprite.frame = 0
	# Make sure the bubble starts at the normal scene scale.
	sprite.scale = normal_sprite_scale

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
	# Stop any old pop animation from a previous run.
	pop_animation_playing = false
	# Reset the pop animation timer so the next pop starts cleanly.
	pop_animation_time = 0.0
	# Reset the remembered frame number to the full-bubble frame.
	pop_animation_frame = 0
	# Show the full bubble frame while the bubble is alive.
	sprite.frame = 0
	# Restore the normal sprite scale in case the previous run ended during the growing pop animation.
	sprite.scale = normal_sprite_scale
	# Restore the normal bubble opacity for a fresh run.
	modulate.a = 0.7

# _physics_process(delta) runs on Godot's fixed physics tick.
# Physics movement belongs here because it stays stable even when frame rate changes.
func _physics_process(delta: float) -> void:
	# If the bubble has popped, it no longer accepts input or bounces off bounds.
	if not alive:
		# Continue the pop animation after death until it reaches the last frame.
		_advance_pop_animation(delta)
		# Still apply gravity so the popped bubble continues drifting after the pop.
		velocity.y += GRAVITY * delta
		# Move according to the reduced pop velocity and ongoing gravity.
		move_and_slide()
		# Keep the popped bubble horizontally anchored too; the world scrolls instead of the character.
		position.x = fixed_x
		# Stop here so the living-bubble logic below does not run.
		return

	# Check whether the player pressed the bounce action during this physics tick.
	if Input.is_action_just_pressed("bounce") or Input.is_action_just_pressed("ui_accept"):
		# Set upward velocity, creating the bounce/flap feeling.
		velocity.y = BOUNCE_VELOCITY
		# Restart the breeze sound so repeated player actions are audible immediately.
		breeze_sound.stop()
		# Play the soft breeze sound assigned in the Bubble scene.
		breeze_sound.play()

	# Add gravity to the vertical velocity, but do not let it exceed MAX_FALL.
	velocity.y = min(velocity.y + GRAVITY * delta, MAX_FALL)
	# Move the CharacterBody2D using Godot's built-in sliding movement.
	move_and_slide()
	# Keep the bubble's x coordinate constant; Left/Right input changes only the world scroll rate.
	position.x = fixed_x

	# floor_y is the lowest y position the bubble's bottom edge may touch before bouncing.
	# Subtracting 88 instead of 118 moves that bounce limit 30 pixels lower on the screen.
	var floor_y := viewport_size.y - 88.0
	# If the bubble's bottom edge has gone below the floor, push it back up.
	if position.y + radius > floor_y:
		# Place the bubble exactly on top of the floor.
		position.y = floor_y - radius
		# Bounce upward from the floor.
		velocity.y = FLOOR_BOUNCE
		# Tell the main scene that a real ground bounce happened, which is when scoring occurs.
		ground_bounced.emit()
	# If the bubble's top edge goes above the screen, clamp it inside the screen.
	if position.y - radius < 0.0:
		# Put the bubble exactly at the top boundary.
		position.y = radius
		# Give it a small downward velocity so it does not stick to the top.
		velocity.y = 90.0

# _advance_pop_animation() plays the bubble sheet from frame 0 to frame 7 after the bubble pops.
func _advance_pop_animation(delta: float) -> void:
	# If the pop animation has already reached its final frame, leave that final frame showing.
	if not pop_animation_playing:
		return
	# Add this physics tick's elapsed time to the pop animation timer.
	pop_animation_time += delta
	# Use a while loop so the animation can catch up if a frame takes longer than expected.
	while pop_animation_time >= POP_ANIMATION_FRAME_TIME and pop_animation_playing:
		# Remove one animation-frame duration from the timer.
		pop_animation_time -= POP_ANIMATION_FRAME_TIME
		# If the next frame would still be inside the 0..7 sheet range, advance to it.
		if pop_animation_frame < POP_ANIMATION_FRAME_COUNT - 1:
			# Move to the next frame in the 2-by-4 bubble sheet.
			pop_animation_frame += 1
			# Show the newly selected pop frame.
			_apply_pop_frame_visuals()
		else:
			# The animation has reached frame 7, so stop changing frames.
			pop_animation_playing = false

# _apply_pop_frame_visuals() makes the current pop frame visible and scales it for the pop effect.
func _apply_pop_frame_visuals() -> void:
	# Show the selected frame from the 2-by-4 bubble sheet.
	sprite.frame = pop_animation_frame
	# scale_factor grows by 10% per frame: frame 0 is 1.0, frame 1 is 1.1, frame 2 is 1.21, etc.
	var scale_factor: float = pow(POP_FRAME_SCALE_MULTIPLIER, pop_animation_frame)
	# Apply the growth relative to the normal sprite scale saved from Bubble.tscn.
	sprite.scale = normal_sprite_scale * scale_factor
# pop() is called by obstacles when they collide with the bubble.
func pop() -> void:
	# If pop() is called again after the bubble is already dead, do nothing.
	# _physics_process() is already advancing any in-progress pop animation.
	if not alive:
		return
	# Mark the bubble as no longer alive.
	alive = false
	# Cut the current vertical speed in half so the pop slows the bubble without freezing it.
	velocity.y *= 0.5
	# Keep horizontal movement at zero because the world scrolls instead of the character.
	velocity.x = 0.0
	# Keep the normal alpha so the pop animation artwork stays visible.
	modulate.a = 0.7
	# Start the pop animation at the first frame of the sheet.
	pop_animation_playing = true
	# Reset the timer so frame 0 stays visible for a full animation step.
	pop_animation_time = 0.0
	# Frame 0 is the whole bubble, and frames 1 through 7 show the pop sequence.
	pop_animation_frame = 0
	# Show frame 0 immediately when the bubble pops.
	_apply_pop_frame_visuals()
	# Restart the pop sound from the beginning in case this Bubble node was reused after a reset.
	pop_sound.stop()
	# Play the bubble popping WAV assigned in the Bubble scene.
	pop_sound.play()
	# Tell any connected script, such as main.gd, that the bubble popped.
	popped.emit()
