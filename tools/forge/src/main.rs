//! Hollow Vigil 자동화 도구.
//! - `forge gen`   : assets/src/manifest.txt의 원본 이미지를 맥미니 이미지 생성기로 만든다(이미 있으면 건너뜀).
//! - `forge pixel` : 원본을 게임용 픽셀아트(assets/sprites/*.png)로 축소·팔레트 정리한다.
//! - `forge sheet <out.png>` : 확인용으로 모든 스프라이트를 확대해 한 장에 모은다.
//! - `forge sfx`   : 효과음·배경음을 합성해 assets/audio/*.wav로 쓴다.
//! - `forge steam-addon` : GodotSteam GDExtension을 받아 addons/godotsteam에 푼다(체크섬 확인).
//! - `forge test [--long|--quick]` : 헤드리스 자가검증(GODOT 환경 변수로 godot 경로 지정). --quick은 밸런스를 빼고 자동 플레이 1판.
//! - `forge build [windows,macos,linux]` : 내보내기(build/). 생략하면 세 플랫폼 모두.
//! - `forge steam-vdf` / `forge steam-upload` : SteamPipe VDF 생성 / steamcmd 업로드.
//! - `forge capsules` : Steam 스토어 캡슐 이미지(store/capsules/)를 키 아트+로고로 만든다.
//! - `forge graph` : GDScript를 직접 읽어 graphify 그래프에 합치고 Obsidian·HTML로 내보낸다.

mod audio;
mod gdgraph;
mod pixel;
mod release;
mod store;

use std::path::{Path, PathBuf};
use std::process::{exit, Command};

pub struct Entry {
    pub name: String,
    pub kind: String,
    pub w: u32,
    pub h: u32,
    pub key: String,
    pub prompt: String,
}

fn root() -> PathBuf {
    // tools/forge 에서 실행해도, 저장소 루트에서 실행해도 동작하게 project.godot를 찾는다
    let mut dir = std::env::current_dir().expect("현재 폴더");
    while !dir.join("project.godot").exists() {
        if !dir.pop() {
            eprintln!("project.godot를 찾지 못했습니다. 저장소 안에서 실행하세요.");
            exit(1);
        }
    }
    dir
}

fn manifest(root: &Path) -> Vec<Entry> {
    let text = std::fs::read_to_string(root.join("assets/src/manifest.txt")).expect("manifest.txt 읽기");
    text.lines()
        .filter(|l| !l.trim().is_empty() && !l.starts_with('#'))
        .map(|l| {
            let f: Vec<&str> = l.split('|').map(str::trim).collect();
            assert!(f.len() == 5, "잘못된 manifest 줄: {l}");
            let (w, h) = f[2].split_once('x').expect("크기는 WxH");
            Entry {
                name: f[0].into(),
                kind: f[1].into(),
                w: w.parse().unwrap(),
                h: h.parse().unwrap(),
                key: f[3].into(),
                prompt: f[4].into(),
            }
        })
        .collect()
}

fn prompt_for(e: &Entry) -> (String, u32, u32) {
    match e.kind.as_str() {
        "sprite" => {
            let bg = if e.key == "green" { "pure green #00FF00" } else { "pure magenta #FF00FF" };
            (format!("16-bit pixel art game sprite of {}, top-down three-quarter view, centered, full body, dark fantasy, limited palette, crisp pixels, isolated on a flat solid {bg} background, no shadow, no ground, no text, no border", e.prompt), 512, 512)
        }
        "badge" => {
            let bg = if e.key.starts_with("green") { "pure green #00FF00" } else { "pure magenta #FF00FF" };
            (format!("16-bit pixel art game achievement icon of {}, single bold object, centered, large and readable silhouette, dark fantasy, limited palette, crisp pixels, isolated on a flat solid {bg} background, no shadow, no text, no border, no frame", e.prompt), 512, 512)
        }
        "tile" => (format!("{}, 16-bit pixel art game texture, dark fantasy, fills the whole frame, no border, no text", e.prompt), 512, 512),
        _ => (format!("{}, 16-bit pixel art, no text, no border", e.prompt), 1024, 576),
    }
}

fn gen(root: &Path, only: Option<&str>) {
    let bin = std::env::var("MACMINI_IMAGE_BIN").unwrap_or_else(|_| {
        let home = std::env::var("HOME").unwrap_or_default();
        format!("{home}/claude-plugins/macmini-image/bin/macmini-image")
    });
    for e in manifest(root) {
        if only.is_some_and(|o| o != e.name) {
            continue;
        }
        let out = root.join(format!("assets/src/{}.png", e.name));
        if out.exists() && only.is_none() {
            continue;
        }
        let (prompt, w, h) = prompt_for(&e);
        println!("생성: {}", e.name);
        let ok = Command::new(&bin)
            .args(["generate", "--prompt", &prompt, "--output"])
            .arg(&out)
            .args(["--width", &w.to_string(), "--height", &h.to_string(), "--steps", "16"])
            .status()
            .map(|s| s.success())
            .unwrap_or(false);
        if !ok {
            eprintln!("실패: {} (macmini-image check로 런타임을 확인하세요)", e.name);
            exit(1);
        }
    }
}

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let root = root();
    match args.first().map(String::as_str) {
        Some("gen") => gen(&root, args.get(1).map(String::as_str)),
        Some("pixel") => pixel::run(&root, &manifest(&root)),
        Some("sfx") => audio::run(&root),
        Some("steam-addon") => release::steam_addon(&root),
        Some("test") => release::test(&root, args.iter().any(|a| a == "--long"), args.iter().any(|a| a == "--quick")),
        Some("build") => release::build(&root, args.get(1).map(String::as_str)),
        Some("steam-vdf") => {
            release::steam_vdf(&root);
        }
        Some("steam-upload") => release::steam_upload(&root),
        Some("capsules") => store::run(&root),
        Some("graph") => gdgraph::run(&root),
        Some("sheet") => pixel::sheet(&root, &manifest(&root), Path::new(args.get(1).map(String::as_str).unwrap_or("sheet.png"))),
        _ => {
            eprintln!("사용법: forge <gen [이름] | pixel | sheet <out.png> | sfx | steam-addon | test [--long|--quick] | build [플랫폼,...] | steam-vdf | steam-upload | capsules | graph>");
            exit(2);
        }
    }
}
