# STR-103 — Source extract

**Source:** harmonicphil, "3 Little Pigs Trading System", BabyPips forum thread
#54174, post #1 (2013-06-27; author's formalized ruleset of the Forex-Useful manual),
https://forums.babypips.com/t/3-little-pigs-trading-system/54174
PDF: `Web-Sources/forums.babypips.com_t_3-little-pigs-trading-system_54174.pdf`
(30 pages; decisive: post #1). Full extract: scratchpad `str103_src_full.txt`.

## Stated rules (verbatim anchors, post #1)

- Alignment: BUY only if price above SMA55(W1) AND above SMA21(D1); SELL vice versa.
- Entry BUY: "On close of the next candle that touches and then closes above the
  34 SMA on the 4 Hour timeframe" (given W1+D1 alignment).
- Stop loss: ATR(14) on H4: "I add the High and the Low values (displayed on the
  right) and multiply this by 25% — I place my stop above/below the 34 SMA … by
  this number of PIPs." Worked example: ATR high 26 + low 14 = 40 → 25% = 10 pips;
  SL = SMA34 − 10 pips (long). Entry = candle close (+spread).
- Trailing: "Trailing Stop loss behind the 34 SMA on the same basis" (SMA rises →
  stop follows at SMA34 − offset).
- Target: "open target and exit only when my Trailing Stop loss is taken out".
- Re-entry: "If I get stopped out I will re-enter according to my Entry rules."
- Staged-alignment rule: H4 cross while D1 (or W1) not aligned → WAIT; once both
  aligned and price still beyond SMA34(H4) → enter on close of the NEXT H4 candle.
- Pairs: AUDUSD, EURGBP, EURJPY, EURUSD, GBPUSD, USDCAD, USDCHF, USDJPY.
- Risk: 1% of account per trade (from the manual).

## Source ambiguities (for reconciliation)

1. "High and the Low values (displayed on the right)" of ATR(14): the MT4
   indicator-window scale shows max/min of the VISIBLE ATR series — visible range
   is not deterministic; a fixed lookback must be chosen.
2. W1/D1 "price above SMA": forming-bar vs closed-bar semantics unstated.
3. Trailing update cadence (tick vs H4 close) unstated; ratchet-only assumed
   (never loosen) but not stated verbatim.
4. "Touches" = does the bar's low (long case) have to reach SMA34 exactly, or
   trade below it intra-bar? (Touch ≡ Low ≤ SMA34 assumed.)
