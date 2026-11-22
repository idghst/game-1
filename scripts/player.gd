extends CharacterBody2D

signal hp_changed
signal died

const Bullet = preload("res://scripts/bullet.gd")

var max_hp := 6
var hp := 6
var speed := 100.0
var damage := 1
var fire_delay := 0.3
var aim := Vector2.RIGHT
var bullet_parent: Node
var _cooldown := 0.0
var _invuln := 0.0
var _mouse_aim := true


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 5
	add_child(shape)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_mouse_aim = true


func _physics_process(delta: float) -> void:
	velocity = Input.get_vector("move_left", "move_right", "move_up", "move_down") * speed
	move_and_slide()

	var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if stick != Vector2.ZERO:
		_mouse_aim = false
		aim = stick.normalized()
	elif _mouse_aim and get_global_mouse_position() != global_position:
		aim = (get_global_mouse_position() - global_position).normalized()

	_cooldown -= delta
	_invuln -= delta
	if Input.is_action_pressed("shoot") and _cooldown <= 0 and bullet_parent:
		_cooldown = fire_delay
		bullet_parent.add_child(Bullet.new().setup(position + aim * 8, aim * 220, damage, true))
	queue_redraw()


func hit(dmg: int) -> void:
	if _invuln > 0 or hp <= 0:
		return
	hp = max(hp - dmg, 0)
	_invuln = 0.8
	hp_changed.emit()
	if hp == 0:
		died.emit()


func _draw() -> void:
	var c := Color("e8d9a8")
	if _invuln > 0 and int(_invuln * 20) % 2 == 0:
		c.a = 0.3
	draw_circle(Vector2.ZERO, 5, c)
	draw_line(aim * 5, aim * 10, c, 2)
