// Undo / redo stack of construction commands. The game supplies apply(cmd, direction) which returns true on success.
export class History {
  constructor(limit = 60) { this.done = []; this.undone = []; this.limit = limit; }
  push(cmd) { this.done.push(cmd); if (this.done.length > this.limit) this.done.shift(); this.undone = []; }
  canUndo() { return this.done.length > 0; }
  canRedo() { return this.undone.length > 0; }
  undo(apply) {
    const cmd = this.done[this.done.length - 1]; if (!cmd) return { ok: false, reason: 'Nothing to undo' };
    const r = apply(cmd, 'undo'); if (!r.ok) return r;
    this.done.pop(); this.undone.push(cmd); return { ok: true, cmd };
  }
  redo(apply) {
    const cmd = this.undone[this.undone.length - 1]; if (!cmd) return { ok: false, reason: 'Nothing to redo' };
    const r = apply(cmd, 'redo'); if (!r.ok) return r;
    this.undone.pop(); this.done.push(cmd); return { ok: true, cmd };
  }
  clear() { this.done = []; this.undone = []; }
}
