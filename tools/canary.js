// Проверка, что сайт расписания всё ещё отдаёт разметку, которую понимает парсер.
// Запускается по расписанию в GitHub Actions: если вёрстку на сайте переделают,
// это выяснится здесь, а не в приложении на телефоне.
//
// Запуск: node tools/canary.js [id_schedule] [id_edu_group]

const http = require('http');
const parse = require('./parse.js');

const HOST = '89.249.130.60';
const PORT = 7085;
const SCHEDULE_ID = process.argv[2] || '116';
const GROUP_ID = process.argv[3] || '3281';

function get(path) {
  return new Promise((resolve, reject) => {
    const req = http.get({ host: HOST, port: PORT, path, timeout: 20000 }, res => {
      if (res.statusCode !== 200) {
        res.resume();
        return reject(new Error('HTTP ' + res.statusCode));
      }
      let body = '';
      res.setEncoding('utf8');
      res.on('data', c => (body += c));
      res.on('end', () => resolve(body));
    });
    req.on('timeout', () => req.destroy(new Error('таймаут запроса')));
    req.on('error', reject);
  });
}

function checkStructure(schedule) {
  const problems = [];
  const lessons = schedule.days.flatMap(d => d.weeks.flatMap(w => w.lessons));

  if (!schedule.title) problems.push('не разобралось название группы');
  if (schedule.days.length === 0) problems.push('не найдено ни одного учебного дня');
  if (lessons.length === 0) problems.push('не найдено ни одного занятия');

  const noName = lessons.filter(l => !l.name).length;
  const noRoom = lessons.filter(l => !l.room).length;
  const noTeacher = lessons.filter(l => !l.teacher).length;
  const badTime = lessons.filter(l => !/^\d{2}:\d{2}-\d{2}:\d{2}$/.test(l.time)).length;

  if (noName) problems.push(noName + ' занятий без названия предмета');
  if (noRoom) problems.push(noRoom + ' занятий без кабинета');
  if (noTeacher) problems.push(noTeacher + ' занятий без преподавателя');
  if (badTime) problems.push(badTime + ' занятий с нераспознанным временем');

  const weeks = new Set(schedule.days.flatMap(d => d.weeks.map(w => w.label.replace(/\s*\(текущая\)/, ''))));
  if (!weeks.has('1-я неделя')) problems.push('пропал блок «1-я неделя»');
  if (!schedule.days.some(d => d.weeks.some(w => w.current))) {
    problems.push('сервер не отметил ни одну неделю текущей');
  }

  return { problems, lessons };
}

(async () => {
  const path = `/viewer/edu-group-schedule?id_schedule=${SCHEDULE_ID}&id_edu_group=${GROUP_ID}`;
  let html;

  try {
    html = await get(path);
  } catch (e) {
    // Сервер учебного заведения может быть недоступен снаружи или лежать —
    // это не поломка парсера, поэтому проверку просто пропускаем.
    console.log('ПРОПУЩЕНО: сайт недоступен (' + e.message + ')');
    process.exit(0);
  }

  let schedule;
  try {
    schedule = parse(html);
  } catch (e) {
    console.error('ОШИБКА: парсер упал — ' + e.message);
    process.exit(1);
  }

  const { problems, lessons } = checkStructure(schedule);

  console.log('Группа:    ' + schedule.title);
  console.log('Семестр:   ' + schedule.semester);
  console.log('Дней:      ' + schedule.days.length);
  console.log('Занятий:   ' + lessons.length);
  console.log('Со ссылкой на курс: ' + lessons.filter(l => l.courseUrl).length);

  if (problems.length) {
    console.error('\nРазметка сайта изменилась — парсер требует правки:');
    problems.forEach(p => console.error('  - ' + p));
    process.exit(1);
  }

  console.log('\nВсё в порядке: структура страницы не изменилась.');
})();
