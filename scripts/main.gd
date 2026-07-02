# This script controls the whole game scene.
# It is attached to the root Node2D in scenes/Main.tscn.
extends Node2D

# preload() loads another script before the game starts using it.
# This constant lets us create new background layer objects in code.
const BackgroundLayer := preload("res://scripts/background_layer.gd")
# These constants preload reusable obstacle scenes that are spawned during gameplay.
const MosquitoScene := preload("res://scenes/Mosquito.tscn")
const SharpPlantScene := preload("res://scenes/SharpPlant.tscn")
# TITLE_TEXTURE is the title image shown over the game when the scene first starts.
const TITLE_TEXTURE := preload("res://assets/title.png")
# TITLE_OVERLAY_SECONDS controls how long the title image stays visible at startup.
const TITLE_OVERLAY_SECONDS := 5.0

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
# prompt_label is the centered UI text for controls and game-over messages.
var prompt_label: Label
# prompt_timer is a normal Timer node used to hide the startup controls prompt.
var prompt_timer: Timer
# title_overlay is the topmost UI layer that briefly covers the whole game at startup.
var title_overlay: CanvasLayer
# title_image displays title.png inside title_overlay.
var title_image: TextureRect
# title_timer is a normal Timer node used to hide the title overlay after startup.
# Using a node-owned Timer avoids leaking a SceneTreeTimer if the game closes before 5 seconds pass.
var title_timer: Timer

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
	# Create the title overlay above all other game and UI elements.
	_build_title_overlay()
	# Start the 5-second title overlay timer without blocking the rest of initialization.
	_show_title_overlay()
	# Connect and start alternating background music tracks immediately at initialization.
	_start_background_music()
	# Start the first run by resetting score, bubble position, timers, and prompts.
	_start_run()

# _notification() lets this script react to low-level Godot lifecycle messages.
func _notification(what: int) -> void:
	# NOTIFICATION_PREDELETE is sent right before this node is destroyed.
	if what == NOTIFICATION_PREDELETE:
		# Release audio streams and timers before Godot checks for leaked resources.
		_cleanup_runtime_resources()

# _exit_tree() runs when Main is leaving the scene tree, such as when the game closes.
func _exit_tree() -> void:
	# Release audio streams and timers when the scene exits normally.
	_cleanup_runtime_resources()

# _cleanup_runtime_resources() stops runtime-owned timers and releases audio playback resources.
func _cleanup_runtime_resources() -> void:
	# Stop the first background music player so its AudioStream resource is released cleanly.
	if is_instance_valid(background_music_1):
		background_music_1.stop()
		# Clearing stream breaks the remaining reference held by the AudioStreamPlayer during shutdown.
		background_music_1.stream = null
	# Stop the second background music player for the same cleanup reason.
	if is_instance_valid(background_music_2):
		background_music_2.stop()
		# Clearing stream breaks the remaining reference held by the AudioStreamPlayer during shutdown.
		background_music_2.stream = null
	# Stop the point sound if it happens to be playing during shutdown.
	if is_instance_valid(point_sound):
		point_sound.stop()
		# Clear the stream reference for complete shutdown cleanup.
		point_sound.stream = null
	# Stop and release the title timer if the game closes before the 5-second overlay finishes.
	if is_instance_valid(title_timer):
		title_timer.stop()
		title_timer.queue_free()
		title_timer = null
	# Stop and release the prompt timer if the game closes before the controls prompt hides.
	if is_instance_valid(prompt_timer):
		prompt_timer.stop()
		prompt_timer.queue_free()
		prompt_timer = null

# _build_title_overlay() creates the startup title image layer above the rest of the game.
func _build_title_overlay() -> void:
	# CanvasLayer draws independently of world nodes; a high layer value puts it above normal UI.
	title_overlay = CanvasLayer.new()
	# Layer 100 is higher than the default game and UI layers, so the title appears over everything.
	title_overlay.layer = 100
	# Add the overlay layer to Main so Godot draws and processes it.
	add_child(title_overlay)

	# TextureRect is a UI node that can draw title.png across the viewport.
	title_image = TextureRect.new()
	# Assign the preloaded title image to the TextureRect.
	title_image.texture = TITLE_TEXTURE
	# STRETCH_KEEP_ASPECT_CENTERED keeps the title proportional and centered inside its half-size rectangle.
	title_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Ignore the texture's native size so our explicit half-viewport size controls the display.
	title_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# Size and center the title image at half the viewport.
	_update_title_image_layout()
	# Add the image to the high overlay layer.
	title_overlay.add_child(title_image)

# _update_title_image_layout() sizes the title image to half the viewport and centers it.
func _update_title_image_layout() -> void:
	# If the title image has not been created yet, there is nothing to lay out.
	if title_image == null:
		return
	# The title should render at half the width and half the height of the viewport.
	title_image.size = viewport_size * 0.5
	# Center the half-size title rectangle over the game.
	title_image.position = (viewport_size - title_image.size) * 0.5

# _show_title_overlay() shows the title image at startup and starts a node-owned 5-second timer.
func _show_title_overlay() -> void:
	# Make sure the title is visible when the game first initializes.
	title_overlay.visible = true
	# If a previous timer exists, stop it before creating a fresh startup timer.
	if title_timer:
		title_timer.stop()
		# queue_free() safely deletes the old Timer node at the end of the frame.
		title_timer.queue_free()
	# Create a normal Timer node so it belongs to Main and is cleaned up with the scene.
	title_timer = Timer.new()
	# The title should hide once, not repeat every 5 seconds.
	title_timer.one_shot = true
	# Wait for the configured title duration.
	title_timer.wait_time = TITLE_OVERLAY_SECONDS
	# When the timer finishes, call _hide_title_overlay().
	title_timer.timeout.connect(_hide_title_overlay)
	# Add the Timer to the scene tree so it can run.
	add_child(title_timer)
	# Start counting down.
	title_timer.start()

# _hide_title_overlay() runs when the startup title timer finishes.
func _hide_title_overlay() -> void:
	# Hide the title layer after the startup display time has passed.
	title_overlay.visible = false
	# Stop holding onto the finished Timer node.
	if title_timer:
		# queue_free() removes the Timer cleanly from the scene tree.
		title_timer.queue_free()
		# Clear the reference so future checks know there is no active title timer.
		title_timer = null
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
	# Show the controls briefly at the beginning of a run.
	prompt_label.text = "Space/Up/click bounce\nRight/D speed up, Left/A slow down"
	# Reset the bubble's position, movement, opacity, and alive state.
	bubble.setup(viewport_size)
	# Start a node-owned timer that will hide the controls prompt after a short delay.
	_start_prompt_timer()

# _start_prompt_timer() starts a node-owned timer for hiding the controls prompt.
func _start_prompt_timer() -> void:
	# If an old prompt timer exists from a previous run, stop and remove it first.
	if prompt_timer:
		prompt_timer.stop()
		prompt_timer.queue_free()
	# Create a normal Timer node so it is cleaned up automatically with Main.
	prompt_timer = Timer.new()
	# The prompt should hide once per run.
	prompt_timer.one_shot = true
	# Keep the same delay that the old SceneTreeTimer used.
	prompt_timer.wait_time = 1.6
	# When the timer finishes, call _hide_start_prompt().
	prompt_timer.timeout.connect(_hide_start_prompt)
	# Add the Timer to the scene tree so it can run.
	add_child(prompt_timer)
	# Start counting down.
	prompt_timer.start()

# _hide_start_prompt() clears the controls prompt if the run is still active.
func _hide_start_prompt() -> void:
	# Only hide the prompt if the bubble did not pop during the waiting period.
	if not game_over:
		# Clear the prompt text so it does not block the view.
		prompt_label.text = ""
	# Stop holding onto the finished Timer node.
	if prompt_timer:
		prompt_timer.queue_free()
		prompt_timer = null
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
	# Keep the title image half-sized and centered if the window is resized while it is visible.
	_update_title_image_layout()
