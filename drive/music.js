"use strict";

/*
 * SunsetMusic —— 程序化 synthwave 配乐(Web Audio 实时合成,无素材依赖)
 *
 * 适配规则:
 *  - mood 越高:BPM 越慢(105 → 75)、低通滤波越柔(约 4700Hz → 900Hz)、镲片越轻
 *  - 收集安详光点:「心率 -1」—— BPM 立即减 1(下限 72),并伴一声轻铃
 *  - 撞到焦虑碎片:低通瞬闭 + 音量下压(闷响),约 1.2 秒恢复
 */

const SunsetMusic = (() => {
  let ctx = null;
  let master = null, bus = null, filter = null;
  let running = false, muted = false;
  let volume = 0.55;
  let mood = 0;
  let bpm = 105;
  let step = 0;
  let nextTime = 0;
  let timer = null;
  let noiseBuf = null;

  const midiHz = (m) => 440 * Math.pow(2, (m - 69) / 12);

  // Am → F → C → G(A 小调 synthwave 进行),每和弦一小节(16 个十六分音符)
  const PROG = [
    { root: 45, third: 3, tones: [45, 48, 52] }, // Am
    { root: 41, third: 4, tones: [41, 45, 48] }, // F
    { root: 48, third: 4, tones: [48, 52, 55] }, // C
    { root: 43, third: 4, tones: [43, 47, 50] }, // G
  ];
  const ARP = [0, 12, 7, 12, 0, 7, 12, 7]; // 半音偏移(八分音符琶音)

  function ensureCtx() {
    if (ctx) return;
    ctx = new (window.AudioContext || window.webkitAudioContext)();
    master = ctx.createGain();
    master.gain.value = volume;
    master.connect(ctx.destination);
    filter = ctx.createBiquadFilter();
    filter.type = "lowpass";
    filter.frequency.value = 900 + (1 - mood) * 3800;
    filter.Q.value = 0.8;
    filter.connect(master);
    bus = ctx.createGain();
    bus.gain.value = 1;
    bus.connect(filter);
    // 白噪缓冲(hihat 用)
    noiseBuf = ctx.createBuffer(1, ctx.sampleRate * 0.1, ctx.sampleRate);
    const d = noiseBuf.getChannelData(0);
    for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
  }

  function env(g, t, a, peak, dec) {
    g.gain.setValueAtTime(0.0001, t);
    g.gain.linearRampToValueAtTime(peak, t + a);
    g.gain.exponentialRampToValueAtTime(0.0001, t + a + dec);
  }

  function playBass(t, midi) {
    const o = ctx.createOscillator();
    o.type = "sawtooth";
    o.frequency.value = midiHz(midi - 12);
    const f = ctx.createBiquadFilter();
    f.type = "lowpass";
    f.frequency.value = 700;
    const g = ctx.createGain();
    env(g, t, 0.005, 0.30, 0.20);
    o.connect(f); f.connect(g); g.connect(bus);
    o.start(t); o.stop(t + 0.26);
  }

  function playPad(t, tones, dur) {
    for (const m of tones) {
      for (const det of [-4, 4]) {
        const o = ctx.createOscillator();
        o.type = "triangle";
        o.frequency.value = midiHz(m + 12);
        o.detune.value = det;
        const g = ctx.createGain();
        g.gain.setValueAtTime(0.0001, t);
        g.gain.linearRampToValueAtTime(0.045, t + dur * 0.35);
        g.gain.linearRampToValueAtTime(0.0001, t + dur);
        o.connect(g); g.connect(bus);
        o.start(t); o.stop(t + dur + 0.05);
      }
    }
  }

  function playKick(t) {
    const o = ctx.createOscillator();
    o.type = "sine";
    o.frequency.setValueAtTime(150, t);
    o.frequency.exponentialRampToValueAtTime(42, t + 0.16);
    const g = ctx.createGain();
    env(g, t, 0.002, 0.55, 0.20);
    o.connect(g); g.connect(bus);
    o.start(t); o.stop(t + 0.24);
  }

  function playHat(t, loud) {
    const s = ctx.createBufferSource();
    s.buffer = noiseBuf;
    const f = ctx.createBiquadFilter();
    f.type = "highpass";
    f.frequency.value = 6500;
    const g = ctx.createGain();
    env(g, t, 0.001, loud ? 0.10 : 0.05, 0.035);
    s.connect(f); f.connect(g); g.connect(bus);
    s.start(t); s.stop(t + 0.06);
  }

  function playBell(t) {
    const o = ctx.createOscillator();
    o.type = "sine";
    o.frequency.value = midiHz(81); // A5
    const g = ctx.createGain();
    env(g, t, 0.005, 0.16, 0.9);
    o.connect(g); g.connect(bus);
    o.start(t); o.stop(t + 1.0);
  }

  // 前瞻调度器
  function scheduler() {
    if (!running) return;
    const ahead = 0.16;
    while (nextTime < ctx.currentTime + ahead) {
      const stepDur = 60 / bpm / 4;
      const bar = Math.floor(step / 16) % PROG.length;
      const chord = PROG[bar];
      const s16 = step % 16;
      if (s16 % 4 === 0) playKick(nextTime);
      if (s16 % 4 === 2) playHat(nextTime, false);
      if (s16 % 2 === 0) playBass(nextTime, chord.root + ARP[(s16 / 2) % 8]);
      if (s16 === 0) playPad(nextTime, chord.tones, stepDur * 16);
      if (s16 === 14 && mood > 0.5) playHat(nextTime + stepDur / 2, true);
      nextTime += stepDur;
      step++;
    }
  }

  function start() {
    if (running || muted) return;
    ensureCtx();
    if (ctx.state === "suspended") ctx.resume();
    running = true;
    nextTime = ctx.currentTime + 0.1;
    timer = setInterval(scheduler, 25);
  }

  return {
    start,
    setMood(m) { mood = Math.max(0, Math.min(1, m)); },
    getBpm: () => Math.round(bpm),
    onCollect() { // 心率 -1
      bpm = Math.max(72, bpm - 1);
      if (ctx && running) playBell(ctx.currentTime + 0.02);
    },
    onCrash() { // 闷响 + 压音量
      if (!ctx) return;
      const t = ctx.currentTime;
      filter.frequency.cancelScheduledValues(t);
      filter.frequency.setTargetAtTime(160, t, 0.03);
      filter.frequency.setTargetAtTime(900 + (1 - mood) * 3800, t + 0.45, 0.35);
      master.gain.setTargetAtTime(volume * 0.35, t, 0.03);
      master.gain.setTargetAtTime(volume, t + 0.5, 0.4);
    },
    setVolume(v) { volume = Math.max(0, Math.min(1, v)); if (master) master.gain.value = volume; },
    setMuted(m) { muted = m; if (m) { if (timer) { clearInterval(timer); timer = null; } running = false; } else start(); },
    status: () => ({ bpm: Math.round(bpm), running, mood: +mood.toFixed(2) }),
  };
})();

window.SunsetMusic = SunsetMusic;
