"""Audition page: three candidates for every sound build_audio.py ships, for the designer to pick from.

    python tools/audio/audition.py            # renders all, writes the page
    python tools/audio/audition.py step_tile  # re-render names containing "step_tile"
    python tools/audio/audition.py --round 2  # round 2: tools/audio/audition_r2.py ALT (3 new options per sound
                                              # the designer did not mark final), built from round-1 picks.json

Option A is the shipped builder; B and C are alternatives from the same CC0 packs or the same synthesis
helpers. Each candidate is normalised to its category target like the shipped file. Output (gitignored):
    tools/audio/.cache/audition/<name>_<a|b|c>.wav
    tools/audio/.cache/audition/index.html   waveform, play, pick best, notes; picks export as JSON
The exported picks.json is what the next build_audio.py edit reads by hand: the picked option's builder
replaces the shipped one.
"""
import html
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from build_audio import (CATEGORIES, CHAR_PITCH, SR, alarm, bp, catalogue, clip, crackle, distortion, drips, env,  # noqa: E402
                         fetch, hp, loopify, lp, lufs, mix, n, noise, normalise, osc, pain_cry, read, recording, resample,
                         silence, src, voice, write)

OUT = os.path.join(os.path.dirname(__file__), ".cache", "audition")


def tile(x, sec):
    """`x` repeated to `sec` seconds (short Kenney loops under a bed)."""
    out = []
    while len(out) < n(sec):
        out += x
    return out[:n(sec)]


def bed(layers):
    return loopify(mix(*layers), 1.0)


# ---------------------------------------------------------------- alternatives: name -> [(label, builder)] for B, C

def amb_a_b():  # 50 Hz mains hum, vent rumble, sparse drips
    L = 13.0
    hum = mix((osc(L, 100), -6), (osc(L, 200), -12), (osc(L, 300), -22))
    return bed([(hum, -9), (lp(noise(L, 211), 380), -2), (drips(L, 0.2, 212), -14)])


def amb_a_c():  # failing fluorescent tube: buzz with flicker bursts
    L = 13.0
    buzz = bp(osc(L, 120, shape="saw"), 2400, 2.0)
    flick = lp(crackle(L, 3.0, 213), 5000)
    return bed([(buzz, -12), (flick, -10), (lp(noise(L, 214), 450), -3), (drips(L, 0.3, 215), -18)])


def amb_b_b():  # deeper fans with slow beating
    L = 13.0
    return bed([(bp(noise(L, 221), 450, 0.5), 0), (lp(noise(L, 222), 110), 4),
                (mix((osc(L, 120), -14), (osc(L, 121.3), -14)), -4)])


def amb_b_c():  # fans plus drive chatter
    L = 13.0
    chatter = bp(crackle(L, 9.0, 223), 3200, 1.2)
    return bed([(bp(noise(L, 224), 700, 0.6), 0), (lp(noise(L, 225), 160), 2), (chatter, -14),
                (osc(L, 241), -26)])


def amb_c_b():  # lower 41 Hz drone, monitor chirps
    L = 13.0
    chirps = drips(L, 0.25, 231)
    return bed([(mix((osc(L, 41), 0), (osc(L, 82), -8)), -4), (lp(noise(L, 232), 250), -6),
                (hp(chirps, 2500), -20)])


def amb_c_c():  # Kenney engine hum, filtered down
    L = 13.0
    eng = lp(tile(src("spaceEngineLow_001"), L), 400)
    return bed([(eng, 0), (bp(osc(L, 60, shape="saw"), 1800, 1.5), -18)])


def amb_link_b():  # duct air, metal ticks from expansion
    L = 13.0
    ticks = drips(L, 0.1, 241)
    return bed([(bp(noise(L, 242), 300, 0.4), 0), (osc(L, 50), -16), (hp(ticks, 1500), -16)])


def amb_link_c():  # Kenney engine bed through a pipe
    L = 13.0
    return bed([(bp(tile(src("spaceEngine_002"), L), 220, 0.8), 0), (lp(noise(L, 243), 200), -4)])


def step_true_b():
    return mix(lp(resample(src("footstep_concrete_000"), 0.6), 900), (resample(src("impactPunch_heavy_000"), 0.7), -3),
               (hp(src("scratch_001"), 2500), -16, 0.02))


def step_true_c():
    return mix(lp(resample(src("footstep_wood_003"), 0.7), 1500), (hp(src("scratch_005"), 2500), -8, 0.01),
               (resample(src("impactSoft_heavy_004"), 0.75), -3))


def lunge_cue_b():  # higher, hissing wind-up
    L = 0.6
    g = voice(L, [110, 150, 230], [(500, 0), (1200, -4), (2600, -10)], 351, breath=0.8)
    return clip(env(mix(g, (hp(noise(L, 352), 3000), -8)), 0.03, 0.3), 2.0)


def lunge_cue_c():  # inhale then force-field snarl
    L = 0.6
    inhale = env(bp(noise(L, 353), 1500, 0.7), 0.4, 0.2)
    snarl = lp(resample(src("forceField_002"), 0.6), 1500)[:n(L)]
    return mix((inhale, -4), (snarl, 0))


def taser_crackle_b():
    crk = env(mix(crackle(0.7, 220, 361), (osc(0.7, 50, shape="saw"), -14)), 0.005, 0.8)
    return mix(src("impactGeneric_light_002"), (crk, -1, 0.03))


def taser_crackle_c():
    return mix(src("laserSmall_002"), (env(crackle(0.7, 140, 362), 0.005, 0.6), -2, 0.02))


def callout_b(c):  # single rising chirp, interval per survivor
    p = CHAR_PITCH[c]
    sq = bp(env(noise(0.06, 190 + c), 0.002, 1), 2400, 1.0)
    ch = bp(env(osc(0.16, 800 * p, 1100 * p * (1 + c * 0.05), shape="sq"), 0.003, 0.6), 1500, 0.7)
    return mix((sq, -4), (ch, 0, 0.06))


def callout_c(c):  # squelch then muffled vowel bursts (pseudo-speech through a radio band)
    p = CHAR_PITCH[c]
    out = []
    for i, (d, fm) in enumerate([(0.12, (700, 1200)), (0.09, (450, 1900)), (0.16, (600, 1000))]):
        out += env(voice(d, [150 * p, 135 * p], [(fm[0], 0), (fm[1], -4)], 300 + c * 3 + i), 0.01, 0.6) + silence(0.03)
    v = bp(clip(out, 3.0), 1500, 0.9)
    sq = bp(env(noise(0.07, 290 + c), 0.002, 1), 2200, 1.0)
    return mix((sq, -4), (v, 0, 0.07), (sq, -6, 0.07 + len(v) / SR))


def grunt_b(c):  # short breathy grunt
    f = 140 * CHAR_PITCH[c]
    return env(voice(0.22, [f * 1.2, f], [(700, 0), (1200, -4), (2600, -10)], 400 + c, 0.6), 0.005, 1.6)


def grunt_c(c):  # lower, strained
    f = 115 * CHAR_PITCH[c]
    return env(clip(voice(0.45, [f, f * 1.15, f * 0.9], [(550, 0), (950, -3), (2300, -12)], 410 + c, 0.35), 1.8),
               0.02, 1.0)


def pain_cry_b():  # higher shriek
    v = voice(0.8, [180, 260, 210, 140], [(700, 0), (1400, -2), (2900, -6)], 420, 0.7)
    return env(clip(mix(v, (hp(noise(0.8, 421), 2000), -10)), 3.5), 0.02, 0.9)


def pain_cry_c():  # low roar
    v = voice(1.0, [60, 85, 75, 50], [(350, 0), (700, -2), (1600, -8)], 422, 0.5)
    return env(clip(mix(v, (lp(noise(1.0, 423), 900), -6)), 4.0), 0.04, 0.7)


def distortion_b():
    L = 2.0
    out, ph = [], 0.0
    for i in range(n(L)):
        t = i / SR
        ph += 2 * math.pi * 90 * (1 + 0.4 * math.sin(2 * math.pi * 5 * t)) / SR
        out.append(math.sin(ph) * math.sin(2 * math.pi * 23 * t))
    return env(mix(clip(out, 2.5), (crackle(L, 15, 431), -12)), 0.2, 0.6)


def distortion_c():
    L = 2.0
    ff = lp(resample(src("forceField_000"), 0.5), 2000)
    return env(mix((tile(ff, L), 0), (crackle(L, 40, 432), -8)), 0.15, 0.6)


def alarm_whoop(sec, lo, hi, period):
    out = []
    for _ in range(int(sec / period)):
        out += env(osc(period, lo, hi, shape="sq"), 0.01, 0.2)
    return lp(out, 3000)


def beeps(sec, f, on, off):
    out = []
    while len(out) < n(sec):
        out += env(osc(on, f, shape="sq"), 0.005, 0.3) + silence(off)
    return lp(out[:n(sec)], 3500)


def hide_cue_b():  # slow, three breaths
    br = []
    for i in range(3):
        br += env(bp(noise(0.7, 440 + i), 800, 0.8), 0.3, 1.5) + silence(0.25)
    return br


def hide_cue_c():  # shaky held breath
    x = []
    for i in range(2):
        b = bp(noise(0.6, 450 + i), 1000, 0.8)
        b = [v * (0.6 + 0.4 * math.sin(2 * math.pi * 11 * k / SR)) for k, v in enumerate(b)]
        x += env(b, 0.2, 1.4) + silence(0.2)
    return x


def stinger_b():  # high cluster
    L = 1.3
    cl = lp(mix(*[(osc(L, f, shape="saw"), -6) for f in (220, 233, 311, 466)]), 2600)
    sw = [v * (i / n(L)) ** 0.25 for i, v in enumerate(cl)]
    return env(sw, 0.01, 0.6)


def stinger_c():  # hit then swell (impact plus low cluster)
    L = 1.3
    cl = lp(mix(*[(osc(L, f, shape="saw"), -6) for f in (55, 58.3, 82.4)]), 1200)
    return env(mix(cl, (src("impactMetal_heavy_003"), -2), (hp(noise(L, 461), 3000), -16)), 0.005, 0.7)


def surveillance_b():
    return mix(env(hp(noise(1.2, 470), 2000), 0.01, 0.6), (tile(src("computerNoise_002"), 1.2), -4))


def surveillance_c():
    g = src("glitch_001") + src("glitch_003") + src("glitch_004")
    return mix(g, (env(hp(noise(len(g) / SR, 471), 1500), 0.01, 0.6), -10))


def blackout_b():  # thunk then falling hum
    return mix(lp(src("lowFrequency_explosion_000"), 300), (env(osc(1.2, 120, 30), 0.0, 1.5), -8, 0.1),
               (src("switch_005"), -6))


def blackout_c():
    return mix(lp(src("explosionCrunch_002"), 500), (src("metalLatch"), -4, 0.2))


def F(name):
    return lambda: src(name)


ALT = {
    "step_tile": [("concrete_004 brighter + glass tick", lambda: mix(hp(resample(src("footstep_concrete_004"), 1.25), 500),
                                                                     (hp(src("impactGlass_light_000"), 3000), -22))),
                  ("wood_001 pitched up", lambda: hp(resample(src("footstep_wood_001"), 1.3), 400))],
    "step_concrete": [("concrete_003", F("footstep_concrete_003")), ("RPG footstep00", lambda: lp(src("footstep00"), 4000))],
    "step_metal": [("concrete + plate ring", lambda: mix(src("footstep_concrete_000"), (hp(src("impactPlate_light_002"), 800), -6))),
                   ("wood + metal rattle", lambda: mix(src("footstep_wood_002"), (src("impactMetal_light_003"), -3)))],
    "step_rubber": [("carpet_002", F("footstep_carpet_002")), ("snow_001 muffled", lambda: lp(src("footstep_snow_001"), 2500))],
    "step_true_form": [("heavier punch stomp", step_true_b), ("claw scrape step", step_true_c)],
    "amb_a": [("50 Hz mains, sparse drips", amb_a_b), ("failing tube flicker", amb_a_c)],
    "amb_b": [("deep fans, slow beating", amb_b_b), ("fans + drive chatter", amb_b_c)],
    "amb_c": [("41 Hz drone, chirps", amb_c_b), ("engine hum filtered", amb_c_c)],
    "amb_link": [("duct air, metal ticks", amb_link_b), ("engine through a pipe", amb_link_c)],
    "lunge_cue": [("higher hissing wind-up", lunge_cue_b), ("inhale + snarl", lunge_cue_c)],
    "lunge_scrape": [("scratch_002 + light metal", lambda: mix(lp(src("scratch_002"), 2500), (src("impactMetal_light_002"), -8))),
                     ("mining scrape", lambda: lp(src("impactMining_001"), 3000))],
    "lunge_hit": [("punch_003 + soft_000", lambda: mix(src("impactPunch_heavy_003"), (src("impactSoft_heavy_000"), -3))),
                  ("punch_000 + cloth", lambda: mix(src("impactPunch_heavy_000"), (src("cloth1"), -4, 0.02)))],
    "taser_crackle": [("denser crackle", taser_crackle_b), ("laser zap + crackle", taser_crackle_c)],
    "taser_fizz": [("slow low fizz", lambda: lp(env(crackle(0.5, 30, 365), 0.01, 1.0), 1000)),
                   ("force-field fizz", lambda: env(lp(src("forceField_003"), 1200)[:n(0.5)], 0.01, 1.0))],
    "hide_cue": [("slow, three breaths", hide_cue_b), ("shaky held breath", hide_cue_c)],
    "distortion": [("slower, deeper wobble", distortion_b), ("force-field warble", distortion_c)],
    "fuse_install": [("latch + medium metal + hum", lambda: mix(src("metalLatch"), (src("impactMetal_medium_003"), -2, 0.1),
                                                                (env(osc(0.6, 100, shape="saw"), 0.05, 1), -14, 0.3))),
                     ("switch + heavy plate + zap", lambda: mix(src("switch_003"), (src("impactPlate_heavy_001"), -2, 0.1),
                                                                (env(crackle(0.3, 150, 380), 0.005, 1), -6, 0.3)))],
    "hide_enter": [("creak2 + latch", lambda: mix(src("creak2"), (src("metalLatch"), -6, 0.15))),
                   ("sci-fi door open, low", lambda: lp(src("doorOpen_000"), 2500))],
    "hide_exit": [("creak1 + click", lambda: mix(src("creak1"), (src("metalClick"), -6, 0.15))),
                  ("sci-fi door close, low", lambda: lp(src("doorClose_000"), 2500))],
    "door_open": [("doorOpen_2", F("doorOpen_2")), ("sci-fi doorOpen_001", F("doorOpen_001"))],
    "door_close": [("doorClose_2", F("doorClose_2")), ("sci-fi doorClose_002", F("doorClose_002"))],
    "barricade_build": [("medium wood knocks", lambda: mix(*[(src("impactWood_medium_00%d" % i), -i * 0.5, i * 0.3) for i in range(4)])),
                        ("planks + hammer taps", lambda: mix(*[(src("impactPlank_medium_00%d" % i), 0, i * 0.4) for i in range(3)],
                                                             *[(src("impactMetal_light_00%d" % i), -6, 0.2 + i * 0.4) for i in range(3)]))],
    "barricade_break": [("heavy_004 + plank_000", lambda: mix(src("impactWood_heavy_004"), (src("impactPlank_medium_000"), -2, 0.05))),
                        ("crunch + splinter", lambda: mix(lp(src("explosionCrunch_000"), 2500), (src("impactWood_heavy_002"), -2, 0.03)))],
    "objective_dock": [("latch + confirmation", lambda: mix(src("metalLatch"), (src("confirmation_002"), -8, 0.15))),
                       ("click + falling beep", lambda: mix(src("metalClick"), (env(osc(0.18, 1320), 0.005, 1) + env(osc(0.25, 880), 0.005, 1), -10, 0.15)))],
    "objective_alarm": [("fast hi-lo", lambda: alarm(2.4, 900, 600, 0.3, 1)), ("whoop siren", lambda: alarm_whoop(2.4, 500, 900, 0.8))],
    "pain_cry_true_form": [("higher shriek", pain_cry_b), ("low roar", pain_cry_c)],
    "scare_transformation_reveal": [("slow wobble + shriek", lambda: mix(distortion_b()[:n(0.8)], (pain_cry_b(), -2, 0.3))),
                                    ("warble + roar", lambda: mix(distortion_c()[:n(0.8)], (pain_cry_c(), -2, 0.3)))],
    "scare_door_burst": [("wood_004 + crunch", lambda: mix(src("impactWood_heavy_004"), (lp(src("explosionCrunch_001"), 1500), -3))),
                         ("metal + plate", lambda: mix(src("impactMetal_heavy_000"), (src("impactPlate_heavy_002"), -2, 0.03),
                                                       (lp(src("lowFrequency_explosion_001"), 500), -6)))],
    "scare_ambush_lunge": [("punch_003 + shriek", lambda: mix(src("impactPunch_heavy_003"), (pain_cry_b()[:n(0.6)], -6))),
                           ("punch + claw scratch", lambda: mix(src("impactPunch_heavy_002"), (hp(src("scratch_003"), 1500), -4, 0.02)))],
    "scare_blackout": [("thunk + falling hum", blackout_b), ("crunch + latch", blackout_c)],
    "scare_slammed_door": [("sci-fi slam + metal", lambda: mix(src("doorClose_002"), (src("impactMetal_heavy_004"), -1, 0.02))),
                           ("doorClose_3 + wood", lambda: mix(src("doorClose_3"), (src("impactWood_heavy_000"), -1, 0.02)))],
    "scare_glass_break": [("medium glass set", lambda: mix(src("impactGlass_medium_000"), (src("impactGlass_medium_002"), -3, 0.05),
                                                           (src("impactGlass_light_000"), -6, 0.3))),
                          ("heavy 001/003/004", lambda: mix(src("impactGlass_heavy_001"), (src("impactGlass_heavy_003"), -2, 0.04),
                                                            (src("impactGlass_heavy_004"), -5, 0.2)))],
    "scare_alarm_fuse": [("faster, higher", lambda: alarm(2.4, 1000, 800, 0.25, 2)), ("pulsed beeps", lambda: beeps(2.4, 950, 0.12, 0.12))],
    "scare_alarm_evacuation": [("rising siren", lambda: alarm_whoop(4.0, 400, 900, 1.5)), ("faster hi-lo", lambda: alarm(4.0, 700, 500, 0.5, 3))],
    "scare_recording_room": [("other seed, more static", lambda: mix(recording(540), (hp(noise(2.5, 541), 3000), -14))),
                             ("slower, lower", lambda: resample(recording(542), 0.8))],
    "scare_recording_script": [("other seed, more static", lambda: mix(recording(550), (hp(noise(2.5, 551), 3000), -14))),
                               ("slower, lower", lambda: resample(recording(552), 0.8))],
    "scare_surveillance_image": [("computerNoise_002 static", surveillance_b), ("glitch sequence", surveillance_c)],
    "scare_stinger": [("high cluster", stinger_b), ("hit + low swell", stinger_c)],
    "ui_click": [("click_004", F("click_004")), ("select_002", F("select_002"))],
    "ping_rejected": [("error_006", F("error_006")), ("error_002", F("error_002"))],
}
for _c in range(1, 6):
    ALT["callout_c%d" % _c] = [("single rising chirp", lambda c=_c: callout_b(c)), ("muffled radio voice", lambda c=_c: callout_c(c))]
    ALT["grunt_c%d" % _c] = [("short breathy", lambda c=_c: grunt_b(c)), ("lower, strained", lambda c=_c: grunt_c(c))]


# ---------------------------------------------------------------- page

def peaks(x, buckets=600):
    step = max(1, len(x) // buckets)
    return [[round(min(x[i:i + step]), 3), round(max(x[i:i + step]), 3)] for i in range(0, len(x), step)][:buckets]


PAGE = r"""<!doctype html><meta charset="utf-8"><title>Dead Signal audio audition</title>
<style>
body{background:#111;color:#ddd;font:14px system-ui,sans-serif;margin:20px;max-width:1100px}
h1{font-size:20px}.card{background:#1b1b1b;border:1px solid #333;border-radius:6px;padding:12px;margin:14px 0}
.card h2{font-size:16px;margin:0 0 4px}.meta{color:#888;font-size:12px;margin-bottom:8px}
.opt{display:grid;grid-template-columns:150px 1fr;gap:8px;align-items:center;margin:6px 0;padding:6px;border-radius:4px}
.opt.best{background:#16301c;outline:1px solid #3c8}.opt label{cursor:pointer}
canvas{width:100%;height:60px;background:#0b0b0b;border-radius:3px;cursor:pointer}
button{background:#2a2a2a;color:#ddd;border:1px solid #444;border-radius:3px;padding:3px 10px;cursor:pointer}
textarea{width:100%;background:#0e0e0e;color:#ddd;border:1px solid #333;border-radius:3px;min-height:38px}
input.note{width:100%;background:#0e0e0e;color:#ddd;border:1px solid #333;border-radius:3px;padding:3px}
.bar{position:sticky;top:0;background:#111;padding:8px 0;border-bottom:1px solid #333;z-index:2}
.done{color:#3c8}
</style>
<div class="bar"><h1>Dead Signal: audio audition, round __ROUND__</h1>
Waveforms are scaled to fit; files are level-matched per category. Click a waveform or ▶ to play (click again to stop). Pick the best per sound, note what is bad or what to improve.
Tick <b>final</b> when a sound is done; the next round only brings new options for the rest. Picks save in this browser. <button onclick="dl()">Download picks.json</button> <button onclick="cp()">Copy picks</button>
<span id="prog"></span></div>
<div id="list"></div>
<script>
const DATA = __DATA__, ROUND = __ROUND__;
const S = JSON.parse(localStorage.getItem('ds_audition_r' + ROUND) || '{}');
const save = () => { localStorage.setItem('ds_audition_r' + ROUND, JSON.stringify(S)); prog(); };
function prog(){ const d = DATA.filter(s => S[s.name] && S[s.name].best).length;
  document.getElementById('prog').innerHTML = `<span class="${d==DATA.length?'done':''}">${d} / ${DATA.length} picked</span>`; }
let cur = null;
function draw(cv, pk, frac){ const r = cv.getBoundingClientRect(); cv.width = r.width*devicePixelRatio; cv.height = r.height*devicePixelRatio;
  const g = cv.getContext('2d'), w = cv.width, h = cv.height, m = h/2, k = 0.95 / Math.max(1e-3, ...pk.map(p => Math.max(-p[0], p[1])));
  g.fillStyle = '#0b0b0b'; g.fillRect(0,0,w,h); g.strokeStyle = '#333'; g.beginPath(); g.moveTo(0,m); g.lineTo(w,m); g.stroke();
  for (let i = 0; i < pk.length; i++){ const x = i/pk.length*w, played = frac != null && i/pk.length <= frac;
    g.fillStyle = played ? '#6cf' : '#4a8'; const y0 = m - pk[i][1]*k*m, y1 = m - pk[i][0]*k*m; g.fillRect(x, y0, Math.max(1, w/pk.length), Math.max(1, y1-y0)); }
  if (frac != null){ g.fillStyle = '#fff'; g.fillRect(frac*w, 0, 2, h); } }
function play(a, cv, pk, btn){ if (cur && cur.a !== a){ cur.a.pause(); cur.a.currentTime = 0; draw(cur.cv, cur.pk, null); cur.btn.textContent='▶'; }
  if (!a.paused){ a.pause(); a.currentTime = 0; draw(cv, pk, null); btn.textContent='▶'; cur = null; return; }
  cur = {a, cv, pk, btn}; a.play(); btn.textContent='■';
  const tick = () => { if (cur && cur.a === a && !a.paused){ draw(cv, pk, a.currentTime / a.duration); requestAnimationFrame(tick); } }; tick();
  a.onended = () => { draw(cv, pk, null); btn.textContent='▶'; if (cur && cur.a === a) cur = null; }; }
const L = document.getElementById('list');
for (const s of DATA){ const st = S[s.name] = S[s.name] || {best:'', notes:'', opt:{}, final:false};
  const c = document.createElement('div'); c.className = 'card';
  c.innerHTML = `<h2>${s.name}</h2><div class="meta">${s.cat} · plays as: ${s.ids}</div>`;
  for (const o of s.opts.concat([{key:'none', label:'None of these is good'}])){
    const row = document.createElement('div'); row.className = 'opt' + (st.best == o.key ? ' best' : '');
    const id = s.name + '_' + o.key;
    row.innerHTML = `<label><input type="radio" name="${s.name}" value="${o.key}" ${st.best==o.key?'checked':''}> <b>${o.key.toUpperCase()}</b> ${o.label}</label>`;
    const right = document.createElement('div');
    if (o.file){ const a = new Audio(o.file); a.preload = 'none'; const cv = document.createElement('canvas'), btn = document.createElement('button');
      btn.textContent = '▶'; btn.onclick = () => play(a, cv, o.peaks, btn); cv.onclick = btn.onclick;
      const top = document.createElement('div'); top.style.cssText = 'display:grid;grid-template-columns:40px 1fr 60px;gap:6px;align-items:center';
      const len = document.createElement('span'); len.style.color='#888'; len.textContent = o.sec.toFixed(2)+' s';
      top.append(btn, cv, len); right.append(top);
      const note = document.createElement('input'); note.className = 'note'; note.placeholder = "what's bad about " + o.key.toUpperCase() + ' (optional)';
      note.value = st.opt[o.key] || ''; note.oninput = () => { st.opt[o.key] = note.value; save(); }; right.append(note);
      requestAnimationFrame(() => draw(cv, o.peaks, null)); }
    row.append(right); c.append(row);
    row.querySelector('input').onchange = () => { st.best = o.key; c.querySelectorAll('.opt').forEach(r => r.classList.remove('best')); row.classList.add('best'); save(); };
  }
  const fin = document.createElement('label'); fin.innerHTML = `<input type="checkbox" ${st.final?'checked':''}> final: keep the pick, no more options`;
  fin.querySelector('input').onchange = e => { st.final = e.target.checked; save(); }; c.append(fin);
  const t = document.createElement('textarea'); t.placeholder = 'What to improve for this sound (applies to the pick)'; t.value = st.notes;
  t.oninput = () => { st.notes = t.value; save(); }; c.append(t); L.append(c); }
prog();
const out = () => JSON.stringify(DATA.map(s => ({round: ROUND, name: s.name, best: S[s.name].best, final: S[s.name].final,
  options: Object.fromEntries(s.opts.map(o => [o.key, o.label])), bad: S[s.name].opt, improve: S[s.name].notes})), null, 1);
function dl(){ const b = new Blob([out()], {type:'application/json'}); const a = document.createElement('a');
  a.href = URL.createObjectURL(b); a.download = 'picks.json'; a.click(); }
function cp(){ navigator.clipboard.writeText(out()); }
</script>
"""


def main():
    fetch()
    args = sys.argv[1:]
    rnd = int(args[args.index("--round") + 1]) if "--round" in args else 1
    want = next((a for a in args if not a.startswith("--") and not a.isdigit()), "")
    out = OUT if rnd == 1 else os.path.join(OUT, "r%d" % rnd)
    os.makedirs(out, exist_ok=True)
    alt = ALT if rnd == 1 else __import__("audition_r%d" % rnd).ALT
    data = []
    for name, cat, fn, ids, _loop in catalogue():
        cands = [("shipped", fn)] + ALT.get(name, []) if rnd == 1 else alt.get(name)
        if not cands:
            continue
        opts = []
        for key, (label, b) in zip("abc", cands):
            path = os.path.join(out, "%s_%s.wav" % (name, key))
            if want and want in name or not os.path.isfile(path):
                write(normalise(b(), CATEGORIES[cat][0]), path)
                print("%-40s %s" % (name, key), flush=True)
            x = read(path)
            opts.append({"key": key, "label": label, "file": os.path.basename(path), "sec": len(x) / SR, "peaks": peaks(x)})
        data.append({"name": name, "cat": cat, "ids": html.escape(", ".join(i[0] for i in ids)), "opts": opts})
    with open(os.path.join(out, "index.html"), "w", newline="\n", encoding="utf-8") as f:
        f.write(PAGE.replace("__DATA__", json.dumps(data)).replace("__ROUND__", str(rnd)))
    print("wrote", os.path.join(out, "index.html"))


if __name__ == "__main__":
    main()
