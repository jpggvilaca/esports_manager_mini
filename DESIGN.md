# DESIGN.md — Esports Manager Mini
*Living document. Update whenever systems change.*

---

## GLOSSARY — What Everything Means

This section exists because the game has several overlapping "trait" concepts. Read this first.

### Player Stats (`Player.gd`)

| Term | Type | Range | What It Does |
|------|------|-------|--------------|
| **skill** | int | 30–65 | Raw score ceiling. The base value in Simulation. Grows slowly on level-up. |
| **focus** | int | 35–75 | Controls score **variance**. High focus = tight performance. Low = wide swings. |
| **stamina** | int | 0–100 | Current energy. Costs 13 pts per normal match, 18 per important/tournament. Recovers on bench rest (+15, or +23 for lazy). Below 45 = tired drag. Below 25 = exhausted drag. |
| **morale** | int | 0–100 | Emotional state. +5/+8 on win, -5/-8 on loss (higher delta on important matches). Feeds into the matchup modifier (10% weight). |
| **xp / level** | int | lv 1–10 | Progression. XP from matches or bench training. Level-up increases skill + other stats per trait growth table. |
| **burnout** | int | 0–5 | Hidden fatigue counter. Rises on match played (+1) or bench train (+1). Falls on bench rest (-2). At 3+ a warning shows in the UI. No mechanical penalty beyond the warning. |
| **hunger** | int | 0–5 | Hidden motivation counter. Rises on bench train (+1) or grinder playing (+1). Falls after 3+ consecutive rests (-1). Not currently used in score or XP calculations — reserved for future use. |

### Traits

There are **two distinct trait layers** plus one minor layer. They look similar but serve completely different purposes.

#### Performance Trait (`primary_trait` on Player)
The player's personality/playstyle. Affects the **Simulation score** directly.

| Trait | Effect in Simulation |
|-------|---------------------|
| **clutch** | +10 pts on important/tournament matches. ±0–3 random on normal matches. |
| **choker** | -8 pts on important/tournament matches. +4 pts on normal matches. |
| **grinder** | No score bonus. On bench: defaults to train. Hunger rises on match played. |
| **lazy** | No score bonus. On bench rest: recovers +23 stamina instead of +15. |
| **consistent** | Tightens focus variance by -5 (floor: 2). More predictable output. |
| **volatile** | Widens focus variance by +8. High peaks, low troughs. |
| **none** | No special effect. |

#### Match Trait (derived — used by TraitMatchup only)
Mapped from `primary_trait`. Used **only** for the matchup modifier calculation — never touches the score.

| primary_trait | → match_trait |
|---------------|--------------|
| clutch | clutch |
| choker | clutch |
| grinder | resilient |
| lazy | aggressive |
| consistent | focused |
| volatile | aggressive |
| none | tactical |

#### Minor Trait (`minor_trait` on Player)
Adjusts the stamina drag floor in Simulation. Unlocked at level milestones (lv 3, 5, 10).

| Minor Trait | Stamina Floor | Effect |
|-------------|--------------|--------|
| **resilient** | 0.80 | Less drag when exhausted. |
| **fragile** | 0.60 | More drag when tired or exhausted. |
| **none** | 0.70 | Default. |

---

### The Matchup Modifier

Every week, before the match runs, a modifier is calculated and applied to the opponent's effective threshold:

```
effective_opponent_score = base_opponent_score - matchup_modifier
```

- **Positive modifier** → threshold drops → easier to win
- **Negative modifier** → threshold rises → harder to win
- Range: roughly ±20 points (MAX_BONUS = 20 in TraitMatchup.gd)
- The **displayed** score on the result screen is the effective threshold, not the base

Three inputs, weighted:

| Input | Weight | Source |
|-------|--------|--------|
| Opponent trait counters | 60% | Your match traits vs opponent's 3 trait slots |
| Situation coverage | 30% | Your match traits vs the 3 phase situations |
| Stamina/morale | 10% | avg(stamina×0.6 + morale×0.4) across active squad |

### Opponent Traits (3 slots per match)
Seeded per season+week, so they're deterministic. Difficulty biases the pool:

| Difficulty | Pool |
|-----------|------|
| weak / average | Random 3 from all 5 match traits |
| strong | One trait duplicated (harder to fully counter) |
| dominant | Weighted toward focused + resilient (punishes aggressive/clutch spam) |

~30% of weak/average weeks are **situation-dominant**: 3 fully distinct traits, no counter bias — situations become the primary decision point.

### Situations (Early / Mid / Late)
Each match has 2–3 situations (important/tournament always get 3). Each phase favors one match trait. If a squad player's match trait matches the favored trait, that phase is **covered** (green on hub and result screen).

| Situation | Favors Match Trait |
|-----------|-------------------|
| Early Pressure | aggressive |
| Control Phase | tactical |
| Precision Phase | focused |
| Clutch Moment | clutch |
| Endurance Phase | resilient |

---

### The Score Formula (per player)

```
1. base         = player.skill
2. stamina drag = base × stamina_multiplier  (0.60–1.0 depending on stamina + minor trait)
3. focus roll   = ±rand(2–22)  (range tightened by consistent, widened by volatile)
4. trait bonus  = clutch: +10 on big match / choker: -8 on big match, +4 on normal
5. player score = clamp(result, 0, ∞)
6. team_score   = sum of all active player scores
7. win          = team_score >= effective_opponent_score
```

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
   → Bench cards: toggle train (XP, -5 stamina) or rest (+15/+23 stamina, +5 morale)
   → Market (weeks 4, 8, 12): browse candidates, replace a roster slot (2 slots/season)

3. "Next Week" — GameManager.advance_week()
   → bench outcomes applied first (train XP / rest recovery)
   → matchup modifier calculated
   → Simulation.simulate_team() runs for active squad
   → stamina cost deducted, morale updated, streaks updated
   → XP awarded, level-ups processed
   → SeasonGoalManager checks goals; triggers quarter bonus if earned
   → pending_banner set if a goal just completed

4. ResolutionScreen plays the event log
   → Header → bench lines
   → Early / Mid / Late acts (player lines colored by counter status in Mid act)
   → VICTORY / DEFEAT + effective score vs threshold
   → Debrief: opponent slots (green = countered, red = punished) + situation coverage
   → Level-up announcements, quarter bonus line
   → Continue → hub refreshes → goal banner shown if pending
```

---

## File Reference

| File | Purpose |
|------|---------|
| `scenes/GameWorld.gd/.tscn` | Hub. Match intel left, goals right. Builds PlayerCard rows. |
| `scenes/RosterScreen.gd/.tscn` | Squad overlay. PlayerCard instances + invisible click overlay button. |
| `scenes/ResolutionScreen.gd/.tscn` | Animated result log. Event queue + timed reveal. |
| `ui/components/MarketOverlay.gd/.tscn` | Market overlay. RosterCard + CandidateCard instances. |
| `ui/components/PlayerCard.gd/.tscn` | Reusable hub/roster card. Setup + bench toggle signal. |
| `ui/components/RosterCard.gd/.tscn` | Market "Your Team" column card. Data binding only. |
| `ui/components/CandidateCard.gd/.tscn` | Market "Available" column card. Data binding only. |
| `scripts/player/Player.gd` | Data class. All player state. No logic. |
| `scripts/managers/GameManager.gd` | Orchestrator. All game logic entry points. UI calls here only. |
| `scripts/managers/PlayerMarket.gd` | Candidate generation + hire logic. Never called directly by UI. |
| `scripts/managers/SeasonGoalManager.gd` | Season + quarter goals. Quarter boundary detection. |
| `scripts/systems/TraitMatchup.gd` | Matchup modifier math. Pure static. Single source of truth for SITUATION_FAVORS. |
| `scripts/systems/Simulation.gd` | Per-player score simulation. Pure static. |
| `scripts/systems/LevelSystem.gd` | XP + level-up stat growth. Pure static. |
| `scripts/systems/MatchFlavorGenerator.gd` | Flavor text per player score. Pure static. |
| `scripts/data/Calendar.gd` | 24-week season schedule. All match type/difficulty/opponent data. |
| `scripts/data/GameText.gd` | All display strings, icons, labels. Single source of truth for text. |
| `scripts/data/WeekResult.gd` | Data container: GameManager → ResolutionScreen. |
| `scripts/data/MatchResult.gd` | Compatibility shim: WeekResult → SeasonGoalManager. |

---

## Balance Knobs

Everything tweakable and where to find it:

| What | Where | Current Value |
|------|-------|--------------|
| Squad size | `GameManager.SQUAD_SIZE` | 3 |
| Season length | `Calendar.WEEKS_PER_SEASON` | 24 weeks |
| Max seasons | `Calendar.MAX_SEASONS` | 10 (-1 = infinite) |
| Season difficulty ramp | `Calendar.SEASON_DIFFICULTY_STEP` | +8% per season |
| Match stamina cost | `GameManager._apply_match_stamina_cost()` | 13 normal, 18 important |
| Bench rest recovery | `GameManager._resolve_bench()` | +15 stamina (+23 lazy), +5 morale |
| Bench train cost | `GameManager._resolve_bench()` | -5 stamina |
| Bench train XP | `LevelSystem.XP_TRAIN` | 5 XP |
| Match XP (carried/solid/struggled) | `LevelSystem.XP_CARRIED/SOLID/STRUGGLED` | 100 / 60 / 30 |
| Match XP loss multiplier | `LevelSystem.XP_LOSS_MULT` | ×0.55 |
| Match type XP multiplier | `LevelSystem.XP_MULT` | normal ×1.0, important ×1.5, tournament ×3.0 |
| Level thresholds | `LevelSystem.LEVEL_THRESHOLDS` | 90 / 160 / 240 … 1140 |
| Stat growth per level | `LevelSystem.TRAIT_GROWTH` | varies by trait |
| Minor trait unlocks | `LevelSystem.TRAIT_UNLOCKS` | lv 3, 5, 10 |
| Matchup modifier max range | `TraitMatchup.MAX_BONUS` | ±20 points |
| Matchup weights | `TraitMatchup.calc_modifier()` | 60% / 30% / 10% |
| Situation-dominant week rate | `TraitMatchup.generate_opponent_traits()` | ~30% of weak/avg weeks |
| Market interval | `PlayerMarket.MARKET_INTERVAL` | every 4 weeks (weeks 4, 8, 12) |
| Market slots per season | `PlayerMarket.MAX_REPLACEMENTS_PER_SEASON` | 2 |
| Candidate starting level | `PlayerMarket.CANDIDATE_START_LEVEL` | 2 |
| Win/loss morale deltas | `GameManager._apply_morale()` | ±5 normal, ±8 important |
| Stamina drag floors | `Simulation._stamina_multiplier()` | 0.70 base, 0.60 fragile, 0.80 resilient |
| Clutch bonus | `Simulation.simulate_player()` | +10 on important/tournament |
| Choker penalty | `Simulation.simulate_player()` | -8 on important/tournament, +4 on normal |
| Quarter bonus reward | `SeasonGoalManager.consume_quarter_bonus()` | +10 morale, +50 XP all active players |
