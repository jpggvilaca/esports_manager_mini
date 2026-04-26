# ESPORTS MANAGER MINI — Design Notes
*Living doc. Update whenever something meaningful changes.*

---

## What this game is

A tycoon/management game where you coach a small esports team across seasons. The fantasy is being the GM and coach — not playing the games, but deciding who plays, who rests, and watching the consequences unfold. Matches resolve automatically, but you watch them act by act. Your decisions before the match are the game.

---

## Core Loop (current implementation)

```
HUB SCREEN (GameWorld)
  ↓  check week context: opponent name + difficulty, match situations, trait matchup verdict
  ↓  read coaching voice on each player card (stamina, form, burnout warnings)
  ↓  read pre-match intel: opponent traits (3 slots), situations (2–3), matchup verdict
  ↓  open Roster to manage squad — pick 1–3 players to counter the opponent

ROSTER SCREEN
  ↓  two columns: BENCH (left) | ACTIVE (right)
  ↓  click a player card to move between bench and active
  ↓  3 active recommended (1–2 is a handicap) — squad full indicator + swap hints
  ↓  bars show Stamina and XP/Level on every card
  ↓  player cards show: performance trait icon + match trait (used for countering)
  ↓  Done → back to hub

HUB — pick squad, read the match intel, press "Next Week"

RESOLUTION SCREEN (sequenced reveal)
  1. Header — Season · Week · Match type
  2. Bench outcomes — who rested (stamina +), who trained (XP+)
  3. Early Game — all active players, stamina/form context
  4. Mid Game — performance labels + any trait that fired
  5. Late Game — flavor text + XP gained
  6. VICTORY / DEFEAT (large, coloured)
  7. Score line
  8. Match breakdown — what the trait counters contributed (new)
  9. Level-ups if any
  10. Quarter bonus if earned
  11. Close button → back to hub
```

---

## Screens

### GameWorld (Hub)
The only persistent screen. Shows:
- Week / Season header
- Match type + upcoming event warning (e.g. "Tournament in 2 weeks")
- Season + Quarter goals
- **Pre-match intel panel:**
  - Opponent name + difficulty
  - Opponent style: 3 trait slots shown with icons (amber tint)
  - Today's match: 2–3 situations + the trait each favors
  - Matchup verdict: ✅ Good counter / 🟡 Even matchup / ⚠️ Bad matchup
- Win estimate (Favored / Even / Underdog) — now incorporates matchup modifier
- Active squad cards (portrait, name, performance trait + match trait, stamina bar, XP bar, coaching voice)
- Bench cards (portrait, name, trait, stamina bar, XP bar, bench status label)
- Roster button, Market button (hidden outside windows), Next Week button

### RosterScreen (Squad Selection)
Full-screen overlay on the CanvasLayer.
- Two-column layout: Bench left, Active right
- Each player card: portrait, name, trait description, bio, stamina bar, XP bar, form label, burnout warning, action hint
- Click a card to toggle active/bench
- Green border = active. Dark border = bench.
- Grinder bench players show "📚 Training" (XP gain). Others show "💤 Resting" (stamina recovery).
- Close with Done button.

### ResolutionScreen (Match Reveal)
Full-screen overlay. Events appear one at a time with timed delays:
- All active players appear in every act
- **Match breakdown section (new):** after VICTORY/DEFEAT, shows:
  - Opponent matchup result (countered / punished / even)
  - Situation coverage result (full / partial / none)

---

## Match System

### The Decision
Before every match, the player sees:
- **Opponent's 3 trait slots** — what style they play
- **Match situations (2–3)** — what the match rewards today

The player must pick 1–3 players whose **match traits** counter:
1. The opponent (primary — 60% weight)
2. The situations (secondary — 30% weight)

### Match Traits (used for strategic countering only)
Every player maps to a match trait based on their performance trait:

| Performance Trait | Match Trait |
|---|---|
| Clutch / Choker | Clutch |
| Grinder | Resilient |
| Lazy / Volatile | Aggressive |
| Consistent | Focused |
| None | Tactical |

### Match Trait Matrix (Pokémon-type model)

| Trait | Beats | Loses to |
|---|---|---|
| Aggressive | Focused | Tactical, Resilient |
| Tactical | Aggressive | Focused |
| Focused | Tactical, Clutch | Aggressive |
| Clutch | Resilient | Focused |
| Resilient | Clutch | Aggressive, Clutch |

### Match Situations

| Situation | Favors |
|---|---|
| 💥 Early Pressure | Aggressive |
| 🧩 Control Phase | Tactical |
| 🔬 Precision Phase | Focused |
| ⚡ Clutch Moment | Clutch |
| 🏃 Endurance Phase | Resilient |

### Resolution Formula
```
opponent_matchup   → 60%  (primary)
situation_coverage → 30%  (secondary)
stamina/morale     → 10%  (modifier)

combined → float modifier applied to opponent_score threshold
```
- Positive modifier = player advantage → effectively lowers the opponent score
- Negative modifier = disadvantage → raises it
- Range: ±20 points (≈15–20% of a typical mid-season score)

### Opponent Generation
- 3 trait slots drawn from the 5 match traits
- Seeded per season+week: consistent within a season, changes each season
- Harder opponents (dominant) get a biased pool (repeated traits = harder to fully counter)

### Edge Case Outcomes
| Scenario | Expected Result |
|---|---|
| Counter opponent, miss all situations | Narrow win (60% covered) |
| Miss opponent, cover all situations | Narrow loss (only 30% covered) |
| Neutral both sides | Stamina/morale decides — coin-flip feel |
| Counter both opponent + situations | Convincing win — reward the smart pick |

---

## Roster (5 players, 3 active each week)

| Player | Skill | Trait | Match Trait | Minor | Bio |
|---|---|---|---|---|---|
| Apex | 50 | Clutch | Clutch | Resilient | Thrives under pressure, drifts in routine |
| Byte | 43 | Grinder | Resilient | — | Slow start, relentless by mid-season |
| Ghost | 38 | Volatile | Aggressive | Fragile | Unplayable peak, invisible trough |
| Kira | 40 | Consistent | Focused | — | Never the hero, never the disaster |
| Rex | 35 | Lazy | Aggressive | — | Explosive when fresh, fades fast |

---

## Trait Icons (shown in all trait labels throughout the UI)

| Trait | Icon | Notes |
|---|---|---|
| Clutch / Choker | ⚡ / 😰 | Performance traits |
| Grinder | ⚙️ | Performance trait |
| Lazy | 💤 | Performance trait |
| Consistent | 🎯 | Performance trait + Focused match trait |
| Volatile | 🌀 | Performance trait |
| Aggressive (match) | 🗡️ | Match trait only |
| Tactical (match) | 🧠 | Match trait only |
| Focused (match) | 🎯 | Match trait only |
| Resilient (match) | 🛡️ | Match trait only |

---

## Bench Mechanic (Pokémon Blue farm style)

Benched players are not idle. Each week:
- **Grinder** → passive training: -5 stamina, +1 burnout, +XP
- **Everyone else** → rest: +15 stamina (+23 for Lazy), +morale, -2 burnout

---

## Player Stats

| Stat | Role |
|---|---|
| **Skill** | Match score ceiling. Grows on level-up only. |
| **Stamina** | Continuous drag on performance. Playing costs 13 (18 on important). Bench rest recovers 15. |
| **Focus** | Controls score variance. High = consistent. Low = chaotic. |
| **Morale** | Shifts after wins/losses. Affects form tracking. |
| **XP** | Earned from matches (main) and bench training (grinders only). |
| **Level** | 1–10. Level-up gives trait-weighted stat gains. |
| **Burnout** | Accumulates from playing/training. At ≥3: penalty on next important match. |
| **Hunger** | Decays after 3+ consecutive bench rest weeks. |

---

## Season Structure

24 weeks per season, up to 10 seasons. Opponent difficulty ×1.08 per season.

```
Weeks  1–6:   Early grind
Weeks  7–12:  Mid-season + tournament (week 12)
Weeks 13–18:  Late season
Weeks 19–24:  Finale — two final tournaments
```

---

## Goals

**Season goal**: Win N matches / Win a tournament / Get N players on a hot streak

**Quarter goal** (resets weeks 6, 12, 18): Win N / Go unbeaten / Hit a hot streak
Completion bonus: +10 morale + +50 XP to all active players.

---

## File Map

```
scenes/
  GameWorld.gd/.tscn       — hub: pre-match intel, squad cards, coaching voice, Next Week
  RosterScreen.gd/.tscn    — two-column squad selector, click-to-swap
  ResolutionScreen.gd/.tscn — sequenced match reveal + matchup debrief

scripts/
  data/
	Calendar.gd             — season template, difficulty scaling, opponent_name/traits/situations generation
	GameText.gd             — all strings, trait icons, situation labels, matchup verdicts
	MatchResult.gd          — minimal shim for SeasonGoalManager
	WeekResult.gd           — full week resolution container (now includes matchup data)

  managers/
	GameManager.gd          — squad management, advance_week() (wires TraitMatchup), get_week_context()
	PlayerMarket.gd         — market candidates, hire logic
	SeasonGoalManager.gd    — goal tracking, quarter bonuses
	MatchDispatcher.gd      — RETIRED stub

  player/
	Player.gd               — stats, XP, burnout, is_active, voice()

  systems/
	TraitMatchup.gd         — NEW: match trait matrix, opponent generation, matchup scoring
	IncidentEngine.gd       — RETIRED stub
	LevelSystem.gd          — XP, level-ups, stat growth
	MatchFlavorGenerator.gd — flavor from trait + performance
	Simulation.gd           — simulate_player / simulate_team

ui/
  theme.tres                — project-wide Button theme
  components/               — LEGACY (PlayerPanel, ResultRow, etc.) — not used, delete soon
```

---

## What Works Well

- Coaching voice reads actual player state — makes management feel human
- Bench is a strategic resource, not just a holding pen
- Resolution sequencing creates tension — you can't skip it
- Click-to-swap roster with swap hints — no ambiguity
- Stamina + XP bars visible everywhere without sub-screens
- Trait personality visible in flavor text before you commit
- **Pre-match intel** shows opponent traits + situations with icons — player can make a real counter-pick decision
- **Matchup debrief** in resolution explains why you won or lost in trait terms — teaches the system without a tutorial

---

## Balance Notes

- **Dominant trio risk**: Vary opponent trait distributions across the season. No trait should appear as opponent primary more than ~25% of weeks.
- **Situations must matter**: Occasionally generate matches where the opponent matchup is close to neutral. Situations decide those. Forces reading both every week.
- **Legibility**: Trait icons act as visual anchors — players will pattern-match icons before reading names. Consistent icon-to-trait mapping is load-bearing for learnability.

---

## Known Issues

- Market not wired to new hub yet (stub)
- `ui/components/` folder is dead legacy code — safe to delete
- `Main.gd/.tscn` are dead stubs kept to avoid UID orphan errors
- Resolution distributes narrative by index, not by actual per-act simulation
- Hub `_intel_box` node must be added to `GameWorld.tscn` (path: `UI/Root/Margin/VBox/MatchInfo/IntelBox`) — currently builds gracefully with null check if not present

---

## What's Next

1. Add `IntelBox` VBoxContainer to GameWorld.tscn scene tree
2. Wire PlayerMarket to the hub
3. Delete legacy `ui/components/` and `Main.gd/.tscn`
4. Per-act simulation (3 mini-sims instead of 1 split narratively)
5. Read mechanic (3+ consecutive play weeks → performance drop)
6. Calendar view on hub (next 6 weeks visible)
7. Season end awards ceremony
