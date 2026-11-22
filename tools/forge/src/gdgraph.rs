//! GDScript → graphify 추출. graphify가 GDScript를 코드로 인식하지 못해 게임 로직이
//! 그래프에서 빠지므로, .gd·.tscn·project.godot를 직접 읽어 graphify 추출 JSON(노드·엣지)을 만든다.
//!
//! - 노드: 파일, class_name, 함수, signal, 씬, project.godot
//! - 엣지(모두 코드에서 직접 확인된 것만, EXTRACTED): contains, inherits(extends),
//!   imports_from(preload/load), calls(같은 파일 함수, 또는 preload 별칭·autoload·class_name으로
//!   확정되는 다른 파일 함수), instantiates(별칭.new()), emits(signal.emit), references(콜백 연결),
//!   uses_script(씬 → 스크립트), autoloads(project.godot → 스크립트)
//! - 주석(#, ##)과 여러 줄 문자열(""")은 읽기 전에 지운다. 근거로 쓰지 않는다.

use std::collections::{BTreeMap, BTreeSet, HashMap};
use std::path::{Path, PathBuf};

pub struct Node {
    pub id: String,
    pub label: String,
    pub file: String,
    pub line: usize,
}

pub struct Edge {
    pub source: String,
    pub target: String,
    pub relation: &'static str,
    pub file: String,
    pub line: usize,
}

#[derive(Default)]
pub struct Graph {
    pub nodes: Vec<Node>,
    pub edges: Vec<Edge>,
}

/// graphify 노드 ID 규칙: 확장자를 뺀 저장소 상대 경로의 각 부분을 소문자·영숫자 외 '_'로 바꿔 '_'로 잇는다.
pub fn stem_id(rel: &str) -> String {
    let no_ext = rel.rsplit_once('.').map(|(a, _)| a).unwrap_or(rel);
    norm(&no_ext.replace(['/', '\\'], "_"))
}

fn norm(s: &str) -> String {
    s.to_lowercase().chars().map(|c| if c.is_alphanumeric() { c } else { '_' }).collect()
}

fn res_to_rel(res: &str) -> Option<String> {
    res.strip_prefix("res://").map(str::to_string)
}

/// 주석과 여러 줄 문자열을 지운 줄 목록(줄 번호는 그대로 유지).
pub fn strip_comments(text: &str) -> Vec<String> {
    let mut out = Vec::new();
    let mut in_triple = false;
    for line in text.lines() {
        let mut code = String::new();
        let chars: Vec<char> = line.chars().collect();
        let mut i = 0;
        let mut quote: Option<char> = None;
        while i < chars.len() {
            let c = chars[i];
            let triple = i + 2 < chars.len() && c == '"' && chars[i + 1] == '"' && chars[i + 2] == '"';
            if in_triple {
                if triple {
                    in_triple = false;
                    code.push_str("\"\"");
                    i += 3;
                } else {
                    code.push(' '); // 들여쓰기(소속 함수 판단)를 지키려고 공백으로 남긴다
                    i += 1;
                }
                continue;
            }
            match quote {
                Some(q) => {
                    code.push(c);
                    if c == '\\' && i + 1 < chars.len() {
                        code.push(chars[i + 1]);
                        i += 1;
                    } else if c == q {
                        quote = None;
                    }
                }
                None => {
                    if triple {
                        in_triple = true;
                        i += 3;
                        continue;
                    }
                    if c == '#' {
                        break;
                    }
                    if c == '"' || c == '\'' {
                        quote = Some(c);
                    }
                    code.push(c);
                }
            }
            i += 1;
        }
        out.push(code.trim_end().to_string());
    }
    out
}

/// 식별자 토큰: (앞에 '.'로 이어진 수신자, 이름, 바로 뒤가 '(' 인지)
fn call_sites(code: &str) -> Vec<(Option<String>, String)> {
    let b: Vec<char> = code.chars().collect();
    let mut out = vec![];
    let mut i = 0;
    let mut in_str: Option<char> = None;
    while i < b.len() {
        let c = b[i];
        if let Some(q) = in_str {
            if c == '\\' {
                i += 1;
            } else if c == q {
                in_str = None;
            }
            i += 1;
            continue;
        }
        if c == '"' || c == '\'' {
            in_str = Some(c);
            i += 1;
            continue;
        }
        if c.is_alphabetic() || c == '_' {
            let start = i;
            while i < b.len() && (b[i].is_alphanumeric() || b[i] == '_') {
                i += 1;
            }
            let name: String = b[start..i].iter().collect();
            let mut j = i;
            while j < b.len() && b[j] == ' ' {
                j += 1;
            }
            if j < b.len() && b[j] == '(' {
                // 바로 앞이 '.'이면 수신자 이름을 찾는다(a.b.c( 는 b를 수신자로)
                let mut k = start;
                let recv = if k > 0 && b[k - 1] == '.' {
                    k -= 1;
                    let end = k;
                    while k > 0 && (b[k - 1].is_alphanumeric() || b[k - 1] == '_') {
                        k -= 1;
                    }
                    Some(b[k..end].iter().collect::<String>()).filter(|s: &String| !s.is_empty())
                } else {
                    None
                };
                out.push((recv, name));
            }
            continue;
        }
        i += 1;
    }
    out
}

fn quoted_after(code: &str, key: &str) -> Vec<String> {
    let mut out = vec![];
    let mut rest = code;
    while let Some(i) = rest.find(key) {
        let after = &rest[i + key.len()..];
        if let Some(s) = after.strip_prefix('"') {
            if let Some(end) = s.find('"') {
                out.push(s[..end].to_string());
            }
        }
        rest = after;
    }
    out
}

/// 한 .gd 파일에서 선언(함수·signal·class_name·extends·별칭)을 모은다.
#[derive(Default)]
pub struct Decls {
    pub funcs: BTreeMap<String, usize>,
    pub signals: BTreeMap<String, usize>,
    pub class_name: Option<(String, usize)>,
    pub extends: Option<(String, usize)>,
    pub aliases: HashMap<String, String>, // const 이름 -> 대상 파일(저장소 상대)
}

pub fn declarations(lines: &[String]) -> Decls {
    let mut d = Decls::default();
    for (n, l) in lines.iter().enumerate() {
        let line = n + 1;
        let t = l.trim_start();
        let top = !l.starts_with(char::is_whitespace);
        if !top {
            continue;
        }
        let word = |p: &str| t.strip_prefix(p).map(|r| r.trim_start().split(|c: char| !(c.is_alphanumeric() || c == '_')).next().unwrap_or("").to_string());
        if let Some(rest) = t.strip_prefix("extends ") {
            d.extends = Some((rest.trim().trim_matches('"').to_string(), line));
        } else if let Some(name) = word("class_name ") {
            d.class_name = Some((name, line));
        } else if let Some(name) = word("signal ") {
            d.signals.insert(name, line);
        } else if let Some(name) = word("func ").or_else(|| word("static func ")) {
            if !name.is_empty() {
                d.funcs.insert(name, line);
            }
        } else if t.starts_with("const ") || t.starts_with("var ") {
            let name = t.split_whitespace().nth(1).unwrap_or("").trim_end_matches(':').to_string();
            for key in ["preload(", "load("] {
                if let Some(p) = quoted_after(t, key).into_iter().next().and_then(|p| res_to_rel(&p)) {
                    if p.ends_with(".gd") || p.ends_with(".tscn") {
                        d.aliases.insert(name.clone(), p);
                    }
                }
            }
        }
    }
    d
}

/// 저장소 전체 맥락: 파일별 선언, autoload 이름, class_name 이름 → 파일.
pub struct Context {
    pub decls: BTreeMap<String, Decls>,
    pub autoloads: HashMap<String, String>,
    pub classes: HashMap<String, String>,
}

impl Context {
    fn resolve(&self, file: &str, recv: &str) -> Option<String> {
        let d = self.decls.get(file)?;
        d.aliases.get(recv).or_else(|| self.autoloads.get(recv)).or_else(|| self.classes.get(recv)).cloned()
    }
}

pub fn parse_gd(rel: &str, lines: &[String], ctx: &Context, g: &mut Graph) {
    let fid = stem_id(rel);
    let d = &ctx.decls[rel];
    let fname = Path::new(rel).file_name().unwrap().to_string_lossy().to_string();
    g.nodes.push(Node { id: fid.clone(), label: fname, file: rel.into(), line: 1 });
    let edge = |g: &mut Graph, s: &str, t: &str, r: &'static str, line: usize| {
        g.edges.push(Edge { source: s.into(), target: t.into(), relation: r, file: rel.into(), line })
    };
    if let Some((c, line)) = &d.class_name {
        g.nodes.push(Node { id: format!("{fid}_{}", norm(c)), label: format!("class {c}"), file: rel.into(), line: *line });
        edge(g, &fid, &format!("{fid}_{}", norm(c)), "contains", *line);
    }
    for (f, line) in &d.funcs {
        g.nodes.push(Node { id: format!("{fid}_{}", norm(f)), label: format!("{f}()"), file: rel.into(), line: *line });
        edge(g, &fid, &format!("{fid}_{}", norm(f)), "contains", *line);
    }
    for (s, line) in &d.signals {
        let id = format!("{fid}_signal_{}", norm(s));
        g.nodes.push(Node { id: id.clone(), label: format!("signal {s}"), file: rel.into(), line: *line });
        edge(g, &fid, &id, "contains", *line);
    }
    if let Some((base, line)) = &d.extends {
        let target = res_to_rel(base).or_else(|| ctx.classes.get(base).cloned());
        if let Some(t) = target {
            edge(g, &fid, &stem_id(&t), "inherits", *line);
        }
    }
    // 본문: 현재 함수 추적(최상위 func 줄부터 다음 최상위 선언까지)
    let mut current: Option<String> = None;
    let mut seen = BTreeSet::new();
    for (n, code) in lines.iter().enumerate() {
        let line = n + 1;
        let top = !code.starts_with(char::is_whitespace) && !code.is_empty();
        let t = code.trim_start();
        if top {
            current = t
                .strip_prefix("func ")
                .or_else(|| t.strip_prefix("static func "))
                .map(|r| r.split(|c: char| !(c.is_alphanumeric() || c == '_')).next().unwrap_or("").to_string());
        }
        let from = current.as_ref().map(|f| format!("{fid}_{}", norm(f))).unwrap_or_else(|| fid.clone());
        for key in ["preload(", "load("] {
            for p in quoted_after(code, key) {
                if let Some(t) = res_to_rel(&p).filter(|t| t.ends_with(".gd") || t.ends_with(".tscn")) {
                    if seen.insert((fid.clone(), stem_id(&t), "imports_from")) {
                        edge(g, &fid, &stem_id(&t), "imports_from", line);
                    }
                }
            }
        }
        if current.is_none() || top {
            continue; // 최상위 선언 줄(함수 머리 포함)의 괄호는 호출이 아니다
        }
        for (recv, name) in call_sites(code) {
            let local = |n: &str| d.funcs.contains_key(n).then(|| format!("{fid}_{}", norm(n)));
            let (rel_kind, target) = match recv.as_deref() {
                None | Some("self") => match local(&name) {
                    Some(t) => ("calls", Some(t)),
                    None => ("", None),
                },
                Some(r) if name == "emit" && d.signals.contains_key(r) => ("emits", Some(format!("{fid}_signal_{}", norm(r)))),
                Some(r) => match ctx.resolve(rel, r) {
                    Some(tf) if name == "new" || name == "instantiate" => ("instantiates", Some(stem_id(&tf))),
                    Some(tf) => match ctx.decls.get(&tf).filter(|td| td.funcs.contains_key(&name)) {
                        Some(_) => ("calls", Some(format!("{}_{}", stem_id(&tf), norm(&name)))),
                        None => ("", None),
                    },
                    None => ("", None),
                },
            };
            if let Some(t) = target {
                if seen.insert((from.clone(), t.clone(), rel_kind)) {
                    edge(g, &from, &t, rel_kind, line);
                }
            }
        }
        // 콜백 연결: something.connect(_handler) 의 _handler가 이 파일 함수면 references
        if let Some(i) = code.find(".connect(") {
            let arg: String = code[i + 9..].chars().take_while(|c| c.is_alphanumeric() || *c == '_').collect();
            if d.funcs.contains_key(&arg) {
                let t = format!("{fid}_{}", norm(&arg));
                if seen.insert((from.clone(), t.clone(), "references")) {
                    edge(g, &from, &t, "references", line);
                }
            }
        }
    }
}

fn walk(dir: &Path, root: &Path, out: &mut Vec<String>) {
    let Ok(rd) = std::fs::read_dir(dir) else { return };
    for e in rd.flatten() {
        let p = e.path();
        let name = e.file_name().to_string_lossy().to_string();
        if name.starts_with('.') || ["addons", "build", "target", "graphify-out"].contains(&name.as_str()) {
            continue;
        }
        if p.is_dir() {
            walk(&p, root, out);
        } else if name.ends_with(".gd") || name.ends_with(".tscn") || name == "project.godot" {
            out.push(p.strip_prefix(root).unwrap().to_string_lossy().replace('\\', "/"));
        }
    }
}

pub fn extract(root: &Path) -> Graph {
    let mut files = vec![];
    walk(root, root, &mut files);
    files.sort();
    let read = |rel: &str| strip_comments(&std::fs::read_to_string(root.join(rel)).unwrap_or_default());
    let mut ctx = Context { decls: BTreeMap::new(), autoloads: HashMap::new(), classes: HashMap::new() };
    let mut g = Graph::default();
    // project.godot: autoload 이름 → 스크립트, 시작 씬
    if files.iter().any(|f| f == "project.godot") {
        let pid = "project".to_string();
        g.nodes.push(Node { id: pid.clone(), label: "project.godot".into(), file: "project.godot".into(), line: 1 });
        let mut section = String::new();
        for (n, l) in std::fs::read_to_string(root.join("project.godot")).unwrap_or_default().lines().enumerate() {
            let l = l.trim();
            if l.starts_with('[') {
                section = l.to_string();
            } else if section == "[autoload]" {
                if let Some((name, path)) = l.split_once('=') {
                    if let Some(t) = res_to_rel(path.trim_matches('"').trim_start_matches('*')) {
                        ctx.autoloads.insert(name.to_string(), t.clone());
                        g.edges.push(Edge { source: pid.clone(), target: stem_id(&t), relation: "autoloads", file: "project.godot".into(), line: n + 1 });
                    }
                }
            } else if let Some(p) = l.strip_prefix("run/main_scene=") {
                if let Some(t) = res_to_rel(p.trim_matches('"')) {
                    g.edges.push(Edge { source: pid.clone(), target: stem_id(&t), relation: "references", file: "project.godot".into(), line: n + 1 });
                }
            }
        }
    }
    let gd: Vec<&String> = files.iter().filter(|f| f.ends_with(".gd")).collect();
    let mut texts = HashMap::new();
    for f in &gd {
        let lines = read(f);
        let d = declarations(&lines);
        if let Some((c, _)) = &d.class_name {
            ctx.classes.insert(c.clone(), (*f).clone());
        }
        ctx.decls.insert((*f).clone(), d);
        texts.insert((*f).clone(), lines);
    }
    for f in &gd {
        parse_gd(f, &texts[*f], &ctx, &mut g);
    }
    // 씬: 스크립트·하위 씬 참조
    for f in files.iter().filter(|f| f.ends_with(".tscn")) {
        let sid = stem_id(f);
        g.nodes.push(Node { id: sid.clone(), label: Path::new(f).file_name().unwrap().to_string_lossy().into(), file: f.clone(), line: 1 });
        for (n, l) in std::fs::read_to_string(root.join(f)).unwrap_or_default().lines().enumerate() {
            if l.starts_with("[ext_resource") {
                if let Some(t) = quoted_after(l, "path=").into_iter().next().and_then(|p| res_to_rel(&p)) {
                    let rel = if t.ends_with(".gd") { "uses_script" } else { "references" };
                    g.edges.push(Edge { source: sid.clone(), target: stem_id(&t), relation: rel, file: f.clone(), line: n + 1 });
                }
            }
        }
    }
    // 그래프에 없는 대상(엔진 클래스 등)을 가리키는 엣지는 버린다
    let ids: BTreeSet<String> = g.nodes.iter().map(|n| n.id.clone()).collect();
    g.edges.retain(|e| ids.contains(&e.target) && ids.contains(&e.source));
    g
}

fn esc(s: &str) -> String {
    let mut o = String::with_capacity(s.len());
    for c in s.chars() {
        match c {
            '"' => o.push_str("\\\""),
            '\\' => o.push_str("\\\\"),
            '\n' => o.push_str("\\n"),
            c if (c as u32) < 0x20 => o.push_str(&format!("\\u{:04x}", c as u32)),
            c => o.push(c),
        }
    }
    o
}

/// graphify 추출 JSON(nodes/edges)으로 쓴다.
pub fn to_json(g: &Graph) -> String {
    let nodes: Vec<String> = g
        .nodes
        .iter()
        .map(|n| {
            format!(
                "{{\"id\":\"{}\",\"label\":\"{}\",\"file_type\":\"code\",\"source_file\":\"{}\",\"source_location\":\"L{}\",\"_origin\":\"ast\"}}",
                esc(&n.id), esc(&n.label), esc(&n.file), n.line
            )
        })
        .collect();
    let edges: Vec<String> = g
        .edges
        .iter()
        .map(|e| {
            format!(
                "{{\"source\":\"{}\",\"target\":\"{}\",\"relation\":\"{}\",\"confidence\":\"EXTRACTED\",\"confidence_score\":1.0,\"source_file\":\"{}\",\"source_location\":\"L{}\",\"weight\":1.0,\"_origin\":\"ast\"}}",
                esc(&e.source), esc(&e.target), e.relation, esc(&e.file), e.line
            )
        })
        .collect();
    format!("{{\"nodes\":[{}],\"edges\":[{}],\"hyperedges\":[],\"input_tokens\":0,\"output_tokens\":0}}", nodes.join(","), edges.join(","))
}

pub fn write(root: &Path) -> PathBuf {
    let g = extract(root);
    let out = root.join("graphify-out/.graphify_gd.json");
    std::fs::create_dir_all(out.parent().unwrap()).unwrap();
    std::fs::write(&out, to_json(&g)).unwrap();
    println!("GDScript: 노드 {}개, 엣지 {}개 → {}", g.nodes.len(), g.edges.len(), out.display());
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    const ENEMY: &str = r#"extends "res://scripts/base.gd"
## 문서 주석: func not_a_func(): 는 무시돼야 한다
class_name Enemy

signal died(who)

const Bullet = preload("res://scripts/bullet.gd")
var hp := 3  # 주석 속 Sfx.play() 도 무시


func hit(dmg: int) -> void:
	hp -= dmg
	Sfx.play("hit")
	if hp <= 0:
		die()


func die() -> void:
	died.emit(self)
	var b = Bullet.new()
	b.setup(1)
	"""
	여러 줄 문자열 속 die() 는 무시
	"""
	game.died.connect(_on_dead)


func _on_dead() -> void:
	pass
"#;

    fn ctx_with(files: &[(&str, &str)]) -> (Context, HashMap<String, Vec<String>>) {
        let mut ctx = Context { decls: BTreeMap::new(), autoloads: HashMap::new(), classes: HashMap::new() };
        ctx.autoloads.insert("Sfx".into(), "scripts/audio.gd".into());
        let mut texts = HashMap::new();
        for (f, t) in files {
            let lines = strip_comments(t);
            ctx.decls.insert((*f).into(), declarations(&lines));
            texts.insert((*f).into(), lines);
        }
        (ctx, texts)
    }

    #[test]
    fn parses_gdscript_without_comments() {
        let (ctx, texts) = ctx_with(&[
            ("scripts/enemy.gd", ENEMY),
            ("scripts/audio.gd", "extends Node\n\nfunc play(name: String) -> void:\n\tpass\n"),
            ("scripts/bullet.gd", "extends Area2D\n\nfunc setup(x) -> void:\n\tpass\n"),
            ("scripts/base.gd", "extends Node\n"),
        ]);
        let mut g = Graph::default();
        for f in ["scripts/enemy.gd", "scripts/audio.gd", "scripts/bullet.gd", "scripts/base.gd"] {
            parse_gd(f, &texts[f], &ctx, &mut g);
        }
        let ids: BTreeSet<&str> = g.nodes.iter().map(|n| n.id.as_str()).collect();
        for want in ["scripts_enemy", "scripts_enemy_enemy", "scripts_enemy_hit", "scripts_enemy_die", "scripts_enemy__on_dead", "scripts_enemy_signal_died"] {
            assert!(ids.contains(want), "missing node {want}: {ids:?}");
        }
        assert!(!ids.iter().any(|i| i.contains("not_a_func")), "comment leaked into nodes");
        let has = |s: &str, t: &str, r: &str| g.edges.iter().any(|e| e.source == s && e.target == t && e.relation == r);
        assert!(has("scripts_enemy", "scripts_base", "inherits"));
        assert!(has("scripts_enemy", "scripts_bullet", "imports_from"));
        assert!(has("scripts_enemy_hit", "scripts_enemy_die", "calls"));
        assert!(has("scripts_enemy_hit", "scripts_audio_play", "calls"), "autoload call");
        assert!(has("scripts_enemy_die", "scripts_enemy_signal_died", "emits"));
        assert!(has("scripts_enemy_die", "scripts_bullet", "instantiates"));
        assert!(has("scripts_enemy_die", "scripts_enemy__on_dead", "references"));
        // 동적 수신자(b.setup)는 타입을 확정할 수 없으므로 엣지를 만들지 않는다
        assert!(!has("scripts_enemy_die", "scripts_bullet_setup", "calls"));
        // 여러 줄 문자열 속 die()는 호출로 세지 않는다: die → die 재귀 엣지가 없어야 한다
        assert!(!has("scripts_enemy_die", "scripts_enemy_die", "calls"));
        let json = to_json(&g);
        assert!(json.starts_with("{\"nodes\":[") && json.contains("\"file_type\":\"code\""));
    }
}

/// graphify 파이프라인(감지 → 코드 AST → GDScript 병합 → 문서 의미 추출 캐시 → 빌드·클러스터 →
/// rationale 제거 → 보고서·Obsidian·HTML 내보내기)을 한 번에 돌린다.
/// 문서의 의미 추출은 LLM이 필요해 여기서 새로 하지 않고, `/graphify`로 만든 캐시만 합친다.
const PIPELINE: &str = r#"
import json, subprocess, sys, collections
from pathlib import Path
from graphify.detect import detect, save_manifest
from graphify.extract import collect_files, extract
from graphify.cache import check_semantic_cache
from graphify.build import build_from_json
from graphify.cluster import cluster, score_all
from graphify.analyze import god_nodes, surprising_connections, suggest_questions
from graphify.report import generate
from graphify.export import to_json
from graphify.paths import out_path
from graphify.watch import _read_build_excludes, _read_build_gitignore
from graphify.cli import _stamped_manifest_files

root = Path(sys.argv[1]); spec = sys.argv[2]
det = detect(root, extra_excludes=_read_build_excludes(out_path()), gitignore=_read_build_gitignore(out_path()))
code = []
for f in det['files'].get('code', []):
    code.extend(collect_files(Path(f)) if Path(f).is_dir() else [Path(f)])
ast = extract(code, cache_root=root, root=root) if code else {'nodes': [], 'edges': []}
gd = json.loads(Path('graphify-out/.graphify_gd.json').read_text(encoding='utf-8'))
docs = [f for cat in ('document', 'paper', 'image') for f in det['files'].get(cat, [])]
sem_nodes, sem_edges, hyper, uncached = ([], [], [], docs)
if Path(spec).exists():
    sem_nodes, sem_edges, hyper, uncached = check_semantic_cache(docs, root=str(root), prompt_file=spec)
if uncached:
    print('주의: 의미 추출 캐시가 없는 문서 %d개는 빠졌습니다(/graphify . --update로 추출): %s' % (len(uncached), ', '.join(Path(u).name for u in uncached)))
# 의미 추출 결과는 출처를 표시해 둔다(source_location이 'L12' 꼴이어도 AST로 오인되지 않게)
for x in sem_nodes + sem_edges:
    x.setdefault('_origin', 'semantic')
nodes, seen = [], set()
for n in ast['nodes'] + gd['nodes'] + sem_nodes:
    if n['id'] not in seen:
        seen.add(n['id']); nodes.append(n)
edges = ast['edges'] + gd['edges'] + sem_edges
# 전역 규칙: 주석·docstring에서 나온 rationale 노드와 rationale_for 엣지는 내보내기 전에 지운다
rat = {n['id'] for n in nodes if n.get('file_type') == 'rationale'}
nodes = [n for n in nodes if n['id'] not in rat]
edges = [e for e in edges if e.get('relation') != 'rationale_for' and e['source'] not in rat and e['target'] not in rat]
hyper = [h for h in hyper if not set(h['nodes']) & rat]
ext = {'nodes': nodes, 'edges': edges, 'hyperedges': hyper, 'input_tokens': 0, 'output_tokens': 0}
G = build_from_json(ext, root=str(root), directed=False)
comm = cluster(G); coh = score_all(G, comm)
# 커뮤니티 이름: 구성원이 가장 많이 속한 파일 이름(LLM 없이 결정적으로)
labels = {}
for cid, members in comm.items():
    files = collections.Counter(Path(G.nodes[m].get('source_file') or '?').name for m in members)
    labels[cid] = ' / '.join(f for f, _ in files.most_common(2))
gods = god_nodes(G); sur = surprising_connections(G, comm)
qs = suggest_questions(G, comm, labels)
to_json(G, comm, 'graphify-out/graph.json', force=True, community_labels=labels)
Path('graphify-out/GRAPH_REPORT.md').write_text(generate(G, comm, coh, labels, gods, sur, det, {'input': 0, 'output': 0}, str(root), suggested_questions=qs), encoding='utf-8')
Path('graphify-out/.graphify_labels.json').write_text(json.dumps({str(k): v for k, v in labels.items()}, ensure_ascii=False), encoding='utf-8')
corpus = det.get('all_files') or det['files']
save_manifest(_stamped_manifest_files(corpus, ext, root, partial_source_files=set()), root=str(root), scan_corpus={f for fl in corpus.values() for f in fl}, clear_semantic=None)
gd_ids = {n['id'] for n in gd['nodes']}
print('그래프: 노드 %d, 엣지 %d, 커뮤니티 %d (GDScript 노드 %d, 엣지 %d, rationale 제거 %d)' % (
    G.number_of_nodes(), G.number_of_edges(), len(comm), len(gd_ids), len(gd['edges']), len(rat)))
for cmd in (['graphify', 'export', 'obsidian'], ['graphify', 'export', 'html']):
    subprocess.run(cmd, check=True)
"#;

pub fn run(root: &Path) {
    write(root);
    let py_file = root.join("graphify-out/.graphify_python");
    let python = std::fs::read_to_string(&py_file).map(|s| s.trim().to_string()).unwrap_or_else(|_| "python3".into());
    let spec = std::env::var("GRAPHIFY_SPEC").unwrap_or_else(|_| {
        format!("{}/.claude/skills/graphify/references/extraction-spec.md", std::env::var("HOME").unwrap_or_default())
    });
    let ok = std::process::Command::new(&python)
        .current_dir(root)
        .args(["-c", PIPELINE])
        .arg(root)
        .arg(&spec)
        .status()
        .map(|s| s.success())
        .unwrap_or(false);
    if !ok {
        eprintln!("graphify 파이프라인 실패 ({python}에 graphify가 설치되어 있는지 확인: pip install graphifyy)");
        std::process::exit(1);
    }
}
