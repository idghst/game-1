//! 빌드·배포: GodotSteam 애드온 받기, 테스트 실행, 3플랫폼 내보내기, SteamPipe VDF 생성·업로드.

use std::io::Read;
use std::path::{Path, PathBuf};
use std::process::{exit, Command};

const GODOTSTEAM_URL: &str = "https://codeberg.org/godotsteam/godotsteam/releases/download/v4.24-gde/godotsteam-4.24-gdextension-plugin-4.4.zip";
const GODOTSTEAM_SHA256: &str = "d4358888959a03f4df0c71aafbcdca8f34b8cb9d4522aa5c8454f0e9e3debbf7";
/// 출시 대상 플랫폼 폴더만 받는다(Steam Deck = linux64).
const KEEP: [&str; 3] = ["win64/", "osx/", "linux64/"];
const PRESETS: [(&str, &str); 3] = [("Windows", "windows"), ("macOS", "macos"), ("Linux", "linux")];

fn godot() -> String {
    std::env::var("GODOT").unwrap_or_else(|_| "godot".into())
}

fn run(cmd: &mut Command) -> bool {
    println!("$ {:?}", cmd);
    cmd.status().map(|s| s.success()).unwrap_or(false)
}

fn fail(msg: &str) -> ! {
    eprintln!("{msg}");
    exit(1);
}

/// GodotSteam GDExtension을 받아 SHA-256을 확인하고, 출시 플랫폼 라이브러리만 addons/godotsteam에 푼다.
pub fn steam_addon(root: &Path) {
    use sha2::{Digest, Sha256};
    let dest = root.join("addons/godotsteam");
    if dest.join("godotsteam.gdextension").exists() {
        println!("addons/godotsteam이 이미 있습니다");
        return;
    }
    println!("받는 중: {GODOTSTEAM_URL}");
    let mut bytes = Vec::new();
    ureq::get(GODOTSTEAM_URL)
        .call()
        .unwrap_or_else(|e| fail(&format!("다운로드 실패: {e}")))
        .into_reader()
        .read_to_end(&mut bytes)
        .expect("다운로드 읽기");
    let hash = format!("{:x}", Sha256::digest(&bytes));
    if hash != GODOTSTEAM_SHA256 {
        fail(&format!("체크섬 불일치: {hash}"));
    }
    let mut zip = zip::ZipArchive::new(std::io::Cursor::new(bytes)).expect("zip 열기");
    for i in 0..zip.len() {
        let mut f = zip.by_index(i).unwrap();
        let Some(name) = f.enclosed_name() else { continue };
        let Ok(rel) = name.strip_prefix("addons/godotsteam") else { continue };
        let rel_s = rel.to_string_lossy().replace('\\', "/");
        let keep = KEEP.iter().any(|k| rel_s.starts_with(k)) || rel_s == "license.md";
        if f.is_dir() || !keep {
            continue;
        }
        let out = dest.join(rel);
        std::fs::create_dir_all(out.parent().unwrap()).unwrap();
        let mut w = std::fs::File::create(&out).unwrap();
        std::io::copy(&mut f, &mut w).unwrap();
    }
    // 받은 플랫폼만 가리키는 .gdextension(없는 라이브러리를 찾다 에러 나지 않게)
    std::fs::write(
        dest.join("godotsteam.gdextension"),
        r#"[configuration]
entry_symbol = "godotsteam_init"
compatibility_minimum = "4.4"

[libraries]
linux.debug.x86_64 = "res://addons/godotsteam/linux64/libgodotsteam.linux.template_debug.x86_64.so"
linux.release.x86_64 = "res://addons/godotsteam/linux64/libgodotsteam.linux.template_release.x86_64.so"
macos.debug = "res://addons/godotsteam/osx/libgodotsteam.macos.template_debug.universal.dylib"
macos.release = "res://addons/godotsteam/osx/libgodotsteam.macos.template_release.universal.dylib"
windows.debug.x86_64 = "res://addons/godotsteam/win64/libgodotsteam.windows.template_debug.x86_64.dll"
windows.release.x86_64 = "res://addons/godotsteam/win64/libgodotsteam.windows.template_release.x86_64.dll"

[dependencies]
linux.x86_64 = { "res://addons/godotsteam/linux64/libsteam_api.so": "" }
macos.universal = { "res://addons/godotsteam/osx/libsteam_api.dylib": "" }
windows.x86_64 = { "res://addons/godotsteam/win64/steam_api64.dll": "" }
"#,
    )
    .unwrap();
    println!("addons/godotsteam 준비 완료");
}

/// 헤드리스 자가검증 전체를 돌린다. 하나라도 실패하면 종료 코드 1.
pub fn test(root: &Path, long: bool, quick: bool) {
    let g = godot();
    let path = root.to_string_lossy().to_string();
    if !run(Command::new(&g).args(["--headless", "--path", &path, "--import"])) {
        // 첫 import는 번역 파일이 아직 없다는 경고로 실패 코드를 낼 수 있어 한 번 더 돌린다
        run(Command::new(&g).args(["--headless", "--path", &path, "--import"]));
    }
    let n = if long { "20" } else if quick { "1" } else { "3" };
    let tests: Vec<Vec<&str>> = vec![
        vec!["tests/test_dungeon.gd"],
        vec!["tests/test_i18n.gd"],
        vec!["tests/test_save.gd"],
        vec!["tests/test_achievement_icons.gd"],
        vec!["tests/test_flow.gd"],
        vec!["tests/test_gamepad.gd"],
        vec!["tests/test_autoplay.gd", "--", n],
        vec!["tests/test_balance.gd", "--", n],
    ];
    // --quick: 다른 OS 러너용(밸런스 측정은 Linux CI 한 곳에서만)
    let tests: Vec<Vec<&str>> = tests.into_iter().filter(|t| !(quick && t[0].ends_with("test_balance.gd"))).collect();
    let mut failed = vec![];
    for t in &tests {
        if !root.join(t[0]).exists() {
            continue;
        }
        let mut c = Command::new(&g);
        c.args(["--headless", "--fixed-fps", "60", "--path", &path, "-s"]).args(t);
        println!("$ {:?}", c);
        let out = c.output().unwrap_or_else(|e| fail(&format!("godot 실행 실패({g}): {e}")));
        let text = String::from_utf8_lossy(&out.stdout).to_string() + &String::from_utf8_lossy(&out.stderr);
        for line in text.lines().filter(|l| l.contains("self-test") || l.contains("FAIL") || l.contains("SCRIPT ERROR") || l.starts_with("run ") || l.starts_with("skill ") || l.starts_with("autoplay")) {
            println!("  {line}");
        }
        // 종료 코드뿐 아니라 스크립트 런타임 에러와 물리 콜백 중 상태 변경 에러도 실패로 본다
        if !out.status.success() || text.contains("SCRIPT ERROR") || text.contains("flushing queries") {
            failed.push(t[0].to_string());
        }
    }
    if !failed.is_empty() {
        fail(&format!("실패한 테스트: {failed:?}"));
    }
    println!("모든 테스트 통과");
}

/// 3플랫폼 내보내기. macOS .zip은 SteamPipe용으로 build/macos/content에 풀어 둔다.
pub fn build(root: &Path, only: Option<&str>) {
    let g = godot();
    let path = root.to_string_lossy().to_string();
    for (preset, dir) in PRESETS.into_iter().filter(|(_, d)| only.is_none_or(|o| o.split(',').any(|x| x == *d))) {
        let out_dir = root.join("build").join(dir);
        let _ = std::fs::remove_dir_all(&out_dir);
        std::fs::create_dir_all(&out_dir).unwrap();
        let file = match dir {
            "windows" => "HollowVigil.exe",
            "macos" => "HollowVigil.zip",
            _ => "HollowVigil.x86_64",
        };
        let out = out_dir.join(file);
        if !run(Command::new(&g).args(["--headless", "--path", &path, "--export-release", preset]).arg(&out)) || !out.exists() {
            fail(&format!("{preset} 내보내기 실패 (위 Godot 출력과 내보내기 템플릿 설치 여부를 확인하세요)"));
        }
        if dir == "macos" {
            let f = std::fs::File::open(&out).unwrap();
            zip::ZipArchive::new(f).unwrap().extract(out_dir.join("content")).expect("macOS zip 풀기");
        }
    }
    println!("build/ 아래 windows, macos, linux 산출물 완료");
}

/// SteamPipe VDF를 steam/out에 만든다. ID는 환경 변수로 받는다(저장소에 넣지 않음).
/// STEAM_APP_ID, STEAM_DEPOT_WINDOWS, STEAM_DEPOT_MACOS, STEAM_DEPOT_LINUX, (선택) STEAM_BRANCH
pub fn steam_vdf(root: &Path) -> PathBuf {
    let var = |k: &str| std::env::var(k).unwrap_or_else(|_| fail(&format!("환경 변수 {k}가 필요합니다 (steam/README.md 참고)")));
    let app = var("STEAM_APP_ID");
    let branch = std::env::var("STEAM_BRANCH").unwrap_or_default();
    let out = root.join("steam/out");
    std::fs::create_dir_all(&out).unwrap();
    let build = root.join("build");
    let depots = [("STEAM_DEPOT_WINDOWS", "windows"), ("STEAM_DEPOT_MACOS", "macos/content"), ("STEAM_DEPOT_LINUX", "linux")];
    let mut depot_lines = String::new();
    for (k, dir) in depots {
        let id = var(k);
        let content = build.join(dir);
        let vdf = out.join(format!("depot_{id}.vdf"));
        std::fs::write(
            &vdf,
            format!(
                "\"DepotBuild\"\n{{\n\t\"DepotID\" \"{id}\"\n\t\"ContentRoot\" \"{}\"\n\t\"FileMapping\"\n\t{{\n\t\t\"LocalPath\" \"*\"\n\t\t\"DepotPath\" \".\"\n\t\t\"Recursive\" \"1\"\n\t}}\n\t\"FileExclusion\" \"*.pdb\"\n}}\n",
                content.display()
            ),
        )
        .unwrap();
        depot_lines += &format!("\t\t\"{id}\" \"{}\"\n", vdf.display());
    }
    let app_vdf = out.join(format!("app_build_{app}.vdf"));
    std::fs::write(
        &app_vdf,
        format!(
            "\"AppBuild\"\n{{\n\t\"AppID\" \"{app}\"\n\t\"Desc\" \"Hollow Vigil build\"\n\t\"BuildOutput\" \"{}\"\n\t\"SetLive\" \"{branch}\"\n\t\"Depots\"\n\t{{\n{depot_lines}\t}}\n}}\n",
            out.join("logs").display()
        ),
    )
    .unwrap();
    println!("만듦: {}", app_vdf.display());
    app_vdf
}

/// steamcmd로 업로드한다. 계정은 STEAM_USER, 비밀번호·Steam Guard는 steamcmd가 직접 묻는다(저장하지 않음).
pub fn steam_upload(root: &Path) {
    let app_vdf = steam_vdf(root);
    let user = std::env::var("STEAM_USER").unwrap_or_else(|_| fail("환경 변수 STEAM_USER가 필요합니다"));
    let steamcmd = std::env::var("STEAMCMD").unwrap_or_else(|_| "steamcmd".into());
    if !run(Command::new(steamcmd).args(["+login", &user, "+run_app_build"]).arg(&app_vdf).arg("+quit")) {
        fail("steamcmd 업로드 실패");
    }
}
