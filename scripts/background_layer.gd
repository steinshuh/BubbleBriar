# This script draws one parallax background layer.
# The artwork for each layer now comes from PNG files in res://assets/.
extends Node2D

# These constants preload Godot Texture2D resources from image files.
# Preloading means Godot loads the images when the script loads, before gameplay needs them.
const SKY_TEXTURE := preload("res://assets/sky_mountains.png")
const FAR_HILLS_TEXTURE := preload("res://assets/far_hills.png")
const NEAR_TREES_TEXTURE := preload("res://assets/near_trees.png")
const GROUND_TEXTURE := preload("res://assets/ground.png")

# NEAR_TREES_VERTICAL_OFFSET moves the near-tree artwork down on the screen.
# A positive y offset means the image starts lower, so less of the high tree tops are visible.
const NEAR_TREES_VERTICAL_OFFSET := 175.0

# @export means the value can be edited in Godot's Inspector if the node is placed in a scene.
# layer_kind chooses what this layer draws: 0 sky, 1 far hills, 2 near trees, 3 ground.
@export var layer_kind := 0
# distance_feet is a notional distance from the camera/player to this layer.
# The game computes speed_factor as 1.0 / distance_feet, so closer layers move faster.
# A value of 0.0 means "infinitely far away" and produces no scrolling.
@export var distance_feet := 0.0
# speed_factor controls how fast this layer moves compared with the immediate foreground.
# It is computed from distance_feet instead of being entered directly.
@export var speed_factor := 0.0
# world_speed is the current scroll speed passed in by main.gd.
# It stays positive, with Left/Right temporarily making it slower or faster.
@export var world_speed := 0.0

# viewport_size stores the current visible game area, used for drawing at the right size.
var viewport_size := Vector2(1280, 720)
# offset_x is how far this layer has scrolled horizontally.
var offset_x := 0.0
# tile_width is the width of one repeated background tile.
var tile_width := 1280.0
# layer_texture stores the actual PNG texture used by this layer.
var layer_texture: Texture2D
# draw_offset_y stores how far down this layer should be drawn.
# Most layers use 0.0, but the near trees use a positive value because their PNG sits too high.
var draw_offset_y := 0.0

# setup() is called by main.gd immediately after the layer is created.
func setup(kind: int, feet: float, speed: float, size: Vector2) -> void:
	# Store which drawing mode this layer should use.
	layer_kind = kind
	# Pick the correct PNG texture for this layer_kind.
	layer_texture = _texture_for_layer(layer_kind)
	# Pick the vertical drawing offset for this layer_kind.
	draw_offset_y = _draw_offset_y_for_layer(layer_kind)
	# Store the notional distance that controls parallax speed.
	distance_feet = feet
	# Convert the notional distance into a parallax speed factor.
	speed_factor = _speed_factor_from_distance(distance_feet)
	# Store the current world speed from the main game.
	world_speed = speed
	# Store the viewport size so drawing can scale to the window.
	viewport_size = size
	# Make the repeated tile at least 960 pixels wide so the art has enough room.
	tile_width = max(960.0, viewport_size.x)
	# Ask Godot to call _draw() soon so the layer appears on screen.
	queue_redraw()

# _texture_for_layer() maps a layer number to the matching PNG asset.
func _texture_for_layer(kind: int) -> Texture2D:
	# Match chooses one branch based on the value of kind.
	match kind:
		# Layer 0 is the stationary sky and mountains image.
		0:
			return SKY_TEXTURE
		# Layer 1 is the far hills image.
		1:
			return FAR_HILLS_TEXTURE
		# Layer 2 is the near trees image.
		2:
			return NEAR_TREES_TEXTURE
		# Layer 3 is the immediate ground image.
		3:
			return GROUND_TEXTURE
	# If an unexpected layer number is used, fall back to the sky image.
	return SKY_TEXTURE

# _draw_offset_y_for_layer() maps a layer number to a vertical drawing offset.
func _draw_offset_y_for_layer(kind: int) -> float:
	# Match chooses one branch based on the value of kind.
	match kind:
		# Layer 2 is the near trees image, which should sit lower than the full-screen default.
		2:
			return NEAR_TREES_VERTICAL_OFFSET
	# Every other layer starts at the top of the viewport.
	return 0.0

# set_scroll_speed() lets main.gd change the current scrolling speed every frame.
func set_scroll_speed(speed: float) -> void:
	# Store the new speed. Larger values scroll the world left faster.
	world_speed = speed

# _speed_factor_from_distance() converts notional feet into a parallax multiplier.
func _speed_factor_from_distance(feet: float) -> float:
	# Zero or negative feet means the layer is treated as infinitely far away and stationary.
	if feet <= 0.0:
		return 0.0
	# The immediate layer is 1 foot away, so 1.0 / 1.0 gives full speed.
	# The old 0.55 layer becomes 1 / 1.81818, and the old 0.22 layer becomes 1 / 4.54545.
	return 1.0 / feet

# _process(delta) runs once per rendered frame.
func _process(delta: float) -> void:
	# A speed factor of 0.0 is the stationary sky/mountain layer, so it should not move.
	if speed_factor > 0.0:
		# Move the horizontal offset based on current speed, parallax factor, and frame time.
		# fposmod() wraps scrolling into the 0..tile_width range so the tiled image loops forever.
		offset_x = fposmod(offset_x + world_speed * speed_factor * delta, tile_width)
		# The offset changed, so the layer must be redrawn in its new position.
		queue_redraw()

# _draw() is Godot's custom drawing function for CanvasItem nodes like Node2D.
func _draw() -> void:
	# If setup() has not assigned a texture yet, do not draw anything.
	if layer_texture == null:
		return
	# The sky texture fills the screen once and stays stationary.
	if speed_factor == 0.0:
		# Draw the sky at its layer-specific y offset, which is normally 0.0.
		draw_texture_rect(layer_texture, Rect2(Vector2(0.0, draw_offset_y), viewport_size), false)
		return
	# Moving layers are drawn as repeated texture tiles so the world can scroll forever.
	for tile in range(-1, 3):
		# x is this tile's left edge after subtracting the scrolling offset.
		var x := tile * tile_width - offset_x
		# Draw the PNG scaled to cover this layer's full viewport-sized tile.
		draw_texture_rect(layer_texture, Rect2(Vector2(x, draw_offset_y), Vector2(tile_width, viewport_size.y)), false)
