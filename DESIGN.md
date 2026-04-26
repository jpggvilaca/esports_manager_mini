# DESIGN.md — Esports Manager Mini
*Living document. Update whenever systems change.*

---

## GLOSSARY — What Everything Means

This section exists because the game has several overlapping "trait" concepts. Read this first.

### Player Stats (on Player.gd)

| Term | Type | Range | What It Does |
|------|------|-------|--------------|
| **skill** | int | 30–65 | Raw mechanical ceiling. The base score in Simulation. Higher = more output per week. Never changes without levelling or market hire. |
| **focus** | int | 35–75 | Controls score **variance**. High focus = tight, predictable performance. Low focus = wide swings (could be great or terrible). |
| **stamina** | int | 0–100 | Current energy. Drains 13–18 pts per match played, recovers on bench rest. Below 45 = tired drag on score. Below 25 = exhausted (severe drag). |
| **morale** | int | 0–100 | Emotional state. Rises on wins, falls on losses (more for important matches). Feeds into the stamina/morale modifier (10% weight on matchup calc). |
| **xp / level** | int | lv 1–10 | Progression. XP earned each match or training session. Levelling up increases skill by 1 (see LevelSystem.gd). |
| **burnout** | int | 0–5 | Hidden fatigue counter. Rises each match played or training session, falls on rest. At 3+ a warning shows. High burnout = reduced XP gain. |
| **hunger** | int | 0–5 | Hidden motivation counter. High hunger = bonus XP. Falls if player rests too often (3+ consecutive rests). |

### Traits

There are **two distinct trait layers**. They look similar but serve different purposes.

#### Performance Trait (`primary_trait` on Player)
The player's personality/playstyle. Affects the **Simulation score** directly.

| Trait | Effect |
|-------|--------|
| **clutch** | +10 pts on important/tournament matches. Small variance otherwise. |
| **choker** | -8 pts on important matches. +4 pts on normal matches (no pressure). |
| **grinder** | No score bonus. Trains faster (+more XP on bench). Hunger rises faster. |
| **lazy** | No score bonus. Recovers more stamina when resting on bench. |
| **consistent** | Tightens focus variance (±5 narrower random swing). |
| **volatile** | Widens focus variance (+8 wider random swing — could be huge or terrible). |
| **none** | No special effect. |

#### Match Trait (derived, used by TraitMatchup)
A strategic category mapped from `primary_trait`. Used **only** for the pre-match matchup modifier — never affects score directly.

| primary_trait | match_trait |
|---------------|-------------|
| clutch | clutch |
| choker | clutch |
| grinder | resilient |
| lazy | aggressive |
| consistent | focused |
| volatile | aggressive |
| none | tactical |

#### Minor Trait (`minor_trait` on Player)
A secondary modifier affecting stamina drag in Simulation.

| Minor Trait | Effect |
|-------------|--------|
| **resilient** | Higher stamina floor when exhausted (0.80 vs 0.70). Less drag. |
| **fragile** | Lower stamina floor (0.60). More drag when tired. |
| **none** | Default floor (0.70). |

### The Matchup Modifier

Every week, before the match runs, a **matchup modifier** is calculated. It adjusts the opponent's effective score threshold — it does **not** change the players' Simulation scores.

```
effective_opponent_score = base_opponent_score - matchup_modifier
```

- **Positive modifier** → opponent threshold drops → easier to win
- **Negative modifier** → opponent threshold rises → harder to win
- Range: roughly ±20 points

The modifier has three inputs, weighted:

| Input | Weight | Source |
|-------|--------|--------|
| Opponent trait counters | 60% | Your match traits vs opponent's 3 trait slots |
| Situation coverage | 30% | Your match traits vs Early/Mid/Late situation traits |
| Stamina/morale | 10% | Average stamina (60%) + morale (40%) across active squad |

### Opponent Traits (3 slots per match)
The opponent has 3 match-trait slots drawn per season (seeded, deterministic). Difficulty shifts the pool:
- **weak/average**: random draw from all 5 match traits
- **strong**: one trait duplicated (harder to fully counter)
- **dominant**: biased toward focused + resilient (punishes aggressive/clutch spam)
- ~30% of weak/average weeks are "situation-dominant" (3 distinct traits, matchup is neutral)

### Situations (Early / Mid / Late)
Each match has 2–3 situations, one per phase. Each favors a match trait. If your squad has a player whose match trait matches the situation's favored trait, that situation is **covered** (shown in green on hub and result screen).

| Situation | Favors |
|-----------|--------|
| Early Pressure | aggressive |
| Control Phase | tactical |
| Precision Phase | focused |
| Clutch Moment | clutch |
| Endurance Phase | resilient |

### The Score Formula (simplified)

```
1. base = player.skill
2. apply stamina drag → multiplier 0.70–1.0 based on stamina (minor trait adjusts floor)
3. focus roll → ±rand(4–22) depending on focus stat and performance trait
4. trait bonus → +10 clutch on big match, -8 choker on big match, etc.
5. sum across 3 active players → team_score
6. compare team_score >= effective_opponent_score → win/loss
```

---

## Architecture

```
GameManager          — orchestrator. Owns players[], week, season, goal_manager, market.
  ↓ calls
  TraitMatchup       — pure static. Generates opponent traits, situations, calculates modifier.
  Simulation         — pure static. Simulates each player's score. Returns team_score.
  LevelSystem        — pure static. XP thresholds, level-up logic.
  SeasonGoalManager  — tracks season + quarter goals.
  PlayerMarket       — generates candidates, handles replacements (2/season).
  Calendar           — week→match type lookup table. All week data is here.

GameWorld (scene)    — hub screen. Reads get_week_context(), calls advance_week().
  ↓ opens
  RosterScreen       — squad selection + bench action toggle (train/rest).
  ResolutionScreen   — animated match result sequence.
  MarketOverlay      — candidate browse + hire flow.
```

### Data Flow Per Week

```
1. Hub refresh: GameManager.get_week_context()
   → generates opponent traits + situations (seeded, deterministic)
   → shows prognosis: Early/Mid/Late with coverage colors
   → shows win estimate

2. Player adjusts:
   → Roster: toggle active/bench players
   → Bench cards: toggle train vs rest for each benched player
   → Market (if week % 4 == 0): browse and hire candidates

3. "Next Week" pressed → GameManager.advance_week()
   → bench outcomes: rest restores stamina/morale; train gives XP
   → matchup modifier calculated
   → Simulation runs for active squad
   → XP awarded, level-ups processed
   → goals checked

4. ResolutionScreen plays the event sequence
   → Early/Mid/Late acts
   → Debrief: what countered what (green/red)
   → Level-ups, quarter bonus
   → Close → hub refreshes
```

---

## Scene + Script Reference

| File | Purpose |
|------|---------|
| `scenes/GameWorld.gd/.tscn` | Hub screen. Two-column layout: left=match intel, right=goals. |
| `scenes/RosterScreen.gd/.tscn` | Squad overlay. Click to activate/bench. Toggle train/rest per bench player. |
| `scenes/ResolutionScreen.gd/.tscn` | Animated result log. Three-act sequence + debrief. |
| `ui/components/MarketOverlay.gd/.tscn` | Market overlay. Browse candidates, confirm replacement. |
| `scripts/player/Player.gd` | Data class. All player state. No logic. |
| `scripts/managers/GameManager.gd` | Orchestrator. All game logic entry points. UI talks here only. |
| `scripts/managers/PlayerMarket.gd` | Candidate generation + slot logic. Only accessed via GameManager bridge methods. |
| `scripts/managers/SeasonGoalManager.gd` | Season + quarter goal tracking. |
| `scripts/systems/TraitMatchup.gd` | Matchup modifier math. Pure static. |
| `scripts/systems/Simulation.gd` | Per-player score simulation. Pure static. |
| `scripts/systems/LevelSystem.gd` | XP + level-up logic. Pure static. |
| `scripts/systems/MatchFlavorGenerator.gd` | Flavor text for player actions. |
| `scripts/data/Calendar.gd` | 12-week season schedule. Match types, difficulty labels. |
| `scripts/data/GameText.gd` | All display strings, icons, labels, colors. Single source of truth for text. |
| `scripts/data/WeekResult.gd` | Result container passed from GameManager → ResolutionScreen. |

---

## Balance Knobs (where to tweak things)

| What to change | Where |
|----------------|-------|
| Player starting stats | `GameManager._init()` |
| Match scoring weights | `Simulation.simulate_player()` |
| Stamina drag curve | `Simulation._stamina_multiplier()` |
| XP per match/action | `LevelSystem.gd` constants |
| Matchup modifier range | `TraitMatchup.MAX_BONUS` (currently 20) |
| Matchup weights (60/30/10) | `TraitMatchup.calc_modifier()` |
| Opponent difficulty bias | `TraitMatchup.generate_opponent_traits()` |
| Situation-dominant week rate | `TraitMatchup.generate_opponent_traits()` — `randi() % 10 < 3` |
| Market timing | `PlayerMarket.MARKET_INTERVAL` (currently every 4 weeks) |
| Market replacements/season | `PlayerMarket.MAX_REPLACEMENTS_PER_SEASON` (currently 2) |
| Season length | `Calendar.gd` |
| Win/loss morale deltas | `GameManager._apply_morale()` |
| Stamina cost per match | `GameManager._apply_match_stamina_cost()` — 13 normal, 18 important |
| Rest stamina recovery | `GameManager._resolve_bench()` — 15 pts (23 for lazy) |

---

## What Was Built (Session History Summary)

- Full trait matchup system (Pokémon-type counters)
- Hub UI: two-column layout, green/red prognosis coloring, win estimate
- Roster screen: click to activate/bench, train/rest toggle per bench player
- Resolution screen: three-act sequence, colored debrief (what countered what)
- Market overlay: candidate browse, confirm-then-replace flow (2 slots/season)
- Balance fixes: dominant trio prevention, situation-dominant weeks (~30%)
- Score display: shows effective threshold (base minus modifier)

## Pending / Not Yet Built

- Per-act simulation (3 separate mini-sims instead of 1 split by narrative)
- Calendar view on hub (next 6 weeks visible)
- Season-end awards ceremony
- Sound effects
