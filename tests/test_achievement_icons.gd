extends SceneTree
## 업적 아이콘 자가검증: godot --headless --path . -s tests/test_achievement_icons.gd
## store/achievements/(64x64)와 256/(256x256)에 업적 정의(Achievements.ALL)마다 <id>.png·<id>_locked.png가
## 정확히 있고, 다른 PNG는 없는지 확인한다.

var fails := 0


func check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		printerr("FAIL: ", msg)


func _check_dir(dir: String, size: int, ids: Array) -> void:
	var want := {}
	for id in ids:
		want[id + ".png"] = true
		want[id + "_locked.png"] = true
	var got := {}
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".png") and f != "sheet.png":
			got[f] = true
	check(got.size() == want.size() and got.has_all(want.keys()), "%s: files %s != expected %s" % [dir, got.keys(), want.keys()])
	for f in want:
		var img := Image.load_from_file(ProjectSettings.globalize_path(dir.path_join(f)))
		check(img != null and img.get_width() == size and img.get_height() == size, "%s/%s is %dx%d" % [dir, f, size, size])


func _initialize() -> void:
	var ids: Array = load("res://scripts/autoload/achievements.gd").ALL
	check(ids.size() == 14, "14 achievements defined")
	_check_dir("res://store/achievements", 64, ids)
	_check_dir("res://store/achievements/256", 256, ids)
	check(FileAccess.file_exists("res://store/achievements/sheet.png"), "sheet.png exists")
	print("achievement icons self-test: %d ids, %d failures" % [ids.size(), fails])
	quit(1 if fails else 0)
