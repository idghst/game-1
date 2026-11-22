extends CharacterBody2D

signal hp_changed
signal died

const Bullet = preload("res://scripts/bullet.gd")
const Art = preload("res://scripts/art.gd")
const DASH_TIME := 0.16
const DASH_SPEED := 320.0

# 능력치 (업그레이드와 메타 강화가 바꾼다)
var max_hp := 6
var hp := 6
var speed := 100.0
var damage := 10
var fire_delay := 0.3
var shot_speed := 220.0
var shot_life := 1.1
var projectiles := 1
var pierce := 0
var bounce := 0
var homing := 0.0
var explode := 0.0
var crit := 0.0
var slow := false
var burn := false
var knockback := 1.0
var dash_cooldown := 0.7
var phantom := false
var souls := false
var dash_reset_on_kill := false
var lifesteal_every := 0
var gold_mult := 1.0

var aim := Vector2.RIGHT
var bullet_parent: Node
var dash_count := 0
var hits_taken := 0
var _cooldown := 0.0
var _invuln := 0.0
var _dash_left := 0.0
var _dash_cd := 0.0
var _dash_dir := Vector2.RIGHT
var _dash_hit := {}
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


func reset_dash() -> void:
	_dash_cd = 0.0


func heal(n: int) -> void:
	hp = mini(hp + n, max_hp)
	hp_changed.emit()


func _physics_process(delta: float) -> void:
	var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_dash_cd -= delta
	if Input.is_action_just_pressed("dash") and _dash_cd <= 0:
		_dash_dir = move.normalized() if move != Vector2.ZERO else aim
		_dash_left = DASH_TIME
		_dash_cd = dash_cooldown
		_dash_hit.clear()
		dash_count += 1
		_invuln = maxf(_invuln, DASH_TIME + (0.2 if phantom else 0.06))  # 대시 무적 프레임
		Fx.burst(get_parent(), position, Color("e8d9a8", 0.6), 6, 40.0)
		Sfx.play("dash", -4.0)
	if _dash_left > 0:
		_dash_left -= delta
		velocity = _dash_dir * DASH_SPEED
		if Engine.get_physics_frames() % 2 == 0:
			Fx.burst(get_parent(), position, Color("c8b98a", 0.5) if not phantom else Color("8ad0ff", 0.6), 2, 10.0, 0.25)
		if phantom:
			for e in get_tree().get_nodes_in_group("enemies"):
				if e.position.distance_to(position) < e.radius + 8 and not _dash_hit.has(e):
					_dash_hit[e] = true
					e.hit(damage * 2, _dash_dir, {})
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
		shoot()
	queue_redraw()


func shoot() -> void:
	var muzzle := position + aim * 9
	var spread := deg_to_rad(10.0)
	for i in projectiles:
		var dir := aim.rotated((i - (projectiles - 1) / 2.0) * spread)
		var is_crit := randf() < crit
		var opts := {"life": shot_life, "pierce": pierce, "bounce": bounce, "homing": homing, "explode": explode,
			"status": {"burn": burn, "slow": slow}}
		if is_crit:
			opts.color = Color("ffffff")
			opts.radius = 3.0
		bullet_parent.add_child(Bullet.new().setup(muzzle, dir * shot_speed, damage * (2 if is_crit else 1), true, opts))
	Fx.burst(bullet_parent, muzzle, Color("f4e27a"), 3, 50.0, 0.12)
	Sfx.play("shoot", -9.0, randf_range(0.92, 1.08))
	_knock -= aim * 12  # 약한 반동


func hit(dmg: int, knock := Vector2.ZERO, _status := {}) -> void:
	if _invuln > 0 or hp <= 0:
		return
	hp = maxi(hp - dmg, 0)
	hits_taken += 1
	_invuln = 1.0
	_flash = 0.12
	_knock = knock.limit_length(1.0) * 220
	Fx.shake(0.55)
	Fx.hitstop(0.09)
	Fx.burst(get_parent(), position, Color("d63c3c"), 14, 90.0)
	Sfx.play("player_die" if hp == 0 else "player_hurt")
	hp_changed.emit()
	if hp == 0:
		died.emit()


func _draw() -> void:
	var m := Color(4, 4, 4) if _flash > 0 else Color.WHITE
	if _invuln > 0 and _flash <= 0 and not is_dashing() and int(_invuln * 20) % 2 == 0:
		m.a = 0.35
	var bob := Vector2(0, -1) if velocity.length() > 10 and int(Time.get_ticks_msec() / 120) % 2 == 0 else Vector2.ZERO
	draw_set_transform(bob)
	if not Art.draw(self, "player", aim.x < 0, m):
		draw_circle(Vector2.ZERO, 5, Color("e8d9a8") * m)
	draw_set_transform(Vector2.ZERO)
	draw_line(aim * 8, aim * 12, Color("f8c040", m.a), 1)
