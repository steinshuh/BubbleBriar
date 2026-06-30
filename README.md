# Bubble Briar

A small Godot 4 2D endless runner prototype. The player is a bubble that bounces through a side-scrolling landscape while avoiding sharp plants and mosquitoes. (c) 2026 Russell Knight

## Controls

- Press Space, Up, or left click to bounce.
- Hold Right or D to accelerate forward through the scrolling world.
- Hold Left or A to accelerate backward through the scrolling world.
- After popping, press Space, Up, or left click to restart.

## Structure

- `scenes/Main.tscn` is the main scene.
- `scripts/main.gd` runs spawning, scoring, and restart flow.
- `scripts/background_layer.gd` draws the four requested background layers.
- `scripts/bubble.gd` handles bubble movement and popping.
- `scripts/obstacle.gd` draws and moves sharp plants and mosquitoes.

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
- `_build_world()` also creates the bubble, calls `bubble.gd::setup()`, connects the bubble's `popped` signal to `main.gd::_on_bubble_popped()`, and adds the bubble to the scene.
- When the bubble enters the tree, `bubble.gd::_ready()` creates its circular collision shape and requests its first draw.
- `_build_ui()` creates the score label, speed label, and center prompt label.
- `_start_run()` clears old obstacles, resets score and timers, resets the scroll speed to the original `245 px/s`, resets the bubble, and shows the initial control prompt.

Obstacles are not created at scene startup. They are spawned later by the main heartbeat when the spawn timer reaches zero.

### Heartbeat Ticks

Godot calls these methods repeatedly while the game is running:

- `main.gd::_process(delta)` runs every rendered frame. It handles restart input during game over, updates acceleration from Right/D and Left/A, applies the current scroll speed to layers and obstacles, counts down the obstacle spawn timer while moving forward, spawns plants or mosquitoes with `_spawn_obstacle()`, and awards score when obstacles pass behind the bubble.
- `background_layer.gd::_process(delta)` runs every rendered frame for each background layer. Moving layers advance `offset_x` by `current_scroll_speed * speed_factor * delta` and call `queue_redraw()` so the layer scrolls right-to-left when moving forward and left-to-right when moving backward.
- `bubble.gd::_physics_process(delta)` runs on the physics tick. It applies bounce input, gravity, floor bounce, top-boundary clamping, and `move_and_slide()`.
- `obstacle.gd::_process(delta)` runs every rendered frame for each obstacle. It moves the obstacle by the current immediate foreground speed, left when speed is positive and right when speed is negative, and emits `escaped` when it leaves either horizontal side of the screen.
- `_draw()` methods run when Godot redraws a node, usually after `queue_redraw()` or when the node first appears. Background layers draw sky, hills, trees, or ground; the bubble draws its translucent body; obstacles draw either a sharp plant or a mosquito.

### Events and Signals

- Bounce input is checked in `bubble.gd::_physics_process()`. Pressing Space, Up, or left click sets the bubble's upward velocity.
- Forward/backward input is checked in `main.gd::_update_scroll_speed()`. Holding Right/D increases `current_scroll_speed`; holding Left/A decreases it and can make the world scroll backward while the bubble's x coordinate stays fixed.
- Restart input is checked in `main.gd::_process()` when `game_over` is true. Pressing Space, Up, or left click calls `_start_run()`.
- Obstacle collision uses Godot's `Area2D.body_entered` signal. `obstacle.gd::_ready()` connects it to `_on_body_entered()`, which calls `bubble.pop()` when the body supports that method.
- `bubble.gd::pop()` marks the bubble dead, fades it, and emits `popped`.
- `main.gd::_on_bubble_popped()` receives `popped`, sets `game_over`, updates `best_score`, and shows the restart prompt.
- `obstacle.gd::escaped` is emitted when an obstacle moves past the left or right edge. `main.gd::_on_obstacle_escaped()` removes it from the obstacle list and frees the node.
- `main.gd::_on_viewport_size_changed()` runs when the window size changes and repositions the prompt label.


