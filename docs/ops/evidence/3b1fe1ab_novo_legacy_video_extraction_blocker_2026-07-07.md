# Novo Legacy Video Extraction: Timestamp Blocker

Task: `3b1fe1ab-fc8c-4362-94d1-466ae3ebb97f`
Source: `https://www.youtube.com/watch?v=fNFTpKmSQB8`
Title: `the trading industry is broken... so I'm leaking my $8.5k course`
Date: 2026-07-07
Research skill used: `qm-strategy-card-extraction` because this is an OWNER-supplied approved video source.
Router-requested skill unavailable in this session: `video_analysis`.

## Verdict

BLOCKED for acceptance. Do not create V5 cards or build work from this pass.

The task requires timestamped citations for every extracted rule. I could not obtain a timestamped transcript from the scheduled-task environment. The accessible materials are enough to identify likely strategy topics, but not enough to produce source-faithful, independently buildable rule sections with timestamped citations.

## Source Acquisition Attempts

- `python -m yt_dlp --skip-download --dump-json "https://www.youtube.com/watch?v=fNFTpKmSQB8"` failed with YouTube bot/sign-in verification.
- `python -m yt_dlp --cookies-from-browser chrome ...` and `--cookies-from-browser edge ...` failed because the headless scheduled-task profile has no browser cookie databases.
- `youtube_transcript_api` initially listed an English auto-generated transcript, but `fetch()` failed with `RequestBlocked` from YouTube.
- YouTubeSummary transcript extractor returned one full plain-text transcript response via Svelte form POST, but it does not include timestamps. Follow-up attempts hit the tool's free usage limit.
- YouTubeSummary summary page was accessible and described the two strategy playbooks, but it is a generated summary, not the primary timestamped transcript.
- OK.ru mirror page `https://ok.ru/video/16074342664926?nomr=` was accessible and confirms a 4:02:08 mirror with a few human-entered timestamp tags such as `34:13 first parabola`, `1:03:58 Acc. Manip. Distrib.`, and `1:21:45 timing`, but those sparse tags do not cite every rule.

## Partial Non-Buildable Extraction

The accessible summary and plain-text transcript indicate two distinct playbooks:

1. Candle Impulse Theory, a continuation model.
2. Candle Range Theory, a reversal/range model.

Both appear to use a single 4-hour context candle, lower-timeframe triggers, and discretionary price-action terms. The current evidence is not sufficient to mechanize them safely.

## Candidate System A: Candle Impulse Theory

Status: NOT BUILDABLE from this pass.

Observed candidate mechanics:

- Context candle: one selected 4-hour candle per session.
- Markets mentioned: forex, futures, stocks, crypto, Nasdaq, ES/S&P, gold, BTC/ETH, Apple examples.
- Session mapping described:
  - Oanda-style Eastern chart candles: 01:00, 05:00, 09:00, 13:00, 17:00, 21:00.
  - CME futures/forex mapping: 02:00, 06:00, 10:00, 14:00, 18:00, 22:00.
  - Crypto mapping: 03:00, 07:00, 11:00 buckets.
- Directional idea: use the 4-hour candle's body/gradient and prior candle relationship to classify continuation.
- Entry idea: enter on a wick retracement around the previous candle close or previous candle level.
- "Novo box" levels mentioned: 0%, 25%, 50%, 75%, 100%.
- Zone idea:
  - high to 25%: premature zone.
  - 25% to 50%: optimum zone.
  - around 75%+: danger/overextended zone.
- Target concepts mentioned: 50%, opposing liquidity, and extensions including 1.272, 1.7, 2.145.

Mechanical gaps:

- No timestamped citation per rule.
- Directionality of the PCC retrace is ambiguous in the accessible transcript summary.
- The exact 4-hour candle selection is personal/example-driven and needs source timestamps for each market mapping.
- No exact lower-timeframe trigger definition.
- No exact stop-loss formula or position sizing rule.
- No objective definition for "gradient", "wick retrace", "rebalance", or "danger zone" beyond rough box levels.

## Candidate System B: Candle Range Theory

Status: NOT BUILDABLE from this pass.

Observed candidate mechanics:

- Context candle: one selected 4-hour candle defines range high and range low.
- Environment: range/reversal or choppy conditions.
- Setup idea: wait for a sweep of the 4-hour high or 4-hour low.
- Follow-up idea: wait for "change in state of delivery" and a breaker/block reaction.
- Target idea: trade from internal liquidity sweep toward external/opposite range liquidity.

Mechanical gaps:

- No timestamped citation per rule.
- "More wick than body" is mentioned, but no numeric wick/body threshold is available.
- No objective definition for "change in state of delivery".
- No objective breaker-block definition.
- No exact entry price, stop placement, invalidation, or target hierarchy.
- No position sizing rule.

## Discretionary Discard List

Discard until primary timestamped source evidence gives exact definitions:

- "Engineered move the market must make every session" because it is a thesis/marketing claim, not a rule.
- "Positive gradient" and "negative gradient" because no formula is available.
- "Choppy market" because no volatility or range threshold is available.
- "Change in state of delivery" because the accessible source text does not define a computable event.
- "Breaker block" because block boundaries and confirmation are not objectively specified.
- "Rebalance" and "second entry" because trigger, price level, and invalidation are underspecified.
- "Turtle soup" label because the accessible evidence does not define exact sweep depth, close condition, or target logic.

## Unverified Claims

The accessible summary/plain transcript includes claims that must remain unverified:

- More than `$500/day`.
- Approximately `84%` win rate.
- Multiple prop accounts passed.
- Six years and about `87,000` candlesticks studied.
- Around `1,200+` or `1,400` trades studied, depending on phrasing.
- Entries/exits often in 10 to 20 minutes, sometimes about 2 minutes.

## Verification Commands

Commands run from `C:/QM/worktrees/codex-orchestration-1`:

```text
python -m yt_dlp --skip-download --dump-json "https://www.youtube.com/watch?v=fNFTpKmSQB8"
python -m yt_dlp --cookies-from-browser chrome --skip-download --dump-json "https://www.youtube.com/watch?v=fNFTpKmSQB8"
python -m yt_dlp --cookies-from-browser edge --skip-download --dump-json "https://www.youtube.com/watch?v=fNFTpKmSQB8"
python -m yt_dlp --extractor-args "youtube:player_client=android" --skip-download --dump-json "https://www.youtube.com/watch?v=fNFTpKmSQB8"
python -m yt_dlp --extractor-args "youtube:player_client=web_embedded" --skip-download --dump-json "https://www.youtube.com/watch?v=fNFTpKmSQB8"
python -m yt_dlp --extractor-args "youtube:player_client=tv" --skip-download --dump-json "https://www.youtube.com/watch?v=fNFTpKmSQB8"
python <youtube_transcript_api list/fetch probes>
python <YouTubeSummary Svelte action POST probe>
```

Result: no primary timestamped transcript was retrievable. The task should be re-run only with one of:

- a saved `.vtt` or `.srt` transcript with timestamps;
- a manually exported YouTube transcript with timestamps;
- owner-approved permission to use approximate timestamps from the video itself after manual viewing.

