# scripts/managers/LeagueManager.gd
# ============================================================
# LEAGUE SYSTEM — one season, 8 teams (1 player + 7 NPCs).
#
# DESIGN GOALS:
#   - Zero complex simulation. NPC results = one seeded randi() per team per week.
#   - Deterministic: same season+week always produces same NPC results.
#   - No new entities, no trait data, no match logs.
#   - Two integration points in GameManager: simulate_npc_week() and record_result().
#
# STANDINGS:
#   - 3 pts for a win, 0 for a loss. No draws.
#   - Tie-break: wins count (same as points, so ties only happen at same record).
#   - Rank re-sorted after every week.
#
# TIERS (end of season):
#   - Rank 1–3 → TOP: +15 morale all players, +100 XP all players
#   - Rank 4–6 → MID: no bonus, no penalty
#   - Rank 7–8 → BOT: −10 morale all players
#
# NPC TEAM NAMES:
#   Drawn from Calendar.OPPONENT_NAMES. 7 NPCs = 7 names, seeded by season.
#   Strength (win probability 30–80%) also seeded by season — same NPCs
#   appear every season but may grow stronger (difficulty scale).
# ============================================================
class_name LeagueManager
extends RefCounted

const TEAM_COUNT:     int = 8
const POINTS_WIN:     int = 3
const POINTS_LOSS:    int = 0
const TOP_TIER_CUTOFF: int = 3   # rank 1–3
const BOT_TIER_CUTOFF: int = 6   # rank 7–8

# Each entry:
# { "name": String, "strength": int, "points": int, "wins": int, "losses": int, "is_player": bool }
var teams:      Array[Dictionary] = []
var player_idx: int               = 0   # index of the player's team in teams[]
var season:     int               = 1


func _init(season_number: int, team_name: String) -> void:
	season = season_number
	_build_teams(team_name)


# ---------------------------------------------------------------------------
# SETUP
# ---------------------------------------------------------------------------
func _build_teams(team_name: String) -> void:
	teams.clear()

	# Player team always at index 0
	teams.append({
		"name":      team_name,
		"strength":  0,    # unused for player
		"points":    0,
		"wins":      0,
		"losses":    0,
		"is_player": true,
	})
	player_idx = 0

	# 7 NPC teams: names + strengths seeded by season
	var npc_names: Array[String] = _pick_npc_names()
	var strengths:  Array[int]   = _pick_npc_strengths()
	for i in 7:
		teams.append({
			"name":      npc_names[i],
			"strength":  strengths[i],
			"points":    0,
			"wins":      0,
			"losses":    0,
			"is_player": false,
		})


func _pick_npc_names() -> Array[String]:
	# Seed by season so the same names appear each season (they're your rivals).
	# Avoid the player's name — players can't rename so this is safe.
	var pool: Array = Calendar.OPPONENT_NAMES.duplicate()
	seed(season * 997 + 7)
	pool.shuffle()
	var result: Array[String] = []
	for i in 7:
		result.append(pool[i])
	return result


func _pick_npc_strengths() -> Array[int]:
	# Base range NPC_STRENGTH_MIN..NPC_STRENGTH_MAX. Each season adds NPC_SEASON_RAMP
	# to every NPC (capped). Strength caps at NPC_STRENGTH_HARD_CAP so any team is beatable.
	seed(season * 1337 + 13)
	var season_bonus: int = min((season - 1) * Balance.league_balance.npc_season_ramp, Balance.league_balance.npc_season_ramp_cap)
	var result: Array[int] = []
	var span: int = Balance.league_balance.npc_strength_max - Balance.league_balance.npc_strength_min + 1
	for i in 7:
		var base: int = Balance.league_balance.npc_strength_min + (randi() % span)
		result.append(min(base + season_bonus, Balance.league_balance.npc_strength_hard_cap))
	return result


# ---------------------------------------------------------------------------
# WEEKLY UPDATE — called once per week in advance_week(), before the player match.
# Simulates all 7 NPC matches for this week.
# Fully deterministic: same season+week = same results, always.
# ---------------------------------------------------------------------------
func simulate_npc_week(week_in_season: int) -> void:
	for i in teams.size():
		if teams[i]["is_player"]:
			continue
		var won: bool = _npc_wins(teams[i]["strength"], season, week_in_season, i)
		if won:
			teams[i]["points"] += POINTS_WIN
			teams[i]["wins"]   += 1
		else:
			teams[i]["losses"] += 1
	_sort_standings()


func _npc_wins(strength: int, s: int, w: int, team_i: int) -> bool:
	seed(s * 10000 + w * 100 + team_i)
	return (randi() % 100) < strength


# ---------------------------------------------------------------------------
# RECORD PLAYER RESULT — called after Simulation.simulate_team() resolves.
# ---------------------------------------------------------------------------
func record_result(won: bool) -> void:
	if won:
		teams[player_idx]["points"] += POINTS_WIN
		teams[player_idx]["wins"]   += 1
	else:
		teams[player_idx]["losses"] += 1
	_sort_standings()


# ---------------------------------------------------------------------------
# STANDINGS — always sorted, player rank computed from position.
# ---------------------------------------------------------------------------
func _sort_standings() -> void:
	teams.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["points"] != b["points"]:
			return a["points"] > b["points"]
		return a["wins"] > b["wins"]
	)
	# Re-find player_idx after sort
	for i in teams.size():
		if teams[i]["is_player"]:
			player_idx = i
			return


func player_rank() -> int:
	return player_idx + 1   # 1-indexed


func player_points() -> int:
	return teams[player_idx]["points"]


func player_record() -> String:
	return "%d–%d" % [teams[player_idx]["wins"], teams[player_idx]["losses"]]


# ---------------------------------------------------------------------------
# SEASON END — apply tier bonuses/penalties.
# Called by GameManager at the end of week 24.
# Returns a description string for the resolution banner.
# ---------------------------------------------------------------------------
func apply_season_result(players: Array[Player]) -> String:
	var season_rank: int = player_rank()
	var description: String = ""

	if season_rank <= TOP_TIER_CUTOFF:
		for p: Player in players:
			p.morale  = min(p.morale + Balance.league_balance.league_top_morale_bonus, 100)
			p.xp      += Balance.league_balance.league_top_xp_bonus
			p.xp_delta += Balance.league_balance.league_top_xp_bonus
		description = "🏅 Season #%d: Finished rank %d — morale +%d, +%d XP all players." % [
			season, season_rank, Balance.league_balance.league_top_morale_bonus, Balance.league_balance.league_top_xp_bonus
		]
	elif season_rank > BOT_TIER_CUTOFF:
		for p: Player in players:
			p.morale  = max(p.morale - Balance.league_balance.league_bot_morale_penalty, 0)
		description = "📉 Season #%d: Finished rank %d — morale −%d." % [
			season, season_rank, Balance.league_balance.league_bot_morale_penalty
		]
	else:
		description = "Season #%d: Finished rank %d." % [season, season_rank]

	return description


# ---------------------------------------------------------------------------
# NEXT SEASON — reset for a new season.
# Re-seeds NPC strengths for the new season (difficulty ramp built-in).
# ---------------------------------------------------------------------------
func reset_for_season(new_season: int, team_name: String) -> void:
	season = new_season
	_build_teams(team_name)


# ---------------------------------------------------------------------------
# GET STANDINGS FOR UI
# Returns the sorted teams array for the hub standings panel.
# Fields: name, points, wins, losses, is_player, tier
# ---------------------------------------------------------------------------
func get_standings() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in teams.size():
		var t: Dictionary = teams[i].duplicate()
		t["rank"] = i + 1
		if i < TOP_TIER_CUTOFF:
			t["tier"] = "top"
		elif i >= BOT_TIER_CUTOFF:
			t["tier"] = "bot"
		else:
			t["tier"] = "mid"
		result.append(t)
	return result
