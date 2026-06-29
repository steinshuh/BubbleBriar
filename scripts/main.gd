extends Node2D

const BackgroundLayer := preload("res://scripts/background_layer.gd")
const Bubble := preload("res://scripts/bubble.gd")
const Obstacle := preload("res://scripts/obstacle.gd")

const BASE_SPEED := 245.0
const SPAWN_MIN := 1.05
const SPAWN_MAX := 1.72

var viewport_size := Vector2(1280, 720)
var bubble: CharacterBody2D
var spawn_timer := 0.0
var score := 0
var best_score := 0
var game_over := false
var obstacles: Array[Area2D] = []

var score_label: Label
var prompt_label: Label

func _ready() -> void:
	randomize()
	viewport_size = get_viewport_rect().size
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_build_world()
	_build_ui()
	_start_run()

func _process(delta: float) -> void:
	if game_over:
		if Input.is_action_just_pressed("bounce") or Input.is_action_just_pressed("ui_accept"):
			_start_run()
		return

	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_spawn_obstacle()
		spawn_timer = randf_range(SPAWN_MIN, SPAWN_MAX)

	for obstacle in obstacles:
		if not obstacle.passed and obstacle.position.x < bubble.position.x:
			obstacle.passed = true
			score += 1
			score_label.text = "Score %d" % score

func _build_world() -> void:
	for data in [
		[0, 0.0],
		[1, 0.22],
		[2, 0.55],
		[3, 1.0],
	]:
		var layer := BackgroundLayer.new()
		layer.setup(data[0], data[1], BASE_SPEED, viewport_size)
		add_child(layer)

	bubble = Bubble.new()
	bubble.setup(viewport_size)
	bubble.popped.connect(_on_bubble_popped)
	add_child(bubble)

func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)

	score_label = Label.new()
	score_label.position = Vector2(28, 22)
	score_label.add_theme_font_size_override("font_size", 32)
	score_label.add_theme_color_override("font_color", Color("#17324d"))
	score_label.text = "Score 0"
	ui.add_child(score_label)

	prompt_label = Label.new()
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 30)
	prompt_label.add_theme_color_override("font_color", Color("#17324d"))
	prompt_label.size = Vector2(viewport_size.x, 100)
	prompt_label.position = Vector2(0, viewport_size.y * 0.38)
	ui.add_child(prompt_label)

func _start_run() -> void:
	for obstacle in obstacles:
		if is_instance_valid(obstacle):
			obstacle.queue_free()
	obstacles.clear()
	score = 0
	game_over = false
	spawn_timer = 0.7
	score_label.text = "Score 0"
	prompt_label.text = "Space, Up, or click to bounce"
	bubble.setup(viewport_size)
	await get_tree().create_timer(1.6).timeout
	if not game_over:
		prompt_label.text = ""

func _spawn_obstacle() -> void:
	var obstacle := Obstacle.new()
	var kind := Obstacle.ObstacleKind.PLANT if randf() < 0.58 else Obstacle.ObstacleKind.MOSQUITO
	obstacle.setup(kind, viewport_size.x + 90.0, viewport_size, BASE_SPEED)
	obstacle.escaped.connect(_on_obstacle_escaped)
	obstacles.append(obstacle)
	add_child(obstacle)

func _on_obstacle_escaped(obstacle: Area2D) -> void:
	obstacles.erase(obstacle)
	obstacle.queue_free()

func _on_bubble_popped() -> void:
	game_over = true
	best_score = max(best_score, score)
	prompt_label.text = "Bubble popped\nScore %d  Best %d\nPress Space, Up, or click" % [score, best_score]

func _on_viewport_size_changed() -> void:
	viewport_size = get_viewport_rect().size
	if prompt_label:
		prompt_label.size = Vector2(viewport_size.x, 120)
		prompt_label.position = Vector2(0, viewport_size.y * 0.38)
