# Hollow Vigil

Godot 4.7 + GDScript 2D 탑다운 트윈스틱 로그라이트(스팀 출시 목표). 480x270 뷰포트, 정수 배율, nearest 필터.

## 패키지명
- macOS 번들 ID: `kr.co.idghst.hollowvigil` (`export_presets.cfg`)

## 제목 바꾸기
- `project.godot`의 `application/config/name`, `translations/strings.csv`의 `GAME_TITLE`, `assets/logo/*.svg`, `export_presets.cfg`의 제품명, `store/` 문서.

## 명령
- 테스트: `tools/forge/target/release/forge test` (헤드리스 자가검증 전체)
- 내보내기: `forge build`, Steam 애드온: `forge steam-addon`, 에셋: `forge gen` → `forge pixel`, 오디오: `forge sfx`
- 자동화 스크립트는 Rust(`tools/forge`)로 작성한다.
