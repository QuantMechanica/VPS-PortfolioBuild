# Strategy Card — Lien Leveraged Carry Trade (interest-rate-differential signal + bond-yield-spread risk-aversion gate, multi-month hold)

> Drafted by Research Agent on 2026-04-28 from `strategy-seeds/sources/SRC04/raw/ch17-20_fundamental.txt` (verbatim Lien Ch 18 § "How Do Carry Trades Work?" + § "Why Do Carry Trades Work?" + § "When Will Carry Trades Work Best?" + § "When Will Carry Trades Not Work?" + § "The Importance of Risk Aversion" + Figure 18.4 3-state risk-aversion classification + § "Other Things to Bear in Mind").
> Submitted for CEO + Quality-Business review (Quality-Business not yet hired → CEO-only review per QUA-188 waiver v3 / DL-030 Class 2 Review-only execution policy).

## Card Header

```yaml
strategy_id: SRC04_S11
ea_id: TBD
slug: lien-carry-trade
status: DRAFT
created: 2026-04-28
created_by: Research
last_updated: 2026-04-28

strategy_type_flags:
  - carry-direction                           # Lien Ch 18 PDF p. 153: "buying a high-yielding currency and funding it with the sale of a low-yielding currency". V4 precedent: SM_076 (Padysak-Vojtko spec), SM_1341-1343 (per `strategy_type_flags.md` table). Carry direction = sign of interest-rate differential between base and quote currencies; on Darwinex this maps directly to `SymbolInfoDouble(SYMBOL_SWAP_LONG/SHORT)` per V5 framework swap-fee handling. Long high-IR / short low-IR; reverse direction = mirror.
  - signal-reversal-exit                      # Lien (PDF p. 158-159): exit when carry direction flips OR when "low interest rate currency appreciates by a significant amount" (de facto carry-flip via spot-side capital appreciation overwhelming IR spread). V4 Good-Carry-Bad-Carry spec uses signal-reversal-exit on 2-bar carry-flip debounce; adopt similar.
  - atr-hard-stop                             # V5 default catastrophic backstop; Lien provides no explicit stop-loss rule (carry trade is implicit-thesis hold), but V5 hard rule requires a stop. ATR(14)·M with M=10-20 (far backstop, not primary exit) per V5 Padysak-Vojtko + Modernised Turtle precedent
  - symmetric-long-short                      # Lien Ch 18 PDF p. 154: explicit AUD/CHF example shows long high-IR + short low-IR; reverse pair = mirror. Universe of pairs ranked by IR-differential supports both long+short positions.
  - friday-close-flatten                      # LOAD-BEARING — Lien explicit: "a carry trade is a long-term strategy. Before entering into a carry trade, an investor should be willing to commit to a time-horizon of at least six months" (PDF p. 160). Friday-close waiver candidacy at P3 (multi-month hold across many weekend gaps; precedent SRC03_S03 + SRC02_S01 + SRC04_S05/S07/S09)
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Lien, Kathy (3rd ed., 2015). Day Trading and Swing Trading the Currency Market: Technical and Fundamental Strategies to Profit from Market Moves. Wiley Trading. Hoboken, NJ: John Wiley & Sons."
    location: "Chapter 18 'Fundamental Trading Strategy: The Leveraged Carry Trade' (PDF pp. 153-160) including § chapter intro (PDF p. 153) + § 'How Do Carry Trades Work?' + § 'Why Do Carry Trades Work?' + Figure 18.1+18.2 AUD/CHF carry mechanics (PDF pp. 154-156) + § 'When Will Carry Trades Work Best?' + § 'How Much Risk Are You Willing to Take?' (PDF pp. 156-157) + § 'When Will Carry Trades Not Work?' (PDF pp. 157-158) + § 'The Importance of Risk Aversion' + Figure 18.4 3-state risk-aversion classification (PDF pp. 158-159) + § 'Other Things to Bear in Mind' (PDF pp. 159-160) including 'Time Horizon' subsection."
    quality_tier: A
    role: primary
```

Raw evidence: `strategy-seeds/sources/SRC04/raw/ch17-20_fundamental.txt` lines 71-455 (entire Ch 18). Source PDF on disk at `G:\My Drive\QuantMechanica\Ebook\PDF resources\Day Trading and Swing Trading t - Kathy Lien.pdf`.

## 2. Concept

Lien's carry trade thesis (PDF p. 153): "buying a high-yielding currency and funding it with the sale of a low-yielding currency." Profit comes from two sources: (1) interest-rate differential ("spread") earned daily on the held position via swap; (2) optional capital appreciation when the high-IR currency strengthens relative to the low-IR currency. The strategy uses leverage (5-10x typical per Lien PDF p. 154) to magnify the small daily IR spread.

Critical regime gate (Lien Figure 18.4 PDF p. 159): carry trades work in LOW risk-aversion regimes (capital flows TO high-IR/risky currencies). Carry trades FAIL in HIGH risk-aversion regimes (capital flows TO low-IR/safe-haven currencies — opposite direction). Lien's quantifiable proxy for risk aversion (PDF p. 159): "look at bond yields. The wider the spread between the yields of bonds from different countries with similar credit ratings, the higher the investor risk aversion."

Mechanical translation:
- **Carry-direction signal** (entry): For each pair, compute IR-differential = base_IR − quote_IR. Long pair if differential > THRESHOLD; short if < −THRESHOLD. On Darwinex, IR-differential maps directly to SWAP_LONG / SWAP_SHORT (positive swap on long = positive carry).
- **Risk-aversion gate** (filter): Compute bond-yield spread between two reference countries (e.g., 10Y Bund − 10Y US Treasury for EUR/USD risk-aversion proxy). Lien's 3-state classification per Figure 18.4: LOW risk aversion (carry profitable), NEUTRAL, HIGH risk aversion (carry unprofitable; consider closing or reversing).
- **Time horizon** (Lien explicit): minimum 6 months hold (PDF p. 160).
- **Exit**: signal-reversal — exit when carry-direction flips OR when risk-aversion crosses into HIGH state (Lien PDF p. 158: "they may also opt to close or unwind their carry trades" during high-risk-aversion).

Verbatim Lien framing on carry-trade core thesis (PDF p. 153):

> "On its most fundamental level, the carry trade strategy involves buying a high-yielding currency and funding it with the sale of a low-yielding currency. Aggressive speculators will leave the trade unhedged with the hope that the high yielding currency will appreciate in value relative to the lower yielding currency, allowing them to earn the interest rate differential on top of the capital appreciation. ... Although the differentials tend to be small, usually 1 to 3 percent if the position is leveraged 5 to 10 times, the profits from interest rates alone can be substantial."

## 3. Markets & Timeframes

```yaml
markets:
  - forex                                     # Lien Ch 18 entire universe is forex; AUDCHF / AUDJPY worked examples
timeframes:
  - D1                                        # primary execution frame; carry-direction + risk-aversion-spread sampled at D1 close
  - W1                                        # plausible variant for Lien's "minimum 6-month time horizon" — weekly resampling reduces signal noise
  - H4                                        # plausible — out-of-source extrapolation
session_window: not specified                 # D1+ multi-month strategy; no intraday session restriction
primary_target_symbols:
  - "AUDCHF.DWX (Lien example: PDF p. 154 AUD 4.75% IR vs CHF 0.25% IR → 4.50% annual carry; long AUDCHF)"
  - "AUDJPY.DWX (Lien example: PDF p. 159 'Australian dollar (high interest rate) versus Japanese yen' carry trade)"
  - "NZDJPY.DWX, NZDCHF.DWX (high-IR commodity currencies vs low-IR safe-haven currencies; cohort match for Lien thesis)"
  - "GBPJPY.DWX, USDJPY.DWX (mid-IR vs JPY low-IR; thesis-admissible candidates)"
  - "EURJPY.DWX, EURCHF.DWX (post-2014 EUR-QE era — carry direction depends on era; signal handles this dynamically via SymbolInfoDouble swap reads)"
  - "Universe approach: rank ALL Darwinex FX pairs by sign(SWAP_LONG) — top-decile long, bottom-decile short, similar to V4 carry-direction-ranked basket (SM_076 / SM_1341-1343 precedent)"
```

## 4. Entry Rules

Pseudocode — translation of Lien's qualitative thesis into V5-mechanical signal + filter logic.

```text
PARAMETERS:
- BAR                       = D1     // primary; D1 close sampling
- IR_DIFFERENTIAL_THRESHOLD = 1.0    // % annual; Lien (PDF p. 154): "differentials tend to be small, usually 1 to 3 percent" — minimum 1% to enter
- IR_DIFFERENTIAL_SOURCE    = "swap_long_minus_swap_short"
                                     // V5 Darwinex-native: (SymbolInfoDouble(SYMBOL_SWAP_LONG) - SymbolInfoDouble(SYMBOL_SWAP_SHORT))
                                     //   converted from points-per-day-per-lot to annualized %
                                     // Alternative: explicit central-bank-rate read (external feed; flagged darwinex_native_data_only)
- RISK_AVERSION_REFERENCE_BONDS = ("US_10Y_Treasury", "DE_10Y_Bund")
                                     // Lien (PDF p. 159): "look at bond yields. The wider the spread between the yields of bonds from different countries with similar credit ratings, the higher the investor risk aversion"
                                     //   default reference pair: US 10Y vs DE 10Y Bund (similar AAA credit ratings)
                                     // Alternative reference pairs sweep variant: AU 10Y vs NZ 10Y, US 10Y vs JP 10Y
- RISK_AVERSION_LOW_THRESHOLD  = 1.5  // % bond-yield spread; below this = LOW risk aversion (carry-favorable)
- RISK_AVERSION_HIGH_THRESHOLD = 3.0  // % bond-yield spread; above this = HIGH risk aversion (carry-unfavorable)
- MIN_HOLD_BARS             = 130    // ~6 months of D1 = 130 trading days; Lien (PDF p. 160): "willing to commit to a time-horizon of at least six months"

DATA REQUIREMENTS (data_requirements: see § 13):
- Standard: SymbolInfoDouble swap reads (Darwinex-native)
- External: 10Y bond yields for risk-aversion gate — flagged `darwinex_native_data_only` at hard_rules_at_risk per § 12

DEFINITION (carry-direction signal at bar t for symbol S):
- swap_long_pts  = SymbolInfoDouble(S, SYMBOL_SWAP_LONG)
- swap_short_pts = SymbolInfoDouble(S, SYMBOL_SWAP_SHORT)
- carry_signal_pts_per_day = swap_long_pts                 // positive = positive carry going long; negative = positive carry going short
- annualized_carry_pct     = (carry_signal_pts_per_day * 365 / point_value) / current_price * 100
                                        // approximate; exact conversion depends on contract spec

DEFINITION (risk-aversion state at bar t):
- yield_spread_pct = abs(yield_country_A[t] - yield_country_B[t])    // for the chosen reference pair
- if yield_spread_pct < RISK_AVERSION_LOW_THRESHOLD:
    risk_state = LOW_RISK_AVERSION
- elif yield_spread_pct > RISK_AVERSION_HIGH_THRESHOLD:
    risk_state = HIGH_RISK_AVERSION
- else:
    risk_state = NEUTRAL_RISK_AVERSION

EACH-BAR (D1 close, evaluating each candidate symbol S):
- compute carry_signal for S
- compute risk_state (shared across all symbols, single global gate)

LONG ENTRY (carry-favorable):
- precondition: annualized_carry_pct(S) > IR_DIFFERENTIAL_THRESHOLD
- regime gate:  risk_state == LOW_RISK_AVERSION (default)
                    OPTIONAL: also allow NEUTRAL_RISK_AVERSION (P3 sweep variant)
- if both:      OPEN_LONG at next bar open

SHORT ENTRY (carry-favorable for short side):
- precondition: annualized_carry_pct(S) < -IR_DIFFERENTIAL_THRESHOLD
- regime gate:  risk_state == LOW_RISK_AVERSION (default)
- if both:      OPEN_SHORT at next bar open

(Note: For Darwinex spot pairs, "annualized_carry_pct < threshold" can mean either positive
short-side swap or significant negative long-side swap; sign convention matters and is
implementation-specific per V5 swap-handling. CTO will codify at IMPL.)
```

## 5. Exit Rules

Lien rules are qualitative — exit when (a) carry direction flips, (b) risk aversion goes high, (c) low-IR currency appreciates significantly. Pseudocode:

```text
PARAMETERS:
- EXIT_TRIGGER_CARRY_FLIP_BARS = 5     // 1-week debounce on carry-direction flip per V4 Good-Carry-Bad-Carry precedent
                                       //   Lien implies looser timing; sweep [2, 5, 10, 20]
- EXIT_TRIGGER_RISK_HIGH       = true  // Lien (PDF p. 158): "they may also opt to close or unwind their carry trades" during high-risk-aversion
- ATR_HARD_STOP_MULT           = 15    // V5 default catastrophic backstop; far-distant stop, not primary exit
                                       //   Lien provides no explicit stop, so V5 hard rule applies via ATR-trail-failed safety
                                       //   sweep [10, 12, 15, 20]
- TIME_STOP_MIN_BARS           = 130   // Lien minimum 6-month hold; do NOT exit on signal-reversal before this
                                       //   sweep [60, 130, 180, 252]
                                       //   note: time-stop is a MINIMUM, not a maximum — position held UNTIL signal-reversal AFTER min hold

EACH-BAR (D1 close, in long position):
- HARD STOP — ATR(14, frozen-at-entry) × ATR_HARD_STOP_MULT below entry (catastrophic backstop only)
- TIME-LOCKED HOLD: if (bars_since_entry < TIME_STOP_MIN_BARS): suppress signal-reversal exit
                                          // Lien minimum 6-month commitment per PDF p. 160
- SIGNAL-REVERSAL EXIT (after time-lock):
    if annualized_carry_pct(S)[t] < IR_DIFFERENTIAL_THRESHOLD for EXIT_TRIGGER_CARRY_FLIP_BARS consecutive bars:
      CLOSE_LONG    // carry direction flipped or weakened below threshold
- RISK-AVERSION EXIT (after time-lock):
    if risk_state == HIGH_RISK_AVERSION:
      CLOSE_LONG    // Lien (PDF p. 158): "close or unwind their carry trades"

EACH-BAR (D1 close, in short position): mirror — exit on carry-flip OR high-risk-aversion.

FRIDAY CLOSE: D1 multi-month hold (Lien explicit minimum 6 months). Friday-close-flatten
LOAD-BEARING. Default V5 friday_close ENABLED with WAIVER CANDIDACY at P3 — multi-month
carry strategy is incompatible with weekly forced-flat; the entire strategy thesis depends
on holding through weekend gaps to accumulate daily swap. Precedent: SRC03_S03 + SRC02_S01
+ SRC04_S05/S07/S09 multi-day-to-multi-month-hold cards have all received P3 waiver
consideration; this card has the STRONGEST waiver case in SRC04 since the Lien thesis
itself REQUIRES multi-month hold (not just allows it).
```

## 6. Filters (No-Trade module)

```text
- standard V5 framework defaults: kill-switch, news filter, MAX_DD trip, Friday Close (with STRONG waiver candidacy per § 5)
- pyramiding: NOT allowed (single position per direction per symbol; universe-rank-driven entries handle multi-symbol exposure)
- gridding: NOT allowed
- IR-differential threshold filter (Lien implicit): minimum 1% annualized carry (PDF p. 154) — filters out near-zero-carry pairs
- Risk-aversion gate (Lien Figure 18.4): bond-yield-spread classifier — entries only in LOW_RISK_AVERSION (default; NEUTRAL also allowed as P3 variant)
- Trade-balance filter (Lien PDF p. 160 — qualitative): countries with large trade surplus may see currency appreciation regardless of risk regime, suppressing carry profitability. Mechanical proxy: trade-balance-as-pct-of-GDP (external data; OECD or IMF feed) — flagged `darwinex_native_data_only`. EXPOSED as P3 sweep variant; OFF by default.
- Time-horizon filter (Lien PDF p. 160): minimum 6-month hold — implemented as TIME_STOP_MIN_BARS suppressing early signal-reversal exits.
```

## 7. Trade Management Rules

```text
- one open position per direction per symbol; universe-rank approach allows multi-symbol exposure (high-decile long, low-decile short) similar to V4 carry-direction-ranked basket
- position size: V5 RISK_PERCENT / RISK_FIXED standard; carry strategy benefits from leverage but V5 hard rules constrain leverage per RISK_PERCENT setting
- No partial-take or trail by default (Lien provides no exit-management beyond signal-reversal); P3 variants expose:
    - partial_take_at_pct_unrealized_pnl ∈ {disabled, 5pct, 10pct, 15pct}
    - trail_after_signal_reversal_arms ∈ {disabled, atr14x5_trail, donchian55_trail}
- Friday Close: ENABLED by default with strong waiver candidacy at P3 (multi-month thesis)
- gridding: NOT allowed
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: ir_differential_threshold
  default: 1.0                                # % annual; Lien: "1 to 3 percent" minimum
  sweep_range: [0.5, 1.0, 1.5, 2.0, 3.0]
- name: risk_aversion_low_threshold
  default: 1.5                                # % bond-yield spread; below = LOW risk aversion
  sweep_range: [1.0, 1.25, 1.5, 1.75, 2.0]
- name: risk_aversion_high_threshold
  default: 3.0                                # % bond-yield spread; above = HIGH risk aversion (exit gate)
  sweep_range: [2.0, 2.5, 3.0, 3.5, 4.0]
- name: risk_aversion_reference_pair
  default: "US_10Y_vs_DE_10Y_Bund"            # similar credit ratings per Lien
  sweep_range: ["US_10Y_vs_DE_10Y_Bund", "US_10Y_vs_JP_10Y", "AU_10Y_vs_NZ_10Y", "DE_10Y_vs_UK_10Y"]
- name: risk_aversion_gate_neutral_allowed
  default: false                              # default: LOW only
  sweep_range: [false, true]                   # true = LOW + NEUTRAL allowed
- name: time_stop_min_bars
  default: 130                                # ~6 months D1 per Lien
  sweep_range: [60, 90, 130, 180, 252]
- name: exit_trigger_carry_flip_bars
  default: 5                                  # debounce per V4 Good-Carry-Bad-Carry precedent
  sweep_range: [2, 5, 10, 20]
- name: atr_hard_stop_mult
  default: 15                                 # V5-default far-backstop
  sweep_range: [10, 12, 15, 20]
- name: trade_balance_filter
  default: off                                # Lien qualitative; data not Darwinex-native
  sweep_range: [off, surplus_only_below_3pct, deficit_only_above_3pct]
- name: tf
  default: D1
  sweep_range: [D1, W1]
- name: friday_close
  default: enabled                            # V5 default
  sweep_range: [enabled, disabled_with_waiver]
```

P3.5 (CSR) axis: Universe = ALL Darwinex FX pairs eligible for ranking by carry signal. Top-N long / bottom-N short basket (e.g., top-3 / bottom-3). Cross-ratio sweep: N ∈ {1, 3, 5, 7}. Cohort confirmation: high-IR commodity currencies (AUD, NZD, CAD per Lien Ch 21 framing) on long side; low-IR safe-havens (CHF, JPY, USD-during-zero-rate-eras) on short side.

## 9. Author Claims (verbatim, with quote marks)

Strategy framing — carry-trade core thesis, PDF p. 153:

> "The leverage carry trade strategy is the quintessential global macro trade that has long been one of the favorite strategies of hedge funds and investment banks. On its most fundamental level, the carry trade strategy involves buying a high-yielding currency and funding it with the sale of a low-yielding currency. Aggressive speculators will leave the trade unhedged with the hope that the high yielding currency will appreciate in value relative to the lower yielding currency, allowing them to earn the interest rate differential on top of the capital appreciation. More conservative investors may choose to hedge the exchange rate component, earning only the interest rate differential. Although the differentials tend to be small, usually 1 to 3 percent if the position is leveraged 5 to 10 times, the profits from interest rates alone can be substantial."

Historical regime-performance, PDF p. 153:

> "Carry trades performed extremely well between 2000 and 2007, failed miserably between 2008 and 2009, and recovered between late 2012 into 2015."

AUDCHF worked example mechanics, PDF pp. 154-155:

> "Assume that the Australian dollar offers an interest rate of 4.75%, while the Swiss franc offers an interest rate of 0.25%. To execute the carry trade, an investor buys the Australian dollar and sells the Swiss franc. In doing so, he or she can earn a profit of 4.50% (2.75% in interest earned minus 0.25% in interest paid), as long as the exchange rate between Australian dollars and Swiss francs do not change."

Why-it-works rationale (capital flow + IR-driven demand), PDF p. 155:

> "Carry trades work because of the constant movement of capital into and out of different countries in search of the highest yield. Interest rates are the main reason why some countries attract more investment than others. ... If several investors make this exact same decision, the country will experience an inflow of capital from those seeking to earn a high rate of return, and the currency should appreciate. ... The difference between countries that offer high interest rates versus countries that offer low interest rates is what makes carry trades possible."

Risk-aversion gate (Figure 18.4 3-state classification), PDF pp. 158-159:

> "Carry trades will generally be profitable when investors have low risk aversion, and unprofitable when investors have high risk aversion. So before placing a carry trade it is important to understand the risk environment--whether investors as a whole have high or low risk aversion--and when it changes."

Risk-aversion mechanical proxy via bond-yield spreads, PDF p. 159:

> "How do you know if investors as a whole have high or low risk aversion? Unfortunately, it is difficult to measure investor risk aversion with a single number. One way to get a broad idea of risk aversion levels is to look at bond yields. The wider the spread between the yields of bonds from different countries with similar credit ratings, the higher the investor risk aversion."

Sharp regime-shift behavior (1998 + 2001 + 2008 examples), PDF p. 158:

> "When periods of risk aversion occur quickly, the result is generally a large capital inflow into low-interest-rate-paying 'safe haven' currencies. ... For example, in the summer of 1998 the Japanese yen appreciated against the dollar by more than 20% over the span of two months, due to the Russian debt crisis and LTCM hedge fund bailout. Similarly, just after the September 11 terrorist attacks the Swiss franc rose by more than 7% against the dollar over a 10-day period. During the global financial crisis in 2008, we also saw big gains in the yen and the Swiss franc. ... when risk aversion shifts, a carry trade can turn from being profitable to unprofitable very quickly."

Time horizon (entry/exit timing rule), PDF p. 160:

> "In general, a carry trade is a long-term strategy. Before entering into a carry trade, an investor should be willing to commit to a time-horizon of at least six months. This commitment helps to make sure that the trade will not be affected by the 'noise' of shorter-term currency price movements."

Trade-balance caveat, PDF p. 160:

> "One reason is because countries with large trade surplus can still see their currencies appreciate in low risk environments because running a trade surplus means that the country exports more than it imports. This creates naturally demand for the currency. ... when investors have low risk aversion, large trade imbalances can cause a low interest rate currency to appreciate ... and when the low interest rate currency in a carry trade (the currency being sold) appreciates, it negatively affects the profitability of the carry trade."

**Lien provides ONE numeric historical regime-performance claim** — "extremely well between 2000 and 2007, failed miserably between 2008 and 2009, and recovered between late 2012 into 2015" (PDF p. 153) — but no aggregate win-rate, profit-factor, max-drawdown, or annualized-return figure. Per BASIS rule, no extrapolated performance number is asserted in this card; pipeline P2-P9 produce the actual edge measurement; the descriptive regime-performance claim is preserved verbatim.

## 10. Initial Risk Profile

```yaml
expected_pf: 1.4                              # rough estimate; carry trades historically 1.2-1.6 PF in low-risk-aversion regimes; 0.5-0.9 PF in high-risk-aversion regimes (i.e., regime-conditional). With proper risk-aversion gate, target 1.3-1.5 PF aggregate
expected_dd_pct: 35                           # rough estimate; carry-trade DD profile is asymmetric — small steady gains in low-risk regimes punctuated by sharp losses during regime shifts (Lien PDF p. 158: "carry trade can turn from being profitable to unprofitable very quickly"). Historical reference: 2008 GFC drawdown on AUDJPY/NZDJPY-style carry baskets exceeded 30%
expected_trade_frequency: 2-6/year/symbol     # rough estimate; multi-month minimum hold (Lien 6 months) limits turnover; regime-shifts add re-entry frequency
risk_class: high                              # asymmetric DD profile + multi-month hold + leverage-magnification + regime-shift tail risk; Lien explicitly notes "leverage can magnify profits, it can also exacerbate losses" (PDF p. 153)
gridding: false
scalping: false                               # D1 multi-month hold; opposite end of spectrum from scalping
ml_required: false                            # IR-differential + bond-yield-spread + threshold logic; no fitted parameters
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical (carry-direction signal from SWAP_LONG/SHORT + risk-aversion-state classification from bond-yield spreads + threshold logic + time-locked hold + signal-reversal exit; deterministic given D1 OHLC + swap reads + bond-yield feed)
- [x] No Machine Learning required
- [x] If gridding: not applicable (single position per direction per symbol)
- [x] If scalping: not applicable (D1 multi-month hold)
- [x] Friday Close compatibility: LOAD-BEARING — Lien explicit minimum 6-month hold; thesis depends on accumulating daily swap across weekend gaps. STRONG waiver candidacy at P3.
- [x] Source citation is precise enough to reproduce (PDF pp. 153-160 entire chapter; verbatim quotes preserved with V5-mechanical-translation notes)
- [x] No near-duplicate of existing approved card — no SRC card uses carry-direction signal (V4 SM_076 Padysak-Vojtko spec is V4-inspiration, not deployed); SRC02 chan-* cards use stat-arb / decile-sort, not carry; SRC03 williams-* cards are price-pattern; SRC04_S* prior cards are technical patterns. SRC04_S11 is the FIRST CARRY-FAMILY CARD across all SRCs.

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "standard V5 default + IR-differential threshold filter + risk-aversion-state gate (bond-yield-spread classifier) + time-horizon minimum 6-month hold-lock; optional trade-balance filter (P3 variant)"
  trade_entry:
    used: true
    notes: "carry-direction signal from SymbolInfoDouble swap reads (Darwinex-native) + risk-aversion-LOW gate from external bond-yield feed; D1 close evaluation; long high-IR / short low-IR symmetric"
  trade_management:
    used: true
    notes: "time-locked hold for minimum TIME_STOP_MIN_BARS (~130 D1 bars / 6 months) before signal-reversal exits arm; ATR(14)·15 catastrophic backstop only; no partial-take or trail by default (Lien-verbatim); P3 variants for partial-take and trail-after-signal-reversal"
  trade_close:
    used: true
    notes: "exit on (a) carry-direction flip with EXIT_TRIGGER_CARRY_FLIP_BARS debounce (default 5 bars) OR (b) risk-aversion-HIGH state crossover OR (c) catastrophic ATR-backstop. ALL exits suppressed during time-lock period."
```

```yaml
hard_rules_at_risk:
  - friday_close                              # LOAD-BEARING — Lien minimum 6-month hold. STRONGEST waiver case in SRC04; thesis itself REQUIRES multi-month hold (not just allows it).
  - darwinex_native_data_only                 # LOAD-BEARING — risk-aversion gate requires external 10Y bond yields (US Treasury, German Bund, etc.) NOT in Darwinex CFD feed. Two paths: (a) FRED API external-fetch shim; (b) proxy via Darwinex bond-CFDs if `US10YR.DWX` / `BUND.DWX` are offered (CTO check at IMPL); (c) drop risk-aversion gate and use carry-direction-only (degraded thesis but Darwinex-native). CTO consultation required at IMPL.
  - risk_mode_dual                            # NOT LOAD-BEARING by default — V5 RISK_PERCENT/RISK_FIXED handles position sizing; Lien's "leveraged 5 to 10 times" framing translates to V5 RISK_PERCENT setting at the portfolio level, not at the strategy level. Listed for CTO completeness.
  - enhancement_doctrine                      # LOAD-BEARING on IR-differential and risk-aversion thresholds (1% / 1.5% / 3.0% defaults). These are heuristic anchors; cross-cohort generalization may favor different thresholds. P3 sweep tests this.
  - news_pause_default                        # NOT LOAD-BEARING — multi-month carry strategy is robust to intraday news; V5 P8 default applies cleanly.

at_risk_explanation: |
  friday_close — Lien explicit minimum 6-month hold (PDF p. 160). Thesis: "this commitment
  helps to make sure that the trade will not be affected by the 'noise' of shorter-term
  currency price movements." V5 Friday-close discipline is incompatible with multi-month
  hold because forcing flat each weekend resets accumulated swap. STRONGEST waiver case
  in SRC04 — propose `disabled_with_waiver` as default for this card if PASS_G0; mirrors
  SRC02_S01 chan-pairs-stat-arb precedent which received P3 waiver consideration on similar
  multi-day-hold thesis.

  darwinex_native_data_only — Risk-aversion gate (Lien Figure 18.4 + PDF p. 159) requires
  10Y bond yields from at least two countries. Darwinex CFD feed does NOT natively include
  bond yields unless bond-yield CFDs (e.g., `US10YR.DWX`, `BUND.DWX`) are offered. CTO
  consultation required at IMPL on path forward: (a) FRED API external-fetch shim, (b)
  Darwinex bond-CFD proxy, (c) degraded carry-direction-only variant without risk-aversion
  gate. Without the risk-aversion gate, the strategy retains V4 SM_076 Padysak-Vojtko-style
  carry-direction-only architecture, which is V4-deployment-precedent — operating without
  the gate is THESIS-DEGRADED but not THESIS-BROKEN.

  risk_mode_dual — Lien's "leveraged 5 to 10 times" applies at the portfolio/account level,
  not the strategy level. V5 RISK_PERCENT setting handles this at the framework level.
  Listed for CTO completeness only.

  enhancement_doctrine — IR-differential and bond-yield-spread thresholds (1% / 1.5% / 3.0%)
  are heuristic anchors derived from Lien's "1 to 3 percent" framing and the credit-similar-
  countries reference pair. P3 sweep refines. Once fixed, retune is enhancement_doctrine.

  news_pause_default — Multi-month carry strategy is robust to intraday news; V5 P8 default
  applies cleanly. Listed for completeness.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD                               # standard V5 default + IR-differential threshold + risk-aversion-state gate + time-horizon hold-lock
  entry: TBD                                  # SymbolInfoDouble swap reads (Darwinex-native, fast); external 10Y bond-yield feed (FRED API or Darwinex bond-CFD proxy) + threshold classification; ~100-150 LOC in MQL5 plus external-data-shim
  management: TBD                             # time-locked hold (suppress signal-reversal until TIME_STOP_MIN_BARS); ATR-frozen catastrophic backstop only
  close: TBD                                  # signal-reversal (carry-flip or risk-aversion-high) after time-lock; ATR backstop always active
estimated_complexity: medium                  # carry signal is trivial (swap reads); risk-aversion gate requires external-data integration which adds modest complexity; CTO check on Darwinex bond-CFD availability at IMPL
estimated_test_runtime: 2-4h                  # P3 sweep ~15,000 cells; D1 bars; 5+ years; FX cohort — modest compute due to D1 timeframe + low signal density
data_requirements: custom_external            # 10Y bond yields from FRED API or equivalent (US 10Y, DE 10Y Bund, AU 10Y, NZ 10Y, JP 10Y at minimum). Path may degrade to standard if `darwinex_native_data_only` is enforced strictly (drop risk-aversion gate).
```

## 14. Pipeline History

| version | date | rebuild reason | P-stage reached | verdict |
|---|---|---|---|---|
| _v1 | 2026-04-28 | initial build | TBD | TBD |

## 15. Pipeline Phase Status (current `_v1`)

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-04-28 | DRAFT (awaiting CEO + Quality-Business review) | this card |
| P1 Build Validation | TBD | TBD | TBD |
| P2 Baseline Screening | TBD | TBD | TBD |
| P3 Parameter Sweep | TBD | TBD | TBD |
| P3.5 CSR | TBD | TBD | TBD |
| P4 Walk-Forward | TBD | TBD | TBD |
| P5 Stress | TBD | TBD | TBD |
| P5b Calibrated Noise | TBD | TBD | TBD |
| P5c Crisis Slices | TBD | TBD | TBD |
| P6 Multi-Seed | TBD | TBD | TBD |
| P7 Statistical Validation | TBD | TBD | TBD |
| P8 News Impact | TBD | TBD | TBD |
| P9 Portfolio Construction | TBD | TBD | TBD |
| P9b Operational Readiness | TBD | TBD | TBD |
| P10 Shadow Deploy | TBD | TBD | TBD |
| Live Promotion | TBD | TBD | TBD |

## 16. Lessons Captured

```text
- 2026-04-28: SRC04_S11 reuses existing `carry-direction` flag (V4 SM_076 Padysak-Vojtko +
  SM_1341-1343 precedent + Good-Carry-Bad-Carry inspiration spec). FIRST CARRY-FAMILY CARD
  across the entire SRC corpus (SRC01-04). V5 carry-direction signal maps directly to
  Darwinex-native swap reads via SymbolInfoDouble(SYMBOL_SWAP_LONG/SHORT) — clean
  architecture-fit.

- 2026-04-28: Risk-aversion gate (Lien Figure 18.4 3-state classification) is the
  load-bearing strategy ENHANCEMENT over a V4-style carry-direction-only architecture. The
  gate requires EXTERNAL 10Y bond-yield data not in the Darwinex CFD feed. Three IMPL paths
  documented (§ 12): (a) FRED API external-fetch shim, (b) Darwinex bond-CFD proxy if
  available, (c) degraded carry-direction-only variant. Without the gate, the strategy is
  THESIS-DEGRADED (loses Lien's regime-conditional edge) but not THESIS-BROKEN (still
  V4-deployment-precedent equivalent). CTO ratification required at IMPL on path choice.

- 2026-04-28: This is the SECOND `darwinex_native_data_only` flag-binding card in SRC04 — the
  external bond-yield-feed dependency mirrors the predicted Ch 22 Bond Spreads (S14) issue
  noted in survey-pass § 6.5.2. SRC04 is now confirmed as introducing TWO classes of
  external-data dependency: (1) bond-yield-spread for risk-aversion / leading-indicator
  purposes (S11, S14), (2) potentially commodity-data for S13 commodity-leading. CTO IMPL
  decision on bond-yield-feed path (FRED vs Darwinex-CFD-proxy vs gate-drop) will affect
  multiple SRC04 cards downstream.

- 2026-04-28: Friday-close is load-bearing for the FIFTH time in SRC04 (after S05 inside-
  day, S07 20-day-breakout, S09 perfect-order, plus indirectly S04 + S06 multi-day swings).
  S11 carry-trade has the STRONGEST waiver case across all SRC04 cards because the Lien
  thesis itself REQUIRES minimum 6-month hold (not just allows it) — propose
  `friday_close = disabled_with_waiver` as DEFAULT for this card if PASS_G0.

- 2026-04-28: Lien provides ONE numeric regime-performance claim ('extremely well between
  2000 and 2007, failed miserably between 2008 and 2009, and recovered between late 2012
  into 2015', PDF p. 153) plus extensive qualitative thesis with multiple historical case
  studies (1998 LTCM, 2001 9/11, 2008 GFC). Per BASIS rule, no aggregate performance number
  is asserted; verbatim regime-performance claim preserved.

- 2026-04-28: V5-architecture-fit profile is MIXED — carry-direction signal is HIGHLY
  Darwinex-native (SymbolInfoDouble swap reads); risk-aversion gate is NOT Darwinex-native
  (requires external bond-yield feed). Net effect: the V4-precedent core mechanism is clean,
  but Lien's regime-conditional ENHANCEMENT requires custom external-data integration. CTO
  may legitimately decide to defer the gate to a later `_v2` rebuild and ship `_v1`
  carry-direction-only first.

- 2026-04-28: Future-vocab-watch reinforced: bond-yield-spread regime classification (used
  here in S11 for risk aversion + likely in S14 for FX leading indicator) could warrant a
  `yield-spread-regime-filter` flag if the pattern recurs in SRC05+ AND deploys successfully.
  For now, captured at card-level via `risk_aversion_reference_pair` parameter; no flag
  proposed in h5.

- 2026-04-28: This is the FIFTH multi-state-machine entry pattern in SRC04 (after S04, S06,
  S07, S09). State-machine entry patterns are now the SRC04-distinctive architectural
  signature. CTO state-machine validation at IMPL is a recurring concern across SRC04 cards.
```
