# REFACTOR_PLAN.md — Esports Manager Mini

> Architectural roadmap for the next-phase refactor.
> Companion document to `DESIGN.md` (which describes *what the game does*).
> This document describes *how the code should be organised to scale*.

---

## Status

| Phase | State | Notes |
|---|---|---|
| **Phase A** — Foundation (signals + typed data) | ✅ Done | `SignalHub` autoload registered; verified clean parse. |
| **Phase B1** — `GameDirector` autoload + `GameManager` retired | ✅ Code complete | Manual: register `GameDirector` autoload in Project Settings (see B1 handover below). |
| **Phase B2** — Split `advance_week()` into `WeekResolver` phases | ✅ Done | `WeekResolver` static class created; `advance_week()` is now a thin orchestrator emitting 7 phase signals. Smoke test extended with per-phase invariant assertions. |
| **Phase B3** — Replace `pending_banner` poll with `SignalHub` signals | ✅ Done | `pending_banner` field + `compose_pending_banner()` deleted; `GameWorld` now listens to 4 SignalHub signals. |
| **Phase B4** — Bench/squad commands via signals | ✅ Done | `toggle_bench_action` emits `bench_action_changed`; `toggle_active` emits `squad_changed`; `GameWorld` + `RosterScreen` react reactively. |
| **Phase B5** — Migrate `Tuning.gd` → three split balance `.tres` resources | ✅ Done | `Balance` autoload exposes `match_balance` / `progression_balance` / `league_balance`. All call sites migrated. `Tuning.gd` deleted. |
| **Phase C** — Real state machines | ⏳ Pending | |
| **Phase D** — Folder restructure | ⏳ Pending | |

### Phase B1 handover (what landed, what to verify)

**Files created:**
- `res://systems/game_director.gd` — the autoload, replacing `GameManager`. Body of `advance_week()` is **moved verbatim** per your B2-deferred decision; the phased pipeline split lands in B2.
- `res://tests/smoke_test.gd` + `res://tests/smoke_test.tscn` — standalone scene that drives `GameDirector` through 24 weeks programmatically and asserts invariants per week (player stat ranges, squad size, league rank, synergy ledger consistency, `WeekResult` field sanity). Run via Scene → Run Specific Scene.

**Files deleted:**
- `res://scripts/managers/GameManager.gd` — retired per the plan.

**Files updated to use `GameDirector` instead of `GameManager`:**
- `res://scenes/GameWorld.gd` — dropped `_game` field, calls `GameDirector` directly throughout.
- `res://scenes/RosterScreen.gd` — same; `setup()` now takes no arguments.
- `res://scenes/ResolutionScreen.gd` — dropped unused `_game` field; `setup()` signature reduced to `setup(result: WeekResult)`.
- `res://ui/components/MarketOverlay.gd` — dropped `_game` field; `open()` takes no arguments.
- `res://ui/components/LeagueOverlay.gd` — dropped `game` parameter from `open()` and `_build_standings()`.
- `res://ui/components/PlayerCard.gd` — dropped unused `_game` parameter from `setup()`.

**Behaviour change:** none. `advance_week()` body is byte-for-byte the same logic; only the owning class changed.

**Verification:** `game_director.gd` parses clean in isolation. The 26 "GameDirector not declared" errors reported on consumer files are 100% expected and resolve the moment the autoload is registered (manual step below).

**Manual step required — register the autoload.** Same situation as `SignalHub`: `project.godot` is godotiq-protected. Open Project Settings → AutoLoad and add:
- Path: `res://systems/game_director.gd`
- Node Name: `GameDirector`
- Singleton: enabled

Once registered, run the smoke test (Scene → Run Specific Scene → `res://tests/smoke_test.tscn`). Expected output ends with `SMOKE TEST: ✅ PASS  (24 weeks, all invariants held)` and a per-week trace.

**Architectural decisions made during Phase B1:**
- **Pure singleton pattern.** UI scripts no longer hold a `_game` field. They read from `GameDirector` directly: `GameDirector.players`, `GameDirector.advance_week()`, etc. This is the end-state the plan describes.
- **`start_new_game()` extracted from `_init`/`_ready`.** Autoload `_ready()` calls `start_new_game()`, but the method is also re-callable so the smoke test can reset state cleanly. Future "New Game" button gets this for free.
- **`setup()`/`open()` signatures slimmed.** Five UI components used to take a `GameManager` parameter. Now they take only what they actually need from arguments (e.g. `WeekResult`), and read everything else from `GameDirector`. Fewer args = fewer call-site changes when the API drifts.
- **`pending_banner` left intact.** The plan says replace it with signals in B3, not B1. It still works as before — `GameDirector.pending_banner` is read by `GameWorld._show_banner_if_pending()` post-resolution.
- **Stale doc-comments referencing `GameManager` left alone.** `Calendar.gd`, `LeagueManager.gd`, `PlayerMarket.gd`, `SeasonGoalManager.gd`, and the Phase A typed-container files all have `# called by GameManager...` comments. These are non-functional and best swept during Phase D's folder reorganisation. Tracked here so they're not forgotten.

### Phase B5 handover (what landed, what to verify)

**Files created:**
- `res://systems/balance.gd` — the new `Balance` autoload. Loads the three `.tres` resources in `_ready()` and exposes them as `match_balance` / `progression_balance` / `league_balance`. No logic, just typed access.
- `res://resources/balance/match_balance.tres` — hand-authored, populated with all match-feel constants from the old `Tuning.gd`.
- `res://resources/balance/progression_balance.tres` — hand-authored, only `quarter_bonus_morale` and `quarter_bonus_xp` populated. The XP/level fields on the resource are declared but NOT populated; `LevelSystem.gd` still owns those constants. See decisions below.
- `res://resources/balance/league_balance.tres` — hand-authored, populated with NPC strength range, season ramp, and end-of-season tier rewards.

**Files updated (Tuning.X → Balance.<domain>.x migration):**
- `res://scripts/systems/WeekResolver.gd` — stamina cost, morale deltas, bench rest/train/study constants.
- `res://scripts/systems/Simulation.gd` — counter penalty/bonus, situation coverage, study charge bonus, study flat skill bonus.
- `res://scripts/systems/MetaPatch.gd` — patch cycle weeks, buff/nerf percentages.
- `res://scripts/systems/Synergy.gd` — threshold, bonus per pair, stack diminish.
- `res://scripts/managers/LeagueManager.gd` — NPC strength constants and end-of-season tier rewards.
- `res://scripts/managers/SeasonGoalManager.gd` — quarter bonus morale and XP (4 sites).
- `res://systems/game_director.gd` — counter / coverage / study constants in the preview helpers.
- `res://scenes/ResolutionScreen.gd` — burnout warning threshold.
- `res://ui/components/PlayerCard.gd` — burnout warning threshold (squad + bench variants).
- `res://tests/smoke_test.gd` — same constants for invariant checks.

**Files deleted:**
- `res://scripts/data/Tuning.gd` — retired per the plan.

**Behaviour change:** none. Every constant value was copied verbatim into the matching `.tres` field.

**Manual step required — register the autoload.** Same situation as `SignalHub` / `GameDirector`: `project.godot` is godotiq-protected. Open Project Settings → AutoLoad and add:
- Path: `res://systems/balance.gd`
- Node Name: `Balance`
- Singleton: enabled

**Autoload order matters.** `Balance` must come BEFORE `GameDirector` in the autoload list, because `GameDirector._ready()` runs the smoke-test path which immediately calls into systems that read `Balance.match_balance.*`. Suggested order: `GodotIQRuntime` → `SignalHub` → `Balance` → `GameDirector`.

**Architectural decisions made during Phase B5:**
- **`Balance` autoload, not `GameDirector` properties.** The plan's wording "`GameDirector` exposes them as `match_balance` properties" is one possible singleton; `Balance` is another. We chose a dedicated autoload because: (1) `Simulation`, `MetaPatch`, `Synergy` are pure-static classes already coupled to a global (`Tuning`), and `Balance` is the smallest call-site diff; (2) it keeps `GameDirector` focused on game state instead of accumulating "things hanging off it"; (3) it mirrors the `SignalHub` pattern (vocabulary autoload, no logic).
- **`match_balance` / `progression_balance` / `league_balance` (suffixed) names.** `match` is a reserved keyword in GDScript (the `match` statement). The suffix is mandatory, not stylistic.
- **ProgressionBalance is partially populated.** Only the two quarter-bonus fields are read by runtime code. The XP / level-threshold / level-up-base fields exist on the resource but are not yet wired — `LevelSystem.gd` still owns those constants. Migrating LevelSystem is out of B5's scope (the plan explicitly scopes B5 to `Tuning.gd`). Future work: a dedicated phase to migrate LevelSystem.gd's constants into the resource and rewrite the static functions to read from `Balance.progression_balance`.
- **Hot reload works.** Editing any `.tres` value in the inspector and saving causes Godot to reload the resource; the next frame's `Balance.match_balance.X` read sees the new value. This is the practical win the refactor was after.
- **Smoke test was migrated despite "forget tests".** Three Tuning references in `smoke_test.gd` would have caused a parse error after deleting `Tuning.gd`. The references were swept mechanically; smoke test correctness is not a B5 concern.

### Phase B4 handover (what landed, what to verify)

**Files updated:**
- `res://systems/game_director.gd` — `toggle_bench_action()` now emits `SignalHub.bench_action_changed(player, action)` after mutating. `toggle_active()` now emits `SignalHub.squad_changed(active, benched)` after mutating. `set_active()` is unchanged (used internally by `toggle_active`; does not emit — the outer call owns the signal).
- `res://scenes/GameWorld.gd` — `_ready()` connects to `bench_action_changed` and `squad_changed`. `_on_bench_toggle()` no longer calls `_refresh_ui()` directly. Two new handlers: `_on_bench_action_changed` (refreshes squad display only) and `_on_squad_changed` (full `_refresh_ui`).
- `res://scenes/RosterScreen.gd` — `_ready()` connects to `squad_changed` and `bench_action_changed`. `_on_card_clicked()` replaced with a single `GameDirector.toggle_active(name)` call (the signal drives `_build()`). Bench toggle lambda no longer calls `_build()` directly. Dead `_find_player()` helper removed.

**Behaviour change:** none. The same mutations happen; the display updates are now driven by signal instead of explicit post-call refreshes.

**Verification:** parse check passes. Bench toggle in hub and roster both update correctly. Squad toggle in roster updates the active/bench columns and the hub's end-week button validity.

**Architectural decisions made during Phase B4:**
- **`set_active` does NOT emit `squad_changed`.** It's a building block called by `toggle_active` (and previously by `RosterScreen` directly). Having the inner function emit would double-fire signals when `toggle_active` calls it. Only the public command entry points emit.
- **`_on_bench_action_changed` does a partial refresh** (`_refresh_squad_display` only, not `_refresh_ui`). Bench action change doesn't affect the intel panel, week label, goal label, or button validity — so a full redraw would be wasteful. This is the "only the affected area" goal from the spec, applied at the scene level.
- **`_on_squad_changed` does a full `_refresh_ui`** because the end-week button validity depends on squad size, and the intel panel's prognosis colours depend on which traits are active.
- **`is_inside_tree()` guard in `RosterScreen` handlers.** The screen is instantiated on demand and freed on close. Without the guard, a `squad_changed` signal emitted while the roster is closed (e.g. from the hub bench toggle) would call `_build()` on a freed node.

### Phase B3 handover (what landed, what to verify)

**Files updated:**
- `res://systems/game_director.gd` — `pending_banner` field deleted. In `advance_week()`, the `compose_pending_banner()` call is replaced by direct `SignalHub` emissions: `quarter_bonus_triggered`, `goal_achieved`, `patch_rotated`, `season_ended`. `season_ended` captures `league.player_rank()` before the season reset runs. No new fields, no new state.
- `res://scripts/systems/WeekResolver.gd` — `compose_pending_banner()` static function deleted (was phase 7b). WeekResolver is now exactly 7 phase functions + private helpers.
- `res://scenes/GameWorld.gd` — `_show_banner_if_pending()` poll removed. `_on_resolution_finished()` no longer calls it. Four signal connections added in `_ready()`: `goal_achieved`, `quarter_bonus_triggered`, `patch_rotated`, `season_ended`. Each calls `_show_banner(text)`, a one-liner that sets `_banner_label.text` and shows `_goal_banner`.

**Files unchanged:** `signal_hub.gd` — all four signals were already declared in Phase A (`goal_achieved`, `quarter_bonus_triggered`, `patch_rotated`, `season_ended`). No changes needed.

**Behaviour change:** none. The same banner text is produced from the same data — only the delivery mechanism changed from poll-after-resolution to emit-during-resolution.

**Verification:** parse check passes. Banner still shows for: quarter bonus, season goal completion, patch rotation, and season end. `GameDirector` has no `pending_banner` field; any access will be a parse error (good — catches stale references).

**Architectural decisions made during Phase B3:**
- **`season_ended` captures rank before reset.** `league.player_rank()` is called before `league.reset_for_season()`, then passed to `SignalHub.season_ended.emit(rank, description)`. The old `compose_pending_banner` had no `season_ended` path — it was handled implicitly by the `goals_checked` phase. Now it's explicit.
- **`_show_banner()` is a private one-liner.** Each signal handler composes its own text and delegates display to `_show_banner(text)`. This avoids duplicating the `label.text = …; banner.show()` pattern in 4 handlers.
- **`_goal_banner` is NOT hidden on resolution.** The old `_show_banner_if_pending()` used to hide the banner if the string was empty. The new pattern never hides it from the signal path — hiding is only done by `_on_banner_dismissed()` (user tap) and implicitly by the next `_refresh_ui()` cycle. This is cleaner: the banner persists until dismissed.

### Phase B2 handover (what landed, what to verify)

**Files created:**
- `res://scripts/systems/WeekResolver.gd` — stateless static class with seven phase functions: `resolve_bench`, `generate_match_context`, `simulate_match`, `apply_post_match_effects`, `award_xp`, `check_goals`, `rotate_systems_if_season_end`. Plus a helper `compose_pending_banner` that B3 will retire.
- `res://scripts/data/MatchContext.gd` — typed bundle of per-week match parameters (calendar entry, opponent, situations, importance flag, opponent score, active patch). Lives between phase 2 and phase 3 of the pipeline.

**Files updated:**
- `res://systems/signal_hub.gd` — added 7 phase signals: `bench_resolved`, `match_context_generated`, `match_simulated`, `post_match_applied`, `xp_awarded`, `goals_checked`, `season_rotated`.
- `res://systems/game_director.gd` — `advance_week()` rewritten as a thin orchestrator (~75 lines, was ~120). Calls each `WeekResolver` phase in order, populates `WeekResult` from each phase's return value, emits the matching `SignalHub` signal between calls. Dead helpers (`_resolve_bench`, `_update_streaks`, `_apply_match_stamina_cost`, `_apply_morale`, `_apply_with_dr`) removed — their bodies now live in `WeekResolver`. File total dropped from 611 to 476 lines.
- `res://tests/smoke_test.gd` — connects to all 7 phase signals, asserts per-phase invariants as each phase fires, plus a phase-trace assertion at end-of-week verifying the canonical phase order. End-to-end checks unchanged. Added a `VERBOSE_PHASES` constant for opt-in detailed tracing.

**Behaviour change:** none. The pipeline produces the same outputs as B1; only the structure changed. Smoke test should still pass with the same per-week trace as before.

**Verification:** all 40 scripts parse clean. `_apply_with_dr` clamp fix (the W3 stamina=102 bug) is preserved in the resolver's copy of the helper.

**Architectural decisions made during Phase B2:**
- **Option 3 emission pattern.** `WeekResolver` is genuinely pure — no `SignalHub` import, no signal emissions. `GameDirector.advance_week()` calls each phase and emits the matching signal. Resolver is testable in isolation; the orchestration layer owns the signal vocabulary.
- **Granular signals (one per phase).** Per your decision. Listeners can hook into specific phases without parsing a phase-name string. `signal_hub.gd` now declares 23 signals total (15 from A1 + B-related additions including the 7 phase signals here).
- **`MatchContext` is RefCounted, not Resource.** Same reasoning as `BenchOutcome`/`MatchOutcome`/`HubContext`: per-call throwaway, never authored as `.tres`.
- **Phase 4 takes the FULL roster (`active + benched`), not just active.** `league.apply_season_result(players)` rewards every player on the roster, not just active. Earlier draft tried to keep Phase 4 active-only and let `GameDirector` apply rewards itself — ugly. Final design passes `players` through cleanly. Resolver phase signatures are now self-contained.
- **`compose_pending_banner` is a temporary phase 7b.** B3 will replace it with reactive `SignalHub` emissions. Keeping it as a static function in `WeekResolver` for now means there's exactly one place to delete in B3.
- **`_win_estimate` and `_preview_counter_ratio` stay in `GameDirector`.** They're PRE-match preview helpers used by `get_week_context()`, not resolution-pipeline phases. Could move to a future `MatchPreview` static class in Phase D, not now.
- **RNG location preserved.** The single `randi_range(-10, 10)` call (opponent score wiggle) stays inside `WeekResolver.generate_match_context`. Moving it would change the seed sequence and produce a different smoke-test trace.

**Smoke test additions:**
- 7 new signal handlers, one per phase, asserting phase-local invariants (action validity, counter_mult range, study charge consumption, level/xp ranges, etc.).
- `_assert_phase_trace` cross-checks that the 7 phases emitted in the canonical order, every week. A missing or out-of-order phase fails this check by name.
- `VERBOSE_PHASES` constant: set `true` for a per-phase trace line (debugging), `false` for the original quiet output.
- Same 24-week duration. Run `Scene → Run Specific Scene → res://tests/smoke_test.tscn`.

**Pipeline now reads top-to-bottom in `advance_week()`:**
```
resolve_bench           → SignalHub.bench_resolved
generate_match_context  → SignalHub.match_context_generated
simulate_match          → SignalHub.match_simulated
apply_post_match_effects→ SignalHub.post_match_applied
award_xp                → SignalHub.xp_awarded
check_goals             → SignalHub.goals_checked
rotate_systems_if_season_end → SignalHub.season_rotated
week_advanced + match_resolved (final lifecycle signals)
```

### Phase A handover (what landed, what to verify)

**Files created (15 scripts, no behaviour change):**
- `res://systems/signal_hub.gd` — the autoload, 15 signals declared, 0 emitters/listeners
- `res://resources/archetype/archetype_definition.gd` + `archetype_growth.gd` — typed home for the 6 archetypes
- `res://resources/calendar/week_template.gd` — typed week schedule entry
- `res://resources/market/player_archetype.gd` — typed market candidate template
- `res://resources/player/player_data.gd` — typed starter-roster authoring
- `res://resources/meta/meta_patch_effect.gd` — typed hand-authored patch (future use)
- `res://resources/balance/match_balance.gd` — skeleton, **no values yet** (B5 fills these)
- `res://resources/balance/progression_balance.gd` — skeleton, **no values yet**
- `res://resources/balance/league_balance.gd` — skeleton, **no values yet**
- `res://scripts/data/BenchOutcome.gd`
- `res://scripts/data/PlayerMatchOutcome.gd`
- `res://scripts/data/MatchOutcome.gd`
- `res://scripts/data/HubContext.gd`

**Verification:** all 37 project scripts parse clean (`godotiq_check_errors` returned 0 errors after a `phase: ""` → `phase: "none"` fix in `archetype_definition.gd` — `@export_enum` rejects empty strings).

**Manual step required — register the autoload.** `project.godot` is godotiq-protected, so this one line cannot be auto-applied. Open Project Settings → AutoLoad and add:
- Path: `res://systems/signal_hub.gd`
- Node Name: `SignalHub`
- Singleton: enabled

Until this is done, `SignalHub.<signal>.emit(...)` calls (added in Phase B) will fail. The Phase A files themselves are self-contained and don't depend on the autoload being registered yet.

**Naming decisions made during Phase A (worth recording):**
- `phase` enum on `ArchetypeDefinition` uses `"none" | "early" | "mid" | "late"` (not `""`) because GDScript's `@export_enum` doesn't accept empty strings as options.
- `PlayerArchetype` (market) and `ArchetypeDefinition` (gameplay identity) are intentionally separate — the former describes a market candidate template, the latter describes the gameplay identity itself. The market resource references the definition: `PlayerArchetype.primary: ArchetypeDefinition`.
- All resource scripts are marked `@tool` so they edit cleanly in the inspector.
- `BenchOutcome` and `PlayerMatchOutcome` are `RefCounted`, not `Resource`, because they're per-match throwaway containers that don't need to be serialized as `.tres`. `WeekResult` already follows this pattern.

---

> Architectural roadmap for the next-phase refactor.
> Companion document to `DESIGN.md` (which describes *what the game does*).
> This document describes *how the code should be organised to scale*.

---

## Naming Reservations

GDScript 4.x reserves certain identifiers, and this project has class names we need to retire rather than reuse. The plan below uses the following replacements; treat these as **the canonical names** when writing code from this plan.

| Concept | Avoid (reserved or in-use) | Use instead |
|---|---|---|
| Global signal autoload | `EventBus` | **`SignalHub`** |
| Long-lived game-state autoload | `GameManager` (existing class, will be retired) | **`GameDirector`** |
| Per-archetype data class | `TraitDefinition` (`trait` is reserved) | **`ArchetypeDefinition`** |
| Player-stored archetype reference | `primary_trait` (legacy field name on `Player`) | **`primary_archetype`** (going forward) |

**Note on display copy:** the reservation bites on *identifiers*, not on user-facing strings. Labels like "Aggressive trait", "trait counters", and "What countered what" can stay exactly as they are in `GameText.gd` — only Godot symbol names need renaming.

**Note on the existing `GameManager.gd` file:** the file is being **retired**, not augmented. Its responsibilities split between `GameDirector` (state ownership) and `WeekResolver` (turn orchestration). Plan to delete `scripts/managers/GameManager.gd` at the end of Phase B.

---

## Glossary — Old Names → New Names

For find-and-replace and code review checklists.

| Old | New | Why |
|---|---|---|
| `class_name GameManager` | `class_name GameDirector` (as autoload) + `class_name WeekResolver` (stateless helper) | Splits god-object into ownership vs orchestration |
| `Tuning.gd` | `MatchBalance.tres` + `ProgressionBalance.tres` + `LeagueBalance.tres` | Hot-reloadable, inspector-editable, per-domain |
| `primary_trait: String` (on `Player`) | `primary_archetype: ArchetypeDefinition` | Typed reference instead of string tag |
| `minor_trait: String` / `minor_trait_2: String` | `minor_archetypes: Array[ArchetypeDefinition]` | Same reasoning, plus collapses the two-slot duplication |
| `bench_action: String` | `bench_action: BenchAction` (enum) + `BenchActionStrategy` resource | Real states, real strategies |
| `match_type: String` | `MatchType` (enum) | Typo-proof |
| `WEEK_TEMPLATE: Array` (in `Calendar.gd`) | `Array[WeekTemplate]` (loaded from `.tres`) | Authorable in editor |
| `ARCHETYPES: Array` (in `PlayerMarket.gd`) | `Array[PlayerArchetype]` (loaded from `.tres`) | Authorable in editor |
| `_resolve_bench()` returns `Dictionary` | returns `BenchOutcome: Resource` | Typed |
| `Simulation.simulate_team()` returns `Dictionary` | returns `MatchOutcome: Resource` | Typed |
| `get_week_context()` returns `Dictionary` | returns `HubContext: Resource` | Typed |
| `pending_banner: String` | `SignalHub.goal_achieved` / `patch_rotated` / `season_ended` signals | Reactive, not polled |

---

## 1. High-Level Architectural Critique

The codebase is **healthier than it looks for its size**, but it has hit a structural ceiling that will hurt as features multiply (Synergy, MetaPatch, and per-player `study_charges` are recent additions that already strain the seams). Seven core problems:

### a) `GameManager` is a god-object orchestrator (571 lines, 22 KB)

`advance_week()` alone is ~120 lines and personally executes: patch lookup, league sim, bench resolution, opponent generation, matchmaking, simulation, study-charge consumption, league recording, streak updates, stamina cost, morale, XP awards, level-ups, goal checks, season reset, week advancement, **and** banner composition. Any new feature (injuries, contracts, training intensity, sponsorships) currently has exactly one place it can land — by adding more lines here.

### b) Tight coupling via direct references rather than signals

Every system holds a hard reference to its collaborators. `GameWorld` holds a `GameManager`, which holds a `LeagueManager`, `PlayerMarket`, `SeasonGoalManager`, and `Synergy`, and pokes their methods directly. The UI calls `_game.toggle_bench_action()` then `_refresh_ui()` — that's pull-based, not event-based. When `advance_week()` finishes, nothing **emits** `match_resolved`; instead the UI knows to read `pending_banner` afterward. This is the single biggest scalability blocker.

### c) The "manager" pattern is doing what `Resource` and `Node` should do

Everything is `RefCounted` instead of either:
- **Pure data** that should be a `Resource` (`Player`, `WeekResult`, archetypes in `PlayerMarket.ARCHETYPES`, the `WEEK_TEMPLATE`, opponent definitions, archetype definitions in `TraitMatchup`), or
- **Long-lived gameplay objects** that should be `Node` (the global game state, the league, the goal tracker, the synergy ledger).

Players, archetypes, and weeks are all just typed dictionaries today. Converting them to `Resource` unlocks the inspector, `.tres` files, drag-and-drop assignment, and hot-reloading of balance — the entire reason `Tuning.gd` exists is to compensate for this absence.

### d) "States" are stringly-typed enums

`bench_action` is `"rest"|"train"|"study"`, `match_type` is `"normal"|"important"|"tournament"|"solo"`, `primary_trait` is one of six strings, `morale_key()` returns `"confident"|"neutral"|"shaky"`. Every consumer does `match` or `if … in […]`, which means a typo silently fails and renaming a state requires a project-wide grep. There is no actual state-machine behaviour here — these are tag enums, not states — but the naming convention has masked that, and the scattered `match` blocks **simulate** a state machine without enforcement.

The one place a real state machine would help is **`ResolutionScreen`** (419 lines), which manually drives an `_index`/`_timer`/`_running` queue through eight event types via giant `match` blocks. That is a state machine, written longhand.

### e) UI scripts contain layout logic and tight scene-tree paths

`GameWorld._build_match_intel()` instantiates `Label` and `HBoxContainer` nodes by hand and applies theme overrides inline. `PlayerCard._add_bench_extras()` does the same. `MarketOverlay._on_candidate_selected()` builds the entire confirmation button row imperatively. The pattern is: scripts inherit `extends Control`, use `@onready` paths that drill seven levels into the scene (`$OuterMargin/VBox/ContentRow/RosterColumn/RosterList`), and rebuild children every refresh. Renaming a single container in the `.tscn` breaks the script silently. There's also a swallowed bug here: the **tooltip for an archetype** is defined in `GameText.TRAIT_TOOLTIPS` but no UI script reads it.

### f) Data coupling through magic-string Dictionaries

`get_week_context()` returns a `Dictionary` with 16 string keys, and every UI consumer calls `.get("opponent_traits", [])` with its own defaults. `WeekResult` already exists as a typed container — that's the right pattern — but the hub `ctx` object is its untyped twin. Same problem in `simulate_team`'s return dict and `_resolve_bench`'s outcome dict. Each is a `WeekResult` waiting to happen.

### g) Minor: file/folder structure is flat where it should be feature-grouped

`scripts/managers/` lumps `GameManager` (orchestrator) with `LeagueManager`, `PlayerMarket`, `SeasonGoalManager` (subsystems). `scripts/systems/` mixes pure-function utilities (`Simulation`, `TraitMatchup`, `LevelSystem`) with stateful systems (`Synergy`). `scripts/data/` mixes static lookup tables (`Calendar`, `GameText`, `Tuning`) with mutable state containers (`WeekResult`). After three more features this ambiguity compounds.

---

## 2. Refactor Checklist

Each step is structured so it leaves the project in a working state and unblocks the next step. **Do not skip ahead** — early steps create the seams later steps need to slot into.

> **Note on `Tuning.gd` migration.** Originally planned for Phase A, the migration has been moved to Phase B (step B5). Reason: a hot-reloadable `BalanceResource` only works once `GameDirector` exists to load and expose it. Phase A creates the resource *types*; Phase B wires them in.

### Phase A — Foundation: introduce events and typed data (no behaviour change)

> Goal: make it possible to listen instead of poll, and make it possible to define content as `.tres` instead of code. No gameplay logic moves yet.

#### A1. Create the `SignalHub` autoload *(blocks A2, B1, B3, C1, C2)*

A new `res://systems/signal_hub.gd` registered as autoload `SignalHub`, containing the project's vocabulary of signals only — no logic. Initial signal list, derived from what `GameManager` and the UI currently push and pull around:

- `week_advanced(week_result)`
- `roster_changed(players)`
- `squad_changed(active, benched)`
- `bench_action_changed(player, action)`
- `study_charge_gained(player, charges)`
- `study_charge_consumed(player, charges)`
- `match_resolved(week_result)`
- `level_up(player, new_level)`
- `goal_achieved(description)`
- `quarter_bonus_triggered(description)`
- `patch_rotated(buffed_archetype, nerfed_archetype)`
- `synergy_formed(name_a, name_b)`
- `market_opened()`
- `market_hire(replaced_player, hired_player)`
- `season_ended(rank, description)`

**No code listens to these yet.** This step is purely declarative.

#### A2. Define typed `Resource` classes for content data *(blocks A3, B2, B5, C2)*

Replace the implicit dictionary types with proper `Resource` subclasses. Order, smallest first:

- **`ArchetypeDefinition`** (replaces the 6-archetype constants in `TraitMatchup` + scattered tables in `GameText`/`LevelSystem`/`Simulation`):
  - `key: StringName`, `display_name: String`, `icon: String`, `tooltip: String`
  - `counters: Array[ArchetypeDefinition]`, `weak_to: Array[ArchetypeDefinition]`
  - `phase: String`, `variance_modifier: int`, `stamina_floor: float`
  - `growth: ArchetypeGrowth` (sub-resource: skill/stamina/focus/morale bonuses)
  - The fact that "archetype identity" is currently spread across **five** files is the strongest signal this is needed.
- **`WeekTemplate`** (replaces `Calendar.WEEK_TEMPLATE` dicts):
  - `match_type`, `opponent_score`, `difficulty_label`
- **`PlayerArchetype`** (replaces `PlayerMarket.ARCHETYPES`):
  - `names: Array[String]`, `primary: ArchetypeDefinition`, `minor: String`
  - `skill_range: Vector2i`, `focus_range: Vector2i`, `stamina_range: Vector2i`, `morale_range: Vector2i`
  - `bio: String`
- **`PlayerData`** (replaces `Player.gd`'s data fields, leaving `Player.gd` to extend it with runtime state and behaviour). Optional but recommended — lets you author the starting roster as `.tres` files instead of in `GameDirector._init`.
- **`MetaPatchEffect`** for future patches you may want hand-authored instead of seeded.

**Balance resource skeletons (no values yet — values migrate in B5):**

- `MatchBalance.gd` — stamina costs, morale deltas, counter penalty/bonus caps, situation coverage bonus, study-charge mechanics, burnout threshold
- `ProgressionBalance.gd` — XP rewards, level thresholds, level-up stat growth, quarter bonus values
- `LeagueBalance.gd` — NPC strength range, season ramp, hard cap, end-of-season tier rewards

#### A3. Convert ad-hoc result dictionaries to `Resource` containers *(blocks B1, C1)*

- Promote `_resolve_bench()`'s return dict to a `BenchOutcome` resource.
- Promote `Simulation.simulate_team`'s return dict to a `MatchOutcome` resource (and `simulate_player`'s to `PlayerMatchOutcome`).
- Promote `get_week_context()` to a `HubContext` resource.
- `WeekResult` already exists — keep it; the others fold into it cleanly.

---

### Phase B — Decouple via signals and split the god-object

> Goal: `GameManager` stops doing everything personally; subsystems own their domain and emit when state changes. The file `scripts/managers/GameManager.gd` is deleted at the end of this phase.

#### B1. Introduce a `GameDirector` autoload that holds the long-lived references *(blocks B2, B3, B4, B5, C1)*

A new `GameDirector` autoload owns `players`, `week`, `synergy`, `league`, `market`, `goal_manager`. The current `GameManager.new()` flow becomes `GameDirector.start_new_game()`. UI scripts stop being passed `_game` references and read from `GameDirector` directly. This is the smallest change that breaks the chain of pointers from `GameWorld → GameManager → LeagueManager → …`.

#### B2. Extract the season/week orchestration into a `WeekResolver` *(blocks B3, B5)*

`advance_week()` moves out of `GameManager` (now `GameDirector`) into a stateless `WeekResolver` that takes the state as input, runs the resolution pipeline as a sequence of small phases, and emits the appropriate `SignalHub` signal at each phase boundary:

1. `resolve_bench`
2. `generate_match_context`
3. `simulate_match`
4. `apply_post_match_effects`
5. `award_xp`
6. `check_goals`
7. `rotate_systems_if_season_end`

Each phase becomes a method ≤ 30 lines, in dependency order, with no shared mutable state beyond the `WeekResult` accumulator.

#### B3. Replace the `pending_banner` poll with a signal *(blocks B4)*

Today: `advance_week()` writes `pending_banner`, then `GameWorld` reads it after `_on_resolution_finished()`. Replace with `SignalHub.goal_achieved` / `SignalHub.patch_rotated` / `SignalHub.season_ended`, which `GameWorld` connects to in `_ready()`. Banner display becomes purely reactive. Remove `pending_banner` from `GameDirector`.

#### B4. Move bench-action and squad-toggle commands behind signals *(blocks C1)*

`_on_bench_toggle()` currently calls `_game.toggle_bench_action()` then `_refresh_ui()`. After: the card emits `bench_toggle_pressed`, a thin command handler in `GameDirector` mutates the player and emits `SignalHub.bench_action_changed`, and `GameWorld` re-renders only the affected card from a connected slot. This is the seam UI scaling needs.

#### B5. Migrate `Tuning.gd` constants to the three split balance resources *(blocked by B1, B2)*

Now that `GameDirector` exists and `WeekResolver` reads from it, port `Tuning.gd` constants into the three resource skeletons created in A2:

- `MatchBalance.tres` — STAMINA_COST_*, MORALE_*, BENCH_*, BURNOUT_*, COUNTER_*, SITUATION_COVERAGE_*, PATCH_*, SYNERGY_*
- `ProgressionBalance.tres` — XP_*, LEVEL_THRESHOLDS, LEVEL_UP_*, TRAIT_GROWTH (renamed `ARCHETYPE_GROWTH`), QUARTER_BONUS_*
- `LeagueBalance.tres` — NPC_STRENGTH_*, NPC_SEASON_RAMP_*, LEAGUE_TOP_*, LEAGUE_BOT_*

`GameDirector` exposes them as `match_balance`, `progression_balance`, `league_balance` properties. All call sites change from `Tuning.STAMINA_COST_NORMAL` to `GameDirector.match_balance.stamina_cost_normal`. Delete `scripts/data/Tuning.gd`.

**Split rationale:** match-feel tuning (stamina, morale, counters) gets touched on every balance pass; progression curves get touched once per major content update; league rewards are essentially write-once. Splitting them lets each domain be edited without diffing the others.

---

### Phase C — Replace stringly-typed states with real state machines

> Goal: where a state machine actually exists, make it explicit and inspectable.

#### C1. Introduce a `BenchAction` state machine *(blocks D1)*

The `rest|train|study` cycle has three real states with three different `_resolve_bench` branches and three different UI labels — that's a state machine pretending to be a string. Convert to either:

- a typed `enum BenchAction { REST, TRAIN, STUDY }` (lightweight), or
- a node-based `StateMachine` child on a future `PlayerNode` (heavyweight, only worth it if Phase D2 happens).

**Recommend the enum first**, with a `BenchActionStrategy` resource per state holding `apply(player) -> BenchOutcome` so behaviour is data-driven and `WeekResolver._resolve_bench` becomes a one-liner.

#### C2. Convert `ResolutionScreen` to a real state machine *(no blocker)*

The 419-line resolution sequencer is the clearest state-machine candidate in the codebase: it has an `_events` queue, an `_index`, a `_timer`, eight event types each with their own reveal logic, and `_running` flips between active and idle. Refactor into a `ResolutionStateMachine` driven by event subclasses (one resource type per reveal, e.g. `HeaderReveal`, `BenchReveal`, `ActHeaderReveal`, `PlayerActReveal`, …), each with a `play(label_factory) -> float` returning its own pacing. This both shrinks the file and lets you add new reveal types without touching the master `_reveal_event` `match` block.

#### C3. Replace string-tags for archetypes, match types, and stamina/morale buckets with enums *(no blocker)*

`primary_archetype` (currently `primary_trait` string), `match_type`, `stamina_key()`, `morale_key()` all become `enum`s with helper methods on the relevant `Resource` (`ArchetypeDefinition.from_enum()` etc.). This is mostly mechanical but pays off in autocomplete, error messages, and the death of `match` typo bugs.

---

### Phase D — Restructure for feature growth (optional but recommended)

> Goal: the project layout matches the mental model of a tycoon game's domains, so the next ten features have obvious homes.

#### D1. Reorganise folders by domain, not by file type

Move from `scripts/{data,managers,systems,player}` to:

```
res://
  systems/        # autoloads: signal_hub.gd, game_director.gd
  features/
	roster/       # PlayerData, PlayerNode, BenchAction, Synergy
	matches/      # WeekResolver, Simulation, TraitMatchup, MatchOutcome
	league/       # LeagueManager, standings UI
	market/       # PlayerMarket, archetypes
	goals/        # SeasonGoalManager, quarter goals
	meta/         # MetaPatch, Calendar, WeekTemplate
  resources/      # .tres files: ArchetypeDefinition, PlayerArchetype, WeekTemplate, balance resources, starter players
  ui/             # unchanged; scenes consume features via SignalHub
  data/           # GameText (stays as static lookup; Tuning is gone after B5)
```

#### D2. Promote `Player` from `RefCounted` to a `Node` with a `PlayerData: Resource`

Optional. Worth it if you later add per-player animations, a 3D portrait scene, or per-player tooltips with their own state. Until then, `RefCounted` + `PlayerData` is fine. **Flag this for re-evaluation, don't do it speculatively.**

#### D3. Document the new architecture in `DESIGN.md`

A short section listing the autoloads, the phase pipeline of `WeekResolver`, the signal vocabulary on `SignalHub`, and the resource types. Future-you and any collaborator will save hours.

---

## Suggested Cadence

- **Phase A** is ~2 sessions of work and ships in one PR each (A1, A2, A3 are independent enough). Zero behaviour change — diff-friendly.
- **Phase B** is the highest-value phase and the riskiest; budget time and add tests/asserts at the `WeekResolver` phase boundaries before touching `advance_week`. B5 (Tuning migration) is the sign-off step that lets the file be deleted.
- **Phase C** can be picked up incrementally — C2 (`ResolutionScreen`) is a self-contained quick win, do it first if morale is low.
- **Phase D** is a "when next feature lands" refactor, not a today refactor.

---

## Design Tensions

### 1. `Tuning.gd` vs `Resource` — **RESOLVED**

> **Decision:** Migrate to three split balance resources (`MatchBalance.tres`, `ProgressionBalance.tres`, `LeagueBalance.tres`) in step B5. Keep `GameText.gd` as a static lookup module — it's display strings, not gameplay numbers, and authoring those in `.tres` would slow down iteration without benefit.

### 2. `SignalHub` vs direct calls — **GUIDANCE**

Don't route literally everything through the bus. Pure queries (`league.player_rank()`, `synergy.is_synergized(a, b)`) stay as direct method calls — signals are for *state changes that multiple unrelated systems care about*. The signal list in A1 is deliberately conservative.

### 3. Synergy stacking in a 3-player squad — **RESOLVED**

> **Decision:** Stack with diminishing returns (per Tuning's `SYNERGY_STACK_DIMINISH = 0.7`). Already implemented in current code; no refactor work needed beyond carrying the constant into `MatchBalance.tres` in step B5.

---

## Decisions Log

Tracking design choices made during refactor planning, so future-me has the *why* not just the *what*.

| Date | Question | Decision | Rationale |
|---|---|---|---|
| Initial | Counter penalty severity (50% / 30% / scaling) | **Open — not decided** | User has not yet confirmed; current code uses 50% as default. Revisit when Phase B5 lands and balance resources become editable. |
| Initial | Synergy stacking in 3-squad | Stack with diminishing returns | Decisive but not match-breaking; matches existing implementation. |
| Plan v1 | Plan file location | `REFACTOR_PLAN.md` at project root | Sits next to `DESIGN.md`, easy to find. |
| Plan v1 | Balance resource scope | Split into three (`MatchBalance`, `ProgressionBalance`, `LeagueBalance`) | Each domain has a different edit cadence; splitting reduces diff noise. |
| Plan v1 | Replacement name for `GameManager` autoload | `GameDirector` | Suggests authority and orchestration, distinct from the retired class name. |
| Plan v1 | Reserved-word handling | Use `SignalHub`, `GameDirector`, `ArchetypeDefinition` for identifiers; keep "trait" wording in display copy | GDScript's `trait` reservation only affects identifiers; display strings unaffected. |

---

## Open Questions

These need answers before or during the relevant phase. Listed here so they don't get forgotten.

1. **Counter penalty severity** (blocks any rebalancing under B5) — 50%, 30%, or graduated? The current 50% setting is brutal-by-design per the original brief, but no playtesting data exists yet.
2. **Player promotion to Node** (D2) — defer until a feature actually requires it. Don't speculatively promote.
3. **`BalanceResource` hot-reload in editor** — Godot supports `.tres` reload but `GameDirector` will need to re-publish references on reload. Validate this works as expected during B5; if not, fall back to a single load at game start.

---

*End of plan. Update this document whenever a phase completes or a decision is revised.*
