# resources/calendar/week_template.gd
# ============================================================
# WEEK TEMPLATE — typed replacement for the dicts in Calendar.WEEK_TEMPLATE.
#
# A WeekTemplate describes ONE week of the season schedule:
#   - what kind of match it is (normal/important/tournament/solo)
#   - the base opponent threshold score
#   - the difficulty label (used for opponent-name tier and trait pool bias)
#
# A full season is an Array[WeekTemplate] of length WEEKS_PER_SEASON.
#
# SCOPE: Phase A skeleton. The legacy dictionary array in Calendar.gd
# remains the source of truth until Phase B migrates it to .tres files.
# This file lets the migration target type be authored ahead of time.
# ============================================================
@tool
class_name WeekTemplate
extends Resource


# Kept as String for now to mirror the legacy `Calendar.TYPE_*` constants.
# Becomes the `MatchType` enum in step C3.
@export_enum("normal", "important", "tournament", "solo") var match_type: String = "normal"

@export var opponent_score: int = 90

@export_enum("weak", "average", "strong", "dominant") var difficulty_label: String = "weak"
