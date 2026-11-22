extends CharacterBody2D

signal hp_changed
signal died

const Bullet = preload("res://scripts/bullet.gd")
const DASH_TIME := 0.16
const DASH_SPEED := 320.0

var max_hp := 6
var hp := 6
var speed := 100.0
var damage := 1
var fire_delay := 0.3
var dash_cooldown := 0.7
var aim := Vector2.RIGHT
var bullet_parent: Node
var _cooldown := 0.0
var _invuln := 0.0
var _dash_left := 0.0
var _dash_cd := 0.0
var _dash_dir := Vector2.RIGHT
var _knock := Vector2.ZERO
var _flash := 0.0
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


func is_dashing() -> bool:
	return _dash_left > 0


func _physics_process(delta: float) -> void:
	var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_dash_cd -= delta
	if Input.is_action_just_pressed("dash") and _dash_cd <= 0:
		_dash_dir = move.normalized() if move != Vector2.ZERO else aim
		_dash_left = DASH_TIME
		_dash_cd = dash_cooldown
		_invuln = maxf(_invuln, DASH_TIME + 0.06)  # 대시 무적 프레임
		Fx.burst(get_parent(), position, Color("e8d9a8", 0.6), 6, 40.0)
	if _dash_left > 0:
		_dash_left -= delta
		velocity = _dash_dir * DASH_SPEED
		if Engine.get_physics_frames() % 2 == 0:
			Fx.burst(get_parent(), position, Color("c8b98a", 0.5), 2, 10.0, 0.25)
	else:
		velocity = move * speed + _knock
	_knock = _knock.move_toward(Vector2.ZERO, 900 * delta)
	move_and_slide()

	var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if stick != Vector2.ZERO:
		_mouse_aim = false
		aim = stick.normalized()
	elif _mouse_aim and get_global_mouse_position() != global_position:
		aim = (get_global_mouse_position() - global_position).normalized()

	_cooldown -= delta
	_invuln -= delta
	_flash -= delta
	if Input.is_action_pressed("shoot") and _cooldown <= 0 and bullet_parent and not is_dashing():
		_cooldown = fire_delay
		var muzzle := position + aim * 9
		bullet_parent.add_child(Bullet.new().setup(muzzle, aim * 220, damage, true))
		Fx.burst(bullet_parent, muzzle, Color("f4e27a"), 3, 50.0, 0.12)
		_knock -= aim * 12  # 약한 반동
	queue_redraw()


func hit(dmg: int, knock := Vector2.ZERO) -> void:
	if _invuln > 0 or hp <= 0:
		return
	hp = max(hp - dmg, 0)
	_invuln = 1.0
	_flash = 0.12
	_knock = knock.limit_length(1.0) * 220
	Fx.shake(0.55)
	Fx.hitstop(0.09)
	Fx.burst(get_parent(), position, Color("d63c3c"), 14, 90.0)
	hp_changed.emit()
	if hp == 0:
		died.emit()


func _draw() -> void:
	var c := Color.WHITE if _flash > 0 else Color("e8d9a8")
	if _invuln > 0 and _flash <= 0 and not is_dashing() and int(_invuln * 20) % 2 == 0:
		c.a = 0.3
	draw_circle(Vector2.ZERO, 5, c)
	draw_line(aim * 5, aim * 10, c, 2)
