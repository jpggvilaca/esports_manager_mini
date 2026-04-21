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


# --- Preparation phase framing ---
const PREP_PHASE_HEADER:   String = "Prepare for Match"
const PREP_PHASE_SUBTITLE: String = "Choose how each player prepares this week."
const PREP_ACTION_LABEL:   String = "Prepare:"

# --- Week context lines (shown below the week/match-type header) ---
const WEEK_CONTEXT: Dictionary = {
	"normal":     "Another week of practice and competition.",
	"important":  "A crucial match is coming up. Preparation matters.",
	"tournament": "Tournament week. Every decision counts.",
	"solo":       "One player carries the team. Choose wisely.",
}

# --- Week + match type header format ---
const WEEK_HEADER: String = "Week %d — %s"  # e.g. "Week 4 — IMPORTANT MATCH"

# --- Match type display names (uppercase, for the week header) ---
const MATCH_TYPE_UPPER: Dictionary = {
	"normal":     "REGULAR MATCH",
	"important":  "IMPORTANT MATCH",
	"tournament": "TOURNAMENT",
	"solo":       "SOLO MATCH",
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


# --- Stamina condition labels (readable, shown in pre-match) ---
const STAMINA_CONDITION: Dictionary = {
	"fresh":     "Fresh",
	"ok":        "OK",
	"tired":     "Tired",
	"exhausted": "Exhausted",
}

# --- Morale condition labels ---
const MORALE_CONDITION: Dictionary = {
	"confident": "Confident",
	"shaky":     "Shaky",
	"neutral":   "",   # don't show anything if unremarkable
}

# --- Opponent difficulty labels (maps calendar label → display) ---
const DIFFICULTY: Dictionary = {
	"weak":     "Easy",
	"average":  "Medium",
	"strong":   "Hard",
	"dominant": "Very Hard",
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
const GAME_OVER_NOTICE:    String = "(Final season reached)"
const GAME_OVER_BTN:       String = "Season limit reached"

# --- Match type labels (Calendar) ---
const MATCH_TYPE: Dictionary = {
	"normal":     "Regular Match",
	"important":  "⭐ Important Match",
	"tournament": "🏆 Tournament",
	"solo":       "👤 Solo Match",
}

# --- Solo match strings ---
const SOLO_PICK_PROMPT:  String = "Choose your solo player:"
const SOLO_WIN_FLAVOR:   Array  = ["Carried the match alone.", "Stepped up when it counted.", "Proved they don't need the team."]
const SOLO_LOSS_FLAVOR:  Array  = ["Couldn't handle it alone.", "The pressure was too much solo.", "Needed backup that wasn't there."]
const ADVANCE_BTN_SOLO:  String = "⚡  Advance Week  — 👤 Solo"

# --- Tournament strings ---
const TOURNAMENT_ROUND:       String = "Round %d"
const TOURNAMENT_WIN_ALL:     String = "Dominated the entire tournament."
const TOURNAMENT_WIN_CLOSE:   String = "Scraped through — but made it."
const TOURNAMENT_LOSS_ROUND:  String = "Eliminated in Round %d."
const TOURNAMENT_ROUNDS_WON:  String = "Won %d / %d rounds"


# --- Micro reward templates (kept for future use) ---
const REWARD_PREFIX: String = "📈 "


# --- MVP badge ---
const MVP_BADGE:   String = "⭐ MVP"
const WORST_BADGE: String = "💔 Struggled"  # worst performer badge in results

# --- Pre-match risk warnings ---
const WARN_TIRED_PLAYER: String = "⚠️ Tired players"
const WARN_IMPORTANT:    String = "Stakes are high — don't waste this"
const WARN_SOLO:         String = "👤 Solo match — pick wisely"

# --- Pre-match win estimate ---
const ESTIMATE_FAVORED:  String = "🟢 You are favored"
const ESTIMATE_EVEN:     String = "🟡 Even match"
const ESTIMATE_UNDERDOG: String = "🔴 You are the underdog"

# --- Morale delta display (shown in conditions line) ---
const MORALE_GAIN: String = "(+%d morale)"
const MORALE_LOSS: String = "(%d morale)"  # value is negative, %d prints it with sign
const ADVANCE_BTN_NORMAL:      String = "⚡  Advance Week"
const ADVANCE_BTN_IMPORTANT:   String = "⚡  Advance Week  — ⭐ Important"
const ADVANCE_BTN_TOURNAMENT:  String = "⚡  Advance Week  — 🏆 Tournament"

# --- XP & Level ---
const XP_GAINED:    String = "+%d XP"
const LEVEL_UP:     String = "⬆ Level %d!"
const LEVEL_UP_STATS: String = "Skill +%d%s"  # %s = "  Focus +1" or ""
const LEVEL_BADGE:  String = "Lv.%d"


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
