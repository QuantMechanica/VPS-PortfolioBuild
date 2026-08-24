import random


def lwma_window(vals):
    # vals: list oldest..newest, weight = position (1..N), most-weight to newest
    n = len(vals)
    weights = list(range(1, n + 1))
    return sum(w * v for w, v in zip(weights, vals)) / sum(weights)


def qm_lwma_ref(prices, shift, period):
    # prices: list oldest..newest (index 0 = oldest). "shift" bars back from the newest closed bar.
    center = len(prices) - 1 - shift
    window = prices[center - period + 1: center + 1]
    assert len(window) == period
    return lwma_window(window)


def diff_series(prices, shift, half, period):
    w_half = qm_lwma_ref(prices, shift, half)
    w_full = qm_lwma_ref(prices, shift, period)
    return 2.0 * w_half - w_full


def qm_hma_fixed_pointwise(prices, shift, period):
    # mirrors the proposed MQL5 loop fix exactly
    half = period // 2
    sqr = int(period ** 0.5)
    weighted_sum = 0.0
    weight_total = 0.0
    for i in range(sqr):
        s = shift + i
        d = diff_series(prices, s, half, period)
        w = sqr - i
        weighted_sum += d * w
        weight_total += w
    return weighted_sum / weight_total


def qm_hma_fixed_vectorized_independent(prices, shift, period):
    # INDEPENDENT re-derivation: build the full diff array (textbook approach),
    # then take a plain LWMA window over that array using the *same* windowing
    # convention as qm_lwma_ref, but implemented via a totally separate code path
    # (array-building + explicit weighted rolling, no shared helper with diff_series()).
    half = period // 2
    sqr = int(period ** 0.5)
    n = len(prices)
    diff_arr = [None] * n
    for center in range(period - 1, n):
        window_half = prices[center - half + 1: center + 1]
        window_full = prices[center - period + 1: center + 1]
        wh = lwma_window(window_half)
        wf = lwma_window(window_full)
        diff_arr[center] = 2.0 * wh - wf
    center = n - 1 - shift
    win = diff_arr[center - sqr + 1: center + 1]
    assert all(v is not None for v in win), "diff window touches unpopulated region"
    return lwma_window(win)


def main():
    random.seed(42)
    periods = [9, 14, 21, 55]
    max_diff = 0.0
    trials = 0
    for period in periods:
        n = 400
        prices = [100.0]
        for _ in range(n - 1):
            prices.append(prices[-1] + random.gauss(0, 0.5))
        for shift in [1, 2, 5, 10, 50, 100]:
            a = qm_hma_fixed_pointwise(prices, shift, period)
            b = qm_hma_fixed_vectorized_independent(prices, shift, period)
            d = abs(a - b)
            max_diff = max(max_diff, d)
            trials += 1
            assert d < 1e-9, f"MISMATCH period={period} shift={shift} a={a} b={b} d={d}"

    print(f"PASS: {trials} trials across periods={periods}, max_abs_diff={max_diff:.3e}")

    buggy_vals = []
    fixed_vals = []
    period = 14
    prices = [100.0]
    random.seed(1)
    for _ in range(300):
        prices.append(prices[-1] + random.gauss(0, 0.5))
    for shift in [1, 5, 20]:
        half = period // 2
        buggy = diff_series(prices, shift, half, period)
        fixed = qm_hma_fixed_pointwise(prices, shift, period)
        buggy_vals.append(buggy)
        fixed_vals.append(fixed)
        print(f"shift={shift} buggy(diff)={buggy:.6f} fixed(hma)={fixed:.6f} delta={buggy - fixed:.6f}")


if __name__ == "__main__":
    main()
