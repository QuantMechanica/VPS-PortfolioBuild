# CODEX INDEPENDENT STRATEGY SPECS — harvest build run 2026-07-24

You are Codex writing INDEPENDENT strategy specifications for 3 sources. Claude
writes his own specs in parallel — do NOT read anything under
`C:\QM\repo\docs\ops\source_harvest\strategies\` (only this brief). Your specs are
diffed against Claude's; divergences get reconciled by tie-break (source wording
decides trading logic; restrictive wins on risk).

**No implementation in this task.** Spec documents only — no MQL5, no EA scaffolding.

## Inputs (staged local copies; extract text with python pypdf)

`D:\QM\reports\source_harvest_build\`
1. `forexfactory_340556_swing-trading-heiken-ashi-stochs_p1-3.pdf` → spec for **STR-097**
   (Heiken-Ashi + Stochastic trend-pullback swing, FX/H4)
2. `forums.babypips.com_t_3-little-pigs-trading-system_54174.pdf` → spec for **STR-103**
   (3 Little Pigs multi-TF SMA trend swing, FX/H4 execution)
3. `ff_1328051_trading-system-based-on-monthly-weekly-and-daily.pdf` → spec for **STR-021**
   (Weekly-open break + order-block/liquidity-sweep entry, Metals/M15)

## Per source: write `02_spec_codex_STR-###.md` into the SAME directory

Sections (mandatory, exactly these):
1. **Source rules (verbatim-anchored):** the stated rules with page/post references —
   quote the decisive sentences. Where the thread evolves, use the ORIGINAL author's
   final stated ruleset; note version drift.
2. **Entry:** deterministic conditions (indicator params exactly as stated; bar-close
   semantics — closed-bar only, no intra-bar repaint; which TF drives).
3. **Exit:** TP/SL/trailing/time exits as stated. If the source states none, say
   NONE STATED (do not invent).
4. **SL/TP sizing:** exact pips/ATR/structure rules from the source.
5. **Filters/Session:** trend/session/news filters as stated.
6. **Money management:** as stated (we will map to framework RISK_FIXED/PERCENT later
   — record the source's intent).
7. **Edge cases:** gaps, weekend, missing bars, simultaneous signals, re-entry rules,
   position already open.
8. **Expected trade frequency:** trades/year estimate for ONE symbol on the stated TF
   (Q02 floor is >=5/yr; flag if episodic).
9. **Ambiguities:** every point where the source underdetermines behavior — list,
   do not resolve silently.
10. **MQL5 mapping notes:** indicator availability (Heiken-Ashi/Stoch/SMA are native
    or trivially computable), any repaint traps, multi-TF access notes.

## Constraints

Read-only outside `D:\QM\reports\source_harvest_build\`. No repo writes, no git, no
DB writes, no MT5/T_Live/factory/task/flag/config actions, no builds. When all 3
specs are written:
`python C:\QM\repo\tools\strategy_farm\agent_router.py update-task <task_id> --state REVIEW --artifact-path "D:\QM\reports\source_harvest_build" --verdict "3 independent specs written: STR-097, STR-103, STR-021"`
(task id via `list-tasks --agent codex --state IN_PROGRESS`). Then exit.
