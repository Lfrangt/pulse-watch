/* global React */
// Pulse — shared UI primitives
// Mono labels, large numbers, tabular figures

const { useState, useEffect, useRef, useMemo } = React;

// ─── Mono label (always uppercase tracking, instrument feel)
function MonoLabel({ children, style = {}, t }) {
  return (
    <span style={{
      fontFamily: '"JetBrains Mono", ui-monospace, Menlo, monospace',
      fontSize: 10, fontWeight: 500, letterSpacing: 0.8,
      textTransform: 'uppercase', color: t.inkMid,
      ...style,
    }}>{children}</span>
  );
}

// ─── Big number with tabular figures
function BigNum({ value, unit, t, size = 96, weight = 300, color }) {
  return (
    <div style={{ display: 'flex', alignItems: 'baseline', gap: 6, color: color || t.ink }}>
      <span style={{
        fontSize: size, lineHeight: 0.92, fontWeight: weight,
        letterSpacing: -0.04 * size, fontVariantNumeric: 'tabular-nums',
        fontFeatureSettings: '"tnum", "ss01"',
      }}>{value}</span>
      {unit && <span style={{
        fontSize: size * 0.18, fontWeight: 500, color: t.inkMid,
        fontFamily: '"JetBrains Mono", ui-monospace, Menlo, monospace',
        letterSpacing: 0.5, textTransform: 'uppercase',
      }}>{unit}</span>}
    </div>
  );
}

// ─── Trend arrow
function TrendArrow({ dir, t, color }) {
  const c = color || (dir === 'up' ? t.good : dir === 'down' ? t.bad : t.inkDim);
  if (dir === 'flat') return <span style={{ color: c, fontSize: 11 }}>—</span>;
  const rot = dir === 'up' ? 0 : 180;
  return (
    <svg width="9" height="9" viewBox="0 0 9 9" style={{ transform: `rotate(${rot}deg)` }}>
      <path d="M4.5 1 L8 6 L1 6 Z" fill={c} />
    </svg>
  );
}

// ─── Sparkline
function Sparkline({ data, t, color, height = 32, width = 120, fill = false }) {
  const max = Math.max(...data);
  const min = Math.min(...data);
  const range = max - min || 1;
  const pts = data.map((v, i) => {
    const x = (i / (data.length - 1)) * width;
    const y = height - ((v - min) / range) * (height - 4) - 2;
    return [x, y];
  });
  const d = pts.map((p, i) => `${i === 0 ? 'M' : 'L'}${p[0].toFixed(1)} ${p[1].toFixed(1)}`).join(' ');
  const areaD = `${d} L${width} ${height} L0 ${height} Z`;
  return (
    <svg width={width} height={height} style={{ display: 'block' }}>
      {fill && <path d={areaD} fill={color || t.accent} fillOpacity={0.15} />}
      <path d={d} fill="none" stroke={color || t.ink} strokeWidth="1.25" strokeLinecap="round" strokeLinejoin="round" />
      <circle cx={pts[pts.length-1][0]} cy={pts[pts.length-1][1]} r="2" fill={color || t.ink} />
    </svg>
  );
}

// ─── Section divider with numbered label (editorial)
function SectionHead({ num, title, sub, t, action }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'baseline', justifyContent: 'space-between',
      padding: '0 22px', marginBottom: 12,
    }}>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 10 }}>
        <MonoLabel t={t} style={{ color: t.inkDim }}>{num}</MonoLabel>
        <span style={{ fontSize: 13, fontWeight: 500, color: t.ink, letterSpacing: -0.1 }}>{title}</span>
        {sub && <MonoLabel t={t}>{sub}</MonoLabel>}
      </div>
      {action && <MonoLabel t={t} style={{ color: t.ink }}>{action} →</MonoLabel>}
    </div>
  );
}

// ─── Card (paper-like)
function Card({ children, t, style = {}, sunk = false, pad = 18 }) {
  return (
    <div style={{
      background: sunk ? t.bgSunk : t.bgElev,
      borderRadius: 18, padding: pad,
      border: `0.5px solid ${t.line}`,
      ...style,
    }}>{children}</div>
  );
}

// ─── Big circular score dial — instrument feel, no rainbow
function ScoreDial({ score, status, t, size = 240 }) {
  const r = size / 2 - 14;
  const c = size / 2;
  const circ = 2 * Math.PI * r;
  const pct = score / 100;
  const dash = circ * pct;
  // 60 minor ticks, every 5th major
  const ticks = [];
  for (let i = 0; i < 60; i++) {
    const a = (i / 60) * Math.PI * 2 - Math.PI / 2;
    const inner = r - (i % 5 === 0 ? 8 : 4);
    const x1 = c + Math.cos(a) * (r + 2);
    const y1 = c + Math.sin(a) * (r + 2);
    const x2 = c + Math.cos(a) * inner;
    const y2 = c + Math.sin(a) * inner;
    const reached = (i / 60) <= pct;
    ticks.push(
      <line key={i} x1={x1} y1={y1} x2={x2} y2={y2}
        stroke={reached ? t.ink : t.line}
        strokeWidth={i % 5 === 0 ? 1.25 : 0.75} />
    );
  }
  return (
    <div style={{ position: 'relative', width: size, height: size }}>
      <svg width={size} height={size} style={{ display: 'block' }}>
        {ticks}
        {/* Outer thin ring */}
        <circle cx={c} cy={c} r={r + 4} fill="none" stroke={t.lineSoft} strokeWidth="0.5" />
        {/* Accent arc */}
        <circle cx={c} cy={c} r={r - 14} fill="none"
          stroke={t.accent} strokeWidth="2"
          strokeDasharray={`${dash * (r-14)/r} ${circ * (r-14)/r}`}
          strokeDashoffset={(circ * (r-14)/r) * 0.25}
          transform={`rotate(-90 ${c} ${c})`}
          strokeLinecap="round"
        />
      </svg>
      <div style={{
        position: 'absolute', inset: 0, display: 'flex',
        flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
      }}>
        <BigNum value={score} t={t} size={88} weight={250} />
        <MonoLabel t={t} style={{ marginTop: 6, color: t.ink, fontSize: 11 }}>
          / 100 · {status}
        </MonoLabel>
      </div>
    </div>
  );
}

// ─── Vital chip
function VitalChip({ icon, label, value, unit, trend, sub, t, onClick }) {
  return (
    <div onClick={onClick} style={{
      flex: 1, padding: '14px 14px 12px', borderRadius: 14,
      background: t.bgElev, border: `0.5px solid ${t.line}`,
      cursor: onClick ? 'pointer' : 'default',
      display: 'flex', flexDirection: 'column', gap: 6,
    }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <MonoLabel t={t}>{label}</MonoLabel>
        {trend && <TrendArrow dir={trend} t={t} />}
      </div>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 4 }}>
        <span style={{
          fontSize: 28, fontWeight: 350, color: t.ink, letterSpacing: -0.6,
          fontVariantNumeric: 'tabular-nums', lineHeight: 1,
        }}>{value}</span>
        {unit && <span style={{
          fontFamily: '"JetBrains Mono", ui-monospace, monospace',
          fontSize: 10, color: t.inkMid, letterSpacing: 0.5,
        }}>{unit}</span>}
      </div>
      {sub && <span style={{
        fontFamily: '"JetBrains Mono", ui-monospace, monospace',
        fontSize: 9.5, color: t.inkDim, letterSpacing: 0.3,
      }}>{sub}</span>}
    </div>
  );
}

// ─── 30-day score chart
function ScoreChart({ data, t, height = 130 }) {
  const w = 340;
  const h = height;
  const max = 100, min = 40;
  const pts = data.map((d, i) => {
    const x = (i / (data.length - 1)) * w;
    const y = h - ((d.v - min) / (max - min)) * (h - 20) - 10;
    return [x, y, d.v];
  });
  const path = pts.map((p, i) => `${i === 0 ? 'M' : 'L'}${p[0].toFixed(1)} ${p[1].toFixed(1)}`).join(' ');
  const area = `${path} L${w} ${h} L0 ${h} Z`;
  const last = pts[pts.length - 1];
  return (
    <svg width="100%" height={h} viewBox={`0 0 ${w} ${h}`} preserveAspectRatio="none" style={{ display: 'block' }}>
      {/* baselines */}
      {[40, 60, 80, 100].map(v => {
        const y = h - ((v - min) / (max - min)) * (h - 20) - 10;
        return <line key={v} x1="0" x2={w} y1={y} y2={y} stroke={t.lineSoft} strokeDasharray={v === 60 ? '0' : '2 4'} strokeWidth="0.5" />;
      })}
      <path d={area} fill={t.accent} fillOpacity="0.12" />
      <path d={path} fill="none" stroke={t.ink} strokeWidth="1.5" strokeLinejoin="round" strokeLinecap="round" />
      <circle cx={last[0]} cy={last[1]} r="4" fill={t.accent} stroke={t.ink} strokeWidth="1.5" />
    </svg>
  );
}

// ─── Sleep band
function SleepBand({ data, t, height = 60 }) {
  const total = data.reduce((s, d) => s + d.mins, 0);
  const colors = {
    awake: t.inkDim,
    rem:   t.accent,
    core:  t.inkMid,
    deep:  t.ink,
  };
  const stages = [
    { k: 'awake', y: 0,  hh: 0.18 },
    { k: 'rem',   y: 0.20, hh: 0.22 },
    { k: 'core',  y: 0.44, hh: 0.26 },
    { k: 'deep',  y: 0.72, hh: 0.28 },
  ];
  let cursor = 0;
  return (
    <svg width="100%" height={height} viewBox={`0 0 ${total} ${height}`} preserveAspectRatio="none" style={{ display: 'block' }}>
      {data.map((seg, i) => {
        const stage = stages.find(s => s.k === seg.stage);
        const x = cursor;
        const w = seg.mins;
        const y = stage.y * height;
        const h = stage.hh * height;
        cursor += seg.mins;
        return <rect key={i} x={x} y={y} width={w - 0.5} height={h} fill={colors[seg.stage]} rx="1" />;
      })}
    </svg>
  );
}

// ─── Hero score block — used on Today
function HeroScore({ t, score, status, insight, lang }) {
  return (
    <div style={{
      padding: '24px 22px 28px',
      display: 'flex', gap: 18, alignItems: 'center',
    }}>
      <ScoreDial score={score} status={status} t={t} size={170} />
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 10 }}>
        <MonoLabel t={t}>Readiness · 05 May</MonoLabel>
        <div style={{
          fontSize: 19, lineHeight: 1.18, color: t.ink, fontWeight: 500,
          letterSpacing: -0.3, textWrap: 'pretty',
        }}>{insight[lang]}</div>
        <div style={{
          marginTop: 4, padding: '6px 10px', borderRadius: 999,
          background: t.accent, color: t.accentInk, alignSelf: 'flex-start',
          fontFamily: '"JetBrains Mono", ui-monospace, monospace',
          fontSize: 10, fontWeight: 600, letterSpacing: 0.6, textTransform: 'uppercase',
        }}>● Streak 47</div>
      </div>
    </div>
  );
}

// Export
Object.assign(window, {
  MonoLabel, BigNum, TrendArrow, Sparkline, SectionHead, Card,
  ScoreDial, VitalChip, ScoreChart, SleepBand, HeroScore,
});
