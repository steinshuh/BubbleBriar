# This script controls the whole game scene.
# It is attached to the root Node2D in scenes/Main.tscn.
extends Node2D

# preload() loads another script before the game starts using it.
# These constants let us create new background, bubble, and obstacle objects in code.
const BackgroundLayer := preload("res://scripts/background_layer.gd")
const Bubble := preload("res://scripts/bubble.gd")
const Obstacle := preload("res://scripts/obstacle.gd")

# START_SCROLL_SPEED is the speed the game uses at the start of each run.
# It matches the old fixed BASE_SPEED value so the game initially feels the same as before.
const START_SCROLL_SPEED := 245.0
# ACCELERATION is how quickly holding forward/backward changes the scroll speed.
const ACCELERATION := 360.0
# DRAG is how quickly the scroll speed eases back toward 0 when no horizontal key is held.
const DRAG := 120.0
# MAX_FORWARD_SPEED is the fastest forward scroll speed.
const MAX_FORWARD_SPEED := 520.0
# MAX_BACKWARD_SPEED is the fastest backward scroll speed.
const MAX_BACKWARD_SPEED := -260.0
# SPAWN_MIN is the shortest time, in seconds, between obstacle spawns at starting speed.
const SPAWN_MIN := 1.05
# SPAWN_MAX is the longest time, in seconds, between obstacle spawns at starting speed.
const SPAWN_MAX := 1.72

# viewport_size stores the current window/game area size.
# The default value is only a fallback before _ready() reads the real viewport size.
var viewport_size := Vector2(1280, 720)
# bubble will point to the player's Bubble node after _build_world() creates it.
var bubble: CharacterBody2D
# background_layers stores the four parallax layer nodes so their speed can be updated.
var background_layers: Array[Node2D] = []
# current_scroll_speed is the player's effective horizontal speed through the world.
# The bubble's x position stays constant; this speed moves the world instead.
var current_scroll_speed := START_SCROLL_SPEED
# spawn_timer counts down every frame until it reaches zero and creates an obstacle.
var spawn_timer := 0.0
# score counts how many obstacles the bubble has successfully passed.
var score := 0
# best_score remembers the best score reached during this play session.
var best_score := 0
# game_over is true after the bubble pops and false while a run is active.
var game_over := false
# obstacles stores all active obstacle nodes so the main script can score and clear them.
var obstacles: Array[Area2D] = []

# score_label is the UI text in the top-left corner.
var score_label: Label
# speed_label is the UI text that shows the current forward/backward scroll speed.
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
	# Create and add the parallax background layers and the player bubble.
	_build_world()
	# Create and add the score, speed, and prompt UI labels.
	_build_ui()
	# Start the first run by resetting score, bubble position, timers, and prompts.
	_start_run()

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

	# Read acceleration input and update the world scroll speed.
	_update_scroll_speed(delta)
	# Send the new scroll speed to all parallax layers and active obstacles.
	_apply_scroll_speed()
	# Update the visible speed label so the player can see forward/backward movement.
	_update_speed_label()

	# Only count spawn time while the player is moving forward.
	# Backward movement scrolls existing objects back to the right instead of creating new hazards.
	if current_scroll_speed > 0.0:
		# Scale spawn countdown by speed so faster travel produces obstacles sooner by distance.
		spawn_timer -= delta * (current_scroll_speed / START_SCROLL_SPEED)
	# When the timer reaches zero or below, it is time to create a new obstacle.
	if spawn_timer <= 0.0:
		# Add either a plant or mosquito to the scene.
		_spawn_obstacle()
		# Pick a new random wait time before the next obstacle appears.
		spawn_timer = randf_range(SPAWN_MIN, SPAWN_MAX)

	# Check every active obstacle to see if the bubble has passed it.
	for obstacle in obstacles:
		# obstacle.passed prevents one obstacle from giving points more than once.
		# obstacle.position.x < bubble.position.x means the obstacle moved left of the bubble.
		if not obstacle.passed and obstacle.position.x < bubble.position.x:
			# Mark this obstacle as already scored.
			obstacle.passed = true
			# Add one point for passing the obstacle.
			score += 1
			# Update the visible score text.
			score_label.text = "Score %d" % score

# _update_scroll_speed() changes world speed from keyboard input.
func _update_scroll_speed(delta: float) -> void:
	# input_direction will be 1 for forward, -1 for backward, and 0 for no horizontal input.
	var input_direction := 0.0
	# Right arrow or D means accelerate forward through the level.
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		input_direction += 1.0
	# Left arrow or A means accelerate backward through the level.
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		input_direction -= 1.0
	# If the player is pressing forward or backward, accelerate in that direction.
	if input_direction != 0.0:
		current_scroll_speed += input_direction * ACCELERATION * delta
	# If no horizontal key is held, gradually reduce speed toward 0.
	else:
		current_scroll_speed = move_toward(current_scroll_speed, 0.0, DRAG * delta)
	# Keep speed inside the allowed backward and forward limits.
	current_scroll_speed = clamp(current_scroll_speed, MAX_BACKWARD_SPEED, MAX_FORWARD_SPEED)

# _apply_scroll_speed() sends current_scroll_speed to every node that scrolls horizontally.
func _apply_scroll_speed() -> void:
	# Update all four parallax background layers.
	for layer in background_layers:
		# set_scroll_speed() is defined in background_layer.gd.
		layer.set_scroll_speed(current_scroll_speed)
	# Update every active obstacle so hazards move with the same immediate foreground speed.
	for obstacle in obstacles:
		# Obstacle speed can be positive or negative, which moves it left or right.
		obstacle.speed = current_scroll_speed

# _update_speed_label() displays current scroll speed in the UI.
func _update_speed_label() -> void:
	# Positive means forward, negative means backward.
	var direction := "Forward" if current_scroll_speed >= 0.0 else "Backward"
	# abs() hides the minus sign because the word already explains the direction.
	speed_label.text = "%s %.0f px/s" % [direction, abs(current_scroll_speed)]

# _build_world() creates the gameplay objects that are not already placed in Main.tscn.
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
		# Remember the layer so we can update its speed when the player accelerates.
		background_layers.append(layer)
		# Add the layer to the scene so Godot processes and draws it.
		add_child(layer)

	# Create the player bubble node from the preloaded script.
	bubble = Bubble.new()
	# Reset the bubble's position, velocity, and alive state.
	bubble.setup(viewport_size)
	# Connect the bubble's popped signal to our game-over function.
	bubble.popped.connect(_on_bubble_popped)
	# Add the bubble after the backgrounds so it draws in front of them.
	add_child(bubble)

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
	# Reset scroll speed to the old fixed speed so the beginning matches the original version.
	current_scroll_speed = START_SCROLL_SPEED
	# Send the reset speed to layers before the first new obstacle appears.
	_apply_scroll_speed()
	# Spawn the first obstacle shortly after the run begins.
	spawn_timer = 0.7
	# Reset the visible score text.
	score_label.text = "Score 0"
	# Reset the visible speed text.
	_update_speed_label()
	# Show the controls briefly at the beginning of a run.
	prompt_label.text = "Space/Up/click bounce\nRight/D accelerate forward, Left/A backward"
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
	# Create the obstacle node from the preloaded script.
	var obstacle := Obstacle.new()
	# Choose a plant 58% of the time and a mosquito 42% of the time.
	var kind := Obstacle.ObstacleKind.PLANT if randf() < 0.58 else Obstacle.ObstacleKind.MOSQUITO
	# Position the obstacle slightly beyond the right edge so it scrolls into view.
	obstacle.setup(kind, viewport_size.x + 90.0, viewport_size, current_scroll_speed)
	# Connect the obstacle's escaped signal so we know when to remove it.
	obstacle.escaped.connect(_on_obstacle_escaped)
	# Store it in the active obstacles list for scoring and cleanup.
	obstacles.append(obstacle)
	# Add it to the scene so Godot processes, collides, and draws it.
	add_child(obstacle)

# _on_obstacle_escaped() runs when an obstacle moves far off either horizontal edge.
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
