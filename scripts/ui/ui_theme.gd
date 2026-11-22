extends RefCounted
## 공용 UI 테마: 픽셀 폰트, 어두운 패널, 금색 포커스 테두리(패드 조작 시 현재 위치가 잘 보이게).

# 본문은 갈무리9(10px), 제목은 갈무리11(12px). 픽셀 폰트라 이 크기에서만 또렷하다.
const FONT_PATH := "res://assets/fonts/Galmuri9.ttf"
const BIG_FONT_PATH := "res://assets/fonts/Galmuri11.ttf"


static func _font(path: String) -> FontFile:
	if not ResourceLoader.exists(path):
		return null
	var f: FontFile = load(path)
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return f


# 제목용 큰 글씨
static func big(c: Control) -> void:
	var f := _font(BIG_FONT_PATH)
	if f:
		c.add_theme_font_override("font", f)
	c.add_theme_font_size_override("font_size", 12)


static func _box(bg: Color, border: Color, width := 1, margin := 4) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_content_margin_all(margin)
	s.anti_aliasing = false
	return s


static func build() -> Theme:
	var t := Theme.new()
	var f := _font(FONT_PATH)
	if f:
		t.default_font = f
	t.default_font_size = 10
	var text := Color("ece6e8")
	t.set_color("font_color", "Label", text)
	t.set_stylebox("panel", "PanelContainer", _box(Color("120f18", 0.95), Color("5a4a6a"), 1, 6))
	t.set_stylebox("panel", "Panel", _box(Color("120f18", 0.95), Color("5a4a6a"), 1, 8))
	for type in ["Button", "OptionButton", "CheckButton"]:
		t.set_stylebox("normal", type, _box(Color("231e2b"), Color("4a4054"), 1, 2))
		t.set_stylebox("hover", type, _box(Color("342c3d"), Color("85798e"), 1, 2))
		t.set_stylebox("pressed", type, _box(Color("4a4054"), Color("a89cae"), 1, 2))
		t.set_stylebox("disabled", type, _box(Color("17141d"), Color("231e2b"), 1, 2))
		var focus := _box(Color(0, 0, 0, 0), Color("f8c040"), 1)
		focus.draw_center = false
		t.set_stylebox("focus", type, focus)
		t.set_color("font_color", type, text)
		t.set_color("font_hover_color", type, Color.WHITE)
		t.set_color("font_focus_color", type, Color("fce888"))
		t.set_color("font_disabled_color", type, Color("655a70"))
	t.set_stylebox("slider", "HSlider", _box(Color("231e2b"), Color("4a4054"), 1, 2))
	t.set_stylebox("grabber_area", "HSlider", _box(Color("966244"), Color("966244"), 0, 2))
	t.set_stylebox("grabber_area_highlight", "HSlider", _box(Color("f8c040"), Color("f8c040"), 0, 2))
	var hfocus := _box(Color(0, 0, 0, 0), Color("f8c040"), 1)
	hfocus.draw_center = false
	t.set_stylebox("focus", "HSlider", hfocus)
	t.set_constant("separation", "VBoxContainer", 2)
	t.set_constant("separation", "HBoxContainer", 6)
	return t
