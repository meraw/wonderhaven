class_name History
extends RefCounted
## Undo / redo stack. apply(cmd, "undo" | "redo") returns {ok, reason?}.
var done: Array = []
var undone: Array = []
var limit := 60
var grouping := false
var group: Array = []
func push(cmd: Dictionary) -> void:
	if grouping:
		group.append(cmd)
		return
	done.append(cmd)
	if done.size() > limit: done.pop_front()
	undone.clear()
func begin_group() -> void:
	end_group()
	grouping = true
func end_group() -> void:
	if not grouping: return
	grouping = false
	var cmds: Array = group
	group = []
	if cmds.size() == 1: push(cmds[0])
	elif cmds.size() > 1: push({"type": "group", "cmds": cmds})
func can_undo() -> bool: return not done.is_empty() or not group.is_empty()
func can_redo() -> bool: return not undone.is_empty()
func undo(apply: Callable) -> Dictionary:
	end_group()
	if done.is_empty(): return {"ok": false, "reason": "Nothing to undo"}
	var r: Dictionary = _apply(done.back(), "undo", apply)
	if not r.ok: return r
	undone.append(done.pop_back()); return {"ok": true}
func redo(apply: Callable) -> Dictionary:
	end_group()
	if undone.is_empty(): return {"ok": false, "reason": "Nothing to redo"}
	var r: Dictionary = _apply(undone.back(), "redo", apply)
	if not r.ok: return r
	done.append(undone.pop_back()); return {"ok": true}
func clear() -> void:
	done.clear(); undone.clear()
	grouping = false
	group = []
func _apply(cmd: Dictionary, dir: String, apply: Callable) -> Dictionary:
	if String(cmd.get("type", "")) != "group": return apply.call(cmd, dir)
	var order: Array = cmd.cmds.duplicate()
	if dir == "undo": order.reverse()
	var applied: Array = []
	for c in order:
		var r: Dictionary = apply.call(c, dir)
		if not r.ok:
			applied.reverse()
			for back in applied: apply.call(back, "redo" if dir == "undo" else "undo")
			return r
		applied.append(c)
	return {"ok": true}
