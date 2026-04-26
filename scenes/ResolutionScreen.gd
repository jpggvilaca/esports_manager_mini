# scenes/ResolutionScreen.gd
# Sequenced resolution with colored act headers and counter results.
class_name ResolutionScreen
extends Control

const TraitMatchup := preload("res://scripts/systems/TraitMatchup.gd")

signal finished

const REVEAL_DELAY: float = 0.9
const ACT_PAUSE:    float = 2.0

var _game:    GameManager = null
var _result:  WeekResult  = null
var _events:  Array       = []
var _index:   int         = 0
var _timer:   float       = 0.0
var _running: bool        = false

var _event_log:    VBoxContainer   = null
var _scroll:       ScrollContainer = null
var _continue_btn: Button          = null


func _ready() -> void:
	_event_log    = $Margin/VBox/ScrollContainer/EventLog
	_scroll       = $Margin/VBox/ScrollContainer
	_continue_btn = $Margin/VBox/ContinueBtn
	_continue_btn.pressed.connect(_on_continue_btn_pressed)


func setup(result: WeekResult, game: GameManager) -> void:
	_result = result
	_game   = game
	_build_event_queue()
	_start()


# ---------------------------------------------------------------------------
# BUILD EVENT QUEUE
# ---------------------------------------------------------------------------

func _build_event_queue() -> void:
	_events = []

	var mtype_label: String = GameText.MATCH_TYPE.get(_result.match_type, "Match")
	_events.append({ "type": "header",
		"text": "Season %d  ·  Week %d  ·  %s" % [_result.season, _result.week, mtype_label]
	})

	# Bench
	for bench_data in _result.bench_results:
		var line: String = bench_data["narrative"]
		if bench_data["xp_gained"] > 0:
			line += "  (+%d XP)" % bench_data["xp_gained"]
		if bench_data["stamina_gain"] > 0:
			line += "  (+%d stamina)" % bench_data["stamina_gain"]
		_events.append({ "type": "bench", "text": line })

	# Three acts — act color driven by situation coverage per act
	var pr: Array = _result.player_results
	var act_situations: Array[String] = _get_act_situations(pr)
	var situations: Array = _result.situations

	# Determine per-act situation hit (does any player cover this act's situation?)
	var player_traits: Array = _result.player_match_traits
	var act_names: Array[String] = ["⚡ Early", "⚡ Mid", "⚡ Late"]

	for act_idx in 3:
		# Check if this act's situation is covered by the squad
		var sit_covered: bool = false
		var sit_name_str: String = ""
		var sit_trait_str: String = ""
		if act_idx < situations.size():
			var sit: String = situations[act_idx]
			var favored: String = TraitMatchup.SITUATION_FAVORS.get(sit, "")
			sit_covered = favored in player_traits
			sit_name_str  = GameText.SITUATION_NAMES.get(sit, sit)
			sit_trait_str = GameText.trait_label(favored)

		# Act header — always neutral blue (phase label is never colored)
		_events.append({ "type": "act_header", "text": act_names[act_idx] })

		# Situation line — colored green if squad covers it, red if not
		if sit_name_str != "":
			_events.append({
				"type":     "sit_line",
				"text":     "%s  →  %s" % [sit_name_str, sit_trait_str],
				"covered":  sit_covered,
			})

		_events.append({ "type": "situation", "text": act_situations[act_idx] })
		for entry in pr:
			# Check if this player's match trait counters any opponent trait
			var p: Player = entry["player"]
			var p_mt: String = TraitMatchup.TRAIT_TO_MATCH.get(p.primary_trait, "tactical")
			var opp_traits: Array = _result.opponent_traits
			var player_counters: bool = false
			var player_countered: bool = false
			for ot in opp_traits:
				if p_mt in TraitMatchup.WINS_AGAINST and ot in TraitMatchup.WINS_AGAINST[p_mt]:
					player_counters = true
				if p_mt in TraitMatchup.LOSES_AGAINST and ot in TraitMatchup.LOSES_AGAINST[p_mt]:
					player_countered = true
			_events.append(_player_act_event(entry, act_idx, player_counters, player_countered))

	# Result
	_events.append({ "type": "result",
		"won":        _result.won,
		"team_score": _result.team_score,
		"opp_score":  _result.opponent_score
	})

	# Matchup debrief with colored counter rows
	_events.append_array(_build_matchup_debrief())

	# Level-ups
	for lu in _result.level_ups:
		_events.append({ "type": "levelup",
			"text": "⬆ %s reached Level %d!" % [lu["player_name"], lu["new_level"]]
		})

	if _result.quarter_bonus != "":
		_events.append({ "type": "bonus", "text": "🌟 " + _result.quarter_bonus })

	_events.append({ "type": "done" })


# ---------------------------------------------------------------------------
# MATCHUP DEBRIEF — per-opponent-slot colored green/red
# ---------------------------------------------------------------------------

func _build_matchup_debrief() -> Array:
	var debrief: Array = []
	var opp_traits:    Array = _result.opponent_traits
	var situations:    Array = _result.situations
	var player_traits: Array = _result.player_match_traits

	if opp_traits.is_empty() and situations.is_empty():
		return debrief

	debrief.append({ "type": "debrief_header", "text": "What countered what" })

	# Per opponent slot — show if any player trait beat it
	for ot in opp_traits:
		var hit: bool = false
		var hit_by: String = ""
		for pt in player_traits:
			if pt in TraitMatchup.WINS_AGAINST and ot in TraitMatchup.WINS_AGAINST[pt]:
				hit = true
				hit_by = GameText.trait_label(pt)
				break
		var opp_label: String = GameText.trait_label(ot)
		if hit:
			debrief.append({
				"type":     "counter_row",
				"text":     "✓  %s  ←  %s" % [opp_label, hit_by],
				"positive": true,
			})
		else:
			# Check if opponent punished us
			var punished: bool = false
			for pt in player_traits:
				if pt in TraitMatchup.LOSES_AGAINST and ot in TraitMatchup.LOSES_AGAINST[pt]:
					punished = true
					break
			var pfx: String = "✗" if punished else "—"
			debrief.append({
				"type":     "counter_row",
				"text":     "%s  %s  (uncountered)" % [pfx, opp_label],
				"positive": false,
			})

	# Situation coverage per event
	debrief.append({ "type": "debrief_subheader", "text": "Situations" })
	var phase_names: Array[String] = ["Early", "Mid", "Late"]
	for i in situations.size():
		var sit: String = situations[i]
		var favored: String = TraitMatchup.SITUATION_FAVORS.get(sit, "")
		var covered: bool = favored in player_traits
		var phase: String = phase_names[i] if i < phase_names.size() else "Late"
		var sit_name: String = GameText.SITUATION_NAMES.get(sit, sit)
		var favor_lbl: String = GameText.trait_label(favored)
		if covered:
			debrief.append({
				"type":     "counter_row",
				"text":     "✓  %s — %s  →  covered" % [phase, sit_name],
				"positive": true,
			})
		else:
			debrief.append({
				"type":     "counter_row",
				"text":     "✗  %s — %s  (needs %s)" % [phase, sit_name, favor_lbl],
				"positive": false,
			})

	return debrief


# ---------------------------------------------------------------------------
# ACT SITUATIONS
# ---------------------------------------------------------------------------

func _get_act_situations(pr: Array) -> Array[String]:
	var is_important: bool = _result.match_type in [
		Calendar.TYPE_IMPORTANT, Calendar.TYPE_TOURNAMENT
	]
	var team_score: int = _result.team_score
	var opp_score:  int = _result.opponent_score

	var early: String
	if is_important:
		early = "High stakes from the first second. Both teams feeling the pressure."
	else:
		early = "Teams sizing each other up. Opening exchanges."

	var diff: int = team_score - opp_score
	var mid: String
	if diff > 15:
		mid = "Your team pulling ahead — momentum building."
	elif diff < -15:
		mid = "Falling behind. Time to dig in."
	else:
		mid = "Neck and neck. Every play matters now."

	var late: String
	if _result.won and diff <= 15:
		late = "Grinding it out in the final stretch. Close all the way."
	elif _result.won:
		late = "Comfortable in the lead. Closing it out."
	elif diff >= -10:
		late = "So close — couldn't find the final play."
	else:
		late = "Couldn't close the gap. A tough one to watch."

	return [early, mid, late]


# ---------------------------------------------------------------------------
# PER-PLAYER PER-ACT EVENT
# ---------------------------------------------------------------------------

func _player_act_event(entry: Dictionary, act_idx: int, player_counters: bool = false, player_countered: bool = false) -> Dictionary:
	var player: Player  = entry["player"]
	var label:  String  = entry.get("label", "")
	var flavor: String  = entry.get("flavor", "")
	var trigger: String = entry.get("trait_trigger", "")
	var score:  int     = entry.get("score", 0)
	var xp:     int     = entry.get("xp_gained", 0)

	var line: String
	match act_idx:
		0:
			var notes: PackedStringArray = []
			match player.stamina_key():
				"exhausted": notes.append("running on empty")
				"tired":     notes.append("showing fatigue")
				"ok":        notes.append("feeling okay")
				"fresh":     notes.append("fully rested")
			if player.form_label == "🔥 In Form":
				notes.append("in form")
			elif player.form_label == "📉 Struggling":
				notes.append("on a rough run")
			if player.burnout >= 3:
				notes.append("burnout showing")
			var note_str: String = "  (%s)" % ", ".join(notes) if notes.size() > 0 else ""
			line = player.player_name + note_str

		1:
			line = player.player_name + "  —  " + label
			if trigger != "":
				line += "  ·  " + trigger

		2:
			if flavor != "":
				line = player.player_name + ": " + flavor
			else:
				var closing: String = "Solid finish." if score >= 50 else "Quiet finish."
				line = player.player_name + ": " + closing
			if xp > 0:
				line += "  (+%d XP)" % xp

	return { "type": "player_act", "text": line, "act": act_idx,
		"is_strong": score >= 75, "is_weak": score < 50,
		"player_counters": player_counters, "player_countered": player_countered }


# ---------------------------------------------------------------------------
# PLAYBACK
# ---------------------------------------------------------------------------

func _start() -> void:
	_index   = 0
	_timer   = 0.0
	_running = true
	_continue_btn.hide()


func _process(delta: float) -> void:
	if not _running:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	if _index >= _events.size():
		return

	var event: Dictionary = _events[_index]
	_index += 1
	_reveal_event(event)

	match event.get("type", ""):
		"act_header", "result", "debrief_header": _timer = ACT_PAUSE
		"done":                                    _timer = 0.0
		_:                                         _timer = REVEAL_DELAY


func _reveal_event(event: Dictionary) -> void:
	match event["type"]:

		"header":
			_add_line(event["text"], Color(1.0, 0.70, 0.25, 1.0), 16)

		"bench":
			_add_line(event["text"], Color(0.48, 0.48, 0.58, 1.0), 13)

		"act_header":
			_add_spacer()
			# Act headers always stay neutral blue — never colored
			_add_line(event["text"], Color(0.35, 0.75, 1.0, 1.0), 15)

		"sit_line":
			# Situation line — green if covered by squad, red if not
			var sit_col: Color = Color(0.30, 0.88, 0.45, 1.0) if event.get("covered", false) \
				else Color(0.88, 0.32, 0.32, 1.0)
			_add_line("  " + event["text"], sit_col, 12)

		"situation":
			_add_line(event["text"], Color(0.58, 0.60, 0.70, 1.0), 12)

		"player_act":
			# Act 1 (mid): color by counter status — green if player counters opponent, red if countered
			# Acts 0 and 2: color by performance (strong/weak)
			var color: Color
			if event["act"] == 1:
				if event.get("player_counters", false):
					color = Color(0.32, 0.90, 0.48, 1.0)  # green — we counter them
				elif event.get("player_countered", false):
					color = Color(0.90, 0.35, 0.35, 1.0)  # red — they counter us
				else:
					color = Color(0.85, 0.85, 0.90, 1.0)  # neutral
			else:
				if event["is_strong"]:   color = Color(0.95, 0.95, 0.70, 1.0)
				elif event["is_weak"]:   color = Color(0.75, 0.55, 0.55, 1.0)
				else:                    color = Color(0.85, 0.85, 0.90, 1.0)
			_add_line("    " + event["text"], color, 13)

		"result":
			_add_spacer()
			if event["won"]:
				_add_line("✅  VICTORY", Color(0.25, 0.90, 0.45, 1.0), 34)
			else:
				_add_line("❌  DEFEAT",  Color(0.90, 0.28, 0.28, 1.0), 34)
			# Show effective scores — these are what the simulation actually compared
			_add_line("Score  %d pts  vs  %d pts (effective threshold)" % [event["team_score"], event["opp_score"]],
				Color(0.55, 0.58, 0.68, 1.0), 13)

		"debrief_header":
			_add_spacer()
			_add_line(event["text"].to_upper(), Color(0.42, 0.44, 0.55, 1.0), 10)

		"debrief_subheader":
			_add_line(event["text"].to_upper(), Color(0.38, 0.40, 0.50, 1.0), 9)

		"counter_row":
			var col: Color = Color(0.35, 0.88, 0.48, 1.0) if event.get("positive", false) \
				else Color(0.88, 0.38, 0.38, 1.0)
			_add_line("    " + event["text"], col, 12)

		"levelup":
			_add_line(event["text"], Color(0.95, 0.85, 0.30, 1.0), 14)

		"bonus":
			_add_line(event["text"], Color(0.90, 0.70, 0.20, 1.0), 13)

		"done":
			_running = false
			_continue_btn.show()
			_scroll_to_bottom()


# ---------------------------------------------------------------------------
# UI HELPERS
# ---------------------------------------------------------------------------

func _add_line(text: String, color: Color, font_size: int) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_event_log.add_child(lbl)
	_scroll_to_bottom()


func _add_spacer() -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	_event_log.add_child(spacer)


func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


func _on_continue_btn_pressed() -> void:
	queue_free()
	finished.emit()
