# Hyonix BB/ADX mean-reversion density card — drafting evidence

Date: 2026-08-13  
Router task: `b1bf37bc-b76c-4514-aa25-540c39ea1ea4`  
State requested: `REVIEW`  
Card: `D:/QM/strategy_farm/artifacts/cards_review/PENDING_B1BF37BC_hyonix-bb-adx-mr-density.md`

## Scope and provenance

This is one strategy-card draft only. No EA was built, no backtest was enqueued, no terminal was launched, and nothing under `C:/Users/Administrator/Dropbox/Hyonix` was modified.

The router ticket binds the mechanism to the OWNER-authored Hyonix legacy mean-reversion framework (2025). Read-only source inspection covered:

- `C:/Users/Administrator/Dropbox/Hyonix/Breakout2/MeanReversion/ModularEA.mq5:75-143` for M15, BB/RSI/ADX, score, risk, session, trade-cap, and legacy news defaults;
- `ModularEA.mq5:431-455` for new-bar signal dispatch;
- `MeanReversionStrategy.mqh:455-617` for symmetric entry scoring;
- `MeanReversionStrategy.mqh:765-817` for stop/target lineage; and
- `C:/QM/repo/docs/research/HYONIX_LEGACY_MINING_2026-08-13.md` for the mining verdict and absence of qualifying multi-year evidence.

The source include list contains no `HiddenMarkovFilter.mqh` reference. The router contract makes that file prohibited dead code; the card therefore forbids including, referencing, or reimplementing it.

## Mechanism binding

The card preserves the ticket's specified mechanism:

- completed-bar `M15` signals and next-bar market entry;
- `ADX(14) < 30` range gate;
- BB(20,2.0) with a 30% half-band touch zone;
- symmetric weighted BB, RSI 35/45 and 65/55, and optional candle-reversal score, threshold 3;
- session parameters with legacy defaults 01:00-10:00 server time and a three-attempt daily cap;
- initial SL at 2.5 completed-bar StdDev;
- 50% partial at 1R and remaining target at 2R; and
- no pyramiding, grid, martingale, or ML.

The ticket's explicit 1R/2R contract is controlling. Legacy trailing, middle-band exit, MACD, visualization, MarketplaceValidation, and extra range-cross behavior were not carried into the card.

## QuantMechanica guardrails

- Draft was placed in `cards_review/`, as required by the active Edge Lab charter and router validation.
- Backtest semantics are `RISK_FIXED > 0`, `RISK_PERCENT = 0`.
- Mandatory high-impact news blackout is fail-closed; `qm_news_stale_max_hours <= 336` is explicit.
- FTMO + DarwinexZero bounds are explicit: no more than 5% daily loss and 10% total loss.
- The EA horizon is M15 scalping, minutes-to-hours, with no HFT.
- No T_Live, AutoTrading, live manifest, deploy, build, or queue action is authorized.
- Portfolio admission must measure overlap against cumRSI2 D1 and squeeze-reversal D1 sleeves.

## Focused verification

Verification for this research artifact was limited to card structure, source fidelity, required literals, and non-mutation of the OWNER legacy tree. The farm's G0 coverage routine was invoked read-only; `approve-card` was not run because approval belongs to independent review.

Results:

1. PASS — frontmatter parsed and status remained `DRAFT` / `PENDING_REVIEW`.
2. PASS — `_verify_card_body_coverage` returned `{"ok": true, "missing": []}` for source citation, Entry, Exit, Stop/SL, `.DWX` targets, literal `M15`, and expected annual frequency.
3. PASS — `_infer_expected_trades_per_year_per_symbol` returned `250`, within the declared 150-350 range.
4. PASS — focused assertions found the fixed-risk contract, news-staleness cap, no-ML rule, named portfolio-overlap controls, and OWNER/year source attribution.
5. PASS — `git diff --check -- docs/ops/evidence/2026-08-13_hyonix_bb_adx_mr_density_card_draft.md` returned clean.
6. Pending router close — the artifact path will be supplied to `update-task ... --state REVIEW` after this evidence-only commit.

Read-only source SHA-256 bindings at verification time:

- `ModularEA.mq5`: `DF26F7F53310B6D53BC269C2F400D4DE7604A1EE5CC27CBB0B82FC8C0E0F4AEF`
- `MeanReversionStrategy.mqh`: `2BFF055B629AA34514603702ADD5BC654DD3E1B813D10294F6E13D03806B3A74`
