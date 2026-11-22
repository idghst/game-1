//! 생성된 원본 이미지를 일관된 픽셀아트로 바꾼다:
//! 배경 키 제거 → 내용 영역 자르기 → 면적 평균 축소 → 공용 팔레트로 양자화 → 1px 외곽선.

use crate::Entry;
use image::{Rgba, RgbaImage};
use std::path::Path;

/// 공용 다크 판타지 팔레트(모든 에셋이 이 색만 쓴다).
const PALETTE: &[u32] = &[
    0x0b0a0f, 0x17141d, 0x231e2b, 0x342c3d, 0x4a4054, 0x655a70, 0x85798e, 0xa89cae, 0xcbc2cf, 0xece6e8,
    0x2a1a14, 0x4a2c1e, 0x6e4430, 0x966244, 0xba8a5e, 0xdcb88c,
    0x3a0e14, 0x6a1420, 0x9e2430, 0xd03a3a, 0xf06a5a,
    0x8a3a12, 0xc45a1a, 0xf08a2a, 0xf8c040, 0xfce888,
    0x14281c, 0x24442a, 0x3e6a38, 0x6a9a4a, 0xa0c868,
    0x102a30, 0x1c4a52, 0x2e7a7a, 0x4ab0a0, 0x1a2448, 0x2c3e7a, 0x4a66b0, 0x7aa0e0,
    0x2a1438, 0x4a2462, 0x7a3a94, 0xa85ac8, 0xd090e8, 0x8a2a5a, 0xd04a8a,
];
const OUTLINE: [u8; 3] = [0x0b, 0x0a, 0x0f];

fn rgb(c: u32) -> [u8; 3] {
    [(c >> 16) as u8, (c >> 8) as u8, c as u8]
}

/// 사람 눈에 가까운 "redmean" 색 거리.
fn dist(a: [u8; 3], b: [u8; 3]) -> f32 {
    let rm = (a[0] as f32 + b[0] as f32) / 2.0;
    let (dr, dg, db) = (a[0] as f32 - b[0] as f32, a[1] as f32 - b[1] as f32, a[2] as f32 - b[2] as f32);
    ((2.0 + rm / 256.0) * dr * dr + 4.0 * dg * dg + (2.0 + (255.0 - rm) / 256.0) * db * db).sqrt()
}

fn nearest(c: [u8; 3]) -> [u8; 3] {
    PALETTE.iter().map(|&p| rgb(p)).min_by(|a, b| dist(c, *a).total_cmp(&dist(c, *b))).unwrap()
}

fn px(img: &RgbaImage, x: u32, y: u32) -> [u8; 3] {
    let p = img.get_pixel(x, y).0;
    [p[0], p[1], p[2]]
}

/// 네 모서리의 평균색을 배경으로 보고 비슷한 픽셀을 투명하게 만든 뒤, 경계의 번진 픽셀을 한 겹 더 지운다.
fn key_out(img: &mut RgbaImage) {
    let (w, h) = img.dimensions();
    let mut sum = [0f32; 3];
    let mut n = 0.0;
    for &(cx, cy) in &[(0, 0), (w - 8, 0), (0, h - 8), (w - 8, h - 8)] {
        for y in cy..cy + 8 {
            for x in cx..cx + 8 {
                let p = px(img, x, y);
                for i in 0..3 {
                    sum[i] += p[i] as f32;
                }
                n += 1.0;
            }
        }
    }
    let bg = [(sum[0] / n) as u8, (sum[1] / n) as u8, (sum[2] / n) as u8];
    for p in img.pixels_mut() {
        if dist([p[0], p[1], p[2]], bg) < 140.0 {
            p[3] = 0;
        }
    }
    let copy = img.clone();
    for y in 1..h - 1 {
        for x in 1..w - 1 {
            let edge = [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)].iter().any(|&(a, b)| copy.get_pixel(a, b)[3] == 0);
            if edge && dist(px(&copy, x, y), bg) < 260.0 {
                img.get_pixel_mut(x, y)[3] = 0;
            }
        }
    }
}

fn bbox(img: &RgbaImage) -> (u32, u32, u32, u32) {
    let (mut x0, mut y0, mut x1, mut y1) = (u32::MAX, u32::MAX, 0, 0);
    for (x, y, p) in img.enumerate_pixels() {
        if p[3] > 0 {
            x0 = x0.min(x);
            y0 = y0.min(y);
            x1 = x1.max(x + 1);
            y1 = y1.max(y + 1);
        }
    }
    if x0 == u32::MAX {
        (0, 0, img.width(), img.height())
    } else {
        (x0, y0, x1, y1)
    }
}

/// 영역 (x0,y0)-(x1,y1)을 tw×th 안에 비율을 지켜 맞추며(fit) 면적 평균으로 줄인다.
/// cover=true면 비율을 지키며 꽉 채우고 넘치는 부분을 자른다.
fn shrink(img: &RgbaImage, r: (u32, u32, u32, u32), tw: u32, th: u32, cover: bool, lift: f32) -> RgbaImage {
    let (bw, bh) = ((r.2 - r.0) as f32, (r.3 - r.1) as f32);
    let s = if cover { (bw / tw as f32).min(bh / th as f32) } else { (bw / tw as f32).max(bh / th as f32) };
    let (ox, oy) = (r.0 as f32 + (bw - s * tw as f32) / 2.0, r.1 as f32 + (bh - s * th as f32) / 2.0);
    let mut out = RgbaImage::new(tw, th);
    for ty in 0..th {
        for tx in 0..tw {
            let (sx0, sy0) = (ox + tx as f32 * s, oy + ty as f32 * s);
            let (mut sum, mut opaque, mut total) = ([0f32; 3], 0f32, 0f32);
            let mut y = sy0.floor().max(0.0) as i64;
            while (y as f32) < sy0 + s {
                let mut x = sx0.floor().max(0.0) as i64;
                while (x as f32) < sx0 + s {
                    total += 1.0;
                    if x < img.width() as i64 && y < img.height() as i64 {
                        let p = img.get_pixel(x as u32, y as u32);
                        if p[3] > 0 {
                            opaque += 1.0;
                            for i in 0..3 {
                                sum[i] += p[i] as f32;
                            }
                        }
                    }
                    x += 1;
                }
                y += 1;
            }
            if opaque > 0.0 && opaque / total.max(1.0) >= 0.4 {
                // 대비를 조금 올려 작은 크기에서도 형태가 보이게 한다
                let c = sum.map(|v| ((v / opaque - 128.0) * 1.2 + 128.0 + lift).clamp(0.0, 255.0) as u8);
                let q = nearest(c);
                out.put_pixel(tx, ty, Rgba([q[0], q[1], q[2], 255]));
            }
        }
    }
    out
}

fn outline(img: &RgbaImage) -> RgbaImage {
    let (w, h) = img.dimensions();
    let mut out = RgbaImage::new(w + 2, h + 2);
    image::imageops::overlay(&mut out, img, 1, 1);
    let base = out.clone();
    for y in 0..h + 2 {
        for x in 0..w + 2 {
            if base.get_pixel(x, y)[3] > 0 {
                continue;
            }
            let near = [(-1i32, 0i32), (1, 0), (0, -1), (0, 1)].iter().any(|&(dx, dy)| {
                let (nx, ny) = (x as i32 + dx, y as i32 + dy);
                nx >= 0 && ny >= 0 && nx < (w + 2) as i32 && ny < (h + 2) as i32 && base.get_pixel(nx as u32, ny as u32)[3] > 0
            });
            if near {
                out.put_pixel(x, y, Rgba([OUTLINE[0], OUTLINE[1], OUTLINE[2], 255]));
            }
        }
    }
    out
}

pub fn run(root: &Path, entries: &[Entry]) {
    let dir = root.join("assets/sprites");
    std::fs::create_dir_all(&dir).expect("assets/sprites 만들기");
    for e in entries {
        let src = root.join(format!("assets/src/{}.png", e.name));
        let Ok(img) = image::open(&src) else {
            eprintln!("건너뜀(원본 없음): {}", e.name);
            continue;
        };
        let mut img = img.to_rgba8();
        let out = match e.kind.as_str() {
            "sprite" => {
                key_out(&mut img);
                outline(&shrink(&img, bbox(&img), e.w - 2, e.h - 2, false, 18.0))
            }
            // 바닥·벽은 어둡게 눌러 캐릭터가 도드라지게 한다
            "tile" => shrink(&img, (0, 0, img.width(), img.height()), e.w, e.h, true, if e.name.starts_with("wall_") { 30.0 } else { -6.0 }),
            _ => shrink(&img, (0, 0, img.width(), img.height()), e.w, e.h, true, 0.0),
        };
        out.save(dir.join(format!("{}.png", e.name))).expect("PNG 저장");
        println!("{} -> {}x{}", e.name, out.width(), out.height());
    }
}

/// 확인용 미리보기: 모든 스프라이트를 8배 확대(nearest)해 한 장에 늘어놓는다.
pub fn sheet(root: &Path, entries: &[Entry], out: &Path) {
    let (cell, cols) = (4 * 48u32, 6u32);
    let rows = (entries.len() as u32).div_ceil(cols);
    let mut canvas = RgbaImage::from_pixel(cell * cols, cell * rows, Rgba([40, 36, 48, 255]));
    for (i, e) in entries.iter().enumerate() {
        let Ok(img) = image::open(root.join(format!("assets/sprites/{}.png", e.name))) else { continue };
        let img = img.to_rgba8();
        let k = (cell / img.width().max(img.height())).clamp(1, 4);
        let big = image::imageops::resize(&img, img.width() * k, img.height() * k, image::imageops::FilterType::Nearest);
        let (cx, cy) = ((i as u32 % cols) * cell, (i as u32 / cols) * cell);
        image::imageops::overlay(&mut canvas, &big, cx as i64, cy as i64);
    }
    canvas.save(out).expect("미리보기 저장");
}
