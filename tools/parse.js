const strip = s => s.replace(/<[^>]+>/g, '')
  .replace(/&nbsp;/g, ' ').replace(/&amp;/g, '&')
  .replace(/&quot;/g, '"').replace(/&#\d+;/g, '')
  .replace(/\s+/g, ' ').trim();

// Subject cell: <b>ROOM</b>, <b>KIND</b>, [<b><a href=COURSE>]NAME[</a></b>], <b><a id_teacher>TEACHER</a></b>
// The name may be plain text OR wrapped in a bold Moodle course link, and may itself contain commas —
// so split on the <b> segments, never on commas.
function parseSubject(cell) {
  let teacher = null, teacherId = null, courseUrl = null;
  const parts = [];
  for (const b of cell.matchAll(/<b>([\s\S]*?)<\/b>/g)) {
    const inner = b[1];
    const t = inner.match(/<a[^>]*id_teacher=(\d+)[^>]*>([\s\S]*?)<\/a>/);
    if (t) { teacherId = t[1]; teacher = strip(t[2]); continue; }
    const c = inner.match(/<a[^>]*href="(https?:\/\/[^"]+)"[^>]*>([\s\S]*?)<\/a>/);
    if (c) { courseUrl = c[1].replace(/&amp;/g, '&'); parts.push(strip(c[2])); continue; }
    const v = strip(inner);
    if (v) parts.push(v);
  }
  const room = parts[0] || null;
  const kind = parts[1] || null;
  const name = parts.length >= 3
    ? parts.slice(2).join(', ')
    : strip(cell.replace(/<b>[\s\S]*?<\/b>/g, '')).replace(/^[,\s]+|[,\s]+$/g, '');
  return { room, kind, name, teacher, teacherId, courseUrl };
}

function parse(html) {
  const title = strip((html.match(/<title>([^<]*)<\/title>/) || [])[1] || '');
  const semester = strip((html.match(/<a href="\/viewer\/view\/\d+">([^<]*)<\/a>/) || [])[1] || '');
  const days = [];
  const stats = { skipped: 0 };

  const dayRe = /<h2 id="link(\d+)"[^>]*>\s*<b>([^<]+)<\/b>\s*<\/h2>/g;
  const marks = [];
  let m;
  while ((m = dayRe.exec(html))) marks.push({ idx: m.index, end: dayRe.lastIndex, name: m[2].trim() });

  marks.forEach((mk, i) => {
    const body = html.slice(mk.end, i + 1 < marks.length ? marks[i + 1].idx : html.length);
    const weeks = [];
    const panelRe = /<h3 class="panel-title">\s*(?:<b>)?\s*([^<]+?)\s*(?:<\/b>)?\s*<\/h3>([\s\S]*?)<\/table>/g;
    let p;
    while ((p = panelRe.exec(body))) {
      const lessons = [];
      // пара/время cells carry rowspan, so a continuation row has fewer <td>s — carry them forward
      let lastPair = '', lastTime = '';
      for (const r of p[2].matchAll(/<tr class="([^"]*)">([\s\S]*?)<\/tr>/g)) {
        const tds = [...r[2].matchAll(/<td[^>]*>([\s\S]*?)<\/td>/g)].map(t => t[1]);
        let pair, time, subgroup, subject;
        if (tds.length >= 4) {
          [pair, time, subgroup, subject] = [strip(tds[0]), strip(tds[1]), strip(tds[2]), tds[3]];
          lastPair = pair; lastTime = time;
        } else if (tds.length === 2) {          // continuation under a rowspan
          [pair, time, subgroup, subject] = [lastPair, lastTime, strip(tds[0]), tds[1]];
        } else { if (strip(r[2])) stats.skipped++; continue; }
        if (!strip(subject)) continue;
        lessons.push({ pair, time, subgroup: subgroup || null, ...parseSubject(subject), nowFlag: r[1].trim() === 'warning' });
      }
      weeks.push({ label: p[1].trim(), current: /текущая/.test(p[1]), lessons });
    }
    days.push({ name: mk.name, weeks });
  });
  return { title, semester, days, stats };
}
module.exports = parse;
