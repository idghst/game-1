extends Area2D

var velocity := Vector2.ZERO
var damage := 1
var color := Color.WHITE
var _life := 3.0
var _spent := false


func setup(pos: Vector2, vel: Vector2, dmg: int, from_player: bool) -> Area2D:
	position = pos
	velocity = vel
	damage = dmg
	collision_layer = 0
	collision_mask = 1 | (4 if from_player else 2)  # 벽 + (적 | 플레이어)
	color = Color("f4e27a") if from_player else Color("ff5a8a")
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 2
	add_child(shape)
	body_entered.connect(_on_body_entered)
	return self


func _physics_process(delta: float) -> void:
	position += velocity * delta
	_life -= delta
	if _life <= 0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if _spent:
		return
	_spent = true
	if body.has_method("hit"):
		body.hit(damage)
	queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 2, color)
