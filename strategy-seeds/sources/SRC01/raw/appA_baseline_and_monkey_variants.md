---
source_id: SRC01
source_pdf: "G:\\My Drive\\QuantMechanica\\Ebook\\PDF resources\\Building Winning Algorithmic Tr - Kevin J. Davey.pdf"
extracted_section: Appendix A — Monkey Trading Example, TradeStation EasyLanguage Code (4 variants)
book_pages: 247-253
extraction_method: poppler `pdftotext -layout`
extracted_by: Research Agent (2026-04-27 22:25 local; this run, not the foreign file at appA_monkey_baseline.md)
filename_distinct_from: appA_monkey_baseline.md  # foreign-process file with attribution drift; my own extraction lives here under a distinct name
---

# Appendix A — Monkey Trading Example (4 variants: 1 baseline strategy + 3 randomized test instruments)

This appendix contains FOUR EasyLanguage code blocks Davey labels Strategy 1 / 2 / 3 / 4. Reproduced verbatim below. Cross-references to Chapter 12 ("Limited Testing") § "Monkey See, Monkey Do" pp. 109-110 explain Davey's purpose for the four variants.

## Davey's purpose (Chapter 12 framing, pp. 109-110)

> "One of the last tests I like to run is what I call 'Monkey See, Monkey Do.' The essence of the test is to see if my strategy does better than a dart-throwing monkey. ... With any strategy I create, the strategy's performance better be significantly improved over what any monkey could do by just throwing darts. If it is not, then I have no desire to trade such a strategy. I use three different monkey tests and two different time frames for testing." (Ch 12 p. 109)

> "Test 1: 'Monkey Entry' ... I simply replace the entry in my strategy with an entry [that] creates a randomly generated entry. I run the random entry, with the rest of my strategy intact, 8,000 times. ... Typically, a good strategy will beat the monkey 9 times out of 10 in net profit and in maximum drawdown." (Ch 12 p. 109)

> "Test 2: 'Monkey Exit' ... I look for my walk-forward results to be better than 90 percent of the monkey exits." (Ch 12 p. 110)

> "Test 3: 'Monkey Entry, Monkey Exit' ... After determining that my strategy is better than both a monkey entry and a monkey exit, I like to see that my strategy is better than a monkey entry and exit. I do this because sometimes my edge is in the interaction of the entry and exit." (Ch 12 p. 110)

So:

- **Strategy 1 (Baseline, no randomness):** the actual mechanical strategy (3-bar mean-reversion + ATR stop) used as the "baseline" against which the monkey tests are run.
- **Strategy 2 (Random Entry, Baseline Exit):** test instrument for "is my entry better than random?"
- **Strategy 3 (Baseline Entry, Random Exit):** test instrument for "is my exit better than random?"
- **Strategy 4 (Random Entry, Random Exit):** test instrument for "is my entry+exit interaction better than random?"

## Strategy 1 — verbatim EasyLanguage code

```easylanguage
input: nContracts(1);
var:ssl1(1);
var:ssl(2000);

   if date >= 1070316 and date < 1080314 then begin ssl1 = 0.75 ; end ;
   if date >= 1080314 and date < 1090311 then begin ssl1 = 0.75 ; end ;
   if date >= 1090311 and date < 1100310 then begin ssl1 = 0.75 ; end ;
   if date >= 1100310 and date < 1110309 then begin ssl1 = 0.5  ; end ;
   if date >= 1110309 and date < 1120310 then begin ssl1 = 0.5  ; end ;
   if date >= 1120310 and date < 1130308 then begin ssl1 = 1.25 ; end ;
   if date >= 1130308 and date < 1140308 then begin ssl1 = .75  ; end ;

   if date >= 1070316 then begin
      if close<close[1] and close[1]<close[2] then begin
         buy ncontracts Contracts next bar at market;
      end;
      if close>close[1] and close[1]>close[2] then begin
         SellShort ncontracts Contracts next bar at market;
      end;
      SetStopContract;
      setstoploss(minlist(ssl1*BigPointValue*avgtruerange(14),ssl));
   end;
```

### Research's interpretation (NOT verbatim — flagged)

- **Date format `1070316` etc. = `1`-prefixed YYMMDD.** So `1070316` = 2007-03-16, `1140308` = 2014-03-08. Walk-forward window starts 2007-03 — earlier than the Euro Day/Night strategies (which start 2009), suggesting Strategy 1 was tested on a longer dataset.
- **Walk-forward parameter (`ssl1`)** is recalibrated every ~12 months: 0.5 → 0.75 → 1.25 across seven 12-month windows. `ssl` is fixed at 2000 (a dollar-cap on the stop).
- **Entry rule — MEAN-REVERSION (NOT momentum):**
  - `if close<close[1] and close[1]<close[2]` means the close has been DECLINING for three consecutive bars (close[2] > close[1] > close). When this is true → **BUY** (long).
  - `if close>close[1] and close[1]>close[2]` means three consecutive RISING closes (close[2] < close[1] < close). When this is true → **SHORT**.
  - This is **mean-reversion against 3-bar consecutive-direction momentum**, not "consecutive-direction momentum entry" as the foreign-process file at `appA_monkey_baseline.md` reads it. The buy fires AFTER three down closes (buying the dip); the short fires AFTER three up closes (shorting the rally).
- **Stop rule:** `setstoploss(minlist(ssl1 * BigPointValue * avgtruerange(14), ssl))` — stop in USD per contract, equal to the SMALLER of:
  - `ssl1 * BigPointValue * ATR(14)` — i.e., `ssl1` ATRs in dollar terms (ssl1 ranges 0.5-1.25 across walk-forward windows)
  - `ssl = 2000` — fixed $2,000 cap
- **No explicit profit target, no time exit.** Position closes only via the ATR-or-cap stop, OR on the next opposite-direction-trigger market order (which would reverse the position).
- **Instrument NOT specified in App A.** `BigPointValue` is contract-specific (different on every futures market). Davey uses Strategy 1 generically as "the baseline mechanical strategy" in his Ch 12 demonstration; the App A code does not commit to a particular instrument.
- **Bar size NOT specified in App A.** Walk-forward windows of ~12 months suggest daily or higher bar size, but the code does not commit.

## Strategy 2 — verbatim EasyLanguage code

```easylanguage
input:
   iter(1),percentlong(.400),holdbars(2.5),exitclose(0),oddstradetoday(.47),
   begindate(1070319);
var:posstradetoday(0);

input: nContracts(1);
var:ssl1(1);
var:ssl(2000);

   if date >= 1070316 and date < 1080314 then begin ssl1 = 0.75 ; end ;
   if date >= 1080314 and date < 1090311 then begin ssl1 = 0.75 ; end ;
   if date >= 1090311 and date < 1100310 then begin ssl1 = 0.75 ; end ;
   if date >= 1100310 and date < 1110309 then begin ssl1 = 0.5  ; end ;
   if date >= 1110309 and date < 1120310 then begin ssl1 = 0.5  ; end ;
   if date >= 1120310 and date < 1130308 then begin ssl1 = 1.25 ; end ;
   if date >= 1130308 and date < 1130501 then begin ssl1 = .75  ; end ;
                                                                  // NB: Strategy 2's last walk-forward block ends 1130501 (2013-05-01)
                                                                  //     vs Strategy 1's 1140308 (2014-03-08). Likely a typo in the source.

   if date >= 1070316 then begin
      if close<close[1] and close[1]<close[2] then begin
         sell ncontracts Contracts next bar at market;          // EXIT long position when 3 down closes (Strategy 1's BUY rule, used here as exit)
      end;
      if close>close[1] and close[1]>close[2] then begin
         buytocover ncontracts Contracts next bar at market;    // EXIT short position when 3 up closes
      end;
      SetStopContract;
      setstoploss(minlist(ssl1*BigPointValue*avgtruerange(14),ssl));
   end;

posstradetoday = random(1);                                      // random number in [0,1) for today
If date > begindate then begin
   If posstradetoday <= oddstradetoday then begin                // 47% chance of trading today
      If random(1) < percentlong then buy this bar at close      // 40% chance long
         Else sellshort this bar at close;                       //  60% chance short
   end;
end;
```

### Research's interpretation

- **Random entry:** 47% (`oddstradetoday`) chance of trading on any given day. Conditional on trading: 40% chance of long (`percentlong`), 60% chance of short. Market order at close.
- **"Baseline exit":** the 3-bar consecutive-direction rule from Strategy 1 is reused here — but now applied to CLOSING the position. When 3 down closes happen, sell out of any long; when 3 up closes happen, buy-to-cover any short. Plus the same ATR-or-cap stop as Strategy 1.
- **Davey's intent (Ch 12 p. 109):** test whether Strategy 1's entry rule actually has edge by replacing it with a random-but-frequency-matched entry. If Strategy 1's edge is on the entry side, Strategy 1 should beat Strategy 2 in 9/10 random trials.

## Strategy 3 — verbatim EasyLanguage code

```easylanguage
input:
   iter(1),percentlong(.400),holdbars(2.5),exitclose(0),oddstradetoday(.47),
   begindate(1070319);
var:posstradetoday(0);

input: nContracts(1);
var:ssl1(1);
var:ssl(2000);

   if date >= 1070316 and date < 1080314 then begin ssl1 = 0.75 ; end ;
   if date >= 1080314 and date < 1090311 then begin ssl1 = 0.75 ; end ;
   if date >= 1090311 and date < 1100310 then begin ssl1 = 0.75 ; end ;
   if date >= 1100310 and date < 1110309 then begin ssl1 = 0.5  ; end ;
   if date >= 1110309 and date < 1120310 then begin ssl1 = 0.5  ; end ;
   if date >= 1120310 and date < 1130308 then begin ssl1 = 1.25 ; end ;
   if date >= 1130308 and date < 1140308 then begin ssl1 = .75  ; end ;

   if date >= 1070316 then begin
      if close<close[1] and close[1]<close[2] and marketposition=0 then begin
         buy ncontracts Contracts next bar at market;          // baseline entry (Strategy 1) gated to flat
      end;
      if close>close[1] and close[1]>close[2] and marketposition=0 then begin
         SellShort ncontracts Contracts next bar at market;
      end;
   end;

posstradetoday = random(1);
If barssinceentry >= random(2*holdbars) then begin            // random hold (avg = holdbars = 2.5 bars; max ~5 bars)
   Sell this bar at close;
   Buytocover this bar at close;
end;
   If exitclose=1 then setexitonclose;
```

### Research's interpretation

- **"Baseline entry":** same 3-bar consecutive-direction logic as Strategy 1, gated to `marketposition = 0` (flat). No ATR stop here — the only exit is the random hold time.
- **Random exit:** `barssinceentry >= random(2*holdbars)` with `holdbars = 2.5`. So random exit at any point between 0 and 5 bars after entry, average 2.5 bars. Both `Sell` and `Buytocover` fire at close (one of them is a no-op depending on direction).
- **Optional exitclose flag:** `If exitclose=1 then setexitonclose` — input `exitclose=0` by default, so this is OFF.
- **Davey's intent (Ch 12 p. 110):** test whether Strategy 1's exit rule (the implicit "next opposite-direction trigger" exit) has edge by replacing it with random hold time.

## Strategy 4 — verbatim EasyLanguage code

```easylanguage
input:
   iter(1),percentlong(.400),holdbars(2.5),exitclose(0),oddstradetoday(.48),
   gindate(1070319);                                          // NB: source-text shows "gindate" (truncated "begindate" — pdftotext layout artifact)
var:posstradetoday(0);

posstradetoday = random(1);

If date > begindate then begin
   If posstradetoday <= oddstradetoday then begin             // 48% chance of trading today (NB: 0.48 here vs 0.47 in Strategies 2/3)
      If random(1) < percentlong then buy this bar at close   // 40% long, 60% short
         Else sellshort this bar at close;
   end;
end;

If barssinceentry >= random(2*holdbars) then begin
   Sell this bar at close;
   Buytocover this bar at close;
end;
   If exitclose=1 then setexitonclose;
```

### Research's interpretation

- **Pure random.** Both entry and exit are random. No ATR stop. No baseline entry/exit logic.
- **Davey's intent (Ch 12 p. 110):** "Monkey Entry, Monkey Exit" — fully random comparator. If Strategy 1 isn't significantly better than this 9/10 of the time across 8,000 trials, the strategy has no edge.

## Source-text typos / artifacts noted

- Strategy 2's final walk-forward block ends `1130501` (2013-05-01) — likely a Davey typo for `1140308` (which is what Strategy 1 and Strategy 3 use).
- Strategy 4's input list shows `gindate(1070319)` — pdftotext layout dropped the `be` prefix. Original is `begindate(1070319)`.
- All four strategies share the same input list pattern (iter, percentlong, holdbars, exitclose, oddstradetoday, begindate) — Strategies 1 and 3 ignore the random-control inputs; Strategy 2 ignores `holdbars`/`exitclose`; Strategy 4 uses all of them.

## Rule-1 classification of the four variants

This is the definitional question: which of the four are "distinct mechanical strategies" under OWNER Rule 1 (CEO comment [`85b9ec8e`](/QUA/issues/QUA-191#comment-85b9ec8e-8461-4579-8110-2fb2621b0470))?

- **Strategy 1 (Baseline):** A real mechanical strategy with deterministic entry and exit rules. Davey deploys it as a strategy in the book's monkey-test demonstration. Passes V5 hard rules. → **Card (S03 = `davey-baseline-3bar`)**.
- **Strategies 2, 3, 4 (Monkey variants):** Designed-by-Davey-as-test-instruments for evaluating whether Strategy 1 has edge. Davey's own framing (Ch 12 p. 109): *"With any strategy I create, the strategy's performance better be significantly improved over what any monkey could do by just throwing darts. If it is not, then I have no desire to trade such a strategy."* These three are the monkeys. Davey explicitly does not view them as deployable strategies.

**My read:** Strategies 2/3/4 are **not** distinct strategies for V5 portfolio inclusion under Rule 1's intent. They're test-instrument code that V5's P2 Baseline Screening could borrow for its own monkey tests, but they are not candidates for the strategy library. The Rule 1 standard ("extract every distinct mechanical strategy") is about strategies the practitioner views as deployable; Davey's own narrative explicitly excludes the monkey variants from that category.

**Asking CEO** in the QUA-191 comment thread to confirm this reading. If the answer is "Rule 1 strict reading requires cards for the random variants too", I'll draft S04/S05/S06 next heartbeat.
