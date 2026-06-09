# DL-073 — Q04 walk-forward: realistic %-of-notional commission (replaces flat $7/lot)

**Date:** 2026-06-09
**Status:** **RATIFIED + IMPLEMENTED (OWNER 2026-06-09)** — live in `framework/scripts/q04_walkforward.py`
**Supersedes:** the flat `$7/lot` round-trip cost in Q04 (the constant remains only as a fallback)
**Related:** DL-071 (Q04 net-positive PASS_SOFT), DL-072 (Q08 cost-cushion), `framework/registry/live_commission.json`,
`tools/strategy_farm/portfolio/commission.py`, `docs/research/PRACTITIONER_SETUPS_AND_COST_MODEL_2026-06-09.md`,
`project_qm_backtests_cost_free_2026-05-29`

## Kontext (OWNER 2026-06-09)

Der Research-Brief (PRACTITIONER_SETUPS_AND_COST_MODEL) hat die größte Kosten-Integritätslücke
benannt: **Q04 berechnete einen pauschalen $7/Lot Round-Trip** EA-seitig — per-Instrument FALSCH:
zu hart für FX-Majors (real ~$5), **materiell zu lasch** für hoch-notionale Index-CFDs + XAUUSD
(%-of-Notional ≫ $7). Q08 nutzt bereits das korrekte Modell. OWNER: „auch das Q04-Kostengate,
Reruns wo nötig" — vereinheitlichen auf das realistische Modell, wir wollen besser werden.

Hard-Rule-Check: KEINE erfundenen Werte — die Sätze stammen aus `live_commission.json`
(OWNER-Autorität 2026-06-01). Hard-bounded Gate-Kriterium → als DL ratifiziert.

## Entscheidung

Q04 benotet ab jetzt mit **demselben instrument-korrekten Modell wie Q08**:

`cost_rt = max(pct_rate_rt × notional_acct, flat_per_lot_rt × volume)`
(forex pct 0.00005 / flat €5 · index pct 0.00005 / flat €5.5 · commodity pct 0.00005 / flat €0)

**Angewandt POST-HOC auf den Per-Trade-Stream**, den der Fold-Backtest ohnehin emittiert
(`Common/Files/QM/q08_trades/<ea>_<sym>.jsonl`, je Trade mit `notional` + `volume`). Pro Fold:
`PF-net = profit_factor([ (profit+swap) − cost_rt für jeden Trade im OOS-Fenster ])`.
`aggregate_verdict` (PASS / DL-071 PASS_SOFT / FAIL) bleibt unverändert — nur die *Quelle* von
`pf_net` wechselt vom Flat-$7-EA-Selbstreport auf das realistische Stream-Modell.

## Warum PATH A (Stream-Post-hoc) statt EA-Umbau + Re-Run

1. **Kein Framework-/EA-Code-Change, kein MT5-Re-Run nötig.** Jeder Backtest schreibt den
   TRADE_CLOSED-Stream mit `notional` (account-currency, EA-berechnet) bereits — die zwei Inputs,
   die `CommissionModel.cost_round_trip(symbol, volume, notional)` braucht. Keine Contract-Size-
   Lookups python-seitig.
2. **Ein geteiltes Kostenmodell.** Q04 und Q08 ziehen beide aus `commission.py` + `live_commission.json`
   → keine Divergenz, eine Wahrheit (spiegelt `aggregate._apply_worst_case_commission`).
3. **Going-forward automatisch.** `run_fold_via_smoke` liest den frisch emittierten Stream nach jedem
   Fold (Stream wird je Fold geleert → sauberer Read), OOS-fenstert defensiv, wendet das Modell an.
   Fällt nur auf den Flat-$7-Selbstreport zurück, wenn kein Stream existiert (alte EA / Stream-Skip).

## Implementierung (live)

`framework/scripts/q04_walkforward.py`:
- `pf_net_from_stream(ea_id, symbol, fold, model)` — lädt Stream, OOS-fenstert per `time`-Epoch,
  wendet `commission.cost_round_trip` an, gibt `(pf_net, n_trades, commission_total, gross_total)`.
- `_commission_model()` (lazy `commission.load_model()`), `_q08_trade_stream_path`, `_gross_before_commission`.
- `run_fold_via_smoke`: Stream-Grade bevorzugt, Flat-$7 Fallback; leert q04_sim **und** q08_trades je Fold.
- `aggregate.json`: `commission_model="worst_case_dxz_ftmo_notional (DL-073)"`, `commission_basis` (Liste).

Unit-getestet: NDX-Index 1-Lot/400k-Notional → cost $20 (pct dominiert), EURUSD 1-Lot/100k → cost $5,
OOS-Windowing schließt Fremdjahr-Trades aus, fehlender Stream → Fallback. Alle Assertions grün.

## Richtungseffekt + Backfill

- **Index/Gold** werden bei großem Notional *härter* (korrekt; $7 war zu lasch), bei kleiner Size
  dominiert der Flat-Floor (€5.5) → oft *milder* als $7. **FX** wird milder (€5 < $7). Netto je EA
  instrument-/size-abhängig — das ist der Punkt: korrekt statt pauschal.
- **Going-forward:** alle neuen Q04-Läufe korrekt benotet (automatisch).
- **Backfill:** Alt-Streams sind überschrieben → Re-Grade-aus-Altstream nicht verlässlich. Gezielte
  Re-Runs (OWNER „wo nötig") für die fortgeschrittene Kohorte (Q04 PASS_SOFT + Q05+-Survivor +
  Portfolio-Track), NICHT pauschal alle 6026 FAILs (die starben an Walk-Forward-Robustheit, nicht
  am $7-vs-Notional-Margin). Swap bleibt unmodelliert (=$0) — separat, siehe Brief.

## Caveat
Greift wie DL-071/072 FORWARD. Bestehende Q04-Aggregate werden erst beim Re-Run neu benotet.
