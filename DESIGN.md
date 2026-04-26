# DESIGN.md — Esports Manager Mini
*Living document. Update whenever systems change.*

---

## GLOSSARY — What Everything Means

### Player Stats (`Player.gd`)

| Term | Type | Range | What It Does |
|------|------|-------|--------------|
| **skill** | int | 30–65 | Raw score ceiling. The base value in Simulation. Grows slowly on level-up. |
| **focus** | int | 35–75 | Controls score **variance**. High focus = tight performance. Low = wide swings. |
| **stamina** | int | 0–100 | Current energy. Costs 13 pts per normal match, 18 per important/tournament. Recovers on bench rest (+15, or +23 for aggressive trait players). Below 45 = tired drag. Below 25 = exhausted drag. |
| **morale** | int | 0–100 | Emotional state. +5/+8 on win, −5/−8 on loss (higher delta on important matches). Clutch players get +3 extra on important wins. |
| **xp / level** | int | lv 1–10 | Progression. XP from matches or bench training. Level-up increases skill + other stats per trait growth table. |
| **burnout** | int | 0–5 | Hidden fatigue counter. Rises on match played (+1) or bench train (+1). Falls on bench rest (−2). At 3+ a warning shows in the UI. No mechanical penalty beyond the warning. |
| **hunger** | int | 0–5 | Hidden motivation counter. Rises on bench train (+1) or resilient playing (+1). Falls after 3+ consecutive rests (−1). Reserved for future use. |

---

### Traits

There is **one unified trait system**. A player's `primary_trait` is used for *everything* — simulation scoring, matchup counters, and phase coverage. There is no hidden mapping or secondary trait layer.

#### Unified Trait (`primary_trait` on Player)

Six traits. Each affects simulation AND matchup. What the player sees on the card is what the game uses.

| Trait | Simulation Effect | Stamina Floor | Counters | Weak To | Phase |
|-------|------------------|--------------|----------|---------|-------|
| **aggressive** 🗡️ | Variance +8 | 0.65 (burns fast) | focused | tactical, resilient | Early |
| **tactical** 🧠 | Variance −4 | 0.70 (base) | aggressive | focused | Mid |
| **focused** 🎯 | Variance −6, +5 on important matches | 0.70 (base) | tactical, clutch | aggressive | — |
| **clutch** ⚡ | +12 on important, ±3 noise otherwise | 0.70 (base) | resilient | focused, aggressive | Late |
| **resilient** 🛡️ | No variance change | 0.80 (holds under fatigue) | aggressive, clutch | clutch | — |
| **volatile** 🌀 | Variance +14, ±5–12 spike/crash | 0.70 (base) | — (neutral) | — (neutral) | Wild card |

**Counter ring (core):** tactical → aggressive → focused → tactical

**Side chain:** focused → clutch → resilient → aggressive

**Volatile** has no counter relationship — matchup modifier is always 0 when volatile meets any trait.

#### Minor Trait (`minor_trait` on Player)

Adjusts the stamina drag floor. Unlocked at level milestones. The primary trait already sets a floor; minor trait can override it.

| Minor Trait | Stamina Floor | Effect |
|-------------|--------------|--------|
| **resilient** | 0.80 | Less drag when exhausted. |
| **fragile** | 0.60 | More drag when tired or exhausted. |
| **none** | — (primary floor applies) | Default. |

**Unlock schedule:**

| Level | aggressive | tactical | focused | clutch | resilient | volatile |
|-------|-----------|----------|---------|--------|-----------|---------|
| 3 | fragile | resilient | resilient | resilient | resilient | fragile |
| 10 | resilient | resilient | resilient | resilient | resilient | resilient |

---

### The Matchup Modifier

Every week, before the match runs, an integer modifier is calculated and applied to the opponent's effective threshold:

```
effective_opponent_score = base_opponent_score - matchup_modifier
```

- **Positive modifier** → threshold drops → easier to win
- **Negative modifier** → threshold rises → harder to win
- Range: roughly −15 to +15 points (integer, no decimals)
- The **displayed** score on the result screen is the effective threshold, not the base

Two inputs:

| Input | Weight | Source |
|-------|--------|--------|
| Opponent trait counters | 60% | Your traits vs opponent's 3 slots (+3 per win, −2 per loss) |
| Situation phase coverage | 30% | Your traits vs the 3 phase situations (+2 per covered phase, −1 partial offset) |

> Stamina/morale no longer has a separate weight — it is reflected directly in the simulation score via the stamina drag multiplier.

### Opponent Traits (3 slots per match)

Seeded per season+week — deterministic, so the same week always has the same opponent. Difficulty biases the pool:

| Difficulty | Pool |
|-----------|------|
| weak / average | Random 3 from all 6 traits |
| strong | One trait duplicated (harder to fully counter) |
| dominant | Weighted toward focused + resilient (punishes aggressive/clutch spam) |

~30% of weak/average weeks are **situation-dominant**: 3 fully distinct traits, no counter bias — phases become the primary decision point.

### Situations (Early / Mid / Late)

Each match has 2–3 situations (important/tournament always get all 3). Each phase favors one trait. If a squad player's trait matches the favored trait, that phase is **covered** (green on hub and result screen).

| Phase | Favors Trait | Why |
|-------|-------------|-----|
| Early | aggressive | Who sets the pace first |
| Mid | tactical | Read, adapt, control the midgame |
| Late | clutch | Deliver when the stakes are highest |

---

### The Score Formula (per player)

```
1. base          = player.skill
2. stamina drag  = base × stamina_multiplier
                   (floor 0.60–0.80 depending on trait + minor trait; 1.0 at full stamina)
3. focus roll    = ±rand(2–22), narrowed/widened by primary trait:
                   focused −6, tactical −4, aggressive +8, volatile +14
4. trait bonus   = clutch:     +12 on important / ±3 noise on normal
                   focused:    +5 on important
                   volatile:   ±5–12 spike or crash (random direction)
                   aggressive, tactical, resilient: effect is in steps 2–3 only
5. player score  = clamp(result, 0, ∞)
6. team_score    = sum of all active player scores
7. win           = team_score >= effective_opponent_score
```

---

### Level-Up Stat Growth

Each trait biases which stats grow on level-up (`base + randi(0, trait_bonus)`):

| Trait | skill bonus | stamina bonus | focus bonus | morale bonus |
|-------|------------|--------------|------------|-------------|
| aggressive | +3 | +1 | +1 | +2 |
| tactical | +2 | +2 | +3 | +1 |
| focused | +2 | +1 | +3 | +1 |
| clutch | +3 | +1 | +1 | +3 |
| resilient | +1 | +3 | +1 | +2 |
| volatile | +3 | +1 | +2 | +0 |

---

## Architecture

```
GameManager            — orchestrator. Owns players[], week, season, goal_manager, market, pending_banner.
  ↓ calls
  TraitMatchup         — pure static. Opponent traits, situations, matchup modifier.
  Simulation           — pure static. Per-player score. Returns team_score + breakdown.
  LevelSystem          — pure static. XP thresholds, level-up stat growth, trait unlocks.
  MatchFlavorGenerator — pure static. Flavor text and perf label per player score.
  SeasonGoalManager    — season + quarter goal tracking. Quarter bonuses.
  PlayerMarket         — candidate generation and slot logic (accessed via GameManager bridge only).
  Calendar             — 24-week season template. Match types, opponent names, difficulty labels.

GameWorld.tscn         — hub screen. Left: match intel. Right: goals.
  ↓ opens (as $UI children)
  RosterScreen.tscn    — squad selection + bench train/rest toggle.
  ResolutionScreen.tscn — animated match log. Three-act sequence + debrief + goal banner.
  MarketOverlay.tscn   — candidate browse + hire flow. Available weeks 4, 8, 12 per season.
```

### Data Flow Per Week

```
1. Hub refresh — GameManager.get_week_context()
   → deterministic opponent traits + situations for this week
   → prognosis panel: Early/Mid/Late with green/red coverage
   → win estimate label

2. Player adjusts squad
   → Roster screen: click to activate/bench players
   → Bench cards: toggle train (XP, −5 stamina) or rest (+15 stamina, +5 morale;
     aggressive trait players recover +23 on rest)
   → Market (weeks 4, 8, 12): browse candidates, replace a roster slot (2 slots/season)

3. "Next Week" — GameManager.advance_week()
   → bench outcomes applied first (train XP / rest recovery)
   → TraitMatchup.calculate_matchup_modifier() — integer result
   → Simulation.simulate_team() runs for active squad
   → stamina cost deducted, morale updated, streaks updated
   → XP awarded, level-ups processed
   → SeasonGoalManager checks goals; triggers quarter bonus if earned
   → pending_banner set if a goal just completed

4. ResolutionScreen plays the event log
   → Header → bench lines
   → Early / Mid / Late acts (player lines colored by counter status)
   → VICTORY / DEFEAT + effective score vs threshold
   → Debrief: opponent slots (green = countered, red = punished) + situation coverage
   → Level-up announcements, quarter bonus line
   → Continue → hub refreshes → goal banner shown if pending
```

---

## File Reference

| File | Role | Key exports |
|------|------|-------------|
| `scripts/player/Player.gd` | Data class. No logic. | `primary_trait`, `minor_trait`, stats, state |
| `scripts/systems/TraitMatchup.gd` | Matchup engine | `ALL_TRAITS`, `WINS_AGAINST`, `LOSES_AGAINST`, `SITUATION_FAVORS`, `generate_opponent_traits()`, `generate_situations()`, `get_team_traits()`, `calculate_matchup_modifier()` |
| `scripts/systems/Simulation.gd` | Score engine | `simulate_player()`, `simulate_team()`, `_stamina_multiplier()` |
| `scripts/systems/LevelSystem.gd` | Progression | `TRAIT_GROWTH`, `TRAIT_UNLOCKS`, `award_match_xp_with_result()` |
| `scripts/systems/MatchFlavorGenerator.gd` | Flavor text | `generate()` |
| `scripts/data/GameText.gd` | All display strings | `TRAIT_ICONS`, `TRAIT_NAMES`, `TRAIT_TOOLTIPS`, `SITUATION_NAMES`, `FLAVOR`, `trait_label()` |
| `scripts/data/Calendar.gd` | Season schedule | `get_week()`, `get_opponent_name()`, `get_next_event()` |
| `scripts/managers/GameManager.gd` | Orchestrator | `advance_week()`, `get_week_context()`, `active_players()` |
| `scripts/managers/PlayerMarket.gd` | Market system | `ARCHETYPES`, `generate_candidates()`, `replace_player()` |
| `scripts/managers/SeasonGoalManager.gd` | Goals | `on_match_result()`, `check_quarter_boundary()` |
| `scripts/data/WeekResult.gd` | Result container | `opponent_traits`, `situations`, `player_match_traits`, `matchup_modifier` |
| `scenes/GameWorld.gd` | Hub UI | Renders match intel panel, prognosis, goals |
| `scenes/ResolutionScreen.gd` | Resolution UI | Three-act event log + debrief |
| `scenes/RosterScreen.gd` | Roster UI | Squad toggle, bench action toggle |
| `ui/components/PlayerCard.gd` | Player card | Shows unified trait label, stats, form |
| `ui/components/CandidateCard.gd` | Market card | Shows candidate stats + trait |

---

## Design Principles

- **One trait, two jobs.** `primary_trait` drives both simulation variance/bonuses and matchup counter logic. No hidden mapping.
- **Integer modifier.** The matchup modifier is an int (roughly −15 to +15). No floats, no black-box percentages.
- **Stamina is mechanical, morale is emotional.** Stamina affects the score via the drag multiplier. Morale affects it indirectly (low morale players hit streaks; no direct score modifier).
- **Volatile is always a risk.** It has the widest variance and no counter advantage — it's a genuine gamble, not a safe pick.
- **Situations are the tiebreaker.** When two teams have similar counter coverage, phase alignment wins the modifier. A Tactical player beats an Aggressive opponent AND covers the Mid phase — that's the double-value pick.
- **Simple to learn, hard to master.** Every rule is visible in the UI. Counterplay depth comes from team composition across 3 slots, not from hidden stats.
