extends CharacterBody2D
## 보스 3종. 패턴을 순서대로(일부 무작위) 돌리며, 체력이 줄면 단계(phase)가 올라 패턴이 늘고 빨라진다.

signal died(enemy: Node, rewards: bool)

const Bullet = preload("res://scripts/bullet.gd")
const Art = preload("res://scripts/art.gd")
const KINDS := {
	"warden": {"hp": 600, "radius": 14.0, "speed": 40.0, "color": Color("d8d0b8"),
		"patterns": [["ring", "charge", "fan", "summon"], ["ring", "charge", "fan", "summon", "charge"]]},
	"matron": {"hp": 1400, "radius": 13.0, "speed": 45.0, "color": Color("4ab0a0"),
		"patterns": [["spiral", "teleport", "fan", "summon"], ["spiral", "teleport", "ring", "summon", "fan"]]},
	"king": {"hp": 2600, "radius": 15.0, "speed": 50.0, "color": Color("f06030"),
		"patterns": [["ring", "fan", "charge"], ["spiral", "ring", "summon", "fan", "charge"], ["rain", "spiral", "charge", "ring", "summon", "rain"]]},
}

var kind := "warden"
var hp := 700
var max_hp := 700
var radius := 14.0
var speed := 40.0
var color := Color.WHITE
var gold := 25
var elite := true
var target: Node2D
var game: Node
var phase := 0
var _pattern := ""
var _pt := 0.0
var _fired := 0
var _idx := 0
var _dir := Vector2.ZERO
var _angle := 0.0
var _flash := 0.0
var _spawn_t := 1.2
var _contact_cd := 0.0


func setup(k: String, player: Node2D, g: Node, hp_mult: float) -> CharacterBody2D:
	kind = k
	target = player
	game = g
	var d: Dictionary = KINDS[k]
	max_hp = int(d.hp * hp_mult)
	hp = max_hp
	radius = d.radius
	speed = d.speed
	color = d.color
	return self


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	Art.unshaded(self)
	collision_layer = 4
	collision_mask = 1
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = radius
	add_child(shape)


func _phases() -> Array:
	return KINDS[kind].patterns


func _next() -> void:
	var list: Array = _phases()[phase]
	_pattern = list[_idx % list.size()]
	_idx += 1
	_pt = -maxf(0.9 - phase * 0.25, 0.3)  # 패턴 사이 쉬는 시간
	_fired = 0


func _shoot(dir: Vector2, spd: float, big := false) -> void:
	Sfx.play("enemy_shoot", -12.0, randf_range(0.8, 1.0))
	var opts := {"radius": 3.5} if big else {}
	get_parent().add_child.call_deferred(Bullet.new().setup(position + dir * (radius + 2), dir * spd, 1, false, opts))


func _ring(n: int, spd: float, offset := 0.0, big := false) -> void:
	for i in n:
		_shoot(Vector2.RIGHT.rotated(TAU * i / n + offset), spd, big)


func _physics_process(delta: float) -> void:
	_flash -= delta
	queue_redraw()
	if _spawn_t > 0:
		_spawn_t -= delta
		if _spawn_t <= 0:
			Sfx.play("boss_roar")
			_next()
		return
	var to := target.position - position
	var dir := to.normalized()
	var fast := 1.0 + phase * 0.2
	_pt += delta * fast
	var want := dir * speed * 0.4 if to.length() > 90 else Vector2.ZERO
	if _pt >= 0:
		match _pattern:
			"ring":
				if _fired < 3 and _pt >= _fired * 0.6:
					_ring(14 + phase * 4, 70.0 + phase * 10, _fired * 0.25, _fired == 2)
					_fired += 1
				if _pt > 2.0:
					_next()
			"fan":
				want = Vector2.ZERO
				if _fired < 4 and _pt >= _fired * 0.45:
					for i in 5 + phase * 2:
						_shoot(dir.rotated((i - (2 + phase)) * 0.18), 120.0 + phase * 15)
					_fired += 1
				if _pt > 2.2:
					_next()
			"charge":
				# 0.6초 예고 후 돌진, 세 번 반복
				var cycle := fmod(_pt, 1.3)
				var n := int(_pt / 1.3)
				if n >= 3:
					_next()
				elif cycle < 0.6:
					want = Vector2.ZERO
					_dir = dir
				else:
					want = _dir * (260.0 + phase * 30)
					if n >= _fired:
						_fired += 1
						Fx.shake(0.15)
			"summon":
				want = Vector2.ZERO
				if _fired == 0 and _pt > 0.5:
					_fired = 1
					var pool := {"warden": ["ghoul", "archer"], "matron": ["bat", "bat", "slimelet"], "king": ["cultist", "brute", "ghoul"]}
					var adds: Array = pool[kind]
					for i in 2 + phase:
						game.spawn_enemy(adds[i % adds.size()], position + Vector2.RIGHT.rotated(TAU * i / (2 + phase)) * 40, false, true)
				if _pt > 1.5:
					_next()
			"spiral":
				want = Vector2.ZERO
				_angle += delta * 2.4
				if _pt < 3.2 and Engine.get_physics_frames() % 5 == 0:
					for a in 2 + phase:
						_shoot(Vector2.RIGHT.rotated(_angle + TAU * a / (2 + phase)), 80.0)
				if _pt > 3.6:
					_next()
			"teleport":
				if _fired == 0 and _pt > 0.3:
					_fired = 1
					Fx.burst(get_parent(), position, color, 20, 80.0)
					position = Vector2(randf_range(80, 400), randf_range(60, 210))
					if position.distance_to(target.position) < 100:
						position = Vector2(480, 270) - position
					Fx.burst(get_parent(), position, color, 20, 80.0)
				if _fired == 1 and _pt > 0.8:
					_fired = 2
					_ring(20, 85.0, 0.0, true)
				if _pt > 1.4:
					_next()
			"rain":
				# 위 벽에서 탄이 줄지어 떨어진다(틈 하나)
				if _fired < 4 and _pt >= _fired * 0.8:
					var gap := randi_range(2, 17)
					for i in 20:
						if absi(i - gap) > 1:
							get_parent().add_child.call_deferred(Bullet.new().setup(Vector2(24 + i * 23, 20), Vector2(0, 85), 1, false))
					_fired += 1
				if _pt > 3.6:
					_next()
	velocity = want
	move_and_slide()
	_contact_cd -= delta
	if to.length() < radius + 6 and _contact_cd <= 0:
		_contact_cd = 0.6
		target.hit(1, dir)


func hit(dmg: int, _knock := Vector2.ZERO, _status := {}) -> void:
	if hp <= 0 or _spawn_t > 0:
		return
	hp -= dmg
	_flash = 0.06
	Fx.burst(get_parent(), position, Color("ffffff", 0.8), 3, 60.0, 0.2)
	Sfx.play("hit", -10.0, randf_range(0.7, 0.9))
	var phases := _phases().size()
	var want_phase := mini(int((1.0 - float(hp) / max_hp) * phases), phases - 1)
	if want_phase > phase:
		phase = want_phase
		Sfx.play("boss_roar", 0.0, 1.15)
		Fx.shake(0.6)
		_ring(24, 60.0, 0.0, true)
		_idx = 0
	if hp <= 0:
		die(true)


func die(rewards: bool) -> void:
	if is_queued_for_deletion():
		return
	hp = 0
	Fx.burst(get_parent(), position, color, 60, 160.0, 0.9)
	Sfx.play("explode", 2.0, 0.7)
	Fx.shake(1.0)
	Fx.hitstop(0.25)
	remove_from_group("enemies")
	died.emit(self, rewards)
	queue_free()


func _draw() -> void:
	if _spawn_t > 0:
		draw_arc(Vector2.ZERO, radius * (1.0 + _spawn_t), 0, TAU, 32, color, 2.0)
		return
	var m := Color(4, 4, 4) if _flash > 0 else Color.WHITE
	if _pattern == "charge" and fmod(maxf(_pt, 0.0), 1.3) < 0.6 and int(_pt * 20) % 2 == 0:
		m = Color(2, 1.5, 1.5)
	draw_set_transform(Vector2(0, roundf(sin(Time.get_ticks_msec() / 300.0) * 1.5)))
	if not Art.draw(self, kind, target.position.x < position.x, m, 1.0, Color(1.0, 0.3, 0.15, 0.8)):
		draw_circle(Vector2.ZERO, radius, color * m)
	draw_set_transform(Vector2.ZERO)
