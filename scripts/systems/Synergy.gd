# scripts/systems/Synergy.gd
# ============================================================
# SYNERGY TRACKER — counts unordered pair appearances across matches.
#
# DESIGN:
#   When two players are both active in the same match, their pair's
#   "matches_together" counter increments by 1. Once it reaches
#   Tuning.SYNERGY_THRESHOLD, the pair is "synergized" and grants a
#   flat per-player score bonus whenever both are active in the same match.
#
#   The counter is stored on a per-pair basis using a canonical key
#   (sorted "name_a||name_b") so order doesn't matter.
#
#   Pairs are NEVER reset by trades — the new player just starts at 0
#   with everyone. If a player is removed from the roster, their pairs
#   are pruned (clean_for_roster).
#
# STACKING (in active squad of 3):
#   Three unordered pairs can exist: (A,B), (A,C), (B,C).
#   Each synergized pair adds Tuning.SYNERGY_BONUS_PER_PAIR to each of
#   its two players' match scores. Diminishing returns apply per the
#   tuning constant SYNERGY_STACK_DIMINISH so a triple-synergized squad
#   doesn't become uncatchable.
#
# DETERMINISM: this state is pure data, no RNG. Increment is gameplay-driven.
# ============================================================
class_name Synergy
extends RefCounted


# Map of "a||b" (sorted) → matches_together (int).
var _counts: Dictionary = {}


# ---------------------------------------------------------------------------
# RECORD MATCH — call this once per resolved match with the active squad.
# Increments every unordered pair's counter by 1.
# ---------------------------------------------------------------------------
func record_match(active_players: Array) -> void:
	if active_players.size() < 2:
		return
	for i in active_players.size():
		for j in range(i + 1, active_players.size()):
			var a: Player = active_players[i]
			var b: Player = active_players[j]
			var key: String = _pair_key(a.player_name, b.player_name)
			_counts[key] = _counts.get(key, 0) + 1


# ---------------------------------------------------------------------------
# MATCHES TOGETHER — public lookup.
# ---------------------------------------------------------------------------
func matches_together(name_a: String, name_b: String) -> int:
	if name_a == name_b:
		return 0
	return _counts.get(_pair_key(name_a, name_b), 0)


# ---------------------------------------------------------------------------
# IS SYNERGIZED — has this pair reached the threshold?
# ---------------------------------------------------------------------------
func is_synergized(name_a: String, name_b: String) -> bool:
	return matches_together(name_a, name_b) >= Balance.match_balance.synergy_threshold


# ---------------------------------------------------------------------------
# SYNERGIZED PAIRS IN SQUAD — returns a list of [name_a, name_b] arrays for
# every synergized pair in the given active squad.
# ---------------------------------------------------------------------------
func synergized_pairs_in(active_players: Array) -> Array:
	var pairs: Array = []
	for i in active_players.size():
		for j in range(i + 1, active_players.size()):
			var a: Player = active_players[i]
			var b: Player = active_players[j]
			if is_synergized(a.player_name, b.player_name):
				pairs.append([a.player_name, b.player_name])
	return pairs


# ---------------------------------------------------------------------------
# PER-PLAYER SCORE BONUS — for use in Simulation.
# Returns a dict { player_name → bonus_int } summing every synergized pair
# the player is in, with diminishing returns when stacking.
#
# Example, fully synergized 3-squad (3 pairs):
#   Each player is in 2 synergized pairs.
#   First pair = full bonus, second pair = bonus × DIMINISH.
#   Player A bonus = SYNERGY_BONUS_PER_PAIR + SYNERGY_BONUS_PER_PAIR * DIMINISH
# ---------------------------------------------------------------------------
func score_bonus_per_player(active_players: Array) -> Dictionary:
	var per_player: Dictionary = {}
	for p in active_players:
		per_player[p.player_name] = []   # list of contributing pair-bonuses

	var pairs: Array = synergized_pairs_in(active_players)
	for pair in pairs:
		var name_a: String = pair[0]
		var name_b: String = pair[1]
		per_player[name_a].append(Balance.match_balance.synergy_bonus_per_pair)
		per_player[name_b].append(Balance.match_balance.synergy_bonus_per_pair)

	# Apply diminishing returns to each player's stack of pair bonuses.
	var result: Dictionary = {}
	for player_name in per_player.keys():
		var stack: Array = per_player[player_name]
		var total: float = 0.0
		for i in stack.size():
			total += float(stack[i]) * pow(Balance.match_balance.synergy_stack_diminish, i)
		result[player_name] = int(round(total))
	return result


# ---------------------------------------------------------------------------
# PROGRESS — how close a pair is to synergy. Returns "matches_together /
# threshold" as a float in [0, 1]. Useful for UI progress bars.
# ---------------------------------------------------------------------------
func progress(name_a: String, name_b: String) -> float:
	var n: int = matches_together(name_a, name_b)
	return clampf(float(n) / float(Balance.match_balance.synergy_threshold), 0.0, 1.0)


# ---------------------------------------------------------------------------
# CLEAN FOR ROSTER — remove pair entries for any player no longer in the
# roster. Call this after trades/firings to prevent the dictionary from
# growing forever.
# ---------------------------------------------------------------------------
func clean_for_roster(roster: Array) -> void:
	var valid_names: Dictionary = {}
	for p in roster:
		valid_names[p.player_name] = true
	var to_remove: Array = []
	for key in _counts.keys():
		var parts: PackedStringArray = key.split("||")
		if parts.size() != 2:
			to_remove.append(key)
			continue
		if not valid_names.has(parts[0]) or not valid_names.has(parts[1]):
			to_remove.append(key)
	for key in to_remove:
		_counts.erase(key)


# ---------------------------------------------------------------------------
# PRIVATE
# ---------------------------------------------------------------------------
static func _pair_key(name_a: String, name_b: String) -> String:
	if name_a <= name_b:
		return name_a + "||" + name_b
	return name_b + "||" + name_a
