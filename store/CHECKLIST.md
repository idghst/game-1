# 스팀 출시 준비물 체크리스트

## 준비됨 (이 저장소)
- [x] 게임 빌드: Windows x64 / macOS universal / Linux x64(Steam Deck) — `forge build`
- [x] 캡슐 이미지 9종 — `store/capsules/`
  - header 920x430, small 462x174, main 1232x706, vertical 748x896
  - library capsule 600x900, library hero 3840x1240(로고 없음), library logo 1280x720(투명)
  - page background 1438x810, community icon 184x184
- [x] 스크린샷 8장(1920x1080, 실제 플레이) — `store/screenshots/` (Steam 최소 5장)
- [x] 짧은 설명·상세 설명·특징(한/영) — `store/STORE_PAGE.md`
- [x] 업적 14개 API 이름·조건 — `steam/README.md`
- [x] SteamPipe VDF 생성·업로드 스크립트 — `forge steam-vdf`, `forge steam-upload`
- [x] 크레딧·라이선스 — `CREDITS.md`, `assets/fonts/OFL.txt`

## 주인이 직접 해야 할 일 (Steamworks)
- [ ] Steamworks 파트너 가입, 앱 비용(Steam Direct) 결제, 세금·은행 정보
- [ ] App ID 발급 → `project.godot`의 `[steam] app_id` 한 줄 교체(현재 테스트용 480)
- [ ] Depot 3개(Windows/macOS/Linux) 만들고 `STEAM_DEPOT_*` 환경 변수로 업로드
- [ ] 업적 14개 등록(API 이름은 `steam/README.md` 표 그대로), 아이콘 업로드(달성/미달성 각 64x64 — 아직 없음)
- [ ] Steam Cloud 켜기(쿼터 1MB, 파일 4개 정도)
- [ ] 스토어 페이지 입력, 캡슐·스크린샷 업로드, 가격·출시일, 연령 등급 설문(IARC)
- [ ] 트레일러 영상(선택이지만 강력 권장, 아직 없음)
- [ ] Steam Deck 호환성 검토 요청
- [ ] macOS 공증(notarization): Apple 개발자 계정으로 서명·공증하지 않으면 Gatekeeper 경고. 현재 ad-hoc 서명
- [ ] Windows 실행 파일 아이콘: rcedit 설치 후 `export_presets.cfg`의 `application/modify_resources=true`
- [ ] 실기 확인: 실제 게임패드, Windows·Linux·Steam Deck 실행, Steam 클라이언트에서 업적·Cloud·오버레이
