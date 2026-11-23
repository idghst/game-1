//! 45초 트레일러: tools/trailer.gd로 장면별 클립을 Movie Maker(480x270, 60fps)로 찍고,
//! ffmpeg로 컷·자막·페이드·배경음을 붙여 1920x1080(4배 nearest) H.264/AAC로 내보낸다.
//! 클립은 build/trailer/<언어>/<클립>/에 남고, cues.txt가 있으면 다시 찍지 않는다(tools/trailer.gd를 고쳤으면 --fresh).

use std::collections::HashMap;
use std::path::Path;
use std::process::{exit, Command};

const LANGS: [&str; 2] = ["ko", "en"];
const TOTAL: f64 = 45.0;

/// 장면: (스틸 이름, 자막 ko, 자막 en, 컷 목록). 컷 = (클립, 기준 큐, 큐부터 시작 초, 길이 초)
type Cut = (&'static str, &'static str, f64, f64);
const SCENES: [(&str, &str, &str, &[Cut]); 7] = [
    ("01_title", "불침번은 끝나지 않았다", "The vigil never ends", &[("title", "", 0.5, 4.0)]),
    ("02_descend", "쏘고, 피하고, 내려가라", "Shoot. Dodge. Descend.", &[("f1", "", 0.4, 4.0), ("f3", "", 0.6, 4.0)]),
    ("03_blessing", "22가지 축복으로 매번 다른 빌드", "22 blessings, a new build each run", &[("bless", "menu", -1.4, 3.9), ("bless", "fight", 0.2, 2.1)]),
    ("04_deeper", "깊어질수록 거세지는 어둠", "The deeper, the darker", &[("shop", "", 0.3, 2.7), ("elite", "", 0.6, 3.0), ("treasure", "", 0.0, 2.3)]),
    ("05_wardens", "세 층마다 기다리는 문지기", "A warden waits every third floor", &[("boss3", "", 1.0, 3.4), ("boss6", "", 1.0, 3.3), ("boss9", "", 1.0, 3.3)]),
    ("06_embers", "쓰러져도 잿불은 남는다", "Fall, and the embers remain", &[("death", "death", -0.6, 2.6), ("altar", "", 0.4, 2.4)]),
    ("07_logo", "Hollow Vigil · 출시 예정", "Hollow Vigil · Coming soon", &[("logo", "", 0.3, 4.0)]),
];
const FADE: f64 = 0.25;

fn run(cmd: &mut Command) -> bool {
    cmd.status().map(|s| s.success()).unwrap_or(false)
}

fn fail(msg: &str) -> ! {
    eprintln!("{msg}");
    exit(1);
}

fn cues(dir: &Path) -> HashMap<String, f64> {
    let text = std::fs::read_to_string(dir.join("cues.txt")).unwrap_or_default();
    text.lines().filter_map(|l| l.split_once(' ')).map(|(k, v)| (k.to_string(), v.parse().unwrap())).collect()
}

pub fn run_all(root: &Path, fresh: bool) {
    let godot = std::env::var("GODOT").unwrap_or_else(|_| "godot".into());
    let work = root.join("build/trailer");
    if fresh {
        let _ = std::fs::remove_dir_all(&work);
    }
    let out = root.join("store/trailer");
    let total: f64 = SCENES.iter().flat_map(|s| s.3.iter()).map(|c| c.3).sum();
    assert!((total - TOTAL).abs() < 1e-6, "컷 길이 합이 {TOTAL}초가 아님: {total}");
    for (li, lang) in LANGS.iter().enumerate() {
        // 1) 촬영
        let mut clips: Vec<&str> = SCENES.iter().flat_map(|s| s.3.iter().map(|c| c.0)).collect();
        clips.dedup();
        for clip in &clips {
            let dir = work.join(lang).join(clip);
            if dir.join("cues.txt").exists() {
                continue;
            }
            println!("촬영: {lang}/{clip}");
            let _ = std::fs::remove_dir_all(&dir);
            std::fs::create_dir_all(&dir).unwrap();
            let ok = run(Command::new(&godot).arg("--path").arg(root).arg("--write-movie").arg(dir.join("f.png"))
                .args(["-s", "tools/trailer.gd", "--"]).arg(&dir).args([lang, clip]));
            if !ok || !dir.join("cues.txt").exists() {
                fail(&format!("촬영 실패: {lang}/{clip}"));
            }
        }
        // 2) 자막(게임 폰트로 그린 투명 PNG)
        let caps = work.join(lang).join("captions");
        std::fs::create_dir_all(&caps).unwrap();
        let texts: Vec<&str> = SCENES.iter().map(|s| if li == 0 { s.1 } else { s.2 }).collect();
        let o = Command::new(&godot).arg("--path").arg(root).args(["-s", "tools/trailer.gd", "--"]).arg(&caps)
            .arg(lang).arg("captions").args(&texts).output().unwrap_or_else(|e| fail(&format!("godot 실행: {e}")));
        let log = String::from_utf8_lossy(&o.stdout);
        log.lines().filter(|l| l.starts_with("caption")).for_each(|l| println!("{l}"));
        if log.contains("OVERFLOW") || log.matches("caption ").count() != texts.len() {
            fail("자막이 넘치거나 만들어지지 않았습니다");
        }
        // 3) 편집
        let file = out.join(format!("HollowVigil-trailer-{lang}.mp4"));
        edit(root, &work.join(lang), &caps, &file);
        // 4) 확인: 길이·해상도·코덱, 장면별 스틸
        check(&file);
        let stills = out.join("stills").join(lang);
        std::fs::create_dir_all(&stills).unwrap();
        let mut t = 0.0;
        for s in &SCENES {
            let d: f64 = s.3.iter().map(|c| c.3).sum();
            let ok = run(Command::new("ffmpeg").args(["-loglevel", "error", "-y", "-ss", &format!("{:.2}", t + d * 0.55), "-i"]).arg(&file)
                .args(["-frames:v", "1"]).arg(stills.join(format!("{}.png", s.0))));
            if !ok {
                fail("스틸 추출 실패");
            }
            t += d;
        }
    }
}

fn edit(root: &Path, clips: &Path, caps: &Path, file: &Path) {
    let mut args: Vec<String> = vec!["-loglevel".into(), "error".into(), "-y".into()];
    let mut graph = String::new();
    let mut n = 0; // 입력 번호
    let (mut vs, mut as_) = (String::new(), String::new());
    let mut t = 0.0;
    let mut cap_at = vec![];
    for (si, s) in SCENES.iter().enumerate() {
        cap_at.push((t, t + s.3.iter().map(|c| c.3).sum::<f64>()));
        for (ci, &(clip, cue, off, dur)) in s.3.iter().enumerate() {
            let dir = clips.join(clip);
            let c = cues(&dir);
            let start = c.get(cue).copied().unwrap_or(0.0) + off;
            if start < 0.0 || start + dur > c["end"] - 0.05 {
                fail(&format!("{clip}: 컷 {start:.2}~{:.2}초가 클립({:.2}초) 밖입니다", start + dur, c["end"]));
            }
            // 장면 첫 컷은 페이드 인, 마지막 컷은 페이드 아웃(맨 처음과 끝은 길게)
            let fi = if ci == 0 { if si == 0 { 0.8 } else { FADE } } else { 0.0 };
            let fo = if ci == s.3.len() - 1 { if si == SCENES.len() - 1 { 1.2 } else { FADE } } else { 0.0 };
            let fades = |a: &str| {
                let mut f = String::new();
                if fi > 0.0 { f += &format!(",{a}fade=t=in:st=0:d={fi}"); }
                if fo > 0.0 { f += &format!(",{a}fade=t=out:st={:.3}:d={fo}", dur - fo); }
                f
            };
            args.extend(["-framerate", "60", "-i"].map(String::from));
            args.push(dir.join("f%08d.png").to_string_lossy().into());
            args.push("-i".into());
            args.push(dir.join("f.wav").to_string_lossy().into());
            graph += &format!("[{n}:v]trim=start={start:.3}:duration={dur},setpts=PTS-STARTPTS,format=rgb24{}[v{n}];", fades(""));
            graph += &format!("[{}:a]atrim=start={start:.3}:duration={dur},asetpts=PTS-STARTPTS,aresample=48000,aformat=channel_layouts=stereo,apad=whole_dur={dur}{}[a{n}];", n + 1, fades("a"));
            vs += &format!("[v{n}]");
            as_ += &format!("[a{n}]");
            n += 2;
            t += dur;
        }
    }
    let segs = n / 2;
    graph += &format!("{vs}concat=n={segs}:v=1:a=0[base];{as_}concat=n={segs}:v=0:a=1[sfx];");
    // 자막: 480x64 PNG를 바닥 근처에 올리고 장면 안에서 페이드
    let mut last = "base".to_string();
    for (i, (a, b)) in cap_at.iter().enumerate() {
        let (a, b) = (a + 0.3, b - 0.3);
        args.extend(["-loop", "1", "-framerate", "60", "-t", "45", "-i"].map(String::from));
        args.push(caps.join(format!("cap{i}.png")).to_string_lossy().into());
        graph += &format!("[{n}:v]format=rgba,fade=t=in:st={a:.2}:d={FADE}:alpha=1,fade=t=out:st={:.2}:d={FADE}:alpha=1[c{i}];", b - FADE);
        graph += &format!("[{last}][c{i}]overlay=x=0:y=198:enable='between(t,{a:.2},{b:.2})'[o{i}];");
        last = format!("o{i}");
        n += 1;
    }
    graph += &format!("[{last}]scale=1920:1080:flags=neighbor,format=yuv420p[vout];");
    // 배경음: 보스전 음악을 반복해 깔고, 실제 효과음을 그 위에 섞는다
    args.extend(["-stream_loop", "-1", "-i"].map(String::from));
    args.push(root.join("assets/audio/music_boss.wav").to_string_lossy().into());
    graph += &format!("[{n}:a]atrim=duration={TOTAL},aresample=48000,aformat=channel_layouts=stereo,volume=0.55,afade=t=in:d=1,afade=t=out:st={}:d=2[mus];", TOTAL - 2.0);
    graph += "[sfx][mus]amix=inputs=2:normalize=0,alimiter=limit=0.9[aout]";
    args.extend(["-filter_complex".into(), graph]);
    args.extend(["-map", "[vout]", "-map", "[aout]", "-r", "60", "-c:v", "libx264", "-preset", "slow", "-crf", "10", "-profile:v", "high",
        "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", "-t", "45"].map(String::from));
    args.push(file.to_string_lossy().into());
    std::fs::create_dir_all(file.parent().unwrap()).unwrap();
    println!("편집: {}", file.display());
    if !run(Command::new("ffmpeg").args(&args)) {
        fail("ffmpeg 편집 실패");
    }
}

fn check(file: &Path) {
    let o = Command::new("ffprobe").args(["-v", "error", "-show_entries", "format=duration,size:stream=codec_name,width,height", "-of", "default=nw=1"])
        .arg(file).output().unwrap_or_else(|e| fail(&format!("ffprobe 실행: {e}")));
    let info = String::from_utf8_lossy(&o.stdout);
    let get = |k: &str| info.lines().find_map(|l| l.strip_prefix(&format!("{k}="))).unwrap_or("").to_string();
    let dur: f64 = get("duration").parse().unwrap_or(0.0);
    let ok = (44.0..=46.0).contains(&dur) && get("width") == "1920" && get("height") == "1080"
        && info.contains("codec_name=h264") && info.contains("codec_name=aac");
    println!("{}: {dur:.2}초, {}x{}, {:.1}MB, h264+aac {}", file.display(), get("width"), get("height"),
        get("size").parse::<f64>().unwrap_or(0.0) / 1e6, if ok { "OK" } else { "FAIL" });
    if !ok {
        fail("트레일러 규격 확인 실패");
    }
}
