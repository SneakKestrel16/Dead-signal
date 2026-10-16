"""The review page and the listening sheet (pipeline-handoff.md Part 9).

One self-contained index.html per family: every option of a sound (the old take "before", then candidates A, B,
C) is embedded as WAV, played in sync through Web Audio (switching compares the same moment), dry or through a
synthetic corridor (generated in the page), with a log-frequency spectrogram (30 Hz-20 kHz) drawn in the
browser. The listener marks one option, notes what is bad in each, what to improve, and a final box; "Export
picks.json" downloads the verdicts. Static spectrogram PNGs of every option are also written to media/ so a
session that cannot listen can still look (a horizontal line outliving the rest is a note, a vertical one a click).
"""
import base64
import json
import struct
import zlib
from pathlib import Path

import numpy as np
from scipy import signal

from lib import dsp, master


def spectrogram_rows(x, rows=140, cols=700):
    """dB spectrogram on a log-frequency axis (30 Hz-20 kHz), shape (rows, cols), 0 = loudest cell."""
    nper = 2048
    x = np.pad(x, (0, max(0, nper + 1 - len(x))))
    hop = max(1, (len(x) - nper) // cols)
    f, t, s = signal.spectrogram(x, dsp.SR, nperseg=nper, noverlap=nper - hop, mode="magnitude")
    edges = 30.0 * (20000.0 / 30.0) ** (np.arange(rows + 1) / rows)
    out = np.zeros((rows, s.shape[1]))
    for r in range(rows):
        sel = (f >= edges[r]) & (f < edges[r + 1])
        if not sel.any():
            sel = np.argmin(np.abs(f - np.sqrt(edges[r] * edges[r + 1])))
        out[r] = s[sel].max(axis=0) if np.ndim(sel) else s[sel]
    db = 20 * np.log10(out + 1e-9)
    return (db - db.max())[::-1]  # low frequencies at the bottom


def write_png(path, rgb):
    h, w, _ = rgb.shape
    raw = b"".join(b"\x00" + rgb[y].tobytes() for y in range(h))

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data))

    Path(path).write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
                           + chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b""))


def heat(db, floor=-90.0):
    v = np.clip((db - floor) / -floor, 0, 1)
    return np.stack([255 * np.clip(3 * v - 1, 0, 1), 255 * np.clip(3 * v - 0.2, 0, 1) * v, 255 * (1 - np.abs(2 * v - 0.6))], -1).astype(np.uint8)


def contact_sheet(path, labelled):
    """One PNG with a spectrogram per option, stacked (labels live in the file name list printed by the caller)."""
    imgs = [heat(sp[:, np.linspace(0, sp.shape[1] - 1, 500).astype(int)]) for sp in (spectrogram_rows(x, 100, 500) for _, x in labelled)]
    gap = np.full((4, 500, 3), 255, np.uint8)
    write_png(path, np.concatenate([a for im in imgs for a in (im, gap)], axis=0))


def wav_b64(x, loop):
    return base64.b64encode(master.wav_bytes(x, loop)).decode()


def build(out, items, title, picks_name="picks.json"):
    """items: [{name, doc, plays, loop, options: [(label, float array)]}]."""
    out = Path(out)
    media = out / "media"
    media.mkdir(parents=True, exist_ok=True)
    data = []
    for it in items:
        contact_sheet(media / f"{it['name']}_spectrograms.png", it["options"])
        data.append({**{k: it[k] for k in ("name", "doc", "plays", "loop")},
                     "options": [{"label": lab, "wav": wav_b64(x, it["loop"]),
                                  "lufs": round(master.loudness(x), 1), "peak": round(float(20 * np.log10(np.max(np.abs(x)) + 1e-12)), 1),
                                  "sec": round(len(x) / dsp.SR, 2)} for lab, x in it["options"]]})
    html = PAGE.replace("__TITLE__", title).replace("__PICKS__", picks_name).replace("__DATA__", json.dumps(data))
    (out / "index.html").write_text(html, encoding="utf-8", newline="\n")
    return out / "index.html"


def sheet(out, takes):
    """The listening sheet: every take once, with its docstring (export.py --sheet)."""
    items = [{"name": t.sound.name, "doc": (getattr(t.sound.build, "func", t.sound.build).__doc__ or t.sound.family), "plays": "", "loop": t.sound.loop,
              "options": [("take", t.x)]} for t in takes]
    print("sheet:", build(out, items, "Listening sheet", "sheet.json"))


PAGE = r"""<!doctype html><meta charset="utf-8"><title>__TITLE__</title>
<style>
body{font:14px system-ui;background:#15171a;color:#d8dadd;margin:0 auto;max-width:1100px;padding:12px}
h1{font-size:18px}.snd{border:1px solid #333;border-radius:6px;padding:10px;margin:14px 0;background:#1b1e22}
.snd h2{margin:0 0 4px;font-size:16px}.plays{color:#e0b060;margin:2px 0 8px}.doc{color:#8a9096;font-size:12px;margin-bottom:6px}
.opts{display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:8px}.opt{border:2px solid #333;border-radius:4px;padding:6px}
.opt.on{border-color:#4aa3ff}.opt.pick{background:#1d2b1d}canvas{width:100%;height:90px;background:#000;display:block}
textarea{width:100%;box-sizing:border-box;height:46px;background:#101215;color:#d8dadd;border:1px solid #333}
button{background:#2a3038;color:#d8dadd;border:1px solid #444;border-radius:4px;padding:4px 10px;cursor:pointer}
.meta{font-size:11px;color:#8a9096}.bar{margin:6px 0}
</style>
<h1>__TITLE__</h1>
<div class="meta">Play starts all options in sync; click an option (or its Hear button) to switch to it at the same moment. Dry or
corridor preview applies to all. Mark one option, note what is bad, then Export. Verdicts are kept in this browser.</div>
<div class="bar"><button id="export">Export __PICKS__</button> <label><input type="radio" name="room" value="dry" checked> dry</label>
<label><input type="radio" name="room" value="corridor"> corridor</label></div>
<div id="root"></div>
<script>
const DATA=__DATA__;const KEY="audio_review_"+document.title;
const ctx=new (window.AudioContext||window.webkitAudioContext)({sampleRate:44100});
const verdict=JSON.parse(localStorage.getItem(KEY)||"{}");const save=()=>localStorage.setItem(KEY,JSON.stringify(verdict));
// corridor: early reflections plus a 1.3 s decay, highs dying sooner (preview only)
function corridorIR(){const n=Math.floor(ctx.sampleRate*1.6),b=ctx.createBuffer(1,n,ctx.sampleRate),d=b.getChannelData(0);let lp=0,seed=12345;
 const rnd=()=>{seed=(seed*1664525+1013904223)>>>0;return seed/2147483648-1};
 for(let i=0;i<n;i++){const t=i/ctx.sampleRate;const k=Math.exp(-t/0.19);const a=0.15+0.85*Math.exp(-t/0.4);lp+=a*(rnd()-lp);d[i]=lp*k*0.6}
 [[0.006,.7],[0.011,.5],[0.019,.4],[0.031,.3]].forEach(([t,g])=>d[Math.floor(t*ctx.sampleRate)]+=g);return b}
const IR=corridorIR();
function fft(re,im){const n=re.length;for(let i=1,j=0;i<n;i++){let bit=n>>1;for(;j&bit;bit>>=1)j^=bit;j^=bit;if(i<j){[re[i],re[j]]=[re[j],re[i]];[im[i],im[j]]=[im[j],im[i]]}}
 for(let len=2;len<=n;len<<=1){const ang=-2*Math.PI/len,wr=Math.cos(ang),wi=Math.sin(ang);for(let i=0;i<n;i+=len){let cr=1,ci=0;for(let k=0;k<len/2;k++){
 const ur=re[i+k],ui=im[i+k],vr=re[i+k+len/2]*cr-im[i+k+len/2]*ci,vi=re[i+k+len/2]*ci+im[i+k+len/2]*cr;re[i+k]=ur+vr;im[i+k]=ui+vi;re[i+k+len/2]=ur-vr;im[i+k+len/2]=ui-vi;
 const t=cr*wr-ci*wi;ci=cr*wi+ci*wr;cr=t}}}}
function drawSpec(canvas,buf){const W=canvas.width=700,H=canvas.height=140,N=2048,x=buf.getChannelData(0),sr=buf.sampleRate;
 const hop=Math.max(1,Math.floor((x.length-N)/W)),g=canvas.getContext("2d"),img=g.createImageData(W,H);const win=new Float32Array(N).map((_,i)=>0.5-0.5*Math.cos(2*Math.PI*i/N));
 const cols=[];let mx=-1e9;for(let c=0;c<W;c++){const re=new Float32Array(N),im=new Float32Array(N);for(let i=0;i<N;i++)re[i]=(x[c*hop+i]||0)*win[i];fft(re,im);
  const row=new Float32Array(H);for(let r=0;r<H;r++){const f0=30*Math.pow(20000/30,r/H),f1=30*Math.pow(20000/30,(r+1)/H);let b0=Math.floor(f0*N/sr),b1=Math.max(b0+1,Math.ceil(f1*N/sr)),m=0;
   for(let b=b0;b<b1&&b<N/2;b++)m=Math.max(m,Math.hypot(re[b],im[b]));const db=20*Math.log10(m+1e-9);row[r]=db;if(db>mx)mx=db}cols.push(row)}
 for(let c=0;c<W;c++)for(let r=0;r<H;r++){const v=Math.min(1,Math.max(0,(cols[c][r]-mx+90)/90)),p=((H-1-r)*W+c)*4;
  img.data[p]=255*Math.min(1,Math.max(0,3*v-1));img.data[p+1]=255*Math.min(1,Math.max(0,3*v-.2))*v;img.data[p+2]=255*(1-Math.abs(2*v-.6));img.data[p+3]=255}g.putImageData(img,0,0)}
const b64=s=>{const bin=atob(s),u=new Uint8Array(bin.length);for(let i=0;i<bin.length;i++)u[i]=bin.charCodeAt(i);return u.buffer};
const root=document.getElementById("root");let playing=null;
DATA.forEach(s=>{const v=verdict[s.name]=verdict[s.name]||{pick:"",bad:{},improve:"",final:""};const el=document.createElement("div");el.className="snd";
 el.innerHTML=`<h2>${s.name}</h2><div class="plays">${s.plays||""}</div><div class="doc">${s.doc}</div><div class="bar"><button class="play">Play / stop</button> <span class="meta">${s.loop?"loops":"one-shot, retriggers on Play"}</span></div><div class="opts"></div>
 <div class="bar">Improve: <textarea class="imp"></textarea> Final: <textarea class="fin" placeholder="the name you want shipped, or a description"></textarea></div>`;
 const opts=el.querySelector(".opts");s.runtime={sel:0,nodes:[]};
 s.options.forEach((o,i)=>{const d=document.createElement("div");d.className="opt";
  d.innerHTML=`<b>${o.label}</b> <span class="meta">${o.lufs} LUFS, peak ${o.peak} dBFS, ${o.sec} s</span><canvas></canvas>
  <label><input type="radio" name="pick_${s.name}"> pick</label> <button class="hear">Hear</button><textarea placeholder="what's bad"></textarea>`;
  const rad=d.querySelector("input"),bad=d.querySelector("textarea");rad.checked=v.pick===o.label;bad.value=v.bad[o.label]||"";
  rad.onchange=()=>{v.pick=o.label;save();el.querySelectorAll(".opt").forEach((e,j)=>e.classList.toggle("pick",j===i))};
  bad.oninput=()=>{v.bad[o.label]=bad.value;save()};d.querySelector(".hear").onclick=()=>select(s,i,el);d.onclick=e=>{if(e.target.tagName==="CANVAS")select(s,i,el)};
  d.classList.toggle("pick",v.pick===o.label);opts.appendChild(d);
  ctx.decodeAudioData(b64(o.wav)).then(buf=>{o.buf=buf;drawSpec(d.querySelector("canvas"),buf)})});
 const imp=el.querySelector(".imp"),fin=el.querySelector(".fin");imp.value=v.improve;fin.value=v.final;imp.oninput=()=>{v.improve=imp.value;save()};fin.oninput=()=>{v.final=fin.value;save()};
 el.querySelector(".play").onclick=()=>toggle(s,el);root.appendChild(el)});
function room(){return document.querySelector('input[name=room]:checked').value}
function stop(s){if(s.runtime.nodes.length){s.runtime.nodes.forEach(n=>{try{n.src.stop()}catch(e){}});s.runtime.nodes=[]}if(playing===s)playing=null}
function toggle(s,el){ctx.resume();if(s.runtime.nodes.length){stop(s);return}if(playing)stop(playing);playing=s;
 const dry=ctx.createGain(),wet=ctx.createGain(),conv=ctx.createConvolver();conv.buffer=IR;dry.connect(ctx.destination);conv.connect(wet);wet.connect(ctx.destination);
 const t0=ctx.currentTime+0.05;s.runtime.t0=t0;s.runtime.dry=dry;s.runtime.wet=wet;
 s.options.forEach((o,i)=>{if(!o.buf)return;const src=ctx.createBufferSource();src.buffer=o.buf;src.loop=s.loop;const g=ctx.createGain();g.gain.value=i===s.runtime.sel?1:0;src.connect(g);g.connect(dry);g.connect(conv);src.start(t0);s.runtime.nodes.push({src,g,i})});
 applyRoom(s);if(!s.loop)setTimeout(()=>stop(s),(s.options[0].sec+1.5)*1000)}
function applyRoom(s){if(!s.runtime.dry)return;const c=room()==="corridor";s.runtime.dry.gain.value=c?0.35:1;s.runtime.wet.gain.value=c?1:0}
document.querySelectorAll("input[name=room]").forEach(r=>r.onchange=()=>DATA.forEach(applyRoom));
function select(s,i,el){s.runtime.sel=i;el.querySelectorAll(".opt").forEach((e,j)=>e.classList.toggle("on",j===i));s.runtime.nodes.forEach(n=>n.g.gain.setTargetAtTime(n.i===i?1:0,ctx.currentTime,0.01))}
document.getElementById("export").onclick=()=>{const a=document.createElement("a");a.href=URL.createObjectURL(new Blob([JSON.stringify(verdict,null,1)],{type:"application/json"}));a.download="__PICKS__";a.click()};
</script>"""
