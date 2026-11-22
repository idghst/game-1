//! Steam 스토어 캡슐 이미지: 픽셀아트 키 아트(assets/sprites/title.png, 480x270)를
//! 정수 배율 nearest로 키워 규격 크기로 자르고, 로고 SVG(1px 사각형으로 된 픽셀 워드마크)를 얹는다.

use image::{imageops, Rgba, RgbaImage};
use std::path::Path;

/// (파일 이름, 가로, 세로, 확대 배율, 키 아트에서 가운데로 볼 x 비율, 로고 배율(0이면 로고 없음), 배경 투명 여부)
const CAPSULES: &[(&str, u32, u32, u32, f32, u32, bool)] = &[
    ("header_capsule_920x430", 920, 430, 2, 0.5, 10, false),
    ("small_capsule_462x174", 462, 174, 2, 0.5, 6, false),
    ("main_capsule_1232x706", 1232, 706, 4, 0.5, 14, false),
    ("vertical_capsule_748x896", 748, 896, 4, 0.42, 9, false),
    ("library_capsule_600x900", 600, 900, 4, 0.42, 7, false),
    ("library_hero_3840x1240", 3840, 1240, 8, 0.5, 0, false), // Steam 규정: 히어로에는 로고·글자 없음
    ("library_logo_1280x720", 1280, 720, 1, 0.5, 16, true),
    ("page_background_1438x810", 1438, 810, 3, 0.5, 0, false),
    ("community_icon_184x184", 184, 184, 0, 0.5, 0, false),
];

/// 로고 SVG의 <rect>들을 (x, y, 색)으로 읽는다. 그룹 fill도 따른다.
fn logo_pixels(svg: &str) -> (Vec<(i32, i32, Rgba<u8>)>, i32, i32) {
    let attr = |tag: &str, k: &str| -> Option<String> {
        let pat = format!(" {k}=\"");
        let i = tag.find(&pat)? + pat.len();
        Some(tag[i..].split('"').next()?.to_string())
    };
    let hex = |s: &str| -> Rgba<u8> {
        let v = u32::from_str_radix(s.trim_start_matches('#'), 16).unwrap_or(0);
        Rgba([(v >> 16) as u8, (v >> 8) as u8, v as u8, 255])
    };
    let mut group_fill: Option<String> = None;
    let mut px = vec![];
    for raw in svg.split('<').skip(1) {
        let tag = raw.split('>').next().unwrap_or("");
        if tag.starts_with("g ") {
            group_fill = attr(tag, "fill");
        } else if tag.starts_with("/g") {
            group_fill = None;
        } else if tag.starts_with("rect ") {
            let (Some(x), Some(y)) = (attr(tag, "x"), attr(tag, "y")) else { continue };
            let Some(fill) = attr(tag, "fill").or_else(|| group_fill.clone()) else { continue };
            if attr(tag, "width").as_deref() != Some("1") {
                continue; // 배경 사각형 등은 건너뜀
            }
            px.push((x.parse::<f32>().unwrap() as i32, y.parse::<f32>().unwrap() as i32, hex(&fill)));
        }
    }
    let w = px.iter().map(|p| p.0).max().unwrap_or(0) + 1;
    let h = px.iter().map(|p| p.1).max().unwrap_or(0) + 1;
    (px, w, h)
}

fn draw_logo(img: &mut RgbaImage, px: &[(i32, i32, Rgba<u8>)], lw: i32, lh: i32, scale: u32, cy: i32) {
    let s = scale as i32;
    let (ox, oy) = ((img.width() as i32 - lw * s) / 2, cy - lh * s / 2);
    for &(x, y, c) in px {
        for dy in 0..s {
            for dx in 0..s {
                let (px_x, px_y) = (ox + x * s + dx, oy + y * s + dy);
                if px_x >= 0 && px_y >= 0 && (px_x as u32) < img.width() && (px_y as u32) < img.height() {
                    img.put_pixel(px_x as u32, px_y as u32, c);
                }
            }
        }
    }
}

pub fn run(root: &Path) {
    let art = image::open(root.join("assets/sprites/title.png")).expect("assets/sprites/title.png (forge pixel 먼저)").to_rgba8();
    let icon_svg = std::fs::read_to_string(root.join("assets/logo/icon.svg")).expect("icon.svg");
    let logo_svg = std::fs::read_to_string(root.join("assets/logo/logo.svg")).expect("logo.svg");
    let (logo, lw, lh) = logo_pixels(&logo_svg);
    let out = root.join("store/capsules");
    std::fs::create_dir_all(&out).unwrap();
    for &(name, w, h, k, focus, logo_scale, transparent) in CAPSULES {
        let mut img = if name.starts_with("community_icon") {
            // 커뮤니티 아이콘: 등불 아이콘을 꽉 차게
            let (ipx, iw, ih) = logo_pixels(&icon_svg);
            let mut i = RgbaImage::from_pixel(w, h, Rgba([0x17, 0x14, 0x1d, 255]));
            let s = (h as i32 - 16) / ih.max(iw);
            draw_logo(&mut i, &ipx, iw, ih, s as u32, h as i32 / 2);
            i
        } else if transparent {
            RgbaImage::new(w, h)
        } else {
            // 키 아트에서 (w/k)x(h/k) 영역을 잘라 정수 배율로 키운다
            let (cw, ch) = (w.div_ceil(k).min(art.width()), h.div_ceil(k).min(art.height()));
            let cx = ((art.width() as f32 * focus) as i32 - cw as i32 / 2).clamp(0, (art.width() - cw) as i32) as u32;
            let cy = (art.height() - ch) / 2;
            let crop = imageops::crop_imm(&art, cx, cy, cw, ch).to_image();
            let big = imageops::resize(&crop, cw * k, ch * k, imageops::FilterType::Nearest);
            imageops::crop_imm(&big, (cw * k - w) / 2, (ch * k - h) / 2, w, h).to_image()
        };
        if logo_scale > 0 {
            let cy = if transparent { h as i32 / 2 } else { (h as f32 * 0.3) as i32 };
            if !transparent {
                // 로고 뒤를 어둡게 눌러 읽히게 한다
                for (_, y, p) in img.enumerate_pixels_mut() {
                    let d = ((y as i32 - cy).abs() as f32 / (lh as f32 * logo_scale as f32 * 1.4)).min(1.0);
                    let k = 0.45 + 0.55 * d;
                    for c in 0..3 {
                        p[c] = (p[c] as f32 * k) as u8;
                    }
                }
            }
            draw_logo(&mut img, &logo, lw, lh, logo_scale, cy);
        }
        img.save(out.join(format!("{name}.png"))).unwrap();
        println!("{name}.png");
    }
}
