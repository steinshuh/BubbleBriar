# This script draws one parallax background layer.
# A parallax layer is a background that scrolls at a different speed than other layers.
extends Node2D

# @export means the value can be edited in Godot's Inspector if the node is placed in a scene.
# layer_kind chooses what this layer draws: 0 sky, 1 far hills, 2 near trees, 3 ground.
@export var layer_kind := 0
# speed_factor controls how fast this layer moves compared with the main game speed.
# 0.0 means no scrolling. 1.0 means full scrolling speed.
@export var speed_factor := 0.0
# world_speed is the base speed passed in by main.gd.
@export var world_speed := 0.0

# viewport_size stores the current visible game area, used for drawing at the right size.
var viewport_size := Vector2(1280, 720)
# offset_x is how far this layer has scrolled horizontally.
var offset_x := 0.0
# tile_width is the width of one repeated background tile.
var tile_width := 1280.0

# setup() is called by main.gd immediately after the layer is created.
func setup(kind: int, factor: float, speed: float, size: Vector2) -> void:
	# Store which drawing mode this layer should use.
	layer_kind = kind
	# Store how much of the main speed this layer should use.
	speed_factor = factor
	# Store the base world speed from the main game.
	world_speed = speed
	# Store the viewport size so drawing can scale to the window.
	viewport_size = size
	# Make the repeated tile at least 960 pixels wide so the art has enough room.
	tile_width = max(960.0, viewport_size.x)
	# Ask Godot to call _draw() soon so the layer appears on screen.
	queue_redraw()

# _process(delta) runs once per rendered frame.
func _process(delta: float) -> void:
	# A speed factor of 0.0 is the stationary sky/mountain layer, so it should not move.
	if speed_factor > 0.0:
		# Move the horizontal offset forward based on speed and frame time.
		# fmod() wraps the value back around when it reaches tile_width, creating an infinite loop.
		offset_x = fmod(offset_x + world_speed * speed_factor * delta, tile_width)
		# The offset changed, so the layer must be redrawn in its new position.
		queue_redraw()

# _draw() is Godot's custom drawing function for CanvasItem nodes like Node2D.
func _draw() -> void:
	# Choose which helper function to call based on layer_kind.
	match layer_kind:
		# 0 draws the stationary sky and mountains.
		0:
			_draw_stationary_sky()
		# 1 draws distant hills.
		1:
			_draw_far_hills()
		# 2 draws closer trees and plants.
		2:
			_draw_near_trees()
		# 3 draws the immediate ground layer.
		3:
			_draw_ground()

# Draws the layer that does not move: blue sky, sun, and mountains.
func _draw_stationary_sky() -> void:
	# Fill the whole viewport with sky blue.
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color("#9bdcff"))
	# Draw the sun near the upper-right part of the screen.
	draw_circle(Vector2(viewport_size.x * 0.82, viewport_size.y * 0.16), 54.0, Color("#fff1a8"))
	# base_y is the vertical position where mountain triangles meet the lower sky.
	var base_y := viewport_size.y * 0.62
	# mountain_color is the main color for mountain faces.
	var mountain_color := Color("#8ab0c3")
	# shade_color is a darker color for the shaded side of each mountain.
	var shade_color := Color("#6f98ad")
	# The peaks array stores mountain triangle points in groups of three.
	var peaks := [
		Vector2(-120, base_y), Vector2(120, viewport_size.y * 0.28), Vector2(360, base_y),
		Vector2(250, base_y), Vector2(545, viewport_size.y * 0.22), Vector2(880, base_y),
		Vector2(730, base_y), Vector2(1020, viewport_size.y * 0.30), Vector2(1360, base_y)
	]
	# Step through the peaks array three points at a time, because each mountain is a triangle.
	for i in range(0, peaks.size(), 3):
		# Draw the full mountain triangle.
		draw_colored_polygon(PackedVector2Array([peaks[i], peaks[i + 1], peaks[i + 2]]), mountain_color)
		# Draw a smaller shaded triangle on one side of the mountain.
		draw_colored_polygon(PackedVector2Array([peaks[i + 1], peaks[i + 2], Vector2(peaks[i + 1].x + 60, base_y)]), shade_color)

# Draws the slow-moving far hills layer.
func _draw_far_hills() -> void:
	# Draw several repeated tiles so there is always art covering the screen while scrolling.
	for tile in range(-1, 3):
		# x is this tile's left edge after subtracting the scrolling offset.
		var x := tile * tile_width - offset_x
		# y is the general vertical height of the hills.
		var y := viewport_size.y * 0.66
		# hill is a polygon that starts below the screen, rises and falls, then ends below the screen.
		var hill := PackedVector2Array([
			Vector2(x - 80, viewport_size.y),
			Vector2(x + 80, y + 30),
			Vector2(x + 260, y - 35),
			Vector2(x + 470, y + 18),
			Vector2(x + 700, y - 52),
			Vector2(x + 970, y + 20),
			Vector2(x + tile_width + 120, viewport_size.y),
		])
		# Draw the brighter front hill shape.
		draw_colored_polygon(hill, Color("#79bf83"))
		# back is a second hill shape with different points to add depth.
		var back := PackedVector2Array([
			Vector2(x - 120, viewport_size.y),
			Vector2(x + 150, y + 72),
			Vector2(x + 410, y + 8),
			Vector2(x + 740, y + 68),
			Vector2(x + 1060, y + 5),
			Vector2(x + tile_width + 160, viewport_size.y),
		])
		# Draw the darker back hill shape.
		draw_colored_polygon(back, Color("#5ba874"))

# Draws closer trees and leafy plants.
func _draw_near_trees() -> void:
	# Repeat the tree pattern across multiple tiles for infinite scrolling.
	for tile in range(-1, 3):
		# x0 is the left edge of this repeated tile after scrolling.
		var x0 := tile * tile_width - offset_x
		# Draw eight trees per tile.
		for i in range(8):
			# x is this tree's horizontal position.
			var x := x0 + i * 180.0 + 35.0
			# trunk_h varies the trunk height so trees do not all look identical.
			var trunk_h := 92.0 + float((i * 29) % 52)
			# base_y is where the tree trunk touches the lower part of the screen.
			var base_y := viewport_size.y * 0.86
			# Draw the tree trunk as a brown rectangle.
			draw_rect(Rect2(Vector2(x - 9, base_y - trunk_h), Vector2(18, trunk_h)), Color("#6d5136"))
			# Draw overlapping circles to form a leafy treetop.
			draw_circle(Vector2(x, base_y - trunk_h - 18.0), 46.0, Color("#26734d"))
			# Draw a lighter leaf clump on the left.
			draw_circle(Vector2(x - 30.0, base_y - trunk_h + 6.0), 32.0, Color("#2d8a58"))
			# Draw a darker leaf clump on the right.
			draw_circle(Vector2(x + 32.0, base_y - trunk_h + 10.0), 34.0, Color("#1f6845"))
			# Draw an extra small plant cluster near the ground.
			_draw_leaf_cluster(x + 84.0, base_y - 22.0, 0.8)

# Draws a small group of leaves at a given position and scale.
func _draw_leaf_cluster(x: float, y: float, scale: float) -> void:
	# Draw four circles with slight vertical variation.
	for j in range(4):
		# p is the center point for one leaf circle.
		var p := Vector2(x + j * 22.0 * scale, y + sin(float(j)) * 8.0)
		# Draw the leaf circle.
		draw_circle(p, 22.0 * scale, Color("#2f995f"))

# Draws the immediate foreground ground layer.
func _draw_ground() -> void:
	# ground_y is the top edge of the solid ground strip.
	var ground_y := viewport_size.y - 88.0
	# Draw the main solid ground rectangle across the bottom of the screen.
	draw_rect(Rect2(Vector2(0, ground_y), Vector2(viewport_size.x, 88.0)), Color("#326242"))
	# Repeat grass and ground details across multiple tiles for infinite scrolling.
	for tile in range(-1, 3):
		# x0 is the left edge of this repeated tile after scrolling.
		var x0 := tile * tile_width - offset_x
		# Draw sixteen pairs of grass blades per tile.
		for i in range(16):
			# x is the base position for this grass clump.
			var x := x0 + i * 82.0
			# blade_h varies blade height so the grass looks more natural.
			var blade_h := 18.0 + float((i * 17) % 32)
			# Draw one leaning grass blade.
			draw_line(Vector2(x, ground_y + 8.0), Vector2(x + 15.0, ground_y - blade_h), Color("#54b35f"), 4.0)
			# Draw a second thinner blade leaning another way.
			draw_line(Vector2(x + 28.0, ground_y + 10.0), Vector2(x + 17.0, ground_y - blade_h * 0.75), Color("#79ca67"), 3.0)
		# Draw a few darker ground bumps per tile.
		for i in range(7):
			# x is the center position of this ground bump.
			var x := x0 + i * 210.0 + 35.0
			# Draw the ground bump as a dark circle partially inside the ground strip.
			draw_circle(Vector2(x, ground_y + 28.0), 18.0, Color("#254c35"))
