# scripts/managers/GameManager.gd
# ============================================================
# THIN ORCHESTRATOR — owns player roster, week counter, and streaks.
# All match execution is delegated to MatchDispatcher.
# All goal tracking is delegated to SeasonGoalManager.
#
# TO TWEAK weekly action effects → edit apply_actions() below.
# TO TWEAK match logic           → edit MatchDispatcher.gd
# TO TWEAK XP / level-ups        → edit LevelSystem.gd
# TO TWEAK season/quarter goals  → edit SeasonGoalManager.gd
# ============================================================
class_name GameManager
extends RefCounted

var players: Array[Player]       = []
var week: int                    = 1
var team_win_streak: int         = 0
var selected_solo_player: String = ""

var goal_manager: SeasonGoalManager = null

# Market system — generates candidates and handles replacements.
# TO TWEAK market timing and slot budget → edit PlayerMarket.gd
var market: PlayerMarket = null

# Derived week/season — never set directly, always computed from week.
var season: int:         get = _get_season
var week_in_season: int: get = _get_week_in_season

func _get_season() -> int:         return Calendar.get_season(week)
func _get_week_in_season() -> int: return Calendar.get_week_in_season(week)


# ---------------------------------------------------------------------------
# INITIALISATION
# TO ADD / CHANGE PLAYERS → edit here. Player.new(name, skill, focus, stamina, morale, primary_trait, minor_trait)
# ---------------------------------------------------------------------------
func _init() -> void:
	var apex  := Player.new("Apex",  42, 50, 60, 55, "clutch",   "resilient")
	var byte_ := Player.new("Byte",  35, 38, 55, 50, "grinder",  "none")
	var ghost := Player.new("Ghost", 30, 45, 58, 45, "volatile", "fragile")
	apex.bio  = "Mechanical prodigy who thrives under pressure — but drifts in routine weeks."
	byte_.bio = "Grinds harder than anyone. Slow to start, relentless by mid-season."
	ghost.bio = "Unpredictable and fragile. On a good day, unplayable. On a bad one, invisible."
	players   = [apex, byte_, ghost]
	goal_manager = SeasonGoalManager.new()
	market       = PlayerMarket.new()


# ---------------------------------------------------------------------------
# ADVANCE WEEK — master flow for one week tick.
# Captures rest state → applies actions → runs match → updates goals.
# ---------------------------------------------------------------------------
func advance_week() -> MatchResult:
	var cal_entry: Dictionary  = Calendar.get_week(week)
	var match_type: String     = cal_entry["type"]

	# Capture who is resting BEFORE apply_actions resets planned_action.
	var resting_players: Array[String] = []
	for p: Player in players:
		if p.planned_action == "rest" or p.planned_action == "":
			resting_players.append(p.player_name)

	var has_active: bool = _team_has_active_action()
	apply_actions()

	# Pure rest week — no match this week.
	if match_type != Calendar.TYPE_SOLO and match_type != Calendar.TYPE_TOURNAMENT and not has_active:
		var rest_result := MatchResult.new()
		rest_result.has_match = false
		week += 1
		return rest_result

	var result: MatchResult = MatchDispatcher.run(
		match_type, players, week, season, team_win_streak,
		selected_solo_player, resting_players
	)
	_update_streaks(result.won)

	var current_week_in_season: int = week_in_season  # capture before week increments
	goal_manager.on_match_result(result, players, current_week_in_season)
	goal_manager.check_quarter_boundary(current_week_in_season)

	# Apply quarter bonus if triggered this week — carry it in the result for UI.
	if goal_manager.quarter_bonus_pending:
		var bonus_desc: String = goal_manager.quarter_bonus_description
		goal_manager.consume_quarter_bonus(players)
		result.quarter_bonus_description = bonus_desc

	week += 1
	# Refresh quarter goal after crossing a quarter boundary.
	goal_manager.start_new_quarter(week_in_season)
	return result


# ---------------------------------------------------------------------------
# PRE-MATCH CONTEXT — everything the UI needs before the player advances.
# TO ADD new context fields for the UI → add them to the returned dict here.
# ---------------------------------------------------------------------------
func get_prematch_context() -> Dictionary:
	var entry: Dictionary  = Calendar.get_week(week)
	var match_type: String = entry["type"]
	var cal_label: String  = entry["label"]

	var conditions: Array = []
	var has_tired:  bool  = false
	for p: Player in players:
		# Stamina condition buckets — TO TWEAK thresholds, change these numbers.
		var stamina_key: String
		if p.stamina >= 70:   stamina_key = "fresh"
		elif p.stamina >= 45: stamina_key = "ok"
		elif p.stamina >= 25: stamina_key = "tired"
		else:                 stamina_key = "exhausted"
		if stamina_key == "tired" or stamina_key == "exhausted":
			has_tired = true

		var morale_key: String
		if p.morale >= 80:   morale_key = "confident"
		elif p.morale < 40:  morale_key = "shaky"
		else:                morale_key = "neutral"

		conditions.append({
			"name":         p.player_name,
			"stamina_key":  stamina_key,
			"stamina_lbl":  GameText.STAMINA_CONDITION[stamina_key],
			"morale_key":   morale_key,
			"morale_lbl":   GameText.MORALE_CONDITION[morale_key],
			"morale_delta": p.morale_delta,
			"condition":    GameText.CONDITIONS.get(stamina_key, GameText.CONDITIONS["ready"]),
		})

	var team_skill: int = 0
	for p: Player in players:
		team_skill += p.skill

	return {
		"week":          week_in_season,
		"season":        season,
		"match_type":    match_type,
		"type_label":    GameText.MATCH_TYPE[match_type],
		"is_important":  match_type == Calendar.TYPE_IMPORTANT or match_type == Calendar.TYPE_TOURNAMENT,
		"is_tournament": match_type == Calendar.TYPE_TOURNAMENT,
		"is_solo":       match_type == Calendar.TYPE_SOLO,
		"opp_strength":  GameText.OPPONENT_STRENGTH.get(cal_label, cal_label),
		"difficulty":    GameText.DIFFICULTY.get(cal_label, cal_label),
		"win_estimate":  MatchDispatcher.win_estimate(team_skill, entry["opponent"]),
		"conditions":    conditions,
		"has_tired":     has_tired,
		"streak":        team_win_streak,
		"game_over":     Calendar.is_game_over(week),
		"player_names":  players.map(func(p): return p.player_name),
		# rest_count is used by the warning label — counts unselected + rest actions
		"rest_count":    players.filter(func(p): return p.planned_action == "rest" or p.planned_action == "").size(),
	}


# ---------------------------------------------------------------------------
# ACTION SYSTEM — applies the chosen weekly action for each player.
#
# DESIGN INTENT (hybrid model):
#   Actions = short-term impact on the NEXT match.
#   Matches = the MAIN source of XP and long-term growth.
#   Levels  = long-term stat improvements.
#
# Actions do NOT directly raise skill anymore — that happens via level-ups.
# Actions adjust stamina/focus/morale, which affect THIS week's match score.
#
# TO ADD A NEW ACTION → add a new "action_id" branch in the match block below,
#   add its XP value to LevelSystem.gd, and add its button in PlayerPanel.gd.
# TO REBALANCE → adjust the stamina costs and focus gains in each branch.
#
# DIMINISHING RETURNS: _apply_with_dr() softens gains when a stat is already high.
# ---------------------------------------------------------------------------
func apply_actions() -> void:
	# Count resting players for the collective focus penalty.
	# If 2+ players rest, the whole team gets slightly less sharp (missed scrim).
	var rest_count: int = 0
	for p: Player in players:
		if p.planned_action == "rest" or p.planned_action == "":
			rest_count += 1

	for p: Player in players:
		var prev_skill:   int = p.skill
		var prev_stamina: int = p.stamina
		var prev_morale:  int = p.morale
		p.xp_delta = 0

		match p.planned_action:

			# TRAIN: invest in long-term growth via XP. Costs stamina.
			# Skill does NOT grow here — it grows on level-up via LevelSystem.
			# Grinders pay more stamina but train harder instinctively.
			"train":
				var stamina_cost: int = 13 if p.primary_trait == "grinder" else 10
				p.stamina = max(p.stamina - stamina_cost, 0)

			# REST: recover stamina and morale. Zero XP — purely a recovery tool.
			# This should be the go-to when a player is tired before a big match.
			"rest":
				var stamina_gain: int = 23 if p.primary_trait == "lazy" else 15
				p.stamina = _apply_with_dr(p.stamina, stamina_gain, 80, 0.5)
				p.morale  = _apply_with_dr(p.morale,  5,            80, 0.5)

			# SCRIM: balanced option. Costs moderate stamina, improves focus.
			# Focus reduces match score randomness — makes the next match more consistent.
			"scrim":
				p.stamina = max(p.stamina - 8, 0)
				p.focus   = _apply_with_dr(p.focus, 4, 70, 0.4)

			# INTENSE: high-risk push. Costs heavy stamina AND morale.
			# Best used when a player is fresh and needs a short-term stat spike before a key match.
			# Does NOT give direct skill — the XP does that over time.
			"intense":
				var stamina_cost: int = 20
				p.stamina = max(p.stamina - stamina_cost, 0)
				p.morale  = max(p.morale  - 5, 0)
				# Small immediate focus bonus — you're sharpening for a specific enemy.
				p.focus   = _apply_with_dr(p.focus, 3, 70, 0.4)

		# Collective bench penalty: team loses a little focus when 2+ players rest.
		# TO TWEAK: change the threshold (2) or the drain amount (2).
		if rest_count >= 2:
			p.focus = max(p.focus - 2, 1)

		# Award action XP (small — matches are the main XP source).
		LevelSystem.award_action_xp(p, p.planned_action)

		# Track deltas for UI feedback (shown in conditions panel next week).
		p.skill_delta    = p.skill   - prev_skill
		p.stamina_delta  = p.stamina - prev_stamina
		p.morale_delta   = p.morale  - prev_morale
		p.planned_action = ""


# ---------------------------------------------------------------------------
# GOAL DISPLAY PASSTHROUGHS — UI only needs to call GameManager.
# ---------------------------------------------------------------------------

# Returns season goal state for the header panel.
func get_season_goal_display() -> Dictionary:
	return goal_manager.get_display()


# Returns quarter goal state for the header panel.
func get_quarter_goal_display() -> Dictionary:
	return goal_manager.get_quarter_display()


# ---------------------------------------------------------------------------
# MARKET PASSTHROUGHS
# The UI calls these — GameManager stays the single interface point.
# ---------------------------------------------------------------------------

# Returns true if the market should be available this week.
# Used by GameWorld to show/hide the Market button.
func is_market_available() -> bool:
	var next_event: Dictionary = Calendar.get_next_event(week)
	return market.is_available(week_in_season, next_event)


# Generates and returns fresh market candidates.
# Call this when the player opens the market UI.
func open_market() -> Array:
	return market.generate_candidates(players)


# Replaces players[replace_index] with candidate.
# Returns false if out of slots or invalid index.
func hire_candidate(candidate: Player, replace_index: int) -> bool:
	var success: bool = market.replace_player(players, candidate, replace_index)
	# After a hire the PlayerPanel cards need to refresh — handled by Main.gd.
	return success


# Returns a display string for remaining market slots, e.g. "●●○".
func market_slots_display() -> String:
	return market.slots_display()


# Returns true if at least one replacement slot remains this season.
func market_has_slots() -> bool:
	return market.has_slots()


# ---------------------------------------------------------------------------
# PRIVATE HELPERS
# ---------------------------------------------------------------------------

# Returns true if at least one player chose an active (match-qualifying) action.
# Solo/tournament matches always run regardless of this flag.
func _team_has_active_action() -> bool:
	for p: Player in players:
		if p.planned_action in ["train", "scrim", "intense"]:
			return true
	return false


# Updates win/loss streaks for the team and all players after a match.
# TO TWEAK streak logic → edit here.
func _update_streaks(won: bool) -> void:
	if won:
		team_win_streak = max(team_win_streak + 1, 1)
		for p: Player in players:
			p.win_streak = max(p.win_streak + 1, 1)
	else:
		team_win_streak = min(team_win_streak - 1, -1)
		for p: Player in players:
			p.win_streak = min(p.win_streak - 1, -1)


# ---------------------------------------------------------------------------
# DIMINISHING RETURNS — prevents stats from scaling too fast.
#
# stat:       current stat value
# raw_gain:   the full gain before DR
# soft_cap:   above this value, DR kicks in
# dr_factor:  fraction of gain kept above soft_cap (e.g. 0.5 = half as effective)
#
# Example: _apply_with_dr(75, 10, 70, 0.5)
#   → 5 points below cap at full rate = +5
#   → 5 points above cap at 50% rate  = +2
#   → total = 77 + 2 = 79 (instead of 85)
#
# TO TUNE: raise soft_cap to push DR later, lower dr_factor to slow gains more.
# ---------------------------------------------------------------------------
static func _apply_with_dr(stat: int, raw_gain: int, soft_cap: int, dr_factor: float) -> int:
	if stat >= soft_cap:
		# Already above cap — apply full DR.
		return min(stat + int(raw_gain * dr_factor), 100)
	var headroom: int = soft_cap - stat
	if raw_gain <= headroom:
		# Entire gain fits below the cap — no DR needed.
		return min(stat + raw_gain, 100)
	# Split: part below cap at full rate, part above at reduced rate.
	var below_cap: int = headroom
	var above_cap: int = raw_gain - headroom
	return min(stat + below_cap + int(above_cap * dr_factor), 100)
