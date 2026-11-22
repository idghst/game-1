extends RefCounted
## 스프라이트 텍스처 캐시. 파일이 없으면 null을 돌려주고, 호출한 쪽은 도형으로 대신 그린다.

static var _cache := {}


# 어두운 환경광의 영향을 받지 않게 한다(캐릭터·탄·픽업 가독성)
static func unshaded(item: CanvasItem) -> void:
	var m := CanvasItemMaterial.new()
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	item.material = m


static func tex(name: String) -> Texture2D:
	if not _cache.has(name):
		var path := "res://assets/sprites/%s.png" % name
		_cache[name] = load(path) if ResourceLoader.exists(path) else null
	return _cache[name]


# 가운데 기준으로 그린다. flip이면 좌우 반전. rim이 있으면 1px 밝은 테두리(림라이트)를 먼저 그린다.
static func draw(item: CanvasItem, name: String, flip := false, modulate := Color.WHITE, scale := 1.0, rim := Color(0, 0, 0, 0)) -> bool:
	var t := tex(name)
	if t == null:
		return false
	item.draw_set_transform(Vector2.ZERO, 0.0, Vector2(-scale if flip else scale, scale))
	if rim.a > 0:
		# 색을 크게 곱해 실루엣을 rim 색으로 포화시킨다
		var sil := Color(rim.r * 60.0, rim.g * 60.0, rim.b * 60.0, rim.a * modulate.a)
		for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
			item.draw_texture(t, -t.get_size() / 2 + o, sil)
	item.draw_texture(t, -t.get_size() / 2, modulate)
	item.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true
