export class PreviewPlayer {
  constructor(assets, notify, muted = false) {
    this.assets = new Map(assets.map(asset => [asset.id, asset]));
    this.notify = notify;
    this.muted = muted;
    this.master = .75;
    this.current = null;
    this.serial = 0;
    this.audio = new Audio();
    this.audio.preload = 'none';
    this.audio.muted = muted;
    this.context = null;
  }

  async play(id, cue, choice) {
    this.stop(false);
    const serial = this.serial;
    this.current = {id, cue, choice: {...choice, files: [...choice.files]}, index: 0};
    try {
      if (!this.context) {
        this.context = new (window.AudioContext || window.webkitAudioContext)();
        this.gain = this.context.createGain();
        this.context.createMediaElementSource(this.audio).connect(this.gain);
        this.gain.connect(this.context.destination);
      }
      this.setGain();
      await this.context.resume();
      if (serial !== this.serial) return;
      await this.playNext(serial);
    } catch (error) { this.fail(error, serial); }
  }

  async playNext(serial) {
    if (serial !== this.serial || !this.current) return;
    const item = this.current;
    const asset = this.assets.get(item.choice.files[item.index]);
    if (!asset) return this.fail(new Error('This clip is missing from the library.'), serial);
    this.audio.src = asset.url;
    this.audio.loop = Boolean(item.cue.loop);
    this.audio.onended = () => {
      if (serial !== this.serial || !this.current) return;
      item.index += 1;
      if (item.index >= item.choice.files.length) return this.stop();
      this.playNext(serial).catch(error => this.fail(error, serial));
    };
    this.audio.onerror = () => this.fail(new Error(`Could not load ${asset.label}. Rebuild the audition page and try again.`), serial);
    this.notify({id: item.id, title: item.cue.label,
      detail: `${asset.label}${item.choice.files.length > 1 ? ` · ${item.index + 1}/${item.choice.files.length}` : ''}${item.cue.loop ? ' · looping' : ''}${this.muted ? ' · muted QA preview' : ''}`});
    await this.audio.play();
  }

  setGain(db) {
    if (this.current && db !== undefined) this.current.choice.db = db;
    if (this.gain) this.gain.gain.value = this.muted ? 0 : this.master * Math.pow(10, (this.current?.choice.db || 0) / 20);
  }

  stop(notify = true) {
    this.serial += 1;
    this.audio.onended = null;
    this.audio.onerror = null;
    this.audio.pause();
    this.audio.removeAttribute('src');
    this.audio.load();
    this.current = null;
    if (notify) this.notify(null);
  }

  fail(error, serial) {
    if (serial !== this.serial) return;
    this.stop(false);
    this.notify({error: error.message || 'Playback was blocked. Press Play again.'});
  }
}
