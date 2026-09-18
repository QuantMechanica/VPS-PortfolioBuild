# FTMO Official Rules Snapshot — 2026-09-18

**Purpose:** binding rule facts for the FTMO 100k 2-Step (Standard) programme, from official FTMO sources, per
`OWNER-DEC-FABLE-FULL-EXECUTIVE-AUTHORITY-20260917` §27. Supersedes nothing by deletion: the bound machine snapshot
remains `docs/ops/evidence/2026-09-15_ftmo_official_rules_snapshot.json` (sha256 `5e25827b…dca8c`, retrieved
2026-09-15T13:59:31Z); this page adds the 2026-09-18 live re-fetch and the payout/fee facts the JSON does not carry.
Rulepack bound in the first-passage engine: `FTMO_2S_100K_STANDARD_V2`.

**Freshness:** live re-fetch 2026-09-18T00:04:44Z via `tools/strategy_farm/ftmo/rules_snapshot.py refresh` —
trading-objectives page, account-specifications FAQ and instruments/strategies FAQ all HTTP 200 (`fetch_status LIVE_OK`);
no field changes detected vs 2026-09-15 → rebind only. Payout/fee FAQ pages fetched read-only 2026-09-18T00:1xZ
(WebFetch, GET-only, no credentials). Re-verify before the purchase packet and before every payout request.

## Binding facts (Standard account, 100k, 2-Step)

| Field | Value | Source (official) | Fetched |
|---|---|---|---|
| Product | FTMO Challenge (2-Step) → Verification → FTMO Account | ftmo.com/en/trading-objectives/ | 2026-09-15, re-fetched 2026-09-18 |
| Account size / type | USD 100,000 / Standard (Normal) | trading-objectives; account-specifications FAQ | 2026-09-15/18 |
| Profit target | Phase 1: 10% (USD 10,000) · Verification: 5% (USD 5,000) | trading-objectives | 2026-09-15/18 |
| Maximum Daily Loss | 5% of initial balance (USD 5,000); reset 00:00 Europe/Prague; basis = midnight balance minus fixed amount; tested on equity incl. open P/L, swaps, commissions; breach when strictly below | trading-objectives | 2026-09-15/18 |
| Maximum Loss | 10% static of initial (floor USD 90,000); equity incl. open P/L; breach strictly below | trading-objectives | 2026-09-15/18 |
| Minimum trading days | 4 per phase; day = CE(S)T calendar day with ≥1 newly opened position | trading-objectives | 2026-09-15/18 |
| Time limit | none (unlimited period for both phases) | trading-objectives | 2026-09-15/18 |
| Leverage | up to 1:100 (FX 1:100, indices 1:50 with HK50/US2000/SPN35 1:30, metals 1:30); cannot be increased | account-specifications FAQ | 2026-09-15/18 |
| Instruments | all platform asset classes (Forex, Indices, Commodities, Stocks, Crypto); no public per-symbol restriction list; specs in MT5 Market Watch | instruments/strategies FAQ | 2026-09-15/18 |
| EAs / algo / scalping | EAs allowed; scalping allowed; third-party EA use may be denied under the maximum-capital-allocation rule; stop loss not mandatory | instruments/strategies FAQ | 2026-09-15/18 |
| Execution limits | max 200 simultaneous orders; hyperactive threshold 2,000 positions per day | instruments/strategies FAQ | 2026-09-15/18 |
| News rule | no Challenge/Verification restriction; funded Standard: no trading ±2 min around targeted high-impact releases | CARRIED_OVER from rulepack (trading-conditions URL 404 on 09-15) | — |
| Overnight / weekend | no restriction during evaluation; funded Standard: manage intra-week, close before weekend | CARRIED_OVER (see above) | — |
| Fee model | one-time fee covering Challenge + Verification; no recurring or hidden fees | FAQ "are the fees recurrent" | 2026-09-18 |
| Fee refund | 2-Step: fee **may be refunded with the first Reward withdrawal**, via the initial payment method. 1-Step: not refunded | FAQ "is the entry fee refunded" | 2026-09-18 |
| Profit split | 2-Step: **80%** to trader (90% when Scaling Plan or Premium Programme conditions are met). 1-Step: 90% | FAQ "how do I withdraw my profits" | 2026-09-18 |
| First payout eligibility | on the **14th or any following day after the first placed trade** on the FTMO Account; all positions and pending orders must be closed first | same FAQ | 2026-09-18 |
| Payout processing | review within 1–2 business days; payment typically 1–2 business days after invoice approval | same FAQ | 2026-09-18 |
| Payout minimums / methods | bank wire (min closed profit USD 20), crypto (min USD 50), Visa Direct / Mastercard Send (≤ USD 20,000), Skrill (≤ USD 3,000); FTMO charges no withdrawal commission, method fees may apply | same FAQ | 2026-09-18 |

## Gaps (must be closed before the purchase packet)

1. **Current fee amount for the USD 100k 2-Step Challenge** — not exposed on the fetched public pages (pricing table is
   client-side rendered at ftmo.com/en/#pricing; a "20% off $100K 1-Step" promotion banner was visible 2026-09-18).
   Close via the FTMO client area / order page at packet time and record the exact amount, currency and promotion.
2. Challenge-phase news/overnight/weekend exemptions remain CARRIED_OVER from the rulepack (official trading-conditions
   URL 404 on 2026-09-15). Not decision-blocking for the Demo (all three are exempt during evaluation) but must be
   re-confirmed from an official page for the funded stage.
3. Per-symbol spread/commission/swap specifications live in the MT5 platform, not scraped; the Demo terminal's
   Market Watch is the source for the compliance sentinel.

## Consequences for QM design (derived, not official)

- Daily-loss accounting must follow the Prague-midnight balance anchor; EA breakers anchored to UTC or broker midnight
  are an approximation and must keep internal headroom (directive §56).
- Funded-stage payout math for `FTMO_NET_CASH_REALIZED`: first reward = 80% of net profit + fee refund; eligibility
  14 days after the first trade on the funded account. The first-passage chain must model this lag.
- Minimum 4 trading days per phase interacts with day-breakers that stop trading early: a stopped day still counts if a
  position was opened.

## Change log

- 2026-09-18 (Fable): created; live re-fetch OK; payout/fee facts added; fee amount recorded as GAP.
