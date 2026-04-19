# scripts/data/GameText.gd
# Single source of truth for ALL user-facing strings.
# Add new flavor lines here — logic picks them automatically.
# No logic here. No UI references. Pure data.
class_name GameText
extends RefCounted


# --- Action descriptions (shown in UI tooltips / pre-match panel) ---
const ACTIONS: Dictionary = {
	"train": {
		"label":       "⚡ Train",
		"description": "Improves skill. Costs stamina.",
	},
	"rest": {
		"label":       "💤 Rest",
		"description": "Recovers stamina and morale. No match.",
	},
	"scrim": {
		"label":       "🎮 Scrim",
		"description": "Practice matches. Improves focus. No stamina cost.",
	},
}


# --- Performance labels (indexed by tier: 0=low, 1=mid, 2=high) ---
const PERF_LABELS: Array[String] = [
	"😬 Struggled",
	"✅ Solid",
	"🔥 Carried",
]


# --- Player condition labels ---
const CONDITIONS: Dictionary = {
	"exhausted":  "😴 Exhausted",
	"tired":      "😐 Tired",
	"confident":  "🔥 Confident",
	"ready":      "✅ Ready",
}


# --- Opponent strength labels ---
const OPPONENT_STRENGTH: Dictionary = {
	"weak":     "Weak",
	"average":  "Average",
	"strong":   "Strong",
	"dominant": "Dominant",
}


# --- Streak labels ---
const STREAK_ON_ROLL:    String = "🔥 on a roll"
const STREAK_COLD:       String = "❄️ cold streak"
const STREAK_WIN_PREFIX: String = "🔥 %d-win streak"
const STREAK_LOSS_PREFIX: String = "❄️ %d-loss streak"


# --- Match outcome labels ---
const OUTCOME_VICTORY:     String = "✅  VICTORY"
const OUTCOME_DEFEAT:      String = "❌  DEFEAT"
const OUTCOME_CLOSE:       String = " — so close!"
const OUTCOME_REST_WEEK:   String = "💤  Rest Week"
const OUTCOME_REST_DESC:   String = "No match this week. Players recovered."
const MATCH_IMPORTANT:     String = "🏆 IMPORTANT MATCH"
const MATCH_SCORE_LINE:    String = "Your team  %d pts   vs   Enemy  %d pts"
const MATCH_OPP_PREFIX:    String = "Opponent: %s"

# --- Match type labels (Calendar) ---
const MATCH_TYPE: Dictionary = {
	"normal":     "Regular Match",
	"important":  "⭐ Important Match",
	"tournament": "🏆 Tournament",
}


# --- Micro reward templates ---
const REWARD_SKILL:   String = "%s improved (Skill +%d)"
const REWARD_STAMINA: String = "%s recovered well (Stamina +%d)"
const REWARD_PREFIX:  String = "📈 "


# --- MVP badge ---
const MVP_BADGE: String = "⭐ MVP"


# --- Flavor text pools ---
# Each entry is an Array so you can add more lines freely.
# The generator picks based on trait + situation.

const FLAVOR: Dictionary = {

	"clutch": {
		"important_high":      ["Delivered under pressure.", "Rose to the occasion."],
		"important_high_streak": ["Delivered under pressure — again.", "Does it every time."],
		"important_low":       ["Couldn't step up when it mattered.", "Disappeared when the stakes were highest."],
		"important_low_streak":  ["Froze up when it mattered most.", "The pressure is getting to them."],
		"high":                ["Carried key moments.", "Stepped up big today."],
		"low":                 ["Off day — not like them.", "Unusually quiet performance."],
		"mid":                 ["Kept things steady.", "Did the job."],
	},

	"choker": {
		"important_low":       ["Collapsed under pressure.", "Fell apart at the worst time."],
		"important_low_streak":  ["Collapsed again under pressure.", "Can't handle the big moments."],
		"important_high":      ["Held it together — surprising everyone.", "Managed to push through."],
		"normal_high":         ["Looked more comfortable than usual.", "Thriving without the pressure."],
		"low":                 ["Struggled to keep up.", "Not their best showing."],
		"mid":                 ["Contributed quietly.", "Stayed out of trouble."],
	},

	"grinder": {
		"high":                ["Hard work paid off.", "All those hours in the lab showing."],
		"high_streak":         ["All those hours paid off.", "Grinding is paying dividends."],
		"mid":                 ["Reliable as always.", "Consistent output — no surprises."],
		"low":                 ["Even grinding couldn't save today.", "Bad day at the office."],
	},

	"lazy": {
		"low":                 ["Looked unprepared.", "Half-hearted effort today."],
		"low_streak":          ["Looked unprepared — as usual.", "The laziness is catching up."],
		"high":                ["Seemed refreshed — and it showed.", "When they try, they deliver."],
		"mid":                 ["Did just enough.", "Got away with it today."],
	},

	"consistent": {
		"high":                ["Flawless — exactly what you'd expect.", "Textbook performance."],
		"low":                 ["Even the reliable ones have bad days.", "Unusually off today."],
		"mid":                 ["Steady and dependable as expected.", "Exactly what was needed."],
	},

	"volatile": {
		"high":                ["Chaos theory in their favour today.", "Completely unhinged — in a good way."],
		"low":                 ["Completely off the rails.", "High risk, high reward — today was the risk."],
		"mid":                 ["You never quite know with them.", "Unpredictable performance today."],
	},

	"none": {
		"high":                ["Had a great match.", "Strong showing today."],
		"low":                 ["Had a rough match.", "Struggled today."],
		"mid":                 ["Played a steady game.", "Decent enough."],
	},
}


# Helper: pick a random string from an array.
static func pick(arr: Array) -> String:
	if arr.is_empty(): return ""
	return arr[randi() % arr.size()]


# Helper: get flavor lines for a given trait + situation key.
static func flavor(trait_key: String, situation: String) -> String:
	var trait_data: Dictionary = FLAVOR.get(trait_key, FLAVOR["none"])
	var lines: Array = trait_data.get(situation, [])
	if lines.is_empty():
		# Fallback to mid
		lines = trait_data.get("mid", ["Played a steady game."])
	return pick(lines)
