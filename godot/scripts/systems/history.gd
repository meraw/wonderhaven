class_name History
extends RefCounted
## Undo / redo stack. apply(cmd, "undo" | "redo") returns {ok, reason?}.
var done: Array = []
var undone: Array = []
var limit := 60
func push(cmd: Dictionary) -> void:
	done.append(cmd)
	if done.size() > limit: done.pop_front()
	undone.clear()
func can_undo() -> bool: return not done.is_empty()
func can_redo() -> bool: return not undone.is_empty()
func undo(apply: Callable) -> Dictionary:
	if done.is_empty(): return {"ok": false, "reason": "Nothing to undo"}
	var r: Dictionary = apply.call(done.back(), "undo")
	if not r.ok: return r
	undone.append(done.pop_back()); return {"ok": true}
func redo(apply: Callable) -> Dictionary:
	if undone.is_empty(): return {"ok": false, "reason": "Nothing to redo"}
	var r: Dictionary = apply.call(undone.back(), "redo")
	if not r.ok: return r
	done.append(undone.pop_back()); return {"ok": true}
func clear() -> void: done.clear(); undone.clear()
