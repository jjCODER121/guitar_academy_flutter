// Админ-панель: немного поведения поверх обычных форм.
// Всё работает и без JS, кроме полосы прогресса видео и перетаскивания уроков.
'use strict';

// Подтверждение опасных действий: <form data-confirm="…">
document.addEventListener('submit', (e) => {
  const form = e.target;
  if (form.dataset.confirm && !window.confirm(form.dataset.confirm)) e.preventDefault();
});

// Копирование: <button data-copy="текст">
document.addEventListener('click', async (e) => {
  const button = e.target.closest('[data-copy]');
  if (!button) return;
  try {
    await navigator.clipboard.writeText(button.dataset.copy);
    const label = button.textContent;
    button.textContent = label.length <= 2 ? '✓' : 'Скопировано';
    setTimeout(() => { button.textContent = label; }, 1500);
  } catch {
    window.prompt('Скопируйте вручную:', button.dataset.copy);
  }
});

// ------------------------------------------------------------------ видео

/** Длительность видео в секундах — браузер читает её из файла до загрузки. */
function videoDuration(file) {
  return new Promise((resolve) => {
    const video = document.createElement('video');
    video.preload = 'metadata';
    const done = (value) => {
      URL.revokeObjectURL(video.src);
      resolve(value);
    };
    video.onloadedmetadata = () => done(Number.isFinite(video.duration) ? video.duration : 0);
    video.onerror = () => done(0);
    video.src = URL.createObjectURL(file);
  });
}

let uploadsInProgress = 0;
window.addEventListener('beforeunload', (e) => {
  if (uploadsInProgress > 0) e.preventDefault();
});

document.querySelectorAll('form[data-upload]').forEach((form) => {
  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    const input = form.querySelector('input[type="file"]');
    const file = input.files[0];
    if (!file) return;
    const button = form.querySelector('button');
    const progress = form.querySelector('progress');
    const status = form.querySelector('.upload-status');

    button.disabled = true;
    input.disabled = true;
    progress.hidden = false;
    status.textContent = 'Подготовка…';

    const data = new FormData();
    data.append('duration', String(await videoDuration(file)));
    data.append('video', file);

    const xhr = new XMLHttpRequest();
    xhr.open('POST', form.action);
    xhr.upload.addEventListener('progress', (ev) => {
      if (!ev.lengthComputable) return;
      const pct = Math.round((ev.loaded / ev.total) * 100);
      progress.value = pct;
      const mb = (n) => (n / 1048576).toFixed(0);
      status.textContent = `${pct}% · ${mb(ev.loaded)} из ${mb(ev.total)} МБ`;
    });
    const fail = (message) => {
      uploadsInProgress -= 1;
      status.textContent = message;
      button.disabled = false;
      input.disabled = false;
    };
    xhr.addEventListener('load', () => {
      if (xhr.status === 200) {
        uploadsInProgress -= 1;
        status.textContent = 'Готово';
        window.location.reload();
        return;
      }
      let message = `Ошибка ${xhr.status}`;
      try { message = JSON.parse(xhr.responseText).error.message; } catch { /* не JSON */ }
      if (xhr.status === 413) message = 'Файл слишком большой';
      fail(message);
    });
    xhr.addEventListener('error', () => fail('Связь прервалась — попробуйте ещё раз'));
    uploadsInProgress += 1;
    xhr.send(data);
  });
});

// ------------------------------------------------------------------ порядок уроков

const list = document.querySelector('[data-reorder-url]');
if (list) {
  const save = async () => {
    const ids = [...list.children].map((li) => li.dataset.id);
    [...list.children].forEach((li, i) => {
      const num = li.querySelector('.lesson-num');
      if (num) num.textContent = String(i + 1);
    });
    const response = await fetch(list.dataset.reorderUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(ids),
    });
    if (!response.ok) {
      window.alert('Не удалось сохранить порядок — страница обновится');
      window.location.reload();
    }
  };

  // Перетаскивание только за ручку, чтобы не мешать вводу текста.
  let dragged = null;
  list.addEventListener('pointerdown', (e) => {
    const grip = e.target.closest('.grip');
    if (grip) grip.closest('li').draggable = true;
  });
  list.addEventListener('dragstart', (e) => {
    dragged = e.target.closest('li');
    if (!dragged) return;
    dragged.classList.add('dragging');
    e.dataTransfer.effectAllowed = 'move';
  });
  list.addEventListener('dragover', (e) => {
    if (!dragged) return;
    e.preventDefault();
    const over = e.target.closest('li');
    if (!over || over === dragged) return;
    const rect = over.getBoundingClientRect();
    const after = e.clientY > rect.top + rect.height / 2;
    list.insertBefore(dragged, after ? over.nextSibling : over);
  });
  list.addEventListener('dragend', () => {
    if (!dragged) return;
    dragged.classList.remove('dragging');
    dragged.draggable = false;
    dragged = null;
    save();
  });

  // С клавиатуры: фокус на ручке, стрелки ↑↓.
  list.addEventListener('keydown', (e) => {
    const grip = e.target.closest('.grip');
    if (!grip || (e.key !== 'ArrowUp' && e.key !== 'ArrowDown')) return;
    e.preventDefault();
    const li = grip.closest('li');
    const sibling = e.key === 'ArrowUp' ? li.previousElementSibling : li.nextElementSibling;
    if (!sibling) return;
    list.insertBefore(li, e.key === 'ArrowUp' ? sibling : sibling.nextSibling);
    grip.focus();
    save();
  });
}

// ------------------------------------------------------------------ генератор ключей

const productSelect = document.querySelector('[data-product-select]');
const amountInput = document.querySelector('[data-amount]');
if (productSelect && amountInput) {
  let auto = true;
  const fill = () => {
    if (!auto) return;
    amountInput.value = productSelect.selectedOptions[0]?.dataset.price ?? '';
  };
  amountInput.addEventListener('input', () => { auto = amountInput.value === ''; });
  productSelect.addEventListener('change', fill);
  fill();
}
