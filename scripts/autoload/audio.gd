extends Node
## 효과음(SFX 버스, 플레이어 풀)과 배경음(Music 버스, 교차 페이드).

const POOL := 16
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _streams := {}
var _last_played := {}  # 같은 소리가 한 프레임에 겹쳐 터지지 않게
var _music: Array[AudioStreamPlayer] = []
var _music_name := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_players.append(p)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.bus = &"Music"
		add_child(m)
		_music.append(m)


func _stream(name: String, loop := false) -> AudioStream:
	if not _streams.has(name):
		var path := "res://assets/audio/%s.wav" % name
		var s: AudioStreamWAV = load(path) if ResourceLoader.exists(path) else null
		if s and loop:
			s = s.duplicate()
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_end = s.data.size() / 2  # 16비트 모노
		_streams[name] = s
	return _streams[name]


func play(name: String, volume_db := 0.0, pitch := 1.0) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_played.get(name, -1000) < 35:
		return
	_last_played[name] = now
	var s := _stream(name)
	if s == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % POOL
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


func music(name: String) -> void:
	if name == _music_name:
		return
	_music_name = name
	var old := _music[0]
	var new := _music[1]
	_music.reverse()
	var tw := create_tween().set_parallel()
	if old.playing:
		tw.tween_property(old, "volume_db", -40.0, 0.8)
		tw.chain().tween_callback(old.stop)
	var s := _stream(name, true) if name != "" else null
	if s:
		new.stream = s
		new.volume_db = -40.0
		new.play()
		create_tween().tween_property(new, "volume_db", 0.0, 0.8)
