extends Area2D
## 플레이어 탄과 적 탄. 플레이어 탄은 관통·튕김·유도·폭발·화상·감속을 가질 수 있다.

var velocity := Vector2.ZERO
var damage := 10
var color := Color.WHITE
var radius := 2.0
var life := 3.0
var pierce := 0
var bounce := 0
var homing := 0.0
var explode := 0.0
var status := {}  # {"burn": true, "slow": true}
var from_player := true
var _hit := {}  # 관통 시 같은 적을 두 번 때리지 않게
var _spent := false


func setup(pos: Vector2, vel: Vector2, dmg: int, is_player: bool, opts := {}) -> Area2D:
	position = pos
	velocity = vel
	damage = dmg
	from_player = is_player
	collision_layer = 0
	collision_mask = 1 | (4 if is_player else 2)  # 벽 + (적 | 플레이어)
	color = opts.get("color", Color("f4e27a") if is_player else Color("ff5a8a"))
	radius = opts.get("radius", 2.0 if is_player else 2.5)
	life = opts.get("life", 3.0)
	pierce = opts.get("pierce", 0)
	bounce = opts.get("bounce", 0)
	homing = opts.get("homing", 0.0)
	explode = opts.get("explode", 0.0)
	status = opts.get("status", {})
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = radius
	add_child(shape)
	body_entered.connect(_on_body_entered)
	add_to_group("bullets_player" if is_player else "bullets_enemy")
	return self


func _physics_process(delta: float) -> void:
	if homing > 0:
		var best: Node2D = null
		var best_d := 140.0
		for e in get_tree().get_nodes_in_group("enemies"):
			var d := position.distance_to(e.position)
			if d < best_d and not _hit.has(e.get_instance_id()):
				best_d = d
				best = e
		if best:
			var want := velocity.angle_to(best.position - position)
			velocity = velocity.rotated(clampf(want, -homing * delta, homing * delta))
	position += velocity * delta
	life -= delta
	if life <= 0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if _spent:
		return
	if body.has_method("hit"):
		if _hit.has(body.get_instance_id()):
			return
		_hit[body.get_instance_id()] = true
		body.hit(damage, velocity.normalized(), status)
		if explode > 0:
			_explode()
		if pierce > 0:
			pierce -= 1
			return
	elif bounce > 0:
		bounce -= 1
		var n := _wall_normal()
		if n != Vector2.ZERO:
			velocity = velocity.bounce(n)
			return
	else:
		Fx.burst(get_parent(), position, color, 4, 40.0, 0.15)
		if explode > 0:
			_explode()
	_spent = true
	queue_free()


func _wall_normal() -> Vector2:
	var q := PhysicsRayQueryParameters2D.create(position - velocity * 0.05, position + velocity * 0.05, 1)
	var r := get_world_2d().direct_space_state.intersect_ray(q)
	return r.get("normal", Vector2.ZERO)


func _explode() -> void:
	Fx.burst(get_parent(), position, Color("ff9a40"), 16, 90.0, 0.3)
	Fx.shake(0.12)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.position.distance_to(position) < explode and not _hit.has(e.get_instance_id()):
			e.hit(int(damage * 0.5), (e.position - position).normalized(), {})


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)
	if radius > 2.5:
		draw_circle(Vector2.ZERO, radius - 1.5, Color.WHITE)
