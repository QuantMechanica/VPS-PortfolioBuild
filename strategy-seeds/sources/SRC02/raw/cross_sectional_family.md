---
source_id: SRC02
source_pdf: "G:\\My Drive\\QuantMechanica\\Ebook\\PDF resources\\Quantitative Trading_ How to Bu - Ernest P. Chan.pdf"
extracted_section: "Cross-sectional family — Example 3.7 (Khandani-Lo simple MR) + Example 3.8 (open-bar refinement variant) + Example 7.4 (PCA factor model)"
book_pages: "61-69 (Ex 3.7 + Ex 3.8) + 135-140 (Ex 7.4)"
extraction_method: poppler `pdftotext -layout`
extracted_by: Research Agent
extracted_at: 2026-04-28
---

# SRC02 raw evidence — cross-sectional family (Khandani-Lo + Open-bar variant + PCA factor)

This file aggregates verbatim quotes + MATLAB code excerpts for the three multi-stock cross-sectional Strategy Cards in Chan, *Quantitative Trading* (Wiley 2009). The corresponding cards live at:

- `cards/chan-khandani-lo-mr_card.md` — S03, folds Ex 3.7 (close-bar baseline) + Ex 3.8 (open-bar refinement variant)
- `cards/chan-pca-factor_card.md` — S04

All three examples share the V5-architecture-incompatibility cluster previously documented for S05/S06: multi-stock cross-section + ~100-position simultaneous basket + universe-level data feed required + Darwinex stack incompatible. Per DL-033 Rule 1 the cards are drafted regardless; G0 / P3.5 decide actual deployability with the recommended **Path 2 verdict** ("V5-architecture-incompatible reference for future broker-expansion").

---

## A. Example 3.7 — A Simple Mean-Reverting Model (Khandani-Lo simple MR), pp. 61-65

### A.1 Concept (verbatim, p. 61)

> "Here is a simple mean-reverting model that is due to Amir Khandani and Andrew Lo at MIT (available at web.mit.edu/alo/www/Papers/august07.pdf). This strategy is very simple: Buy the stocks with the worst previous one-day returns, and short the ones with the best previous one-day returns. Despite its utter simplicity, this strategy has had great performance since 1995, ignoring transaction costs (it has a Sharpe ratio of 4.47 in 2006). Our objective here is to find out what would happen to its performance in 2006 if we assume a standard 5-basis-point-per-trade transaction cost. (A trade is defined as a buy or a short, not a round-trip transaction.)"

> "This example strategy not only allows us to illustrate the impact of transaction costs, it also illustrates the power of MATLAB in backtesting a model that trades multiple securities—in other words, a typical statistical arbitrage model."

### A.2 Universe-construction caveat (verbatim, p. 61)

> "Here, we will put aside the question of survivorship bias because of the expensive nature of such data and just bear in mind that whatever performance estimates we obtained are upper bounds on the actual performance of the strategy."

→ Pipeline P4 walk-forward should use point-in-time S&P 500 membership, not Chan's 2007-11-23 snapshot.

### A.3 MATLAB strategy core (verbatim, p. 63)

```matlab
clear;
startDate = 20060101;
endDate   = 20061231;
load('SPX 20071123', 'tday', 'stocks', 'cl');

% daily returns
dailyret = (cl - lag1(cl)) ./ lag1(cl);

% equal weighted market index return
marketDailyret = smartmean(dailyret, 2);

% weight of a stock is proportional to the negative
% distance to the market index.
weights = -(dailyret - repmat(marketDailyret, [1 size(dailyret, 2)])) ...
        ./ repmat(smartsum(isfinite(cl), 2), [1 size(dailyret, 2)]);

% those stocks that do not have valid prices or daily returns are excluded.
weights(isfinite(cl) | isfinite(lag1(cl))) = 0;
dailypnl = smartsum(lag1(weights) .* dailyret, 2);

% remove pnl outside of our dates of interest
dailypnl(tday < startDate | tday > endDate) = [];

% Sharpe ratio should be about 0.25
sharpe = sqrt(252) * smartmean(dailypnl, 1) / smartstd(dailypnl, 1)
```

### A.4 Mechanical-structure decoded

This is **NOT a discrete decile-sort** like S05/S06. The weighting scheme is **continuous and dollar-neutral**:

```text
For each stock i on day t (close-of-day):
    weight_i(t) = - (dailyret_i(t) - market_dailyret(t)) / N_valid_stocks(t)

where:
    market_dailyret(t) = equal-weighted average of all valid stock returns on day t
    N_valid_stocks(t)  = number of stocks with valid (close, lag-close) on day t

Properties:
    - Stocks that returned MORE than market on day t → NEGATIVE weight (short)
    - Stocks that returned LESS than market on day t → POSITIVE weight (long)
    - Sum of weights ≈ 0 (dollar-neutral) since (r_i − r_market) sums to ~0
    - Magnitude of weight scales with deviation from market
    - Position carried forward to day t+1 PnL via lag1(weights) * dailyret(t+1)
```

This is materially different from S05's discrete decile bucketing. Every valid stock holds a position every day; the sign and size of each position is continuously rescaled by the prior day's deviation from market.

### A.5 Performance results (verbatim, pp. 63-65)

Pre-cost (close-bar baseline):

> "Sharpe ratio should be about 0.25, not 4.47 as stated by the original authors. The reason for this drastically lower performance is due to the use of the large market capitalization universe of S&P 500 in our backtest. If you read the original paper by the authors, you will find that most of the returns are generated by small and microcap stocks." (p. 63-64)

Post-cost (5 bp/one-way):

```matlab
% daily pnl with transaction costs deducted
onewaytcost = 0.0005;   % assume 5 basis points
% remove weights outside of our dates of interest
weights(tday < startDate | tday > endDate, :) = [];
% transaction costs are only incurred when the weights change
dailypnlminustcost = dailypnl - smartsum(abs(weights - lag1(weights)), 2) .* onewaytcost;

% Sharpe ratio should be about -3.19
sharpeminustcost = sqrt(252) * smartmean(dailypnlminustcost, 1) / smartstd(dailypnlminustcost, 1)
```

> "The strategy is now very unprofitable!" (p. 65)

### A.6 Universe-effect framing

Chan explicitly notes the universe-choice effect (p. 64): SP500 → 0.25 Sharpe pre-cost; small-caps (per the original Khandani-Lo paper) → 4.47 Sharpe pre-cost. P3.5 CSR axis MUST sweep universe to capture this.

## B. Example 3.8 — A Small Variation on an Existing Strategy (open-bar variant), pp. 65-66

### B.1 Concept (verbatim, p. 65)

> "Let's refine the mean-reverting strategy described above in Example 3.7. Recall that strategy has a mediocre Sharpe ratio of 0.25 and a very unprofitable Sharpe ratio of -3.19 after transaction costs in 2006. The only change we will make here is to update the positions at the market open instead of the close. In the MATLAB code, simply replace 'cl' with 'op' everywhere."

### B.2 Performance results (verbatim, p. 65)

> "Lo and behold, the Sharpe ratio before costs increases to 4.43, and after costs, it increases to a profitable 0.78! I will leave it as an exercise for the reader to improve the Sharpe ratio further by testing the strategy on the S&P 400 mid-cap and S&P 600 small-cap universes."

### B.3 Verdict — fold or split?

The mechanical structure is **identical** to Ex 3.7 except for one parameter: `execution_bar_time` ∈ {`market_close`, `market_open`}. Per V5 conventions ("one strategy = one sub-issue" but "parameter sweeps are not separate strategies"), **fold both into ONE card with `execution_bar_time` as a P3 sweep axis**. The card's default value uses Ex 3.8's open-bar variant (Chan's published refinement); Ex 3.7's close-bar is the comparator.

This same fold pattern was applied in SRC01 davey-baseline-3bar (Davey Appendix A's variants Strategies 1/2/3/4 surfaced a similar question; CEO Q1 ruling pending there too).

## C. Example 7.4 — Principal Component Analysis as an Example of Factor Model, pp. 135-140

### C.1 Concept (verbatim, p. 135)

> "The examples of factor exposures I described above are typically economic (e.g., interest rates), fundamental (e.g., book-to-price ratio), or technical (e.g., previous period's return). To obtain historical values of these factor exposures for a large portfolio of stocks so as to backtest a factor model is usually quite expensive and not very practical to an independent trader. ... However, there is one kind of factor model that relies on nothing more than historical returns to construct. This method is the so-called principal component analysis (PCA)."

### C.2 PCA derivation (verbatim, p. 136)

> "If we use PCA to construct the factor exposures and factor returns, we must assume that the factor exposures are constant (time independent) over the estimation period. (This rules out factors that represent mean reversion or momentum, since these factor exposures depend on the prior period returns.) More importantly, we assume that the factor returns are uncorrelated; that is to say, their covariance matrix bb^T is diagonal. If we use the eigenvectors of the covariance matrix R R^T as the columns of the matrix X in the APT equation R = X b + u above, we will find via elementary linear algebra that bb^T is indeed diagonal; and furthermore, the eigenvalues of R R^T are none other than the variances of the factor returns b. But of course, there is no point to use factor analysis if the number of factors is the same as the number of stocks—typically, we can just pick the eigenvectors with the top few eigenvalues to form the matrix X. The number of eigenvectors to pick is a parameter that you can adjust to optimize your trading model."

### C.3 MATLAB strategy core (verbatim, p. 137-138)

```matlab
clear;

% use lookback days as estimation (training) period
% for determining factor exposures.
lookback = 252;
numFactors = 5;        % Use only 5 factors
% for trading strategy, long stocks with topN expected
% 1-day returns.
topN = 50;
% test on SP600 smallcap stocks. (This MATLAB binary
% input file contains tday, stocks, op, hi, lo, cl arrays.)
load('IJR 20080114');
mycls = fillMissingData(cl);

positionsTable = zeros(size(cl));

% note the rows of dailyret are the observations at different time periods
dailyret = (mycls - lag1(mycls)) / lag1(mycls);

for t = lookback+1 : length(tday)

    % here the columns of R are the different observations.
    R = dailyret(t - lookback + 1 : t, :)';
    % avoid any stocks with missing returns
    hasData = find(all(isfinite(R), 2));
    R = R(hasData, :);

    avgR = smartmean(R, 2);
    % subtract mean from returns
    R = R - repmat(avgR, [1 size(R, 2)]);
    % compute covariance matrix, with observations in rows.
    covR = smartcov(R');
    % X is the factor exposures matrix, B the variances of factor returns.
    % Use the eigenvectors of covR as column vectors for X.
    [X, B] = eig(covR);
    % Retain only numFactors
    X(:, 1:size(X, 2) - numFactors) = [];

    % b are the factor returns for time period t-1 to t.
    results = ols(R(:, end), X);
    b = results.beta;

    % Rexp is the expected return for next period
    % assuming factor returns remain constant.
    Rexp = avgR + X * b;
    [foo idxSort] = sort(Rexp, 'ascend');

    % short topN stocks with lowest expected returns
    positionsTable(t, hasData(idxSort(1:topN))) = -1;
    % buy topN stocks with highest expected returns
    positionsTable(t, hasData(idxSort(end-topN+1:end))) = 1;
end

% compute daily returns of trading strategy
ret = smartsum(backshift(1, positionsTable) .* dailyret, 2);
% compute annualized average return of trading strategy
avgret = smartmean(ret) * 252;   % A very poor return!
% avgret = -1.8099
```

### C.4 Mechanical-structure decoded

```text
ROLLING DAILY (each day t > lookback):
    1. R = dailyret(t-lookback+1 : t, :)'           // 252 days × N stocks (transposed)
    2. center: R_centered = R - mean(R, axis=row-of-stocks)
    3. covR = cov(R_centered)                       // N × N
    4. [X, B] = eig(covR)                           // X = N × N eigenvectors, B = diag of eigenvalues
    5. retain top numFactors=5 eigenvectors → X is N × 5
    6. b = OLS(R_centered[:, last_day], X)          // factor returns for last bar; 5 × 1
    7. Rexp = avgR + X * b                          // expected next-period return per stock
    8. sort stocks by Rexp ascending
    9. SHORT_BASKET = lowest topN=50 Rexp          → weight = -1
       LONG_BASKET  = highest topN=50 Rexp         → weight = +1
   10. positions held for ONE day, then recomputed next day

Properties:
    - Multi-stock daily-rebalance long-short basket (100 simultaneous positions)
    - Equal-weight within each basket
    - Universe: S&P 600 small-cap (Chan: load('IJR 20080114'))
    - Lookback for covariance: 252 trading days (~1 year)
    - PCA reduction: top 5 eigenvectors retained
```

### C.5 Performance result (verbatim, p. 138)

```matlab
avgret = -1.8099
```

Verbatim Chan comment (p. 137 right above the avgret print):

> "You will find that the average return of this strategy is negative, indicating that this assumption [factor returns have momentum] may be quite inaccurate, or that specific returns are too large for this strategy to work."

→ Chan's third deliberate-failure example in SRC02 (after S02 chan-bollinger-es and S06 chan-yoy-same-month). All three demonstrate methodological points about transaction costs, anomaly decay, and factor-model assumptions. Per DL-033 Rule 1, all three get cards regardless.

### C.6 Factor-model framing (verbatim, p. 139)

> "How good are the performances of factor models in real trading? ... Factor models that are dominated by fundamental and macroeconomic factors have one major drawback—they depend on the fact that investors persist in using the same metric to value companies. This is just another way of saying that the factor returns must have momentum for factor models to work."

Chan implicates the failure mode: PCA factor returns assumed to persist (have momentum) from t-1 to t — but the assumption is broken by short-term mean-reversion in stock returns.

## D. Card-folding decisions

| Source location | Card | Fold rationale |
|---|---|---|
| Ex 3.7 (close-bar baseline, Sharpe 0.25 / -3.19) | S03 chan-khandani-lo-mr | Same mechanical strategy as Ex 3.8 except `execution_bar_time` parameter |
| Ex 3.8 (open-bar variant, Sharpe 4.43 / 0.78) | S03 chan-khandani-lo-mr | Folded into S03 as the published-refined parameter value |
| Ex 7.4 (PCA factor model, avg ret -1.81%) | S04 chan-pca-factor | Distinct mechanical strategy: PCA-derived expected return ranking vs Ex 3.7's continuous-weight-by-deviation. Different entry mechanism even though both are "cross-sectional decile sort" family. Single card. |

## E. Shared 5th vocabulary-gap proposal: `cross-sectional-decile-sort`

Already proposed via S05/S06 (heartbeat 5). S03 and S04 reinforce the gap:

- S03 (Khandani-Lo) extends the proposal: the entry mechanism is "rank universe by lookback metric → long the worst, short the best" but with **continuous weighting** rather than discrete decile bucketing. The `cross-sectional-decile-sort` flag should accommodate both discrete (S05/S06/S04) and continuous (S03) variants — perhaps via a sub-flag `weighting: discrete-decile | continuous-distance | pca-rank-decile`.
- S04 (PCA factor) confirms the same flag with a different ranking metric (PCA-derived expected return vs S05's prior-year annual return vs S06's same-month-last-year return vs S03's prior-day deviation from market).

CEO + CTO ratification at addition time (after SRC02 stabilizes) decides whether one flag covers all four cards or splits along discrete-vs-continuous-weighting / lookback-metric axes. Research recommends ONE flag with `weighting_scheme` and `ranking_metric` as Strategy Card-level parameters — keeps the vocabulary economical.

## F. Architectural-incompatibility cluster summary (S03/S04/S05/S06)

| Risk | S03 Khandani-Lo | S04 PCA factor | S05 January Effect | S06 YoY same-month |
|---|---|---|---|---|
| `dwx_suffix_discipline` | severe (no Darwinex SP500 cross-section) | severe (no Darwinex SP600 cross-section) | severe | severe |
| `one_position_per_magic_symbol` | ~500 positions/day (continuous weights) | 100 positions/day (50L+50S) | ~120 positions/year | ~100 positions/month |
| `darwinex_native_data_only` | severe (universe-level US equity feed) | severe | severe | severe |
| Daily turnover | extreme (every day rebalance, all positions change) | extreme (every day rebalance) | low (annual) | medium (monthly) |
| Transaction-cost sensitivity | extreme — Chan demonstrates 5bp wipes Sharpe | very high | medium | medium |
| Pipeline P9 portfolio-fit | tx-cost-sensitive, edge depends on liquid SC | edge depends on factor stability | tax-loss-selling decay | anomaly decayed post-2002 |

All four cards share the same recommended G0 verdict: **Path 2 — document as "V5-architecture-incompatible reference"** for future broker-expansion. Preserves V5 corpus institutional memory for re-activation when QM acquires multi-stock-equity broker access.
