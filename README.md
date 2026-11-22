# Hollow Vigil (할로우 비질)

다크 판타지 던전을 내려가는 2D 탑다운 트윈스틱 로그라이트. Godot 4.7 + GDScript, 480x270 픽셀아트(정수 배율, nearest).

- 9층(테마 3개 × 3층), 3·6·9층 보스, 9층 보스 처치가 엔딩. 한 판 15~25분.
- 적 7계열 + 엘리트, 보스 3종, 축복 22개(희귀도 4단계, 태그 3개 시너지), 방 5종(전투·보물·상점·관문·보스)
- 잿불 제단 영구 강화 10종, 업적 14개, Steam Cloud, 한국어·영어, 키·패드 재설정

## 지원 플랫폼

| 구분 | 플랫폼 | 검증 |
|---|---|---|
| 메인 | Windows 10/11 x64 | CI `windows-latest`에서 배포 exe 실행: 헤드리스 자동 플레이 한 판, 실제 창(ANGLE/Direct3D) 렌더·정수 배율·전체 화면, 저장, GodotSteam DLL, 메타데이터·아이콘·GUI 서브시스템, `forge test --quick` |
| 메인 | macOS 11+ (Apple Silicon·Intel 유니버설) | CI `macos-latest`(Apple Silicon)에서 배포 앱 실행: 같은 스모크, 유니버설 바이너리·ad-hoc 서명 확인 |
| 부가 | Linux x64 / SteamOS(Steam Deck) | 빌드와 헤드리스 스모크는 돌지만 실패해도 CI를 막지 않음 |

배포 빌드 스모크는 누구나 돌릴 수 있습니다: `HollowVigil.exe --headless --fixed-fps 60 -- --smoke`, 실제 창은 `-- --smoke-render`(결과: 사용자 데이터 폴더의 `smoke_result.txt`).

## Windows에 설치하기

1. [Releases](https://github.com/idghst/game-1/releases)에서 `HollowVigil-Setup-<버전>.exe`를 받아 실행합니다. 같은 곳의 `SHA256SUMS.txt`로 파일을 확인할 수 있습니다.
2. 코드 서명이 없어서 **"Windows의 PC 보호"(SmartScreen) 창**이 뜰 수 있습니다. **추가 정보 → 실행**을 누르면 설치가 계속됩니다.
3. 관리자 권한 없이 내 계정(`%LOCALAPPDATA%\Programs\Hollow Vigil`)에 설치되고, 시작 메뉴에 바로가기가 생깁니다. 바탕화면 바로가기는 설치 중에 고를 수 있습니다.
4. 지우려면 Windows **설정 → 앱 → 설치된 앱**에서 Hollow Vigil을 제거합니다. 저장 파일(`%APPDATA%\Godot\app_userdata\Hollow Vigil`)은 지워지지 않으니, 완전히 지우려면 이 폴더도 직접 삭제하세요.

설치하지 않고 쓰려면 `HollowVigil-<버전>-windows.zip`을 풀고 `HollowVigil.exe`를 실행합니다.

### 릴리스 만들기(관리자)
`project.godot`의 `config/version`을 올리고 머지한 뒤, 같은 버전의 태그(`v0.9.0` 형식)를 푸시하면 `.github/workflows/release.yml`이
테스트·실기 검증을 다시 돌리고 설치 파일·zip·체크섬을 GitHub Release로 올립니다. 설치 파일만 로컬에서 만들려면 Windows에서
`forge build windows` 후 `ISCC /DAppVersion=<버전> installer\HollowVigil.iss`(Inno Setup 6).

## 실행

```sh
brew install --cask godot                    # Godot 4.7.x
cargo build --release --manifest-path tools/forge/Cargo.toml
tools/forge/target/release/forge steam-addon # GodotSteam(선택, 없으면 Steam 없이 실행)
godot --headless --path . --import           # 첫 실행 전 한 번
godot --path .                               # 게임 실행
```

조작: WASD 이동, 마우스 조준·좌클릭 사격, Space/Shift 대시, E 상호작용, Esc 일시정지.
게임패드: 왼스틱 이동, 오른스틱 조준, RT 사격, LB/LT 대시, X 상호작용, Start 일시정지, 메뉴는 D패드/스틱 + A/B.

## 도구 (`tools/forge`, Rust)

| 명령 | 하는 일 |
|---|---|
| `forge test [--long\|--quick]` | 헤드리스 자가검증 전체(던전 연결성, 번역, 저장 손상, 9층 흐름, 패드 전용 메뉴, 자동 플레이, 실력별 밸런스) |
| `forge build [windows,macos,linux]` | 내보내기 → `build/`(생략하면 세 플랫폼) |
| `forge steam-addon` | GodotSteam GDExtension 받기(체크섬 확인) |
| `forge steam-vdf` / `forge steam-upload` | SteamPipe VDF 생성 / steamcmd 업로드 (`steam/README.md`) |
| `forge gen` → `forge pixel` | 맥미니 이미지 생성기로 원본 생성 → 공용 팔레트 픽셀아트 변환 |
| `forge sfx` | 효과음·배경음 합성 |
| `forge capsules` | 스토어 캡슐 이미지 |
| `forge graph` | GDScript(.gd·.tscn·project.godot)를 직접 읽어 graphify 그래프에 합치고 Obsidian·HTML로 내보내기(주석은 읽지 않음) |

창이 필요한 확인: `godot --path . -s tests/test_perf.gd`(프레임 속도), `godot --path . -s tools/screenshot.gd -- <폴더> [장면...]`(스크린샷).

## 문서

- 밸런스 측정과 봇의 한계: `docs/BALANCE.md`
- Steam 연동·업로드: `steam/README.md`
- 스토어 페이지·출시 체크리스트: `store/`
- 크레딧·라이선스: `CREDITS.md`
