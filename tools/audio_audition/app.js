import {createStore} from './state.js';
import {PreviewPlayer} from './player.js';
import {renderCue} from './cue.js';

const $ = id => document.getElementById(id);
const muted = new URLSearchParams(location.search).get('muted') === '1';
let resetArmed = false;

function announce(message) { $('announcement').textContent = message; }
function showError(message) { $('error').hidden = !message; $('error').textContent = message || ''; }

async function start() {
  const response = await fetch('data.json');
  if (!response.ok) throw new Error('The sound library is unavailable. Rebuild the audition page and reload.');
  const data = await response.json();
  const store = createStore(data);
  const views = new Map();
  const sections = new Map();
  const player = new PreviewPlayer(data.assets, state => {
    for (const [id, view] of views) {
      const active = state?.id === id;
      view.card.classList.toggle('is-playing', active);
      view.play.textContent = active ? '■ Stop' : '▶ Play';
      view.play.setAttribute('aria-label', `${active ? 'Stop' : 'Play'} ${data.cues[id].label}`);
    }
    $('playing-dot').classList.toggle('active', Boolean(state?.id));
    $('stop').disabled = !state?.id;
    $('playing-title').textContent = state?.title || (state?.error ? 'Preview unavailable' : 'Ready to listen');
    $('playing-detail').textContent = state?.error || state?.detail || (muted ? 'QA mode: all previews are muted.' : 'Choose a moment and press Play.');
    if (state?.error) { showError(state.error); announce(state.error); }
    else if (state?.id) showError('');
  }, muted);

  function refresh() {
    const query = $('search').value.toLowerCase().trim();
    const mode = $('filter').value;
    let visible = 0;
    for (const [id, cue] of Object.entries(data.cues)) {
      const text = `${id} ${cue.label} ${cue.description} ${cue.group}`.toLowerCase();
      const show = (!query || text.includes(query)) &&
        (mode !== 'review' || cue.review) && (mode !== 'changed' || store.changed(id));
      views.get(id).card.hidden = !show;
      if (show) visible += 1;
    }
    for (const section of sections.values()) {
      const count = [...section.grid.children].filter(card => !card.hidden).length;
      section.element.hidden = count === 0; section.count.textContent = `${count} moment${count === 1 ? '' : 's'}`;
    }
    const changed = Object.keys(data.cues).filter(id => store.changed(id)).length;
    const review = Object.values(data.cues).filter(cue => cue.review).length;
    $('summary').textContent = `${visible} / ${Object.keys(data.cues).length} moments · ${review} need a listen · ${changed} changed`;
    $('json').value = JSON.stringify(store.export(), null, 2);
    $('copy').textContent = 'Copy JSON';
    $('empty').hidden = visible !== 0;
    if (!store.storageAvailable()) showError('Browser storage is unavailable. Keep this tab open and export your choices before leaving.');
  }

  function render() {
    views.clear(); sections.clear(); $('groups').replaceChildren();
    for (const [id, cue] of Object.entries(data.cues)) {
      const group = cue.group || 'Other moments';
      if (!sections.has(group)) {
        const element = document.createElement('section'); element.className = 'group';
        const heading = document.createElement('div'); heading.className = 'group-heading';
        const title = document.createElement('h2'); title.textContent = group;
        const count = document.createElement('span');
        const grid = document.createElement('div'); grid.className = 'cue-grid';
        heading.append(title, count); element.append(heading, grid); $('groups').append(element);
        sections.set(group, {element, grid, count});
      }
      const view = renderCue(id, cue, data, store, player, refresh);
      views.set(id, view); sections.get(group).grid.append(view.card);
    }
    refresh();
  }

  $('search').addEventListener('input', refresh);
  $('filter').addEventListener('change', refresh);
  $('volume').addEventListener('input', () => {
    player.master = Number($('volume').value) / 100; player.setGain();
    $('volume-value').textContent = `${$('volume').value}%`;
  });
  $('stop').addEventListener('click', () => player.stop());
  window.addEventListener('pagehide', () => player.stop(false));
  document.addEventListener('keydown', event => { if (event.key === 'Escape') player.stop(); });
  $('reset').addEventListener('click', () => {
    if (!resetArmed) {
      resetArmed = true; $('reset').textContent = 'Reset everything? Click again';
      announce('Click Reset again to discard your choices and notes.');
      setTimeout(() => { resetArmed = false; $('reset').textContent = 'Reset choices'; }, 6000);
      return;
    }
    resetArmed = false; player.stop(); store.reset(); render();
    $('reset').textContent = 'Reset choices'; announce('Restored current game choices.');
  });
  $('export').addEventListener('click', () => {
    const blob = new Blob([JSON.stringify(store.export(), null, 2) + '\n'], {type: 'application/json'});
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a'); link.href = url; link.download = 'pass-the-game-audio-choices.json';
    document.body.append(link); link.click(); link.remove();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
    $('export-panel').open = true; announce('Choices exported. Send the JSON file back to apply them to the game.');
  });
  $('copy').addEventListener('click', async () => {
    try { await navigator.clipboard.writeText($('json').value); $('copy').textContent = 'Copied'; announce('Choices copied.'); }
    catch { $('json').focus(); $('json').select(); announce('Select and copy the JSON below.'); }
  });
  for (const [index, pack] of data.packs.entries()) {
    if (index) $('sources').append(document.createTextNode(' · '));
    const link = document.createElement('a'); link.textContent = pack.title;
    if (/^https:\/\//.test(pack.url)) { link.href = pack.url; link.target = '_blank'; link.rel = 'noopener noreferrer'; }
    $('sources').append(link);
  }
  for (const id of ['reset', 'export', 'copy']) $(id).disabled = false;
  if (muted) $('playing-detail').textContent = 'QA mode: all previews are muted.';
  render();
}

start().catch(error => { showError(error.message || 'Could not load the audition page.'); $('summary').textContent = 'Library could not load'; });
