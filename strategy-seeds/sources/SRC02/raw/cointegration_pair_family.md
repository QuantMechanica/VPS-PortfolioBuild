---
source_id: SRC02
source_pdf: "G:\\My Drive\\QuantMechanica\\Ebook\\PDF resources\\Quantitative Trading_ How to Bu - Ernest P. Chan.pdf"
extracted_section: "Cointegration pair-trade family — Examples 3.6 + 7.2 + 7.3 + 7.5 + Ch 7 Stationarity & Cointegration narrative"
book_pages: "55-66 (Ex 3.6) + 126-133 (Ch 7 narrative + Ex 7.2 + 7.3) + 140-142 (Ex 7.5)"
extraction_method: poppler `pdftotext -layout`
extracted_by: Research Agent
extracted_at: 2026-04-27
---

# SRC02 raw evidence — cointegration pair-trade family (GLD / GDX)

This file aggregates verbatim quotes + mechanical-structure passages from Chan, *Quantitative Trading* (Wiley 2009) for the **GLD / GDX cointegration pair-trade strategy**, which spans four Examples in the book (3.6 + 7.2 + 7.3 + 7.5) plus the Ch 7 "Stationarity and Cointegration" narrative. The card `cards/chan-pairs-stat-arb_card.md` folds these into a single Strategy Card per V5 schema; this raw file exists so reviewers can audit the verbatim source-text without re-running `pdftotext`.

Page numbers refer to the printed book pagination (PDF text-extraction layout matches it). Page-break artifacts ("130 QUANTITATIVE TRADING" running headers and "Special Topics in Quantitative Trading 127" footers) are dropped where they fragment a sentence; otherwise preserved.

---

## A. Ch 7 narrative — "Stationarity and Cointegration", pp. 126-127

Verbatim (`raw/ch7_special_topics_pp116-165.txt` lines 1272-1299):

> A time series is "stationary" if it never drifts farther and farther away from its initial value. In technical terms, stationary time series are "integrated of order zero," or I(0). (See Alexander, 2001.) It is obvious that if the price series of a security is stationary, it would be a great candidate for a mean-reversion strategy. Unfortunately, most stock price series are not stationary—they exhibit a geometric random walk that gets them farther and farther away from their starting (i.e., initial public offering) values. However, you can often find a pair of stocks such that if you long one and short the other, the market value of the pair is stationary. If this is the case, then the two individual time series are said to be cointegrated. They are so described because a linear combination of them is integrated of order zero. Typically, two stocks that form a cointegrating pair are from the same industry group. Traders have long been familiar with this so-called pair-trading strategy. They buy the pair portfolio when the spread of the stock prices formed by these pairs is low, and sell/short the pair when the spread is high—in other words, a classic mean-reverting strategy.
>
> An example of a pair of cointegrating price series is the gold ETF GLD versus the gold miners ETF, GDX, which I discussed in Example 3.6. If we form a portfolio with long 1 share of GLD and short 1.6766 share of GDX, the prices of the portfolio form a stationary time series (see Figure 7.4). The exact number of shares of GLD and GDX can be determined by a regression fit of the two component time series (see Example 7.2).

Figure 7.4 caption: "A Stationary Time Series Formed by the Spread between GLD and GDX". Spread plotted from approx. 2006-05-23 to 2007-12-21; spread oscillates roughly in [-6, +10] dollars over the window.

## B. Example 3.6 — Pair Trading of GLD and GDX, pp. 55-59

### B.1 Set-up rationale (verbatim, p. 55)

> GLD versus GDX is a good candidate for pair trading because GLD reflects the spot price of gold, and GDX is a basket of gold-mining stocks. It makes intuitive sense that their prices should move in tandem. I have discussed this pair of ETFs extensively on my blog in connection with cointegration analysis (see, e.g., epchan.blogspot.com/2006/11/reader-suggested-possible-trading.html). Here, however, I will defer until Chapter 7 the cointegration analysis on the training set, which demonstrates that the spread formed by long GLD and short GDX is mean reverting. Instead, we will perform a regression analysis on the training set to determine the hedge ratio between GLD and GDX, and then define entry and exit thresholds for a pair-trading strategy.

### B.2 MATLAB code — strategy core (verbatim, pp. 56-58)

```matlab
% spread = GLD - hedgeRatio*GDX
spread = cl1 - hedgeRatio*cl2;

% mean of spread on trainset
spreadMean = mean(spread(trainset));
% standard deviation of spread on trainset
spreadStd = std(spread(trainset));
% z-score of spread
zscore = (spread - spreadMean)./spreadStd;

% buy spread when its value drops below 2 standard deviations.
longs  = zscore <= -2;
% short spread when its value rises above 2 standard deviations.
shorts = zscore >=  2;
% exit any spread position when its value is within 1
% standard deviation of its mean.
exits  = abs(zscore) <= 1;

% short entries
positions(shorts, :) = repmat([-1  1], [length(find(shorts)) 1]);
% long entries
positions(longs,  :) = repmat([ 1 -1], [length(find(longs))  1]);
% exit positions
positions(exits,  :) = zeros(length(find(exits)), 2);
% ensure existing positions are carried forward unless there is an exit signal
positions = fillMissingData(positions);
```

Hedge-ratio fit (verbatim, p. 58):
```matlab
results = ols(cl1(trainset), cl2(trainset));
hedgeRatio = results.beta;
% hedgeRatio = 1.6766
```

### B.3 Performance claims (verbatim, p. 58)

> So this pair-trading strategy has excellent Sharpe ratios on both the training set and the test set. Therefore, this strategy can be considered free of data-snooping bias.

Sharpe ratios reported in code comments:
- `% the Sharpe ratio on the training set should be about 2.3` (training-set fit, ±2 entry / ±1 exit)
- `% the Sharpe ratio on the test set should be about 1.5` (out-of-sample, same thresholds)

Refined-thresholds Sharpe (verbatim, p. 59):
> However, there may be room for improvement. Let's see what happens if we change the entry thresholds to 1 standard deviation and exit threshold to 0.5 standard deviation. In this case, the Sharpe ratio on the training set increases to 2.9 and the Sharpe ratio on the test set increases to 2.1. So, clearly, this set of thresholds is better.

### B.4 Train/test split

```matlab
trainset = 1:252;                                       % first 252 daily bars (~1 year)
testset  = trainset(end)+1:length(tday);
```

Data range (inferred from book context + Figure 7.4 caption): GLD inception 2004-11-18, GDX inception 2006-05-22 → effective shared history starts 2006-05-23. Training set ≈ 2006-05-23 to 2007-05-21; test set runs from 2007-05-22 forward to publication-time data (~2007-12-21 per Figure 7.4 endpoint).

### B.5 Look-ahead-bias self-test (verbatim, pp. 58-59)

> One last check, though, that we should perform before calling this a success: We need to check for any look-ahead bias in the backtest program.

Code: re-run the strategy with the last 60 days truncated, save as `example3 6 1.m`; verify that the truncated run's `positions` array equals the original `positions` truncated to the same range. Chan reports the strategy passes this test.

### B.6 Transaction-cost note (verbatim, p. 59)

> I have not incorporated transaction costs (which I discuss in the next section) into this analysis. You can try to add that as an exercise. Since this strategy doesn't trade very frequently, transaction costs do not have a big impact on the resulting Sharpe ratio.

## C. Example 7.2 — How to Form a Good Cointegrating (and Mean-Reverting) Pair of Stocks, pp. 128-130

### C.1 Cointegration test (verbatim, p. 128)

> The main method used to test for cointegration is called the cointegrating augmented Dickey-Fuller test, hence the function name `cadf`. A detailed description of this method can be found in the manual also available on the same web site mentioned earlier.

### C.2 MATLAB code — cointegration test on GLD/GDX

```matlab
res = cadf(adjcls(:, 1), adjcls(:, 2), 0, 1);
prt(res, vnames);
```

### C.3 cadf output (verbatim, p. 129)

```
Augmented DF test for co-integration variables: GLD, GDX
CADF t-statistic     # of lags AR(1) estimate
 -3.35698533              1     -0.060892

1% Crit Value 5% Crit Value 10% Crit Value
       -3.819        -3.343         -3.042
```

> The t-statistic of -3.36 which is in between the 1% Crit Value of -3.819 and the 5% Crit Value of -3.343 means that there is a better than 95% probability that these 2 time series are cointegrated.

### C.4 Hedge-ratio derivation (verbatim, p. 130)

```matlab
results = ols(adjcls(:, 1), adjcls(:, 2));
hedgeRatio = results.beta;     % A hedgeRatio of 1.6766 was found.
z = results.resid;
% I.e. GLD = 1.6766*GDX + z, where z can be interpreted as the
% spread GLD - 1.6766*GDX and should be stationary.
```

## D. Example 7.3 — Cointegration vs Correlation Counterexample (KO/PEP), pp. 131-133

### D.1 Counterexample framing (verbatim, p. 131)

> Many pair traders are unfamiliar with the concepts of stationarity and cointegration. But most of them are familiar with correlation, which superficially seems to mean the same thing as cointegration. Actually, they are quite different. Correlation between two price series actually refers to the correlations of their returns over some time horizon ... However, having a positive correlation does not say anything about the long-term behavior of the two stocks. In particular, it doesn't guarantee that the stock prices will not grow farther and farther apart in the long run even if they do move in the same direction most days. However, if two stocks were cointegrated and remain so in the future, their prices (weighted appropriately) will be unlikely to diverge. Yet their daily (or weekly, or any other time horizon) returns may be quite uncorrelated.

### D.2 KO/PEP cointegration test result (verbatim, pp. 132-133)

> The cointegration result shows that the t-statistic for the augmented Dickey-Fuller test is -2.14, larger than the 10 percent critical value of -3.038, meaning that there is a less than 90 percent probability that these two time series are cointegrated.

KO/PEP daily-return correlation: 0.4849, P-value 0 (statistically significant).

**Methodological takeaway**: cointegration ≠ correlation. The pair-trade strategy in Examples 3.6 / 7.2 only works on cointegrated pairs (cadf t-stat below the chosen critical value), not on merely-correlated pairs. KO/PEP would fail the cointegration filter and therefore be EXCLUDED from a real-world deployment of this strategy — even though many "pairs traders" historically used correlation as a substitute filter.

### D.3 Generalization (verbatim, p. 133)

> Stationarity is not limited to the spread between stocks: it can also be found in certain currency rates. For example, the Canadian dollar / Australian dollar (CAD/AUD) cross-currency rate is quite stationary, both being commodities currencies. Numerous pairs of futures as well as well as fixed-income instruments can be found to be cointegrating as well. (The simplest examples of cointegrating futures pairs are calendar spreads: long and short futures contracts of the same underlying commodity but different expiration months. Similarly for fixed-income instruments, one can long and short bonds by the same issuer but of different maturities.)

→ **V5 Darwinex re-mapping candidates**: AUDCAD.DWX (spot FX, single symbol; mean-reversion candidate), or commodity-futures calendar spreads (not on Darwinex). The two-ETF GLD/GDX approach maps awkwardly to Darwinex (GOLD.DWX exists, but no gold-miners equivalent).

## E. Example 7.5 — Half-Life of Mean Reversion (Ornstein-Uhlenbeck), pp. 141-142

### E.1 Theoretical basis (verbatim, pp. 140-141)

> The mean reversion of a time series can be modeled by an equation called the Ornstein-Uhlenbeck formula (Uhlenbeck, 1930). Let's say we denote the mean-reverting spread (long market value minus short market value) of a pair of stocks as z(t). Then we can write
>
>      dz(t) = -θ(z(t) - μ)dt + dW
>
> where μ is the mean value of the prices over time, and dW is simply some random Gaussian noise. Given a time series of the daily spread values, we can easily find θ (and μ) by performing a linear regression fit of the daily change in the spread dz against the spread itself. Mathematicians tell us that the average value of z(t) follows an exponential decay to its mean μ, and the half-life of this exponential decay is equal to ln(2)/θ, which is the expected time it takes for the spread to revert to half its initial deviation from the mean. This half-life can be used to determine the optimal holding period for a mean-reverting position.

### E.2 MATLAB code — OU half-life on GLD/GDX (verbatim, p. 141)

```matlab
prevz = backshift(1, z);                 % z at a previous time-step
dz    = z - prevz;
dz(1)    = [];
prevz(1) = [];
% assumes dz = theta*(z - mean(z))*dt + w, where w is error term
results  = ols(dz, prevz - mean(prevz));
theta    = results.beta;

halflife = -log(2)/theta
% halflife = 10.0037
```

### E.3 Operational implication (verbatim, p. 142)

> The program finds that the half-life for mean reversion of the GLD-GDX is about 10 days, which is approximately how long you should expect to hold this spread before it becomes profitable.
>
> If you believe that your security is mean reverting, then you also have a ready-made target price—the mean value of the historical prices of the security, or μ in the Ornstein-Uhlenbeck formula. This target price can be used together with the half-life as exit signals (exit when either criterion is met).

→ **Card §5 implication**: profit target = mean(spread) reached (z-score in [-1, +1] band per Example 3.6 exit rule); time-stop = half-life (≈10 days for GLD/GDX). Both fire whichever comes first.

## F. Mechanical structure summary (folded across A-E)

| Element | Specification | Source |
|---|---|---|
| Universe | Two-asset cointegrating pair (GLD + GDX in Chan's example; generalizes to any pair passing cadf at chosen significance level) | Ex 3.6 §B.1; Ch 7 narrative §A |
| Data | Daily adjusted close (split & dividend adjusted) | Ex 3.6 code §B.2 (`adjcls`) |
| Cointegration filter | Augmented Dickey-Fuller cointegration test (`cadf`); require t-statistic < 5% critical value (-3.343 for 2-variable case) | Ex 7.2 §C.3 |
| Hedge ratio | OLS regression of asset 1 on asset 2 over training set; β = `ols(cl1, cl2).beta` (1.6766 for GLD/GDX) | Ex 3.6 §B.2; Ex 7.2 §C.4 |
| Spread | `spread = cl1 - hedgeRatio * cl2` | Ex 3.6 §B.2 |
| Mean / std fit | `mean(spread(trainset))` and `std(spread(trainset))` — frozen on training set; **NOT recomputed on each bar** | Ex 3.6 §B.2 |
| Z-score | `zscore = (spread - spreadMean) / spreadStd` | Ex 3.6 §B.2 |
| Long entry | `zscore <= -2.0` (default) or `<= -1.0` (refined per §B.3) → long 1 unit asset 1, short hedgeRatio units asset 2 | Ex 3.6 §B.2 |
| Short entry | `zscore >= +2.0` (default) or `>= +1.0` (refined) → short 1 unit asset 1, long hedgeRatio units asset 2 | Ex 3.6 §B.2 |
| Exit | `abs(zscore) <= 1.0` (default) or `<= 0.5` (refined) | Ex 3.6 §B.2 |
| Time-stop | OU half-life ≈ 10 days for GLD/GDX (computed via Ex 7.5); generalizes per pair | Ex 7.5 §E.1, §E.3 |
| Sharpe (no costs) | Default thresholds: 2.3 train / 1.5 test; refined thresholds: 2.9 train / 2.1 test | Ex 3.6 §B.3 |
| Transaction-cost note | "Doesn't trade very frequently, transaction costs do not have a big impact" — no specific bps figure given | Ex 3.6 §B.6 |
| Counterexample | KO/PEP fails cadf at 90% (t = -2.14); correlated daily-returns (ρ=0.48) but NOT cointegrated → would be EXCLUDED from a real-world basket | Ex 7.3 §D.2 |
| Generalization | "Numerous pairs of futures as well as fixed-income instruments can be found to be cointegrating ... CAD/AUD cross-currency rate is quite stationary" | Ex 7.3 §D.3 |

This summary informs the entry/exit/parameter sections of `cards/chan-pairs-stat-arb_card.md`.
