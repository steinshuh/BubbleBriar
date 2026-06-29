# Bubble Briar

A small Godot 4 2D endless runner prototype. The player is a bubble that bounces through a side-scrolling landscape while avoiding sharp plants and mosquitoes. (c) 2026 Russell Knight

## Controls

- Press Space, Up, or left click to bounce.
- After popping, press Space, Up, or left click to restart.

## Structure

- `scenes/Main.tscn` is the main scene.
- `scripts/main.gd` runs spawning, scoring, and restart flow.
- `scripts/background_layer.gd` draws the four requested background layers.
- `scripts/bubble.gd` handles bubble movement and popping.
- `scripts/obstacle.gd` draws and moves sharp plants and mosquitoes.
