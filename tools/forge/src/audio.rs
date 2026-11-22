//! 효과음과 배경음을 직접 합성해 assets/audio/*.wav(22050Hz, 16비트 모노)로 쓴다.
//! 외부 음원을 쓰지 않으므로 라이선스 문제가 없다. 시드가 고정이라 매번 같은 결과가 나온다.

use std::f32::consts::TAU;
use std::path::Path;

const SR: f32 = 22050.0;

#[derive(Clone, Copy)]
enum Wave {
    Sine,
    Square,
    Saw,
    Tri,
    Noise,
}

/// 결정적 난수(LCG).
struct Rng(u64);
impl Rng {
    fn next(&mut self) -> f32 {
        self.0 = self.0.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
        ((self.0 >> 33) as f32 / (1u64 << 31) as f32) * 2.0 - 1.0
    }
    fn pick(&mut self, n: usize) -> usize {
        ((self.next() * 0.5 + 0.5) * n as f32) as usize % n
    }
}

fn midi(n: f32) -> f32 {
    440.0 * 2f32.powf((n - 69.0) / 12.0)
}

/// 소리 하나: 주파수가 f0→f1로 지수 변화, 어택/릴리스 엔벨로프, 한 극 저역 통과 필터.
#[derive(Clone, Copy)]
struct Voice {
    wave: Wave,
    f0: f32,
    f1: f32,
    dur: f32,
    vol: f32,
    attack: f32,
    release: f32,
    lowpass: f32, // 0~1, 1이면 필터 없음
    vibrato: f32,
}

impl Voice {
    fn new(wave: Wave, f0: f32, dur: f32, vol: f32) -> Self {
        Voice { wave, f0, f1: f0, dur, vol, attack: 0.005, release: dur * 0.8, lowpass: 1.0, vibrato: 0.0 }
    }
    fn to(mut self, f1: f32) -> Self {
        self.f1 = f1;
        self
    }
    fn env(mut self, attack: f32, release: f32) -> Self {
        self.attack = attack;
        self.release = release;
        self
    }
    fn lp(mut self, k: f32) -> Self {
        self.lowpass = k;
        self
    }
    fn vib(mut self, v: f32) -> Self {
        self.vibrato = v;
        self
    }
}

fn render(buf: &mut Vec<f32>, start: f32, v: Voice, rng: &mut Rng) {
    let n = (v.dur * SR) as usize;
    let s0 = (start * SR) as usize;
    if buf.len() < s0 + n {
        buf.resize(s0 + n, 0.0);
    }
    let (mut phase, mut lp) = (0.0f32, 0.0f32);
    for i in 0..n {
        let t = i as f32 / SR;
        let k = t / v.dur;
        let f = v.f0 * (v.f1 / v.f0).powf(k) * (1.0 + v.vibrato * (t * 38.0).sin());
        phase = (phase + f / SR).fract();
        let raw = match v.wave {
            Wave::Sine => (phase * TAU).sin(),
            Wave::Square => if phase < 0.5 { 0.6 } else { -0.6 },
            Wave::Saw => (phase * 2.0 - 1.0) * 0.6,
            Wave::Tri => 1.0 - 4.0 * (phase - 0.5).abs(),
            Wave::Noise => rng.next(),
        };
        lp += (raw - lp) * v.lowpass;
        let a = if t < v.attack { t / v.attack } else { 1.0 };
        let r = ((v.dur - t) / v.release).clamp(0.0, 1.0);
        buf[s0 + i] += lp * a * r * r * v.vol;
    }
}

fn write_wav(path: &Path, samples: &[f32]) {
    let peak = samples.iter().fold(0f32, |m, s| m.max(s.abs())).max(1e-6);
    let gain = if peak > 0.95 { 0.95 / peak } else { 1.0 };
    let mut data = Vec::with_capacity(44 + samples.len() * 2);
    let len = (samples.len() * 2) as u32;
    data.extend_from_slice(b"RIFF");
    data.extend_from_slice(&(36 + len).to_le_bytes());
    data.extend_from_slice(b"WAVEfmt ");
    data.extend_from_slice(&16u32.to_le_bytes());
    data.extend_from_slice(&1u16.to_le_bytes()); // PCM
    data.extend_from_slice(&1u16.to_le_bytes()); // 모노
    data.extend_from_slice(&(SR as u32).to_le_bytes());
    data.extend_from_slice(&((SR as u32) * 2).to_le_bytes());
    data.extend_from_slice(&2u16.to_le_bytes());
    data.extend_from_slice(&16u16.to_le_bytes());
    data.extend_from_slice(b"data");
    data.extend_from_slice(&len.to_le_bytes());
    for s in samples {
        data.extend_from_slice(&(((s * gain).tanh() * 32000.0) as i16).to_le_bytes());
    }
    std::fs::write(path, data).expect("WAV 저장");
}

fn sfx(name: &str) -> Vec<f32> {
    use Wave::*;
    let mut b = Vec::new();
    let r = &mut Rng(name.len() as u64 * 7919);
    let mut v = |b: &mut Vec<f32>, t: f32, voice: Voice| render(b, t, voice, r);
    match name {
        "shoot" => {
            v(&mut b, 0.0, Voice::new(Square, 900.0, 0.07, 0.25).to(380.0).lp(0.35));
            v(&mut b, 0.0, Voice::new(Noise, 1.0, 0.03, 0.2).lp(0.6));
        }
        "enemy_shoot" => v(&mut b, 0.0, Voice::new(Sine, 560.0, 0.09, 0.3).to(330.0)),
        "hit" => {
            v(&mut b, 0.0, Voice::new(Noise, 1.0, 0.05, 0.5).lp(0.5));
            v(&mut b, 0.0, Voice::new(Sine, 320.0, 0.08, 0.5).to(110.0));
        }
        "enemy_die" => {
            v(&mut b, 0.0, Voice::new(Noise, 1.0, 0.28, 0.6).lp(0.25));
            v(&mut b, 0.0, Voice::new(Square, 240.0, 0.22, 0.25).to(55.0).lp(0.3));
        }
        "player_hurt" => {
            v(&mut b, 0.0, Voice::new(Square, 320.0, 0.25, 0.4).to(90.0).lp(0.3).vib(0.08));
            v(&mut b, 0.0, Voice::new(Noise, 1.0, 0.12, 0.4).lp(0.4));
        }
        "player_die" => {
            v(&mut b, 0.0, Voice::new(Saw, 420.0, 1.2, 0.45).to(40.0).lp(0.2).vib(0.05));
            v(&mut b, 0.0, Voice::new(Noise, 1.0, 0.8, 0.35).lp(0.12));
        }
        "dash" => v(&mut b, 0.0, Voice::new(Noise, 1.0, 0.18, 0.45).lp(0.08).env(0.06, 0.12)),
        "coin" => {
            v(&mut b, 0.0, Voice::new(Square, 1320.0, 0.06, 0.18).lp(0.5));
            v(&mut b, 0.05, Voice::new(Square, 1760.0, 0.1, 0.18).lp(0.5));
        }
        "pickup" => {
            for (i, n) in [72.0, 76.0, 79.0].iter().enumerate() {
                v(&mut b, i as f32 * 0.06, Voice::new(Tri, midi(*n), 0.14, 0.4));
            }
        }
        "upgrade" => {
            for (i, n) in [69.0, 72.0, 76.0, 81.0].iter().enumerate() {
                v(&mut b, i as f32 * 0.07, Voice::new(Tri, midi(*n), 0.3, 0.35));
                v(&mut b, i as f32 * 0.07, Voice::new(Sine, midi(*n + 12.0), 0.3, 0.12));
            }
        }
        "ui_move" => v(&mut b, 0.0, Voice::new(Square, 1200.0, 0.03, 0.12).lp(0.5)),
        "ui_select" => {
            v(&mut b, 0.0, Voice::new(Tri, 660.0, 0.06, 0.35));
            v(&mut b, 0.05, Voice::new(Tri, 990.0, 0.1, 0.35));
        }
        "explode" => {
            v(&mut b, 0.0, Voice::new(Noise, 1.0, 0.45, 0.7).lp(0.15));
            v(&mut b, 0.0, Voice::new(Sine, 120.0, 0.35, 0.6).to(35.0));
        }
        "door" => {
            v(&mut b, 0.0, Voice::new(Sine, 90.0, 0.25, 0.6).to(50.0));
            v(&mut b, 0.02, Voice::new(Noise, 1.0, 0.2, 0.25).lp(0.2));
        }
        "boss_roar" => {
            v(&mut b, 0.0, Voice::new(Saw, 95.0, 1.3, 0.5).to(70.0).lp(0.15).vib(0.06).env(0.15, 0.8));
            v(&mut b, 0.0, Voice::new(Noise, 1.0, 1.1, 0.3).lp(0.06).env(0.2, 0.7));
        }
        "stairs" => {
            for (i, n) in [76.0, 72.0, 69.0, 64.0, 57.0].iter().enumerate() {
                v(&mut b, i as f32 * 0.09, Voice::new(Tri, midi(*n), 0.2, 0.35));
            }
        }
        "victory" => {
            for (i, n) in [69.0, 72.0, 76.0, 81.0, 84.0, 88.0].iter().enumerate() {
                v(&mut b, i as f32 * 0.12, Voice::new(Tri, midi(*n), 0.9, 0.3).env(0.01, 0.8));
            }
        }
        _ => unreachable!(),
    }
    b
}

/// 배경음: 화성 진행 위에 패드·베이스·아르페지오·멜로디·드럼을 얹은 루프.
struct Song {
    bpm: f32,
    bars: usize,
    chords: [[f32; 3]; 4], // A 단조 기준 반음 오프셋(루트 A2 = MIDI 45)
    drums: u8,             // 0 없음, 1 보통, 2 격렬
    arp: bool,
    melody: bool,
    seed: u64,
}

fn music(s: &Song) -> Vec<f32> {
    use Wave::*;
    let beat = 60.0 / s.bpm;
    let len = s.bars as f32 * 4.0 * beat;
    let mut b = vec![0.0; (len * SR) as usize];
    let r = &mut Rng(s.seed);
    for bar in 0..s.bars {
        let t0 = bar as f32 * 4.0 * beat;
        let ch = s.chords[bar % 4];
        // 패드: 약간 어긋난 톱니 두 개, 느린 어택
        for &n in &ch {
            for det in [-0.08, 0.08] {
                render(&mut b, t0, Voice::new(Saw, midi(57.0 + n + det), 4.0 * beat, 0.05).env(beat, beat).lp(0.06), r);
            }
        }
        // 베이스
        let steps = if s.drums == 0 { 1 } else if s.drums == 1 { 8 } else { 16 };
        for i in 0..steps {
            let step = 4.0 * beat / steps as f32;
            let oct = if s.drums == 2 && i % 4 == 3 { 12.0 } else { 0.0 };
            render(&mut b, t0 + i as f32 * step, Voice::new(Tri, midi(33.0 + ch[0] + oct), step * 0.9, 0.35).lp(0.3), r);
        }
        // 아르페지오(16분음표)
        if s.arp {
            for i in 0..16 {
                let n = ch[i % 3] + if (i / 3) % 2 == 1 { 12.0 } else { 0.0 };
                render(&mut b, t0 + i as f32 * beat / 4.0, Voice::new(Square, midi(69.0 + n), beat / 4.0, 0.05).lp(0.25), r);
            }
        }
        // 멜로디: 화음 구성음 위 무작위 걸음(종소리)
        if s.melody {
            let scale = [0.0, 2.0, 3.0, 5.0, 7.0, 8.0, 11.0, 12.0];
            for i in 0..2 {
                if r.next() > 0.6 {
                    continue;
                }
                let n = if i == 0 { ch[r.pick(3)] } else { scale[r.pick(scale.len())] };
                let t = t0 + i as f32 * 2.0 * beat;
                render(&mut b, t, Voice::new(Sine, midi(69.0 + n), 2.0 * beat, 0.16).env(0.005, 1.8 * beat), r);
                render(&mut b, t, Voice::new(Sine, midi(81.0 + n), 1.0 * beat, 0.04).env(0.005, 0.9 * beat), r);
            }
        }
        // 드럼
        if s.drums > 0 {
            for q in 0..16 {
                let t = t0 + q as f32 * beat / 4.0;
                let kick = if s.drums == 1 { q % 8 == 0 } else { q % 4 == 0 || q == 10 };
                if kick {
                    render(&mut b, t, Voice::new(Sine, 120.0, 0.18, 0.7).to(40.0), r);
                }
                if q % 8 == 4 {
                    render(&mut b, t, Voice::new(Noise, 1.0, 0.16, 0.3).lp(0.35), r);
                }
                if q % 2 == 0 || s.drums == 2 {
                    render(&mut b, t, Voice::new(Noise, 1.0, 0.03, if q % 4 == 2 { 0.1 } else { 0.06 }).lp(0.9), r);
                }
            }
        }
    }
    // 끝을 넘어간 꼬리를 처음에 더해 이음매 없는 루프로 만든다
    let n = (len * SR) as usize;
    let tail: Vec<f32> = b.drain(n..).collect();
    for (i, s) in tail.into_iter().enumerate() {
        b[i % n] += s;
    }
    b
}

pub fn run(root: &Path) {
    let dir = root.join("assets/audio");
    std::fs::create_dir_all(&dir).expect("assets/audio 만들기");
    for name in [
        "shoot", "enemy_shoot", "hit", "enemy_die", "player_hurt", "player_die", "dash", "coin", "pickup", "upgrade",
        "ui_move", "ui_select", "explode", "door", "boss_roar", "stairs", "victory",
    ] {
        write_wav(&dir.join(format!("{name}.wav")), &sfx(name));
    }
    let am = [0.0, 3.0, 7.0];
    let songs = [
        ("music_menu", Song { bpm: 66.0, bars: 16, chords: [am, [-5.0, -2.0, 3.0], [-4.0, 0.0, 3.0], [-7.0, -4.0, 0.0]], drums: 0, arp: false, melody: true, seed: 1 }),
        ("music_dungeon", Song { bpm: 100.0, bars: 16, chords: [am, [-4.0, 0.0, 3.0], [-7.0, -4.0, 0.0], [-5.0, -1.0, 2.0]], drums: 1, arp: true, melody: true, seed: 2 }),
        ("music_boss", Song { bpm: 140.0, bars: 16, chords: [am, [1.0, 5.0, 8.0], am, [-5.0, -1.0, 2.0]], drums: 2, arp: true, melody: false, seed: 3 }),
    ];
    for (name, song) in songs {
        write_wav(&dir.join(format!("{name}.wav")), &music(&song));
    }
    println!("assets/audio: 효과음 17개, 배경음 3개");
}
