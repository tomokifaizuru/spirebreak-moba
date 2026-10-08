class_name HudCanvas
extends Control
## Draws the whole in-match HUD (layout follows draft-hud.png) and handles multi-touch:
##   left half  -> floating joystick
##   right side -> Attack, 3 skills, Ultimate (tap = auto-aim, drag = aim, drag back = cancel)
##   top-left   -> minimap (hold to look around), SHOP and CENTER (camera) buttons
##   empty screen on the right -> drag to pan the camera (eases back to your hero after ~2 s
##   idle or as soon as you move); top bar -> both teams' heroes (grey + timer while dead)
##   bottom -> portrait with 6 item slots, Recall and Heal; purple button = active item (Blink).
## Desktop: WASD / arrows move, Space or J attack, 1-2-3 (or Q-E-F) skills, R or 4 ultimate,
## G blink toward the mouse, Tab shop, C center camera, B recall, H heal, Esc / P pause.
## Skills aim at the mouse when you use one. Right-click moves; right/middle-drag or screen
## edges pan the camera.

const JOY_R := 80.0
const SKILL_COLORS := [Color("f0a040"), Color("5b8fd6"), Color("e9b93a"), Color("e8455a")]
const ATTACK_COLOR := Color("f08a2c")

var hud: Node
var arena: Arena
var font: Font
var pointers := {}
var joy_center := Vector2.ZERO
var joy_knob := Vector2.ZERO
var joy_active := false
var feed_items: Array = []
var toast_text := ""
var toast_t := 0.0
## Set false to hide the autopilot hint (used by the screenshot tool).
var show_autopilot_label := true
var last_mouse_t := -100.0
var mouse_pos := Vector2.ZERO
var sb_panel: StyleBoxFlat
var sb_dark: StyleBoxFlat
var mm_lane := PackedVector2Array()
var mm_river := PackedVector2Array()
var lay := {}
var portrait_tex: Texture2D
var shop: ShopPanel
## Team bar portraits: hero -> {"tex": ViewportTexture, "gray": ImageTexture, "color": ImageTexture}
var team_icons := {}
var icon_frames := 0
## Free camera: world point the camera looks at while panned (INF = follow your hero).
var cam_pan := Vector2.INF
var pan_idle := 0.0
## Seconds of no panning before the camera eases back to your hero.
const PAN_RETURN_DELAY := 2.0
## Desktop edge-pan speed (world px / s) and edge band (screen px).
const EDGE_PAN_SPEED := 1500.0
const EDGE_BAND := 10.0
var last_touch_t := -100.0


func _ready() -> void:
	font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	sb_panel = StyleBoxFlat.new()
	sb_panel.bg_color = Color(0.07, 0.08, 0.12, 0.82)
	sb_panel.set_corner_radius_all(12)
	sb_panel.border_color = Color(1, 1, 1, 0.1)
	sb_panel.set_border_width_all(2)
	sb_dark = sb_panel.duplicate()
	sb_dark.bg_color = Color(0.05, 0.06, 0.09, 0.9)


func setup(a: Arena) -> void:
	arena = a
	var lane := a.lane_pts
	for i in range(0, lane.size(), 3):
		mm_lane.append(lane[i])
	mm_lane.append(lane[lane.size() - 1])
	var river := a.map.get_river()
	for i in range(0, river.size(), 3):
		mm_river.append(river[i])
	a.feed.connect(add_feed)
	# 3D-rendered portrait of your hero (falls back to the 2D drawing if unavailable)
	if not a.headless:
		var holder := Node.new()
		add_child(holder)
		portrait_tex = Portraits.make(holder, a.player.data, a.player.team, 128)
		for h in a.heroes:
			var tex: Texture2D = portrait_tex if h == a.player else Portraits.make(holder, h.data, h.team, 96)
			team_icons[h] = {"tex": tex}
	shop = ShopPanel.new()
	shop.canvas = self
	shop.arena = a
	add_child(shop)
	# who is in this match
	var mates: Array[String] = []
	var foes: Array[String] = []
	for h in a.heroes:
		var tag := "%s (%s)" % [h.data.display_name, h.data.role_name()]
		if h.team == a.player.team:
			if h != a.player:
				mates.append(tag)
		else:
			foes.append(tag)
	add_feed("Enemies: " + ", ".join(foes), 1 - a.player.team)
	add_feed("Allies: " + ", ".join(mates), a.player.team)


func add_feed(text: String, team: int) -> void:
	feed_items.push_front({"text": text, "team": team, "t": 0.0})
	if feed_items.size() > 4:
		feed_items.pop_back()


func toast(text: String, t := 2.0) -> void:
	toast_text = text
	toast_t = t


func now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _process(delta: float) -> void:
	for it in feed_items:
		it["t"] += delta
	feed_items = feed_items.filter(func(it: Dictionary) -> bool: return it["t"] < 6.0)
	toast_t -= delta
	_update_camera(delta)
	_build_gray_icons()
	_probe(delta)
	queue_redraw()


var probe_t := 0.0


## Web test hook: with #probe in the URL, publishes HUD state to window.sbState for the
## automated browser check (gold, items, shop open, camera offset). Off otherwise.
func _probe(delta: float) -> void:
	if not OS.has_feature("web") or arena == null or arena.player == null:
		return
	var game := get_node_or_null("/root/Game")
	if game == null or not game.debug_args.has("probe"):
		return
	probe_t -= delta
	if probe_t > 0.0:
		return
	probe_t = 0.25
	var p := arena.player
	var ids: Array = []
	for it in p.items:
		ids.append(String(it.id))
	var st := {"time": arena.time, "gold": p.gold, "items": ids, "shop_open": shop.visible,
		"at_base": Shop.can_shop_here(p), "cam_free": cam_pan != Vector2.INF,
		"cam_offset": arena.cam_focus.distance_to(p.position), "alive": p.alive,
		"selected": String(shop.selected.id) if shop.selected != null else ""}
	JavaScriptBridge.eval("window.sbState=" + JSON.stringify(st) + ";", true)


## Builds colour + greyscale copies of the team bar portraits once the viewports have rendered.
func _build_gray_icons() -> void:
	if team_icons.is_empty() or icon_frames < 0:
		return
	icon_frames += 1
	if icon_frames < 12:
		return
	icon_frames = -1
	for h in team_icons:
		var d: Dictionary = team_icons[h]
		var tex: Texture2D = d["tex"]
		var img: Image = tex.get_image() if tex != null else null
		if img == null or img.is_empty():
			continue
		img.convert(Image.FORMAT_RGBA8)
		var g := img
		for y in g.get_height():
			for x in g.get_width():
				var c := g.get_pixel(x, y)
				var l := c.r * 0.3 + c.g * 0.59 + c.b * 0.11
				var v := clampf(l * 0.95 + 0.1, 0.0, 1.0)
				g.set_pixel(x, y, Color(v, v, v * 1.04, c.a))
		d["gray"] = ImageTexture.create_from_image(g)


# ---------------- camera pan ----------------

func is_panning() -> bool:
	for k in pointers:
		var r: String = pointers[k]["role"]
		if r == "pan" or (r == "rpan" and pointers[k].get("panning", false)):
			return true
	return false


func reset_camera() -> void:
	cam_pan = Vector2.INF
	pan_idle = 0.0
	if arena != null:
		arena.look_override = Vector2.INF


func _clamp_world(w: Vector2) -> Vector2:
	return w.clamp(Vector2(350.0, 250.0), arena.map.map_size - Vector2(350.0, 150.0))


## World px per screen px around the screen centre (x and y differ: the ground is tilted).
func _pan_scale() -> Vector2:
	if arena.view == null:
		return Vector2.ONE
	var c := size * 0.5
	var w0 := _to_world(c)
	var wx := _to_world(c + Vector2(100, 0))
	var wy := _to_world(c + Vector2(0, 100))
	return Vector2(maxf(w0.distance_to(wx) / 100.0, 0.5), maxf(w0.distance_to(wy) / 100.0, 0.5))


func _pan_start(pt: Dictionary) -> void:
	pt["focus"] = cam_pan if cam_pan != Vector2.INF else arena.cam_focus
	pt["k"] = _pan_scale()


func _pan_drag(pt: Dictionary, pos: Vector2) -> void:
	var k: Vector2 = pt["k"]
	var st: Vector2 = pt["start"]
	cam_pan = _clamp_world((pt["focus"] as Vector2) + Vector2((st.x - pos.x) * k.x, (st.y - pos.y) * k.y))
	arena.look_override = cam_pan
	pan_idle = 0.0


func _update_camera(delta: float) -> void:
	if arena == null or arena.player == null or arena.over:
		return
	if get_tree().paused:
		return
	# desktop edge pan (mouse only, not while touching or with the shop open)
	var vr := get_viewport_rect()
	if now() - last_mouse_t < 8.0 and now() - last_touch_t > 3.0 and not shop.visible and pointers.is_empty() \
			and DisplayServer.window_is_focused() and vr.has_point(mouse_pos):
		var e := Vector2.ZERO
		if mouse_pos.x <= EDGE_BAND:
			e.x = -1
		elif mouse_pos.x >= size.x - EDGE_BAND:
			e.x = 1
		if mouse_pos.y <= EDGE_BAND:
			e.y = -1
		elif mouse_pos.y >= size.y - EDGE_BAND:
			e.y = 1
		if e != Vector2.ZERO:
			var base := cam_pan if cam_pan != Vector2.INF else arena.cam_focus
			cam_pan = _clamp_world(base + e * EDGE_PAN_SPEED * delta)
			arena.look_override = cam_pan
			pan_idle = 0.0
			return
	if cam_pan == Vector2.INF or is_panning():
		return
	pan_idle += delta
	var kb := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if pan_idle > PAN_RETURN_DELAY or arena.joy_vector.length() > 0.15 or kb.length() > 0.1:
		reset_camera()


func release_all() -> void:
	pointers.clear()
	cam_pan = Vector2.INF
	joy_active = false
	if arena != null:
		arena.joy_vector = Vector2.ZERO
		arena.look_override = Vector2.INF
		if arena.player != null:
			arena.player.attack_held = false
			arena.player.aim_preview = {}


# ---------------- layout ----------------

func _layout() -> Dictionary:
	var s := size
	var m := 14.0
	var d := {}
	d["atk"] = Vector2(s.x - 120.0, s.y - 114.0)
	d["atk_r"] = 70.0
	var c: Vector2 = d["atk"]
	d["skill"] = [c + Vector2.from_angle(deg_to_rad(190)) * 152.0, c + Vector2.from_angle(deg_to_rad(229)) * 152.0,
			c + Vector2.from_angle(deg_to_rad(268)) * 152.0, c + Vector2.from_angle(deg_to_rad(231)) * 268.0]
	d["skill_r"] = [46.0, 46.0, 46.0, 52.0]
	d["minimap"] = Rect2(m, m, 190.0, 190.0)
	d["shop"] = Rect2(m, m + 204.0, 112.0, 50.0)
	d["center"] = Rect2(m + 120.0, m + 204.0, 70.0, 50.0)
	d["score"] = Rect2(s.x * 0.5 - 112.0, 8.0, 224.0, 60.0)
	d["icon_r"] = 21.0
	d["pause"] = Vector2(s.x - m - 26.0, m + 26.0)
	d["gold"] = Rect2(s.x - m - 64.0 - 138.0, m + 4.0, 138.0, 44.0)
	d["kda"] = Rect2(s.x - m - 64.0 - 138.0, m + 54.0, 138.0, 34.0)
	d["item"] = c + Vector2.from_angle(deg_to_rad(148)) * 150.0
	d["item_r"] = 34.0
	var pw := 452.0
	var px := clampf(s.x * 0.5 - pw * 0.5, 230.0, s.x - 360.0 - pw)
	d["portrait"] = Rect2(px, s.y - 106.0, pw, 98.0)
	d["slots"] = Rect2(px + 102.0, s.y - 106.0 + 69.0, 6 * 34.0, 26.0)
	d["recall"] = Rect2(px + pw - 80.0, s.y - 100.0, 72.0, 40.0)
	d["heal"] = Rect2(px + pw - 80.0, s.y - 54.0, 72.0, 40.0)
	d["joy_home"] = Vector2(m + 130.0, s.y - 140.0)
	return d


# ---------------- input ----------------

func _input(event: InputEvent) -> void:
	if arena == null or arena.player == null:
		return
	if arena.over or get_tree().paused:
		if not pointers.is_empty():
			release_all()
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		last_touch_t = now()
		if st.pressed:
			_press(st.index, st.position)
		else:
			_release(st.index, st.position)
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_drag(sd.index, sd.position)
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		var mb := event as InputEventMouseButton
		mouse_pos = mb.position
		last_mouse_t = now()
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press(1000, mb.position)
			else:
				_release(1000, mb.position)
		elif mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			# right-click = move (on release, if it was not a drag); right/middle-drag = pan camera
			var pid := 1001 if mb.button_index == MOUSE_BUTTON_RIGHT else 1002
			if mb.pressed and not shop.visible:
				var pt := {"role": "rpan" if pid == 1001 else "pan", "start": mb.position, "max": 0.0, "panning": pid == 1002}
				_pan_start(pt)
				pointers[pid] = pt
			elif not mb.pressed and pointers.has(pid):
				var pt2: Dictionary = pointers[pid]
				pointers.erase(pid)
				if pid == 1001 and not pt2.get("panning", false) and arena.player.alive:
					reset_camera()
					arena.player.command_move(_to_world(mb.position))
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		mouse_pos = (event as InputEventMouseMotion).position
		last_mouse_t = now()
		for pid2 in [1000, 1001, 1002]:
			if pointers.has(pid2):
				_drag(pid2, mouse_pos)


func _unhandled_input(event: InputEvent) -> void:
	if arena == null or arena.player == null or arena.over:
		return
	if event.is_action_pressed("pause"):
		if shop.visible and event is InputEventKey and (event as InputEventKey).keycode == KEY_ESCAPE:
			shop.close()
			return
		hud.toggle_pause()
		return
	if get_tree().paused:
		return
	var p := arena.player
	if event.is_action_pressed("skill_1"):
		_key_cast(0)
	elif event.is_action_pressed("skill_2"):
		_key_cast(1)
	elif event.is_action_pressed("skill_3"):
		_key_cast(2)
	elif event.is_action_pressed("ultimate"):
		_key_cast(3)
	elif event.is_action_pressed("attack"):
		p.press_attack()
	elif event.is_action_pressed("recall"):
		p.start_recall()
	elif event.is_action_pressed("heal"):
		p.cast_heal()
	elif event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_TAB:
		toggle_shop()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_G:
		_use_item({"point": _to_world(mouse_pos)} if now() - last_mouse_t < 4.0 else {})
	elif event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_C:
		reset_camera()
	elif event.is_action_pressed("toggle_autopilot"):
		p.autopilot = not p.autopilot
		toast("Autopilot " + ("ON" if p.autopilot else "OFF"))


func _key_cast(slot: int) -> void:
	var aim := {}
	if now() - last_mouse_t < 4.0:
		aim = {"point": _to_world(mouse_pos)}
	if not arena.player.cast(slot, aim):
		_explain_fail(slot)


func toggle_shop() -> void:
	if shop.visible:
		shop.close()
	else:
		release_all()
		shop.open()
		if not Shop.can_shop_here(arena.player):
			toast("Return to base to buy", 1.6)


func _use_item(aim: Dictionary) -> void:
	var p := arena.player
	var it := p.active_item()
	if it == null:
		toast("Buy a Blink Charm in the shop to use this", 1.4)
	elif not p.use_item(aim) and p.alive and p.item_cd > 0.0:
		toast("%s ready in %ds" % [it.display_name, ceili(p.item_cd)], 1.0)


func _explain_fail(slot: int) -> void:
	var p := arena.player
	if not p.alive or slot >= p.data.abilities.size():
		return
	if p.ranks[slot] <= 0:
		toast("Unlocks at level %d" % (4 if slot == 3 else slot + 1), 1.2)
	elif p.cds[slot] > 0.0:
		pass
	elif p.mana < p.data.abilities[slot].mana_cost:
		toast("Not enough mana", 1.0)


func _to_world(pos: Vector2) -> Vector2:
	if arena.view != null:
		return arena.view.screen_to_world(pos)
	return get_viewport().get_canvas_transform().affine_inverse() * pos


func _press(id: int, pos: Vector2) -> void:
	lay = _layout()
	var p := arena.player
	var role := ""
	if shop.visible:
		shop.press(pos)
		get_viewport().set_input_as_handled()
		return
	if pos.distance_to(lay["pause"]) <= 34.0:
		hud.toggle_pause()
		get_viewport().set_input_as_handled()
		return
	for slot in 4:
		if pos.distance_to(lay["skill"][slot]) <= lay["skill_r"][slot] + 8.0:
			role = "skill%d" % slot
			break
	if role == "" and pos.distance_to(lay["atk"]) <= lay["atk_r"] + 12.0:
		role = "attack"
	if role == "" and p.active_item() != null and pos.distance_to(lay["item"]) <= lay["item_r"] + 8.0:
		role = "item"
	if role == "":
		if (lay["recall"] as Rect2).grow(6).has_point(pos):
			p.start_recall()
			get_viewport().set_input_as_handled()
			return
		if (lay["heal"] as Rect2).grow(6).has_point(pos):
			if not p.cast_heal() and p.alive:
				toast("Heal ready in %ds" % ceili(p.heal_cd), 1.0)
			get_viewport().set_input_as_handled()
			return
		if (lay["shop"] as Rect2).grow(4).has_point(pos) or (lay["slots"] as Rect2).grow(4).has_point(pos):
			toggle_shop()
			get_viewport().set_input_as_handled()
			return
		if (lay["center"] as Rect2).grow(4).has_point(pos):
			reset_camera()
			get_viewport().set_input_as_handled()
			return
		if (lay["minimap"] as Rect2).has_point(pos):
			role = "minimap"
			cam_pan = Vector2.INF
			_minimap_look(pos)
	if role == "" and pos.x < size.x * 0.46 and not (lay["portrait"] as Rect2).has_point(pos) and not joy_active:
		role = "joy"
		joy_active = true
		joy_center = pos
		joy_knob = pos
	if role == "" and id == 1000:
		_world_click(pos)
		get_viewport().set_input_as_handled()
		return
	if role == "" and not _on_hud_panel(pos):
		role = "pan"  # empty screen on the right: drag the camera around
	if role == "":
		return
	pointers[id] = {"role": role, "start": pos, "max": 0.0}
	if role == "pan":
		_pan_start(pointers[id])
	if role == "attack":
		p.attack_held = true
		p.press_attack()
	get_viewport().set_input_as_handled()


func _drag(id: int, pos: Vector2) -> void:
	if not pointers.has(id):
		return
	var pt: Dictionary = pointers[id]
	var role: String = pt["role"]
	lay = _layout()
	if role == "joy":
		var v := pos - joy_center
		if v.length() > JOY_R:
			joy_center = pos - v.normalized() * JOY_R
		joy_knob = pos
		arena.joy_vector = (joy_knob - joy_center) / JOY_R
	elif role.begins_with("skill"):
		var slot := int(role.substr(5))
		var v2: Vector2 = pos - lay["skill"][slot]
		pt["max"] = maxf(pt["max"], v2.length())
		if v2.length() > 26.0:
			arena.player.aim_preview = {"slot": slot, "dir": v2.normalized(), "mag": clampf((v2.length() - 26.0) / 130.0, 0.12, 1.0)}
		elif pt["max"] > 40.0:
			arena.player.aim_preview = {"slot": slot, "dir": Vector2.ZERO, "cancel": true}
	elif role == "item":
		var v3: Vector2 = pos - lay["item"]
		pt["max"] = maxf(pt["max"], v3.length())
		if v3.length() > 24.0:
			arena.player.aim_preview = {"slot": 4, "dir": v3.normalized(), "mag": clampf((v3.length() - 24.0) / 120.0, 0.25, 1.0)}
		elif pt["max"] > 40.0:
			arena.player.aim_preview = {"slot": 4, "dir": Vector2.ZERO, "cancel": true}
	elif role == "minimap":
		_minimap_look(pos)
	elif role == "pan":
		_pan_drag(pt, pos)
	elif role == "rpan":
		if pos.distance_to(pt["start"]) > 12.0:
			pt["panning"] = true
		if pt["panning"]:
			_pan_drag(pt, pos)
	get_viewport().set_input_as_handled()


func _release(id: int, pos: Vector2) -> void:
	if not pointers.has(id):
		return
	var pt: Dictionary = pointers[id]
	pointers.erase(id)
	var role: String = pt["role"]
	var p := arena.player
	lay = _layout()
	if role == "joy":
		joy_active = false
		arena.joy_vector = Vector2.ZERO
	elif role == "attack":
		p.attack_held = false
	elif role.begins_with("skill"):
		var slot := int(role.substr(5))
		p.aim_preview = {}
		var v: Vector2 = pos - lay["skill"][slot]
		var ok := true
		if v.length() > 26.0:
			ok = p.cast(slot, {"dir": v.normalized(), "mag": clampf((v.length() - 26.0) / 130.0, 0.12, 1.0)})
		elif pt["max"] > 40.0:
			toast("Cancelled", 0.6)
		else:
			ok = p.cast(slot)
		if not ok:
			_explain_fail(slot)
	elif role == "item":
		p.aim_preview = {}
		var vi: Vector2 = pos - lay["item"]
		if vi.length() > 24.0:
			_use_item({"dir": vi.normalized(), "mag": clampf((vi.length() - 24.0) / 120.0, 0.25, 1.0)})
		elif pt["max"] > 40.0:
			toast("Cancelled", 0.6)
		else:
			_use_item({})
	elif role == "minimap":
		arena.look_override = Vector2.INF
	elif role == "pan":
		pan_idle = 0.0
	get_viewport().set_input_as_handled()


## True over HUD panels that should not start a camera drag.
func _on_hud_panel(pos: Vector2) -> bool:
	if (lay["portrait"] as Rect2).grow(6).has_point(pos) or (lay["score"] as Rect2).grow(6).has_point(pos):
		return true
	if (lay["gold"] as Rect2).grow(6).has_point(pos) or (lay["kda"] as Rect2).grow(6).has_point(pos):
		return true
	# the hero icon strip next to the score
	var sr: Rect2 = lay["score"]
	if pos.y < sr.end.y + 30.0 and pos.x > sr.position.x - 170.0 and pos.x < sr.end.x + 170.0:
		return true
	return false


func _world_click(pos: Vector2) -> void:
	var p := arena.player
	if not p.alive:
		return
	var w := _to_world(pos)
	var best: Unit = null
	var bd := 70.0
	for u in arena.units:
		if u.alive and u.team != p.team and u.is_targetable_by(p.team):
			var d := w.distance_to(u.position) - u.radius
			if d < bd:
				bd = d
				best = u
	reset_camera()
	if best != null:
		p.command_attack(best)
	else:
		p.command_move(w)


func _minimap_look(pos: Vector2) -> void:
	var r: Rect2 = lay["minimap"]
	var k := r.size.x / arena.map.map_size.x
	arena.look_override = ((pos - r.position) / k).clamp(Vector2.ZERO, arena.map.map_size)


# ---------------- drawing ----------------

func _text(pos: Vector2, s: String, sz: int, col: Color, align := 0, outline := 0) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	var x := pos.x
	if align == 1:
		x -= w * 0.5
	elif align == 2:
		x -= w
	if outline > 0:
		draw_string_outline(font, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, outline, Color(0, 0, 0, 0.75 * col.a))
	draw_string(font, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)


func _fmt_time(t: float) -> String:
	var s := int(t)
	return "%02d:%02d" % [s / 60, s % 60]


func _draw() -> void:
	if arena == null or arena.player == null:
		return
	lay = _layout()
	var p := arena.player
	_draw_minimap(lay["minimap"])
	_draw_shop(lay["shop"])
	_draw_center_button(lay["center"])
	_draw_score(lay["score"])
	_draw_team_icons(lay["score"])
	_draw_top_right()
	_draw_feed()
	_draw_portrait(lay["portrait"])
	_draw_joystick()
	_draw_buttons()
	_draw_item_button()
	if cam_pan != Vector2.INF and not shop.visible:
		_text(Vector2(size.x * 0.5, size.y - 124.0), "Free camera · tap CENTER or move to return", 14, Color(1, 1, 1, 0.75), 1, 4)
	if toast_t > 0.0 and toast_text != "":
		var a := clampf(toast_t * 2.0, 0.0, 1.0)
		var w := font.get_string_size(toast_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 40.0
		draw_style_box(sb_dark, Rect2(size.x * 0.5 - w * 0.5, 176.0, w, 40.0))
		_text(Vector2(size.x * 0.5, 203.0), toast_text, 20, Color(1, 1, 1, a), 1)
	if not p.alive and not arena.over:
		_text(Vector2(size.x * 0.5, size.y * 0.42), "Respawning in %d" % ceili(p.respawn_t), 34, Color(1, 1, 1, 0.95), 1, 8)
	if p.autopilot and show_autopilot_label:
		_text(Vector2(size.x * 0.5, 96.0 + 120.0), "AUTOPILOT (F8)", 16, Color("8fe8ff"), 1, 5)
	if arena.sudden_death and not arena.over:
		_text(Vector2(size.x * 0.5, 84.0), "SUDDEN DEATH", 14, Color("ff8a5c"), 1, 4)


func _draw_minimap(r: Rect2) -> void:
	draw_style_box(sb_dark, r.grow(5))
	draw_rect(r, Color("3c7530"))
	var k := r.size.x / arena.map.map_size.x
	var o := r.position
	var river := PackedVector2Array()
	for q in mm_river:
		river.append(o + q * k)
	draw_polyline(river, Color("3d9be0"), 8.0, true)
	var lane := PackedVector2Array()
	for q in mm_lane:
		lane.append(o + q * k)
	draw_polyline(lane, Color("d8b98a"), 7.0, true)
	for t in [0, 1]:
		draw_circle(o + arena.map.base_center(t) * k, 15.0, Color(Art.team_color(t), 0.55))
	for s in arena.structures:
		var c := o + s.position * k
		if not s.alive:
			draw_line(c - Vector2(4, 4), c + Vector2(4, 4), Color(0.2, 0.2, 0.2), 2.0)
			draw_line(c - Vector2(4, -4), c + Vector2(4, -4), Color(0.2, 0.2, 0.2), 2.0)
			continue
		var hs := 7.0 if s.tier == 2 else 4.5
		draw_rect(Rect2(c - Vector2(hs, hs), Vector2(hs, hs) * 2.0), Color.WHITE)
		draw_rect(Rect2(c - Vector2(hs - 1.5, hs - 1.5), Vector2(hs - 1.5, hs - 1.5) * 2.0), Art.team_color(s.team))
	for u in arena.units:
		if u.alive and u.kind == Unit.Kind.CREEP:
			draw_rect(Rect2(o + u.position * k - Vector2(1.5, 1.5), Vector2(3, 3)), Art.team_color(u.team).lightened(0.2))
		elif u.alive and u.kind == Unit.Kind.NEUTRAL:
			draw_circle(o + u.position * k, 2.0, Color("e0d050"))
	for h in arena.heroes:
		if not h.alive:
			continue
		if h.team != arena.player.team and h.stealth_t > 0.0 and h.mark_t <= 0.0:
			continue
		var c2 := o + h.position * k
		if h == arena.player:
			draw_circle(c2, 7.0, Color.WHITE)
			draw_circle(c2, 5.0, Art.PLAYER)
		else:
			draw_circle(c2, 6.0, Color(0.05, 0.05, 0.08))
			draw_circle(c2, 4.5, Art.team_color(h.team))
	if arena.view != null:
		# the 3D camera sees a trapezoid of ground (wider at the top of the screen)
		var q := arena.view.view_quad()
		var pts := PackedVector2Array()
		for wp in q:
			var mp := o + wp * k
			pts.append(Vector2(clampf(mp.x, r.position.x, r.end.x), clampf(mp.y, r.position.y, r.end.y)))
		pts.append(pts[0])
		draw_polyline(pts, Color(1, 1, 1, 0.85), 1.5, true)


func _draw_shop(r: Rect2) -> void:
	var p := arena.player
	var at_base := Shop.can_shop_here(p)
	var nx := p.brain.next_item() if p.brain != null else null
	var ready := at_base and nx != null and p.gold >= Shop.price_for(p, nx)
	var sb := sb_panel.duplicate() as StyleBoxFlat
	sb.bg_color = Color(0.62, 0.46, 0.12, 0.85) if at_base else Color(0.45, 0.35, 0.12, 0.7)
	if ready:
		sb.border_color = Color(1, 0.85, 0.4, 0.55 + 0.35 * sin(now() * 5.0))
		sb.set_border_width_all(3)
	draw_style_box(sb, r)
	Art.draw_icon(self, "coin", r.position + Vector2(20.0, 25.0), 10.0)
	_text(Vector2(r.position.x + 66.0, r.position.y + 23.0), "SHOP", 18, Color.WHITE, 1, 3)
	_text(Vector2(r.position.x + 66.0, r.position.y + 42.0), "buy now" if at_base else "at base", 12,
			Color("b8ffb0") if at_base else Color(1, 0.9, 0.6, 0.8), 1)


func _draw_center_button(r: Rect2) -> void:
	var free := cam_pan != Vector2.INF
	var sb := sb_panel.duplicate() as StyleBoxFlat
	sb.bg_color = Color(0.2, 0.45, 0.8, 0.85) if free else Color(0.07, 0.08, 0.12, 0.7)
	draw_style_box(sb, r)
	var c := r.position + Vector2(r.size.x * 0.5, 20.0)
	draw_arc(c, 9.0, 0, TAU, 20, Color.WHITE, 2.0, true)
	draw_circle(c, 3.0, Color.WHITE)
	for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(c + d * 11.0, c + d * 15.0, Color.WHITE, 2.0)
	_text(Vector2(c.x, r.position.y + 44.0), "CENTER", 11, Color(1, 1, 1, 0.9 if free else 0.6), 1)


## Both teams' heroes beside the score: Dawn on the left, Dusk on the right. Dead heroes turn
## grey with their respawn countdown.
func _draw_team_icons(sr: Rect2) -> void:
	var rr: float = lay["icon_r"]
	for t in [0, 1]:
		var list: Array = []
		for h in arena.heroes:
			if h.team == t:
				list.append(h)
		for i in list.size():
			var h: Hero = list[i]
			var x := sr.position.x - 8.0 - rr - i * (rr * 2.0 + 7.0) if t == 0 else sr.end.x + 8.0 + rr + i * (rr * 2.0 + 7.0)
			var c := Vector2(x, sr.position.y + 28.0)
			var col := Art.team_color(t)
			draw_circle(c, rr + 2.0, Color(0.04, 0.05, 0.08, 0.92))
			draw_circle(c, rr, Color(h.data.body_color.darkened(0.3), 0.9) if h.alive else Color(0.3, 0.3, 0.33))
			var d: Dictionary = team_icons.get(h, {})
			var tex: Texture2D = null
			if h.alive:
				tex = d.get("tex", null)
			else:
				tex = d.get("gray", null)
			if tex != null:
				draw_texture_rect(tex, Rect2(c - Vector2(rr, rr + 2.0), Vector2(rr, rr) * 2.0), false, Color(1, 1, 1))
			elif not h.alive:
				draw_circle(c, rr, Color(0.35, 0.35, 0.38))
			draw_arc(c, rr + 1.0, 0, TAU, 32, (Art.PLAYER if h == arena.player else col) if h.alive else Color(0.45, 0.45, 0.5), 3.0 if h == arena.player else 2.0, true)
			# level badge
			var lc := c + Vector2(rr * 0.72, rr * 0.72)
			draw_circle(lc, 8.0, Color(0.05, 0.06, 0.09))
			_text(lc + Vector2(0, 4), str(h.level), 10, Color.WHITE if h.alive else Color(0.7, 0.7, 0.7), 1)
			if not h.alive:
				draw_circle(c, rr, Color(0, 0, 0, 0.22))
				_text(c + Vector2(0, 7), str(ceili(h.respawn_t)), 19, Color.WHITE, 1, 5)
			elif h.hp_frac() < 0.999:
				var bw := rr * 1.6
				var br := Rect2(c + Vector2(-bw * 0.5, rr + 4.0), Vector2(bw, 4.0))
				draw_rect(br, Color(0, 0, 0, 0.6))
				draw_rect(Rect2(br.position, Vector2(bw * h.hp_frac(), 4.0)), Color("4cd06a") if t == arena.player.team else Color("ff5a5a"))


func _draw_item_button() -> void:
	var p := arena.player
	var it := p.active_item()
	if it == null:
		return
	var c: Vector2 = lay["item"]
	var r: float = lay["item_r"]
	var ready := p.alive and p.item_cd <= 0.0
	draw_circle(c + Vector2(0, 3), r + 3.0, Color(0, 0, 0, 0.3))
	draw_circle(c, r, Color("7d4fd6") if ready else Color("4a3a70"))
	draw_circle(c, r * 0.82, Color("9a6cf0") if ready else Color("54447a"))
	draw_arc(c, r, 0, TAU, 40, Color(1, 1, 1, 0.9 if ready else 0.45), 3.0, true)
	ItemIcons.draw(self, it.icon, c + Vector2(0, -3), r * 0.55, Color(1, 1, 1), 1.0 if ready else 0.6)
	_text(c + Vector2(0, r + 14.0), "BLINK", 12, Color.WHITE, 1, 3)
	if p.item_cd > 0.0:
		var frac := clampf(p.item_cd / maxf(it.active_cooldown, 0.01), 0.0, 1.0)
		draw_colored_polygon(Art.pie_pts(c, r, -PI / 2.0, -PI / 2.0 + TAU * frac), Color(0, 0, 0, 0.5))
		_text(c + Vector2(0, 8), str(ceili(p.item_cd)), 22, Color.WHITE, 1, 4)
	if p.aim_preview.get("slot", -1) == 4:
		draw_arc(c, r + 5.0, 0, TAU, 40, Color(1, 1, 1, 0.9), 3.0, true)


func _draw_score(r: Rect2) -> void:
	draw_style_box(sb_dark, r)
	_text(Vector2(r.position.x + 40.0, r.position.y + 44.0), str(arena.kills[0]), 34, Art.DAWN, 1, 4)
	_text(Vector2(r.end.x - 40.0, r.position.y + 44.0), str(arena.kills[1]), 34, Art.DUSK, 1, 4)
	_text(Vector2(r.position.x + r.size.x * 0.5, r.position.y + 32.0), _fmt_time(arena.time), 26, Color.WHITE, 1)
	_text(Vector2(r.position.x + r.size.x * 0.5, r.position.y + 51.0), "DAWN  ·  DUSK", 12, Color(1, 1, 1, 0.6), 1)
	# Buildings left per team
	for t in [0, 1]:
		var i := 0
		for s in arena.structures:
			if s.team != t:
				continue
			var x := r.position.x + 12.0 + i * 13.0 if t == 0 else r.end.x - 12.0 - i * 13.0
			var c := Vector2(x, r.end.y + 10.0)
			var col := Art.team_color(t) if s.alive else Color(0.3, 0.3, 0.35)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -5), c + Vector2(5, 0), c + Vector2(0, 5), c + Vector2(-5, 0)]), col)
			i += 1


func _draw_top_right() -> void:
	var p := arena.player
	var kr: Rect2 = lay["kda"]
	draw_style_box(sb_dark, kr)
	_text(Vector2(kr.position.x + 14.0, kr.position.y + 28.0), "K/D/A", 13, Color(1, 1, 1, 0.6))
	_text(Vector2(kr.end.x - 12.0, kr.position.y + 30.0), "%d/%d/%d" % [p.kills, p.deaths, p.assists], 20, Color.WHITE, 2)
	var gr: Rect2 = lay["gold"]
	draw_style_box(sb_dark, gr)
	Art.draw_icon(self, "coin", gr.position + Vector2(24.0, 22.0), 14.0)
	_text(Vector2(gr.end.x - 14.0, gr.position.y + 30.0), str(p.gold), 21, Art.GOLD, 2)
	var pc: Vector2 = lay["pause"]
	draw_circle(pc, 26.0, Color(0.05, 0.06, 0.09, 0.9))
	draw_arc(pc, 26.0, 0, TAU, 32, Color(1, 1, 1, 0.15), 2.0, true)
	Art.draw_icon(self, "pause", pc, 12.0, Color(1, 1, 1, 0.9))


func _draw_feed() -> void:
	var y := 112.0
	for it in feed_items:
		var a := clampf((6.0 - it["t"]) * 1.5, 0.0, 1.0)
		var s: String = it["text"]
		var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 30.0
		var r := Rect2(size.x * 0.5 - w * 0.5, y - 18.0, w, 26.0)
		var sb := sb_dark.duplicate() as StyleBoxFlat
		sb.bg_color = Color(0.05, 0.06, 0.09, 0.75 * a)
		sb.border_color = Color(Art.team_color(it["team"]) if it["team"] >= 0 else Color("ff8a5c"), 0.7 * a)
		draw_style_box(sb, r)
		_text(Vector2(size.x * 0.5, y), s, 15, Color(1, 1, 1, a), 1)
		y += 30.0


func _draw_portrait(r: Rect2) -> void:
	var p := arena.player
	draw_style_box(sb_dark, r)
	var c := r.position + Vector2(50.0, 50.0)
	draw_circle(c, 40.0, Color(p.data.body_color, 0.35))
	draw_arc(c, 40.0, 0, TAU, 40, Art.PLAYER, 3.0, true)
	if portrait_tex != null:
		draw_texture_rect(portrait_tex, Rect2(c - Vector2(42, 44), Vector2(84, 84)), false, Color(1, 1, 1, 1.0 if p.alive else 0.4))
	else:
		Art.draw_hero(self, p.data.id, c, 30.0, Vector2(0, 0.6), 1.0 if p.alive else 0.4)
	var lc := c + Vector2(30.0, 28.0)
	draw_circle(lc, 15.0, Color(0.06, 0.07, 0.1))
	draw_arc(lc, 15.0, 0, TAU, 24, Art.GOLD, 2.0, true)
	_text(lc + Vector2(0, 6), str(p.level), 16, Color.WHITE, 1)
	var x0 := r.position.x + 102.0
	var bw := r.size.x - 102.0 - 92.0
	_text(Vector2(x0, r.position.y + 21.0), p.data.display_name, 18, Color.WHITE, 0, 3)
	# role badge next to the name
	var role := p.data.role_name().to_upper()
	var nw := font.get_string_size(p.data.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	var rw := font.get_string_size(role, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 14.0
	var badge := Rect2(x0 + nw + 8.0, r.position.y + 8.0, rw, 17.0)
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = p.data.role_color().darkened(0.35)
	bsb.border_color = p.data.role_color()
	bsb.set_border_width_all(1)
	bsb.set_corner_radius_all(8)
	draw_style_box(bsb, badge)
	_text(Vector2(badge.position.x + rw * 0.5, badge.position.y + 13.0), role, 11, Color.WHITE, 1)
	var xp_txt := "MAX" if p.level >= arena.config.max_level else "XP %d%%" % int(100.0 * p.xp / p.xp_needed())
	_text(Vector2(x0 + bw, r.position.y + 20.0), xp_txt, 13, Color(1, 1, 1, 0.6), 2)
	var hr := Rect2(x0, r.position.y + 30.0, bw, 16.0)
	draw_rect(hr, Color(0.15, 0.17, 0.2))
	draw_rect(Rect2(hr.position, Vector2(bw * p.hp_frac(), hr.size.y)), Color("4cd06a"))
	if p.shield > 0.0:
		draw_rect(Rect2(hr.position + Vector2(bw * p.hp_frac(), 0), Vector2(minf(bw * p.shield / p.max_hp, bw * (1.0 - p.hp_frac())), hr.size.y)), Color(1, 1, 1, 0.8))
	_text(hr.position + Vector2(bw * 0.5, 13.0), "%d / %d" % [int(p.hp), int(p.max_hp)], 13, Color.WHITE, 1, 3)
	var mr := Rect2(x0, r.position.y + 50.0, bw, 11.0)
	draw_rect(mr, Color(0.15, 0.17, 0.2))
	draw_rect(Rect2(mr.position, Vector2(bw * p.mana / maxf(p.max_mana, 1.0), mr.size.y)), Color("4b8ef0"))
	_text(mr.position + Vector2(bw * 0.5, 10.0), "%d / %d" % [int(p.mana), int(p.max_mana)], 11, Color.WHITE, 1, 2)
	var xr := Rect2(x0, r.position.y + 63.0, bw, 3.0)
	draw_rect(xr, Color(0.15, 0.17, 0.2))
	draw_rect(Rect2(xr.position, Vector2(bw * (1.0 if p.level >= arena.config.max_level else p.xp / p.xp_needed()), 3.0)), Color("c9a0ff"))
	var slots: Rect2 = lay["slots"]
	for i in arena.config.item_slots:
		var ir := Rect2(slots.position.x + i * 34.0, slots.position.y, 30.0, 26.0)
		draw_rect(ir, Color(1, 1, 1, 0.07))
		draw_rect(ir, Color(1, 1, 1, 0.16), false, 1.0)
		if i < p.items.size():
			var it: ItemData = p.items[i]
			draw_rect(ir.grow(-1), Color(it.color.darkened(0.72), 0.95))
			ItemIcons.draw(self, it.icon, ir.get_center(), 11.0, it.color)
			if it.active != "none" and p.item_cd > 0.0:
				draw_rect(Rect2(ir.position, Vector2(ir.size.x, ir.size.y * clampf(p.item_cd / it.active_cooldown, 0.0, 1.0))), Color(0, 0, 0, 0.55))
		else:
			_text(ir.get_center() + Vector2(0, 5), "+", 14, Color(1, 1, 1, 0.25), 1)
	_small_button(lay["recall"], "recall", "RECALL", p.recall_t > 0.0, 0.0)
	_small_button(lay["heal"], "heal", "HEAL", false, maxf(p.heal_cd, 0.0) / arena.config.heal_spell_cooldown)
	if not p.alive:
		draw_rect(r, Color(0, 0, 0, 0.45))
		_text(r.get_center() + Vector2(0, 8), "Respawn %ds" % ceili(p.respawn_t), 22, Color.WHITE, 1, 4)


func _small_button(r: Rect2, icon: String, label: String, active: bool, cd_frac: float) -> void:
	var sb := sb_panel.duplicate() as StyleBoxFlat
	sb.set_corner_radius_all(8)
	sb.bg_color = Color(0.25, 0.45, 0.8, 0.8) if active else Color(1, 1, 1, 0.08)
	draw_style_box(sb, r)
	Art.draw_icon(self, icon, r.position + Vector2(17.0, r.size.y * 0.5), 9.0, Color("7fe08a") if icon == "heal" else Color.WHITE)
	_text(Vector2(r.position.x + 30.0, r.position.y + r.size.y * 0.5 + 5.0), label, 12, Color.WHITE)
	if cd_frac > 0.0:
		draw_rect(Rect2(r.position, Vector2(r.size.x * cd_frac, r.size.y)), Color(0, 0, 0, 0.55))


func _draw_joystick() -> void:
	var home: Vector2 = lay["joy_home"]
	if joy_active:
		draw_circle(joy_center, JOY_R + 10.0, Color(1, 1, 1, 0.08))
		draw_arc(joy_center, JOY_R + 10.0, 0, TAU, 48, Color(1, 1, 1, 0.35), 3.0, true)
		draw_circle(joy_knob, 38.0, Color(0.85, 0.9, 1.0, 0.85))
		draw_arc(joy_knob, 38.0, 0, TAU, 40, Color(1, 1, 1, 0.9), 2.0, true)
	else:
		draw_circle(home, JOY_R + 10.0, Color(1, 1, 1, 0.05))
		draw_arc(home, JOY_R + 10.0, 0, TAU, 48, Color(1, 1, 1, 0.18), 2.0, true)
		draw_circle(home, 34.0, Color(1, 1, 1, 0.18))


func _draw_buttons() -> void:
	var p := arena.player
	var t := now()
	var ac: Vector2 = lay["atk"]
	var ar: float = lay["atk_r"]
	var held := false
	for k in pointers:
		if pointers[k]["role"] == "attack":
			held = true
	draw_circle(ac + Vector2(0, 4), ar + 4.0, Color(0, 0, 0, 0.3))
	draw_circle(ac, ar, ATTACK_COLOR.darkened(0.15) if held else ATTACK_COLOR)
	draw_circle(ac, ar * 0.84, ATTACK_COLOR.lightened(0.12))
	draw_arc(ac, ar, 0, TAU, 56, Color(1, 1, 1, 0.9), 4.0, true)
	Art.draw_icon(self, "attack_bow" if p.data.ranged_attack else "attack_sword", ac + Vector2(0, -8), 26.0, Color.WHITE)
	_text(ac + Vector2(0, 40), "ATTACK", 15, Color.WHITE, 1, 3)
	for slot in 4:
		if slot >= p.data.abilities.size():
			continue
		var ab: AbilityData = p.data.abilities[slot]
		var c: Vector2 = lay["skill"][slot]
		var r: float = lay["skill_r"][slot]
		var rank := p.ranks[slot]
		var col: Color = SKILL_COLORS[slot]
		var locked := rank <= 0
		var no_mana := p.mana < ab.mana_cost
		var on_cd := p.cds[slot] > 0.0
		var ready := not locked and not on_cd and not no_mana and p.alive
		if slot == 3 and ready:
			var pulse := 0.5 + 0.5 * sin(t * 5.0)
			draw_circle(c, r + 10.0 + pulse * 4.0, Color(1.0, 0.35, 0.45, 0.25 + 0.15 * pulse))
			_text(c + Vector2(0, -r - 14.0), "ULT READY", 13, Color("ffd84a"), 1, 3)
		draw_circle(c + Vector2(0, 3), r + 3.0, Color(0, 0, 0, 0.3))
		draw_circle(c, r, col if not locked else col.darkened(0.6))
		draw_circle(c, r * 0.82, (col.lightened(0.12) if not locked else col.darkened(0.55)))
		draw_arc(c, r, 0, TAU, 48, Color(1, 1, 1, 0.9 if ready else 0.45), 3.0, true)
		Art.draw_icon(self, ab.icon, c, r * 0.45, Color(1, 1, 1, 1.0 if ready else 0.55))
		if locked:
			draw_circle(c, r, Color(0, 0, 0, 0.45))
			_text(c + Vector2(0, 7), "Lv%d" % (4 if slot == 3 else slot + 1), 18, Color(1, 1, 1, 0.85), 1, 3)
		elif on_cd:
			var frac := clampf(p.cds[slot] / maxf(ab.cd_at(rank), 0.01), 0.0, 1.0)
			if frac > 0.02:
				draw_colored_polygon(Art.pie_pts(c, r, -PI / 2.0, -PI / 2.0 + TAU * frac), Color(0, 0, 0, 0.55))
			_text(c + Vector2(0, 9), str(ceili(p.cds[slot])), 26, Color.WHITE, 1, 4)
		elif no_mana:
			draw_circle(c, r, Color(0.1, 0.2, 0.6, 0.45))
		# mana cost badge
		# (skill 1 sits left of skill 2, so its badge goes top-left to avoid overlapping)
		var bc := c + Vector2(r * (-0.72 if slot == 0 else 0.72), -r * 0.72)
		var sb := sb_panel.duplicate() as StyleBoxFlat
		sb.set_corner_radius_all(8)
		sb.bg_color = Color("2b5fc4")
		sb.border_color = Color(1, 1, 1, 0.5)
		sb.set_border_width_all(1)
		draw_style_box(sb, Rect2(bc - Vector2(17, 10), Vector2(34, 20)))
		_text(bc + Vector2(0, 5), str(int(ab.mana_cost)), 12, Color.WHITE, 1)
		# rank pips
		var maxr := 3 if slot == 3 else 4
		for i in maxr:
			var pc := c + Vector2((i - (maxr - 1) * 0.5) * 11.0, r + 9.0)
			draw_circle(pc, 3.5, Color("ffd84a") if i < rank else Color(1, 1, 1, 0.25))
		# aiming highlight
		if p.aim_preview.get("slot", -1) == slot:
			draw_arc(c, r + 5.0, 0, TAU, 48, Color(1, 1, 1, 0.9), 3.0, true)
