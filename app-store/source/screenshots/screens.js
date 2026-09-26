const ic = (n, s, c = 'currentColor', extra = '') =>
  `<span class="i" style="width:${s}px;height:${s}px;background:${c};-webkit-mask-image:url('sym/${n}.png');${extra}"></span>`;
/* ---------------- App screens (all sizes in iOS points) ---------------- */
const statusBar = (t = '11:15', dark = false) => `
  <div class="island"></div>
  <div class="status"><div class="time">${t}</div>
    <div class="right" style="color:#fff">${ic('cellularbars', 18)}${ic('wifi', 17)}${ic('battery.100percent', 27)}</div></div>`;

const tabBar = (on) => `
  <div class="tabbar">
    ${[['house.fill','Home'],['calendar','Schedule'],['gearshape.fill','Rules']].map(([s,l]) =>
      `<div class="tab ${on===l?'on':''}">${ic(s, 22)}<span>${l}</span></div>`).join('')}
  </div>`;

const otterPeek = (w = 88) => `<img src="OtterOverlook.png" style="position:absolute;width:${w}px;right:20px;top:-70px;z-index:2">`;

// Week data: fraction of 4 AM – 12 PM window
const f = (h, m) => ((h + m / 60) - 4) / 8;
const WEEK = [
  { d: 'S' },
  { d: 'M', a: f(7,55), e: f(9,0), primary: true },
  { d: 'T', a: f(9,45), e: f(11,0) },
  { d: 'W', a: f(6,40), e: f(8,0) },
  { d: 'Th', a: f(7,55), e: f(9,0) },
  { d: 'F', a: f(7,30) },
  { d: 'S' },
];
function weekColumns(colW = 44, gap = 12, h = 236) {
  const y = fr => 18 + (h - 36) * fr;
  const dot = (fr, c, pr) => { const s = pr ? 18 : 16, pad = pr ? 4 : 3;
    return `<div style="position:absolute;left:50%;top:${y(fr)}px;width:${s}px;height:${s}px;margin:-${s/2}px 0 0 -${s/2}px;border-radius:50%;background:#121212;padding:${pad}px;box-shadow:0 0 ${pr?6:3}px ${c}59"><div style="width:100%;height:100%;border-radius:50%;background:${c}"></div></div>`; };
  return `<div class="row" style="gap:${gap}px;padding:0 6px;align-items:flex-start">` + WEEK.map(w => {
    const pr = !!w.primary;
    const line = (w.a != null && w.e != null) ? `<div style="position:absolute;left:50%;margin-left:-1px;top:${y(Math.min(w.a,w.e))}px;height:${y(Math.max(w.a,w.e))-y(Math.min(w.a,w.e))}px;width:0;border-left:2px dashed rgba(255,158,10,.85)"></div>` : '';
    return `<div style="flex:1;display:flex;flex-direction:column;align-items:center;gap:10px">
      <div style="height:18px;font-size:12px;font-weight:${pr?700:600};color:${pr?'var(--t1)':'var(--t2)'}">${w.d}</div>
      <div style="position:relative;width:${colW}px;height:${h}px;border-radius:${colW}px;background:rgba(179,92,20,${pr?.16:.09});box-shadow:inset 0 0 0 ${pr?2.4:1.8}px rgba(179,92,20,${pr?.92:.68})">
        ${line}${w.a!=null?dot(w.a,'#ff9e0a',pr):''}${w.e!=null?dot(w.e,'#0a85ff',pr):''}
      </div></div>`; }).join('') + `</div>`;
}

function heroCard(opts = {}) {
  return `<div class="card">
    <div class="row"><div style="font-size:20px;font-weight:600">Next Alarm</div><div class="sp"></div>${ic('sparkles', 13, 'rgba(255,158,10,.6)')}</div>
    <div style="margin-top:12px;font-size:15px;font-weight:500;color:var(--t2)">${opts.until || 'In 8 hours, 40 minutes'}</div>
    <div class="rounded" style="margin-top:8px;font-size:72px;font-weight:700;letter-spacing:-0.01em;line-height:1.05;font-variant-numeric:tabular-nums">7:55 AM</div>
    <div class="row" style="margin-top:14px;gap:8px">${ic('calendar', 18, 'var(--blue)')}<div style="font-size:17px;font-weight:600">Biology Class</div><div class="sp"></div><div style="font-size:15px;font-weight:500;color:var(--t2)">9:00 AM</div></div>
  </div>`;
}

function dashboard(t = '11:15') {
  return `<div class="app"><div class="app-bg"></div>${statusBar(t)}
    <div style="position:absolute;left:16px;right:16px;top:62px">
      <div class="rounded" style="font-size:26px;font-weight:700;color:var(--orange);padding-left:10px;transform:translateY(15px);height:31px">EarlyOtter</div>
      <div style="position:relative;margin-top:28px">${otterPeek()}${heroCard()}</div>
      <div class="card" style="margin-top:14px">
        <div style="font-size:17px;font-weight:600;margin-bottom:14px">Oct 4 - 10</div>
        <div style="height:270px">${weekColumns()}</div>
      </div>
      <div style="margin-top:12px;border-top:.5px solid rgba(82,69,51,.75);padding-top:12px;text-align:center;font-size:13px;font-weight:500;color:var(--t3)" class="row"><div class="sp"></div>Send feedback<div class="sp"></div></div>
    </div>
    ${tabBar('Home')}</div>`;
}

function detailsSheet() {
  const tl = (s, l, v) => `<div class="row" style="gap:10px;padding:5px 0">${ic(s, 17, 'var(--t3)')}<div style="font-size:16px;color:var(--t2)">${l}</div><div class="sp"></div><div style="font-size:16px;font-weight:500">${v}</div></div>`;
  const hr = `<div style="height:.5px;background:rgba(255,255,255,.14);margin:14px 0"></div>`;
  return `<div class="app"><div class="app-bg"></div>${statusBar('11:16')}
    <div style="position:absolute;left:16px;right:16px;top:62px;filter:brightness(.55)">
      <div class="rounded" style="font-size:26px;font-weight:700;color:var(--orange);padding-left:10px;transform:translateY(15px);height:31px">EarlyOtter</div>
      <div style="position:relative;margin-top:28px">${otterPeek()}${heroCard()}</div>
    </div>
    <div style="position:absolute;inset:0;background:rgba(0,0,0,.25)"></div>
    <div style="position:absolute;left:0;right:0;top:360px;bottom:0;border-radius:38px 38px 0 0;overflow:hidden;box-shadow:0 -10px 40px rgba(0,0,0,.5)">
      <div class="app-bg"></div>
      <div style="position:absolute;left:50%;top:6px;width:36px;height:5px;margin-left:-18px;border-radius:3px;background:rgba(255,255,255,.3)"></div>
      <div style="position:relative;padding:32px 20px 0">
        <div style="font-size:22px;font-weight:700">Monday, October 5</div>
        <div style="margin-top:24px;background:var(--surface);border-radius:24px;padding:20px">
          <div class="row" style="gap:10px">${ic('alarm.fill', 19, 'var(--orange)')}
            <div><div style="font-size:17px;font-weight:600">Wake Time</div><div style="font-size:12px;color:var(--t2);margin-top:2px">Dawn&nbsp; •&nbsp; Snooze 10m</div></div>
            <div class="sp"></div><div style="font-size:20px;font-weight:600">7:55 AM</div></div>
          ${hr}${tl('cup.and.saucer.fill','Prep Time','35m')}${tl('car.fill','Commute','30m')}${hr}
          <div class="row" style="gap:10px">${ic('calendar', 18, 'var(--blue)')}<div style="font-size:17px;font-weight:600">Biology Class</div><div class="sp"></div><div style="font-size:20px;font-weight:600">9:00 AM</div></div>
        </div>
        <div class="row" style="margin-top:16px;gap:10px;padding:14px 16px;border-radius:16px;background:rgba(48,209,89,.1)">${ic('checkmark', 15, 'rgb(48,209,89)')}<div style="font-size:15px;font-weight:600">Alarm scheduled</div></div>
        <div style="margin-top:20px;height:52px;border-radius:16px;background:var(--orange);color:#000;font-size:17px;font-weight:600;display:flex;align-items:center;justify-content:center;gap:8px">Edit Alarm</div>
      </div>
    </div></div>`;
}

function rulesScreen() {
  const rule = (name, prep, com, def) => `
    <div class="row" style="gap:14px;padding:16px;border-radius:24px;background:var(--surface);margin-bottom:8px">
      <div style="width:42px;height:42px;border-radius:50%;background:${def?'rgba(255,158,10,.15)':'var(--raised)'};display:flex;align-items:center;justify-content:center">${ic(def?'star.fill':'slider.horizontal.3', 18, 'var(--orange)')}</div>
      <div><div style="font-size:17px;font-weight:600">${name}</div>
        <div class="row" style="gap:12px;margin-top:6px;font-size:12px;font-weight:500;color:var(--t2)">
          <span class="row" style="gap:4px">${ic('cup.and.saucer.fill', 12, 'var(--t3)')}${prep}m prep</span>
          <span class="row" style="gap:4px">${ic('car.fill', 12, 'var(--t3)')}${com}m commute</span></div></div>
      <div class="sp"></div>${ic('chevron.right', 12, 'var(--t3)')}
    </div>`;
  return `<div class="app"><div class="app-bg"></div>${statusBar('11:18')}
    <div style="position:absolute;right:16px;top:58px;width:44px;height:44px;border-radius:50%;background:rgba(60,60,62,.7);box-shadow:inset 0 0 0 .5px rgba(255,255,255,.15);display:flex;align-items:center;justify-content:center">${ic('gearshape.fill', 19, '#fff')}</div>
    <div style="position:absolute;left:16px;right:16px;top:104px">
      <div style="font-size:34px;font-weight:700;padding-left:4px;letter-spacing:.01em">Rules</div>
      <div class="row" style="gap:12px;margin-top:14px;padding:18px 16px;border-radius:28px;background:var(--surface)">
        <div style="width:40px;height:40px;border-radius:50%;background:var(--raised);display:flex;align-items:center;justify-content:center">${ic('line.3.horizontal.decrease.circle.fill', 18, 'var(--orange)')}</div>
        <div style="min-width:0"><div style="font-size:17px;font-weight:600">Ignored Events & Filters</div><div style="font-size:15px;color:var(--t2);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;margin-top:2px">Configure which events are always skip…</div></div>
      </div>
      <div style="margin:26px 0 10px 4px;font-size:12px;font-weight:700;letter-spacing:.1em;color:var(--t2)">RULES</div>
      ${rule('Default', 45, 15, true)}${rule('Class', 35, 30)}${rule('Flights', 90, 45)}${rule('Gym', 10, 15)}${rule('Work', 40, 25)}
      <div class="row" style="gap:8px;justify-content:center;margin-top:16px;padding:14px;border-radius:16px;background:var(--surface);font-size:17px;font-weight:600">${ic('plus.circle.fill', 19, 'var(--orange)')}Add Rule</div>
    </div>
    ${tabBar('Rules')}</div>`;
}

function scheduleScreen() {
  const day = (name, mode, time) => {
    const auto = mode === 'auto', off = mode === 'off';
    const accent = auto ? 'var(--orange)' : 'rgba(255,255,255,.18)';
    const trail = time ? `<div class="rounded" style="font-size:19px;font-weight:700;color:var(--orange);font-variant-numeric:tabular-nums">${time}</div>`
      : ic('moon.zzz.fill', 21, 'rgba(255,255,255,.4)');
    return `<div class="row" style="gap:14px;padding:14px 16px;border-radius:18px;background:var(--surface);box-shadow:inset 0 0 0 1px ${auto?'rgba(255,158,10,.4)':'rgba(82,69,51,.38)'};margin-bottom:8px;opacity:${off?.55:1}">
      <div style="width:4px;height:30px;border-radius:2px;background:${accent}"></div>
      <div class="rounded" style="font-size:17px;font-weight:700;color:${off?'var(--t3)':'var(--t1)'}">${name}</div>
      <div class="sp"></div>${trail}${ic('chevron.right', 10, 'var(--t3)')}</div>`;
  };
  return `<div class="app"><div class="app-bg"></div>${statusBar('11:20')}
    <div style="position:absolute;left:20px;right:20px;top:104px">
      <div style="font-size:34px;font-weight:700;letter-spacing:.01em">Schedule</div>
      <div style="margin:22px 0 10px;font-size:12px;font-weight:700;letter-spacing:.1em;color:var(--t2)">YOUR WEEK</div>
      ${day('Sunday','off')}${day('Monday','auto','7:30 AM')}${day('Tuesday','auto','7:30 AM')}${day('Wednesday','auto','7:30 AM')}${day('Thursday','auto','7:30 AM')}${day('Friday','auto','8:00 AM')}${day('Saturday','off')}
    </div>
    ${tabBar('Schedule')}</div>`;
}

function lockScreen() {
  return `<div class="app" style="background:#06102b">
    <img src="OtterSwim.png" style="position:absolute;height:100%;left:-330px;top:0;opacity:.95">
    <div style="position:absolute;inset:0;background:linear-gradient(180deg,rgba(3,8,26,.35),rgba(3,8,26,.05) 40%,rgba(3,8,26,.75) 100%)"></div>
    <div class="island" style="width:126px"></div>
    <div class="status"><div class="time"></div><div class="right" style="color:#fff">${ic('cellularbars', 18)}${ic('wifi', 17)}${ic('battery.100percent', 27)}</div></div>
    <div style="position:absolute;left:0;right:0;top:66px;text-align:center;color:#fff">
      <div class="row" style="justify-content:center;gap:6px;font-size:20px;font-weight:600;opacity:.9">${ic('lock.fill', 15, '#fff')}</div>
      <div style="font-size:21px;font-weight:600;margin-top:6px;opacity:.92">Monday, October 5</div>
      <div class="rounded" style="font-size:112px;font-weight:700;line-height:1;margin-top:0;letter-spacing:-0.02em;text-shadow:0 4px 30px rgba(0,0,0,.25)">7:55</div>
    </div>
    <div style="position:absolute;left:14px;right:14px;bottom:118px;border-radius:40px;padding:22px 20px 20px;background:rgba(30,26,24,.55);backdrop-filter:blur(30px) saturate(1.4);box-shadow:inset 0 0 0 .5px rgba(255,255,255,.2)">
      <div class="row" style="gap:10px">
        <div style="width:30px;height:30px;border-radius:50%;background:rgba(255,158,10,.25);display:flex;align-items:center;justify-content:center">${ic('alarm.fill', 16, 'var(--orange)')}</div>
        <div style="font-size:15px;font-weight:600;color:rgba(255,255,255,.7)">Alarm</div>
      </div>
      <div style="font-size:26px;font-weight:700;line-height:1.15;margin-top:12px;color:#fff">Rise and shine!<br><span style="color:rgba(255,255,255,.72);font-weight:600">Biology Class</span></div>
      <div class="row" style="gap:12px;margin-top:22px">
        <div style="flex:1;height:58px;border-radius:29px;background:var(--orange);color:#1b0e00;font-size:19px;font-weight:700;display:flex;align-items:center;justify-content:center;gap:8px">${ic('zzz', 17, '#1b0e00')}Snooze</div>
        <div style="flex:1;height:58px;border-radius:29px;background:rgba(255,255,255,.22);color:#fff;font-size:19px;font-weight:700;display:flex;align-items:center;justify-content:center">Stop</div>
      </div>
    </div>
  </div>`;
}


function ruleEditor() {
  const chip = t => `<span class="row" style="display:inline-flex;gap:4px;padding:6px 10px;border-radius:20px;background:var(--raised);font-size:15px;font-weight:500;margin:0 6px 6px 0">${t}${ic('xmark.circle.fill', 14, 'var(--t3)')}</span>`;
  const label = t => `<div style="font-size:12px;font-weight:700;letter-spacing:.1em;color:var(--t2);margin:0 0 10px 4px">${t}</div>`;
  const stepper = (l, v) => `<div class="row" style="padding:12px 16px;gap:10px"><div style="font-size:17px">${l}</div><div class="sp"></div>
      <div style="font-size:17px;font-weight:600;color:var(--orange);font-variant-numeric:tabular-nums">${v} min</div>
      <div class="row" style="height:32px;border-radius:16px;background:rgba(118,118,128,.24);font-size:20px;color:#fff"><span style="width:47px;text-align:center">−</span><span style="width:1px;height:18px;background:rgba(255,255,255,.2)"></span><span style="width:47px;text-align:center">+</span></div></div>`;
  return `<div class="app"><div class="app-bg"></div>${statusBar('11:18')}
    <div class="row" style="position:absolute;left:16px;right:16px;top:58px;height:44px">
      <div style="width:44px;height:44px;border-radius:50%;background:rgba(60,60,62,.7);box-shadow:inset 0 0 0 .5px rgba(255,255,255,.15);display:flex;align-items:center;justify-content:center">${ic('chevron.right', 17, '#fff', 'transform:scaleX(-1)')}</div>
      <div class="sp" style="text-align:center;font-size:17px;font-weight:600">Class</div>
      <div style="height:44px;padding:0 16px;border-radius:22px;background:rgba(60,60,62,.7);box-shadow:inset 0 0 0 .5px rgba(255,255,255,.15);display:flex;align-items:center;font-size:17px;font-weight:600;color:var(--orange)">Save</div>
    </div>
    <div style="position:absolute;left:16px;right:16px;top:118px">
      <div style="background:var(--surface);border-radius:16px">
        <div class="row" style="padding:12px 16px"><div style="font-size:17px;font-weight:500">Enable Rule</div><div class="sp"></div>
          <div style="width:51px;height:31px;border-radius:16px;background:var(--orange);position:relative"><div style="position:absolute;right:2px;top:2px;width:27px;height:27px;border-radius:50%;background:#fff;box-shadow:0 2px 4px rgba(0,0,0,.2)"></div></div></div>
        <div style="height:.5px;background:rgba(255,255,255,.14);margin-left:16px"></div>
        <div class="row" style="padding:14px 16px"><div style="font-size:17px">Name</div><div class="sp"></div><div style="font-size:17px;color:var(--t2)">Class</div></div>
      </div>
      <div class="row" style="margin-top:18px">
        <div style="flex:1;text-align:center;font-size:15px;font-weight:700">Trigger Criteria<div style="height:3px;border-radius:2px;background:var(--orange);margin:10px auto 0;width:118px"></div></div>
        <div style="flex:1;text-align:center;font-size:15px;color:var(--t2)">Alarm<div style="height:3px;border-radius:2px;background:var(--raised);margin-top:10px"></div></div>
      </div>
      <div style="margin-top:22px">${label('CONDITIONS')}
        <div class="row" style="gap:8px;margin-bottom:10px">${ic('text.magnifyingglass', 16, 'var(--orange)')}<div style="font-size:15px;font-weight:600">Title contains</div></div>
        <div>${chip('class')}${chip('lecture')}${chip('lab')}</div>
        <div class="row" style="margin-top:4px;padding:12px;border-radius:10px;background:var(--surface);font-size:15px;color:var(--t3)">keyword<div class="sp"></div>${ic('plus.circle.fill', 18, 'var(--orange)')}</div>
        <div class="row" style="gap:8px;margin:16px 0 10px">${ic('mappin', 16, 'var(--orange)')}<div style="font-size:15px;font-weight:600">Location contains</div></div>
        <div>${chip('Campus')}</div>
      </div>
      <div style="margin-top:20px">${label('TIMING')}
        <div style="background:var(--surface);border-radius:16px">${stepper('Prep time', 35)}<div style="height:.5px;background:rgba(255,255,255,.14);margin-left:16px"></div>${stepper('Commute', 30)}</div>
      </div>
    </div></div>`;
}
