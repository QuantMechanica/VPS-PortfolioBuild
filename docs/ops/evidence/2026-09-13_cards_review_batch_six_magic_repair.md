# Card review batch: six EAs post magic-precondition repair (2026-09-13)

Router task `30b97a32-5f28-4da7-b707-8364d8ce11c5`. Source cards sat only in
`D:/QM/strategy_farm/artifacts/cards_review/` following the governed magic
precondition repair on 2026-09-12/13 (evidence:
`docs/ops/evidence/2026-09-12_qm5_11939_governed_magic_precondition.json` and
siblings for 11935/11933/11932/11927/11926). Each card already carried
`g0_status: APPROVED` from the 2026-09-12 Edge Lab adversarial screen (OWNER
go); this pass is the formal second-gate review + promotion to
`cards_approved`.

Checked against the Edge Lab charter and hard rules: mechanical/no-ML/no-grid/
no-martingale, single declared target symbol, literal (non-ambiguous)
timeframe, source citation with lineage, `expected_pf`/`expected_dd_pct`
present, and `expected_trades_per_year_per_symbol` >= 5.

## Decisions (6/6 APPROVE, 0 REJECT)

1. **QM5_11939 ff-j16-pin-rejection** (EURUSD.DWX, H4, 50 trades/yr) — APPROVE.
   H4 pin-bar reversal, mechanical closed-form (60% wick / 20% body / level
   penetration), limit entry at 50% wick retracement, SL 5 pips beyond the
   wick extreme (verified on the correct adverse side of entry, not inside
   it), TP fixed 1:2R. Source: FF James16.
2. **QM5_11935 ff-sonic-r** (EURUSD.DWX, M15, 150 trades/yr) — APPROVE.
   Dragon EMA(34 H/L/C) tunnel breakout + retest closed-bar state machine,
   filtered by EMA89 trend, SL = 89 EMA far side, TP fixed 1.5R. Source: FF
   Sonic R.
3. **QM5_11933 ff-holo-tooslow** (EURUSD.DWX, M5, 200 trades/yr) — APPROVE.
   Mean-reversion off the running intraday H1-open extremes (00:00 reset),
   closed-bar two-condition trigger, SL = day extreme, TP fixed 15 pips
   (midpoint of the source 10-20 pip range). Source: FF HOLO/TooSlow.
4. **QM5_11932 ff-tms-big-e** (EURUSD.DWX, H4, 100 trades/yr) — APPROVE.
   Canonical TDI (RSI13 / SMA 2-7-34) green/red cross confirmed by Heiken
   Ashi, single deterministic exit (green crosses yellow base line), SL
   fixed 60 pips (midpoint of the source 50-80 pip range). Source: FF
   TMS/Big E.
5. **QM5_11927 rb-atr-candle-break** (XAUUSD.DWX, H1, 50 trades/yr) —
   APPROVE. Outlier-candle momentum, closed-bar[1] trigger (range >= 1.5x
   ATR100, body >= 60% range, close in the extreme quartile), direction from
   the candle's own sign, D1 EMA200 trend filter, time filter 08:00-20:00
   server, entry at next-bar open. SL 1.5% / TP 2.0% of price (percent-based,
   appropriate for Gold). Source: live_balke.
6. **QM5_11926 rb-rsi-ma-filter** (EURUSD.DWX, H1, 100 trades/yr) — APPROVE.
   RSI(14) 30/70 trigger with D1 SMA50 trend filter and a deterministic
   anti-spam RSI-50 reset latch; single resolved exit regime (SL fixed 5.0%
   / TP fixed 1.0%, trailing alternative dropped). Source: live_balke.

## Mechanics

- `farmctl approve-card` run against each card at its `cards_review` path
  (default `--root D:\QM\strategy_farm`) with `--expected-pf 1.2
  --expected-dd-pct 10.0` (matching each card's own frontmatter estimate) and
  a per-card reasoning line. All six returned `approved: true` with
  `registry_precondition.precheck.ready: true` (active magic row, EA
  directory present, target symbols valid) — confirming the 2026-09-12/13
  repair closed the precondition cleanly.
- `approve_card()` does not relocate a card whose source directory is not
  `cards_draft/` (only draft-sourced approvals get an automatic move), so
  after approval each file was manually copied from
  `D:/QM/strategy_farm/artifacts/cards_review/` into both
  `D:/QM/strategy_farm/artifacts/cards_approved/` and
  `C:/QM/repo/artifacts/cards_approved/` (dual-location convention per prior
  practice, e.g. commit `5136355a4a`), then removed from `cards_review/`.
- C: copy committed on `agents/board-advisor` with explicit pathspecs
  (commit `2a761f8398`, 6 files, no unrelated changes picked up).

## Evidence

- `docs/ops/evidence/2026-09-12_qm5_11939_governed_magic_precondition.json`
  (+ siblings for 11935/11933/11932/11927/11926) — magic allocation repair.
- `D:/QM/strategy_farm/artifacts/cards_approved/QM5_119{39,35,33,32,27,26}_*.md`
  and `C:/QM/repo/artifacts/cards_approved/` (same filenames) — approved
  cards, dual location.
- git commit `2a761f8398` on `agents/board-advisor`.

## Next step

COMPILE_EA / build_ea dispatch for these six now follows the normal governed
path (magic precondition ready, card approved) — no further Claude action
required to unblock it.
