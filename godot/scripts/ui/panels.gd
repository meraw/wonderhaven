class_name Panels
extends Control
## Menu panels: bag, quest journal, Kingdom Harmony, world map, notice board, pause, saves, settings and controls.

var game
var current := ""
var body: VBoxContainer
var capture_action := ""

func setup(g) -> void:
	game = g
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); visible = false; mouse_filter = Control.MOUSE_FILTER_STOP

func open_panel(name: String, title: String) -> VBoxContainer:
	for c in get_children(): c.queue_free()
	# Soft blurred backdrop so the open menu reads clearly against the busy world.
	var dim := ColorRect.new(); dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sm := ShaderMaterial.new(); sm.shader = _backdrop_shader(); dim.material = sm
	dim.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: close())
	add_child(dim)
	var p := UiTheme.panel(UiTheme.CREAM, UiTheme.LINE, 30)
	var ps: StyleBoxFlat = p.get_theme_stylebox("panel").duplicate(); ps.shadow_size = 18; ps.shadow_offset = Vector2(0, 8); ps.shadow_color = Color(0.3, 0.15, 0.25, 0.3)
	ps.border_width_top = 3; ps.content_margin_top = 14; ps.content_margin_left = 22; ps.content_margin_right = 22
	p.add_theme_stylebox_override("panel", ps)
	p.anchor_left = 0.5; p.anchor_right = 0.5; p.anchor_top = 0.5; p.anchor_bottom = 0.5
	p.offset_left = -450; p.offset_right = 450; p.offset_top = -310; p.offset_bottom = 310
	add_child(p)
	p.pivot_offset = Vector2(450, 310); p.scale = Vector2(0.96, 0.96); p.modulate.a = 0.0
	var tw := p.create_tween().set_parallel(); tw.tween_property(p, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT); tw.tween_property(p, "modulate:a", 1.0, 0.12)
	var outer := VBoxContainer.new(); outer.add_theme_constant_override("separation", 10); p.add_child(outer)
	var head := HBoxContainer.new(); outer.add_child(head)
	var ribbon := UiTheme.panel(UiTheme.PINK, UiTheme.PINK_DARK, 999)
	var rs: StyleBoxFlat = ribbon.get_theme_stylebox("panel").duplicate(); rs.content_margin_left = 20; rs.content_margin_right = 20; rs.content_margin_top = 4; rs.content_margin_bottom = 6
	ribbon.add_theme_stylebox_override("panel", rs)
	var tl := UiTheme.label(title, 26, Color.WHITE); tl.add_theme_color_override("font_shadow_color", Color(0.6, 0.2, 0.35, 0.35)); tl.add_theme_constant_override("shadow_offset_y", 2)
	ribbon.add_child(tl); head.add_child(ribbon)
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(sp)
	var cb := UiTheme.button("✕", close); cb.name = "close"; cb.tooltip_text = "Close (Esc)"; cb.custom_minimum_size = Vector2(44, 44); cb.add_theme_font_size_override("font_size", 20)
	head.add_child(cb)
	var scroll := ScrollContainer.new(); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	body = VBoxContainer.new(); body.size_flags_horizontal = Control.SIZE_EXPAND_FILL; body.add_theme_constant_override("separation", 8)
	scroll.add_child(body)
	current = name; visible = true
	if game.mode != "title": game.set_mode("menu")
	game.sfx("open")
	game.emit_event("panel", {"id": name})
	return body

## A first-time tip shown inside the open panel, at the top, instead of a floating card over it.
func inline_tip(tip: Dictionary) -> void:
	if body == null: return
	var p := UiTheme.panel(Color("fffdf3"), UiTheme.GOLD, 16)
	var v := VBoxContainer.new(); p.add_child(v)
	v.add_child(UiTheme.label("💡 " + String(tip.title), 16))
	for line in tip.lines:
		var l := RichTextLabel.new(); l.bbcode_enabled = true; l.fit_content = true; l.scroll_active = false; l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.text = Tutorial.fill(line, func(a): return "[b][color=#e86f8f]%s[/color][/b]" % Controls.key_label(a))
		l.add_theme_font_size_override("normal_font_size", UiTheme.px(14)); l.add_theme_font_size_override("bold_font_size", UiTheme.px(14)); l.add_theme_color_override("default_color", UiTheme.INK2)
		v.add_child(l)
	body.add_child(p); body.move_child(p, 0)

static var _backdrop: Shader
static func _backdrop_shader() -> Shader:
	if _backdrop == null:
		_backdrop = Shader.new()
		_backdrop.code = """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
void fragment() {
	vec3 c = textureLod(screen, SCREEN_UV, 2.5).rgb;
	c = mix(c, vec3(0.42, 0.3, 0.38), 0.32);
	COLOR = vec4(c, 1.0);
}
"""
	return _backdrop

func close() -> void:
	if current == "": return
	current = ""; visible = false
	for c in get_children(): c.queue_free()
	if game.mode == "menu": game.set_mode("explore")
	game.sfx("close")

func update(_dt: float) -> void:
	if current == "" or capture_action != "": return
	if Input.is_action_just_pressed("pause"): close(); return
	for pair in [["inventory", "inventory"], ["journal", "journal"], ["map", "map"], ["progress", "progress"]]:
		if Input.is_action_just_pressed(pair[0]) and current == pair[1]: close(); return

func _input(event: InputEvent) -> void:
	if capture_action != "" and event is InputEventKey and event.pressed:
		get_viewport().set_input_as_handled()
		var a := capture_action; capture_action = ""
		if event.physical_keycode != KEY_ESCAPE:
			game.settings.bindings = Controls.rebind(game.settings.bindings, a, event.physical_keycode)
			game.apply_settings()
		settings()

func _card(bg: Color = Color.WHITE) -> VBoxContainer:
	var p := UiTheme.panel(bg, Color("f3dfc0"), 18)
	var v := VBoxContainer.new(); p.add_child(v); body.add_child(p)
	return v

func _wrap(text: String, size: int = 14, color: Color = UiTheme.INK2) -> Label:
	var l := UiTheme.label(text, size, color); l.autowrap_mode = TextServer.AUTOWRAP_WORD; l.custom_minimum_size.x = 780
	return l

func _taste_place(id: String) -> String:
	var near = Tastes.of(id).get("near", null)
	if near is String: return String(Needs.hangout(Needs.hangouts(), String(near)).get("name", near)).to_lower()
	return "home"

func inventory() -> void:
	open_panel("inventory", "🎒 Your Bag")
	var grid := GridContainer.new(); grid.columns = 5; grid.add_theme_constant_override("h_separation", 10); grid.add_theme_constant_override("v_separation", 10); body.add_child(grid)
	# Things you have come first; ones not found yet stay faint so the bag doesn't read as a wall of zeros.
	var order: Array = Data.resource_order.filter(func(i): return int(game.state.inventory.get(i, 0)) > 0) + Data.resource_order.filter(func(i): return int(game.state.inventory.get(i, 0)) <= 0)
	for id in order:
		var r: Dictionary = Data.resources[id]
		var p := UiTheme.panel(Color.WHITE, Color("f3dfc0"), 18); p.custom_minimum_size = Vector2(150, 0); p.name = "item_" + id
		if int(game.state.inventory.get(id, 0)) <= 0: p.modulate = Color(1, 1, 1, 0.4)
		var v := VBoxContainer.new(); p.add_child(v)
		for l in [UiTheme.label(r.icon, 30), UiTheme.label(str(int(game.state.inventory.get(id, 0))), 22), UiTheme.label(r.name, 12, UiTheme.INK2)]:
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(l)
		grid.add_child(p)
	if game.state.flags.get("hasTool", false):
		body.add_child(UiTheme.label("Tools", 18, UiTheme.INK2))
		for tid in Tools.defs():
			var lv := Tools.stats(game.state, String(tid))
			var nx := Tools.next(game.state, String(tid))
			var seller := String(Data.npc(String(Data.tools.get("seller", ""))).get("name", "")).get_slice(" ", 0)
			var line := "%s  (%d/%d)  %s" % [Tools.label(game.state, String(tid)), int(lv.level), Tools.def(String(tid)).get("levels", []).size(), String(lv.get("does", ""))]
			if not nx.is_empty(): line += "\n      Next: %s at %s's, %s" % [String(nx.get("name", "")), seller, Tools.cost_text(nx)]
			var tl := _wrap(line, 14, UiTheme.INK); tl.name = "tool_" + String(tid)
			body.add_child(tl)
	var st: Dictionary = game.state.stats
	var owned := 0
	for c in Data.appearance.locked:
		if game.state.clothes_owned.has(c): owned += 1
	body.add_child(UiTheme.label("Collection", 18, UiTheme.INK2))
	body.add_child(_wrap("📐 %d / %d blueprints   👗 %d / %d special outfits   🐟 %d fish   💎 %d treasures   🔨 %d pieces built" % [game.state.blueprints.size(), Data.pieces.size(), owned, Data.appearance.locked.size(), st.fish, st.treasures, st.placed], 15, UiTheme.INK))
	body.add_child(UiTheme.label("Friends", 18, UiTheme.INK2))
	for n in Data.npcs:
		if game.state.relationships.has(n.id):
			body.add_child(UiTheme.label("%s — %s   %s" % [n.name, n.title, "♥".repeat(int(game.state.relationships[n.id].get("hearts", 0)))], 15))
			if Tastes.known(game.state, String(n.id)) and not Tastes.of(String(n.id)).is_empty():
				var tl := _wrap("      Likes %s, near %s" % [Tastes.describe(String(n.id)), _taste_place(String(n.id))], 13, UiTheme.INK2)
				tl.name = "taste_" + String(n.id)
				body.add_child(tl)

## A villager's shop: buy bundles and blueprints with coins, or sell them what they want.
func shop(npc_id: String, tab: String = "buy") -> void:
	var d := Shop.def(npc_id)
	if d.is_empty(): return
	open_panel("shop", "🛍 " + String(d.name))
	var s: Dictionary = game.state
	var top := HBoxContainer.new(); top.add_theme_constant_override("separation", 10); body.add_child(top)
	for pair in [["buy", "Buy"], ["sell", "Sell"]]:
		var t: String = pair[0]
		var b := UiTheme.button(pair[1], func(): shop(npc_id, t), tab == t); b.name = "tab_" + t; top.add_child(b)
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top.add_child(sp)
	var purse := UiTheme.panel(Color("fff7cf"), UiTheme.GOLD, 999); purse.name = "purse"
	purse.add_child(UiTheme.label("%s %s" % [Data.resources.coins.icon, Money.lire(Shop.coins(s))], 17)); top.add_child(purse)
	if tab == "buy":
		for e in Shop.stock(s, npc_id):
			var row := _shop_row(e.icon, e.label, "" if e.owned else Money.lire(e.price))
			var i: int = e.i
			var b := UiTheme.button("Owned" if e.owned else "Buy", func(): _shop_buy(npc_id, i), not e.owned and e.afford)
			b.name = "buy_%d" % i; b.disabled = e.owned or not e.afford; b.custom_minimum_size.x = 96
			if not e.owned and not e.afford: b.tooltip_text = ("You need %s more" % Money.lire(e.price - Shop.coins(s))) if Shop.coins(s) < e.price else "You're short of materials for it"
			row.add_child(b)
	else:
		var list := Shop.sellable(s, npc_id)
		var wants: Array = d.get("buys", {}).keys().map(func(id): return "%s %s (%s each)" % [Data.resources[id].icon, Data.resources[id].name, Money.lire(Shop.sell_price(npc_id, id, game.state))])
		body.add_child(_wrap("%s buys: %s." % [Data.npc(npc_id).name, ", ".join(wants)]))
		if list.is_empty(): body.add_child(_wrap("You don't have anything %s wants right now." % Data.pron(npc_id), 15, UiTheme.INK))
		for e in list:
			var r: Dictionary = Data.resources[e.id]
			var row := _shop_row(r.icon, "%s × %d" % [r.name, e.have], "%s each" % Money.lire(e.price))
			var choices: Array = [[1, "Sell 1", "1"]]
			if e.have > 5: choices.append([5, "Sell 5", "5"])
			if e.have > 1: choices.append([e.have, "Sell all", "all"])
			for c in choices:
				var item: String = e.id; var count: int = c[0]
				var b := UiTheme.button(c[1], func(): _shop_sell(npc_id, item, count))
				b.name = "sell_%s_%s" % [e.id, c[2]]
				row.add_child(b)

func _shop_row(icon: String, text: String, price: String) -> HBoxContainer:
	var p := UiTheme.panel(Color.WHITE, Color("f3dfc0"), 16)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 12); p.add_child(row); body.add_child(p)
	row.add_child(UiTheme.label(icon, 24))
	var l := UiTheme.label(text, 17); l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(l)
	if price != "": row.add_child(UiTheme.label(price, 16, UiTheme.INK2))
	return row

func _shop_buy(npc_id: String, i: int) -> void:
	var r := Shop.buy(game.state, npc_id, i)
	if not r.ok:
		game.toast("You need %s more." % Money.lire(int(r.get("need", 0))) if r.reason == "coins" else ("You're short of materials for it." if r.reason == "items" else "You can't buy that."), "warn"); return
	game.sfx("unlock")
	if r.has("tool"):
		game.render_resources()
		if not r.unlocks.is_empty(): game.story.unlock_blueprints(r.unlocks, String(r.name))
		game.banner(Tools.label(game.state, String(r.tool)), String(Tools.stats(game.state, String(r.tool)).get("does", "")), [], 3.6)
		game.emit_event("tool", {"tool": String(r.tool), "level": int(r.level)})
	if r.has("items"): game.render_resources(r.items.keys()); game.emit_event("gain", {"items": r.items})
	if r.has("blueprint"): game.story.unlock_blueprints([r.blueprint])
	if r.has("clothes"): game.story.unlock_clothes([r.clothes])
	if r.has("items"): game.toast("Bought %s" % ", ".join(r.items.keys().map(func(k): return Money.amount(k, int(r.items[k])))), "good", 2.0)
	game.render_resources(["coins"])
	game.emit_event("shop", {"npc": npc_id, "buy": true})
	game.autosave("shop")
	shop(npc_id, "buy")

func _shop_sell(npc_id: String, item: String, n: int) -> void:
	var r := Shop.sell(game.state, npc_id, item, n)
	if not r.ok: return
	game.sfx("pick")
	game.toast("Sold %d %s for %s" % [r.n, Data.resources[item].name, Money.lire(r.coins)], "good", 2.0)
	game.render_resources(["coins"])
	game.emit_event("shop", {"npc": npc_id, "sell": true, "coins": r.coins})
	game.autosave("shop")
	shop(npc_id, "sell")

## The journal shows the place you're in: its requests, its side requests and what you've finished there. Requests
## left going in other places wait in their own tab ("Other places"), so they don't crowd the one you're in.
func journal(tab: String = "active") -> void:
	open_panel("journal", "📜 Quest Journal")
	var e: QuestEngine = game.story.engine
	var away: Array = e.active().filter(func(q): return not e.here(q.id))
	var tabs := HBoxContainer.new(); body.add_child(tabs)
	var tab_list := [["active", "Active"], ["optional", "Available side quests"], ["done", "Completed"]]
	if not away.is_empty(): tab_list.append(["elsewhere", "Other places (%d)" % away.size()])
	for pair in tab_list:
		var t: String = pair[0]
		var b := UiTheme.button(pair[1], func(): journal(t), tab == t); b.name = "tab_" + t; tabs.add_child(b)
	if tab == "elsewhere": _journal_elsewhere(away); return
	var qs: Array = []
	match tab:
		"active": qs = e.active().filter(func(q): return e.here(q.id))
		"optional": qs = Data.quests.filter(func(q): return not q.get("main", false) and (e.can_offer(q.id) or e.later_for(q.giver).has(q)) and e.here(q.id))
		"done": qs = e.done().filter(func(q): return e.here(q.id))
	if tab == "active":
		for lq in e.story_leads():
			var lv := _card(Color("fff8e6"))
			lv.add_child(UiTheme.label("★ Next in the story · From " + Data.npc(lq.giver).name, 12, Color("b34a6a")))
			lv.add_child(UiTheme.label(lq.title, 18))
			lv.add_child(_wrap("%s has a request for you. Find %s (look for the ! over %s head) and talk to %s to begin." % [Data.npc(lq.giver).name, Data.pron(lq.giver, "them"), Data.pron(lq.giver, "their"), Data.pron(lq.giver, "them")]))
			var lid: String = "lead:" + lq.id
			var tb := UiTheme.button("📍 Tracking" if game.state.tracked == lid else "📍 Track", func(): game.state.tracked = lid; game.hud.render_tracker(); close(); game.toast("Heading for %s" % Data.npc(lq.giver).name), game.state.tracked == lid)
			tb.name = "track_" + lid; lv.add_child(tb)
	if qs.is_empty() and not (tab == "active" and not e.story_leads().is_empty()):
		body.add_child(_wrap({"active": "No active quests. Look for villagers with a ! over their heads.", "optional": "No new side quests right now — keep exploring!", "done": "Nothing completed here yet. Every journey starts with a single plank."}[tab], 15))
	for q in qs:
		var v := _card(Color("f6fff8") if tab == "done" else Color.WHITE)
		v.add_child(UiTheme.label(("★ Main story · " if q.get("main", false) else "") + "From " + Data.npc(q.giver).name, 12, Color("b34a6a")))
		v.add_child(UiTheme.label(q.title, 18))
		v.add_child(_wrap(q.description))
		if tab == "optional" and q.has("hours"): v.add_child(UiTheme.label("🕒 %s asks about this %s" % [Data.npc(q.giver).name, Clock.hours_text(q.hours)], 13, UiTheme.INK))
		if tab == "active":
			_journal_steps(v, q)
			var qid: String = q.id
			v.add_child(UiTheme.button("📍 Tracking" if game.state.tracked == qid else "📍 Track", func(): game.state.tracked = qid; game.hud.render_tracker(); close(); game.toast("Tracking “%s”" % q.title), game.state.tracked == qid))
		if tab == "optional": v.add_child(UiTheme.label("Talk to %s to start." % Data.npc(q.giver).name, 13, Color("b34a6a")))
		v.add_child(UiTheme.label(_rewards_text(q.get("rewards", {}), Data.quest_island(q.id)), 13, Color("a07a20")))
	if tab == "active" and not away.is_empty():
		body.add_child(_wrap("Also unfinished in other places: %s. They wait for you there (see “Other places”)." % ", ".join(_places_of(away)), 13))

func _journal_steps(v: VBoxContainer, q: Dictionary) -> void:
	var e: QuestEngine = game.story.engine
	var shown := e.shown_objectives(q.id)
	var n_st := e.stages(q.id).size()
	if n_st > 1: v.add_child(UiTheme.label("Step %d of %d" % [e.stage_index(q.id), n_st], 13, Color("b34a6a")))
	for o in shown.objectives:
		var st := e.objective(q.id, o)
		var txt: String = ("✔ " if st.done else "○ ") + o.text + ("  🕒 " + Clock.hours_text(o.hours) if o.has("hours") and not st.done else "")
		if not st.done and st.need > 1: txt += " (%d/%d)" % [int(game.state.harmony) if o.kind == "harmony" else st.have, st.need]
		v.add_child(UiTheme.label(txt, 14, Color("59a86f") if st.done else UiTheme.INK))
	if shown.later > 0: v.add_child(UiTheme.label("🔒 More to do once this step is done", 13, UiTheme.INK2))

## Names of the places these requests belong to, in the order of the map.
func _places_of(qs: Array) -> Array:
	var out: Array = []
	for isl in Data.islands:
		if qs.any(func(q): return Data.quest_island(q.id) == isl.id): out.append(String(isl.get("name", isl.id)))
	return out

## Requests still going in other places, by place: where you left them, to pick up when you go back.
func _journal_elsewhere(away: Array) -> void:
	body.add_child(_wrap("Requests you started in other places. They keep their progress and wait for you; the compass only points at them once you're there.", 14))
	for isl in Data.islands:
		var mine: Array = away.filter(func(q): return Data.quest_island(q.id) == isl.id)
		if mine.is_empty(): continue
		body.add_child(UiTheme.label("📍 " + String(isl.get("name", isl.id)), 18, UiTheme.PINK_DARK))
		for q in mine:
			var v := _card(Color("f7f4ee"))
			v.add_child(UiTheme.label(("★ Main story · " if q.get("main", false) else "") + "From " + Data.npc(q.giver).name, 12, Color("b34a6a")))
			v.add_child(UiTheme.label(q.title, 17))
			_journal_steps(v, q)

func _rewards_text(r: Dictionary, island: String = "") -> String:
	var parts: Array = []
	if r.get("harmony", 0) > 0: parts.append("💖 %d" % int(r.harmony))
	if r.get("meter", 0) > 0: parts.append(LocationMeter.reward_text(LocationMeter.def(island if island != "" else Data.island), int(r.meter)))
	for k in r.get("items", {}): parts.append(Money.amount(k, int(r.items[k])) if k == "coins" else "%s %d" % [Data.resources[k].icon, int(r.items[k])])
	for b in r.get("blueprints", []): parts.append("📐 " + Data.piece(b).name)
	for c in r.get("clothes", []): parts.append("👗 " + Data.appearance.labels.get(c, c))
	return "Rewards: " + ("  ".join(parts) if not parts.is_empty() else "the villagers' gratitude")

func progress() -> void:
	var m := LocationMeter.def(Data.island)
	if not m.is_empty(): _meter_progress(m); return
	open_panel("progress", "💖 The Sindaco's Approval Rating")
	var h := int(game.state.harmony)
	var nx := Harmony.next_unlock(h)
	body.add_child(UiTheme.label("Approval: %d%s" % [h, ("  ·  Next: %s at %d" % [nx.title, int(nx.at)]) if not nx.is_empty() else "  ·  Every milestone reached!"], 22))
	var bar := ProgressBar.new(); bar.custom_minimum_size = Vector2(780, 20); bar.show_percentage = false; bar.max_value = nx.at if not nx.is_empty() else 1; bar.value = h if not nx.is_empty() else 1; body.add_child(bar)
	body.add_child(_wrap("The Sindaco's approval rating grows when you help villagers, finish requests, build something new for the first time and fix up the village. He takes the credit; you get the rewards."))
	_village_why(h)
	_openings()
	var best := maxi(h, int(game.state.get("approval_best", h)))
	for u in Data.harmony_unlocks:
		var got: bool = best >= u.at
		var v := _card(Color("f3fff6") if got else Color.WHITE)
		v.add_child(UiTheme.label(("🌟 " if got else "🔒 ") + u.title + ("   Unlocked" if got else "   at %d approval" % int(u.at)), 16))
		v.add_child(_wrap(u.desc, 13))

func _openings() -> void:
	var list: Array = game.state.get("openings", []) if game.state.get("openings") is Array else []
	if list.is_empty(): return
	var v := _card(Color("fffaf0"))
	v.name = "openings"
	v.add_child(UiTheme.label("🎀 Openings", 16))
	var recent: Array = list.slice(maxi(list.size() - 6, 0))
	recent.reverse()
	for o in recent:
		var l := _wrap("Day %d · %s %s · %s" % [int(o.get("day", 0)), String(o.get("what", "")), String(o.get("place", "")), String(o.get("grade", ""))], 13, UiTheme.INK)
		v.add_child(l)
	if list.size() > 6: v.add_child(_wrap("And %d before those." % (list.size() - 6), 12, UiTheme.INK2))

func _village_why(h: int) -> void:
	var hs := Needs.hangouts()
	if hs.is_empty(): return
	var vp := int(game.state.get("village_points", 0))
	var why := UiTheme.label("Why? %d from requests, firsts and friends, and %d from the village as it is now" % [h - vp, vp], 17, UiTheme.INK); why.name = "approval_why"
	body.add_child(why)
	var per := int(Data.needs.get("points", 5))
	var known: Array = Needs.of(game.state).noticed
	var v: Dictionary = game.village_score
	for hg in hs:
		var hid := String(hg.id)
		var c := _card()
		c.name = "why_" + hid
		var charm := 0
		for ch in v.get("charm", []):
			if ch.hangout == hid: charm = int(ch.points)
		var lively := Visits.level(v, hid)
		c.add_child(UiTheme.label("%s   %s%s" % [String(hg.name), ("★".repeat(charm) + "  charm +%d" % charm) if charm > 0 else "no charm yet", ("   · lively %d/3" % lively) if lively > 0 else ""], 16))
		var hidden := 0
		for n in v.get("needs", []):
			if n.hangout != hid: continue
			var kd := Needs.kind_def(String(n.kind))
			if n.met: c.add_child(_wrap("%s ✔ %s  +%d" % [String(kd.get("icon", "")), String(kd.get("name", n.kind)), per], 13, Color("2f8a52")))
			elif known.has(n.key): c.add_child(_wrap("%s ○ %s: wanted, not there yet" % [String(kd.get("icon", "")), String(kd.get("name", n.kind))], 13, UiTheme.INK))
			else: hidden += 1
		if hidden > 0: c.add_child(_wrap("… and maybe something nobody has mentioned yet.", 12))

## The progress screen for a location with its own meter (LocationMeter): its reading, what it's about, milestones.
func _meter_progress(m: Dictionary) -> void:
	open_panel("progress", "%s %s" % [m.get("icon", "📈"), m.get("name", "Progress")])
	var pts := LocationMeter.points(game.state, Data.island)
	var nx := LocationMeter.next_milestone(m, pts)
	body.add_child(UiTheme.label("%s%s" % [LocationMeter.reading(m, pts), ("  ·  Next: %s at %s" % [nx.title, LocationMeter.reading(m, int(nx.at))]) if not nx.is_empty() else "  ·  Every milestone reached!"], 22))
	var bar := ProgressBar.new(); bar.custom_minimum_size = Vector2(780, 20); bar.show_percentage = false; bar.max_value = int(nx.at) if not nx.is_empty() else 1; bar.value = pts if not nx.is_empty() else 1; body.add_child(bar)
	if m.has("about"): body.add_child(_wrap(String(m.about)))
	for u in m.get("milestones", []):
		var got: bool = pts >= int(u.at) and (not u.has("requires") or LocationMeter.reached(game.state, u))
		var v := _card(Color("f3fff6") if got else Color.WHITE)
		var when := "   at %s" % LocationMeter.reading(m, int(u.at)) + (" and " + String(u.waits) if u.has("waits") else "")   # waits: what else it needs
		v.add_child(UiTheme.label(("🌟 " if got else "🔒 ") + String(u.title) + ("   Reached" if got else when), 16))
		v.add_child(_wrap(String(u.desc), 13))

func notice_board() -> void:
	open_panel("board", "📌 Village Notice Board")
	var e: QuestEngine = game.story.engine
	var offers := Data.quests.filter(func(q): return e.can_offer(q.id) and e.here(q.id))   # this place's board
	if offers.is_empty(): body.add_child(_wrap("No new requests posted. %s is having a quiet day." % String(Data.island_def(Data.island).get("name", "The village")), 15, UiTheme.INK))
	for q in offers:
		var v := _card()
		v.add_child(UiTheme.label("Posted by " + Data.npc(q.giver).name, 12, Color("b34a6a"))); v.add_child(UiTheme.label(q.title, 17)); v.add_child(_wrap(q.description))
	body.add_child(_wrap("Tips: a gold ! over someone means a request; a green ★ means you can report back. Your metal detector beeps near buried finds.", 14))

func map(from_boat: bool = false) -> void:
	open_panel("map", "🗺️ Map")
	var info := _wrap("Where to? Pick a destination." if from_boat else "Click a place to learn about it.", 15, UiTheme.INK)
	var canvas := MapView.new(); canvas.game = game; canvas.custom_minimum_size = Vector2(800, 430); canvas.name = "map_view"
	canvas.picked.connect(func(isl: Dictionary):
		info.text = "%s: %s" % [isl.name, isl.desc]   # only places you've unlocked are on the map (Travel.on_map)
		for c in body.get_children():
			if c.name == "sail": c.queue_free()
		if isl.id == Data.island: info.text += "  (You are here.)"
		elif not from_boat and not game.state.flags.get("boatReady", false): info.text += "  Build the new bus stop to start travelling."
		else:
			var b := UiTheme.button("🚌 Travel to " + isl.name, func(): game.sail_to(isl), true); b.name = "sail"; body.add_child(b)
			# with a tip card above the map the button can fall below the fold: bring it into view once laid out
			var sc := body.get_parent() as ScrollContainer
			if sc: get_tree().create_timer(0.1).timeout.connect(func(): if is_instance_valid(b) and is_instance_valid(sc): sc.ensure_control_visible(b))
		game.sfx("select"))
	body.add_child(canvas); body.add_child(info)

const WAKE_TIMES := [["🌅", "Dawn", 6], ["☀️", "Morning", 9], ["🕛", "Noon", 12], ["🌇", "Evening", 18], ["🌙", "Night", 21]]

## Sleep or nap until a chosen time of day (some requests only happen at certain hours).
func sleep(where: String, seat = null) -> void:
	open_panel("sleep", "🪑 A bench" if where == "bench" else "🛏️ Time to rest")
	var now: float = game.state.time.minute
	body.add_child(_wrap(("Take a nap here until…" if where == "bench" else "Sleep until…") + "   (it's %s now)" % Clock.text(game.state.time).get_slice("· ", 1), 16, UiTheme.INK))
	var v := VBoxContainer.new(); v.custom_minimum_size.x = 420; v.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; v.add_theme_constant_override("separation", 8); body.add_child(v)
	var day_rules := WorkDay.def(Data.island)
	if WorkDay.holds(day_rules):
		for o in WorkDay.sleep_options(now, day_rules):
			var opt: Dictionary = o
			var mins: float = WorkDay.next_morning(game.state.time) - float(game.state.time.total) if opt.ends_day else float(opt.hour) * 60.0 - now
			var text := "%s  %s · %s   (in %dh %02dm)" % [opt.icon, opt.label, Clock.hour_num(opt.hour), int(mins / 60.0), int(fmod(mins, 60.0))]
			if opt.ends_day: text = "%s  Sleep until tomorrow morning · ends the day" % opt.icon
			var ob := UiTheme.button(text, func(): game.sleep_until(opt.hour, where, seat, opt.ends_day), opt.ends_day)
			ob.name = String(opt.id); ob.alignment = HORIZONTAL_ALIGNMENT_LEFT; v.add_child(ob)
		if where == "bench" and seat != null:
			var sit := UiTheme.button("🪑  Just sit a while", func(): close(); game.sit_on(seat)); sit.name = "just_sit"; v.add_child(sit)
		return
	for w in WAKE_TIMES:
		var mins := fposmod(float(w[2]) * 60.0 - now, 1440.0)
		if mins < 1.0: mins = 1440.0
		var hour: float = w[2]
		var ends := WorkDay.ends_day(game.state.time, int(WorkDay.record(game.state).day), hour, day_rules)
		var b := UiTheme.button("%s  %s · %s   (in %dh %02dm)%s" % [w[0], w[1], Clock.hour_num(hour), int(mins / 60.0), int(fmod(mins, 60.0)), " · ends the day" if ends else ""], func(): game.sleep_until(hour, where, seat, ends))
		b.name = "wake_%d" % int(hour); b.alignment = HORIZONTAL_ALIGNMENT_LEFT; v.add_child(b)
	if where == "bench" and seat != null:
		var st := UiTheme.button("🪑  Just sit a while", func(): close(); game.sit_on(seat), true); st.name = "just_sit"; v.add_child(st)

## Where to from a stop (a tram stop, say): the other stops on its line, and how long the ride takes.
func stops(stop: Dictionary) -> void:
	open_panel("stops", "🚋 " + String(stop.get("name", "Stop")))
	body.add_child(_wrap("Where to?", 16, UiTheme.INK))
	var v := VBoxContainer.new(); v.custom_minimum_size.x = 420; v.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; v.add_theme_constant_override("separation", 8); body.add_child(v)
	for to in Travel.stops_on(stop, Data.layout.features):
		var dest: Dictionary = to
		var b := UiTheme.button("%s   (about %d min)" % [String(to.get("name", to.id)), int(round(Travel.ride_minutes(stop, to)))], func(): game.ride_to(stop, dest))
		b.name = "ride_" + String(to.id); b.alignment = HORIZONTAL_ALIGNMENT_LEFT; v.add_child(b)

func pause() -> void:
	open_panel("pause", "🌟 Paused")
	var v := VBoxContainer.new(); v.custom_minimum_size.x = 300; v.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; v.add_theme_constant_override("separation", 10); body.add_child(v)
	for pair in [["▶ Resume", close, true], ["💾 Save game", func(): saves("save"), false], ["📂 Load game", func(): saves("load"), false], ["👗 Wardrobe", func(): close(); game.open_wardrobe(), false], ["⚙️ Settings & controls", settings, false], ["🆘 I'm stuck", func(): close(); game.unstick(), false], ["🏠 Quit to title", func(): close(); game.to_title(), false]]:
		var b := UiTheme.button(pair[0], pair[1], pair[2]); b.name = "btn_" + str(pair[0]).substr(2).to_lower().replace(" ", "_"); v.add_child(b)

func saves(mode: String) -> void:
	open_panel("saves", "💾 Save Game" if mode == "save" else "📂 Load Game")
	var slots: Array = SaveSystem.SLOTS if mode == "save" else [SaveSystem.AUTOSAVE] + SaveSystem.SLOTS
	for slot in slots:
		var m := SaveSystem.meta(slot)
		var v := _card()
		var row := HBoxContainer.new(); v.add_child(row)
		var desc: String = "Empty" if m.is_empty() else ("Damaged save" if m.get("broken", false) else "%s · Day %d · 💖 %d · %d quests done" % [m.name, m.day, m.harmony, m.quests])
		var l := UiTheme.label(("Autosave" if slot == SaveSystem.AUTOSAVE else "Slot " + slot.right(1)) + "   —   " + desc, 15); l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(l)
		var s: String = slot
		var b: Button
		if mode == "save": b = UiTheme.button("Overwrite" if not m.is_empty() else "Save here", func(): game.save_to(s); saves("save"), true)
		else:
			b = UiTheme.button("Load", func(): close(); game.load_from(s), true); b.disabled = m.is_empty() or m.get("broken", false)
		b.name = "slot_" + slot; row.add_child(b)
	body.add_child(UiTheme.button("← Back", pause))

func settings() -> void:
	open_panel("settings", "⚙️ Settings")
	var st: Dictionary = game.settings
	for pair in [["🎵 Music volume", "music", 0.0, 1.0], ["🔔 Sound effects", "sfx", 0.0, 1.0], ["🖱️ Camera sensitivity", "sensitivity", 0.3, 2.5]]:
		var row := HBoxContainer.new(); body.add_child(row)
		var l := UiTheme.label(pair[0], 15); l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(l)
		var sl := HSlider.new(); sl.min_value = pair[2]; sl.max_value = pair[3]; sl.step = 0.05; sl.value = st[pair[1]]; sl.custom_minimum_size.x = 220
		var key: String = pair[1]
		sl.value_changed.connect(func(v): st[key] = v; game.apply_settings())
		row.add_child(sl)
	var toggles := [["↕️ Invert camera Y", "invert_y"], ["🌦️ Weather effects", "weather"], ["★ Evening inaugurations", "inaugurations"]]
	if Outline.supported(): toggles.append(["✏️ Ink outlines", "outlines"])
	toggles.append(["🖥️ Simpler graphics, for slower computers", "simple_graphics"])
	toggles.append(["🖥️ Fullscreen (F11)", "fullscreen"])
	for pair in toggles:
		var cb := CheckBox.new(); cb.text = pair[0]; cb.button_pressed = st.get(pair[1], pair[1] not in ["fullscreen", "simple_graphics"])
		var key2: String = pair[1]
		cb.toggled.connect(func(v): st[key2] = v; game.apply_settings())
		body.add_child(cb)
	body.add_child(UiTheme.label("Controls — click a key to change it", 18, UiTheme.INK2))
	for a in Controls.DEFAULTS:
		var row := HBoxContainer.new(); body.add_child(row)
		var l := UiTheme.label(Controls.LABELS[a], 14); l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(l)
		var act: String = a
		var b := UiTheme.button("Press a key…" if capture_action == a else " / ".join(Controls.keys_of(a).map(func(k): return OS.get_keycode_string(k))), func(): capture_action = act; settings())
		row.add_child(b)
	body.add_child(_wrap("F11 or Alt+Enter: fullscreen. Undo / redo in build mode: Ctrl+Z / Ctrl+Y. Gamepad: left stick move · right stick camera · A interact · X build · Y journal · Start menu · Back map.", 13))
	var row2 := HBoxContainer.new(); body.add_child(row2)
	row2.add_child(UiTheme.button("Reset controls", func(): st.bindings = {}; game.apply_settings(); settings()))
	row2.add_child(UiTheme.button("← Back", pause))

class MapView extends Control:
	signal picked(island: Dictionary)
	var game
	var trip_from := ""
	var trip_to := ""
	var trip_t := 0.0
	var vehicle := "🚌"
	## Places on the map: only the ones you've unlocked, and the one you're in (Travel.on_map). They turn up as
	## surprises, and the view widens to take them in (Travel.map_frame).
	func _shown() -> Array: return Data.islands.filter(func(i): return Travel.on_map(i, game.state.flags, Data.island) or i.id in [trip_from, trip_to])
	func _frame() -> Rect2: return Travel.map_frame(_shown())
	## Where a point of the map (in map units) is drawn on screen.
	func to_screen(p: Vector2) -> Vector2:
		var f := _frame()
		return (p - f.position) * (size / f.size)

	func _draw() -> void:
		var f := _frame()
		var k := size.x / f.size.x   # map units to pixels, for sizes
		draw_rect(Rect2(Vector2.ZERO, size), Color("7fd0ec"))
		var s := size / Vector2(800, 500)
		for n in 40:
			var x := float((n * 137) % 780 + 10) * s.x
			var y := float((n * 89) % 480 + 10) * s.y
			draw_arc(Vector2(x + 8, y), 8, PI, TAU, 8, Color("a9e4f5"), 3)
		var hg: Dictionary = Data.islands[0]
		for isl in _shown():
			if isl.id == "hearthglow": continue
			var a := to_screen(Vector2(hg.x, hg.y))
			var b := to_screen(Vector2(isl.x, isl.y))
			var steps := 16
			for j in steps:
				if j % 2 == 1: continue
				draw_line(a.lerp(b, float(j) / steps), a.lerp(b, float(j + 1) / steps), Color(1, 1, 1, 0.95), 4)
		var route := trip_route()
		if route.size() >= 2:
			var at := trip_point(route, trip_t)
			var done := 0.0
			var whole := 0.0
			for j in route.size() - 1: whole += route[j].distance_to(route[j + 1])
			for j in route.size() - 1:
				var seg: float = route[j].distance_to(route[j + 1])
				var upto := clampf((trip_t * whole - done) / maxf(seg, 0.001), 0.0, 1.0)
				if upto > 0.0: draw_line(route[j], route[j].lerp(route[j + 1], upto), Color("ffd166"), 7)
				done += seg
		for isl in _shown():
			var c := to_screen(Vector2(isl.x, isl.y))
			var r: float = isl.r * k
			draw_circle(c + Vector2(0, 8), r + 12, Color("f0dfae"))
			draw_circle(c, r, Color(isl.color))
			for j in 5: draw_circle(c + Vector2(cos(j * 1.3) * r * 0.5, sin(j * 1.7) * r * 0.35), 7, Color("4fae63"))
			var font := UiTheme.main_font()
			var name: String = isl.name
			var lw := maxf(r * 2.0, 220.0)   # wide enough for the whole name
			draw_string_outline(font, c + Vector2(-lw / 2.0, r + 30), name, HORIZONTAL_ALIGNMENT_CENTER, lw, 18, 6, Color.WHITE)
			draw_string(font, c + Vector2(-lw / 2.0, r + 30), name, HORIZONTAL_ALIGNMENT_CENTER, lw, 18, UiTheme.INK)
			if trip_to != "": continue
			if isl.id == Data.island:   # you are here, with how many requests are open on this island
				draw_string(font, c + Vector2(-r * 0.7, -r * 0.4), "📍", HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
				var e: QuestEngine = game.story.engine
				var n: int = e.active().filter(func(q): return e.here(q.id)).size() + Data.quests.filter(func(q): return e.can_offer(q.id) and e.here(q.id)).size()
				if n > 0: draw_string(font, c + Vector2(r * 0.5, -r * 0.5), "❗%d" % n, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UiTheme.PINK_DARK)
		if route.size() >= 2:
			var p := trip_point(route, trip_t)
			var hop := absf(sin(trip_t * 40.0)) * 5.0
			draw_circle(p + Vector2(0, 10), 16, Color(0, 0, 0, 0.18))
			draw_string(UiTheme.main_font(), p + Vector2(-17, 10 - hop), vehicle, HORIZONTAL_ALIGNMENT_LEFT, -1, 30)

	func trip_route() -> Array:
		if trip_from == "" or trip_to == "": return []
		var a := Data.island_def(trip_from)
		var b := Data.island_def(trip_to)
		if a.is_empty() or b.is_empty(): return []
		var hub: Dictionary = Data.islands[0]
		var pts: Array = [to_screen(Vector2(a.x, a.y))]
		if trip_from != hub.id and trip_to != hub.id: pts.append(to_screen(Vector2(hub.x, hub.y)))
		pts.append(to_screen(Vector2(b.x, b.y)))
		return pts

	func trip_point(route: Array, f: float) -> Vector2:
		var whole := 0.0
		for j in route.size() - 1: whole += route[j].distance_to(route[j + 1])
		var left := clampf(f, 0.0, 1.0) * whole
		for j in route.size() - 1:
			var seg: float = route[j].distance_to(route[j + 1])
			if left <= seg: return route[j].lerp(route[j + 1], left / maxf(seg, 0.001))
			left -= seg
		return route[route.size() - 1]

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			var k := size.x / _frame().size.x
			for isl in _shown():
				if ev.position.distance_to(to_screen(Vector2(isl.x, isl.y))) < isl.r * k + 10: picked.emit(isl); return
