# Edge Lab card rework — task `4927dcbb-de7a-4ff0-bb84-2998aecc1421`

## Outcome

All 17 requested Strategy Cards were reworked in place under
`D:/QM/strategy_farm/artifacts/cards_review/`; none was dropped. The fallback
RSI(2) mechanic was removed from `QM5_1063_v2` and isolated in one additional
review-only child draft, `PENDING_4927DCBB_unger-rsi2-extreme-fallback-v1.md`.
No card was copied to `cards_approved`, no EA was built, and no pipeline or
terminal action ran.

Every resulting draft carries the six required Edge Lab sections: Structural
cause, Price signature, Persistence, Falsification, Q08/Q11 risk, and FTMO fit.
Every target symbol is present in `framework/registry/dwx_symbol_matrix.csv`,
every modeled drawdown is at most 9%, and every FTMO block fixes
`RISK_FIXED > 0` with `RISK_PERCENT = 0`.

## Named rework

| Card | Result |
|---|---|
| `QM5_1063_v2` | Parent is now a pure Bollinger/ADX fade; the RSI(2) fallback is a separate review draft. |
| `QM5_11937` | DD reduced to 8%; risk set to 0.1%; overlap fingerprint added against `QM5_10004`. |
| `QM5_11943` | DD reduced to 8.5%; structural, persistence, falsification, and crisis-risk tests made explicit. |
| `QM5_11944` | DD reduced to 8%; three-candle structural cause and falsification control added. |
| `QM5_11945` | DD reduced to 8%; persistence/falsification and approved-sibling fingerprint added. |
| `QM5_11948` | DD reduced to 8%; pivot persistence and falsification controls added. |
| `QM5_11950` | Replaced the unconditional 100-pip stop with `min(100 pips, 1.25*ATR(D1))`; added 25% scale-outs at 1R/1.5R/2R plus runner; DD reduced to 8%. |
| `QM5_11962` | Added EURUSD/GBPUSD/USDJPY targets, M5 horizon, 8.5% DD, charter sections, and an EMA-family fingerprint. |
| `QM5_11972` | Added a geometry-based structural cause, persistence, falsification, H1 horizon, three registered targets, and 8.5% DD. |
| `QM5_11992` | Fixed `k=1`, M15 and a deterministic 0.5-ATR stop; added three targets, 8.5% DD, crisis tests, and ORB differentiation. |
| `QM5_11997` | Fixed the adaptive lookback to N=20/40/60 from a declared volatility percentile; added D1, targets, 8.5% DD, persistence/falsification, and crisis tests. |
| `QM5_12003` | Targets are only registered `USDCAD.DWX`/`XTIUSD.DWX`; DXY is not an active input; oil-release bars are consumed by the mandatory news blackout; DD is 8%. |
| `QM5_12018` | Added order-slicing structural cause, an EMA-control falsification test, targets, H1, and 8.5% DD. |
| `QM5_12037` | Replaced visual clock-face discretion with `(Green[1]-Green[4])/3` and thresholds `>= +2.0` / `<= -2.0` RSI points per completed H1 bar. |
| `QM5_12055` | Added four registered targets, numeric RSI divergence, deterministic target/stop, structural cause, and falsification. |
| `QM5_12064` | Removed M1 from the design; defined an M5 opening-gap reversal with deterministic stop/time exit, four registered targets, structural cause, and falsification. |
| `QM5_20024` | Added the Evans paper DOI and FCA citation plus an explicit fingerprint against `QM5_20034` covering window, entry, target, universe, and news handling. |

The Evans bibliographic fields and DOI were checked against the
[publisher record](https://www.sciencedirect.com/science/article/abs/pii/S0378426617302327).

## Bound card hashes

The first hash is the pre-rework card; the second is the reviewed result. The
child draft is new and therefore has no predecessor hash.

| Card file | SHA-256 before | SHA-256 after |
|---|---|---|
| `QM5_1063_unger-bollinger-fx-meanrev-v2.md` | `357f827c214422d0b76d2e1f973407dd779b8d98f3c88636d121f5a81d6cd73c` | `4e287ae8adc9fdadef0f69ad02e44befaea1c58e21c62ff58633f0d13da8a05a` |
| `QM5_11937_ff-agnew-h1-break.md` | `8b02b1142193facdf53905d378e154a8836934a0d560452b6c3b51211463bb55` | `74fa9ee0fadff16cd46cd2ab022d7ff6bae3ef15ff858ff1e0042df1372d7fe6` |
| `QM5_11943_ff-wae-explosion.md` | `f4592af63366dc0c998897590b332a7884d7ab205242db08c6617d3bdfcc578c` | `679f9e2fb6582ece1e36f338387bb485c6af8f1ca352994da367cb27628e7577` |
| `QM5_11944_ff-d1-simplicity.md` | `09e2c6cd96dec2f7470637ec402b134b3d231282f9879f514f2932cc425baee1` | `23880aa447b29f8d2459805e5284b275d0d81a184289c25c97335078346553c7` |
| `QM5_11945_ff-the-strat-212.md` | `adecb938e36f8b5e30657976360c735bf53c981df66cf7b13d07c1565da5ad19` | `d63aabccf2588c4a95f5729bbd0011cb026eb8265f64ff946ae45c7604071943` |
| `QM5_11948_ff-davit-pivots.md` | `c28138e4e724063986175ccab6a60570d8446ba449db51c3aa79342174c02898` | `0bbfd72f89d4107edab98573663a613d298e8cb2aefb7a9ebaa68ffcd282cfb1` |
| `QM5_11950_ff-ozfx-mechanical.md` | `20f64ee91f7a579c1e581777a70a5f18f163a0154b370d308396e83ecbcabfb0` | `226e7ab4414ae48817eaf714dd0bb67173506a7a1c071876dd24c8cddb2e9400` |
| `QM5_11962_ff-3ema-trend-cont.md` | `434d16aed2fb3bf9d8fa5a304a32d35268191b8a8b83d7e0d8e591ffc2dff4f2` | `99b87c3e5c014acc4a0c9b227298f6feab1e39645c8bd2f0c5df3890a56ebb8a` |
| `QM5_11972_mql5-wolfe-waves.md` | `7492966b0ab4fc5f7cb1df418f53404b26d23a048a63536432821df4e314dd7d` | `c3a2bd09602d66a21d3b1779e45a498f64f86fbdf1fa6958c6a8c7259fe6a78b` |
| `QM5_11992_cup-vol-breakout-atr.md` | `c8ff278680f9397add7646c1804c5ccb489d9cb40960b6c490b15fb79bcbd2d8` | `c8b29d074588893a04f217a5a804ed13cf241f3452474ad9ad5ce3cb9f41b5bb` |
| `QM5_11997_qc-dynamic-breakout-ii.md` | `43fdb42357ec8f7788023bf73c6bb53bf5f256c78f3e4414d63f09e1d0c64de1` | `9a499d199cbe191eae777a4f47e92b6747147b7d9875f804a27a3328786eb642` |
| `QM5_12003_ano-commodity-lead-lag.md` | `7e67825dd6feadcd1cded199dcb1f040ecc496a6cfe9cd21bba6f21ae4f6170a` | `4c3d411a46a92fbbf9e7bb4d6724d66c429144a1ed704eede7137c82a2f5bb8e` |
| `QM5_12018_ru-kravchuk-digital-filters.md` | `d8eab8d37667702e26bd3f7397a98d0687158c7e7fab15d21fe5ff8092c05a35` | `50721594b10b64a1711bda7757299c2b54f399ec9a7f14f1f5cc673c06303969` |
| `QM5_12037_ru-tdi-angle-attack.md` | `e8c6a4be7360ca77306af1c0b5a69ff94797e7db9f73120325f7f2d95711d34c` | `66333e2b6077cc8eca716f1324c201366ac4c5bb1d40fbf0da1a2da8dc8f91f0` |
| `QM5_12055_yt-secret-monday-sweep.md` | `0dca476dbe5dcd4bee737412c45f1e542aba59eff4f9250df0a1a31f1c25cc0d` | `40c2f594cc1a8da184fea311bc5625a31d2801941b7c797df5c85dc7c33cbd2c` |
| `QM5_12064_yt-inst-gap-fill.md` | `95980b0b353722a14ffb259132449d71a6b9d9c6cc9f20635a45f70ff2a032f7` | `a0771f80d398ccf777a4a68798283ea48483b97d02e01b9530f65a2de0ea62e6` |
| `QM5_20024_london-fix-reversion.md` | `729bb4f7bd8fa0bd07c1332aa9858d6ff7b683f2f153018db1f9095cee2df13d` | `b05a129c6d732b2f83fc52ee648e15bebc1f6b91ef8d3905decabcd1443428de` |
| `PENDING_4927DCBB_unger-rsi2-extreme-fallback-v1.md` | new | `83371fb530966997256ba738656b1c5ab1795674ba19cfa0c83bc9e3d164f08b` |

## Verification

Read-only prescreen:

```powershell
python tools/strategy_farm/card_intake_prescreen.py --card <each-of-the-18-review-files> --report docs/ops/evidence/4927dcbb_edge_lab_rework_prescreen_2026-09-15.json
```

- `18` cards inspected, `18` KEEP, `0` REJECT, `0` mutated.
- All required sections present, all target symbols registry-valid, all DD
  limits valid, all timeframes within the charter horizon, and no prohibited
  mechanics detected.
- The eight near-duplicate warnings are retained for G0 review; each warned
  draft includes explicit differentiation, so the prescreen did not silently
  approve or reject it.
- Focused assertions passed for the RSI split, DXY removal, numeric TDI slope,
  M5-not-M1 gap design, source citation, and `QM5_20034` fingerprint.
- Prescreen report SHA-256:
  `44edf4042849e15ab4bb94c479b20f81bafc1b2164bc345d0acfca2bd9ec2c88`.
- Prescreen tool SHA-256:
  `7ad170f6b3615f2a8bb0cd459017b0549888a369452bb9fd1d8038a2725eccb3`.
- Tool regression tests: `36 passed in 1.30s`.

RESULT task=4927dcbb-de7a-4ff0-bb84-2998aecc1421 verdict=PASS requested_cards_resubmitted=17 split_child_drafts=1 cards_dropped=0 prescreen_keep=18 prescreen_reject=0 cards_approved_writes=0 builds=0
