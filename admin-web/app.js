// Веб-админка гитарной школы: маршруты по #адресу и страницы.
import * as api from './api.js';
import { SCHOOL_NAME } from './config.js';
import {
  LEVELS, MONTHS, TYPES, copy, date, downloadCsv, duration, flash, html, icons, money, raw,
  statusBadge, takeFlash, videoDuration, whatsappLink,
} from './ui.js';

const root = document.getElementById('app');
const mount = (markup) => { root.innerHTML = String(markup); };
const $ = (sel) => root.querySelector(sel);
const $$ = (sel) => [...root.querySelectorAll(sel)];
const go = (hash) => { if (location.hash === hash) router(); else location.hash = hash; };

let uploadsInProgress = 0;

// Обработчики на #app живут, пока открыта страница: при переходе снимаются.
let viewAbort = new AbortController();
const viewSignal = () => viewAbort.signal;
window.addEventListener('beforeunload', (e) => { if (uploadsInProgress > 0) e.preventDefault(); });

// Кнопки «Скопировать» на любой странице.
root.addEventListener('click', (e) => {
  const button = e.target.closest('[data-copy]');
  if (button) copy(button, button.dataset.copy);
});

// ------------------------------------------------------------------ маршруты

const routes = [
  [/^#\/login$/, loginView],
  [/^#\/?$/, dashboardView],
  [/^#\/products$/, productsView],
  [/^#\/products\/new$/, newProductView],
  [/^#\/products\/([0-9a-f-]{36})$/, editorView],
  [/^#\/keys$/, keysView],
];

async function router() {
  const [path, query] = (location.hash || '#/').split('?');
  const params = new URLSearchParams(query || '');
  if (path !== '#/login' && !(await api.currentUser())) {
    location.hash = '#/login';
    return;
  }
  const route = routes.find(([re]) => re.test(path));
  if (!route) { location.hash = '#/'; return; }
  viewAbort.abort();
  viewAbort = new AbortController();
  try {
    await route[1]({ params, args: path.match(route[0]).slice(1) });
  } catch (err) {
    console.error(err);
    mount(page('Ошибка', null, html`
      <section class="card">
        <h2>Не получилось</h2>
        <p>${err.message || String(err)}</p>
        <a class="button" href="#/">В админ-панель</a>
      </section>`));
  }
}
window.addEventListener('hashchange', router);
router();

function page(title, active, body) {
  document.title = `${title} · Админ-панель`;
  const link = (key, href, label, icon) => html`
    <a class="nav-link ${active === key ? 'active' : ''}" href="${href}"
       ${active === key ? raw('aria-current="page"') : ''}>${icon}<span>${label}</span></a>`;
  return html`
    <div class="admin">
      <aside class="sidebar">
        <div class="brand">
          <div class="brand-logo" aria-hidden="true">${icons.guitar}</div>
          <div><div class="brand-name">${SCHOOL_NAME}</div><div class="brand-sub">Админ-панель</div></div>
        </div>
        <nav>
          ${link('dashboard', '#/', 'Обзор', icons.chart)}
          ${link('products', '#/products', 'Продукты', icons.music)}
          ${link('keys', '#/keys', 'Ключи', icons.key)}
        </nav>
        <form class="logout" id="logout"><button class="ghost" type="submit">Выйти</button></form>
      </aside>
      <main class="content">${takeFlash()}${body}</main>
    </div>`;
}

/** После mount страницы с меню: кнопка «Выйти». */
function bindShell() {
  $('#logout')?.addEventListener('submit', async (e) => {
    e.preventDefault();
    await api.signOut();
    go('#/login');
  });
}

function show(markup) {
  mount(markup);
  bindShell();
}

/** Кнопка занята, пока идёт действие; ошибка — сообщением вверху. */
async function busy(button, action) {
  const label = button?.textContent;
  if (button) { button.disabled = true; button.textContent = 'Подождите…'; }
  try {
    await action();
  } catch (err) {
    flash(err.message || String(err), 'error');
    router();
  } finally {
    if (button?.isConnected) { button.disabled = false; button.textContent = label; }
  }
}

// ------------------------------------------------------------------ вход

async function loginView() {
  if ((await api.currentUser()) && (await api.isAdmin())) { go('#/'); return; }
  document.title = 'Вход · Админ-панель';
  mount(html`
    <main class="login">
      <form class="card" id="login">
        <div class="brand-logo" aria-hidden="true">${icons.guitar}</div>
        <h1>Админ-панель</h1>
        <p class="muted">${SCHOOL_NAME}</p>
        <p class="error" id="login-error" role="alert" hidden></p>
        <label>Почта<input type="email" name="email" autocomplete="username" required></label>
        <label>Пароль<input type="password" name="password" autocomplete="current-password" required></label>
        <button class="primary" type="submit">Войти</button>
      </form>
    </main>`);
  const form = $('#login');
  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    const button = form.querySelector('button');
    const error = $('#login-error');
    button.disabled = true;
    error.hidden = true;
    try {
      await api.signIn(form.email.value.trim(), form.password.value);
      go('#/');
    } catch (err) {
      error.textContent = err.message;
      error.hidden = false;
    } finally {
      button.disabled = false;
    }
  });
}

// ------------------------------------------------------------------ обзор

const PERIODS = { week: ['Неделя', 7, 'за 7 дней'], month: ['Месяц', 30, 'за 30 дней'], year: ['Год', 365, 'за год'] };

async function dashboardView({ params }) {
  const period = PERIODS[params.get('period')] ? params.get('period') : 'month';
  const [, days, caption] = PERIODS[period];
  const since = new Date(Date.now() - days * 86400e3).toISOString();

  const now = new Date();
  const months = Array.from({ length: 6 }, (_, i) => {
    const d = new Date(now.getFullYear(), now.getMonth() - 5 + i, 1);
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
  });
  const monthsSince = new Date(now.getFullYear(), now.getMonth() - 5, 1).toISOString();

  const [inPeriod, allTime, byMonth, top, recent, counts] = await Promise.all([
    api.totals(since), api.totals(null), api.salesByMonth(monthsSince),
    api.topProducts(since, 5), api.listSales({}), api.counts(),
  ]);
  const bars = months.map((m) => [m, Number(byMonth.find((r) => r.month === m)?.revenue ?? 0)]);
  const maxBar = Math.max(1, ...bars.map(([, v]) => v));
  const maxTop = Math.max(1, ...top.map((t) => Number(t.sales)));

  show(page('Обзор', 'dashboard', html`
    <header class="page-header">
      <div><h1>Обзор</h1><p class="muted">Продажи по выданным ключам</p></div>
      <nav class="segmented" aria-label="Период">
        ${Object.entries(PERIODS).map(([key, [label]]) => html`
          <a class="${key === period ? 'active' : ''}" href="#/?period=${key}">${label}</a>`)}
      </nav>
    </header>
    <section class="kpis">
      <div class="card kpi"><div class="kpi-label">Продажи</div>
        <div class="kpi-value">${inPeriod.sales}</div><div class="kpi-note">${caption}</div></div>
      <div class="card kpi"><div class="kpi-label">Выручка</div>
        <div class="kpi-value">${money(inPeriod.revenue)} <span>сомони</span></div><div class="kpi-note">${caption}</div></div>
      <div class="card kpi"><div class="kpi-label">Ученики</div>
        <div class="kpi-value">${counts.students}</div><div class="kpi-note">зарегистрировано в приложении</div></div>
      <div class="card kpi"><div class="kpi-label">Всего продаж</div>
        <div class="kpi-value">${allTime.sales}</div>
        <div class="kpi-note">${money(allTime.revenue)} сомони · активаций: ${counts.activations}</div></div>
    </section>
    <div class="grid-2">
      <section class="card">
        <div class="section-head"><h2>Выручка по месяцам</h2><span class="muted">сомони</span></div>
        <div class="bars" role="img" aria-label="Выручка за последние 6 месяцев">
          ${bars.map(([m, v]) => html`
            <div class="bar-col">
              <div class="bar-value">${money(v)}</div>
              <div class="bar" style="height:${Math.round((v * 100) / maxBar)}%"></div>
              <div class="bar-label">${MONTHS[Number(m.slice(5)) - 1]}</div>
            </div>`)}
        </div>
      </section>
      <section class="card">
        <h2>Лучшие продукты</h2>
        ${top.length === 0 ? html`<p class="muted">Пока нет продаж ${caption}.</p>` : ''}
        ${top.map((t) => html`
          <div class="top-row">
            <div class="top-text"><div class="top-title">${t.title}</div>
              <div class="muted">${t.sales} продаж · ${money(t.revenue)} сомони</div></div>
            <div class="meter"><div style="width:${Math.round((Number(t.sales) * 100) / maxTop)}%"></div></div>
          </div>`)}
      </section>
    </div>
    <section class="card">
      <div class="section-head"><h2>Последние ключи</h2><a href="#/keys">Все ключи →</a></div>
      ${recent.length === 0
        ? html`<p class="muted">Ключей ещё нет. Создайте первый в разделе <a href="#/keys">«Ключи»</a>.</p>`
        : html`<div class="table-wrap"><table>
            <thead><tr><th>Дата</th><th>Ученик</th><th>Продукт</th><th class="num">Сумма</th></tr></thead>
            <tbody>${recent.slice(0, 8).map((s) => html`
              <tr><td class="nowrap">${date(s.created_at)}</td>
                <td>${s.student || raw('<span class="muted">—</span>')}</td>
                <td>${s.products?.title}</td>
                <td class="num">${s.amount_somoni === null ? '—' : money(s.amount_somoni)}</td></tr>`)}
            </tbody></table></div>`}
    </section>`));
}

// ------------------------------------------------------------------ продукты

function coverThumb(path, size) {
  const url = api.coverUrl(path);
  return url
    ? html`<img class="thumb" src="${url}" alt="" width="${size}" height="${size}" loading="lazy">`
    : html`<span class="thumb thumb-empty" style="width:${size}px;height:${size}px" aria-hidden="true">${icons.guitar}</span>`;
}

async function productsView({ params }) {
  const type = TYPES[params.get('type')] ? params.get('type') : null;
  const items = await api.listProducts(type);
  const chip = (label, value) => html`
    <a class="${type === value ? 'active' : ''}" href="${value ? `#/products?type=${value}` : '#/products'}">${label}</a>`;

  show(page('Продукты', 'products', html`
    <header class="page-header">
      <div><h1>Продукты</h1><p class="muted">Курсы, альбомы песен и отдельные песни</p></div>
      <a class="button primary" href="#/products/new">Новый продукт</a>
    </header>
    <nav class="segmented" aria-label="Тип">
      ${chip('Все', null)}${chip('Курсы', 'course')}${chip('Альбомы', 'song_album')}${chip('Песни', 'single')}
    </nav>
    <section class="card">
      ${items.length === 0
        ? html`<div class="empty"><p>Продуктов пока нет.</p><a class="button primary" href="#/products/new">Создать первый</a></div>`
        : html`<div class="table-wrap"><table class="products">
            <thead><tr><th>Название</th><th>Тип</th><th class="num">№ ключа</th><th class="num">Видео</th>
              <th class="num">Цена</th><th class="num">Продажи</th><th>Статус</th></tr></thead>
            <tbody>${items.map((p) => {
              const videos = p.lessons.filter((l) => l.video_key).length;
              return html`
                <tr class="clickable">
                  <td><a class="product-cell" href="#/products/${p.id}">${coverThumb(p.cover_path, 40)}
                    <span><strong>${p.title}</strong>${p.subtitle ? html`<br><span class="muted">${p.subtitle}</span>` : ''}</span></a></td>
                  <td>${TYPES[p.type].label}</td>
                  <td class="num">${p.activation_number}</td>
                  <td class="num ${videos < p.lessons.length ? 'warn' : ''}">${videos} / ${p.lessons.length}</td>
                  <td class="num">${p.price_somoni === null ? '—' : money(p.price_somoni)}</td>
                  <td class="num">${p.sales?.[0]?.count ?? 0}</td>
                  <td>${statusBadge(p.is_published)}</td>
                </tr>`;
            })}</tbody></table></div>`}
    </section>`));
}

function typePicker(current) {
  return html`
    <fieldset class="type-picker"><legend>Тип продукта</legend>
      ${Object.entries(TYPES).map(([value, t]) => html`
        <label class="chip"><input type="radio" name="type" value="${value}" ${value === current ? raw('checked') : ''} required>
          <span>${t.label}</span></label>`)}
    </fieldset>`;
}

async function newProductView() {
  show(page('Новый продукт', 'products', html`
    <header class="page-header"><div><a class="back" href="#/products">← Продукты</a><h1>Новый продукт</h1></div></header>
    <section class="card narrow">
      <form class="stack" id="new-product">
        ${typePicker('course')}
        <label>Название<input name="title" required maxlength="120" placeholder="Например: Гитара с нуля"></label>
        <p class="muted">Продукт создастся черновиком: в приложении его не будет видно, пока вы не нажмёте «Опубликовать».</p>
        <button class="primary" type="submit">Создать</button>
      </form>
    </section>`));
  const form = $('#new-product');
  form.addEventListener('submit', (e) => {
    e.preventDefault();
    busy(form.querySelector('button'), async () => {
      const id = await api.createProduct(form.type.value, form.title.value.trim());
      flash('Продукт создан. Добавьте уроки, видео и обложку, затем опубликуйте.');
      go(`#/products/${id}`);
    });
  });
}

// ------------------------------------------------------------------ редактор продукта

async function editorView({ args: [id] }) {
  const p = await api.getProduct(id);
  const kind = TYPES[p.type];
  const isSingle = p.type === 'single';
  const general = p.materials.filter((m) => !m.lesson_id);
  const missingVideo = p.lessons.filter((l) => !l.video_key).length;
  const total = p.lessons.reduce((s, l) => s + l.duration_sec, 0);
  const stem = (name) => name.replace(/\.[^.]+$/, '');

  show(page(p.title, 'products', html`
    <header class="page-header">
      <div><a class="back" href="#/products">← Продукты</a><h1>${p.title} ${statusBadge(p.is_published)}</h1></div>
      <div class="actions">
        <button class="secondary" type="submit" form="product-form" value="save">${p.is_published ? 'Сохранить' : 'Сохранить черновик'}</button>
        ${p.is_published
          ? html`<button class="secondary" type="submit" form="product-form" value="unpublish">Снять с публикации</button>`
          : html`<button class="primary" type="submit" form="product-form" value="publish">Опубликовать</button>`}
      </div>
    </header>
    <div class="editor-grid">
      <div class="editor-main">
        <section class="card">
          <form id="product-form">
            ${typePicker(p.type)}
            <label>Название<input name="title" value="${p.title}" required maxlength="120"></label>
            <label>Короткое описание (1–2 строки)<textarea name="subtitle" rows="2" maxlength="160">${p.subtitle}</textarea></label>
            <div class="row3">
              <label>Цена, сомони
                <input name="price" inputmode="numeric" pattern="[0-9]*" value="${p.price_somoni ?? ''}" placeholder="—">
                <span class="hint">для статистики и генератора; в приложении не показывается</span></label>
              <label>Уровень
                <select name="level">${Object.entries(LEVELS).map(([v, l]) => html`
                  <option value="${v}" ${v === p.level ? raw('selected') : ''}>${l}</option>`)}</select></label>
              <div class="readonly"><span class="label">Номер для ключей</span>
                <strong>№ ${p.activation_number}</strong><span class="hint">не меняется</span></div>
            </div>
          </form>
        </section>

        <section class="card" id="lessons">
          <div class="section-head">
            <h2>${kind.items} · ${p.lessons.length}</h2>
            <span class="muted">${p.lessons.length > 1 ? 'Перетащите, чтобы изменить порядок · ' : ''}всего ${duration(total)}</span>
          </div>
          <ol class="lesson-list" id="lesson-list">
            ${p.lessons.map((l) => {
              const pdfs = p.materials.filter((m) => m.lesson_id === l.id);
              return html`
                <li class="lesson" data-id="${l.id}" id="lesson-${l.id}">
                  <div class="lesson-row">
                    <button class="grip" type="button" title="Перетащите или нажмите и используйте стрелки ↑↓"
                      aria-label="Переместить урок ${l.position}">${icons.grip}</button>
                    <span class="lesson-num">${l.position}</span>
                    <form class="lesson-form" data-lesson="${l.id}">
                      <input name="title" value="${l.title}" required maxlength="120" aria-label="Название">
                      <label class="check"><input type="checkbox" name="free" ${l.is_free_preview ? raw('checked') : ''}> бесплатно</label>
                      ${isSingle ? html`<label class="inline">превью, сек
                        <input name="preview" inputmode="numeric" size="3" value="${l.preview_limit_sec ?? ''}"></label>` : ''}
                      <button class="small secondary" type="submit">Сохранить</button>
                    </form>
                  </div>
                  <div class="lesson-media">
                    <div class="video-state">
                      ${l.video_key
                        ? html`<span class="ok">✓ Видео · ${duration(l.duration_sec)}</span>
                            <button class="link-button" type="button" data-preview="${l.video_key}">смотреть</button>`
                        : html`<span class="warn">Нет видео</span>`}
                    </div>
                    <div class="upload-row">
                      <label class="button small file-button">${l.video_key ? 'Заменить видео' : 'Загрузить видео'}
                        <input type="file" accept="video/*,.mp4,.mov,.m4v,.webm" data-video="${l.id}"></label>
                      <span class="upload-progress" data-progress="${l.id}" hidden>
                        <progress max="100" value="0"></progress><span role="status"></span></span>
                    </div>
                    <div class="pdfs">
                      ${pdfs.map((m) => html`
                        <span class="pdf-chip">
                          <button class="link-button" type="button" data-preview="${m.file_key}">PDF · ${m.title}</button>
                          <button class="icon" type="button" data-delete-material="${m.id}" aria-label="Удалить PDF">×</button>
                        </span>`)}
                      <label class="button small secondary file-button">Добавить PDF к уроку
                        <input type="file" accept="application/pdf,.pdf" data-lesson-pdf="${l.id}"></label>
                    </div>
                    <div><button class="small danger" type="button" data-delete-lesson="${l.id}">Удалить урок</button></div>
                  </div>
                </li>`;
            })}
          </ol>
          <form class="add-lesson" id="add-lesson">
            <input name="title" required maxlength="120" aria-label="Название нового урока"
              placeholder="Название — например «${p.lessons.length + 1}. Как держать гитару»">
            <button class="primary" type="submit">${kind.add}</button>
          </form>
        </section>

        <section class="card" id="materials">
          <h2>PDF ко всему продукту · ${general.length}</h2>
          <p class="muted">Показываются на странице курса в приложении (аккорды, схемы, упражнения).
            PDF к конкретному уроку добавляйте в строке урока.</p>
          ${general.length ? html`<ul class="file-list">${general.map((m) => html`
            <li><button class="link-button" type="button" data-preview="${m.file_key}">${m.title}</button>
              <button class="small danger" type="button" data-delete-material="${m.id}">Удалить</button></li>`)}</ul>` : ''}
          <form class="upload-row" id="general-pdf">
            <input name="title" maxlength="120" placeholder="Название (необязательно)" aria-label="Название PDF">
            <input type="file" name="file" accept="application/pdf,.pdf" required aria-label="PDF">
            <button class="secondary" type="submit">Загрузить PDF</button>
            <span class="upload-progress" id="general-progress" hidden><progress max="100" value="0"></progress><span role="status"></span></span>
          </form>
        </section>

        <section class="card danger-zone">
          <h2>Удаление</h2>
          <p class="muted">Продукт, по которому уже выданы ключи, удалить нельзя — снимите его с публикации.</p>
          <button class="danger" type="button" id="delete-product">Удалить продукт</button>
        </section>
      </div>

      <aside class="editor-side">
        <section class="card">
          <h2>Обложка</h2>
          <div class="cover-preview">${coverThumb(p.cover_path, 220)}</div>
          <label class="button secondary file-button">Загрузить обложку
            <input type="file" accept="image/jpeg,image/png,image/webp" id="cover-input"></label>
          <p class="hint">Квадрат, от 1000×1000 px, JPG или PNG, до 5 МБ</p>
        </section>
        <section class="card">
          <h2>Как в приложении</h2>
          <div class="app-card">${coverThumb(p.cover_path, 120)}
            <div class="app-card-title">${p.title}</div>
            <div class="muted">${LEVELS[p.level]} уровень · ${p.lessons.length} ${kind.items.toLowerCase()}</div></div>
        </section>
        <section class="card">
          <h2>Готовность</h2>
          <ul class="checklist">
            <li class="${p.title ? 'done' : ''}">Название</li>
            <li class="${p.cover_path ? 'done' : ''}">Обложка</li>
            <li class="${p.lessons.length ? 'done' : ''}">${kind.items}: ${p.lessons.length}</li>
            <li class="${p.lessons.length && !missingVideo ? 'done' : ''}">${missingVideo ? `Нет видео: ${missingVideo}` : 'Видео у всех'}</li>
            <li class="${p.lessons.some((l) => l.is_free_preview || l.preview_limit_sec) ? 'done' : ''}">Бесплатный урок</li>
            <li class="${p.materials.length ? 'done' : ''}">PDF: ${p.materials.length}</li>
          </ul>
        </section>
      </aside>
    </div>`));

  const reload = () => router();
  const lessonById = (lid) => p.lessons.find((l) => l.id === lid);

  // --- основные поля и публикация
  const form = $('#product-form');
  form.addEventListener('submit', (e) => {
    e.preventDefault();
    const action = e.submitter?.value ?? 'save';
    busy(e.submitter, async () => {
      const priceRaw = form.price.value.trim();
      if (priceRaw && !/^\d+$/.test(priceRaw)) throw new Error('Цена — целое число сомони');
      await api.updateProduct(id, {
        type: form.type.value,
        title: form.title.value.trim(),
        subtitle: form.subtitle.value.trim(),
        level: form.level.value,
        price_somoni: priceRaw ? Number(priceRaw) : null,
      });
      if (action === 'publish') {
        if (!p.lessons.length) throw new Error('Нельзя опубликовать без уроков — добавьте хотя бы один');
        const missing = p.lessons.filter((l) => !l.video_key).map((l) => l.position);
        if (missing.length) throw new Error(`Нельзя опубликовать: нет видео у уроков № ${missing.join(', ')}`);
        await api.updateProduct(id, { is_published: true });
        flash('Опубликовано — продукт виден в приложении');
      } else if (action === 'unpublish') {
        await api.updateProduct(id, { is_published: false });
        flash('Снято с публикации — в приложении его больше не видно');
      } else {
        flash('Сохранено');
      }
      reload();
    });
  });

  // --- обложка
  $('#cover-input').addEventListener('change', (e) => {
    const file = e.target.files[0];
    if (!file) return;
    busy(null, async () => {
      if (file.size > 5 * 1024 * 1024) throw new Error('Обложка больше 5 МБ — уменьшите изображение');
      await api.uploadCover(p, file);
      flash('Обложка загружена');
      reload();
    });
  });

  // --- уроки
  $('#add-lesson').addEventListener('submit', (e) => {
    e.preventDefault();
    const f = e.currentTarget;
    busy(f.querySelector('button'), async () => {
      await api.addLesson(id, f.title.value.trim());
      flash('Урок добавлен');
      reload();
    });
  });

  $$('.lesson-form').forEach((f) => f.addEventListener('submit', (e) => {
    e.preventDefault();
    busy(f.querySelector('button'), async () => {
      const previewRaw = f.preview?.value.trim() ?? '';
      let preview = null;
      if (previewRaw) {
        preview = Number(previewRaw);
        if (!Number.isInteger(preview) || preview < 5 || preview > 600) throw new Error('Превью — от 5 до 600 секунд');
      }
      await api.updateLesson(f.dataset.lesson, {
        title: f.title.value.trim(),
        is_free_preview: f.free.checked,
        preview_limit_sec: preview,
      });
      flash('Урок сохранён');
      reload();
    });
  }));

  root.addEventListener('click', async (e) => {
    const t = e.target;
    if (t.dataset.preview) {
      const w = window.open('', '_blank');
      try {
        w.location = await api.previewUrl(t.dataset.preview);
      } catch (err) {
        w.close();
        flash(err.message, 'error');
        reload();
      }
    } else if (t.dataset.deleteLesson) {
      if (!confirm('Удалить урок вместе с видео?')) return;
      busy(t, async () => { await api.deleteLesson(lessonById(t.dataset.deleteLesson)); flash('Урок удалён'); reload(); });
    } else if (t.dataset.deleteMaterial) {
      if (!confirm('Удалить этот PDF?')) return;
      busy(t, async () => {
        await api.deleteMaterial(p.materials.find((m) => m.id === t.dataset.deleteMaterial));
        flash('PDF удалён');
        reload();
      });
    } else if (t.id === 'delete-product') {
      if (!confirm('Удалить продукт со всеми уроками, видео и PDF? Это нельзя отменить.')) return;
      busy(t, async () => { await api.deleteProduct(p); flash('Продукт удалён'); go('#/products'); });
    }
  }, { signal: viewSignal() });

  // --- загрузка видео и PDF в R2 с прогрессом
  const withProgress = async (box, work) => {
    const bar = box.querySelector('progress');
    const status = box.querySelector('[role="status"]');
    box.hidden = false;
    uploadsInProgress += 1;
    try {
      return await work((fraction, loaded) => {
        bar.value = Math.round(fraction * 100);
        status.textContent = `${Math.round(fraction * 100)}% · ${Math.round(loaded / 1048576)} МБ`;
      });
    } finally {
      uploadsInProgress -= 1;
    }
  };

  $$('[data-video]').forEach((input) => input.addEventListener('change', () => {
    const file = input.files[0];
    if (!file) return;
    const lesson = lessonById(input.dataset.video);
    const box = $(`[data-progress="${lesson.id}"]`);
    input.disabled = true;
    busy(null, async () => {
      const seconds = await videoDuration(file);
      const key = await withProgress(box, (onProgress) => api.uploadToR2('video', file, onProgress));
      await api.setLessonVideo(lesson, key, seconds);
      flash(`Видео «${lesson.title}» загружено`);
      reload();
    });
  }));

  $$('[data-lesson-pdf]').forEach((input) => input.addEventListener('change', () => {
    const file = input.files[0];
    if (!file) return;
    busy(null, async () => {
      const key = await api.uploadToR2('pdf', file);
      await api.addMaterial(id, input.dataset.lessonPdf, stem(file.name), key);
      flash('PDF загружен');
      reload();
    });
  }));

  const pdfForm = $('#general-pdf');
  pdfForm.addEventListener('submit', (e) => {
    e.preventDefault();
    const file = pdfForm.file.files[0];
    if (!file) return;
    busy(pdfForm.querySelector('button'), async () => {
      const key = await withProgress($('#general-progress'), (onProgress) => api.uploadToR2('pdf', file, onProgress));
      await api.addMaterial(id, null, pdfForm.title.value.trim() || stem(file.name), key);
      flash('PDF загружен');
      reload();
    });
  });

  // --- порядок уроков: перетаскивание за ручку и стрелки ↑↓
  const list = $('#lesson-list');
  const saveOrder = () => busy(null, async () => {
    const ids = [...list.children].map((li) => li.dataset.id);
    [...list.children].forEach((li, i) => { li.querySelector('.lesson-num').textContent = String(i + 1); });
    await api.reorderLessons(id, ids);
  });
  let dragged = null;
  list.addEventListener('pointerdown', (e) => {
    const grip = e.target.closest('.grip');
    if (grip) grip.closest('li').draggable = true;
  });
  list.addEventListener('dragstart', (e) => {
    dragged = e.target.closest('li');
    dragged?.classList.add('dragging');
  });
  list.addEventListener('dragover', (e) => {
    if (!dragged) return;
    e.preventDefault();
    const over = e.target.closest('li');
    if (!over || over === dragged) return;
    const r = over.getBoundingClientRect();
    list.insertBefore(dragged, e.clientY > r.top + r.height / 2 ? over.nextSibling : over);
  });
  list.addEventListener('dragend', () => {
    if (!dragged) return;
    dragged.classList.remove('dragging');
    dragged.draggable = false;
    dragged = null;
    saveOrder();
  });
  list.addEventListener('keydown', (e) => {
    const grip = e.target.closest('.grip');
    if (!grip || (e.key !== 'ArrowUp' && e.key !== 'ArrowDown')) return;
    e.preventDefault();
    const li = grip.closest('li');
    const sib = e.key === 'ArrowUp' ? li.previousElementSibling : li.nextElementSibling;
    if (!sib) return;
    list.insertBefore(li, e.key === 'ArrowUp' ? sib : sib.nextSibling);
    grip.focus();
    saveOrder();
  });
}

// ------------------------------------------------------------------ ключи

let lastKey = null;

async function keysView({ params }) {
  const query = params.get('q') ?? '';
  const productId = params.get('product') ?? '';
  const period = params.get('period') ?? '';
  const since = PERIODS[period] ? new Date(Date.now() - PERIODS[period][1] * 86400e3).toISOString() : null;
  const [products, sales, activations] = await Promise.all([
    api.listProducts(null),
    api.listSales({ query, productId, since }),
    api.listActivations(),
  ]);
  const total = sales.reduce((s, r) => s + (r.amount_somoni ?? 0), 0);
  const message = (r) => `Код активации курса «${r.product_title}»: ${r.key}\nВ приложении: «Активировать курс» → поле «Код активации».`;

  show(page('Ключи', 'keys', html`
    <header class="page-header"><div><h1>Ключи</h1>
      <p class="muted">Ученик присылает ID-код из приложения — вы создаёте ключ и отправляете ему</p></div></header>

    ${lastKey ? html`
      <section class="card key-result">
        <div class="muted">Ключ · ${lastKey.product_title} · ID-код <code>${lastKey.device_code}</code></div>
        <div class="key-value">${lastKey.key}</div>
        <div class="key-calc muted">Расчёт: ${lastKey.calc}</div>
        <div class="actions">
          <a class="button primary" href="${whatsappLink(lastKey.student, message(lastKey))}" target="_blank" rel="noopener">Отправить в WhatsApp</a>
          <button class="secondary" type="button" data-copy="${lastKey.key}">Скопировать ключ</button>
          <button class="secondary" type="button" data-copy="${message(lastKey)}">Скопировать сообщение</button>
        </div>
      </section>` : ''}

    <div class="grid-2 keys-grid">
      <section class="card">
        <h2>Новый ключ</h2>
        ${products.length === 0
          ? html`<p class="muted">Сначала создайте продукт в разделе <a href="#/products">«Продукты»</a>.</p>`
          : html`<form class="stack" id="new-key">
              <label>ID-код ученика<input name="device_code" inputmode="numeric" required autocomplete="off" placeholder="17 цифр из приложения"></label>
              <label>Продукт<select name="product_id" required>
                ${products.map((p) => html`<option value="${p.id}" data-price="${p.price_somoni ?? ''}">№ ${p.activation_number} · ${p.title}${p.is_published ? '' : ' (черновик)'}</option>`)}
              </select></label>
              <label>Ученик<input name="student" maxlength="120" placeholder="Имя и телефон, например: Фарход +992 90 123 45 67">
                <span class="hint">если указать телефон — «Отправить в WhatsApp» откроет его чат</span></label>
              <label>Сумма, сомони<input name="amount" inputmode="numeric" pattern="[0-9]*">
                <span class="hint">для статистики; по умолчанию — цена продукта</span></label>
              <button class="primary" type="submit">Создать ключ</button>
              <p class="hint">Ключи из генератора на телефоне сюда не попадают — чтобы они были в статистике, внесите продажу этой же формой (ключ получится тот же).</p>
            </form>`}
      </section>
      <section class="card">
        <h2>Найти</h2>
        <form class="stack" id="filter">
          <label>Поиск<input name="q" value="${query}" placeholder="ученик, ID-код или ключ"></label>
          <label>Продукт<select name="product"><option value="">Все продукты</option>
            ${products.map((p) => html`<option value="${p.id}" ${p.id === productId ? raw('selected') : ''}>${p.title}</option>`)}</select></label>
          <label>Период<select name="period">
            ${[['', 'За всё время'], ['week', 'Неделя'], ['month', 'Месяц'], ['year', 'Год']].map(([v, l]) => html`
              <option value="${v}" ${v === period ? raw('selected') : ''}>${l}</option>`)}</select></label>
          <div class="actions"><button class="secondary" type="submit">Показать</button><a class="button ghost" href="#/keys">Сбросить</a></div>
        </form>
      </section>
    </div>

    <section class="card">
      <div class="section-head">
        <h2>Журнал продаж · ${sales.length} · ${money(total)} сомони</h2>
        <button class="secondary" type="button" id="csv">Скачать для Excel</button>
      </div>
      ${sales.length === 0 ? html`<p class="muted">Записей нет.</p>` : html`
        <div class="table-wrap"><table>
          <thead><tr><th>Дата</th><th>Ученик</th><th>Продукт</th><th>ID-код</th><th>Ключ</th><th class="num">Сумма</th><th></th></tr></thead>
          <tbody>${sales.map((r) => html`
            <tr><td class="nowrap">${date(r.created_at)}</td>
              <td>${r.student || raw('<span class="muted">—</span>')}</td>
              <td>${r.products?.title}</td>
              <td><code>${r.device_code}</code></td>
              <td><code>${r.activation_key}</code> <button class="icon" type="button" data-copy="${r.activation_key}" aria-label="Скопировать ключ">⧉</button></td>
              <td class="num">${r.amount_somoni === null ? '—' : money(r.amount_somoni)}</td>
              <td><button class="icon" type="button" data-delete-sale="${r.id}" aria-label="Удалить запись">×</button></td></tr>`)}
          </tbody></table></div>`}
    </section>

    <section class="card">
      <h2>Активации учеников · ${activations.length}</h2>
      <p class="muted">Кто ввёл ключ в приложении. «Отозвать» закрывает курс на этом телефоне (например, при возврате денег).</p>
      ${activations.length === 0 ? html`<p class="muted">Пока никто не активировал курс.</p>` : html`
        <div class="table-wrap"><table>
          <thead><tr><th>Дата</th><th>Ученик</th><th>Продукт</th><th>ID-код</th><th></th></tr></thead>
          <tbody>${activations.map((a) => html`
            <tr><td class="nowrap">${date(a.created_at)}</td><td>${a.email}</td><td>${a.products?.title}</td>
              <td><code>${a.device_code}</code></td>
              <td><button class="small danger" type="button" data-revoke="${a.id}">Отозвать</button></td></tr>`)}
          </tbody></table></div>`}
    </section>`));

  // --- новый ключ
  const form = $('#new-key');
  if (form) {
    const amount = form.amount;
    let auto = true;
    const fill = () => { if (auto) amount.value = form.product_id.selectedOptions[0]?.dataset.price ?? ''; };
    amount.addEventListener('input', () => { auto = amount.value === ''; });
    form.product_id.addEventListener('change', fill);
    fill();
    form.addEventListener('submit', (e) => {
      e.preventDefault();
      busy(form.querySelector('button[type="submit"]'), async () => {
        const res = await api.generateKey({
          device_code: form.device_code.value,
          product_id: form.product_id.value,
          student: form.student.value,
          amount: form.amount.value,
        });
        lastKey = {
          key: res.sale.activation_key,
          device_code: res.sale.device_code,
          student: res.sale.student,
          product_title: res.product_title,
          calc: res.calc,
        };
        router();
        window.scrollTo({ top: 0 });
      });
    });
  }

  // --- фильтр
  $('#filter').addEventListener('submit', (e) => {
    e.preventDefault();
    const f = e.currentTarget;
    const q = new URLSearchParams();
    if (f.q.value.trim()) q.set('q', f.q.value.trim());
    if (f.product.value) q.set('product', f.product.value);
    if (f.period.value) q.set('period', f.period.value);
    go(`#/keys${q.toString() ? `?${q}` : ''}`);
  });

  // --- Excel
  $('#csv').addEventListener('click', () => {
    const today = new Date().toISOString().slice(0, 10);
    downloadCsv(`keys-${today}.csv`,
      ['Дата', 'Ученик', 'Продукт', 'Номер продукта', 'ID-код', 'Ключ', 'Сумма, сомони'],
      sales.map((r) => [date(r.created_at), r.student, r.products?.title, r.products?.activation_number,
        r.device_code, r.activation_key, r.amount_somoni ?? '']));
  });

  // --- удалить продажу / отозвать активацию
  root.addEventListener('click', (e) => {
    const t = e.target;
    if (t.dataset.deleteSale) {
      if (!confirm('Удалить запись? Ключ у ученика продолжит работать — запись нужна только для статистики.')) return;
      busy(t, async () => { await api.deleteSale(t.dataset.deleteSale); flash('Запись удалена'); router(); });
    } else if (t.dataset.revoke) {
      if (!confirm('Отозвать доступ? Ученик больше не сможет смотреть этот курс на этом телефоне.')) return;
      busy(t, async () => { await api.revokeActivation(t.dataset.revoke); flash('Доступ отозван'); router(); });
    }
  }, { signal: viewSignal() });
}
