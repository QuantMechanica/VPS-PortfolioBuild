---
source_id: AI-CODEX-EURCHF-FRANC-REVERSAL-20260901
title: EURCHF extreme franc-strength closed-bar reversal
publisher: QuantMechanica governed synthesis from OWNER research and official-source packets
source_type: ai_originated_governed_structural_hypothesis
status: approved_source_complete
approval_basis: decisions/2026-09-01_eurchf_franc_strength_reversal_source_approval.md
parent_source_ids:
  - ORTHOGONAL-RETURN-SOURCES-PROGRAM-20260813
  - EIA-SNB-XTI-USDCHF-RSPREAD-2026
  - EIA-SNB-WTI-CHF-2026
parent_sha256:
  ORTHOGONAL-RETURN-SOURCES-PROGRAM-20260813: 5032C7492C5A57A71D46C4176E6D6E48A1312C566BFD28CB955B104D40E061BD
  EIA-SNB-XTI-USDCHF-RSPREAD-2026: 13974A44F4A509F63BF5F408FB2C89CC6F7F35A96EDAF0339B0358A260679BC8
  EIA-SNB-WTI-CHF-2026: F2337C442501B941D0FB6BE72DB3A1F14657999AAD4AF642B085B5988D39B707
created: 2026-09-01
created_by: Research+Development
cards_extracted:
  - QM5_41276_eurchf-franc-rev
---

# EURCHF Extreme Franc-Strength Closed-Bar Reversal

## Approval And Complete Read

The durable approval is
`decisions/2026-09-01_eurchf_franc_strength_reversal_source_approval.md`.
The current OWNER mission authorizes one structural low-frequency edge on an
instrument absent from the certified book after the higher-priority backlog
and infrastructure paths were exhausted.

The bounded complete reads are the full OWNER research program at
`docs/research/ORTHOGONAL_RETURN_SOURCES_PROGRAM_2026-08-13.md` and the two
local official-source packets listed in frontmatter. Their hashes are frozen
above. The program's candidate 7 supplies the H4 EURCHF research ticket and
explicitly preserves the 2015 gap and post-floor regime hazards.

The public-source reader classified the two official SNB pages as
`DEFERRED:SOURCE_POLICY`. The exact JSON receipts are stored in this directory.
No alternate retrieval was attempted. Those URLs are bibliographic lineage,
not a basis for imported coefficients or performance claims.

## Source-Defined Findings

- The OWNER program proposes a long-only H4 EURCHF extreme-strength reversal:
  z-score below -2, lower-decile location over 250 bars, and bullish closed-bar
  reversal, with one entry, ATR risk, and no averaging.
- The local SNB-linked packets preserve only the official central-bank lineage
  that CHF behaves as a safe-haven currency and that stress response can vary
  by counterpart currency and regime.
- The program explicitly says the hard-floor regime ended, requires capped
  loss and gap-tail modeling, and treats post-2015 persistence as unproven.

No bounded source says this conjunction predicts returns, survives post-2015,
earns a particular profit factor, trades at a particular frequency, fills its
stop through gaps, or diversifies the current portfolio.

## Bounded Trading Hypothesis

At each new exact `EURCHF.DWX` H4 bar, using completed bars only:

```text
C0 = just-completed close
R  = C1..C40                         # forty closes before C0
mu = mean(R)
sd = sqrt(sum((x-mu)^2 for x in R) / 40)
z  = (C0-mu) / sd

lo = min(C1..C250)
hi = max(C1..C250)
lower_decile = lo + 0.10*(hi-lo)
bullish_reversal = close0 > open0 and close0 > close1

BUY iff z < -2.0 and C0 <= lower_decile and bullish_reversal
```

Freeze `ATR(14,H4)` on the signal bar. Start with a structural stop at
`signal_low - 0.25*ATR`, widen only to the fixed `1.25*ATR` minimum distance,
and reject the entry if the required distance exceeds `2.50*ATR`. Target
`entry + 1.50*ATR`. Exit on the first completed H4 bar with `z > -0.50`, after
eighteen H4 periods, Friday close, hard stop/target, or kill switch.

The current signal bar is excluded from all reference samples. The 250-bar
range uses closes. There is no short side or USDCHF confirmation in this
single-symbol baseline. No signal value changes risk.

## Reputable-Source Criteria

- R1: `PASS_WITH_UNTESTED_MECHANIZATION_AND_POST_FLOOR_REGIME_RISK`.
  Complete durable OWNER research and official-source packets support the CHF
  stress carrier and exact research ticket; the price rule is explicitly
  untested QuantMechanica synthesis.
- R2: `PASS`. Sample membership, population deviation, strict thresholds,
  reversal, side, fixed ATR risk, target, exits, and activity boundary are
  frozen before testing.
- R3: `PASS`. Canonical `EURCHF.DWX` H4 history
  provides all research inputs. No confirmed live alias exists in the matrix;
  this source authorizes no live action.
- R4: `PASS`. Native completed OHLC, fixed arithmetic, ATR, quote, position,
  and framework state only. No trained or adaptive output and no external
  runtime feed.

## Non-Duplicate Review

The canonical receipt
`artifacts/qm5_eurchf_franc_rev_preallocation_dedup_20260901.json`, SHA-256
`D78071AA44A69A45F5133709888CCD2B2E5684DF0539494B13B2CC95040FA80E`,
checked 4,775 registry rows, 1,411 cards, and 45 Strategy Wiki nodes and found
no exact or fuzzy identity.

The closest EURCHF-capable cards are mechanically distinct: `QM5_35008` is a
symmetric M15 Bollinger/RSI evening fade, `QM5_1012` is a D1/H1 low-ADX
prior-range false-break fade, and `QM5_1011` is an inside-day breakout. Grid,
stochastic-scalper, and ADX/MA blueprints share neither the locked information
set nor risk architecture.

Verdict:
`DISTINCT_EURCHF_H4_LONG_ONLY_EXCURRENT_ZSCORE_LOWER_DECILE_BULLISH_REVERSAL`.

## Failure And Extraction Boundaries

- Retire zero positions or fewer than ten distinct entry days in any full
  post-warm-up calendar year.
- Retire nonpositive governed economics, failed reference arithmetic, a
  Q04-Q07 gap/regime failure, or any downstream gate failure.
- Do not rescue a result by changing windows, thresholds, side, stop, target,
  hold, carrier, risk, or by adding confirmation.
- A hard stop is a requested broker price, not a guaranteed gap fill.
- Q09 alone can establish realized overlap; EURCHF carrier identity is not a
  decorrelation result.

Exactly one card may be extracted from this source. Scope ends after one
branch build, deterministic reference tests, strict Q01, and one CPU-admitted
non-live Q02 enqueue. It excludes source scraping, optimization, live/demo/
shadow/stress presets, portfolio-gate changes, deploy/live manifests,
`T_Live`, AutoTrading, and terminal control.
