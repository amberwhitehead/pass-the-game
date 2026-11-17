import {makeOptions, selectionIndex} from './state.js';

function el(tag, text, className) {
  const node = document.createElement(tag);
  if (text !== undefined) node.textContent = text;
  if (className) node.className = className;
  return node;
}

export function renderCue(id, cue, data, store, player, onChange) {
  const card = el('article', undefined, 'cue');
  card.dataset.cue = id;
  const top = el('div', undefined, 'cue-top');
  const title = el('h3', cue.label); title.id = `title-${id}`;
  card.setAttribute('aria-labelledby', title.id);
  const badge = el('span', 'In game', 'badge');
  top.append(title, badge);
  card.append(top, el('p', cue.description, 'description'));
  if (cue.review) card.append(el('p', '◇ Needs a listen — provisional choice', 'review-note'));

  const label = el('label', 'Sound choice');
  const select = el('select'); select.setAttribute('aria-label', `${cue.label} sound choice`);
  const options = makeOptions(cue, data.assets);
  const saved = store.get(id);
  if (selectionIndex(options, saved.files) < 0) options.unshift({label: 'Your saved variation set', files: saved.files});
  const recommended = el('optgroup'); recommended.label = 'Current & suggested';
  const library = el('optgroup'); library.label = 'All CC0 clips';
  options.forEach((option, index) => {
    const view = el('option', `${option.label}${option.files.length > 1 ? ` (${option.files.length} clips)` : ''}`);
    view.value = index;
    (option.library ? library : recommended).append(view);
  });
  select.append(recommended, library);
  select.value = selectionIndex(options, saved.files);
  label.append(select); card.append(label);
  const meta = el('p', '', 'clip-meta'); card.append(meta);

  const controls = el('div', undefined, 'cue-controls');
  const play = el('button', '▶ Play'); play.setAttribute('aria-label', `Play ${cue.label}`);
  play.addEventListener('click', () => {
    if (player.current?.id === id) player.stop();
    else player.play(id, cue, store.get(id));
  });
  const levelLabel = el('label', 'Cue level', 'level-label');
  const output = el('output', `${saved.db} dB`);
  const level = el('input'); level.type = 'range'; level.min = -60; level.max = 6; level.step = 1;
  level.value = saved.db; level.setAttribute('aria-label', `${cue.label} level`);
  levelLabel.append(output, level); controls.append(play, levelLabel); card.append(controls);
  const notesLabel = el('label', 'Notes for this moment', 'notes-label');
  const notes = el('textarea'); notes.rows = 2; notes.maxLength = 2000;
  notes.value = saved.notes; notes.placeholder = 'Softer? More tactile? Leave a direction…';
  notes.setAttribute('aria-label', `${cue.label} notes`);
  notesLabel.append(notes); card.append(notesLabel);

  const update = () => {
    const choice = store.get(id);
    const changed = store.changed(id);
    badge.textContent = changed ? 'Your choice' : 'In game';
    badge.classList.toggle('changed', changed);
    const clips = choice.files.map(file => data.assets.find(asset => asset.id === file));
    select.title = clips.map(clip => clip?.label).join(' / ');
    const seconds = clips.reduce((sum, clip) => sum + (clip?.duration || 0), 0);
    const packs = [...new Set(clips.map(clip => clip?.pack))].filter(Boolean).join(', ');
    meta.textContent = `${choice.files.length} clip${choice.files.length === 1 ? '' : 's'} · ${seconds.toFixed(2)}s${cue.loop ? ' · loops' : ''} · ${packs}`;
  };
  select.addEventListener('change', () => {
    if (player.current?.id === id) player.stop();
    store.set(id, {files: [...options[Number(select.value)].files]}); update(); onChange();
  });
  level.addEventListener('input', () => {
    const db = Number(level.value); output.textContent = `${db} dB`;
    store.set(id, {db});
    if (player.current?.id === id) player.setGain(db);
    update(); onChange();
  });
  notes.addEventListener('input', () => { store.set(id, {notes: notes.value}); update(); onChange(); });
  update();
  return {card, play, update};
}
