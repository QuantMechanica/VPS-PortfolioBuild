# DL-076 — Q04 Walk-Forward: low-freq pooled-OOS rescue (PASS_LOWFREQ) + PASS_SOFT live-path repair

**Date:** 2026-06-23
**Status:** **RATIFIED + IMPLEMENTED (OWNER 2026-06-23, "Freigeben mit Defaults")**
**Supersedes:** none — extends `aggregate_verdict` logic in `framework/scripts/q04_walkforward.py` ([[DL-071]] PASS_SOFT tier)
**Related:** DL-071 (Q04 net-positive-with-variance PASS_SOFT), DL-070 (Q08 swing/low-freq track), DL-073 (Q04 realistic %-notional commission), DL-064 (portfolio-construction layer). Files: `framework/scripts/q04_walkforward.py`, `tools/strategy_farm/farmctl.py`, `tools/strategy_farm/dashboards/render_dashboards.py`.

## Kontext (OWNER 2026-06-23)

Der obere Funnel (Q05+) stand über Nacht praktisch still (in 6h ~2-3 Q05, Q06-Q12 leer,
0 Portfolio-Kandidaten). Die Q04-Funnel-Forensik (2026-06-22, [[qm-ram-wedge-8terminals-2026-06-22]])
hatte unter den 543 Q04-Toden **63 EAs mit 0 Trades in allen 3 OOS-Folds** klassifiziert —
Low-Freq-Edges, vom 3×1-Jahr-Fold-Schnitt verhungert; **52 davon Forex** = exakt die fehlende
Portfolio-Diversifikation (aktuell 4 korrelierte Sleeves, Ziel 8-12 unkorrelierte, [[qm-portfolio-layer-status-2026-06-21]]).
OWNER hatte die Gate-Design-Entscheidung reserviert; der Q04-Desktop-Heap-Wedge kam dazwischen.

## Das Problem (im Code verankert)

`framework/scripts/q04_walkforward.py` testet mit **3 anchored Folds, je 1 Kalenderjahr OOS**
(`FOLDS`: 2023/2024/2025, DEV ab 2017). `aggregate_verdict`: jeder Fold PF-net > 1.0 = PASS;
PASS_SOFT = Mehrheit + mean>1.10 + kein Fold<0.80; **ein No-Trade-Fold zählt PF-net 0.0 → Fail.**

Bei einer ~10/Jahr-Strategie hat ein einzelnes Jahr 5-10 Trades → die Pro-Jahr-PF ist
**statistisches Rauschen, keine Robustheit**, und ein dünnes/Null-Jahr killt das strikte Gate.
Die echte OOS-Fail-Rate unter *fair getesteten* EAs ist ~81%, nicht die genannten ~90% — die
Differenz sind genau diese Geometrie-Opfer.

## Entscheidung A — Low-Freq pooled-OOS (PASS_LOWFREQ)

Eine **frequenz-gegatete** Variante: nur für Low-Freq-EAs zusätzlich ein **gepooltes OOS-Fenster
(alle OOS-Jahre konkateniert)** unter der **identischen PF-net > 1.0 Latte**. Bei der Sample-Größe
ist Pooling die *statistisch korrekte Einheit*, keine Schwellen-Senkung. Der gepoolte Stream ist
die **Konkatenation der per-Trade-Realistic-Net-Streams der 3 strikten Folds** (DL-073-Kostenmodell)
— **kein zusätzlicher Backtest**, mathematisch identisch zu einem gepoolten OOS-Run.

**Drei Guards halten die Qualität identisch:**
1. **Eligibility (Eintritt, kein Verdikt):** avg < **15 Trades/Jahr** über die strikten Folds
   (`Q04_LOWFREQ_MAX_TRADES_PER_YEAR`). High-Freq behält strikt 3-Fold, unverändert.
2. **Min Pooled Trades = 12** (`Q04_LOWFREQ_MIN_POOLED_TRADES`) — sonst INVALID, nie ein Free-Pass.
3. **Anti-Single-Year-Wonder:** Trades in **≥ 2 der 3** OOS-Jahre (`Q04_LOWFREQ_MIN_ACTIVE_YEARS`)
   — die sample-size-angemessene Robustheitsprüfung.

Nur versucht, wenn der **strikte Verdikt FAIL** ist und **alle Folds abgeschlossen** sind (nie
Rettung von INFRA/INVALID). PASS über diesen Pfad = Verdikt **`PASS_LOWFREQ`**, voll nachverfolgbar
(`lowfreq_verdict`/`lowfreq_reason` im aggregate.json). Advanced via `cascade_pass_verdicts["Q04"]`
nach Q05 wie ein Soft-Pass. Defaults OWNER-freigegeben 2026-06-23; alle tunbar.

## Entscheidung B — PASS_SOFT Live-Pfad-Reparatur (Bug bei A gefunden)

Bei der Implementierung aufgedeckt: **DL-071 PASS_SOFT war im Live-Dispatch-Pfad seit 2026-06-09
tot.** `farmctl._derive_phase_runner_verdict` (das den aggregate.json-Verdikt in `work_items.verdict`
übersetzt) ist eine Whitelist; `_normalize_phase("Q04")` → `P3.5`, das keinen Zweig trifft →
`PASS_SOFT`/`PASS_LOWFREQ` fielen zum Tail-Fallthrough `unknown_phase_runner_verdict` → **FAIL**.
**Beweis:** alle 18 PASS_SOFT-Q04-Rows tragen denselben Timestamp `2026-06-09T07:33:13Z` (der
DL-071-Backfill) — **null neue seither**, trotz 9596 Q04-FAILs. Net-positive-variance Soft-Passes
wurden 2 Wochen lang still zu FAIL degradiert = **Mit-Ursache des eingefrorenen oberen Funnels.**

**Fix:** Passthrough-Zweig in `_derive_phase_runner_verdict` für `{PASS_SOFT, PASS_LOWFREQ}` (Verdikt-
String ehrlich erhalten; das per-Phase `cascade_pass_verdicts`-Set bleibt das echte Advance-Gate).
`PASS_LOWFREQ` zu `cascade_pass_verdicts["Q04"]`, zur Q04-Grid-Spawn-Query und zum Dashboard-`passish`
ergänzt.

## Umsetzung (alle implementiert 2026-06-23)

- `q04_walkforward.py`: Konstanten + `is_lowfreq_eligible` + `aggregate_verdict_lowfreq` +
  `pf_net_from_stream` gibt die Per-Trade-Nets zurück (gepoolt in-memory; `oos_nets` aus aggregate.json
  gestrippt, um High-Freq-JSON nicht aufzublähen); main() Low-Freq-Zweig + Return-Code; PASS_LOWFREQ
  zählt als Pass.
- `farmctl.py`: PASS_SOFT/PASS_LOWFREQ-Passthrough; `cascade_pass_verdicts["Q04"]`; Grid-Spawn-Query.
- `render_dashboards.py`: `passish` inkl. PASS_LOWFREQ.
- Tests: 5 neue Low-Freq-Unit-Tests (eligibility, pooled-pass, single-year-wonder, insufficient-trades,
  below-floor) — alle grün; bestehende strikte `aggregate_verdict`-Tests unverändert grün. Die 2
  roten `test_verdict_taxonomy_ws2`-Tests (Q08-Seasonal) sind **pre-existing** (per git-stash verifiziert).

## Aktivierung & erwartete Wirkung

Beide Fixes greifen erst nach **Worker-Daemon-Neustart** (laufende Daemons haben den alten Code im
RAM); q04_walkforward läuft als Subprozess und zieht sofort. Nach Aktivierung: jeder NEUE Q04-FAIL,
der eigentlich net-positive-variance ist, klassifiziert wieder korrekt als PASS_SOFT; Low-Freq-FAILs
bekommen den gepoolten Test. Re-Enqueue der Low-Freq-Q04-FAILs (Reset latest Q04-Row → pending, eine
pro EA) recovert den Rückstand in **kleinen Batches**. Erwartung: ~52 Forex-Low-Freq-Sleeves +
die net-positive-variance-Population bekommen einen fairen Test → frische, unkorrelierte Q05/Q08-Sleeves
= der Portfolio-Sharpe/DD-Hebel, **ohne die Latte zu senken**. Risiko (gepoolt verdeckt Regime-Bruch)
abgefangen durch den 2-Jahres-Trade-Guard + spätere Q05-Stress/Q08-Regime-Stufen.
