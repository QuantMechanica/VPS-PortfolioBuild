#property strict
#property version   "5.0"
#property description "QM5_2004 NNFX TRIX Momentum"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_2004: The TRIX Momentum
// Baseline:     ZLEMA(34) — price above baseline = bullish
// Confirmation: TRIX(14) line > signal(9) — momentum confirms direction
// Regime:       Choppiness Index(14) < 38 — trending market only
// Exit:         TRIX line crosses signal in opposite direction
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 2004;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_zlema_period        = 34;
input int    strategy_trix_period         = 14;
input int    strategy_trix_signal_period  = 9;
input int    strategy_chop_period         = 14;
input double strategy_chop_threshold      = 38.0;
input int    strategy_atr_period          = 14;
input double strategy_atr_sl_mult         = 1.5;
input double strategy_rr                  = 1.5;

// --- File-scope indicator state -------------------------------------------
// ZLEMA: two-pass EMA (first EMA of close, then EMA on lag-adjusted close)
double g_zlema_alpha = 0.0;
double g_zlema_e1    = 0.0;
double g_zlema       = 0.0;

// TRIX: triple-smoothed EMA + signal line
double g_trix_alpha     = 0.0;
double g_trix_sig_alpha = 0.0;
double g_trix_e1        = 0.0;
double g_trix_e2        = 0.0;
double g_trix_e3        = 0.0;
double g_trix_val       = 0.0;
double g_trix_sig       = 0.0;

// CHOP: recomputed per closed bar via QM_ATR + range scan
double g_chop        = 100.0;

bool   g_state_ready = false;

// --------------------------------------------------------------------------
// Bootstrap EMA state from historical bars — called once in OnInit.
// Uses CopyRates to seed all EMA chains over ~300 bars so that by the time
// the first live bar arrives the warmup bias is negligible.
// --------------------------------------------------------------------------
void BootstrapIndicators()
{
    g_state_ready    = false;
    g_zlema_alpha    = 2.0 / (strategy_zlema_period + 1.0);
    g_trix_alpha     = 2.0 / (strategy_trix_period + 1.0);
    g_trix_sig_alpha = 2.0 / (strategy_trix_signal_period + 1.0);

    const int min_bars = 3 * strategy_trix_period + strategy_trix_signal_period + 10;
    const int warmup   = 300;
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    const int n = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 0, warmup, rates); // perf-allowed: one-shot OnInit warmup for ZLEMA/TRIX bootstrap; never called from OnTick
    if(n < min_bars)
        return;

    // Seed from oldest bar; iterate oldest-to-newest, stop at rates[1] (last closed)
    g_zlema_e1 = rates[n - 1].close;
    g_zlema    = rates[n - 1].close;
    g_trix_e1  = rates[n - 1].close;
    g_trix_e2  = rates[n - 1].close;
    g_trix_e3  = rates[n - 1].close;
    g_trix_val = 0.0;
    g_trix_sig = 0.0;
    g_chop     = 100.0;

    for(int i = n - 2; i >= 1; i--)
    {
        const double c = rates[i].close;

        // ZLEMA: EMA of (2*close - EMA(close)) eliminates lag
        g_zlema_e1 = g_zlema_alpha * c + (1.0 - g_zlema_alpha) * g_zlema_e1;
        g_zlema    = g_zlema_alpha * (2.0 * c - g_zlema_e1)
                   + (1.0 - g_zlema_alpha) * g_zlema;

        // TRIX: triple-smoothed EMA rate of change
        g_trix_e1 = g_trix_alpha * c + (1.0 - g_trix_alpha) * g_trix_e1;
        g_trix_e2 = g_trix_alpha * g_trix_e1 + (1.0 - g_trix_alpha) * g_trix_e2;
        const double e3new = g_trix_alpha * g_trix_e2 + (1.0 - g_trix_alpha) * g_trix_e3;
        if(g_trix_e3 > 0.0)
        {
            g_trix_val = (e3new - g_trix_e3) / g_trix_e3 * 100.0;
            g_trix_sig = g_trix_sig_alpha * g_trix_val
                       + (1.0 - g_trix_sig_alpha) * g_trix_sig;
        }
        g_trix_e3 = e3new;
    }

    g_state_ready = true;
}

// --------------------------------------------------------------------------
// Advance all indicator state by one closed bar.
// Must be called once per new bar AFTER QM_IsNewBar() fires.
// --------------------------------------------------------------------------
void AdvanceState_OnNewBar()
{
    if(!g_state_ready) return;

    const double c = iClose(_Symbol, _Period, 1); // perf-allowed: bespoke ZLEMA/TRIX per-bar advance; runs once per closed bar behind QM_IsNewBar gate

    // ZLEMA advance
    g_zlema_e1 = g_zlema_alpha * c + (1.0 - g_zlema_alpha) * g_zlema_e1;
    g_zlema    = g_zlema_alpha * (2.0 * c - g_zlema_e1)
               + (1.0 - g_zlema_alpha) * g_zlema;

    // TRIX advance
    g_trix_e1 = g_trix_alpha * c + (1.0 - g_trix_alpha) * g_trix_e1;
    g_trix_e2 = g_trix_alpha * g_trix_e1 + (1.0 - g_trix_alpha) * g_trix_e2;
    const double e3new = g_trix_alpha * g_trix_e2 + (1.0 - g_trix_alpha) * g_trix_e3;
    if(g_trix_e3 > 0.0)
    {
        g_trix_val = (e3new - g_trix_e3) / g_trix_e3 * 100.0;
        g_trix_sig = g_trix_sig_alpha * g_trix_val
                   + (1.0 - g_trix_sig_alpha) * g_trix_sig;
    }
    g_trix_e3 = e3new;

    // CHOP = 100 * log10(sum(ATR1, N) / (highest_high - lowest_low, N)) / log10(N)
    double atr_sum = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, 1);
    double highest = iHigh(_Symbol, _Period, 1); // perf-allowed: bespoke Choppiness Index highest-high scan; no QM_* multi-bar range helper
    double lowest  = iLow(_Symbol, _Period, 1);  // perf-allowed: bespoke Choppiness Index lowest-low scan; no QM_* multi-bar range helper
    for(int i = 2; i <= strategy_chop_period; i++)
    {
        atr_sum += QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, i);
        const double h = iHigh(_Symbol, _Period, i); // perf-allowed: CHOP range scan iteration
        const double l = iLow(_Symbol, _Period, i);  // perf-allowed: CHOP range scan iteration
        if(h > highest) highest = h;
        if(l < lowest)  lowest  = l;
    }
    const double range = highest - lowest;
    g_chop = (range > 0.0)
           ? 100.0 * MathLog10(atr_sum / range) / MathLog10((double)strategy_chop_period)
           : 100.0;
}

// --- Strategy Hooks -------------------------------------------------------

// No intraday filter — strategy is D1 closed-bar, 24/5.
bool Strategy_NoTradeFilter()
{
    return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
    if(!g_state_ready) return false;
    if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0) return false;

    // Regime gate: only trade in strongly trending market (CHOP < threshold)
    if(g_chop >= strategy_chop_threshold) return false;

    const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

    // Long: price above ZLEMA baseline AND TRIX line above signal
    if(bid > g_zlema && g_trix_val > g_trix_sig)
    {
        req.type   = QM_BUY;
        req.price  = 0.0;
        req.sl     = QM_StopATR(_Symbol, req.type, ask, strategy_atr_period, strategy_atr_sl_mult);
        req.tp     = QM_TakeRR(_Symbol, req.type, ask, req.sl, strategy_rr);
        req.reason = "NNFX_TRIX_LONG";
        return (req.sl > 0.0);
    }

    // Short: price below ZLEMA baseline AND TRIX line below signal
    if(bid < g_zlema && g_trix_val < g_trix_sig)
    {
        req.type   = QM_SELL;
        req.price  = 0.0;
        req.sl     = QM_StopATR(_Symbol, req.type, bid, strategy_atr_period, strategy_atr_sl_mult);
        req.tp     = QM_TakeRR(_Symbol, req.type, bid, req.sl, strategy_rr);
        req.reason = "NNFX_TRIX_SHORT";
        return (req.sl > 0.0);
    }

    return false;
}

// No per-tick management (SL/TP handles risk; exit is signal-driven).
void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
{
    if(!g_state_ready) return false;
    const int magic = QM_FrameworkMagic();
    for(int i = PositionsTotal() - 1; i >= 0; --i)
    {
        const ulong ticket = PositionGetTicket(i);
        if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
        if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
        const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        // Exit when TRIX line crosses signal in the opposite direction
        if(ptype == POSITION_TYPE_BUY  && g_trix_val < g_trix_sig) return true;
        if(ptype == POSITION_TYPE_SELL && g_trix_val > g_trix_sig) return true;
    }
    return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time)
{
    return false; // defer to framework's two-axis news filter
}

// --- Framework Wiring -----------------------------------------------------

int OnInit()
{
    if(!QM_FrameworkInit(qm_ea_id,
                         qm_magic_slot_offset,
                         RISK_PERCENT,
                         RISK_FIXED,
                         PORTFOLIO_WEIGHT,
                         qm_news_mode_legacy,
                         qm_friday_close_enabled,
                         qm_friday_close_hour_broker,
                         30,
                         30,
                         qm_news_stale_max_hours,
                         qm_news_min_impact,
                         qm_rng_seed,
                         qm_stress_reject_probability,
                         qm_news_temporal,
                         qm_news_compliance))
        return INIT_FAILED;

    BootstrapIndicators();
    QM_LogEvent(QM_INFO, "INIT_OK", StringFormat("{\"state_ready\":%s}",
                g_state_ready ? "true" : "false"));
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
    QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
    QM_FrameworkShutdown();
}

void OnTick()
{
    if(!QM_KillSwitchCheck()) return;

    const datetime broker_now = TimeCurrent();
    if(Strategy_NewsFilterHook(broker_now)) return;

    bool news_allows = true;
    if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
        news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
    else
        news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
    if(!news_allows) return;

    if(QM_FrameworkHandleFridayClose()) return;
    if(Strategy_NoTradeFilter()) return;

    // Per-tick: management and exit check use last-known cached indicator state
    Strategy_ManageOpenPosition();

    if(Strategy_ExitSignal())
    {
        const int magic = QM_FrameworkMagic();
        for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
            const ulong ticket = PositionGetTicket(i);
            if(!PositionSelectByTicket(ticket)) continue;
            if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
            QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
    }

    // Per-closed-bar: advance indicators then evaluate entry
    if(!QM_IsNewBar()) return;

    QM_EquityStreamOnNewBar();
    AdvanceState_OnNewBar();

    QM_EntryRequest req;
    if(Strategy_EntrySignal(req))
    {
        ulong out_ticket = 0;
        QM_TM_OpenPosition(req, out_ticket);
    }
}

void OnTimer()
{
    QM_FrameworkOnTimer();
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
    QM_FrameworkOnTradeTransaction(trans, request, result);
}

double OnTester()
{
    QM_ChartUI_Refresh();
    return QM_DefaultObjective();
}
