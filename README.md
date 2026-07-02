# Bubble Briar

A Godot 4.6 2D endless runner prototype. The player is a bubble that stays at a fixed horizontal screen position while the world scrolls right-to-left. The goal is to survive sharp plants and mosquitoes. (c) 2026 Russell Knight

## Controls

- Press Space, Up, or left click to bounce.
- Hold Right or D to temporarily speed up the continual forward scrolling.
- Hold Left or A to temporarily slow down the continual forward scrolling.
- After popping, press Space, Up, or left click to restart.

## Current Gameplay

- The bubble earns points only when it bounces off the ground.
- The score bell plays when a ground-bounce point is earned.
- The bubble pops when it collides with a mosquito or sharp plant.
- The pop animation uses `assets/bubble_sheet.png`, plays frames 0 through 7, and stops on the last frame.
- Each pop frame grows by 30% relative to the previous frame.
- A half-size `assets/title.png` overlay appears centered above everything for 5 seconds at startup.
- Background music alternates between `background1.wav` and `background2.wav` from initialization.

## Structure

- `scenes/Main.tscn` is the main scene.
- `scripts/main.gd` runs initialization, scrolling, spawning, scoring, title overlay, music, and restart flow.
- `scenes/Bubble.tscn` is the reusable player scene. It owns the bubble sprite sheet, collision shape, pop sound, and breeze sound players.
- `scripts/bubble.gd` handles bubble movement, floor bounce scoring signal, popping, pop animation, and bounce sound.
- `scenes/Mosquito.tscn` is the mosquito obstacle scene. It owns the animated mosquito sprite sheet, collision shape, and looping mosquito sound.
- `scripts/mosquito.gd` handles mosquito movement, animation, collision, cleanup signal, sound looping, and distance-based volume.
- `scenes/SharpPlant.tscn` is the sharp plant obstacle scene. It owns the plant sprite and hitbox.
- `scripts/sharp_plant.gd` handles plant movement, collision, and cleanup signal.
- `scripts/background_layer.gd` draws the four parallax background layers from PNG textures.
- `assets/` contains imported PNGs and WAVs.

## Assets

Important image assets:

- `assets/title.png`: startup title overlay.
- `assets/bubble_sheet.png`: 2 row by 4 column bubble sheet. Frame 0 is the normal bubble. Frames 0-7 play when popped.
- `assets/mosquito_sheet.png`: 2 row by 4 column mosquito animation sheet.
- `assets/sky_mountains.png`, `far_hills.png`, `near_trees.png`, `ground.png`: scrolling background layers.
- `assets/sharp_plant.png`: sharp plant obstacle.

Important sound assets:

- `assets/sounds/background1.wav` and `background2.wav`: alternating background music.
- `assets/sounds/bubble_popping.wav`: played when the bubble pops.
- `assets/sounds/soft_breeze.wav`: played when the player bounces.
- `assets/sounds/small_soft_bell_ring.wav`: played when a ground-bounce point is earned.
- `assets/sounds/continual_mosquito.wav`: looped by each mosquito, with volume based on distance to the bubble.

## Runtime Flow

### Initialization

Godot starts at `scenes/Main.tscn`, whose root `Main` node uses `scripts/main.gd`.

`main.gd::_ready()` runs once when the main scene enters the tree:

- Seeds random numbers.
- Reads the viewport size.
- Connects viewport resize handling.
- Calls `_build_world()` to create background layers and connect the existing Bubble scene instance.
- Calls `_build_ui()` to create the score label and prompt label.
- Calls `_build_title_overlay()` and `_show_title_overlay()` to show `title.png` above everything for 5 seconds.
- Calls `_start_background_music()` so `background1.wav` starts immediately.
- Calls `_start_run()` to reset score, obstacles, timers, scroll speed, prompts, and bubble state.

`_build_world()` creates four background layers. Each layer has a notional distance in feet, and `background_layer.gd` computes scroll factor as `1.0 / distance_feet`:

- Layer 0: stationary sky and mountains, `0.0 ft` as the special infinitely-far value.
- Layer 1: far hills at `4.5454545 ft`, reversed from the old `0.22` scroll factor.
- Layer 2: near trees at `1.8181818 ft`, reversed from the old `0.55` scroll factor.
- Layer 3: immediate ground at `1.0 ft`, matching full foreground speed.

### Heartbeat Ticks

Godot calls these repeatedly while the scene is running:

- `main.gd::_process(delta)` handles restart input during game over, updates scroll speed from Left/Right input, applies scroll speed to layers and obstacles, and spawns obstacles when the spawn timer reaches zero.
- `background_layer.gd::_process(delta)` advances each moving layer's horizontal offset using `current_scroll_speed * speed_factor * delta`.
- `background_layer.gd::_draw()` redraws each background layer from its PNG texture.
- `bubble.gd::_physics_process(delta)` handles bounce input, breeze sound, gravity, fixed x-position, floor bounce, top clamp, and popped motion.
- `mosquito.gd::_process(delta)` advances mosquito animation, moves the mosquito left, updates mosquito sound volume from distance to the bubble, and emits `escaped` when off screen.
- `sharp_plant.gd::_process(delta)` moves the plant left and emits `escaped` when off screen.

### Events and Signals

- Player bounce input is checked in `bubble.gd::_physics_process()`. It sets upward velocity and plays `soft_breeze.wav`.
- Ground bounce is detected in `bubble.gd::_physics_process()` when the bubble hits the floor clamp. It emits `ground_bounced`.
- `main.gd::_on_bubble_ground_bounced()` receives `ground_bounced`, adds one point, updates the score label, and plays `small_soft_bell_ring.wav`.
- Obstacle collision uses `Area2D.body_entered`. `mosquito.gd` and `sharp_plant.gd` call `bubble.pop()` when the colliding body supports that method.
- `bubble.gd::pop()` marks the bubble dead, halves its y velocity, starts the pop animation, plays `bubble_popping.wav`, and emits `popped`.
- `main.gd::_on_bubble_popped()` receives `popped`, sets `game_over`, updates best score, and shows the restart prompt.
- `mosquito.gd::escaped` and `sharp_plant.gd::escaped` are emitted when an obstacle moves off screen. `main.gd::_on_obstacle_escaped()` removes it from the obstacle list and frees it.
- `main.gd::_on_background_music_finished()` alternates background music between `background1.wav` and `background2.wav`.
- `main.gd::_on_viewport_size_changed()` resizes prompt UI and keeps the title image half-sized and centered.

## Notes

- Sprite and audio resources for Bubble, Mosquito, SharpPlant, and Main are assigned in scenes instead of loaded directly by gameplay scripts.
- `mosquito.gd` is attached to the root `Mosquito` node in `scenes/Mosquito.tscn`.
- The Bubble and SharpPlant hitboxes are scene-owned collision shapes and may be adjusted in the Godot editor.
