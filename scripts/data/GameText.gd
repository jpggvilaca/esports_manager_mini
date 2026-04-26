class_name GameText
extends RefCounted


# --- Action descriptions ---
const ACTIONS: Dictionary = {
	"train": {
		"label":       "⚡ Grind",
		"description": "Heavy XP investment. Costs stamina. Builds burnout — too many in a row will hurt on big match day.",
	},
	"rest": {
		"label":       "💤 Rest",
		"description": "Recovers stamina and morale. Zero XP. Warning: 3+ rest weeks in a row drains competitive hunger.",
	},
	"scrim": {
		"label":       "🎮 Scrim",
		"description": "Balanced. Improves focus, keeps hunger sharp. Costs stamina but less than grinding.",
	},
	"intense": {
		"label":       "🔥 Intense",
		"description": "Desperate measure. Huge burnout cost. Only when you need one more push before a big match.",
	},
}


# --- Week context lines ---
const WEEK_CONTEXT: Dictionary = {
	"normal":     "Another week of practice and competition.",
	"important":  "A crucial match is coming up. Preparation matters.",
	"tournament": "Tournament week. Every decision counts.",
	"solo":       "One player carries the team. Choose wisely.",
}

const WEEK_HEADER: String = "Week %d — %s"

const MATCH_TYPE_UPPER: Dictionary = {
	"normal":     "REGULAR MATCH",
	"important":  "IMPORTANT MATCH",
	"tournament": "TOURNAMENT",
	"solo":       "SOLO MATCH",
}


# --- Performance labels ---
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


# --- Stamina condition labels ---
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
	"neutral":   "",
}

# --- Opponent difficulty labels ---
const DIFFICULTY: Dictionary = {
	"weak":     "Easy",
	"average":  "Medium",
	"strong":   "Hard",
	"dominant": "Very Hard",
}

const OPPONENT_STRENGTH: Dictionary = {
	"weak":     "Weak",
	"average":  "Average",
	"strong":   "Strong",
	"dominant": "Dominant",
}


# --- Streak labels ---
const STREAK_ON_ROLL:  String = "🔥 on a roll"
const STREAK_COLD:     String = "❄️ cold streak"


# ============================================================
# TRAIT DISPLAY — icons + descriptions
# Used everywhere: hub cards, roster, resolution screen, pre-match info.
#
# Icon assignment (using numbered icons from assets/icons/):
#   aggressive  → 🗡  icon 1  (sword — attack archetype)
#   tactical    → 🧠  icon 2  (brain — strategy archetype)
#   focused     → 🎯  icon 3  (target — precision archetype)
#   clutch      → ⚡  icon 4  (lightning — pressure archetype)
#   resilient   → 🛡  icon 5  (shield — endurance archetype)
#
# Performance traits (existing) also get icons for roster/hub display:
#   clutch      → ⚡  (maps to clutch match trait)
#   choker      → 😰
#   grinder     → ⚙️
#   lazy        → 💤
#   consistent  → 📐
#   volatile    → 🌀
# ============================================================

# Icon prefix shown before trait name everywhere in the UI.
# Format: "ICON  " (emoji + two spaces for visual spacing in Labels)
const TRAIT_ICONS: Dictionary = {
	# Performance traits (Player.primary_trait)
	"clutch":      "⚡  ",
	"choker":      "😰  ",
	"grinder":     "⚙️  ",
	"lazy":        "💤  ",
	"consistent":  "🎯  ",
	"volatile":    "🌀  ",
	"none":        "",
	# Match traits (TraitMatchup — shown on opponent + matchup panels)
	"aggressive":  "🗡️  ",
	"tactical":    "🧠  ",
	"focused":     "🎯  ",
	"resilient":   "🛡️  ",
}

# Short display name for each trait (icon + name).
# Use trait_label() helper to build the full string.
const TRAIT_NAMES: Dictionary = {
	# Performance traits
	"clutch":      "Clutch",
	"choker":      "Choker",
	"grinder":     "Grinder",
	"lazy":        "Lazy",
	"consistent":  "Consistent",
	"volatile":    "Volatile",
	"none":        "Balanced",
	# Match traits
	"aggressive":  "Aggressive",
	"tactical":    "Tactical",
	"focused":     "Focused",
	"resilient":   "Resilient",
}

# Full one-line tooltip descriptions for roster/pre-match panel.
const TRAIT_DESCRIPTIONS: Dictionary = {
	"clutch":      "Clutch — peaks under pressure",
	"choker":      "Chokes under pressure, thrives in easy games",
	"grinder":     "Grinder — steady improvement through hard work",
	"lazy":        "Lazy — needs rest to perform well",
	"consistent":  "Consistent — reliable, low variance",
	"volatile":    "Volatile — unpredictable, big highs and lows",
	"none":        "Balanced",
	# Match traits (shown in opponent panel)
	"aggressive":  "Aggressive — strong in fast/pressure play",
	"tactical":    "Tactical — strong in structured, control play",
	"focused":     "Focused — consistent, reduces mistakes",
	"resilient":   "Resilient — strong in long endurance matches",
}

# Match trait beat/weakness hints (shown in pre-match panel as tooltips).
const TRAIT_BEATS: Dictionary = {
	"aggressive":  "Beats: Focused",
	"tactical":    "Beats: Aggressive",
	"focused":     "Beats: Tactical, Clutch",
	"clutch":      "Beats: Resilient",
	"resilient":   "Beats: Clutch",
}

const TRAIT_WEAK: Dictionary = {
	"aggressive":  "Weak vs: Tactical, Resilient",
	"tactical":    "Weak vs: Focused",
	"focused":     "Weak vs: Aggressive",
	"clutch":      "Weak vs: Focused",
	"resilient":   "Weak vs: Aggressive, Clutch",
}

# Returns "ICON  Name" for display in Labels.
static func trait_label(trait_key: String) -> String:
	var icon: String = TRAIT_ICONS.get(trait_key, "")
	var name: String = TRAIT_NAMES.get(trait_key, trait_key.capitalize())
	return icon + name


# ============================================================
# SITUATION DISPLAY
# Each situation has an icon, short name, and one-line description.
# ============================================================

const SITUATION_ICONS: Dictionary = {
	"early_pressure":  "💥",
	"control_phase":   "🧩",
	"precision_phase": "🔬",
	"clutch_moment":   "⚡",
	"endurance_phase": "🏃",
}

const SITUATION_NAMES: Dictionary = {
	"early_pressure":  "Early Pressure",
	"control_phase":   "Control Phase",
	"precision_phase": "Precision Phase",
	"clutch_moment":   "Clutch Moment",
	"endurance_phase": "Endurance Phase",
}

const SITUATION_DESC: Dictionary = {
	"early_pressure":  "Fast opener — rewards aggressive plays",
	"control_phase":   "Slow, structured — rewards tactical reads",
	"precision_phase": "No room for mistakes — rewards focus",
	"clutch_moment":   "Late-game pressure — rewards clutch players",
	"endurance_phase": "Long grind — rewards resilient players",
}

const SITUATION_FAVORS: Dictionary = {
	"early_pressure":  "aggressive",
	"control_phase":   "tactical",
	"precision_phase": "focused",
	"clutch_moment":   "clutch",
	"endurance_phase": "resilient",
}

# Returns "ICON  Name" for a situation.
static func situation_label(situation_key: String) -> String:
	var icon: String = SITUATION_ICONS.get(situation_key, "❓")
	var name: String = SITUATION_NAMES.get(situation_key, situation_key.capitalize())
	return icon + "  " + name


# --- Match outcome labels ---
const OUTCOME_VICTORY:     String = "✅  VICTORY"
const OUTCOME_DEFEAT:      String = "❌  DEFEAT"
const OUTCOME_CLOSE:       String = " — so close!"
const OUTCOME_REST_WEEK:   String = "💤  Rest Week"
const OUTCOME_REST_DESC:   String = "No match this week. Players recovered."
const MATCH_SCORE_LINE:    String = "Your team  %d pts   vs   Enemy  %d pts"
const GAME_OVER_BTN:       String = "Season limit reached"

# --- Match type labels ---
const MATCH_TYPE: Dictionary = {
	"normal":     "Regular Match",
	"important":  "⭐ Important Match",
	"tournament": "🏆 Tournament",
	"solo":       "👤 Solo Match",
}

# --- Solo match strings ---
const SOLO_PICK_PROMPT:  String = "Choose your solo player:"
const SOLO_WIN_FLAVOR:   Array  = ["Carried the match alone.", "Stepped up when it counted.", "Proved the team was not needed."]
const SOLO_LOSS_FLAVOR:  Array  = ["Couldn't handle it alone.", "The pressure was too much solo.", "Needed backup that wasn't there."]
const ADVANCE_BTN_SOLO:  String = "⚡  Advance Week  — 👤 Solo"

# --- Tournament strings ---
const TOURNAMENT_ROUND:       String = "Round %d"
const TOURNAMENT_WIN_ALL:     String = "Dominated the entire tournament."
const TOURNAMENT_WIN_CLOSE:   String = "Scraped through — but made it."
const TOURNAMENT_LOSS_ROUND:  String = "Eliminated in Round %d."
const TOURNAMENT_ROUNDS_WON:  String = "Won %d / %d rounds"

# --- MVP badge ---
const MVP_BADGE:   String = "⭐ MVP"
const WORST_BADGE: String = "💔 Struggled"

# --- Pre-match risk warnings ---
const WARN_TIRED_PLAYER: String = "⚠️ Tired players"
const WARN_IMPORTANT:    String = "Stakes are high — don't waste this"
const WARN_SOLO:         String = "👤 Solo match — pick wisely"

# --- Pre-match win estimate ---
const ESTIMATE_FAVORED:  String = "🟢 You are favored"
const ESTIMATE_EVEN:     String = "🟡 Even match"
const ESTIMATE_UNDERDOG: String = "🔴 You are the underdog"

# --- Matchup verdict labels (shown pre-match) ---
const MATCHUP_STRONG:  String = "✅ Good counter"
const MATCHUP_NEUTRAL: String = "🟡 Even matchup"
const MATCHUP_WEAK:    String = "⚠️ Bad matchup"

static func matchup_verdict(modifier: float) -> String:
	if modifier >= 8.0:
		return MATCHUP_STRONG
	elif modifier <= -8.0:
		return MATCHUP_WEAK
	else:
		return MATCHUP_NEUTRAL

# --- Morale delta display ---
const MORALE_GAIN: String = "(+%d morale)"
const MORALE_LOSS: String = "(%d morale)"
const ADVANCE_BTN_NORMAL:     String = "⚡  Advance Week"
const ADVANCE_BTN_IMPORTANT:  String = "⚡  Advance Week  — ⭐ Important"
const ADVANCE_BTN_TOURNAMENT: String = "⚡  Advance Week  — 🏆 Tournament"

# --- XP & Level ---
const XP_GAINED:      String = "+%d XP"
const LEVEL_UP:       String = "⬆ Level %d!"
const LEVEL_UP_STATS: String = "Skill +%d%s"
const LEVEL_BADGE:    String = "Lv.%d"


# --- Flavor text pools ---
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
		"low":         ["Looked disinterested from the start.", "Coasting — needs a spark."],
		"high":        ["Turned it on when it counted.", "Explosive when motivated."],
		"mid":         ["Managed their energy carefully.", "Didn't overextend."],
	},

	"consistent": {
		"high":        ["Delivered exactly what was asked.", "No drama — just results."],
		"mid":         ["Steady as always.", "Reliable in every phase."],
		"low":         ["Off their usual standard.", "Uncharacteristically sloppy."],
	},

	"volatile": {
		"high":        ["Unplayable today.", "On one of those peaks — unstoppable."],
		"high_streak": ["Back-to-back peaks — rare for this player.", "Running hot."],
		"low":         ["One of those invisible days.", "Completely off — nothing working."],
		"low_streak":  ["Cold streak continuing.", "Can't find the form."],
		"mid":         ["Somewhere in between today.", "Not their best, not their worst."],
	},

	"none": {
		"high":  ["Strong outing.", "Came through when needed."],
		"mid":   ["Solid contribution.", "Did their part."],
		"low":   ["Quiet match.", "Couldn't make an impact."],
	},
}


# ---------------------------------------------------------------------------
# FLAVOR — picks a random line from the FLAVOR pool for a trait+key combo.
# Falls back gracefully if the key or trait is missing.
# ---------------------------------------------------------------------------
static func flavor(trait_key: String, situation_key: String) -> String:
	if not FLAVOR.has(trait_key):
		trait_key = "none"
	var pool: Dictionary = FLAVOR[trait_key]
	# Try exact key, then fall back to base key (strip _streak suffix)
	var base_key: String = situation_key.replace("_streak", "")
	var lines: Array
	if pool.has(situation_key):
		lines = pool[situation_key]
	elif pool.has(base_key):
		lines = pool[base_key]
	elif pool.has("mid"):
		lines = pool["mid"]
	else:
		return ""
	if lines.is_empty():
		return ""
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
