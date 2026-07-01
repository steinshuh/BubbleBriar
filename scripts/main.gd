# This script controls the whole game scene.
# It is attached to the root Node2D in scenes/Main.tscn.
extends Node2D

# preload() loads another script before the game starts using it.
# This constant lets us create new background layer objects in code.
const BackgroundLayer := preload("res://scripts/background_layer.gd")
# These constants preload reusable obstacle scenes that are spawned during gameplay.
const MosquitoScene := preload("res://scenes/Mosquito.tscn")
const SharpPlantScene := preload("res://scenes/SharpPlant.tscn")

# BASE_SCROLL_SPEED is the continual forward speed of the bubble through the world.
# The bubble stays fixed on screen, so this speed is shown by scrolling the world left.
const BASE_SCROLL_SPEED := 245.0
# RATE_ADJUST_ACCEL is how quickly holding Left/Right changes the temporary speed adjustment.
const RATE_ADJUST_ACCEL := 360.0
# RATE_ADJUST_RETURN is how quickly the temporary adjustment eases back to 0 when no key is held.
const RATE_ADJUST_RETURN := 220.0
# MAX_SPEED_BONUS is the largest temporary speed increase above BASE_SCROLL_SPEED.
const MAX_SPEED_BONUS := 220.0
# MAX_SPEED_PENALTY is the largest temporary speed decrease below BASE_SCROLL_SPEED.
const MAX_SPEED_PENALTY := -150.0
# SPAWN_MIN is the shortest time, in seconds, between obstacle spawns at baseline speed.
const SPAWN_MIN := 1.05
# SPAWN_MAX is the longest time, in seconds, between obstacle spawns at baseline speed.
const SPAWN_MAX := 1.72

# viewport_size stores the current window/game area size.
# The default value is only a fallback before _ready() reads the real viewport size.
var viewport_size := Vector2(1280, 720)
# bubble points to the Bubble scene instance placed directly in Main.tscn.
@onready var bubble: CharacterBody2D = $Bubble
# background_music_1 points to the first AudioStreamPlayer child in Main.tscn.
# Its WAV file is assigned in the scene instead of loaded by this script.
@onready var background_music_1 := $BackgroundMusic1 as AudioStreamPlayer
# background_music_2 points to the second AudioStreamPlayer child in Main.tscn.
# The script alternates between this player and background_music_1.
@onready var background_music_2 := $BackgroundMusic2 as AudioStreamPlayer
# point_sound points to the AudioStreamPlayer child that plays when the player earns a point.
# The bell WAV is assigned in Main.tscn, so this script does not load audio files.
@onready var point_sound := $PointSound as AudioStreamPlayer
# background_layers stores the four parallax layer nodes so their speed can be updated.
var background_layers: Array[Node2D] = []
# current_scroll_speed is the player's effective horizontal speed through the world.
# The bubble's x position stays constant; this speed moves the world instead.
var current_scroll_speed := BASE_SCROLL_SPEED
# speed_adjustment is a temporary offset caused by holding Left/Right.
# It returns to 0 when the player releases horizontal input.
var speed_adjustment := 0.0
# spawn_timer counts down every frame until it reaches zero and creates an obstacle.
var spawn_timer := 0.0
# score counts how many times the bubble has bounced off the ground.
var score := 0
# best_score remembers the best score reached during this play session.
var best_score := 0
# game_over is true after the bubble pops and false while a run is active.
var game_over := false
# obstacles stores all active obstacle nodes so the main script can score and clear them.
var obstacles: Array[Area2D] = []
# current_background_music_index remembers which background track should play next.
# 0 means background_music_1; 1 means background_music_2.
var current_background_music_index := 0

# score_label is the UI text in the top-left corner.
var score_label: Label
# speed_label is the UI text that shows the current continual forward scroll speed.
var speed_label: Label
# prompt_label is the centered UI text for controls and game-over messages.
var prompt_label: Label

# _ready() is a Godot lifecycle function.
# Godot calls it one time after this node has entered the scene tree.
func _ready() -> void:
	# Seed Godot's random number generator so obstacle timing and type are varied.
	randomize()
	# Read the actual viewport size from Godot instead of relying on the fallback value.
	viewport_size = get_viewport_rect().size
	# Connect Godot's size_changed signal to our function so the UI adapts when the window resizes.
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	# Create and add the parallax background layers.
	_build_world()
	# Create and add the score, speed, and prompt UI labels.
	_build_ui()
	# Connect and start alternating background music tracks.
	_start_background_music()
	# Start the first run by resetting score, bubble position, timers, and prompts.
	_start_run()

# _start_background_music() connects the two music players and starts the first track.
func _start_background_music() -> void:
	# Connect background_music_1's finished signal only if it has not already been connected.
	if not background_music_1.finished.is_connected(_on_background_music_finished):
		# When track 1 finishes, Godot calls _on_background_music_finished().
		background_music_1.finished.connect(_on_background_music_finished)
	# Connect background_music_2's finished signal only if it has not already been connected.
	if not background_music_2.finished.is_connected(_on_background_music_finished):
		# When track 2 finishes, Godot calls the same function so the tracks can alternate forever.
		background_music_2.finished.connect(_on_background_music_finished)
	# Start with the first background track whenever the main scene is created.
	current_background_music_index = 0
	# Play the selected track.
	_play_current_background_music()

# _play_current_background_music() starts whichever background track current_background_music_index selects.
func _play_current_background_music() -> void:
	# Stop both players first so only one background song can be heard at a time.
	background_music_1.stop()
	background_music_2.stop()
	# If the selected index is 0, play background1.wav.
	if current_background_music_index == 0:
		# Start the first background track from its beginning.
		background_music_1.play()
	# Otherwise, play background2.wav.
	else:
		# Start the second background track from its beginning.
		background_music_2.play()

# _on_background_music_finished() runs whenever the active background track reaches its end.
func _on_background_music_finished() -> void:
	# Flip 0 to 1 or 1 to 0 so the next track alternates from the one that just ended.
	current_background_music_index = 1 - current_background_music_index
	# Start the newly selected track.
	_play_current_background_music()

# _process(delta) is called once per rendered frame.
# delta is the amount of time, in seconds, since the previous frame.
func _process(delta: float) -> void:
	# If the run is over, the only thing we check for is restart input.
	if game_over:
		# is_action_just_pressed() is true only on the frame the player first presses the action.
		# "bounce" covers Space, Up, and mouse click from project.godot.
		# "ui_accept" is Godot's built-in accept action and gives us extra keyboard compatibility.
		if Input.is_action_just_pressed("bounce") or Input.is_action_just_pressed("ui_accept"):
			# Start a fresh run when the player presses the restart input.
			_start_run()
		# Stop here so no obstacles spawn and no score changes while the game is over.
		return

	# Read Left/Right input and update the temporary world-speed adjustment.
	_update_scroll_speed(delta)
	# Send the new scroll speed to all parallax layers and active obstacles.
	_apply_scroll_speed()
	# Update the visible speed label so the player can see the temporary rate change.
	_update_speed_label()

	# Scale spawn countdown by speed so faster travel produces obstacles sooner by distance.
	spawn_timer -= delta * (current_scroll_speed / BASE_SCROLL_SPEED)
	# When the timer reaches zero or below, it is time to create a new obstacle.
	if spawn_timer <= 0.0:
		# Add either a plant or mosquito to the scene.
		_spawn_obstacle()
		# Pick a new random wait time before the next obstacle appears.
		spawn_timer = randf_range(SPAWN_MIN, SPAWN_MAX)


# _update_scroll_speed() changes the temporary world-speed adjustment from keyboard input.
func _update_scroll_speed(delta: float) -> void:
	# input_direction will be 1 for faster, -1 for slower, and 0 for no horizontal input.
	var input_direction := 0.0
	# Right arrow or D means temporarily increase the forward rate.
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		input_direction += 1.0
	# Left arrow or A means temporarily decrease the forward rate.
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		input_direction -= 1.0
	# If the player is pressing Left or Right, move the temporary adjustment in that direction.
	if input_direction != 0.0:
		speed_adjustment += input_direction * RATE_ADJUST_ACCEL * delta
	# If no horizontal key is held, ease the adjustment back to 0 so baseline motion resumes.
	else:
		speed_adjustment = move_toward(speed_adjustment, 0.0, RATE_ADJUST_RETURN * delta)
	# Keep the temporary adjustment inside its allowed slower/faster range.
	speed_adjustment = clamp(speed_adjustment, MAX_SPEED_PENALTY, MAX_SPEED_BONUS)
	# The bubble always moves forward because the baseline speed is always included.
	current_scroll_speed = BASE_SCROLL_SPEED + speed_adjustment

# _apply_scroll_speed() sends current_scroll_speed to every node that scrolls horizontally.
func _apply_scroll_speed() -> void:
	# Update all four parallax background layers.
	for layer in background_layers:
		# set_scroll_speed() is defined in background_layer.gd.
		layer.set_scroll_speed(current_scroll_speed)
	# Update every active obstacle so hazards move with the same immediate foreground speed.
	for obstacle in obstacles:
		# Obstacle speed is always positive because the world continually moves forward.
		obstacle.set("speed", current_scroll_speed)

# _update_speed_label() displays current scroll speed in the UI.
func _update_speed_label() -> void:
	# Show the actual continual forward speed after temporary Left/Right adjustment.
	speed_label.text = "Forward %.0f px/s" % current_scroll_speed

# _build_world() creates gameplay objects that are still generated from code.
func _build_world() -> void:
	# Each item has two values: the layer type and its notional distance in feet.
	# These feet values are reversed from the old speed factors using feet = 1 / factor:
	# old 0.22 becomes 4.54545 feet, old 0.55 becomes 1.81818 feet, and old 1.0 becomes 1 foot.
	# The stationary sky used old factor 0.0, so it uses 0 feet as a special "infinite distance" value.
	for data in [
		[0, 0.0],
		[1, 4.5454545],
		[2, 1.8181818],
		[3, 1.0],
	]:
		# Create a new background layer node from the preloaded script.
		var layer := BackgroundLayer.new()
		# Tell the layer what to draw, how far away it is, current speed, and viewport size.
		layer.setup(data[0], data[1], current_scroll_speed, viewport_size)
		# Keep generated background layers visually behind the Bubble child that is already in Main.tscn.
		layer.z_index = -100 + int(data[0])
		# Remember the layer so we can update its speed when the rate adjustment changes.
		background_layers.append(layer)
		# Add the layer to the scene so Godot processes and draws it.
		add_child(layer)

	# The Bubble node is already instanced in Main.tscn, so this script only connects and resets it.
	bubble.setup(viewport_size)
	# Connect the bubble's popped signal to our game-over function.
	bubble.popped.connect(_on_bubble_popped)
	# Connect the bubble's ground_bounced signal so score changes only when the bubble hits the ground.
	bubble.ground_bounced.connect(_on_bubble_ground_bounced)

# _build_ui() creates labels for score, speed, instructions, and game-over text.
func _build_ui() -> void:
	# CanvasLayer keeps UI drawn over the world and independent of world nodes.
	var ui := CanvasLayer.new()
	# Add the CanvasLayer to the scene tree.
	add_child(ui)

	# Create the score label object.
	score_label = Label.new()
	# Place it near the top-left corner.
	score_label.position = Vector2(28, 22)
	# Increase the font size so it is readable during play.
	score_label.add_theme_font_size_override("font_size", 32)
	# Use a dark blue color that contrasts with the sky.
	score_label.add_theme_color_override("font_color", Color("#17324d"))
	# Set the initial text before the run starts.
	score_label.text = "Score 0"
	# Add the score label to the UI layer.
	ui.add_child(score_label)

	# Create the speed label object.
	speed_label = Label.new()
	# Put the speed label under the score.
	speed_label.position = Vector2(28, 60)
	# Make it a little smaller than the score.
	speed_label.add_theme_font_size_override("font_size", 22)
	# Use the same dark blue as other UI text.
	speed_label.add_theme_color_override("font_color", Color("#17324d"))
	# Set initial text before the first frame updates it.
	speed_label.text = "Forward 245 px/s"
	# Add the speed label to the UI layer.
	ui.add_child(speed_label)

	# Create the prompt label for instructions and game-over messages.
	prompt_label = Label.new()
	# Center text horizontally inside the label rectangle.
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Center text vertically inside the label rectangle.
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Make the prompt large enough to read clearly.
	prompt_label.add_theme_font_size_override("font_size", 30)
	# Use the same dark blue as the score.
	prompt_label.add_theme_color_override("font_color", Color("#17324d"))
	# Make the label as wide as the viewport so centering works across the screen.
	prompt_label.size = Vector2(viewport_size.x, 120)
	# Put the label somewhat above the vertical center.
	prompt_label.position = Vector2(0, viewport_size.y * 0.34)
	# Add the prompt label to the UI layer.
	ui.add_child(prompt_label)

# _start_run() resets the game state for a new attempt.
func _start_run() -> void:
	# Remove every old obstacle from the previous run.
	for obstacle in obstacles:
		# is_instance_valid() makes sure the node still exists before freeing it.
		if is_instance_valid(obstacle):
			# queue_free() asks Godot to safely delete the node at the end of the frame.
			obstacle.queue_free()
	# Empty the list because all old obstacles are gone.
	obstacles.clear()
	# Reset the current score.
	score = 0
	# Mark the game as active again.
	game_over = false
	# Reset the temporary rate adjustment so the run starts at baseline speed.
	speed_adjustment = 0.0
	# Reset scroll speed to the baseline speed.
	current_scroll_speed = BASE_SCROLL_SPEED
	# Send the reset speed to layers before the first new obstacle appears.
	_apply_scroll_speed()
	# Spawn the first obstacle shortly after the run begins.
	spawn_timer = 0.7
	# Reset the visible score text.
	score_label.text = "Score 0"
	# Reset the visible speed text.
	_update_speed_label()
	# Show the controls briefly at the beginning of a run.
	prompt_label.text = "Space/Up/click bounce\nRight/D speed up, Left/A slow down"
	# Reset the bubble's position, movement, opacity, and alive state.
	bubble.setup(viewport_size)
	# Wait 1.6 seconds before hiding the prompt.
	await get_tree().create_timer(1.6).timeout
	# Only hide the prompt if the bubble did not pop during that waiting period.
	if not game_over:
		# Clear the prompt text so it does not block the view.
		prompt_label.text = ""

# _spawn_obstacle() creates one new plant or mosquito just off the right side of the screen.
func _spawn_obstacle() -> void:
	# Choose a plant 58% of the time and a mosquito 42% of the time.
	var obstacle_scene := SharpPlantScene if randf() < 0.58 else MosquitoScene
	# Create the obstacle node from the chosen scene.
	var obstacle := obstacle_scene.instantiate() as Area2D
	# Position the obstacle slightly beyond the right edge so it scrolls into view.
	obstacle.call("setup", viewport_size.x + 90.0, viewport_size, current_scroll_speed)
	# Mosquitoes need the bubble position so their loop volume can react to distance.
	if obstacle.has_method("set_bubble_target"):
		# Sharp plants do not have this method, so only mosquitoes receive the bubble reference.
		obstacle.call("set_bubble_target", bubble)
	# Connect the obstacle's escaped signal so we know when to remove it.
	obstacle.connect("escaped", Callable(self, "_on_obstacle_escaped"))
	# Store it in the active obstacles list for scoring and cleanup.
	obstacles.append(obstacle)
	# Add it to the scene so Godot processes, collides, and draws it.
	add_child(obstacle)

# _on_bubble_ground_bounced() runs when the living bubble hits the floor and bounces upward.
func _on_bubble_ground_bounced() -> void:
	# Do not award points after game over, even if a late signal somehow arrives.
	if game_over:
		return
	# Add one point for this ground bounce.
	score += 1
	# Restart the point sound so quick repeated bounces still play the bell clearly.
	point_sound.stop()
	# Play the small soft bell ring assigned in the Main scene.
	point_sound.play()
	# Update the visible score text.
	score_label.text = "Score %d" % score

# _on_obstacle_escaped() runs when an obstacle moves off the left edge.
func _on_obstacle_escaped(obstacle: Area2D) -> void:
	# Remove the obstacle from our list of active obstacles.
	obstacles.erase(obstacle)
	# Delete the obstacle node from the scene.
	obstacle.queue_free()

# _on_bubble_popped() runs when the bubble emits its popped signal.
func _on_bubble_popped() -> void:
	# Switch the game into game-over mode.
	game_over = true
	# Keep the larger value: the previous best or the score from this run.
	best_score = max(best_score, score)
	# Show the final score, best score, and restart instruction.
	prompt_label.text = "Bubble popped\nScore %d  Best %d\nPress Space, Up, or click" % [score, best_score]

# _on_viewport_size_changed() runs when the game window size changes.
func _on_viewport_size_changed() -> void:
	# Read the new viewport size from Godot.
	viewport_size = get_viewport_rect().size
	# The prompt label may not exist yet if this fires very early, so check it first.
	if prompt_label:
		# Resize the prompt label to match the new viewport width.
		prompt_label.size = Vector2(viewport_size.x, 120)
		# Move the prompt label to the same relative vertical position in the new window.
		prompt_label.position = Vector2(0, viewport_size.y * 0.34)
