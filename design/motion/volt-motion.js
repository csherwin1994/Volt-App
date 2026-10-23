/* Volt Motion: line-drawn exercise animations in the Nordic Precision style.
 *
 * One figure, posed by keyframes from design/movements.json, solved with 2-link IK
 * and drawn as SVG strokes: graphite body, gold working segments, dashed gold implement path.
 * The SwiftUI port (Volt/Components/MovementView.swift) follows the same rules, so a
 * movement looks the same on the web prototype and on the phone.
 *
 * World units are metres. y is up, the floor is y = 0, the figure faces +x.
 * Limb angles are degrees from straight down, positive towards +x.
 * Torso and head angles are degrees from straight up, positive towards +x.
 */
const VoltMotion = (() => {
  const L = { shin: 0.44, thigh: 0.44, torso: 0.5, neck: 0.07, head: 0.095, upper: 0.3, fore: 0.28, foot: 0.15, shoulderHalf: 0.17, hipHalf: 0.1 };
  const rad = d => d * Math.PI / 180;
  const add = (a, b) => [a[0] + b[0], a[1] + b[1]];
  const sub = (a, b) => [a[0] - b[0], a[1] - b[1]];
  const limb = (len, deg) => [Math.sin(rad(deg)) * len, -Math.cos(rad(deg)) * len];
  const up = (len, deg) => [Math.sin(rad(deg)) * len, Math.cos(rad(deg)) * len];
  const lerp = (a, b, t) => a + (b - a) * t;
  const ease = t => 0.5 - Math.cos(Math.PI * t) / 2;

  function lerpSpec(a, b, t) {
    if (typeof a === 'number' && typeof b === 'number') return lerp(a, b, t);
    if (Array.isArray(a) && Array.isArray(b)) return a.map((v, i) => lerpSpec(v, b[i], t));
    if (a && typeof a === 'object' && b && typeof b === 'object') {
      const o = {};
      for (const k of Object.keys(a)) o[k] = k in b ? lerpSpec(a[k], b[k], t) : a[k];
      return o;
    }
    return t < 0.5 ? a : b;
  }

  // Two-link IK. bend > 0 puts the middle joint counter-clockwise of the root→target line.
  function ik(root, target, a, b, bend) {
    const d0 = sub(target, root);
    let d = Math.hypot(d0[0], d0[1]);
    d = Math.max(Math.abs(a - b) + 1e-4, Math.min(a + b - 1e-4, d));
    const base = Math.atan2(d0[1], d0[0]);
    const A = Math.acos(Math.max(-1, Math.min(1, (a * a + d * d - b * b) / (2 * a * d))));
    const ang = base + (bend >= 0 ? A : -A);
    const joint = add(root, [Math.cos(ang) * a, Math.sin(ang) * a]);
    const dir = Math.atan2(target[1] - joint[1], target[0] - joint[0]);
    return [joint, add(joint, [Math.cos(dir) * b, Math.sin(dir) * b])];
  }

  // Solve one pose into joint positions.
  function solve(p, view) {
    const front = view === 'front';
    const hip = p.hip;
    const tilt = p.torso || 0;
    const sh = add(add(hip, up(L.torso, tilt)), [0, p.shrug || 0]);
    const neck = add(sh, up(L.neck, tilt + (p.head || 0) * 0.4));
    const head = add(neck, up(L.head, tilt + (p.head || 0)));
    const pts = { hip, shoulder: sh, neck, head };
    const ref = spec => {
      if (Array.isArray(spec)) return spec;
      const base = pts[spec.from] || [0, 0];
      return add(base, spec.d || [0, 0]);
    };

    const solveLeg = (spec, hipPt) => {
      let knee, ankle;
      if (spec.foot) [knee, ankle] = ik(hipPt, ref(spec.foot), L.thigh, L.shin, spec.bend ?? 1);
      else { knee = add(hipPt, limb(L.thigh, spec.thigh)); ankle = add(knee, limb(L.shin, spec.shin)); }
      let toe;
      if (spec.toe !== undefined) toe = add(ankle, limb(L.foot, spec.toe));
      else if (!front && ankle[1] < L.foot) toe = [ankle[0] + Math.sqrt(L.foot * L.foot - ankle[1] * ankle[1]), 0];
      else if (front) toe = add(ankle, [0, -0.02]);
      else {
        const shinDeg = Math.atan2(ankle[0] - knee[0], -(ankle[1] - knee[1])) * 180 / Math.PI;
        toe = add(ankle, limb(L.foot, shinDeg + 95));
      }
      return { hip: hipPt, knee, ankle, toe };
    };
    const solveArm = (spec, shPt) => {
      let elbow, hand;
      if (spec.hand) [elbow, hand] = ik(shPt, ref(spec.hand), L.upper, L.fore, spec.bend ?? -1);
      else { elbow = add(shPt, limb(L.upper, spec.upper)); hand = add(elbow, limb(L.fore, spec.fore)); }
      return { shoulder: shPt, elbow, hand };
    };

    if (front) {
      // Front view: the near limbs are the figure's left (screen right, +x); far limbs mirror unless given.
      const shR = add(sh, [L.shoulderHalf, -0.03]), shL = add(sh, [-L.shoulderHalf, -0.03]);
      const hipR = add(hip, [L.hipHalf, 0]), hipL = add(hip, [-L.hipHalf, 0]);
      const mirror = s => s && JSON.parse(JSON.stringify(s), (k, v) => (k === 'upper' || k === 'fore' || k === 'thigh' || k === 'shin' || k === 'toe') && typeof v === 'number' ? -v : k === 'bend' ? -v : v);
      const mirrorTarget = s => {
        if (!s) return s;
        const o = JSON.parse(JSON.stringify(s));
        for (const key of ['hand', 'foot']) {
          if (!o[key]) continue;
          if (Array.isArray(o[key])) o[key] = [-o[key][0], o[key][1]];
          else o[key].d = [-(o[key].d || [0, 0])[0], (o[key].d || [0, 0])[1]];
        }
        return o;
      };
      const legFarSpec = p.legFar || mirrorTarget(mirror(p.leg));
      const armFarSpec = p.armFar || mirrorTarget(mirror(p.arm));
      // Targets relative to "shoulder"/"hip" use the matching side.
      pts.shoulder = shR; pts.hip = hipR;
      const leg = solveLeg(p.leg, hipR), arm = solveArm(p.arm, shR);
      pts.shoulder = shL; pts.hip = hipL;
      const legFar = solveLeg(legFarSpec, hipL), armFar = solveArm(armFarSpec, shL);
      pts.shoulder = sh; pts.hip = hip;
      return { view, hip, shoulder: sh, neck, head, shR, shL, hipR, hipL, leg, legFar, arm, armFar };
    }
    const leg = solveLeg(p.leg, hip);
    const legFar = solveLeg(p.legFar || p.leg, hip);
    const arm = solveArm(p.arm, sh);
    const armFar = solveArm(p.armFar || p.arm, sh);
    return { view, hip, shoulder: sh, neck, head, leg, legFar, arm, armFar };
  }

  function pointOf(j, at) {
    if (!at || at === 'hand') return j.arm.hand;
    if (at === 'ankle') return j.leg.ankle;
    if (Array.isArray(at)) return at;
    const base = { hip: j.hip, shoulder: j.shoulder, neck: j.neck, head: j.head, hand: j.arm.hand, ankle: j.leg.ankle }[at.from] || [0, 0];
    return add(base, at.d || [0, 0]);
  }

  // Build the timeline from a pattern: [{from, to, dur, label}] segments.
  function timeline(pat) {
    const seq = pat.seq || [
      { to: 1, dur: 2, label: (pat.phases || [])[0] || 'Lower' },
      { hold: 0.4 },
      { to: 0, dur: 1.1, label: (pat.phases || [])[1] || 'Return' },
      { hold: 0.6 }
    ];
    const segs = []; let cur = 0, t = 0;
    for (const s of seq) {
      if (s.hold !== undefined) { segs.push({ from: cur, to: cur, t0: t, dur: s.hold, label: segs.length ? segs[segs.length - 1].label : '' }); t += s.hold; }
      else { segs.push({ from: cur, to: s.to, t0: t, dur: s.dur, label: s.label || '', linear: s.linear }); t += s.dur; cur = s.to; }
    }
    return { segs, total: t };
  }

  function poseAt(pat, tl, time) {
    const tt = ((time % tl.total) + tl.total) % tl.total;
    const seg = tl.segs.find(s => tt >= s.t0 && tt < s.t0 + s.dur) || tl.segs[tl.segs.length - 1];
    const u = seg.dur ? (tt - seg.t0) / seg.dur : 1;
    const e = seg.linear ? u : ease(u);
    return { pose: lerpSpec(pat.keys[seg.from], pat.keys[seg.to], e), label: seg.label, u: tt / tl.total };
  }

  // Resolve an exercise name to a pattern + equipment, using explicit names first, then keyword rules.
  function resolve(lib, name) {
    let entry = lib.exercises[name];
    if (!entry) {
      const n = name.toLowerCase();
      const rule = lib.rules.find(r => r.any.some(k => n.includes(k)) && !(r.not || []).some(k => n.includes(k)));
      if (rule) entry = { pattern: rule.pattern };
      if (entry) {
        if (n.includes('dumbbell')) entry.equipment = 'dumbbell';
        else if (n.includes('kettlebell')) entry.equipment = 'kettlebell';
        else if (n.includes('cable')) entry.equipment = entry.equipment || undefined;
      }
    }
    if (!entry || !lib.patterns[entry.pattern]) return null;
    const pat = JSON.parse(JSON.stringify(lib.patterns[entry.pattern]));
    if (entry.equipment && pat.equipment && pat.equipment.length) pat.equipment[0].type = entry.equipment;
    if (entry.equipment === 'none') pat.equipment = [];
    pat.name = name; pat.patternName = entry.pattern;
    return pat;
  }

  // ---------- SVG rendering ----------
  const NS = 'http://www.w3.org/2000/svg';
  const el = (tag, attrs, parent) => {
    const n = document.createElementNS(NS, tag);
    for (const k in attrs) n.setAttribute(k, attrs[k]);
    if (parent) parent.appendChild(n);
    return n;
  };
  const P = p => `${p[0].toFixed(4)},${(-p[1]).toFixed(4)}`;

  function bounds(pat, tl) {
    let x0 = Infinity, x1 = -Infinity, y0 = Infinity, y1 = -Infinity;
    const eat = p => { x0 = Math.min(x0, p[0]); x1 = Math.max(x1, p[0]); y0 = Math.min(y0, p[1]); y1 = Math.max(y1, p[1]); };
    for (let i = 0; i <= 40; i++) {
      const j = solve(poseAt(pat, tl, tl.total * i / 40).pose, pat.view);
      [j.head, j.neck, j.hip, j.leg.knee, j.leg.ankle, j.leg.toe, j.legFar.ankle, j.legFar.toe, j.arm.elbow, j.arm.hand, j.armFar.hand].forEach(eat);
      eat(add(j.head, [L.head, L.head])); eat(add(j.head, [-L.head, -L.head]));
      for (const q of pat.equipment || []) { const c = pointOf(j, q.at); const r = q.type === 'barbell' && pat.view !== 'front' ? 0.22 : 0.12; eat(add(c, [r, r])); eat(add(c, [-r, -r])); if (q.from) eat(q.from); }
    }
    for (const pr of pat.props || []) (pr.pts || []).forEach(eat);
    if (pat.floor !== false) eat([x0, 0]);
    return { x0, x1, y0, y1 };
  }

  function mount(container, pat, opts = {}) {
    const tl = timeline(pat);
    const b = bounds(pat, tl);
    const aspect = opts.aspect || 1.5, pad = 0.14;
    let w = b.x1 - b.x0 + pad * 2, h = b.y1 - b.y0 + pad * 2;
    if (w / h > aspect) h = w / aspect; else w = h * aspect;
    const cx = (b.x0 + b.x1) / 2, cy = (b.y0 + b.y1) / 2;
    const vb = [cx - w / 2, -(cy + h / 2), w, h];
    const sw = w * (opts.stroke || 0.0098);
    const svg = el('svg', { viewBox: vb.map(v => v.toFixed(3)).join(' '), class: 'vm', role: 'img', 'aria-label': `${pat.name || 'Exercise'} animation` });
    svg.style.cssText = 'display:block;width:100%;height:100%';
    const g = {
      props: el('g', {}, svg), trace: el('g', {}, svg), far: el('g', { 'stroke-linecap': 'round', 'stroke-linejoin': 'round', fill: 'none' }, svg),
      equipBack: el('g', {}, svg), body: el('g', { 'stroke-linecap': 'round', 'stroke-linejoin': 'round', fill: 'none' }, svg), equip: el('g', {}, svg)
    };
    // Floor and props (static)
    if (pat.floor !== false) el('line', { x1: vb[0], x2: vb[0] + vb[2], y1: 0, y2: 0, stroke: 'var(--label)', 'stroke-width': sw * 0.35 }, g.props);
    for (const pr of pat.props || []) {
      if (pr.type === 'block') el('polygon', { points: pr.pts.map(P).join(' '), fill: 'var(--fill)', stroke: 'var(--line)', 'stroke-width': sw * 0.3 }, g.props);
      else if (pr.type === 'line') el('polyline', { points: pr.pts.map(P).join(' '), fill: 'none', stroke: 'var(--ink-3)', 'stroke-width': sw * 0.5, 'stroke-linecap': 'square' }, g.props);
      else if (pr.type === 'circle') el('circle', { cx: pr.pts[0][0], cy: -pr.pts[0][1], r: pr.r || 0.15, fill: 'none', stroke: 'var(--line)', 'stroke-width': sw * 0.5 }, g.props);
      else if (pr.type === 'bar') { el('line', { x1: pr.pts[0][0] - 0.12, x2: pr.pts[0][0] + 0.12, y1: -pr.pts[0][1], y2: -pr.pts[0][1], stroke: 'var(--ink-3)', 'stroke-width': sw * 0.5 }, g.props); el('circle', { cx: pr.pts[0][0], cy: -pr.pts[0][1], r: sw * 0.9, fill: 'var(--label)' }, g.props); }
    }
    // Implement path, sampled once
    const tracked = (pat.equipment || []).find(q => q.trace !== false) || (pat.trace ? { at: pat.trace } : null);
    if (tracked && pat.showTrace !== false) {
      const path = [];
      for (let i = 0; i <= 80; i++) path.push(pointOf(solve(poseAt(pat, tl, tl.total * i / 80).pose, pat.view), tracked.at));
      el('polyline', { points: path.map(P).join(' '), fill: 'none', stroke: 'var(--accent)', 'stroke-width': sw * 0.45, 'stroke-dasharray': `${sw * 1.2} ${sw * 1.6}`, opacity: 0.85 }, g.trace);
    }
    const work = new Set(pat.work || []);
    const stroke = (parent, a, bb, color, width) => el('line', { x1: a[0], y1: -a[1], x2: bb[0], y2: -bb[1], stroke: color, 'stroke-width': width }, parent);

    function draw(j) {
      for (const k of ['far', 'body', 'equip', 'equipBack']) g[k].textContent = '';
      const ink = 'var(--label)', far = 'var(--ink-3)', gold = 'var(--accent)';
      const segColor = (name, near) => (near && work.has(name) ? gold : near ? ink : far);
      const drawLeg = (lg, near, parent) => {
        stroke(parent, lg.hip, lg.knee, segColor('thigh', near), sw);
        stroke(parent, lg.knee, lg.ankle, segColor('shin', near), sw);
        stroke(parent, lg.ankle, lg.toe, near ? ink : far, sw);
      };
      const drawArm = (am, near, parent) => {
        stroke(parent, am.shoulder, am.elbow, segColor('upper', near), sw);
        stroke(parent, am.elbow, am.hand, segColor('fore', near), sw);
      };
      if (j.view === 'front') {
        drawLeg(j.legFar, true, g.body); drawLeg(j.leg, true, g.body);
        stroke(g.body, j.hipL, j.hipR, ink, sw);
        stroke(g.body, j.shL, j.shR, segColor('chest', true), sw);
        stroke(g.body, j.hip, j.shoulder, segColor('torso', true), sw);
        drawArm(j.armFar, true, g.body); drawArm(j.arm, true, g.body);
      } else {
        drawLeg(j.legFar, false, g.far); drawArm(j.armFar, false, g.far);
        drawLeg(j.leg, true, g.body);
        stroke(g.body, j.hip, j.shoulder, segColor('torso', true), sw * 1.15);
        drawArm(j.arm, true, g.body);
      }
      stroke(g.body, j.shoulder, j.neck, ink, sw);
      el('circle', { cx: j.head[0], cy: -j.head[1], r: L.head, fill: 'var(--bg)', stroke: ink, 'stroke-width': sw }, g.body);
      if (work.has('hip')) el('circle', { cx: j.hip[0], cy: -j.hip[1], r: sw * 1.6, fill: gold }, g.body);
      if (work.has('shoulder')) el('circle', { cx: j.shoulder[0], cy: -j.shoulder[1], r: sw * 1.6, fill: gold }, g.body);
      if (work.has('calf')) stroke(g.body, j.leg.knee, j.leg.ankle, gold, sw);

      for (const q of pat.equipment || []) {
        const c = pointOf(j, q.at);
        const hands = j.view === 'front' && (!q.at || q.at === 'hand') ? [j.arm.hand, j.armFar.hand] : [c];
        if (q.type === 'cable' || q.from) {
          for (const hnd of hands) {
            const from = j.view === 'front' && hnd === j.armFar.hand && q.from ? [-q.from[0], q.from[1]] : q.from;
            if (!from) continue;
            el('line', { x1: from[0], y1: -from[1], x2: hnd[0], y2: -hnd[1], stroke: 'var(--ink-3)', 'stroke-width': sw * 0.35 }, g.equipBack);
            el('circle', { cx: from[0], cy: -from[1], r: sw * 1.4, fill: 'var(--bg)', stroke: 'var(--ink-3)', 'stroke-width': sw * 0.4 }, g.equipBack);
          }
        }
        if (q.type === 'barbell') {
          if (j.view === 'front') {
            const y = (hands[0][1] + hands[1][1]) / 2, half = 0.62;
            el('line', { x1: -half, x2: half, y1: -y, y2: -y, stroke: ink, 'stroke-width': sw * 0.7 }, g.equip);
            for (const s of [-1, 1]) el('rect', { x: s * half - (s > 0 ? 0 : 0.05), y: -y - 0.2, width: 0.05, height: 0.4, fill: ink }, g.equip);
          } else {
            el('circle', { cx: c[0], cy: -c[1], r: 0.2, fill: 'var(--fill)', 'fill-opacity': 0.5, stroke: 'var(--ink-2)', 'stroke-width': sw * 0.55 }, g.equipBack);
            el('circle', { cx: c[0], cy: -c[1], r: 0.035, fill: ink }, g.equip);
          }
        } else if (q.type === 'dumbbell') {
          for (const hnd of hands) {
            const horiz = j.view !== 'front';
            el('line', { x1: hnd[0] - (horiz ? 0.08 : 0), x2: hnd[0] + (horiz ? 0.08 : 0), y1: -hnd[1] - (horiz ? 0 : 0.08), y2: -hnd[1] + (horiz ? 0 : 0.08), stroke: ink, 'stroke-width': sw * 0.6 }, g.equip);
            for (const s of [-1, 1]) {
              const cxp = hnd[0] + (horiz ? s * 0.08 : 0), cyp = -hnd[1] + (horiz ? 0 : s * 0.08);
              el('rect', { x: cxp - 0.03, y: cyp - 0.06, width: 0.06, height: 0.12, fill: ink }, g.equip);
            }
          }
        } else if (q.type === 'kettlebell') {
          for (const hnd of hands) {
            el('circle', { cx: hnd[0], cy: -(hnd[1] - 0.11), r: 0.085, fill: ink }, g.equip);
            el('path', { d: `M${hnd[0] - 0.05},${-(hnd[1] - 0.06)} Q${hnd[0]},${-(hnd[1] + 0.03)} ${hnd[0] + 0.05},${-(hnd[1] - 0.06)}`, fill: 'none', stroke: ink, 'stroke-width': sw * 0.6 }, g.equip);
          }
        } else if (q.type === 'handle' || q.type === 'cable') {
          for (const hnd of hands) el('rect', { x: hnd[0] - 0.035, y: -hnd[1] - 0.035, width: 0.07, height: 0.07, fill: ink }, g.equip);
        } else if (q.type === 'ball') {
          const m = hands.length > 1 ? [(hands[0][0] + hands[1][0]) / 2, (hands[0][1] + hands[1][1]) / 2] : c;
          el('circle', { cx: m[0], cy: -m[1], r: 0.1, fill: 'var(--fill)', stroke: ink, 'stroke-width': sw * 0.7 }, g.equip);
        } else if (q.type === 'wheel') {
          el('circle', { cx: c[0], cy: -(c[1] - 0.02), r: 0.09, fill: 'var(--bg)', stroke: ink, 'stroke-width': sw * 0.8 }, g.equip);
        } else if (q.type === 'pad') {
          el('circle', { cx: c[0], cy: -c[1], r: 0.05, fill: 'var(--fill)', stroke: ink, 'stroke-width': sw * 0.5 }, g.equip);
        } else if (q.type === 'platform') {
          const a = rad(q.angle || 0), hl = (q.len || 0.4) / 2, dx = Math.cos(a) * hl, dy = Math.sin(a) * hl;
          el('line', { x1: c[0] - dx, y1: -(c[1] - dy), x2: c[0] + dx, y2: -(c[1] + dy), stroke: ink, 'stroke-width': sw * 1.4, 'stroke-linecap': 'square' }, g.equip);
        }
      }
    }

    container.textContent = '';
    container.appendChild(svg);
    let raf = 0, playing = opts.autoplay !== false, t0 = performance.now(), offset = opts.start || 0, lastLabel = null, speed = opts.speed || 1, lastU = -1, rep = 1;
    const reduce = window.matchMedia && matchMedia('(prefers-reduced-motion: reduce)').matches;
    const frame = now => {
      const time = playing ? offset + (now - t0) / 1000 * speed : offset;
      const { pose, label, u } = poseAt(pat, tl, time);
      draw(solve(pose, pat.view));
      if (u < lastU - 0.5) { rep++; if (opts.onRep) opts.onRep(rep); }
      lastU = u;
      if (opts.onFrame) opts.onFrame(u, label);
      if (label !== lastLabel) { lastLabel = label; if (opts.onPhase) opts.onPhase(label); }
      if (playing && !reduce) raf = requestAnimationFrame(frame);
    };
    const api = {
      play() { if (playing) return; playing = true; t0 = performance.now(); raf = requestAnimationFrame(frame); },
      pause() { if (!playing) return; offset += (performance.now() - t0) / 1000 * speed; playing = false; cancelAnimationFrame(raf); frame(performance.now()); },
      setSpeed(v) { if (playing) { offset += (performance.now() - t0) / 1000 * speed; t0 = performance.now(); } speed = v; },
      get time() { return playing ? offset + (performance.now() - t0) / 1000 * speed : offset; },
      get speed() { return speed; },
      get firstMoveFraction() { return tl.segs[0].dur / tl.total; },
      seek(frac) { offset = frac * tl.total; t0 = performance.now(); if (!playing) frame(performance.now()); },
      get playing() { return playing; },
      total: tl.total,
      destroy() { cancelAnimationFrame(raf); playing = false; container.textContent = ''; }
    };
    if (reduce) { playing = false; offset = (pat.keys.length > 1 ? tl.segs[0].dur : 0); }
    raf = requestAnimationFrame(frame);
    return api;
  }

  return { mount, resolve, solve, timeline, poseAt, bounds, L };
})();
if (typeof module !== 'undefined') module.exports = VoltMotion;
