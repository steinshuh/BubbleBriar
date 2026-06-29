# This script controls the whole game scene.
# It is attached to the root Node2D in scenes/Main.tscn.
extends Node2D

# preload() loads another script before the game starts using it.
# These constants let us create new background, bubble, and obstacle objects in code.
const BackgroundLayer := preload("res://scripts/background_layer.gd")
const Bubble := preload("res://scripts/bubble.gd")
const Obstacle := preload("res://scripts/obstacle.gd")

# BASE_SPEED is the main leftward scrolling speed for the game world.
const BASE_SPEED := 245.0
# SPAWN_MIN is the shortest time, in seconds, between obstacle spawns.
const SPAWN_MIN := 1.05
# SPAWN_MAX is the longest time, in seconds, between obstacle spawns.
const SPAWN_MAX := 1.72

# viewport_size stores the current window/game area size.
# The default value is only a fallback before _ready() reads the real viewport size.
var viewport_size := Vector2(1280, 720)
# bubble will point to the player's Bubble node after _build_world() creates it.
var bubble: CharacterBody2D
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
	# Create and add the score and prompt UI labels.
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

	# Count down the obstacle spawn timer by the time that passed this frame.
	spawn_timer -= delta
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

# _build_world() creates the gameplay objects that are not already placed in Main.tscn.
func _build_world() -> void:
	# Each item has two values: the layer type and its speed factor.
	# A speed factor of 0.0 means stationary. A factor of 1.0 means full game speed.
	for data in [
		[0, 0.0],
		[1, 0.22],
		[2, 0.55],
		[3, 1.0],
	]:
		# Create a new background layer node from the preloaded script.
		var layer := BackgroundLayer.new()
		# Tell the layer what to draw, how fast to move, and how large the viewport is.
		layer.setup(data[0], data[1], BASE_SPEED, viewport_size)
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

# _build_ui() creates labels for score, instructions, and game-over text.
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
	prompt_label.size = Vector2(viewport_size.x, 100)
	# Put the label somewhat above the vertical center.
	prompt_label.position = Vector2(0, viewport_size.y * 0.38)
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
	# Spawn the first obstacle shortly after the run begins.
	spawn_timer = 0.7
	# Reset the visible score text.
	score_label.text = "Score 0"
	# Show the controls briefly at the beginning of a run.
	prompt_label.text = "Space, Up, or click to bounce"
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
	obstacle.setup(kind, viewport_size.x + 90.0, viewport_size, BASE_SPEED)
	# Connect the obstacle's escaped signal so we know when to remove it.
	obstacle.escaped.connect(_on_obstacle_escaped)
	# Store it in the active obstacles list for scoring and cleanup.
	obstacles.append(obstacle)
	# Add it to the scene so Godot processes, collides, and draws it.
	add_child(obstacle)

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
		prompt_label.position = Vector2(0, viewport_size.y * 0.38)
