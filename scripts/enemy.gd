extends CharacterBody2D

signal died

const Bullet = preload("res://scripts/bullet.gd")

var ranged := false
var hp := 3
var speed := 55.0
var target: Node2D
var _cooldown := 1.0
var _flash := 0.0
var _knock := Vector2.ZERO


func setup(is_ranged: bool, player: Node2D, floor_n: int) -> CharacterBody2D:
	ranged = is_ranged
	target = player
	hp = (2 if ranged else 3) + floori((floor_n - 1) / 2.0)
	speed = 40.0 if ranged else 55.0
	_cooldown = randf_range(0.8, 1.6)
	return self


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 4  # 벽 + 다른 적
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 6
	add_child(shape)


func _physics_process(delta: float) -> void:
	var to := target.global_position - global_position
	var dir := to.normalized()
	if ranged:
		# 80~120px 거리를 유지하며 사격
		var k := 0.0
		if to.length() > 120:
			k = 1.0
		elif to.length() < 80:
			k = -1.0
		velocity = dir * speed * k
		_cooldown -= delta
		if _cooldown <= 0:
			_cooldown = 1.6
			get_parent().add_child(Bullet.new().setup(position + dir * 8, dir * 110, 1, false))
	else:
		velocity = dir * speed
		if to.length() < 12:
			target.hit(1, dir)
	velocity += _knock
	_knock = _knock.move_toward(Vector2.ZERO, 700 * delta)
	move_and_slide()
	_flash -= delta
	queue_redraw()


func hit(dmg: int, knock := Vector2.ZERO) -> void:
	if hp <= 0:
		return
	hp -= dmg
	_flash = 0.08
	_knock = knock.limit_length(1.0) * 160
	Fx.burst(get_parent(), position, Color("ffffff", 0.8), 4, 60.0, 0.2)
	if hp <= 0:
		Fx.burst(get_parent(), position, Color("c0392b") if not ranged else Color("9b59d0"), 18, 110.0, 0.45)
		Fx.shake(0.25)
		Fx.hitstop(0.045)
		died.emit()
		queue_free()


func _draw() -> void:
	var c := Color.WHITE if _flash > 0 else (Color("9b59d0") if ranged else Color("c0392b"))
	if ranged:
		draw_colored_polygon(PackedVector2Array([Vector2(0, -7), Vector2(6, 0), Vector2(0, 7), Vector2(-6, 0)]), c)
	else:
		draw_rect(Rect2(-6, -6, 12, 12), c)
