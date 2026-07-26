# FTMO margin leverage registry proposal — task 9b7c6aaf

Date: 2026-07-27 (Europe/Berlin)

## Verdict

REVIEW — official FTMO evidence supports the leverage and stop-out facts below.
Maximum lots/position size is not publicly enumerated per symbol and must remain
null until exported from an FTMO platform symbol specification.

## Official findings

| Account type | FX majors | Metals (XAUUSD) | Indices |
|---|---:|---:|---:|
| Standard | 1:100 | 1:30 | 1:50 |
| Swing | 1:30 | 1:9 | 1:15 |

FTMO's official account-specification FAQ says Standard leverage is **up to
1:100**, Swing leverage is **up to 1:30**, and the instrument specification must
be viewed in the trading platform. The official FTMO Symbols page independently
publishes 1:100 Standard / 1:30 Swing for FX symbols. FTMO's official Swing
account announcement supplies the asset-class breakdown: Standard (called
"Normal" on that page) is FX 1:100, indices 1:50, metals 1:30; Swing is FX 1:30,
indices 1:15, metals 1:9.

FTMO also states that trading conditions are the same on Free Trial,
Challenge/Verification, and FTMO Account. No official source found a leverage
change by evaluation stage or account size. Therefore stage/account-size
overrides should be empty, not inferred.

The official 22-Aug-2024 trading update changed the automatic stop-out level from
30% to **50%**, effective 24/25-Aug-2024. This is the current official numeric
publication found.

FTMO's public Symbols page exposes contract size, margin percent, leverage, and
Swing leverage, but does not publish a complete maximum-lots field in its public
page body. FTMO's official account FAQ directs users to the trading platform
instrument specification, and its official FX Blue article says the Market List
shows minimum and maximum position size. Consequently, per-symbol maximum lots
is platform-gated and is recorded as null below.

## Official sources

- `FTMO_ACCOUNT_SPECS`: https://ftmo.com/en/faq/what-are-the-account-specifications/
- `FTMO_SYMBOLS`: https://ftmo.com/en/symbols/
- `FTMO_SWING_CONDITIONS`: https://ftmo.com/en/blog/a-few-answers-to-your-questions/
- `FTMO_STOP_OUT_2024_08_22`:
  https://ftmo.com/en/blog/trading-updates/trading-update-22-aug-2024/
- `FTMO_FX_BLUE_MARKET_LIST`:
  https://ftmo.com/en/blog/fx-blue-app-suite-take-your-mt-trading-to-the-next-level/

All sources above are first-party FTMO pages. No secondary figure is used.

## Exact proposed `venue_cost_model.json` addition

Add the five source objects above to `sources`, then add this top-level sibling
after `reference_prices_indicative_2026_07`:

```json
"ftmo_margin_model": {
  "as_of": "2026-07-27",
  "authority": "official_ftmo",
  "account_types": {
    "standard": {
      "forex_major": {"leverage": 100, "margin_percent": 1.0},
      "metal": {"leverage": 30, "margin_percent": 3.3333333333},
      "index": {"leverage": 50, "margin_percent": 2.0}
    },
    "swing": {
      "forex_major": {"leverage": 30, "margin_percent": 3.3333333333},
      "metal": {"leverage": 9, "margin_percent": 11.1111111111},
      "index": {"leverage": 15, "margin_percent": 6.6666666667}
    }
  },
  "stage_overrides": {},
  "account_size_overrides": {},
  "platform_overrides": {},
  "stop_out_level_percent": 50.0,
  "margin_call_level_percent": null,
  "max_position_lots_by_symbol": {},
  "max_position_lots_status": "PLATFORM_GATED_NOT_PUBLICLY_ENUMERATED",
  "sources": [
    "FTMO_ACCOUNT_SPECS",
    "FTMO_SYMBOLS",
    "FTMO_SWING_CONDITIONS",
    "FTMO_STOP_OUT_2024_08_22",
    "FTMO_FX_BLUE_MARKET_LIST"
  ],
  "notes": "Leverage is up to the stated ratio and instrument-specific platform specifications remain authoritative. Empty override objects mean no official difference was found, not that future overrides are impossible."
}
```

`margin_call_level_percent` deliberately remains null: the official educational
pages explain the concept using examples but do not publish a current FTMO
account-wide numeric margin-call level. Likewise, maximum lots remains empty
until a reproducible platform export is captured.

