# René Balke — Range/Time-Range Breakout: Symbol & Time-Window Survey
Date: 2026-07-15 · Read-only research (Web + YouTube transcript proxy) · No repo/terminal mutation
Author: Claude (board-advisor worktree) · Brief: `D:\QM\reports\research\balke_symbols_prompt.txt`

**Bottom line up front:** Balke's *published* Range-Breakout universe beyond USDJPY/XAU is the
classic **"morning / London-session breakout" majors** — GBPUSD, EURUSD, EURJPY — plus index
DE40 (DAX). He **does NOT publish** windows for the CAD/AUD/NZD crosses the brief hypothesized
(GBPJPY, AUDUSD, USDCAD as a traded pair, CADJPY, NZDCAD, AUDCAD). USDCAD/USDCHF appear only as
an *example universe* on the mql5 page, never with a window. His per-symbol rule is explicit and
simple: **keep every setting constant, change ONLY the time window**, and choose that window by
(a) the instrument's low-spread hours and (b) capturing the early directional move of its active
session.

---

## Symbol × Window table (one citation per row; unverified = GAP)

| Symbol | Range window + zone | Exit / close | SL / risk / mgmt | Balke verdict | Source (URL) |
|---|---|---|---|---|---|
| **USDJPY** | Range **00:00–07:30** (450 min), broker server time | Delete orders + close positions **18:00** | SL factor 1 (opposite side of range); no TP; 0.5% risk; max 2 trades/day; no trailing/BE (FTMO acct) | "Even **way better** than GBPUSD" in 2013–2024 tick-data backtest; his live FTMO 100K pair | `youtube.com/watch?v=Pay-JP34YSI` (transcript L186–207) |
| **USDJPY (variant)** | **03:00–06:00 GMT+3** | 18:xx | same family | Works, OOS PF ~1.20 (our prior finding) | brief known-facts (prior QM evidence, not re-verified here) |
| **GBPUSD** | Range **04:00–12:00**, broker server time | Delete + close **18:00** | SL factor 1; no TP; 0.5% risk; max 1 buy + 1 sell/day; no trailing/BE in FTMO acct (other accts use BE) | Profitable since 2013; "last few months a little sideways" | `youtube.com/watch?v=Pay-JP34YSI` (transcript L48–171) |
| **EURJPY** | Range **01:00–10:00** (alt **04:00–10:00**, called "more" robust), broker server time | Close position **18:00** ("no matter where price is") | SL opposite side of range; first breakout only; no trailing; no filters; €500/trade on live acct | Live-traded by him; 5,500 trades / 20+ yr profitable BUT "**mainly sideways periods**"; strong 2010–2017, 2003–2005, 2020–2023; "**since I started we are stuck in a sideways period**" | `youtube.com/watch?v=xstcEMDUZeg` (transcript L55–102, L145–159) |
| **DE40 (DAX)** | Range **08:01–11:30** (~3h30 / tested 210 min); alt **10:00–12:30** and **10:30–13:00**; start offset +1 min off round hour; range must **end after 09:00** | Close **~20:55** (evening); found close-time "does not make too much difference" | SL factor 1 (opposite side); fixed-money sizing; max **1** trade/day; range filter ON; no TP | His index Range-Breakout demo; optimizes range length as single param | `youtube.com/watch?v=qCdqheZrK7M` (transcript L85–164, L272–358) |
| **XAUUSD (Gold)** | **03:05–06:05**; close **18:55** | 18:55 | live-gold config | Balke's live gold, **marginal** (our prior finding) | brief known-facts (prior QM evidence, not re-verified here) |
| **EURUSD** | "**adjust the times a bit** for EURUSD" vs USDJPY default — no exact numbers given | — | same family | Mentioned as tradable; **exact window = GAP** | `mql5.com/en/market/product/87520` (desc/comments) |
| **USDCAD, USDCHF** | Listed only as *example universe*; **no window published** | — | — | User/desc mentions testing; **no Balke window = GAP** | `mql5.com/en/market/product/87520` (desc + user review) |
| **US30 / USTEC / NAS100 / S&P500** | Indices — Balke runs these mainly under **"Turnaround Tuesday"**, a *different* concept, NOT the morning Range Breakout | — | — | In his live 3-strategy / 6-asset book, but not as morning-range | `docs.profectus.ai/en/articles/12453702` (portfolio replicating Balke) |
| **GBPJPY, CADJPY, NZDCAD, AUDCAD, AUDUSD, NZDUSD** | **NONE FOUND** | — | — | **No Balke-published window in any video/setfile/page located** → OFFEN/GAP | (negative result across all searches; see GAPs) |

*Timezone note:* Balke states times in **his broker's server time** and targets brokers on the
standard US/NY-close server (GMT+2 winter / GMT+3 US-DST — same convention as our DXZ book). He
does **not** state the GMT offset explicitly in these clips; mapping to GMT+2/+3 is inferred, not
quoted → minor GAP. All windows above must be re-anchored to our broker's server offset before use.

---

## Adaptation principle — HOW he picks the window per symbol

This is the core answer to "was und wie tradet er diese Symbole." It is a **rule, not a lookup
table**, and Balke states it explicitly:

1. **Only the time window changes per symbol; everything else is held constant.** Moving from
   GBPUSD to USDJPY he says: *"pretty much everything's the same … just the time here changes so we
   trade from 0 to 730 and that's the only difference."* Same SL (opposite side of range), same
   no-TP, same 0.5% risk, same time-based close. → `Pay-JP34YSI` L188–204.

2. **Enter as EARLY as possible to catch the biggest portion of the day's directional move**
   (the strategy assumes the market finds direction in the morning and trends the rest of the day).
   *"trades that can run for a very very long time throughout the day … this is why I want to enter
   early so I can catch the biggest portion of this actual move."* → `qCdqheZrK7M` L295–300.

3. **…but not so early that spread/cost kills it.** The window is **cost-anchored**: for his
   broker/DAX the spread before 09:00 is ~**8× higher**, so he forces the range to **end after
   09:00**. *"if I would open positions before 9:00 a.m. I would pay a spread which is I think eight
   times higher … I set up the test so that the range never ends before 9."* → `qCdqheZrK7M` L301–315.
   → Per symbol, the window's *earliest acceptable end* = start of that instrument's liquid /
   low-spread session.

4. **Offset the start ~1 minute off round hours** (08:01 not 08:00) to dodge round-number
   news/liquidity spikes and reduce slippage vs the (optimistic) tester. → `qCdqheZrK7M` L90–116.

5. **Range LENGTH is a single optimized parameter** (minutes), tuned on that symbol's own history;
   **close time is a near-free parameter** ("does not make too much difference"), defaulted to an
   evening time. → `qCdqheZrK7M` L323–358.

6. **Conceptual origin:** the classic *"morning breakout / London-session breakout — there are
   multiple names for this, these strategies are super old and I did not invent this."*
   → `mOa4dqxAh4g` L21–28. The EA lets you "change all of these values so it fits your symbol." → L259–263.

**Net:** the per-symbol window ≈ *that instrument's morning session build-up, ending just after its
own liquid/low-spread hour opens.* That is why the windows track sessions, not the calendar:
JPY pairs anchor Asia→Europe (USDJPY 00:00–07:30, EURJPY 01:00–10:00); GBPUSD anchors the London
morning (04:00–12:00); DAX anchors the pre/early-cash session (08:01–11:30); Gold anchors pre-London
(03:05–06:05). There is **no evidence** he adds exotic crosses — he stays on high-liquidity majors +
gold + main indices precisely because his edge is cost-sensitive.

---

## Negative / rejected findings

- **No CAD/AUD/NZD crosses published.** Exhaustive searches (`site:youtube`, mql5, bmtrading.de,
  set-file mirrors) returned **zero** Balke-authored windows for GBPJPY, AUDUSD, USDCAD-as-traded,
  CADJPY, NZDCAD, AUDCAD. The brief's hypothesis list is not reflected in his published material.
- Balke **refuses fixed recommendations**: *"I never recommend settings. You can copy my settings
  from my YouTube videos but I recommend you do your own tests. Different symbols need different
  inputs."* → `mql5.com/en/market/product/87520`. So all numbers above are *his examples*, not
  endorsements — treat as starting points to re-optimize.
- **Indices ≠ pure Range Breakout in his live book.** US30/NAS100/S&P500/DAX are run mostly under
  "Turnaround Tuesday" in his live portfolio; only the DE40 optimization video applies the morning
  Range Breakout to an index. → `docs.profectus.ai/en/articles/12453702`.

---

## Priority recommendation — which 2–3 to mechanize first

1. **EURJPY 01:00–10:00 (or 04:00–10:00) close 18:00 — HIGH.** Freshest source (Mar 2026), he
   trades it *live*, 20+ yr / 5,500-trade backtest, and it is the **direct family analog to our
   USDJPY winner** (JPY cross, same session logic) → cheapest orthogonality gain. Carry the caveat:
   "mostly sideways, currently in a weak regime" — expect a low but positive-expectancy structure.
2. **GBPUSD 04:00–12:00 close 18:00 — MED-HIGH.** Verified 2013+ tick-data backtest, London-morning
   window orthogonal to the JPY pairs, identical settings block. Watch the "recent months sideways"
   note; validate on full history + our cost model (FX commission ~$45/trade is the real killer).
3. **DE40 08:01–11:30 close ~20:55 — MED.** Index → higher Q04 survival in our data (Index 6.9% net
   vs FX 1.6%), diversifies asset class, and the DE40 video gives an unusually complete recipe
   (offset, spread rule, range-length optimization). Note it is index-cost-sensitive, not FX.

All three should be re-anchored to our broker server offset and re-optimized on full history with
our commission/swap model before any gate run — Balke explicitly disclaims his numbers.

---

## Sources
- `https://www.youtube.com/watch?v=Pay-JP34YSI` — "My Settings for the Range Breakout EA in USDJPY and GBPUSD" (Apr 2024) — GBPUSD 04:00–12:00, USDJPY 00:00–07:30, close 18:00. Transcript: `D:\QM\reports\research\balke_symbol_transcripts\transcript_Pay-JP34YSI.txt`
- `https://www.youtube.com/watch?v=xstcEMDUZeg` — "EURJPY Range Breakout Strategy: 23 Year Backtest & Live Results" (Mar 2026) — EURJPY 01:00–10:00 (alt 04:00–10:00), close 18:00. Transcript: `...\transcript_xstcEMDUZeg.txt`
- `https://www.youtube.com/watch?v=qCdqheZrK7M` — "Range Breakout Strategy Testing and Optimization Process for DE40" (Oct 2024) — DE40 08:01–11:30, close ~20:55, spread/offset rules. Transcript: `...\transcript_qCdqheZrK7M.txt`
- `https://www.youtube.com/watch?v=mOa4dqxAh4g` — "Explaining all the Settings of my Range Breakout EA (New/Latest Version)" (Feb 2025) — mechanics, defaults, "fits your symbol", London-session origin. Transcript: `...\transcript_mOa4dqxAh4g.txt`
- `https://www.mql5.com/en/market/product/87520` — Range Breakout EA product page — example universe (USDJPY/EURUSD/XAUUSD/USDCAD/USDCHF), "different symbols need different inputs", "I never recommend settings".
- `https://bmtrading.de/en/expert-advisors/range-breakout/` — "Forex, indices; M5–H1; different symbols need different inputs; defaults not optimal."
- `https://docs.profectus.ai/en/articles/12453702-the-trading-portfolio-inspired-by-rene-balke` — live book: Range Breakout on USDJPY + Gold; Turnaround Tuesday on DAX/S&P500/US30/NAS100.
- Balke's own live-EA symbol list (mql5 desc / bmtrading): US30, USDJPY, USTEC, GBPUSD, XAUUSD, EURJPY, DE40.

## GAPs (unresolved — do not guess)
- **EURUSD exact window** — only "adjust the times a bit" stated; no numbers.
- **USDCAD / USDCHF windows** — in example universe only; no Balke-published times.
- **GBPJPY, CADJPY, NZDCAD, AUDCAD, AUDUSD, NZDUSD** — no Balke material found at all.
- **Exact GMT offset** for the quoted times — never stated on-air; inferred GMT+2/+3.
- **XAUUSD / USDJPY-03:00 windows** — carried from prior QM evidence, not re-verified in this pass (per brief instruction).
- `strategyquant.com` Balke interview and `myfxbook` 50K account both returned **HTTP 403** — could not verify live per-symbol allocation there.
