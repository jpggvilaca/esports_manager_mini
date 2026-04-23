# scripts/data/MatchResult.gd
# Typed result container returned by all match runners.
# Replaces the stringly-typed Dictionary bag that was passed between
# MatchDispatcher, GameManager, and Main.gd.
# All fields have safe defaults — callers never need .get("key", fallback).
class_name MatchResult
extends RefCounted

# --- Outcome ---
var won:            bool   = false
var team_score:     int    = 0
var opponent_score: int    = 0

# --- Match identity ---
var match_type:  String = ""   # Calendar.TYPE_* constant
var type_label:  String = ""   # display string e.g. "⭐ Important Match"
var week:        int    = 0
var season:      int    = 0
var opp_strength: String = ""  # calendar label key e.g. "strong"
var is_important:  bool  = false
var is_tournament: bool  = false
var is_solo:       bool  = false

# --- Per-player data (Array of Dictionaries, one per player) ---
# Each entry: { player, score, label, flavor, rested, xp_gained, level, xp_progress }
var players: Array = []

# --- Highlights ---
var mvp_name:   String = ""
var worst_name: String = ""

# --- XP / progression ---
var level_ups: Array = []  # Array of { player_name, new_level, skill_gain, focus_gain }

# --- Tournament-specific ---
var rounds_won:        int    = 0
var rounds_total:      int    = 0
var lost_in_round:     int    = -1   # -1 = didn't lose any round
var tournament_rounds: Array  = []   # per-round sub-results
var round_summary:     String = ""

# --- Meta ---
var streak:   int  = 0
var game_over: bool = false
var has_match: bool = true   # false for pure rest weeks

# --- Quarter bonus (set when a quarter goal is completed this week) ---
var quarter_bonus_description: String = ""  # empty = no bonus this week

# --- Defeat hint (post-match causal chain summary, set by MatchDispatcher) ---
var defeat_hint: String = ""  # e.g. "Ghost was Exhausted (-5 pts). Consider resting them."
