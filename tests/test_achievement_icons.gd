extends SceneTree
## 업적 아이콘 자가검증: godot --headless --path . -s tests/test_achievement_icons.gd
## store/achievements/(64x64)와 256/(256x256)에 업적 정의(Achievements.ALL)마다 <id>.png·<id>_locked.png가
## 정확히 있고, 다른 PNG는 없는지, 미달성본은 무채색이고 달성본은 색이 있는지 확인한다.

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


# 공용 팔레트 회색(0b0a0f~ece6e8)은 색 폭(max-min)이 0.1 미만, 달성본의 청동 테두리(ba8a5e)는 0.36이다
func _max_chroma(path: String) -> float:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	var best := 0.0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			best = maxf(best, maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b)))
	return best


func _initialize() -> void:
	var ids: Array = load("res://scripts/autoload/achievements.gd").ALL
	check(ids.size() == 14, "14 achievements defined")
	_check_dir("res://store/achievements", 64, ids)
	_check_dir("res://store/achievements/256", 256, ids)
	check(FileAccess.file_exists("res://store/achievements/sheet.png"), "sheet.png exists")
	for id in ids:
		check(_max_chroma("res://store/achievements/%s_locked.png" % id) < 0.1, "%s_locked is grey" % id)
		check(_max_chroma("res://store/achievements/%s.png" % id) > 0.3, "%s has color" % id)
	print("achievement icons self-test: %d ids, %d failures" % [ids.size(), fails])
	quit(1 if fails else 0)
