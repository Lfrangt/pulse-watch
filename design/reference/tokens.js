// Pulse design tokens — light + dark
// Aesthetic: editorial, scientific instrument. Mono labels, large numbers.
// Single accent (lime/citron) borrowed from instrumentation displays.

window.PulseTokens = {
  light: {
    bg:        '#F5F4EF',   // warm paper
    bgElev:    '#FFFFFF',
    bgSunk:    '#EDEBE3',
    line:      'rgba(20, 22, 18, 0.10)',
    lineSoft:  'rgba(20, 22, 18, 0.06)',
    ink:       '#14140F',
    inkMid:    'rgba(20, 22, 18, 0.62)',
    inkDim:    'rgba(20, 22, 18, 0.38)',
    accent:    '#C8FF3D',   // lime
    accentInk: '#0E1A00',   // ink to use ON accent
    good:      '#2F7A3D',
    warn:      '#B6571B',
    bad:       '#A11D1D',
    chipBg:    'rgba(20, 22, 18, 0.05)',
  },
  dark: {
    bg:        '#0B0C0A',
    bgElev:    '#141513',
    bgSunk:    '#070806',
    line:      'rgba(255, 255, 255, 0.10)',
    lineSoft:  'rgba(255, 255, 255, 0.05)',
    ink:       '#F2F1EC',
    inkMid:    'rgba(242, 241, 236, 0.62)',
    inkDim:    'rgba(242, 241, 236, 0.34)',
    accent:    '#D2FF3D',
    accentInk: '#0E1A00',
    good:      '#7BD68A',
    warn:      '#E89A55',
    bad:       '#E76E6E',
    chipBg:    'rgba(255, 255, 255, 0.06)',
  },
};

// Demo data — 30 days of plausible health metrics
window.PulseDemo = (() => {
  const today = new Date('2026-05-05T07:14:00');
  const score = 82;
  const status = 'Great';
  const insight = { en: 'Train hard. Push intensity today.', zh: '今天可以拉强度，状态在线。' };
  const vitals = {
    hr:   { value: 64,  unit: 'bpm', label: { en: 'Heart Rate', zh: '心率' },         range: '52–142 today',  trend: 'flat' },
    hrv:  { value: 58,  unit: 'ms',  label: { en: 'HRV',         zh: '心率变异性' },   range: '+6 vs 30d',     trend: 'up'   },
    rhr:  { value: 54,  unit: 'bpm', label: { en: 'Resting HR',  zh: '静息心率' },     range: '−2 vs 30d',     trend: 'down' },
    spo2: { value: 98,  unit: '%',   label: { en: 'Blood O₂',    zh: '血氧' },         range: '97–99 today',   trend: 'flat' },
    sleep:{ value: 7.8, unit: 'h',   label: { en: 'Sleep',       zh: '睡眠' },         range: 'Asleep at 11:42', trend: 'up' },
    steps:{ value: 4280,unit: '',    label: { en: 'Steps',       zh: '步数' },         range: 'Goal 10,000',   trend: 'up'   },
    stress:{value: 28,  unit: '',    label: { en: 'Stress',      zh: '压力' },         range: 'Low',           trend: 'down' },
    age:  { value: 29,  unit: 'yr',  label: { en: 'Health Age',  zh: '健康年龄' },     range: '−5 vs actual',  trend: 'down' },
  };

  // 30-day score history
  const scoreHist = [];
  let s = 70;
  for (let i = 29; i >= 0; i--) {
    s += (Math.sin(i*0.6)*4) + (Math.random()-0.5)*5;
    s = Math.max(45, Math.min(94, s));
    scoreHist.push({ d: i, v: Math.round(s) });
  }
  scoreHist[scoreHist.length-1].v = score;

  // Sleep band (last night)
  const sleepBand = [
    { stage: 'awake', mins: 6 },
    { stage: 'core',  mins: 38 },
    { stage: 'deep',  mins: 52 },
    { stage: 'core',  mins: 31 },
    { stage: 'rem',   mins: 28 },
    { stage: 'core',  mins: 44 },
    { stage: 'deep',  mins: 22 },
    { stage: 'rem',   mins: 36 },
    { stage: 'core',  mins: 47 },
    { stage: 'rem',   mins: 41 },
    { stage: 'awake', mins: 8 },
    { stage: 'core',  mins: 25 },
    { stage: 'rem',   mins: 30 },
  ];

  // Recovery timeline
  const timeline = [
    { time: '07:14', type: 'wake',     title: { en: 'Awake',                   zh: '醒来' },          detail: 'Sleep 7h 48m · 8 awakenings', impact: 'pos' },
    { time: '06:42', type: 'sleep',    title: { en: 'REM peak',                zh: 'REM 峰值' },      detail: '36m block — strong cycle',     impact: 'pos' },
    { time: '02:18', type: 'sleep',    title: { en: 'Deep sleep',              zh: '深睡' },          detail: '52m — best block in 9 days',   impact: 'pos' },
    { time: 'Yest 21:30', type: 'caffeine', title: { en: 'No caffeine after 14:00', zh: '14 点后无咖啡因' }, detail: 'Logged · helps deep sleep', impact: 'pos' },
    { time: 'Yest 18:40', type: 'workout', title: { en: 'Push session',         zh: '推举训练' },     detail: '52 min · 4 PRs · strain 71',   impact: 'neg' },
  ];

  // Workout history
  const history = [
    { date: 'May 4', type: 'Push',     dur: '52m', strain: 71, group: 'chest', prs: 4 },
    { date: 'May 3', type: 'Run',      dur: '38m', strain: 64, group: 'cardio', km: 6.8 },
    { date: 'May 1', type: 'Pull',     dur: '48m', strain: 58, group: 'back',  prs: 1 },
    { date: 'Apr 30',type: 'Legs',     dur: '64m', strain: 82, group: 'legs',  prs: 2 },
    { date: 'Apr 29',type: 'Easy walk',dur: '42m', strain: 22, group: 'cardio', km: 4.1 },
    { date: 'Apr 27',type: 'HIIT',     dur: '24m', strain: 76, group: 'cardio' },
  ];

  // Anomalies
  const anomalies = [
    { date: 'Apr 28', type: 'Low HRV',     value: '32 ms (baseline 54)', meaning: 'Sympathetic load is up.', action: 'Take a true rest day.' },
    { date: 'Apr 22', type: 'High RHR',    value: '67 bpm × 2 days',     meaning: 'Possibly fighting something.', action: 'Hydrate, sleep early.' },
    { date: 'Apr 15', type: 'Sleep disruption', value: 'Deep < 30m × 3', meaning: 'Recovery is shallow.',     action: 'Earlier bedtime, no screens.' },
  ];

  // Suggested workout (B1)
  const suggestion = {
    group: { en: 'Pull', zh: '拉日' },
    intensity: 'Heavy',
    daysSince: 4,
    reason: { en: 'Last Pull was 4d ago', zh: '上次拉日在 4 天前' },
    exercises: [
      { name: { en: 'Deadlift',      zh: '硬拉' },     sets: 4, reps: '5',  load: '@ RPE 8' },
      { name: { en: 'Pull-up',       zh: '引体向上' }, sets: 4, reps: '6–8',load: '+ 5kg' },
      { name: { en: 'Barbell row',   zh: '杠铃划船' }, sets: 3, reps: '8',  load: '70kg' },
    ],
  };

  // Weekly aggregates
  const weekly = {
    avgScore: 78,
    workouts: 5,
    duration: '4h 12m',
    sleepAvg: '7h 32m',
    bestDay: 'Wed',
    worstDay: 'Sat',
    delta: { score: +4, sleep: +12, strain: -8 },
  };

  return { today, score, status, insight, vitals, scoreHist, sleepBand, timeline, history, anomalies, suggestion, weekly };
})();
