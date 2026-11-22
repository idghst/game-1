extends Node
## 업적 14개. 해금은 프로필에 저장하고 Steam에도 알린다(Steam API 이름 = id 대문자).
## 이름·설명 키: ACH_<ID>, ACH_<ID>_DESC

signal unlocked(id: String)

const ALL := ["first_blood", "warden", "matron", "king", "untouched", "synergy", "legendary", "hoarder",
	"slayer", "elite_hunter", "swift_vigil", "devoted", "dasher", "persistent"]

var session_new: Array = []  # 이번 판에 새로 얻은 업적(결과 화면 표시용)


func unlock(id: String) -> void:
	assert(id in ALL)
	if Profile.data.achievements.has(id):
		return
	Profile.data.achievements.append(id)
	Profile.save()
	session_new.append(id)
	SteamService.unlock(id.to_upper())
	unlocked.emit(id)


func has(id: String) -> bool:
	return Profile.data.achievements.has(id)


# 누적 통계 기반 업적(판 종료 후 호출)
func check_totals() -> void:
	var t: Dictionary = Profile.data.totals
	if t.kills >= 1:
		unlock("first_blood")
	if t.kills >= 1000:
		unlock("slayer")
	if t.elites >= 50:
		unlock("elite_hunter")
	if t.dashes >= 500:
		unlock("dasher")
	if t.runs >= 10:
		unlock("persistent")


func check_meta() -> void:
	var levels := 0
	for id in Profile.data.meta:
		levels += Profile.data.meta[id]
	if levels >= 5:
		unlock("devoted")
