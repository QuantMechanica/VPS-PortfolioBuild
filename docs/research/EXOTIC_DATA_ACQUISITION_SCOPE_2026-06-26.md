# Exotic / EM Symbol-Data Acquisition — Scope & Decision (2026-06-26)

Author: Claude. Trigger: OWNER — "Exoten testen wir gar nicht?" Correct — we test **zero**
exotics. This scopes whether to acquire the data, weighed against the cost gate.

## 1. What we have vs. what's missing

The tested universe is the **57 symbols in `framework/registry/live_commission.json`**: FX majors
+ G10 crosses, metals/energy (XAU/XAG/XTI/XBR/XNG/XCU), and the index set (NDX/SP500/WS30/GDAXI/
UK100). **No emerging-market or exotic FX, no crypto.** Confirmed: 0 work_items ever referenced
TRY/ZAR/MXN/SEK/NOK/PLN/HUF/SGD/HKD/CNH. Non-major crosses *are* tested but thinly (~100 Q02 runs
each vs EURUSD's 1,505) and die by Q03/Q04.

## 2. Why it matters — and the cost caveat that bounds it

**Diversification (the upside).** The book is structurally concentrated in US index / metal / energy
(see `PORTFOLIO_PATH_TO_PROFITABLE_2026-06-26.md`). Exotics are driven by *different* forces — EM
carry, commodity-currency cycles (NOK/oil, ZAR/gold, MXN), rate-differential regimes — so they are
genuinely uncorrelated to the current sleeves. Breadth is our one lever to ≥20 %/yr, and exotics are
unexplored breadth.

**The cost wall (the bound).** Our commission audit (this session) showed the Q04 cost gate already
kills FX majors with thin/high-frequency edges. Exotics have **wider spreads + higher commission**
than majors, so they hit that wall *harder*. Conclusion: **exotics will only survive as low-frequency,
structural edges** (carry, multi-week mean-reversion, cointegration) — never high-freq. The funnel
already proves this is the right shape (low-freq cointegration FX is our live breadth play). So the
acquisition only pays off **if paired with low-freq exotic strategies**, not a generic re-sweep.

## 3. Acquisition cost (the work)

1. **Source** exotic `.DWX`-format M1 history (2017–2025) for the target set. The DWX/Darwinex feed
   may not carry all EM pairs — likely needs a data vendor or broker-specific export. *This is the
   real unknown; spike it first.*
2. **Import** as MT5 custom symbols (same path as existing `.DWX` symbols) on the factory terminals.
3. **Calibrate cost**: add each symbol to `live_commission.json` with its *real* per-class rate —
   exotic FX commission/spread is materially higher than majors; do NOT default them to the $5/lot
   forex rate or we'll over-admit. Document the source (no invented values — Hard Rule).
4. **Validate** broker-symbol vs custom-symbol timestamps over DST windows (per the T1–T10
   ownership protocol) before any bulk enqueue.

## 4. Priority order (most liquid + most diversifying first)

1. **USDSEK, USDNOK** — G10-adjacent, liquid, NOK↔oil link (diversifies vs our energy sleeve).
2. **USDZAR, USDMXN** — EM carry + commodity-currency; high diversification, higher cost.
3. **USDTRY, USDPLN, USDHUF** — deep EM; strong carry edge but widest cost → low-freq only.
4. **Crypto (BTCUSD/ETHUSD)** — only if `.DWX`-routable and live-tradable on DXZ; different driver
   entirely. Separate cost model (24/7, funding instead of swap).

## 5. Decision for OWNER

**Recommendation: YES, but gated and sequenced —** do a **data-availability spike** on USDSEK/USDNOK/
USDZAR/USDMXN first (cheap; answers "can we even get clean `.DWX` history"). If the data is obtainable,
acquire those 4, calibrate their real commission, and pair them with **low-frequency** cards (carry /
mean-reversion / cointegration) — not a generic high-freq sweep that the cost gate would kill anyway.
Defer deep EM (TRY/HUF) and crypto to a second wave.

This is a real effort (data sourcing is the long pole) and a genuine breadth bet. The alternative —
keep mining low-freq edges on the existing 8 liquid instruments — is lower-cost but lower-ceiling on
diversification. Both are valid; exotics raise the diversification ceiling if the data is gettable.

Evidence: `framework/registry/live_commission.json` (universe), this session's commission audit
(cost wall), `docs/research/PORTFOLIO_PATH_TO_PROFITABLE_2026-06-26.md` (concentration + breadth lever).
