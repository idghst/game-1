extends Node
## Steam 연동(GodotSteam GDExtension): 초기화, 콜백, 업적, Steam Cloud, 오버레이.
## App ID는 프로젝트 설정 steam/app_id 한 곳에서 정한다(0이면 끔, 테스트는 480).
## 애드온이 없거나 Steam 클라이언트가 꺼져 있으면 active=false로 두고 게임은 그대로 돈다.

signal overlay_toggled(active: bool)

var active := false
var on_deck := false
var _steam: Object


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var app_id := int(ProjectSettings.get_setting("steam/app_id", 0))
	if app_id <= 0 or not Engine.has_singleton("Steam") or DisplayServer.get_name() == "headless":
		return
	_steam = Engine.get_singleton("Steam")
	if not _steam.isSteamRunning():
		print("steam: 클라이언트가 실행 중이 아니어서 Steam 기능 없이 시작합니다")
		return
	var r: Dictionary = _steam.steamInitEx(app_id, false)
	if int(r.get("status", -1)) != 0:
		push_warning("steam: 초기화 실패 %s" % r)
		return
	active = true
	on_deck = _steam.has_method("isSteamRunningOnSteamDeck") and _steam.isSteamRunningOnSteamDeck()
	_steam.overlay_toggled.connect(func(on: bool, _user: bool, _app: int) -> void: overlay_toggled.emit(on))
	print("steam: 초기화 완료 (app %d)" % app_id)


func _process(_delta: float) -> void:
	if active:
		_steam.run_callbacks()


func unlock(api_name: String) -> void:
	if not active:
		return
	var a: Dictionary = _steam.getAchievement(api_name)
	if a.get("ret", false) and not a.get("achieved", false):
		_steam.setAchievement(api_name)
		_steam.storeStats()


func cloud_enabled() -> bool:
	return active and _steam.isCloudEnabledForAccount() and _steam.isCloudEnabledForApp()


func cloud_write(file: String, bytes: PackedByteArray) -> bool:
	return cloud_enabled() and _steam.fileWrite(file, bytes, bytes.size())


func cloud_read(file: String) -> PackedByteArray:
	if not cloud_enabled() or not _steam.fileExists(file):
		return PackedByteArray()
	var r: Dictionary = _steam.fileRead(file, _steam.getFileSize(file))
	return r.get("buf", PackedByteArray()) if r.get("ret", 0) > 0 else PackedByteArray()
