import fs from 'node:fs';
import { CAPTIONS, CAPTION_END } from './src/timeline.js';
const ts = (s) => { const ms = Math.round(s * 1000); const h = String(Math.floor(ms / 3600000)).padStart(2, '0'); const m = String(Math.floor(ms / 60000) % 60).padStart(2, '0'); const se = String(Math.floor(ms / 1000) % 60).padStart(2, '0'); return `${h}:${m}:${se},${String(ms % 1000).padStart(3, '0')}`; };
let srt = '';
CAPTIONS.forEach(([t, txt], i) => { const end = i + 1 < CAPTIONS.length ? CAPTIONS[i + 1][0] : CAPTION_END; srt += `${i + 1}\n${ts(t)} --> ${ts(end - 0.02)}\n${txt}\n\n`; });
fs.writeFileSync('out/untertitel.srt', srt);
console.log('wrote out/untertitel.srt');
