// Безопасная сборка HTML и мелкие помощники интерфейса.

const ESCAPES = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };

class Raw {
  constructor(value) { this.value = value; }
  toString() { return this.value; }
}

/** Уже готовая разметка — не экранируется. */
export const raw = (value) => new Raw(value);

function render(value) {
  if (value instanceof Raw) return value.value;
  if (Array.isArray(value)) return value.map(render).join('');
  if (value === null || value === undefined || value === false) return '';
  return String(value).replace(/[&<>"']/g, (c) => ESCAPES[c]);
}

/**
 * Шаблон: всё, что подставляется через ${…}, экранируется (данные из базы
 * не могут внедрить разметку). Вложенные html`…` вставляются как есть.
 */
export function html(strings, ...values) {
  let out = '';
  strings.forEach((s, i) => {
    out += s;
    if (i < values.length) out += render(values[i]);
  });
  return raw(out);
}

/** 6:40, 1:02:05. */
export function duration(total) {
  const t = Math.max(0, Math.round(total || 0));
  const h = Math.floor(t / 3600);
  const m = Math.floor((t % 3600) / 60);
  const s = String(t % 60).padStart(2, '0');
  return h > 0 ? `${h}:${String(m).padStart(2, '0')}:${s}` : `${m}:${s}`;
}

/** 34450 → «34 450». */
export function money(n) {
  return new Intl.NumberFormat('ru-RU').format(Number(n) || 0);
}

/** Дата по Душанбе: «12.10.2026 15:31». */
export function date(iso) {
  return new Intl.DateTimeFormat('ru-RU', {
    timeZone: 'Asia/Dushanbe',
    day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit',
  }).format(new Date(iso)).replace(',', '');
}

export const MONTHS = ['янв', 'фев', 'мар', 'апр', 'май', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];

export const TYPES = {
  course: { label: 'Курс', items: 'Уроки', add: 'Добавить урок' },
  song_album: { label: 'Альбом песен', items: 'Песни', add: 'Добавить песню' },
  single: { label: 'Отдельная песня', items: 'Песни', add: 'Добавить песню' },
};

export const LEVELS = { beginner: 'Начальный', intermediate: 'Средний', advanced: 'Продвинутый' };

export function statusBadge(published) {
  return published
    ? html`<span class="badge badge-success">Опубликован</span>`
    : html`<span class="badge">Черновик</span>`;
}

const SVG = (paths) => raw(`<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${paths}</svg>`);

export const icons = {
  guitar: SVG('<path d="m11.9 12.1 4.514-4.514"/><path d="M20.1 2.3a1 1 0 0 0-1.4 0l-1.114 1.114A2 2 0 0 0 17 4.828v1.344a2 2 0 0 1-.586 1.414A2 2 0 0 1 17.828 7h1.344a2 2 0 0 0 1.414-.586L21.7 5.3a1 1 0 0 0 0-1.4z"/><path d="m6 16 2 2"/><path d="M8.23 9.85A3 3 0 0 1 11 8a5 5 0 0 1 5 5 3 3 0 0 1-1.85 2.77l-.92.38A2 2 0 0 0 12 18a4 4 0 0 1-4 4 6 6 0 0 1-6-6 4 4 0 0 1 4-4 2 2 0 0 0 1.85-1.23z"/>'),
  chart: SVG('<path d="M3 3v16a2 2 0 0 0 2 2h16"/><path d="M18 17V9"/><path d="M13 17V5"/><path d="M8 17v-3"/>'),
  music: SVG('<path d="M9 18V5l12-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="18" cy="16" r="3"/>'),
  key: SVG('<path d="m15.5 7.5 2.3 2.3a1 1 0 0 0 1.4 0l2.1-2.1a1 1 0 0 0 0-1.4L19 4"/><path d="m21 2-9.6 9.6"/><circle cx="7.5" cy="15.5" r="5.5"/>'),
  grip: SVG('<circle cx="9" cy="6" r="1"/><circle cx="9" cy="12" r="1"/><circle cx="9" cy="18" r="1"/><circle cx="15" cy="6" r="1"/><circle cx="15" cy="12" r="1"/><circle cx="15" cy="18" r="1"/>'),
};

/** Сообщение вверху страницы; исчезает при следующей навигации. */
let pendingFlash = null;
export function flash(message, kind = 'ok') { pendingFlash = { message, kind }; }
export function takeFlash() {
  const f = pendingFlash;
  pendingFlash = null;
  if (!f) return '';
  return f.kind === 'ok'
    ? html`<p class="flash" role="status">${f.message}</p>`
    : html`<p class="error" role="alert">${f.message}</p>`;
}

/** Копирование в буфер с подсказкой на кнопке. */
export async function copy(button, text) {
  try {
    await navigator.clipboard.writeText(text);
    const label = button.textContent;
    button.textContent = label.length <= 2 ? '✓' : 'Скопировано';
    setTimeout(() => { button.textContent = label; }, 1500);
  } catch {
    window.prompt('Скопируйте вручную:', text);
  }
}

/** Длительность видео в секундах — браузер читает её из файла до загрузки. */
export function videoDuration(file) {
  return new Promise((resolve) => {
    const video = document.createElement('video');
    video.preload = 'metadata';
    const done = (v) => { URL.revokeObjectURL(video.src); resolve(v); };
    video.onloadedmetadata = () => done(Number.isFinite(video.duration) ? video.duration : 0);
    video.onerror = () => done(0);
    video.src = URL.createObjectURL(file);
  });
}

/** CSV для Excel: UTF-8 с BOM, «;», защита от формул. */
export function downloadCsv(filename, header, rows) {
  const field = (v) => {
    let s = String(v ?? '');
    if (/^[=+\-@]/.test(s)) s = `'${s}`;
    return /[;"\n\r]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  };
  const text = '﻿' + [header, ...rows].map((r) => r.map(field).join(';')).join('\r\n') + '\r\n';
  const url = URL.createObjectURL(new Blob([text], { type: 'text/csv;charset=utf-8' }));
  const a = Object.assign(document.createElement('a'), { href: url, download: filename });
  document.body.append(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
}

/** Ссылка «Отправить в WhatsApp»: если в поле «Ученик» есть номер — сразу в его чат. */
export function whatsappLink(student, text) {
  const digits = String(student ?? '').replace(/\D/g, '');
  const q = `text=${encodeURIComponent(text)}`;
  return digits.length >= 9 ? `https://wa.me/${digits}?${q}` : `https://wa.me/?${q}`;
}
