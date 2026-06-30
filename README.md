# Bubble Briar

A small Godot 4 2D endless runner prototype. The player is a bubble that bounces through a side-scrolling landscape while avoiding sharp plants and mosquitoes. (c) 2026 Russell Knight

## Controls

- Press Space, Up, or left click to bounce.
- Hold Right or D to temporarily speed up the continual forward scrolling.
- Hold Left or A to temporarily slow down the continual forward scrolling.
- After popping, press Space, Up, or left click to restart.

## Structure

- `scenes/Main.tscn` is the main scene.
- `scenes/Bubble.tscn` is the reusable player bubble scene with its script and collision shape.
- `scripts/main.gd` runs spawning, scoring, and restart flow.
- `assets/` contains the PNG game assets imported by Godot.
- `scripts/background_layer.gd` draws the four requested background layers from PNG textures.
- `scripts/bubble.gd` handles bubble movement, popping, and the bubble sprite texture.
- `scripts/obstacle.gd` draws and moves sharp plant and mosquito sprite textures.
- `tools/generate_image_assets.ps1` regenerates the current PNG asset set.

## Runtime Flow

### Initialization

Godot starts at `scenes/Main.tscn`, which contains the root `Main` `Node2D` with `scripts/main.gd` attached.

- `main.gd::_ready()` runs once when the main scene enters the tree.
- `_ready()` randomizes the run, stores the viewport size, connects the viewport resize signal, then calls `_build_world()`, `_build_ui()`, and `_start_run()`.
- `_build_world()` creates the four `BackgroundLayer` nodes and calls `background_layer.gd::setup()` for each one. Each layer now has a notional distance in feet, and `background_layer.gd` computes its scroll factor as `1.0 / distance_feet`:
  - layer `0`: stationary sky and mountains, using `0.0 ft` as the special infinitely-far value
  - layer `1`: far hills at `4.5454545 ft`, reversed from the old `0.22` scroll factor
  - layer `2`: near trees and plants at `1.8181818 ft`, reversed from the old `0.55` scroll factor
  - layer `3`: immediate ground at `1.0 ft`, reversed from the old `1.0` scroll factor
- `_build_world()` also instantiates `scenes/Bubble.tscn`, calls `bubble.gd::setup()`, connects the bubble's `popped` signal to `main.gd::_on_bubble_popped()`, and adds the bubble to the scene.
- When the bubble enters the tree, `bubble.gd::_ready()` uses the `CollisionShape2D` child from `scenes/Bubble.tscn`, keeps its circle radius matched to the script, and requests its first draw using `assets/bubble.png`.
- `_build_ui()` creates the score label, speed label, and center prompt label.
- `_start_run()` clears old obstacles, resets score and timers, resets the scroll speed to the baseline `245 px/s`, resets the bubble, and shows the initial control prompt.

Obstacles are not created at scene startup. They are spawned later by the main heartbeat when the spawn timer reaches zero.

### Heartbeat Ticks

Godot calls these methods repeatedly while the game is running:

- `main.gd::_process(delta)` runs every rendered frame. It handles restart input during game over, updates the temporary rate adjustment from Right/D and Left/A, applies the current forward scroll speed to layers and obstacles, counts down the obstacle spawn timer, spawns plants or mosquitoes with `_spawn_obstacle()`, and awards score when obstacles pass behind the bubble.
- `background_layer.gd::_process(delta)` runs every rendered frame for each background layer. Moving layers advance `offset_x` by `current_scroll_speed * speed_factor * delta` and call `queue_redraw()` so the layer scrolls right-to-left continuously, faster or slower based on the temporary rate adjustment.
- `bubble.gd::_physics_process(delta)` runs on the physics tick. It applies bounce input, gravity, floor bounce, top-boundary clamping, and `move_and_slide()`.
- `obstacle.gd::_process(delta)` runs every rendered frame for each obstacle. It moves the obstacle left by the current immediate foreground speed and emits `escaped` when it leaves the screen.
- `_draw()` methods run when Godot redraws a node, usually after `queue_redraw()` or when the node first appears. Background layers draw PNG textures for sky, hills, trees, or ground; the bubble draws `assets/bubble.png`; obstacles draw either `assets/sharp_plant.png` or `assets/mosquito.png`.

### Events and Signals

- Bounce input is checked in `bubble.gd::_physics_process()`. Pressing Space, Up, or left click sets the bubble's upward velocity.
- Rate-adjustment input is checked in `main.gd::_update_scroll_speed()`. Holding Right/D temporarily increases `current_scroll_speed`; holding Left/A temporarily decreases it; releasing both returns the speed to the baseline while the bubble's x coordinate stays fixed.
- Restart input is checked in `main.gd::_process()` when `game_over` is true. Pressing Space, Up, or left click calls `_start_run()`.
- Obstacle collision uses Godot's `Area2D.body_entered` signal. `obstacle.gd::_ready()` connects it to `_on_body_entered()`, which calls `bubble.pop()` when the body supports that method.
- `bubble.gd::pop()` marks the bubble dead, fades it, and emits `popped`.
- `main.gd::_on_bubble_popped()` receives `popped`, sets `game_over`, updates `best_score`, and shows the restart prompt.
- `obstacle.gd::escaped` is emitted when an obstacle moves off screen. `main.gd::_on_obstacle_escaped()` removes it from the obstacle list and frees the node.
- `main.gd::_on_viewport_size_changed()` runs when the window size changes and repositions the prompt label.





