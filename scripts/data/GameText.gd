class_name GameText
extends RefCounted

# Single source of truth for all display text, icons, and labels.
#
# UNIFIED TRAIT SYSTEM — 6 traits, each with ONE entry here.
#   aggressive | tactical | focused | clutch | resilient | volatile
#
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
	if modifier >= 8.0:    return MATCHUP_STRONG
	elif modifier <= -8.0: return MATCHUP_WEAK
	else:                  return MATCHUP_NEUTRAL


# ---------------------------------------------------------------------------
# TRAIT DISPLAY — icon + name for the 6 unified traits.
# Icon format: "EMOJI  " (two trailing spaces for Label spacing).
# ---------------------------------------------------------------------------
const TRAIT_ICONS: Dictionary = {
	"aggressive": "🗡️  ",
	"tactical":   "🧠  ",
	"focused":    "🎯  ",
	"clutch":     "⚡  ",
	"resilient":  "🛡️  ",
	"volatile":   "🌀  ",
}

const TRAIT_NAMES: Dictionary = {
	"aggressive": "Aggressive",
	"tactical":   "Tactical",
	"focused":    "Focused",
	"clutch":     "Clutch",
	"resilient":  "Resilient",
	"volatile":   "Volatile",
}

# Short tooltip shown in UI for each trait (simulation + matchup in one line).
const TRAIT_TOOLTIPS: Dictionary = {
	"aggressive": "High variance. Counters Focused. Strong in Early phase.",
	"tactical":   "Stable output. Counters Aggressive. Strong in Mid phase.",
	"focused":    "Tight variance. Counters Tactical & Clutch. Bonus on big matches.",
	"clutch":     "+12 on important matches. Counters Resilient. Strong in Late phase.",
	"resilient":  "Resists stamina drain. Counters Aggressive & Clutch.",
	"volatile":   "Huge swings — can spike or crash. Neutral counter relationship.",
}

# Counter description shown in pre-match screen.
const TRAIT_COUNTERS: Dictionary = {
	"aggressive": "Counters: Focused\nWeak to: Tactical, Resilient",
	"tactical":   "Counters: Aggressive\nWeak to: Focused",
	"focused":    "Counters: Tactical, Clutch\nWeak to: Aggressive",
	"clutch":     "Counters: Resilient\nWeak to: Focused, Aggressive",
	"resilient":  "Counters: Aggressive, Clutch\nWeak to: Clutch",
	"volatile":   "No reliable counter relationship (wild card)",
}

static func trait_label(trait_key: String) -> String:
	return TRAIT_ICONS.get(trait_key, "") + TRAIT_NAMES.get(trait_key, trait_key.capitalize())

static func trait_tooltip(trait_key: String) -> String:
	return TRAIT_TOOLTIPS.get(trait_key, "")


# ---------------------------------------------------------------------------
# SITUATION NAMES — short display names for the 3 match phases
# ---------------------------------------------------------------------------
const SITUATION_NAMES: Dictionary = {
	"early": "Early Phase",
	"mid":   "Mid Phase",
	"late":  "Late Phase",
}


# ---------------------------------------------------------------------------
# FLAVOR TEXT — picked by MatchFlavorGenerator per trait + situation key.
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
	"aggressive": {
		"high":        ["Explosive performance.", "Took over early and never looked back."],
		"high_streak": ["On a tear — can't stop this momentum.", "Relentless again today."],
		"mid":         ["Kept the pressure on.", "Forced the pace all game."],
		"low":         ["Overextended — burned too bright too fast.", "The aggression backfired today."],
		"low_streak":  ["Still swinging, still missing.", "The crash continues."],
	},
	"tactical": {
		"high":        ["Read the game brilliantly.", "Controlled every phase."],
		"high_streak": ["The game plan is working perfectly.", "One step ahead at every turn."],
		"mid":         ["Solid, structured performance.", "Did what the team needed."],
		"low":         ["Couldn't adapt — outplayed in the mid-game.", "The opponent broke the structure today."],
	},
	"focused": {
		"important_high":        ["Locked in on the biggest stage.", "Precision when it counted."],
		"important_high_streak": ["Consistently elite under pressure.", "The focused ones always show up."],
		"high":                  ["Delivered exactly what was asked.", "No drama — just results."],
		"mid":                   ["Steady as always.", "Reliable in every phase."],
		"low":                   ["Off their usual standard.", "Uncharacteristically sloppy."],
	},
	"resilient": {
		"high":        ["Wore them down over time.", "Stamina won it in the end."],
		"high_streak": ["Still going strong — this one doesn't tire.", "Endurance is paying off."],
		"mid":         ["Held firm throughout.", "Never wilted under pressure."],
		"low":         ["Even the wall crumbles eventually.", "Couldn't absorb the damage today."],
	},
	"volatile": {
		"high":        ["Unplayable today.", "On one of those peaks — unstoppable."],
		"high_streak": ["Back-to-back peaks — rare for this player.", "Running hot."],
		"low":         ["One of those invisible days.", "Completely off — nothing working."],
		"low_streak":  ["Cold streak continuing.", "Can't find the form."],
		"mid":         ["Somewhere in between today.", "Not their best, not their worst."],
	},
}

static func flavor(trait_key: String, situation_key: String) -> String:
	if not FLAVOR.has(trait_key):
		trait_key = "focused"
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
	var notes: Array[String] = []

	if stamina_key == "exhausted": notes.append("running on fumes")
	elif stamina_key == "tired":   notes.append("showing signs of fatigue")

	if morale_key == "confident":  notes.append("brimming with confidence")
	elif morale_key == "shaky":    notes.append("on a rough run")

	if player.primary_trait == "clutch" and match_type in ["important", "tournament"]:
		notes.append("this is their moment")
	elif player.primary_trait == "aggressive" and match_type == "normal":
		notes.append("ready to set the pace")
	elif player.primary_trait == "resilient":
		notes.append("steady as ever")
	elif player.primary_trait == "volatile":
		notes.append("could go either way today")

	if notes.is_empty():
		return player.player_name + " is ready."
	return player.player_name + " — " + notes[randi() % notes.size()] + "."
