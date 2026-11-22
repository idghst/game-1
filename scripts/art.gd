extends RefCounted
## 스프라이트 텍스처 캐시. 파일이 없으면 null을 돌려주고, 호출한 쪽은 도형으로 대신 그린다.

static var _cache := {}


static func tex(name: String) -> Texture2D:
	if not _cache.has(name):
		var path := "res://assets/sprites/%s.png" % name
		_cache[name] = load(path) if ResourceLoader.exists(path) else null
	return _cache[name]


# 가운데 기준으로 그린다. flip이면 좌우 반전, flash면 하얗게.
static func draw(item: CanvasItem, name: String, flip := false, modulate := Color.WHITE, scale := 1.0) -> bool:
	var t := tex(name)
	if t == null:
		return false
	item.draw_set_transform(Vector2.ZERO, 0.0, Vector2(-scale if flip else scale, scale))
	item.draw_texture(t, -t.get_size() / 2, modulate)
	item.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true
