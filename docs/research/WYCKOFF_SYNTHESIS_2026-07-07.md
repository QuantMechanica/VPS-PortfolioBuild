# Wyckoff Two-Track Synthesis — OWNER Video × Independent Sonnet Dossier

**Date:** 2026-07-07 · **Author:** Claude (synthesis) · **OWNER order:** analyze video
AfcP2nYJB4E via agy + general Wyckoff strategies; independent Sonnet preparation for
comparison; "mach das Beste aus beiden Inputs".

**Inputs:**
1. Video AfcP2nYJB4E — full proxy-fetched transcript (746 rows, timestamped),
   `docs/ops/youtube-transcripts/AfcP2nYJB4E/` (agy ticket e398f9d2; access delivered,
   analysis by Claude after two agy session deaths — ops finding in the ticket).
2. Independent Sonnet dossier —
   `D:/QM/strategy_farm/artifacts/research/WYCKOFF_SONNET_INDEPENDENT_2026-07-07.md`
   (no transcript input; web research + formulas; blind to track 1).

---

## 1. Track-1 verdict: the video contains NO strategy

Honest extraction result: **NO_MECHANIZABLE_CONTENT.** AfcP2nYJB4E is part 5 of a
vlog series in which the author has AI models (Sonnet, Opus 4.6–4.8, and "Fable 5")
generate a Wyckoff-cycle EA in MQL5. The transcript contains zero rule definitions —
no range criterion, no entry/exit, no SL/TP, no volume threshold, no phase test. The
only strategy content is the one-sentence textbook frame: accumulation/distribution
are consolidations; markup/markdown are the trends between them [00:00:31-00:00:48].
The rest is the author watching the generated EA mislabel clear trends as
consolidations ("How on earth is this a consolidation? … This is a clear downtrend"
[00:11:09-00:11:27]), burning his full token budget on one "maximum" prompt
[00:31:44-00:32:07], and concluding that EA-building via AI needs a coding background
[00:38:31-00:38:48].

**But the video is evidence of something else** — see §3.

## 2. Track-2 verdict (Sonnet, independent): narrow codifiable core, mostly duplicates

- **Codifiable:** spring/upthrust (exact closed-bar formulas), SOS/LPS breakout-retest,
  selling/buying climax, VSA bar types (no-demand/no-supply/absorption).
- **Inherently discretionary:** real-time phase labeling (A–E), Composite-Man
  narrative, "creek" lines — the parts that make Wyckoff content compelling.
- **Evidence:** zero peer-reviewed out-of-sample profitability anywhere; the one
  academic study proves detectability (99% range classification) not P&L; the
  85–95% accuracy claims online are unverified marketing.
- **Overlap:** spring/upthrust ≡ CRT sweep-reversal (QM5_13033 family, expected corr
  >0.7); SOS/LPS ≡ breakout-retest (existing family). Genuinely new for a price-only
  shop: **volume-climax as primary trigger** (corr ~0.4–0.6 vs price-stretch MR) and
  **absorption bars** (high-volume/narrow-range) as an entry gate (~0.2–0.4).

## 3. The convergence — where the two tracks agree without knowing each other

The video is an accidental **empirical demonstration** of the Sonnet dossier's central
analytical claim. Sonnet (blind to the video): *"Pure lookback range detection
conflates ranges with ongoing trends … real-time phase labeling will misclassify
frequently — especially in Phase B."* The video (blind to the dossier): five parts,
multiple frontier AI models, and every iteration fails at exactly that step — trends
labeled as consolidations, consecutive markups without intervening ranges, "total
crash" at the range-vs-trend boundary.

**Synthesis conclusion:** full-cycle Wyckoff automation ("detect all phases, trade
the cycle") is a tar pit — not because AI models are weak, but because the phase
grammar is not well-defined on OHLCV. Anyone (human or AI) automating "the Wyckoff
cycle" as a whole inherits an unfalsifiable spec. The only defensible automation
target is the small set of *events* with exact bar-level definitions.

## 4. Decisions (best of both inputs)

| # | Decision | Rationale |
|---|---|---|
| D1 | **NO full-cycle Wyckoff card.** | §3 convergence; over-engineered vs available signal quality (both tracks). |
| D2 | **NO spring/upthrust card.** | Mechanically ≡ CRT sweep-reversal; QM5_13033 already carries this family through the gates. A Wyckoff-labeled twin adds correlated exposure, not orthogonality. |
| D3 | **NO SOS/LPS card.** | Breakout-retest family exists; same duplication argument. |
| D4 | **CANDIDATE (gated): volume-climax D1 mean reversion, XAUUSD + XTIUSD.** Entry: Vol > 2.5×SMA(Vol,20) + spread > 2×SMA(H-L,20) + close position + next-bar confirmation; SL beyond climax extreme; TP = SMA(Close,20); time exit 8 bars. ~12–25 tr/yr/symbol, index/commodity costs. | The one genuinely non-duplicate mechanic (Sonnet §2.3). **HARD GATE before carding:** validate .DWX tick-volume quality — do known climax dates (2020-03 COVID, 2020-08 gold spike, 2022-03 WTI) actually show Vol > 2.5×SMA in our tester data? If tick volume is noise, the family is dead on our data and must not be carded. |
| D5 | **LATER: absorption-bar filter** (Vol>1.5×SMA + range<0.65×SMA + down-close near range-low) as a v2 entry gate on existing sweep-reversal EAs — an exit/entry-surgery-class experiment, not a new card. | Lowest-correlation contribution, but unproven standalone; cheapest tested as a variant. |
| D6 | **Ops rule for agy tickets: one video per ticket.** Multi-fetch surveys exceed a single session (2× session death: silent backend loss; 60-min print-timeout during fetch waits). | Ticket e398f9d2 evidence. |

**Next concrete step (D4 gate):** a small evidence script over the .DWX D1 streams —
pull Vol/SMA(Vol,20) ratios for XAUUSD/XTIUSD on the known climax dates from tester
history; CSV → if ≥2 of 3 events clear 2.5×, write the card; else record the family
as untradeable on our data. Cheap (no backtest slots).

## 5. Unverified-claims register (carried from both tracks)

- All practitioner win-rate claims (55–65% spring, 85–95% climax) — UNVERIFIED.
- The video author's "profitable system" remark about his part-4 EA [00:01:28-00:01:31]
  — no report shown in captions; UNVERIFIED and irrelevant (his EA, not a strategy spec).
- arXiv 2403.18839 accuracy ≠ profitability (verified classification only).
