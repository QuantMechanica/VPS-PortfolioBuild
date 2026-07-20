# TradingView `7IFb4Zx7` vs QM5_9987 source-fidelity audit

Observed 2026-07-20. This is a source-fidelity record, not a performance result and not authority to edit either EA.

## Conclusion

The approved card, committed SPEC, and committed EA for `QM5_9987_tv-ict-session-break-reentry-retest` are not an implementation of the currently indexed source-center description. They implement a reversal/fakeout family. The indexed TradingView publication describes a previous-session continuation family. The difference reverses both trade direction and the range being traded, so it cannot be treated as a harmless parameter drift.

The direct TradingView URL now returns `publication_deleted`. TradingView's own category/search pages still expose a cached description of the May 17 publication, but the Pine source is no longer retrievable from the page. No `.pine` copy or source snapshot was found in the searched VPS caches. Exact outcome testing is therefore fail-closed blocked.

## Current indexed source description

Primary publication URL: <https://www.tradingview.com/script/7IFb4Zx7/>

TradingView-indexed listings observed on 2026-07-20:

- <https://in.tradingview.com/scripts/trendanalysis/page-24/?script_access=all>
- <https://es.tradingview.com/scripts/breakouttrade/?script_access=all&sort=recent>
- <https://in.tradingview.com/scripts/search/TAKE/page-35/>

The indexed description identifies `ICT Session Breakout v3`, associates the May 17 publication with `EmptyCupTrades`, and names `ICT_Session_Breakout_Published.pine` in its publishing checklist. Its mechanical center is:

- build a session high/low from a configurable `Europe/Rome` new-day boundary; at rollover it becomes the previous-session range;
- default new-day boundary 06:00 Europe/Rome;
- SHORT break: candle body opens above previous low and closes below it;
- LONG break: candle body opens below previous high and closes above it;
- a new break resets the opposite-side setup;
- wait for a pullback inside to the yellow reentry/retest level, enforce the minimum-bars filter, then use a wick retest to enter in the original breakout direction;
- center inputs requested for this audit: 5-pip inside level, 5-pip tolerance, minimum 3 bars, SL 10 pips, TP 20 pips, M5;
- SL/TP reference the actual average fill;
- a New York calendar resets the daily counter and a New York day-end flat can be enabled.

That is continuation: a break above previous high ultimately seeks LONG; a break below previous low ultimately seeks SHORT.

## Approved Card and committed implementation

The approved card is:

`D:/QM/strategy_farm/artifacts/cards_approved/QM5_9987_tv-ict-session-break-reentry-retest.md`

SHA-256: `869c581c20f6d8516cd94c1633c4a02652ecf15a126a99c9bffb5f78e96e6e56`

It says:

- M15, not the requested source center M5;
- accumulate active Asia/London/NY-AM sub-session ranges, not the immediately previous 06:00-to-06:00 Rome session;
- after a high break and reentry, arm SHORT; after a low break and reentry, arm LONG;
- defaults wait 2 bars, SL 15 pips, TP 30 pips;
- one trade per sub-session and force-close at sub-session end plus two M15 bars.

The committed [SPEC](../../../../QM5_9987_tv-ict-session-break-reentry-retest/SPEC.md) repeats that reversal behavior. The committed EA state enum contains `ST_ARMED_SHORT` after the high-side path and `ST_ARMED_LONG` after the low-side path, and its session exit is calculated from the selected sub-session end plus the configured buffer.

## Material mismatch matrix

| Dimension | Current indexed source | Approved Card / committed QM5_9987 |
|---|---|---|
| Family | Continuation | Reversal / fakeout |
| High-side outcome | LONG | SHORT |
| Low-side outcome | SHORT | LONG |
| Reference range | Previous complete Rome-roll session | Active Asia/London/NY-AM sub-session |
| Clock | Europe/Rome, default roll 06:00 | Fixed broker-minute sub-sessions |
| Center timeframe | EURUSD M5 suggested/requested | M15 |
| Wait | 3 bars | 2 bars |
| SL / TP | 10 / 20 pips | 15 / 30 pips |
| Trade cap | New York daily counter; audit freezes 1/day | One trade per selected sub-session |
| Flat | Optional New York day end | Each sub-session end + two M15 bars |

## Provenance failure

The farm source note at `D:/QM/strategy_farm/artifacts/source_notes/30591366-874b-5bee-b47c-da2fca20b728.md` records only a one-line concept and says the Pine code on the detail page should be the authoritative P1 reference. It also asks whether Pine should be archived to prevent exactly this failure mode. No archive was created.

The approved card has `card_body_incomplete: true` and `card_body_missing: source_citation`. It attributes the script to `Burdiga84`; the current indexed listing associates the May 17 publication text with `EmptyCupTrades`. Without a hashed Pine revision, neither attribution nor exact rule fidelity can be repaired by inference.

## VPS search evidence

Filename searches covered the repository, worktrees, archives, staging/scratch/task/tmp roots, `D:/QM/research_sources`, `D:/QM/strategy_farm`, exports, and the Administrator Downloads/Documents/AppData Local roots. Needles were `*.pine`, `7IFb4Zx7`, `ICT_Session_Breakout`, and source UUID `30591366-874b-5bee-b47c-da2fca20b728`.

Relevant hits were limited to the source research note and approved card. No Pine file, HTML/PDF snapshot, or source-code artifact was found. Internet Archive CDX returned no capture for the publication URL.

## Required disposition

- Do not use QM5_9987 performance as evidence for the current continuation source.
- Do not modify QM5_9987 or another EA from this audit.
- Do not reconstruct missing Pine details and label them source-exact.
- Keep the offline result `BLOCKED_SOURCE_AMBIGUITY` until the exact Pine revision is archived and hashed, including the exact New York day-flat boundary/order and state-transition inequalities.
- If Pine is recovered, create a new pre-outcome contract revision/analysis ID before opening the market or news inputs.
