class_name GameText
extends RefCounted

# Single source of truth for all display text, icons, and labels.
# TO ADD a new trait     → add to TRAIT_ICONS, TRAIT_NAMES, FLAVOR
# TO ADD a new situation → add to SITUATION_NAMES (favors live in TraitMatchup)
# TO ADD a new match type → add to MATCH_TYPE


# ---------------------------------------------------------------------------
# PERFORMANCE LABELS — indexed by score bucket (0=struggled, 1=solid, 2=carried)
# ---------------------------------------------------------------------------
const PERF_LABELS: Array[String] = [
	"😬 Struggled",
	"✅ Solid",
	"🔥 Carried",
]


# ---------------------------------------------------------------------------
# DIFFICULTY — display name for Calendar difficulty labels
# ---------------------------------------------------------------------------
const DIFFICULTY: Dictionary = {
	"weak":     "Easy",
	"average":  "Medium",
	"strong":   "Hard",
	"dominant": "Very Hard",
}


# ---------------------------------------------------------------------------
# MATCH TYPE — display name for Calendar type constants
# ---------------------------------------------------------------------------
const MATCH_TYPE: Dictionary = {
	"normal":     "Regular Match",
	"important":  "⭐ Important Match",
	"tournament": "🏆 Tournament",
	"solo":       "👤 Solo Match",
}


# ---------------------------------------------------------------------------
# WIN ESTIMATE — shown pre-match on hub
# ---------------------------------------------------------------------------
const ESTIMATE_FAVORED:  String = "🟢 You are favored"
const ESTIMATE_EVEN:     String = "🟡 Even match"
const ESTIMATE_UNDERDOG: String = "🔴 You are the underdog"


# ---------------------------------------------------------------------------
# MATCHUP VERDICT — shown pre-match on hub below prognosis
# ---------------------------------------------------------------------------
const MATCHUP_STRONG:  String = "✅ Good counter"
const MATCHUP_NEUTRAL: String = "🟡 Even matchup"
const MATCHUP_WEAK:    String = "⚠️ Bad matchup"

static func matchup_verdict(modifier: float) -> String:
	if modifier >= 8.0:   return MATCHUP_STRONG
	elif modifier <= -8.0: return MATCHUP_WEAK
	else:                  return MATCHUP_NEUTRAL


# ---------------------------------------------------------------------------
# TRAIT DISPLAY — icon + name for both performance traits and match traits.
# Icon format: "EMOJI  " (two trailing spaces for Label spacing).
# ---------------------------------------------------------------------------
const TRAIT_ICONS: Dictionary = {
	# Performance traits (Player.primary_trait)
	"clutch":     "⚡  ",
	"choker":     "😰  ",
	"grinder":    "⚙️  ",
	"lazy":       "💤  ",
	"consistent": "🎯  ",
	"volatile":   "🌀  ",
	"none":       "",
	# Match traits (TraitMatchup — opponent panel, prognosis)
	"aggressive": "🗡️  ",
	"tactical":   "🧠  ",
	"focused":    "🎯  ",
	"resilient":  "🛡️  ",
}

const TRAIT_NAMES: Dictionary = {
	# Performance traits
	"clutch":     "Clutch",
	"choker":     "Choker",
	"grinder":    "Grinder",
	"lazy":       "Lazy",
	"consistent": "Consistent",
	"volatile":   "Volatile",
	"none":       "Balanced",
	# Match traits
	"aggressive": "Aggressive",
	"tactical":   "Tactical",
	"focused":    "Focused",
	"resilient":  "Resilient",
}

static func trait_label(trait_key: String) -> String:
	return TRAIT_ICONS.get(trait_key, "") + TRAIT_NAMES.get(trait_key, trait_key.capitalize())


# ---------------------------------------------------------------------------
# SITUATION NAMES — short display names (favors live in TraitMatchup)
# ---------------------------------------------------------------------------
const SITUATION_NAMES: Dictionary = {
	"early_pressure":  "Early Pressure",
	"control_phase":   "Control Phase",
	"precision_phase": "Precision Phase",
	"clutch_moment":   "Clutch Moment",
	"endurance_phase": "Endurance Phase",
}


# ---------------------------------------------------------------------------
# FLAVOR TEXT — picked by MatchFlavorGenerator per trait + situation key.
# Keys: "high", "mid", "low", "important_high", "important_low", etc.
# TO ADD a trait → add a new dict here with at least "high", "mid", "low".
# ---------------------------------------------------------------------------
const FLAVOR: Dictionary = {
	"clutch": {
		"important_high":        ["Delivered under pressure.", "Rose to the occasion."],
		"important_high_streak": ["Delivered under pressure — again.", "Does it every time."],
		"important_low":         ["Couldn't step up when it mattered.", "Disappeared when the stakes were highest."],
		"important_low_streak":  ["Froze up when it mattered most.", "The pressure is getting to this one."],
		"high":                  ["Carried key moments.", "Stepped up big today."],
		"low":                   ["Off day — unusual for a player like this.", "Unusually quiet performance."],
		"mid":                   ["Kept things steady.", "Did the job."],
	},
	"choker": {
		"important_low":         ["Collapsed under pressure.", "Fell apart at the worst time."],
		"important_low_streak":  ["Collapsed again under pressure.", "Cannot handle the big moments."],
		"important_high":        ["Held it together — surprising everyone.", "Managed to push through."],
		"normal_high":           ["Looked more comfortable than usual.", "Thriving without the pressure."],
		"low":                   ["Struggled to keep up.", "Not a great showing."],
		"mid":                   ["Contributed quietly.", "Stayed out of trouble."],
	},
	"grinder": {
		"high":        ["Hard work paid off.", "All those hours in the lab showing."],
		"high_streak": ["All those hours paid off.", "Grinding is paying dividends."],
		"mid":         ["Reliable as always.", "Consistent output — no surprises."],
		"low":         ["Even grinding couldn't save today.", "Bad day at the office."],
	},
	"lazy": {
		"low": ["Looked disinterested from the start.", "Coasting — needs a spark."],
		"high": ["Turned it on when it counted.", "Explosive when motivated."],
		"mid":  ["Managed their energy carefully.", "Didn't overextend."],
	},
	"consistent": {
		"high": ["Delivered exactly what was asked.", "No drama — just results."],
		"mid":  ["Steady as always.", "Reliable in every phase."],
		"low":  ["Off their usual standard.", "Uncharacteristically sloppy."],
	},
	"volatile": {
		"high":        ["Unplayable today.", "On one of those peaks — unstoppable."],
		"high_streak": ["Back-to-back peaks — rare for this player.", "Running hot."],
		"low":         ["One of those invisible days.", "Completely off — nothing working."],
		"low_streak":  ["Cold streak continuing.", "Can't find the form."],
		"mid":         ["Somewhere in between today.", "Not their best, not their worst."],
	},
	"none": {
		"high": ["Strong outing.", "Came through when needed."],
		"mid":  ["Solid contribution.", "Did their part."],
		"low":  ["Quiet match.", "Couldn't make an impact."],
	},
}

static func flavor(trait_key: String, situation_key: String) -> String:
	if not FLAVOR.has(trait_key):
		trait_key = "none"
	var pool: Dictionary = FLAVOR[trait_key]
	var base_key: String = situation_key.replace("_streak", "")
	var lines: Array
	if pool.has(situation_key):        lines = pool[situation_key]
	elif pool.has(base_key):           lines = pool[base_key]
	elif pool.has("mid"):              lines = pool["mid"]
	else:                              return ""
	if lines.is_empty():               return ""
	return lines[randi() % lines.size()]


# ---------------------------------------------------------------------------
# PLAYER VOICE — one-line coaching sentence shown on hub cards.
# ---------------------------------------------------------------------------
static func player_voice(player: Player, stamina_key: String, morale_key: String, match_type: String) -> String:
	var notes: Array = []
	match stamina_key:
		"exhausted": notes.append("Running on fumes")
		"tired":     notes.append("Showing fatigue")
	match morale_key:
		"confident": notes.append("in great spirits")
		"shaky":     notes.append("confidence is low")
	if player.burnout >= 3:
		notes.append("burnout warning")
	if player.form_label == "🔥 In Form":
		notes.append("in form")
	elif player.form_label == "📉 Struggling":
		notes.append("on a rough run")
	if player.primary_trait == "clutch" and match_type in ["important", "tournament"]:
		notes.append("this is their moment")
	elif player.primary_trait == "choker" and match_type in ["important", "tournament"]:
		notes.append("watch the nerves")
	if notes.is_empty():
		return ""
	return notes[0].capitalize() + (". " + notes[1].capitalize() if notes.size() > 1 else ".")
