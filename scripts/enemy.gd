extends CharacterBody2D
## 일반 적. kind별로 행동이 다르고, elite면 체력·크기·공격 빈도가 오른다.

signal died(enemy: Node, rewards: bool)

const Bullet = preload("res://scripts/bullet.gd")
const Art = preload("res://scripts/art.gd")
const KINDS := {
	"ghoul": {"hp": 30, "speed": 52.0, "radius": 6.0, "gold": 1, "color": Color("c0392b")},
	"archer": {"hp": 22, "speed": 42.0, "radius": 6.0, "gold": 1, "color": Color("d8c8a0")},
	"bat": {"hp": 12, "speed": 85.0, "radius": 5.0, "gold": 1, "color": Color("8a6ab0")},
	"bloater": {"hp": 50, "speed": 26.0, "radius": 9.0, "gold": 2, "color": Color("6a9a4a")},
	"slimelet": {"hp": 10, "speed": 62.0, "radius": 4.0, "gold": 0, "color": Color("9aca6a")},
	"cultist": {"hp": 28, "speed": 30.0, "radius": 6.0, "gold": 2, "color": Color("9b59d0")},
	"brute": {"hp": 70, "speed": 34.0, "radius": 9.0, "gold": 3, "color": Color("b0703a")},
	"eye": {"hp": 45, "speed": 0.0, "radius": 8.0, "gold": 2, "color": Color("d04060")},
}

var kind := "ghoul"
var elite := false
var hp := 30
var max_hp := 30
var speed := 50.0
var radius := 6.0
var gold := 1
var color := Color.RED
var target: Node2D
var game: Node  # main.gd: 분열·소환 요청용
var bullet_speed_mult := 1.0
var fire_rate_mult := 1.0  # 층이 깊을수록 더 자주 쏜다
var _spawn_t := 0.5  # 등장 연출 중에는 행동·피격 없음
var _t := 0.0  # 범용 타이머
var _cd := 1.0  # 공격 쿨다운
var _state := ""
var _dir := Vector2.ZERO
var _angle := 0.0
var _flash := 0.0
var _knock := Vector2.ZERO
var _slow_t := 0.0
var _burn_t := 0.0
var _burn_tick := 0.0
var _contact_cd := 0.0


func setup(k: String, is_elite: bool, player: Node2D, g: Node, hp_mult: float) -> CharacterBody2D:
	kind = k
	elite = is_elite
	target = player
	game = g
	var d: Dictionary = KINDS[k]
	max_hp = int(d.hp * hp_mult * (2.5 if elite else 1.0))
	hp = max_hp
	speed = d.speed * (1.12 if elite else 1.0)
	radius = d.radius * (1.3 if elite else 1.0)
	gold = d.gold * (3 if elite else 1)
	color = d.color
	_cd = randf_range(1.0, 2.0)
	return self


func _ready() -> void:
	add_to_group("enemies")
	Art.unshaded(self)
	collision_layer = 4
	collision_mask = 1 | 4  # 벽 + 다른 적
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = radius
	add_child(shape)


func _cool(base: float) -> float:
	return base * (0.7 if elite else 1.0) / fire_rate_mult


func _shoot(dir: Vector2, spd: float, big := false) -> void:
	Sfx.play("enemy_shoot", -14.0, randf_range(0.9, 1.1))
	var opts := {"radius": 3.5} if big else {}
	game.spawn.call_deferred(Bullet.new().setup(position + dir * (radius + 2), dir * spd * bullet_speed_mult, 1, false, opts), get_parent())


func _ring(n: int, spd: float, offset := 0.0) -> void:
	for i in n:
		_shoot(Vector2.RIGHT.rotated(TAU * i / n + offset), spd)


func _physics_process(delta: float) -> void:
	_flash -= delta
	queue_redraw()
	if _spawn_t > 0:
		_spawn_t -= delta
		return
	var slow_k := 0.5 if _slow_t > 0 else 1.0
	_slow_t -= delta
	if _burn_t > 0:
		_burn_t -= delta
		_burn_tick -= delta
		if _burn_tick <= 0:
			_burn_tick = 0.5
			Fx.burst(get_parent(), position, Color("ff8030"), 3, 30.0, 0.2)
			_damage(3)
			if hp <= 0:
				return
	var to := target.position - position
	var dist := to.length()
	var dir := to / maxf(dist, 0.001)
	_t += delta
	_cd -= delta * slow_k
	var want := Vector2.ZERO
	match kind:
		"ghoul", "slimelet":
			want = dir * speed
			if kind == "slimelet":
				want *= 0.6 + absf(sin(_t * 6.0))  # 통통 튀는 움직임
		"archer":
			if dist > 130:
				want = dir * speed
			elif dist < 90:
				want = -dir * speed
			else:
				want = dir.orthogonal() * speed * 0.5 * sign(sin(_t * 0.7))
			if _state == "aim":
				want = Vector2.ZERO
				if _cd <= 0:
					_shoot(dir, 125.0)
					if elite:
						_shoot(dir.rotated(0.2), 125.0)
						_shoot(dir.rotated(-0.2), 125.0)
					_state = ""
					_cd = _cool(1.9)
			elif _cd <= 0.35:
				_state = "aim"  # 0.35초 조준(깜빡임) 후 발사
		"bat":
			if _state == "swoop":
				want = _dir * 190.0
				if _cd <= 0:
					_state = ""
					_cd = _cool(2.4)
			else:
				want = (dir + dir.orthogonal() * sin(_t * 5.0) * 1.2).normalized() * speed
				if _cd <= 0 and dist < 150:
					_state = "swoop"
					_dir = dir
					_cd = 0.35
		"bloater":
			want = dir * speed
		"cultist":
			if dist > 150:
				want = dir * speed
			elif dist < 70:
				want = -dir * speed
			if _cd <= 0:
				_ring(12 if elite else 8, 70.0, _t)
				_cd = _cool(2.6)
				if randf() < 0.35:
					_teleport()
		"brute":
			match _state:
				"windup":
					want = Vector2.ZERO
					if _cd <= 0:
						_state = "charge"
						_cd = 0.55
						Fx.shake(0.1)
				"charge":
					want = _dir * 230.0
					if _cd <= 0 or get_slide_collision_count() > 0 and _cd < 0.45:
						_state = "stun"
						_cd = 0.6
						if get_slide_collision_count() > 0:
							Fx.shake(0.2)
							Fx.burst(get_parent(), position, color, 10, 70.0)
				"stun":
					if _cd <= 0:
						_state = ""
						_cd = _cool(1.6)
				_:
					want = dir * speed
					if _cd <= 0 and dist < 150:
						_state = "windup"
						_dir = dir
						_cd = 0.6
		"eye":
			_angle += delta * (2.2 if elite else 1.6)
			if _cd <= 0:
				_cd = 0.22
				if fmod(_t, 4.0) < 2.6:  # 2.6초 쏘고 1.4초 쉰다
					_shoot(Vector2.RIGHT.rotated(_angle), 75.0)
					_shoot(Vector2.RIGHT.rotated(_angle + PI), 75.0)
	if not Rect2(8, 8, 464, 254).has_point(position):  # 겹쳐 생긴 적이 벽 밖으로 튕겨 나간 경우 되돌린다
		position = Vector2(240, 135)
	velocity = want * slow_k + _knock
	_knock = _knock.move_toward(Vector2.ZERO, 700 * delta)
	move_and_slide()
	_contact_cd -= delta
	if dist < radius + 6 and _contact_cd <= 0:
		_contact_cd = 0.5
		target.hit(1, dir)


func _teleport() -> void:
	Fx.burst(get_parent(), position, color, 12, 60.0)
	for i in 10:
		var p := Vector2(randf_range(40, 440), randf_range(40, 230))
		if p.distance_to(target.position) > 90:
			position = p
			break
	Fx.burst(get_parent(), position, color, 12, 60.0)


func hit(dmg: int, knock := Vector2.ZERO, status := {}) -> void:
	if hp <= 0 or _spawn_t > 0:
		return
	_flash = 0.08
	if kind != "eye":
		_knock = knock.limit_length(1.0) * (60.0 if elite or kind == "brute" else 160.0) * target.knockback
	if status.get("slow", false):
		_slow_t = 1.5
	if status.get("burn", false):
		_burn_t = 2.0
	Fx.burst(get_parent(), position, Color("ffffff", 0.8), 4, 60.0, 0.2)
	Sfx.play("hit", -8.0, randf_range(0.9, 1.15))
	_damage(dmg)


func _damage(dmg: int) -> void:
	hp -= dmg
	if hp <= 0:
		die(true)


# rewards=false: 보스가 죽어 남은 졸개가 함께 사라질 때
func die(rewards: bool) -> void:
	if is_queued_for_deletion():
		return
	hp = 0
	Fx.burst(get_parent(), position, color, 18 if not elite else 30, 110.0, 0.45)
	if rewards:
		Sfx.play("enemy_die", -4.0 if elite else -7.0, randf_range(0.85, 1.1))
		Fx.shake(0.25 if not elite else 0.4)
		Fx.hitstop(0.045 if not elite else 0.08)
		if kind == "bloater":
			for i in 2:
				game.spawn_enemy("slimelet", position + Vector2(-7 + 14 * i, randf_range(-3, 3)), false, true)
	remove_from_group("enemies")
	died.emit(self, rewards)
	queue_free()


func _draw() -> void:
	if _spawn_t > 0:
		# 등장 예고: 깜빡이는 원
		if int(_spawn_t * 16) % 2 == 0:
			draw_arc(Vector2.ZERO, radius + 2, 0, TAU, 16, color, 1.0)
		return
	var m := Color(4, 4, 4) if _flash > 0 else Color.WHITE
	if _state in ["aim", "windup"] and int(_t * 20) % 2 == 0:
		m = Color(2, 2, 2)
	elif _burn_t > 0:
		m = Color(1.4, 0.8, 0.5)
	elif _slow_t > 0:
		m = Color(0.7, 0.9, 1.5)
	if elite:
		draw_arc(Vector2.ZERO, radius + 3, 0, TAU, 20, Color("f0c040"), 1.0)
	var bob := Vector2(0, roundf(sin(_t * 8.0) * 0.6)) if kind != "eye" else Vector2(0, roundf(sin(_t * 3.0)))
	draw_set_transform(bob)
	var flip := target.position.x < position.x
	var rim := Color(1.0, 0.85, 0.2, 0.9) if elite else Color(1.0, 0.18, 0.12, 0.75)
	if not Art.draw(self, kind, flip, m, 1.3 if elite else 1.0, rim):
		draw_circle(Vector2.ZERO, radius, color * m)
	draw_set_transform(Vector2.ZERO)
