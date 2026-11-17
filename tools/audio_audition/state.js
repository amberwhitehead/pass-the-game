const STORAGE_KEY = 'pass-the-game-audio-choices-v1';
const sameFiles = (a, b) => JSON.stringify(a) === JSON.stringify(b);

export function makeOptions(cue, assets) {
  const currentName = assets.find(asset => asset.id === cue.files[0])?.label || cue.files[0];
  const options = [{label: `In game · ${currentName}${cue.files.length > 1 ? ` + ${cue.files.length - 1} variations` : ''}`, files: [...cue.files]}];
  for (const option of cue.options || []) {
    if (!options.some(value => sameFiles(value.files, option.files))) options.push(option);
  }
  const singles = new Set(options.filter(value => value.files.length === 1).map(value => value.files[0]));
  for (const asset of assets) {
    if (!singles.has(asset.id)) options.push({label: asset.label, files: [asset.id], library: true});
  }
  return options;
}

export function createStore(data, storage) {
  const assets = new Set(data.assets.map(asset => asset.id));
  const defaults = () => Object.fromEntries(Object.entries(data.cues).map(([id, cue]) =>
    [id, {files: [...cue.files], db: cue.db, notes: ''}]));
  let choices = defaults();
  let storageAvailable = true;
  try {
    if (storage === undefined) storage = window.localStorage;
    const saved = JSON.parse(storage.getItem(STORAGE_KEY) || 'null');
    if (saved?.kind === 'pass-the-game-audio-choices' && saved.version === 1) {
      for (const [id, value] of Object.entries(saved.cues || {})) {
        if (!data.cues[id] || !Array.isArray(value.files) || !value.files.length) continue;
        if (value.files.some(file => !assets.has(file)) || !Number.isFinite(value.db)) continue;
        if (value.db < -60 || value.db > 6) continue;
        choices[id] = {files: [...new Set(value.files)], db: value.db,
          notes: typeof value.notes === 'string' ? value.notes.slice(0, 2000) : ''};
      }
    }
  } catch { storageAvailable = false; }
  const exported = () => ({version: 1, kind: 'pass-the-game-audio-choices', cues: structuredClone(choices)});
  const persist = () => {
    try { storage.setItem(STORAGE_KEY, JSON.stringify(exported())); }
    catch { storageAvailable = false; }
  };
  return {
    get: id => choices[id],
    set(id, value) { choices[id] = {...choices[id], ...value}; persist(); },
    reset() { choices = defaults(); persist(); },
    changed(id) { const value = choices[id], cue = data.cues[id];
      return !sameFiles(value.files, cue.files) || value.db !== cue.db || Boolean(value.notes.trim()); },
    export: exported,
    storageAvailable: () => storageAvailable,
  };
}

export function selectionIndex(options, files) {
  return options.findIndex(option => sameFiles(option.files, files));
}
