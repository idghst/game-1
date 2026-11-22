extends Node
## 타격감 효과: 화면 흔들림(trauma), 히트스톱, 파티클 버스트.

var shake_enabled := true
var trauma := 0.0  # 0~1, 카메라가 매 프레임 읽어 흔든다
var _hitstop_left := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func shake(amount: float) -> void:
	if shake_enabled:
		trauma = minf(trauma + amount, 1.0)


func hitstop(seconds: float) -> void:
	_hitstop_left = maxf(_hitstop_left, seconds)
	Engine.time_scale = 0.05


func shake_offset(max_px: float) -> Vector2:
	var k := trauma * trauma * max_px
	return Vector2(randf_range(-k, k), randf_range(-k, k)).round()


func _process(delta: float) -> void:
	# time_scale에 영향받지 않는 실제 시간으로 줄인다
	var real := delta / maxf(Engine.time_scale, 0.0001)
	trauma = maxf(trauma - real * 1.8, 0.0)
	if _hitstop_left > 0:
		_hitstop_left -= real
		if _hitstop_left <= 0:
			Engine.time_scale = 1.0


# 한 번 터지고 사라지는 픽셀 파티클.
func burst(parent: Node, pos: Vector2, color: Color, amount := 10, speed := 70.0, life := 0.35) -> void:
	if not is_instance_valid(parent):
		return
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = life
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.damping_min = speed * 1.5
	p.damping_max = speed * 2.5
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = color
	p.emitting = true
	parent.add_child(p)
	p.finished.connect(p.queue_free)
