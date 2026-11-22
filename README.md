# Dungeon Prototype

2D 탑다운 트윈스틱 로그라이트 프로토타입 (Godot 4.7, GDScript). 그래픽은 도형/단색이며 480x270 뷰포트를 정수 배율로 키운다.

## 실행

```sh
brew install --cask godot
godot --path .            # 게임 실행
godot --path . --editor   # 에디터로 열기
```

조작: WASD 이동, 마우스 조준 + 좌클릭 사격. 게임패드는 왼스틱 이동, 오른스틱 조준, RT 사격. 메뉴는 마우스 클릭 또는 방향키/D패드 + Enter/A.

## 자가검증

```sh
godot --headless --path . -s tests/test_dungeon.gd   # 절차 생성 던전 연결성 (2000 시드)
godot --headless --path . -s tests/test_flow.gd      # 층 클리어 → 업그레이드 → 다음 층, 사망 → 게임오버
godot --headless --path . --quit-after 600            # 메인 씬 로드·실행
godot --path . -s tools/screenshot.gd -- screenshots  # 실제 창 스크린샷 2장
```
