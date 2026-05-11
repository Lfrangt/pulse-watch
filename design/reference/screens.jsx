/* global React, PulseTokens, PulseDemo */
// Pulse — screens
const { useState: useStateS, useMemo: useMemoS } = React;

// ─── Today screen
function TodayScreen({ t, lang, onNavigate }) {
  const D = PulseDemo;
  const v = D.vitals;
  return (
    <div style={{ paddingBottom: 100 }}>
      <HeroScore t={t} score={D.score} status={D.status} insight={D.insight} lang={lang} />

      {/* 30d score chart */}
      <div style={{ padding: '0 22px', marginTop: 4 }}>
        <Card t={t} pad={16}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10 }}>
            <MonoLabel t={t}>Score · 30 days</MonoLabel>
            <span style={{ fontFamily: '"JetBrains Mono", ui-monospace, monospace', fontSize: 10, color: t.inkMid, letterSpacing: 0.5 }}>
              avg 78 · σ 8.2
            </span>
          </div>
          <ScoreChart data={D.scoreHist} t={t} height={120} />
          <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 6 }}>
            <MonoLabel t={t} style={{ color: t.inkDim }}>Apr 06</MonoLabel>
            <MonoLabel t={t} style={{ color: t.inkDim }}>Today</MonoLabel>
          </div>
        </Card>
      </div>

      {/* Vitals grid */}
      <div style={{ marginTop: 26 }}>
        <SectionHead num="01" title="Vitals" sub="6 metrics" t={t} action="All" />
        <div style={{ padding: '0 22px', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
          <VitalChip t={t} label="HRV"        value={v.hrv.value}   unit="ms"  trend="up"   sub="+6 vs 30d baseline" onClick={() => onNavigate('vital', 'hrv')} />
          <VitalChip t={t} label="Resting HR" value={v.rhr.value}   unit="bpm" trend="down" sub="−2 vs 30d · improving" />
          <VitalChip t={t} label="Sleep"      value={v.sleep.value} unit="h"   trend="up"   sub="Asleep 11:42 · 8 wake" />
          <VitalChip t={t} label="Blood O₂"   value={v.spo2.value}  unit="%"   trend="flat" sub="97 – 99 today" />
          <VitalChip t={t} label="Stress"     value={v.stress.value} unit=""    trend="down" sub="Low · auto-calculated" />
          <VitalChip t={t} label="Health Age" value={v.age.value}   unit="yr"  trend="down" sub="−5 vs chronological" />
        </div>
      </div>

      {/* Suggested workout */}
      <div style={{ marginTop: 26 }}>
        <SectionHead num="02" title="Train" sub="suggested" t={t} action="Start" />
        <div style={{ padding: '0 22px' }}>
          <Card t={t} pad={0} style={{ overflow: 'hidden' }}>
            <div style={{ padding: '16px 18px 14px', borderBottom: `0.5px solid ${t.line}`, display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
              <div>
                <div style={{ fontSize: 22, fontWeight: 400, color: t.ink, letterSpacing: -0.4 }}>{D.suggestion.group[lang]}</div>
                <MonoLabel t={t} style={{ marginTop: 4 }}>{D.suggestion.intensity} · {D.suggestion.reason[lang]}</MonoLabel>
              </div>
              <div style={{
                padding: '6px 10px', background: t.accent, color: t.accentInk,
                borderRadius: 999, fontFamily: '"JetBrains Mono", ui-monospace, monospace',
                fontSize: 10, fontWeight: 600, letterSpacing: 0.6,
              }}>HEAVY</div>
            </div>
            <div style={{ padding: '6px 18px 6px' }}>
              {D.suggestion.exercises.map((e, i) => (
                <div key={i} style={{
                  display: 'flex', justifyContent: 'space-between', alignItems: 'center',
                  padding: '12px 0', borderBottom: i < 2 ? `0.5px solid ${t.lineSoft}` : 'none',
                }}>
                  <div>
                    <div style={{ fontSize: 15, color: t.ink, fontWeight: 450 }}>{e.name[lang]}</div>
                    <MonoLabel t={t} style={{ marginTop: 2 }}>{e.load}</MonoLabel>
                  </div>
                  <div style={{ display: 'flex', alignItems: 'baseline', gap: 4, fontVariantNumeric: 'tabular-nums' }}>
                    <span style={{ fontSize: 22, color: t.ink, fontWeight: 350 }}>{e.sets}</span>
                    <span style={{ fontSize: 11, color: t.inkMid, fontFamily: 'monospace' }}>×</span>
                    <span style={{ fontSize: 22, color: t.ink, fontWeight: 350 }}>{e.reps}</span>
                  </div>
                </div>
              ))}
            </div>
            <div onClick={() => onNavigate('workout')} style={{
              padding: '14px 18px', background: t.ink, color: t.bg,
              display: 'flex', justifyContent: 'space-between', alignItems: 'center',
              cursor: 'pointer',
            }}>
              <span style={{ fontSize: 14, fontWeight: 500 }}>Start session</span>
              <span style={{ fontFamily: 'monospace', fontSize: 11, letterSpacing: 1 }}>→</span>
            </div>
          </Card>
        </div>
      </div>

      {/* Recovery timeline */}
      <div style={{ marginTop: 26 }}>
        <SectionHead num="03" title="Recovery" sub="today" t={t} />
        <div style={{ padding: '0 22px' }}>
          <Card t={t} pad={0}>
            {D.timeline.map((e, i) => (
              <div key={i} style={{
                display: 'flex', gap: 12, padding: '14px 18px',
                borderBottom: i < D.timeline.length - 1 ? `0.5px solid ${t.lineSoft}` : 'none',
                alignItems: 'flex-start',
              }}>
                <div style={{
                  width: 8, height: 8, borderRadius: 4, marginTop: 6, flexShrink: 0,
                  background: e.impact === 'pos' ? t.accent : t.warn,
                }} />
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', gap: 8 }}>
                    <span style={{ fontSize: 14, color: t.ink, fontWeight: 450 }}>{e.title[lang]}</span>
                    <MonoLabel t={t}>{e.time}</MonoLabel>
                  </div>
                  <div style={{ fontSize: 12, color: t.inkMid, marginTop: 2 }}>{e.detail}</div>
                </div>
              </div>
            ))}
          </Card>
        </div>
      </div>
    </div>
  );
}

// ─── Vital detail screen
function VitalScreen({ t, lang, metric = 'hrv', onBack }) {
  const D = PulseDemo;
  const v = D.vitals[metric] || D.vitals.hrv;
  // synth 7d data
  const data = useMemoS(() => {
    const out = [];
    let s = v.value;
    for (let i = 6; i >= 0; i--) { s += (Math.random()-0.5)*8; out.push(Math.round(s)); }
    out[6] = v.value;
    return out;
  }, [metric]);
  const max = Math.max(...data), min = Math.min(...data);
  return (
    <div style={{ paddingBottom: 100 }}>
      <div style={{ padding: '8px 22px 0', display: 'flex', justifyContent: 'space-between' }}>
        <span onClick={onBack} style={{ cursor: 'pointer', fontFamily: 'monospace', fontSize: 12, color: t.inkMid }}>← Today</span>
        <MonoLabel t={t}>02 / Vital</MonoLabel>
      </div>
      <div style={{ padding: '20px 22px 8px' }}>
        <MonoLabel t={t}>{v.label.en} · {v.label.zh}</MonoLabel>
        <div style={{ marginTop: 10, display: 'flex', alignItems: 'baseline', gap: 8 }}>
          <BigNum value={v.value} unit={v.unit} t={t} size={108} />
          <div style={{ marginLeft: 'auto', textAlign: 'right' }}>
            <MonoLabel t={t}>30d avg</MonoLabel>
            <div style={{ fontSize: 22, color: t.ink, fontWeight: 350, fontVariantNumeric: 'tabular-nums' }}>52</div>
          </div>
        </div>
        <div style={{ marginTop: 6, fontSize: 13, color: t.inkMid }}>{v.range}</div>
      </div>

      {/* big chart */}
      <div style={{ padding: '20px 22px 0' }}>
        <Card t={t} pad={16}>
          <div style={{ display: 'flex', gap: 6, marginBottom: 12 }}>
            {['7D','30D','90D','6M','1Y'].map((r, i) => (
              <div key={r} style={{
                padding: '4px 10px', borderRadius: 999,
                background: i === 0 ? t.ink : 'transparent',
                color: i === 0 ? t.bg : t.inkMid,
                fontFamily: 'monospace', fontSize: 10, fontWeight: 600, letterSpacing: 0.5,
                border: i === 0 ? 'none' : `0.5px solid ${t.line}`,
              }}>{r}</div>
            ))}
          </div>
          <svg width="100%" height="160" viewBox="0 0 320 160" preserveAspectRatio="none" style={{ display: 'block' }}>
            {[max, (max+min)/2, min].map((vv, i) => {
              const y = 12 + (140 * i / 2);
              return <line key={i} x1="0" x2="320" y1={y} y2={y} stroke={t.lineSoft} strokeDasharray="2 3" />;
            })}
            {data.map((d, i) => {
              const x = (i / 6) * 320;
              const y = 152 - ((d - min) / (max - min || 1)) * 140;
              return (
                <g key={i}>
                  <line x1={x} y1={152} x2={x} y2={y} stroke={t.line} strokeWidth="0.5" />
                  <circle cx={x} cy={y} r={i === 6 ? 5 : 3} fill={i === 6 ? t.accent : t.ink} stroke={i === 6 ? t.ink : 'none'} strokeWidth="1.5" />
                </g>
              );
            })}
          </svg>
          <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 8 }}>
            {['M','T','W','T','F','S','S'].map((d, i) => (
              <MonoLabel key={i} t={t} style={{ color: i === 6 ? t.ink : t.inkDim, fontSize: 9 }}>{d}</MonoLabel>
            ))}
          </div>
        </Card>
      </div>

      {/* meta */}
      <div style={{ padding: '14px 22px 0', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
        <Card t={t} pad={14}>
          <MonoLabel t={t}>Personal baseline</MonoLabel>
          <div style={{ fontSize: 22, color: t.ink, fontWeight: 350, marginTop: 4, fontVariantNumeric: 'tabular-nums' }}>52 ms</div>
          <div style={{ fontSize: 11, color: t.inkDim, marginTop: 2 }}>30-day rolling</div>
        </Card>
        <Card t={t} pad={14}>
          <MonoLabel t={t}>Norm range</MonoLabel>
          <div style={{ fontSize: 22, color: t.ink, fontWeight: 350, marginTop: 4, fontVariantNumeric: 'tabular-nums' }}>40 – 65</div>
          <div style={{ fontSize: 11, color: t.inkDim, marginTop: 2 }}>Adults · age-adjusted</div>
        </Card>
      </div>
    </div>
  );
}

// ─── Workout / live screen
function WorkoutScreen({ t, onBack }) {
  const [running, setRunning] = useStateS(false);
  const [seconds, setSeconds] = useStateS(1247);
  React.useEffect(() => {
    if (!running) return;
    const id = setInterval(() => setSeconds(s => s + 1), 1000);
    return () => clearInterval(id);
  }, [running]);
  const fmt = (s) => `${String(Math.floor(s/60)).padStart(2,'0')}:${String(s%60).padStart(2,'0')}`;
  const hr = 142;
  const zone = 'Cardio';
  return (
    <div style={{ paddingBottom: 100 }}>
      <div style={{ padding: '8px 22px 0', display: 'flex', justifyContent: 'space-between' }}>
        <span onClick={onBack} style={{ cursor: 'pointer', fontFamily: 'monospace', fontSize: 12, color: t.inkMid }}>← Today</span>
        <MonoLabel t={t}>Live · Pull · Heavy</MonoLabel>
      </div>

      <div style={{ padding: '24px 22px 8px', textAlign: 'center' }}>
        <MonoLabel t={t}>Elapsed</MonoLabel>
        <div style={{
          marginTop: 6, fontSize: 88, fontWeight: 200, color: t.ink, letterSpacing: -2,
          fontVariantNumeric: 'tabular-nums', fontFeatureSettings: '"tnum"',
        }}>{fmt(seconds)}</div>
      </div>

      {/* HR ring */}
      <div style={{ display: 'flex', justifyContent: 'center', marginTop: 8 }}>
        <div style={{ position: 'relative', width: 220, height: 220 }}>
          <svg width="220" height="220">
            <circle cx="110" cy="110" r="100" fill="none" stroke={t.line} strokeWidth="1" />
            {/* Zone arcs */}
            {[
              { from: 0,   to: 0.20, c: t.lineSoft },
              { from: 0.20,to: 0.40, c: t.inkDim },
              { from: 0.40,to: 0.60, c: t.accent },
              { from: 0.60,to: 0.80, c: t.warn },
              { from: 0.80,to: 1.00, c: t.bad },
            ].map((seg, i) => {
              const r = 100;
              const len = (seg.to - seg.from) * 2 * Math.PI * r;
              const offset = -seg.from * 2 * Math.PI * r;
              return <circle key={i} cx="110" cy="110" r={r} fill="none"
                stroke={seg.c} strokeWidth="6"
                strokeDasharray={`${len - 4} ${2 * Math.PI * r}`}
                strokeDashoffset={offset}
                transform="rotate(-90 110 110)" />;
            })}
            {/* HR pointer */}
            <circle cx="110" cy="110" r="100" fill="none"
              stroke={t.ink} strokeWidth="2"
              strokeDasharray={`6 ${2 * Math.PI * 100 - 6}`}
              strokeDashoffset={-(0.50 * 2 * Math.PI * 100) + 3}
              transform="rotate(-90 110 110)" />
          </svg>
          <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center' }}>
            <BigNum value={hr} unit="bpm" t={t} size={72} weight={300} />
            <MonoLabel t={t} style={{ marginTop: 8, color: t.accent, fontSize: 11 }}>● Z3 {zone}</MonoLabel>
          </div>
        </div>
      </div>

      {/* stats */}
      <div style={{ padding: '24px 22px 0', display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 8 }}>
        <Card t={t} pad={12}>
          <MonoLabel t={t}>Avg HR</MonoLabel>
          <div style={{ fontSize: 22, color: t.ink, fontWeight: 350, marginTop: 4, fontVariantNumeric: 'tabular-nums' }}>128</div>
        </Card>
        <Card t={t} pad={12}>
          <MonoLabel t={t}>Calories</MonoLabel>
          <div style={{ fontSize: 22, color: t.ink, fontWeight: 350, marginTop: 4, fontVariantNumeric: 'tabular-nums' }}>284</div>
        </Card>
        <Card t={t} pad={12}>
          <MonoLabel t={t}>Strain</MonoLabel>
          <div style={{ fontSize: 22, color: t.ink, fontWeight: 350, marginTop: 4, fontVariantNumeric: 'tabular-nums' }}>62</div>
        </Card>
      </div>

      {/* controls */}
      <div style={{ padding: '24px 22px 0', display: 'flex', gap: 8 }}>
        <div onClick={() => setRunning(!running)} style={{
          flex: 1, padding: '16px', borderRadius: 14,
          background: running ? t.bgSunk : t.ink, color: running ? t.ink : t.bg,
          textAlign: 'center', fontWeight: 500, fontSize: 14, cursor: 'pointer',
          border: running ? `0.5px solid ${t.line}` : 'none',
        }}>{running ? 'Pause' : 'Resume'}</div>
        <div style={{
          flex: 1, padding: '16px', borderRadius: 14,
          background: 'transparent', color: t.bad, cursor: 'pointer',
          border: `0.5px solid ${t.line}`,
          textAlign: 'center', fontWeight: 500, fontSize: 14,
        }}>End</div>
      </div>
    </div>
  );
}

// ─── Sleep / detail variant
function SleepScreen({ t, lang, onBack }) {
  const D = PulseDemo;
  return (
    <div style={{ paddingBottom: 100 }}>
      <div style={{ padding: '8px 22px 0', display: 'flex', justifyContent: 'space-between' }}>
        <span onClick={onBack} style={{ cursor: 'pointer', fontFamily: 'monospace', fontSize: 12, color: t.inkMid }}>← Today</span>
        <MonoLabel t={t}>Sleep · last night</MonoLabel>
      </div>
      <div style={{ padding: '20px 22px 0' }}>
        <BigNum value="7:48" unit="hrs" t={t} size={80} />
        <div style={{ display: 'flex', gap: 12, marginTop: 8 }}>
          <MonoLabel t={t}>23:42 → 07:30</MonoLabel>
          <MonoLabel t={t}>· Score 84</MonoLabel>
        </div>
      </div>
      <div style={{ padding: '20px 22px 0' }}>
        <Card t={t} pad={16}>
          <MonoLabel t={t} style={{ display: 'block', marginBottom: 10 }}>Stages</MonoLabel>
          <SleepBand data={D.sleepBand} t={t} height={70} />
          <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 8 }}>
            <MonoLabel t={t} style={{ color: t.inkDim }}>23:42</MonoLabel>
            <MonoLabel t={t} style={{ color: t.inkDim }}>03:30</MonoLabel>
            <MonoLabel t={t} style={{ color: t.inkDim }}>07:30</MonoLabel>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr 1fr', gap: 8, marginTop: 16 }}>
            {[
              { k: 'Deep', v: '1h 14m', c: t.ink },
              { k: 'REM',  v: '2h 15m', c: t.accent },
              { k: 'Core', v: '3h 56m', c: t.inkMid },
              { k: 'Awake',v: '23m',    c: t.inkDim },
            ].map((s, i) => (
              <div key={i}>
                <div style={{ width: 10, height: 10, background: s.c, borderRadius: 2, marginBottom: 6 }} />
                <MonoLabel t={t}>{s.k}</MonoLabel>
                <div style={{ fontSize: 14, color: t.ink, fontVariantNumeric: 'tabular-nums', marginTop: 2 }}>{s.v}</div>
              </div>
            ))}
          </div>
        </Card>
      </div>
    </div>
  );
}

// ─── History list
function HistoryScreen({ t, onBack }) {
  const D = PulseDemo;
  return (
    <div style={{ paddingBottom: 100 }}>
      <div style={{ padding: '8px 22px 0', display: 'flex', justifyContent: 'space-between' }}>
        <span onClick={onBack} style={{ cursor: 'pointer', fontFamily: 'monospace', fontSize: 12, color: t.inkMid }}>← Today</span>
        <MonoLabel t={t}>History</MonoLabel>
      </div>
      <div style={{ padding: '20px 22px 0' }}>
        <BigNum value={D.history.length} unit="sessions" t={t} size={64} />
        <MonoLabel t={t} style={{ display: 'block', marginTop: 8 }}>past 14 days · 4h 42m total</MonoLabel>
      </div>
      <div style={{ padding: '24px 22px 0' }}>
        <Card t={t} pad={0}>
          {D.history.map((w, i) => (
            <div key={i} style={{
              padding: '14px 18px', borderBottom: i < D.history.length - 1 ? `0.5px solid ${t.lineSoft}` : 'none',
              display: 'flex', gap: 14, alignItems: 'center',
            }}>
              <div style={{
                width: 36, textAlign: 'right', flexShrink: 0,
              }}>
                <MonoLabel t={t} style={{ display: 'block', color: t.ink, fontSize: 9 }}>{w.date.split(' ')[0]}</MonoLabel>
                <span style={{ fontSize: 18, color: t.ink, fontWeight: 350, fontVariantNumeric: 'tabular-nums' }}>{w.date.split(' ')[1]}</span>
              </div>
              <div style={{ width: 0.5, alignSelf: 'stretch', background: t.line }} />
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: 15, color: t.ink, fontWeight: 450 }}>{w.type}</div>
                <MonoLabel t={t} style={{ marginTop: 2 }}>
                  {w.dur} {w.km ? `· ${w.km} km` : ''} {w.prs ? `· ${w.prs} PR` : ''}
                </MonoLabel>
              </div>
              <div style={{ textAlign: 'right' }}>
                <MonoLabel t={t}>Strain</MonoLabel>
                <div style={{ fontSize: 18, color: t.ink, fontWeight: 350, fontVariantNumeric: 'tabular-nums' }}>{w.strain}</div>
              </div>
            </div>
          ))}
        </Card>
      </div>
    </div>
  );
}

// ─── Coach screen
function CoachScreen({ t, lang, onBack }) {
  const [msg, setMsg] = useStateS('');
  const messages = [
    { role: 'agent', text: lang === 'zh' ? '早。HRV 比基线高 6ms，今天可以拉强度。' : 'Morning. HRV is 6ms above baseline. You can push intensity today.' },
    { role: 'user',  text: lang === 'zh' ? '建议练什么？' : 'What should I train?' },
    { role: 'agent', text: lang === 'zh' ? '拉日，距上次 4 天。先硬拉 4×5 @RPE8，再做引体。' : 'Pull. It’s been 4 days. Start with deadlift 4×5 @ RPE 8, then pull-ups.' },
  ];
  return (
    <div style={{ paddingBottom: 100, display: 'flex', flexDirection: 'column', height: '100%' }}>
      <div style={{ padding: '8px 22px 0', display: 'flex', justifyContent: 'space-between' }}>
        <span onClick={onBack} style={{ cursor: 'pointer', fontFamily: 'monospace', fontSize: 12, color: t.inkMid }}>← Today</span>
        <MonoLabel t={t}>Coach · OpenClaw</MonoLabel>
      </div>
      <div style={{ padding: '12px 22px 6px', display: 'flex', alignItems: 'center', gap: 8 }}>
        <div style={{ width: 8, height: 8, borderRadius: 4, background: t.good }} />
        <MonoLabel t={t}>Connected · 12ms · agent: lab.local</MonoLabel>
      </div>
      <div style={{ flex: 1, padding: '12px 22px 12px', display: 'flex', flexDirection: 'column', gap: 10, overflow: 'auto' }}>
        {messages.map((m, i) => (
          <div key={i} style={{
            alignSelf: m.role === 'user' ? 'flex-end' : 'flex-start',
            maxWidth: '80%',
            padding: '10px 14px', borderRadius: 14,
            background: m.role === 'user' ? t.ink : t.bgElev,
            color: m.role === 'user' ? t.bg : t.ink,
            border: m.role === 'user' ? 'none' : `0.5px solid ${t.line}`,
            fontSize: 14, lineHeight: 1.4,
          }}>{m.text}</div>
        ))}
        <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginTop: 4 }}>
          {[
            lang === 'zh' ? '为什么 HRV 低？' : 'Why is my HRV low?',
            lang === 'zh' ? '安排明天训练' : 'Plan tomorrow',
            lang === 'zh' ? '我应该多睡吗？' : 'Should I sleep more?',
          ].map((q, i) => (
            <div key={i} style={{
              padding: '6px 12px', borderRadius: 999,
              background: t.chipBg, color: t.ink, fontSize: 12,
              border: `0.5px solid ${t.line}`,
            }}>{q}</div>
          ))}
        </div>
      </div>
      <div style={{ padding: '8px 18px 24px', display: 'flex', gap: 8 }}>
        <input
          value={msg} onChange={e => setMsg(e.target.value)}
          placeholder={lang === 'zh' ? '问点什么…' : 'Ask anything…'}
          style={{
            flex: 1, padding: '12px 14px', borderRadius: 14, border: `0.5px solid ${t.line}`,
            background: t.bgElev, color: t.ink, fontSize: 14, outline: 'none',
          }}
        />
        <div style={{
          width: 44, height: 44, borderRadius: 14, background: t.accent,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          color: t.accentInk, fontSize: 16, fontWeight: 700,
        }}>↑</div>
      </div>
    </div>
  );
}

// ─── Anomaly / report screen
function ReportScreen({ t, lang, onBack }) {
  const D = PulseDemo;
  return (
    <div style={{ paddingBottom: 100 }}>
      <div style={{ padding: '8px 22px 0', display: 'flex', justifyContent: 'space-between' }}>
        <span onClick={onBack} style={{ cursor: 'pointer', fontFamily: 'monospace', fontSize: 12, color: t.inkMid }}>← Today</span>
        <MonoLabel t={t}>Week · Apr 28 – May 04</MonoLabel>
      </div>
      <div style={{ padding: '20px 22px 0' }}>
        <BigNum value={D.weekly.avgScore} unit="avg" t={t} size={88} />
        <MonoLabel t={t} style={{ display: 'block', marginTop: 6 }}>+4 vs prior week · trending ↑</MonoLabel>
      </div>

      <div style={{ padding: '20px 22px 0', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
        <Card t={t} pad={14}>
          <MonoLabel t={t}>Workouts</MonoLabel>
          <div style={{ fontSize: 28, color: t.ink, fontWeight: 350, marginTop: 6, fontVariantNumeric: 'tabular-nums' }}>{D.weekly.workouts}</div>
          <MonoLabel t={t} style={{ color: t.inkDim }}>{D.weekly.duration} total</MonoLabel>
        </Card>
        <Card t={t} pad={14}>
          <MonoLabel t={t}>Sleep avg</MonoLabel>
          <div style={{ fontSize: 28, color: t.ink, fontWeight: 350, marginTop: 6, fontVariantNumeric: 'tabular-nums' }}>{D.weekly.sleepAvg}</div>
          <MonoLabel t={t} style={{ color: t.inkDim }}>+12m vs week ago</MonoLabel>
        </Card>
      </div>

      <div style={{ marginTop: 26 }}>
        <SectionHead num="04" title="Anomalies" sub="this month" t={t} />
        <div style={{ padding: '0 22px' }}>
          <Card t={t} pad={0}>
            {D.anomalies.map((a, i) => (
              <div key={i} style={{
                padding: '14px 18px',
                borderBottom: i < D.anomalies.length - 1 ? `0.5px solid ${t.lineSoft}` : 'none',
              }}>
                <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                  <span style={{ fontSize: 14, color: t.ink, fontWeight: 500 }}>{a.type}</span>
                  <MonoLabel t={t}>{a.date}</MonoLabel>
                </div>
                <div style={{ fontSize: 12, color: t.inkMid, marginTop: 2, fontFamily: '"JetBrains Mono", monospace' }}>{a.value}</div>
                <div style={{ fontSize: 13, color: t.ink, marginTop: 6 }}>{a.meaning}</div>
                <div style={{ marginTop: 6, display: 'inline-block', padding: '3px 8px', borderRadius: 999, background: t.chipBg, fontSize: 11, color: t.ink }}>
                  → {a.action}
                </div>
              </div>
            ))}
          </Card>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, {
  TodayScreen, VitalScreen, WorkoutScreen, SleepScreen, HistoryScreen, CoachScreen, ReportScreen,
});
