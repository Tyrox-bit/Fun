// Single source of truth: captions, visual FX and sound effects share these timings.
// Times in seconds. Voice should follow the caption timings (see out/untertitel.srt).

export const FPS = 30;
export const DURATION = 63.0;
export const W = 1080;
export const H = 1920;

// Segment = scene with its own set/camera/lighting. hour = value shown on the timer.
export const SEGMENTS = [
  { id: 'hook',   start: 0.0,  end: 4.6,  hour: 0 },
  { id: 'minute', start: 4.6,  end: 11.0, hour: 0, minute: 1 },
  { id: 'tower',  start: 11.0, end: 19.5, hour: 3 },
  { id: 'gas',    start: 19.5, end: 28.5, hour: 12 },
  { id: 'water',  start: 28.5, end: 35.5, hour: 24 },
  { id: 'hosp',   start: 35.5, end: 39.6, hour: 48 },
  { id: 'truck',  start: 39.6, end: 43.5, hour: 48, cont: true },
  { id: 'market', start: 43.5, end: 46.1, hour: 72 },
  { id: 'door',   start: 46.1, end: 51.0, hour: 72, cont: true },
  { id: 'outro',  start: 51.0, end: 61.9, hour: 72, cont: true },
  { id: 'loop',   start: 61.9, end: 63.0, hour: 0 },
];

// Captions: [start, text, opts]. Words in opts.hl are highlighted (yellow), opts.red -> red.
// opts.hour -> big "STUNDE X" style chunk.
export const CAPTIONS = [
  [0.00, 'GANZ DEUTSCHLAND.', { hl: ['DEUTSCHLAND.'] }],
  [0.95, 'KEIN STROM.', { red: ['STROM.'] }],
  [1.80, '72 STUNDEN.', { hl: ['72'] }],
  [2.75, 'DIE ERSTE STUNDE', {}],
  [3.55, 'IST NOCH LUSTIG.', { hl: ['LUSTIG.'] }],

  [4.60, 'MINUTE 1:', { hour: true }],
  [5.25, 'AMPELN AUS.', { red: ['AUS.'] }],
  [6.05, 'AUFZÜGE', { hl: ['AUFZÜGE'] }],
  [6.45, 'STECKEN FEST.', {}],
  [7.30, 'ALLE ZÜCKEN', {}],
  [7.85, 'DIE HANDYLAMPE.', { hl: ['HANDYLAMPE.'] }],
  [8.90, 'FÜHLT SICH NOCH AN', {}],
  [9.80, 'WIE EIN ABENTEUER.', { hl: ['ABENTEUER.'] }],

  [11.00, 'STUNDE 3:', { hour: true }],
  [11.60, 'VIELE FUNKMASTEN', { hl: ['FUNKMASTEN'] }],
  [12.45, 'LAUFEN NUR NOCH', {}],
  [13.10, 'AUF AKKU.', { hl: ['AKKU.'] }],
  [13.80, 'DANN IST SCHLUSS.', { red: ['SCHLUSS.'] }],
  [14.75, 'KEIN NETZ,', { red: ['NETZ,'] }],
  [15.35, 'KEIN WHATSAPP,', { red: ['WHATSAPP,'] }],
  [15.95, 'KEIN NOTRUF.', { red: ['NOTRUF.'] }],
  [16.85, 'DEIN HANDY', {}],
  [17.45, 'IST JETZT', {}],
  [17.95, 'EINE TASCHENLAMPE.', { hl: ['TASCHENLAMPE.'] }],

  [19.50, 'STUNDE 12:', { hour: true }],
  [20.15, 'TANKSTELLEN GEBEN', { hl: ['TANKSTELLEN'] }],
  [21.00, 'KEIN BENZIN MEHR RAUS,', { red: ['BENZIN'] }],
  [22.05, 'DENN DIE PUMPEN', {}],
  [22.75, 'BRAUCHEN STROM.', { hl: ['STROM.'] }],
  [23.55, 'KARTE GEHT NICHT,', { red: ['NICHT,'] }],
  [24.35, 'GELDAUTOMAT', { hl: ['GELDAUTOMAT'] }],
  [24.95, 'AUCH NICHT.', { red: ['NICHT.'] }],
  [25.75, 'KEIN BARGELD HEISST:', { hl: ['BARGELD'] }],
  [26.85, 'DU KAUFST', {}],
  [27.35, 'NICHTS MEHR.', { red: ['NICHTS'] }],

  [28.50, 'STUNDE 24:', { hour: true }],
  [29.15, 'IN HOCHHÄUSERN', { hl: ['HOCHHÄUSERN'] }],
  [29.95, 'KOMMT OBEN', {}],
  [30.45, 'KEIN WASSER MEHR AN.', { red: ['WASSER'] }],
  [31.55, 'KEINE DUSCHE.', { red: ['DUSCHE.'] }],
  [32.45, 'UND DIE TOILETTE', { hl: ['TOILETTE'] }],
  [33.25, 'SPÜLT GENAU', {}],
  [33.85, 'NOCH EIN MAL.', { red: ['EIN'] }],

  [35.50, 'STUNDE 48:', { hour: true }],
  [36.15, 'KRANKENHÄUSER', { hl: ['KRANKENHÄUSER'] }],
  [36.85, 'LAUFEN AUF NOTSTROM.', { hl: ['NOTSTROM.'] }],
  [37.85, 'MIT DIESEL.', { red: ['DIESEL.'] }],
  [38.60, 'DEN MUSS', {}],
  [39.05, 'JEMAND LIEFERN,', { hl: ['LIEFERN,'] }],
  [39.85, 'ÜBER STRASSEN', {}],
  [40.45, 'OHNE AMPELN', { red: ['AMPELN'] }],
  [41.15, 'UND MIT LKWS,', { hl: ['LKWS,'] }],
  [41.85, 'DIE NICHT', {}],
  [42.30, 'TANKEN KÖNNEN.', { red: ['TANKEN'] }],

  [43.50, 'STUNDE 72:', { hour: true }],
  [44.15, 'SUPERMÄRKTE LEER.', { red: ['LEER.'] }],
  [45.15, 'KÜHLSCHRÄNKE WARM.', { red: ['WARM.'] }],
  [46.15, 'JEMAND KLOPFT', { hl: ['KLOPFT'] }],
  [46.85, 'AN DEINE TÜR.', { red: ['TÜR.'] }],
  [47.85, 'UND JETZT DIE FRAGE,', {}],
  [48.85, 'DIE KEINER', {}],
  [49.35, 'HÖREN WILL:', { red: ['WILL:'] }],

  [51.00, 'DER STAAT EMPFIEHLT', {}],
  [52.10, 'VORRÄTE FÜR', {}],
  [52.80, '10 TAGE.', { hl: ['10', 'TAGE.'] }],
  [53.80, 'DU HAST WAHRSCHEINLICH', {}],
  [55.00, 'NICHT MAL WELCHE', {}],
  [55.80, 'FÜR 3.', { red: ['3.'] }],
  [56.75, 'WIE LANGE WÜRDEST', {}],
  [57.45, 'DU DURCHHALTEN?', { hl: ['DURCHHALTEN?'] }],
  [58.30, "SCHREIB'S IN", {}],
  [58.80, 'DIE KOMMENTARE!', { hl: ['KOMMENTARE!'] }],
  [59.75, 'DENN GENAU SO', {}],
  [60.55, 'FÄNGT ES AN …', { hl: ['AN', '…'] }],
];
export const CAPTION_END = 61.85;

// Popup word visualisations (emoji cards / big text). type: 'icon' | 'big'
// x/y are relative (0..1) screen positions; x:'row' places icons in a row.
export const POPUPS = [
  { t: 1.80, d: 0.95, type: 'big', text: '72', sub: 'STUNDEN', color: '#ff2a2a' },

  { t: 5.25, d: 0.8, type: 'icon', e: '🚦', x: 0.5, y: 0.4, x_out: true },
  { t: 6.05, d: 1.2, type: 'icon', e: '🛗', x: 0.5, y: 0.4 },
  { t: 7.85, d: 1.0, type: 'icon', e: '🔦', x: 0.5, y: 0.4 },

  { t: 11.60, d: 2.15, type: 'icon', e: '📡', x: 0.5, y: 0.4 },
  { t: 13.10, d: 0.70, type: 'battery', x: 0.5, y: 0.4 },
  { t: 14.75, d: 2.05, type: 'icon', e: '📶', x: 0.22, y: 0.4, x_out: true },
  { t: 15.35, d: 1.45, type: 'icon', e: '💬', x: 0.5, y: 0.4, x_out: true },
  { t: 15.95, d: 0.85, type: 'icon', e: '🆘', x: 0.78, y: 0.4, x_out: true },
  { t: 17.95, d: 1.4, type: 'icon', e: '🔦', x: 0.5, y: 0.4 },

  { t: 20.15, d: 1.85, type: 'icon', e: '⛽', x: 0.5, y: 0.4, x_out: true, xt: 21.0 },
  { t: 22.75, d: 0.8, type: 'icon', e: '🔌', x: 0.5, y: 0.4 },
  { t: 23.55, d: 2.15, type: 'icon', e: '💳', x: 0.3, y: 0.4, x_out: true },
  { t: 24.35, d: 1.35, type: 'icon', e: '🏧', x: 0.7, y: 0.4, x_out: true, xt: 24.95 },
  { t: 25.75, d: 1.1, type: 'icon', e: '💶', x: 0.5, y: 0.4 },
  { t: 27.35, d: 1.1, type: 'icon', e: '🛒', x: 0.5, y: 0.4, x_out: true },

  { t: 30.45, d: 1.1, type: 'icon', e: '💧', x: 0.5, y: 0.4, x_out: true },
  { t: 31.55, d: 0.9, type: 'icon', e: '🚿', x: 0.5, y: 0.4, x_out: true },
  { t: 32.45, d: 1.4, type: 'icon', e: '🚽', x: 0.5, y: 0.4 },
  { t: 33.85, d: 1.55, type: 'big', text: '1×', sub: 'NOCH', color: '#ff2a2a' },

  { t: 36.15, d: 1.7, type: 'icon', e: '🏥', x: 0.5, y: 0.4 },
  { t: 37.85, d: 0.75, type: 'gauge', x: 0.5, y: 0.4 },
  { t: 41.15, d: 1.0, type: 'icon', e: '🚚', x: 0.5, y: 0.4 },
  { t: 42.30, d: 1.1, type: 'icon', e: '⛽', x: 0.5, y: 0.4, x_out: true },

  { t: 44.15, d: 1.0, type: 'icon', e: '🛒', x: 0.5, y: 0.4, x_out: true },
  { t: 45.15, d: 0.95, type: 'thermo', x: 0.5, y: 0.4 },

  { t: 52.80, d: 1.0, type: 'big', text: '10', sub: 'TAGE', color: '#ffd400' },
  { t: 55.80, d: 0.95, type: 'big', text: '3', sub: 'TAGE?', color: '#ff2a2a' },
];

// Visual FX: flash (white/red), shake, glitch (rgb split), punch (zoom), blackout (fade to black)
export const FX = [
  { t: 0.95, type: 'flash', d: 0.25, a: 0.55, c: [1, 1, 1] },
  { t: 0.95, type: 'shake', d: 0.5, a: 0.9 },
  { t: 0.95, type: 'glitch', d: 0.35, a: 1.0 },
  { t: 1.80, type: 'punch', d: 0.35, a: 0.06 },
  { t: 1.80, type: 'shake', d: 0.35, a: 0.6 },
  { t: 1.80, type: 'flash', d: 0.18, a: 0.35, c: [1, 0.15, 0.1] },

  { t: 4.60, type: 'whip', d: 0.3, a: 1 },
  { t: 5.40, type: 'shake', d: 0.25, a: 0.25 },
  { t: 6.50, type: 'shake', d: 0.45, a: 0.7 },
  { t: 6.50, type: 'glitch', d: 0.2, a: 0.5 },

  { t: 11.00, type: 'whip', d: 0.3, a: 1 },
  { t: 13.80, type: 'glitch', d: 0.4, a: 1.0 },
  { t: 13.80, type: 'shake', d: 0.35, a: 0.5 },
  { t: 14.75, type: 'punch', d: 0.2, a: 0.03 },
  { t: 15.35, type: 'punch', d: 0.2, a: 0.03 },
  { t: 15.95, type: 'punch', d: 0.25, a: 0.05 },
  { t: 15.95, type: 'flash', d: 0.15, a: 0.3, c: [1, 0.1, 0.1] },

  { t: 19.50, type: 'whip', d: 0.3, a: 1 },
  { t: 23.55, type: 'glitch', d: 0.2, a: 0.6 },
  { t: 24.95, type: 'glitch', d: 0.2, a: 0.6 },
  { t: 27.35, type: 'punch', d: 0.3, a: 0.05 },
  { t: 27.35, type: 'shake', d: 0.3, a: 0.4 },

  { t: 28.50, type: 'whip', d: 0.3, a: 1 },
  { t: 33.85, type: 'punch', d: 0.3, a: 0.05 },
  { t: 33.85, type: 'flash', d: 0.15, a: 0.3, c: [1, 0.1, 0.1] },

  { t: 35.50, type: 'whip', d: 0.3, a: 1 },
  { t: 39.60, type: 'whip', d: 0.3, a: 1 },
  { t: 42.30, type: 'shake', d: 0.3, a: 0.35 },

  { t: 43.50, type: 'whip', d: 0.3, a: 1 },
  { t: 46.10, type: 'flash', d: 0.12, a: 0.25, c: [1, 1, 1] },
  { t: 46.40, type: 'shake', d: 0.18, a: 0.9 },
  { t: 46.72, type: 'shake', d: 0.18, a: 0.9 },
  { t: 47.04, type: 'shake', d: 0.22, a: 1.1 },
  { t: 49.35, type: 'glitch', d: 0.3, a: 0.7 },

  { t: 52.80, type: 'punch', d: 0.35, a: 0.06 },
  { t: 52.80, type: 'shake', d: 0.3, a: 0.5 },
  { t: 55.80, type: 'punch', d: 0.35, a: 0.06 },
  { t: 55.80, type: 'flash', d: 0.2, a: 0.35, c: [1, 0.1, 0.1] },
  { t: 57.45, type: 'punch', d: 0.25, a: 0.035 },
  { t: 58.80, type: 'punch', d: 0.3, a: 0.05 },
  { t: 58.80, type: 'shake', d: 0.25, a: 0.35 },
  { t: 61.35, type: 'glitch', d: 0.55, a: 1.4 },
  { t: 61.90, type: 'flash', d: 0.2, a: 0.4, c: [1, 1, 1] },
];

// Sound effects: name, time, gain (linear), optional dur
export const SFX = [
  // hook
  { s: 'riser', t: -0.0, g: 0.35, d: 0.95 },
  { s: 'clack', t: 0.95, g: 1.0 },
  { s: 'powerdown', t: 0.97, g: 0.85 },
  { s: 'boom', t: 0.95, g: 1.0 },
  { s: 'glitch', t: 0.98, g: 0.45 },
  { s: 'impact', t: 1.80, g: 0.9 },
  { s: 'pop', t: 2.75, g: 0.35 },
  { s: 'riser', t: 3.7, g: 0.4, d: 0.9 },

  // minute 1
  { s: 'whoosh', t: 4.45, g: 0.9 },
  { s: 'tickroll', t: 4.6, g: 0.45 },
  { s: 'zap', t: 5.30, g: 0.55 },
  { s: 'honk', t: 5.45, g: 0.6 },
  { s: 'honk2', t: 5.85, g: 0.45 },
  { s: 'swipe', t: 5.95, g: 0.5 },
  { s: 'clunk', t: 6.50, g: 1.0 },
  { s: 'swipe', t: 7.25, g: 0.5 },
  { s: 'click', t: 7.95, g: 0.7 },
  { s: 'click', t: 8.20, g: 0.55 },
  { s: 'click', t: 8.40, g: 0.6 },
  { s: 'click', t: 8.62, g: 0.5 },
  { s: 'whoosh_soft', t: 8.9, g: 0.6 },
  { s: 'riser', t: 10.1, g: 0.45, d: 0.9 },

  // stunde 3
  { s: 'whoosh', t: 10.85, g: 0.9 },
  { s: 'tickroll', t: 11.0, g: 0.5 },
  { s: 'beep', t: 11.7, g: 0.25 },
  { s: 'beep', t: 12.7, g: 0.25 },
  { s: 'batterylow', t: 13.15, g: 0.55 },
  { s: 'powerdown', t: 13.80, g: 0.8 },
  { s: 'glitch', t: 13.82, g: 0.5 },
  { s: 'stamp', t: 14.80, g: 0.85 },
  { s: 'stamp', t: 15.40, g: 0.85 },
  { s: 'stamp', t: 16.00, g: 1.0 },
  { s: 'error', t: 16.05, g: 0.35 },
  { s: 'swipe', t: 16.8, g: 0.45 },
  { s: 'click', t: 18.0, g: 0.7 },
  { s: 'riser', t: 18.6, g: 0.45, d: 0.9 },

  // stunde 12
  { s: 'whoosh', t: 19.35, g: 0.9 },
  { s: 'tickroll', t: 19.5, g: 0.5 },
  { s: 'pop', t: 20.15, g: 0.45 },
  { s: 'stamp', t: 21.05, g: 0.8 },
  { s: 'swipe', t: 22.0, g: 0.45 },
  { s: 'zap', t: 22.8, g: 0.45 },
  { s: 'error', t: 23.60, g: 0.6 },
  { s: 'pop', t: 24.35, g: 0.4 },
  { s: 'error', t: 25.00, g: 0.6 },
  { s: 'cash', t: 25.80, g: 0.5 },
  { s: 'impact', t: 27.35, g: 0.8 },
  { s: 'riser', t: 27.6, g: 0.45, d: 0.9 },

  // stunde 24
  { s: 'whoosh', t: 28.35, g: 0.9 },
  { s: 'tickroll', t: 28.5, g: 0.5 },
  { s: 'scan', t: 28.6, g: 0.35 },
  { s: 'gurgle', t: 29.95, g: 0.7, d: 1.6 },
  { s: 'stamp', t: 30.5, g: 0.7 },
  { s: 'stamp', t: 31.6, g: 0.75 },
  { s: 'pop', t: 32.45, g: 0.45 },
  { s: 'flush', t: 33.0, g: 0.55 },
  { s: 'impact', t: 33.85, g: 0.85 },
  { s: 'riser', t: 34.6, g: 0.45, d: 0.9 },

  // stunde 48
  { s: 'whoosh', t: 35.35, g: 0.9 },
  { s: 'tickroll', t: 35.5, g: 0.5 },
  { s: 'hum', t: 35.5, g: 0.45, d: 4.1 },
  { s: 'pop', t: 36.15, g: 0.4 },
  { s: 'gauge', t: 37.85, g: 0.6 },
  { s: 'whoosh', t: 39.45, g: 0.9 },
  { s: 'wind', t: 39.6, g: 0.35, d: 3.9 },
  { s: 'hazard', t: 40.0, g: 0.3, d: 3.3 },
  { s: 'pop', t: 41.15, g: 0.4 },
  { s: 'stamp', t: 42.35, g: 0.8 },
  { s: 'riser', t: 42.6, g: 0.45, d: 0.9 },

  // stunde 72
  { s: 'whoosh', t: 43.35, g: 0.9 },
  { s: 'tickroll', t: 43.5, g: 0.5 },
  { s: 'flicker', t: 43.6, g: 0.35, d: 2.4 },
  { s: 'stamp', t: 44.2, g: 0.7 },
  { s: 'gauge', t: 45.15, g: 0.45 },
  { s: 'boom', t: 46.10, g: 0.6 },
  { s: 'knock', t: 46.40, g: 1.0 },
  { s: 'knock', t: 46.72, g: 1.0 },
  { s: 'knock', t: 47.04, g: 1.1 },
  { s: 'heartbeat', t: 47.6, g: 0.75, d: 3.4 },
  { s: 'glitch', t: 49.35, g: 0.35 },
  { s: 'subdrop', t: 50.3, g: 0.8 },

  // outro
  { s: 'whoosh_soft', t: 50.95, g: 0.6 },
  { s: 'pop', t: 52.10, g: 0.3 },
  { s: 'impact', t: 52.80, g: 0.95 },
  { s: 'swipe', t: 53.75, g: 0.45 },
  { s: 'impact', t: 55.80, g: 1.0 },
  { s: 'whoosh_soft', t: 56.6, g: 0.55 },
  { s: 'pop', t: 56.75, g: 0.5 },
  { s: 'swipe', t: 58.25, g: 0.45 },
  { s: 'impact', t: 58.80, g: 0.7 },
  { s: 'tickroll', t: 59.0, g: 0.3 },
  { s: 'riser', t: 59.6, g: 0.6, d: 1.75 },
  { s: 'rewind', t: 61.35, g: 0.7 },
  { s: 'boom', t: 61.90, g: 0.7 },
];

// Music bed: tension drone, which stops at the loop point so the loop feels seamless
export const MUSIC = { start: 0, end: 63.0, gain: 0.15 };
