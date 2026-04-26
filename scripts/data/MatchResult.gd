# scripts/data/MatchResult.gd
# Minimal shim — only exists so SeasonGoalManager (which predates the new loop)
# can receive match outcome data without a full rewrite.
# Only the fields below are actually read. Everything else was removed.
class_name MatchResult
extends RefCounted

var won:          bool   = false
var team_score:   int    = 0
var match_type:   String = ""
var is_tournament: bool  = false   # read by SeasonGoalManager
var has_match:    bool   = true
