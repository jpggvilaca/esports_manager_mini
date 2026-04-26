# scenes/ResolutionScreen.gd
# Sequenced resolution. Bench outcomes → three match acts (all players each act) → result.
# Also shows matchup debrief: what the trait counters and situations contributed.
class_name ResolutionScreen
extends Control

const TraitMatchup := preload("res://scripts/systems/TraitMatchup.gd")

signal finished

const REVEAL_DELAY: float = 0.9   # between lines within an act
const ACT_PAUSE:    float = 2.0   # pause between acts

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

	# Header
	var mtype_label: String = GameText.MATCH_TYPE.get(_result.match_type, "Match")
	_events.append({ "type": "header",
		"text": "Season %d  ·  Week %d  ·  %s" % [_result.season, _result.week, mtype_label]
	})

	# Bench outcomes — quiet before the drama
	for bench_data in _result.bench_results:
		var line: String = bench_data["narrative"]
		if bench_data["xp_gained"] > 0:
			line += "  (+%d XP)" % bench_data["xp_gained"]
		if bench_data["stamina_gain"] > 0:
			line += "  (+%d stamina)" % bench_data["stamina_gain"]
		_events.append({ "type": "bench", "text": line })

	# Three match acts — ALL players appear in every act.
	var pr: Array = _result.player_results
	var act_situations: Array[String] = _get_act_situations(pr)

	var act_names: Array[String] = ["⚡ Early Game", "⚡ Mid Game", "⚡ Late Game"]
	for act_idx in 3:
		_events.append({ "type": "act_header", "text": act_names[act_idx] })
		_events.append({ "type": "situation", "text": act_situations[act_idx] })
		for entry in pr:
			_events.append(_player_act_event(entry, act_idx))

	# Result beat
	_events.append({ "type": "result",
		"won":        _result.won,
		"team_score": _result.team_score,
		"opp_score":  _result.opponent_score
	})

	# Matchup debrief — explains what the trait counters contributed
	_events.append_array(_build_matchup_debrief())

	# Level-ups
	for lu in _result.level_ups:
		_events.append({ "type": "levelup",
			"text": "⬆ %s reached Level %d!" % [lu["player_name"], lu["new_level"]]
		})

	if _result.quarter_bonus != "":
		_events.append({ "type": "bonus", "text": "🌟 " + _result.quarter_bonus })

	# Trait cheatsheet — always shown at the end so the player can study it
	_events.append({ "type": "cheatsheet_header" })
	for mt in TraitMatchup.MATCH_TRAITS:
		var beats: Array = TraitMatchup.WINS_AGAINST.get(mt, [])
		var weak:  Array = TraitMatchup.LOSES_AGAINST.get(mt, [])
		_events.append({
			"type":  "cheatsheet_row",
			"trait": mt,
			"beats": beats,
			"weak":  weak,
		})

	_events.append({ "type": "done" })


# ---------------------------------------------------------------------------
# MATCHUP DEBRIEF — short readable summary of what the trait matchup contributed.
# Appears after VICTORY/DEFEAT so the player understands the why.
# ---------------------------------------------------------------------------

func _build_matchup_debrief() -> Array:
	var debrief: Array = []
	var modifier: float = _result.matchup_modifier
	var opp_traits: Array = _result.opponent_traits
	var situations: Array = _result.situations
	var player_traits: Array = _result.player_match_traits

	if opp_traits.is_empty() and situations.is_empty():
		return debrief

	debrief.append({ "type": "debrief_header", "text": "Match breakdown" })

	# Opponent matchup line
	var opp_hits: int = 0
	var opp_misses: int = 0
	for pt in player_traits:
		for ot in opp_traits:
			if pt in TraitMatchup.WINS_AGAINST and ot in TraitMatchup.WINS_AGAINST[pt]:
				opp_hits += 1
			elif pt in TraitMatchup.LOSES_AGAINST and ot in TraitMatchup.LOSES_AGAINST[pt]:
				opp_misses += 1

	var opp_line: String
	if opp_hits > opp_misses:
		opp_line = "Opponent  ·  Your comp countered their style"
	elif opp_misses > opp_hits:
		opp_line = "Opponent  ·  Their style punished your comp"
	else:
		opp_line = "Opponent  ·  Even matchup — no clear edge"
	debrief.append({ "type": "debrief", "text": opp_line, "positive": opp_hits >= opp_misses })

	# Situation coverage line
	var sit_hits: int = 0
	for sit in situations:
		var favored: String = TraitMatchup.SITUATION_FAVORS.get(sit, "")
		if favored in player_traits:
			sit_hits += 1
	var sit_label: String = GameText.situation_label(situations[0]) if situations.size() > 0 else ""
	var sit_line: String
	if sit_hits == situations.size():
		sit_line = "Situations  ·  Full coverage — every event suited your team"
	elif sit_hits > 0:
		sit_line = "Situations  ·  Partial coverage — %d / %d events suited you" % [sit_hits, situations.size()]
	else:
		sit_line = "Situations  ·  No coverage — events didn't suit your comp"
	debrief.append({ "type": "debrief", "text": sit_line, "positive": sit_hits > 0 })

	return debrief


# ---------------------------------------------------------------------------
# ACT SITUATIONS — narrative for each act based on match state.
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

	var mid: String
	var diff: int = team_score - opp_score
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

func _player_act_event(entry: Dictionary, act_idx: int) -> Dictionary:
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
			var sk: String = player.stamina_key()
			match sk:
				"exhausted": notes.append("running on empty")
				"tired":     notes.append("showing fatigue")
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
		"is_strong": score >= 75, "is_weak": score < 50 }


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
			_add_line(event["text"], Color(0.35, 0.75, 1.0, 1.0), 15)

		"situation":
			_add_line(event["text"], Color(0.60, 0.62, 0.72, 1.0), 13)

		"player_act":
			var color: Color
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
			_add_line("Score  %d pts  vs  %d pts" % [event["team_score"], event["opp_score"]],
				Color(0.55, 0.58, 0.68, 1.0), 13)

		"debrief_header":
			_add_spacer()
			_add_line(event["text"].to_upper(), Color(0.40, 0.42, 0.52, 1.0), 11)

		"debrief":
			var col: Color = Color(0.55, 0.85, 0.60, 1.0) if event.get("positive", true) \
				else Color(0.85, 0.52, 0.45, 1.0)
			_add_line("    " + event["text"], col, 12)

		"levelup":
			_add_line(event["text"], Color(0.95, 0.85, 0.30, 1.0), 14)

		"bonus":
			_add_line(event["text"], Color(0.90, 0.70, 0.20, 1.0), 13)

		"cheatsheet_header":
			_add_spacer()
			_add_line("TRAIT COUNTER GUIDE", Color(0.38, 0.40, 0.50, 1.0), 10)

		"cheatsheet_row":
			var mt: String = event["trait"]
			var beats_names: Array = event["beats"].map(func(t): return GameText.trait_label(t))
			var weak_names:  Array = event["weak"].map(func(t): return GameText.trait_label(t))
			var beats_str: String = "  ↑ " + ", ".join(beats_names) if beats_names.size() > 0 else ""
			var weak_str:  String = "  ↓ " + ", ".join(weak_names)  if weak_names.size()  > 0 else ""
			var row_text: String = GameText.trait_label(mt) + beats_str + weak_str
			_add_line("    " + row_text, Color(0.55, 0.58, 0.70, 1.0), 11)

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
