extends Area2D
## 바닥 픽업: 동전, 하트, 보물 상자, 상점 상품, 다음 층 계단.

signal taken(pickup: Area2D)

const Art = preload("res://scripts/art.gd")
const Upgrades = preload("res://scripts/upgrades.gd")

var kind := "coin"  # coin | heart | chest | shop | stairs
var value := 1  # 동전 액수 또는 상품 가격
var item := ""  # 상점 상품: 업그레이드 id 또는 "heart"
var player: Node2D
var _t := 0.0


func setup(k: String, pos: Vector2, p: Node2D, v := 1, it := "") -> Area2D:
	kind = k
	position = pos
	player = p
	value = v
	item = it
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 10.0 if kind in ["chest", "shop", "stairs"] else 5.0
	add_child(shape)
	add_to_group("pickups")
	return self


# 상점·상자처럼 버튼으로 집는지
func needs_interact() -> bool:
	return kind in ["shop", "stairs"]


func _physics_process(delta: float) -> void:
	_t += delta
	if kind in ["coin", "heart"]:
		var d := position.distance_to(player.position)
		if d < 48:
			position = position.move_toward(player.position, (220.0 - d * 3) * delta)  # 자석
	# 방에 들어온 직후에는 이전 방 위치의 겹침 정보가 남아 있으므로 잠시 무시한다
	if _t > 0.2 and not needs_interact() and overlaps_body(player):
		taken.emit(self)
	queue_redraw()


func _draw() -> void:
	var bob := Vector2(0, roundf(sin(_t * 4.0)))
	match kind:
		"coin", "heart", "chest":
			draw_set_transform(bob if kind != "chest" else Vector2.ZERO)
			Art.draw(self, kind)
		"stairs":
			Art.draw(self, "stairs")
		"shop":
			draw_rect(Rect2(-8, 5, 16, 3), Color("3a3040"))
			draw_set_transform(bob + Vector2(0, -2))
			if item == "heart":
				Art.draw(self, "heart")
			else:
				var up: Dictionary = Upgrades.ALL[item]
				draw_rect(Rect2(-7, -7, 14, 14), Upgrades.RARITY_COLOR[up.rarity], false, 1.0)
				Art.draw(self, "icon_" + up.tag)
			draw_set_transform(Vector2.ZERO)
			var font := ThemeDB.fallback_font
			draw_string(font, Vector2(-20, 18), "%dg" % value, HORIZONTAL_ALIGNMENT_CENTER, 40, 8, Color("f8c040"))
	draw_set_transform(Vector2.ZERO)
