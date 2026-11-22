extends RefCounted

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
## 메뉴 만들기 도우미: 가운데 패널 + 제목 + 버튼 목록. 첫 버튼에 포커스를 주어 패드만으로 조작된다.


static func overlay(parent: Node, dim := 0.6) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, dim)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	parent.add_child(root)
	return root


static func panel(root: Control, title: String, min_width := 200.0) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var p := PanelContainer.new()
	p.custom_minimum_size.x = min_width
	center.add_child(p)
	var box := VBoxContainer.new()
	p.add_child(box)
	if title != "":
		var t := Label.new()
		t.text = title
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UiTheme.big(t)
		t.add_theme_color_override("font_color", Color("f8c040"))
		box.add_child(t)
	return box


static func button(box: Container, text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(on_press)
	box.add_child(b)
	return b


static func focus_first(box: Node) -> void:
	for c in box.find_children("*", "", true, false):
		if c is Control and c.focus_mode == Control.FOCUS_ALL and c.visible and not (c is BaseButton and c.disabled):
			c.grab_focus.call_deferred()
			return
