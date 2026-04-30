# scripts/systems/Simulation.gd
# ============================================================
# MATCH SIMULATION — pure functions, no side effects.
# Takes a Player's current stats and returns a match score + breakdown.
#
# UNIFIED TRAIT SYSTEM:
#   Every player has ONE primary_trait from the set:
#   aggressive | tactical | focused | clutch | resilient | volatile
#
#   Each trait affects BOTH simulation (here) AND matchup (TraitMatchup.gd).
#
# PERFORMANCE FORMULA (order of application):
#   1. Skill         → base score
#   2. Stamina drag  → continuous multiplier (always active)
#   3. Focus         → controls score variance (higher focus = smaller swing)
#   4. Trait effects → simulation bonuses / variance modifiers
#   5. Study buff    → flat skill bump if study charges remain
#   6. Patch buff/nerf → multiplicative on per-player score
#   7. Counter pressure → multiplicative on team score (Strategy > Power)
#   8. Synergy       → flat per-player bonus for synergized pairs
#
# HIGH SKILL ALONE DOES NOT GUARANTEE VICTORY.
# A 90-skill player at 10 stamina will underperform a 60-skill fresh player.
# A 90-skill team that gets fully countered will play at 50% effectiveness.
#
# TRAIT SIMULATION EFFECTS:
#   aggressive → variance +8; stamina drains faster (lower floor)
#   tactical   → variance -4; no floor modifier
#   focused    → variance -6; +5 on important matches
#   clutch     → +12 on important; small variance in normal games
#   resilient  → stamina floor raised; no variance modifier
#   volatile   → variance +14; big swing either way
#
# TO TWEAK stamina drag      → edit _stamina_multiplier()
# TO TWEAK focus variance    → edit the rand_range_val section in simulate_player()
# TO TWEAK trait bonuses     → edit the match block in simulate_player()
# TO TWEAK counter pressure  → edit Tuning.COUNTER_PENALTY_MAX / COUNTER_BONUS_MAX
# TO TWEAK patch swing       → edit Tuning.PATCH_BUFF_PCT / PATCH_NERF_PCT
# TO TWEAK synergy           → edit Tuning.SYNERGY_BONUS_PER_PAIR / DIMINISH
# ============================================================
class_name Simulation
extends RefCounted


# ---------------------------------------------------------------------------
# SIMULATE PLAYER — computes one player's contribution score for a match.
#
# Returns { "score": int, "breakdown": Array, "trait_label": String,
#           "study_consumed": int, "patch_mult": float }
# breakdown entries: { "reason": String, "delta": int }
#
# is_important: true for important matches, tournaments, and solos.
#   Amplifies clutch and focused trait effects.
# absolute_week: used for patch lookup. -1 means "no patch (legacy / tests)".
# ---------------------------------------------------------------------------
static func simulate_player(player: Player, is_important: bool, absolute_week: int = -1) -> Dictionary:
	var breakdown: Array = []

	# --- STEP 1: Skill base ---
	var score: float = player.skill

	# --- STEP 2: Stamina drag (continuous, always active) ---
	var minor_traits: Array = player.get_minor_traits()
	var primary_trait: String = player.primary_trait
	var stamina_mult: float = _stamina_multiplier(player.stamina, minor_traits, primary_trait)
	var drag_delta: int     = int(player.skill * stamina_mult) - player.skill
	if drag_delta < 0:
		score += drag_delta
		breakdown.append({ "reason": "Tired legs", "delta": drag_delta })

	# --- STEP 3: Focus variance ---
	# High focus → tight performance. Low focus → wide variance.
	# Trait modifies the variance range on top of focus.
	var focus_factor: float = player.focus / 100.0
	var rand_range_val: int = int(lerp(22.0, 4.0, focus_factor))

	match primary_trait:
		"focused":    rand_range_val = max(rand_range_val - 6, 2)   # precision: tightest variance
		"tactical":   rand_range_val = max(rand_range_val - 4, 2)   # structured: steady
		"aggressive": rand_range_val += 8                            # explosive: wide swings
		"volatile":   rand_range_val += 14                           # chaos: biggest swings
		# clutch, resilient: no variance modifier — their effect is situational/stamina

	var focus_roll: int = randi_range(-rand_range_val, rand_range_val)
	score += focus_roll
	if focus_roll > 0:
		breakdown.append({ "reason": "Good read", "delta": focus_roll })
	elif focus_roll < 0:
		breakdown.append({ "reason": "Off read", "delta": focus_roll })

	# --- STEP 4: Primary trait effects ---
	var trait_delta: int    = 0
	var trait_label: String = ""

	match primary_trait:
		"clutch":
			# Spikes on important matches. Small noise in normal games.
			if is_important:
				trait_delta = 12
				trait_label = "⚡ Clutch moment"
			else:
				trait_delta = randi_range(-3, 3)
				trait_label = "" if trait_delta == 0 else "⚡ Clutch"
		"focused":
			# Small but consistent bonus on important matches (precision under pressure).
			if is_important:
				trait_delta = 5
				trait_label = "🎯 Locked in"
		"volatile":
			# Extra spike chance — coin-flip direction, high magnitude.
			var spike: int = randi_range(0, 1)
			if spike == 1:
				trait_delta = randi_range(5, 12)
				trait_label = "🌀 Hot streak"
			else:
				trait_delta = randi_range(-12, -5)
				trait_label = "🌀 Off day"
		# aggressive, tactical, resilient: their effects are stamina/variance-based (Steps 2–3).
		"aggressive", "tactical", "resilient":
			pass

	if trait_delta != 0:
		score += trait_delta
		breakdown.append({ "reason": trait_label, "delta": trait_delta })

	# --- STEP 5: Study buff (consumes charges) ---
	# A studying player walks into the match having read the meta. Charges
	# are SET ASIDE here so the team-level counter math can boost their
	# contribution; the flat skill bump is applied immediately.
	var study_consumed: int = 0
	if player.study_charges > 0:
		study_consumed = player.study_charges
		var flat: int = Tuning.STUDY_FLAT_SKILL_BONUS * study_consumed
		score += flat
		breakdown.append({
			"reason": "📚 Studied the meta (×%d)" % study_consumed,
			"delta":  flat,
		})

	# --- STEP 6: Meta patch buff/nerf ---
	# Multiplicative on the per-player score.
	var patch_mult: float = 1.0
	if absolute_week > 0:
		patch_mult = MetaPatch.multiplier_for(primary_trait, absolute_week)
		if patch_mult > 1.0:
			var before: float = score
			score = score * patch_mult
			breakdown.append({
				"reason": "🔥 Patch buff (+%d%%)" % int(round((patch_mult - 1.0) * 100.0)),
				"delta":  int(round(score - before)),
			})
		elif patch_mult < 1.0:
			var before2: float = score
			score = score * patch_mult
			breakdown.append({
				"reason": "❄ Patch nerf (-%d%%)" % int(round((1.0 - patch_mult) * 100.0)),
				"delta":  int(round(score - before2)),
			})

	return {
		"score":           max(int(score), 0),
		"breakdown":       breakdown,
		"trait_label":     trait_label,
		"study_consumed":  study_consumed,
		"patch_mult":      patch_mult,
	}


# ---------------------------------------------------------------------------
# SIMULATE TEAM — runs simulate_player for all players, sums scores.
#
# This is also where the multiplicative TEAM-LEVEL effects land:
#   • Counter pressure (per Tuning.COUNTER_PENALTY_MAX / COUNTER_BONUS_MAX)
#   • Synergy (flat per-player bonus from synergized pairs)
#
# Counter pressure is calculated from per-player matchup vs. the opponent
# trait slots, weighted by study charges (a studied player's counter math
# carries more weight). Situation coverage applies a smaller bonus per hit.
#
# Returns:
#   {
#     won, team_score, opponent_score, players,
#     counter_ratio, counter_mult, situation_bonus, study_consumed_total
#   }
# ---------------------------------------------------------------------------
static func simulate_team(
	players: Array[Player],
	is_important: bool,
	opponent_score: int,
	opponent_traits: Array = [],
	situations: Array = [],
	synergy: Synergy = null,
	absolute_week: int = -1
) -> Dictionary:
	var player_results: Array = []
	var raw_team_score: int = 0
	var study_consumed_total: int = 0
	var per_player_study: Dictionary = {}   # name → charges consumed

	for player: Player in players:
		var sim: Dictionary = simulate_player(player, is_important, absolute_week)
		var score: int      = sim["score"]
		var flavor_data: Dictionary = MatchFlavorGenerator.generate(
			player, score, is_important, sim["trait_label"]
		)

		raw_team_score += score
		study_consumed_total += sim["study_consumed"]
		per_player_study[player.player_name] = sim["study_consumed"]

		player_results.append({
			"player":         player,
			"score":          score,
			"raw_score":      score,
			"label":          flavor_data["label"],
			"flavor":         flavor_data["flavor"],
			"trait_trigger":  flavor_data["trait_trigger"],
			"breakdown":      sim["breakdown"],
			"study_consumed": sim["study_consumed"],
			"patch_mult":     sim["patch_mult"],
		})

	# --- Counter pressure (multiplicative on team score) ---
	# We compute a counter_ratio in [-1, 1] per player vs. opponent traits,
	# average across players (weighted by study charges), and convert to a
	# multiplier per Tuning.COUNTER_PENALTY_MAX / COUNTER_BONUS_MAX.
	var counter_data: Dictionary = _calc_counter_ratio(
		players, opponent_traits, per_player_study
	)
	var counter_ratio: float = counter_data["ratio"]
	var counter_mult:  float = _ratio_to_multiplier(counter_ratio)
	var team_score_after_counter: int = int(round(float(raw_team_score) * counter_mult))

	# --- Situation coverage bonus (small multiplicative on top) ---
	var coverage_hits: int = _count_coverage_hits(players, situations)
	var coverage_mult: float = 1.0 + Tuning.SITUATION_COVERAGE_BONUS_PER_HIT * float(coverage_hits)
	var team_score_after_coverage: int = int(round(float(team_score_after_counter) * coverage_mult))

	# --- Synergy (flat per-player bonus) ---
	var synergy_bonus_total: int = 0
	var synergy_per_player: Dictionary = {}
	if synergy != null:
		synergy_per_player = synergy.score_bonus_per_player(players)
		for entry in player_results:
			var name: String = entry["player"].player_name
			var bonus: int = synergy_per_player.get(name, 0)
			if bonus > 0:
				entry["score"] += bonus
				entry["synergy_bonus"] = bonus
				entry["breakdown"].append({
					"reason": "🤝 Synergy",
					"delta":  bonus,
				})
				synergy_bonus_total += bonus

	# Distribute the counter+coverage swing back into per-player scores so
	# the resolution screen displays consistent numbers. We do this
	# proportionally to each player's raw share.
	var team_score: int = team_score_after_coverage + synergy_bonus_total
	if raw_team_score > 0 and (counter_mult != 1.0 or coverage_mult != 1.0):
		var combined_team_mult: float = counter_mult * coverage_mult
		for entry in player_results:
			var raw: int = entry["raw_score"]
			var adjusted: int = int(round(float(raw) * combined_team_mult))
			# preserve any synergy bonus that was already added to entry["score"]
			var synergy_bonus_for_player: int = entry.get("synergy_bonus", 0)
			entry["score"] = max(adjusted + synergy_bonus_for_player, 0)
		# Re-sum to avoid rounding drift between sum-of-parts and team total.
		var resum: int = 0
		for entry in player_results:
			resum += entry["score"]
		team_score = resum

	return {
		"won":                   team_score >= opponent_score,
		"team_score":            team_score,
		"raw_team_score":        raw_team_score,
		"opponent_score":        opponent_score,
		"players":               player_results,
		"counter_ratio":         counter_ratio,
		"counter_mult":          counter_mult,
		"coverage_hits":         coverage_hits,
		"coverage_mult":         coverage_mult,
		"synergy_bonus_total":   synergy_bonus_total,
		"synergy_per_player":    synergy_per_player,
		"study_consumed_total":  study_consumed_total,
	}


# ---------------------------------------------------------------------------
# COUNTER RATIO — per-player wins/losses vs opponent traits, averaged.
#
# For each player, against each opponent trait slot:
#   +1 contribution if player's trait counters opponent's trait
#   -1 contribution if opponent's trait counters player's trait
#    0 otherwise (volatile or neutral)
#
# Per-player ratio = contribution / opponent_slot_count, clamped to [-1, 1].
# Study charges WEIGHT a player's contribution: studied players' counter
# math counts more (they came in prepared).
#
# Final ratio = weighted average across active players, in [-1, 1].
# ---------------------------------------------------------------------------
static func _calc_counter_ratio(
	players: Array,
	opponent_traits: Array,
	per_player_study: Dictionary
) -> Dictionary:
	if opponent_traits.is_empty() or players.is_empty():
		return { "ratio": 0.0 }

	var weighted_sum: float = 0.0
	var total_weight: float = 0.0

	for p in players:
		var pt: String = p.primary_trait
		var contribution: int = 0
		for ot in opponent_traits:
			if TraitMatchup.WINS_AGAINST.has(pt) and ot in TraitMatchup.WINS_AGAINST[pt]:
				contribution += 1
			elif TraitMatchup.LOSES_AGAINST.has(pt) and ot in TraitMatchup.LOSES_AGAINST[pt]:
				contribution -= 1
		var per_player_ratio: float = clampf(
			float(contribution) / float(opponent_traits.size()), -1.0, 1.0
		)
		# Study weight: each consumed charge boosts this player's contribution.
		var study: int = per_player_study.get(p.player_name, 0)
		var weight: float = 1.0 + Tuning.STUDY_COUNTER_BONUS_PER_CHARGE * float(study)
		weighted_sum += per_player_ratio * weight
		total_weight += weight

	if total_weight <= 0.0:
		return { "ratio": 0.0 }
	return { "ratio": clampf(weighted_sum / total_weight, -1.0, 1.0) }


# ---------------------------------------------------------------------------
# RATIO → MULTIPLIER — convert a [-1, 1] counter ratio into a team-score
# multiplier using the asymmetric Tuning constants.
#   ratio  0   → 1.0
#   ratio +1   → 1 + COUNTER_BONUS_MAX
#   ratio -1   → 1 - COUNTER_PENALTY_MAX
# ---------------------------------------------------------------------------
static func _ratio_to_multiplier(ratio: float) -> float:
	if ratio >= 0.0:
		return 1.0 + Tuning.COUNTER_BONUS_MAX * ratio
	return 1.0 + Tuning.COUNTER_PENALTY_MAX * ratio   # ratio is negative → subtraction


# ---------------------------------------------------------------------------
# COVERAGE HITS — how many situation phases are covered by at least one
# active player's primary trait.
# ---------------------------------------------------------------------------
static func _count_coverage_hits(players: Array, situations: Array) -> int:
	if situations.is_empty():
		return 0
	var team_traits: Dictionary = {}
	for p in players:
		team_traits[p.primary_trait] = true
	var hits: int = 0
	for sit in situations:
		var favored: String = TraitMatchup.SITUATION_FAVORS.get(sit, "")
		if favored != "" and team_traits.has(favored):
			hits += 1
	return hits


# ---------------------------------------------------------------------------
# STAMINA MULTIPLIER — continuous stamina drag on performance.
#
# Returns a multiplier applied to base skill:
#   1.0 at full stamina  → no drag
#   ~0.70 at zero stamina → 30% reduction (base)
#
# aggressive lowers the floor (burns harder, drains faster).
# resilient raises the floor (endurance — holds together under fatigue).
# fragile minor trait further lowers; resilient minor trait further raises.
# ---------------------------------------------------------------------------
static func _stamina_multiplier(stamina: int, minor_traits: Array, primary_trait: String) -> float:
	const BASE_FLOOR:      float = 0.70
	const FRAGILE_FLOOR:   float = 0.60
	const RESILIENT_FLOOR: float = 0.80

	var floor_val: float = BASE_FLOOR

	# Primary trait modifier
	if primary_trait == "aggressive":
		floor_val = 0.65   # burns hot, pays a stamina cost
	elif primary_trait == "resilient":
		floor_val = 0.80   # endurance: holds form under fatigue

	# Minor trait override (takes priority over primary)
	if "fragile"   in minor_traits: floor_val = FRAGILE_FLOOR
	if "resilient" in minor_traits: floor_val = RESILIENT_FLOOR

	return lerp(floor_val, 1.0, clampf(stamina / 100.0, 0.0, 1.0))
