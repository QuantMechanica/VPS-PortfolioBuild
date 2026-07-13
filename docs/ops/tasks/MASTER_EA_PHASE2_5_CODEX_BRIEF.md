# Phase-2.5 Delegations-Auftrag — headless Codex: expliziter Fixed-Lot-Sizing-Pfad

**Rolle:** headless Codex. **PM:** Claude. **Worktree:** `agents/codex-master-ea-p25`
(nie main, nie T_Live, nie T1/T2). **Non-live, reversibel.**
Kontext: `docs/ops/MASTER_EA_SYMBOL_CONSOLIDATION_PLAN_2026-07-13.md` (Phase 2.5).
Baut auf Phase 1/1.5/2 (alle gemerged).

## Befund

Die per-Modul-Regression (Phase 3/4) muss das Standalone-**RISK_FIXED**-Backtest-Sizing
centgenau reproduzieren. Der Risk-Sizer (`framework/include/QM/QM_RiskSizer.mqh`) kennt
`QM_RISK_MODE_PERCENT` und `QM_RISK_MODE_FIXED`. RISK_FIXED = fixes Risiko-*Geld*
(`g_qm_risk_fixed`), Lots via `QM_LotsForRiskFromSnapshot(snapshot, risk_money, sl_points)`.

Phase 1 lieferte einen expliziten **PERCENT**-Pfad, der den globalen PERCENT-Branch ohne
Global-Mutation spiegelt:
- `QM_RiskSizerRiskMoney(equity, explicit_risk_percent)` (Zeile ~81)
- `QM_LotsForRisk(symbol, sl_points, explicit_risk_percent)` (Zeile ~373)
- per-Call in `QM_TM_OpenPosition` (explicit_risk_percent)

Ein expliziter **FIXED**-Branch fehlt. Ohne ihn kann ein Master-Modul das Standalone-
RISK_FIXED-Sizing nicht replizieren → keine centgenaue Regression.

## Auftrag

Einen parallelen expliziten **FIXED**-Pfad ergänzen, der den globalen FIXED-Branch von
`QM_RiskSizerRiskMoney(equity)` (base_risk = `g_qm_risk_fixed`, × `g_qm_risk_portfolio_weight`,
dann `g_qm_risk_per_trade_cap_money`-Cap; Zeilen ~63-74) **1:1 spiegelt, ohne Globals zu
mutieren**. Konkret:

1. Explizite risk_money-Auflösung für FIXED — z.B. `QM_RiskSizerRiskMoney(equity, QM_RiskMode
   explicit_mode, double explicit_value)` (mode-aware), oder ein dediziertes
   `QM_RiskSizerRiskMoneyFixed(equity, explicit_risk_fixed)`. Dieselben portfolio_weight- +
   per_trade_cap-Rails wie global.
2. Passendes `QM_LotsForRisk(symbol, sl_points, explicit_mode, explicit_value)` (oder
   Fixed-Variante), das auf die richtige risk_money-Auflösung routet und dann dieselbe
   `QM_LotsForRiskFromSnapshot`-Mathematik nutzt.
3. Per-Call-Threading durch `QM_TM_OpenPosition`, sodass ein Modul mode+value übergeben kann.
4. **Backward-kompatibel:** Phase-1-PERCENT-Overload + alle bestehenden Aufrufe bleiben
   bit-identisch. Neue Overloads/optionale Params, keine Signatur-Brüche. Der Phase-1-
   `explicit_risk_percent`-Pfad darf als mode=PERCENT-Wrapper konsolidiert werden, MUSS aber
   identisch rechnen.

KEIN Master-Modul, KEINE Strategie-Logik (das ist Phase 3, Sonnet). Nur der Framework-Pfad.

## Acceptance-Gate (MUSS grün)

1. **Unit-Beweis** (erweitere `risk_sizer_smoke.mq5` oder die passende Test-Datei): für
   identische Inputs (equity, fixed-value, sl_points, Symbol-Snapshot, portfolio_weight, cap)
   liefert der **explizite FIXED-Pfad** dasselbe `risk_money` UND dieselben Lots wie der
   **globale** Pfad nach `QM_RiskSizerConfigure(QM_RISK_MODE_FIXED, ...)`. Assert Gleichheit
   (exakt). Analog ein Gegen-Check, dass explizit-PERCENT weiter == global-PERCENT.
2. **Backward-compat-Regression:** `QM5_12567_cum-rsi2-commodity` XAUUSD.DWX D1 force-rebuilden +
   Full-History 2017–2025 Model 4 → weiter **73 Trades / Net $4.676,76** centgenau
   (freies T6–T10; der explizite Pfad ist additiv, ändert den Global-Pfad nicht).

## Deliverable

PR auf `agents/codex-master-ea-p25`: Sizer-Erweiterung + QM_TM_OpenPosition-Threading,
Unit-Test, Design-Notiz (welche Overloads, warum backward-kompatibel, wie FIXED gespiegelt
wird), grüne Gate-Belege (Unit-Assert + 12567-Zahlen). Claude reviewt + fährt das
autoritative Gate + merged.
