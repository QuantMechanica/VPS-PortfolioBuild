#property strict
#property version   "5.0"
#property description "QM5_12563 Donchian Turtle Trend D1 — Commodities (WTI/Silver/Gold)"

#include <QM/QM_Common.mqh>

// ==================================================================================
// QM5_12563 — Donchian / Turtle Trend Following — Commodities & Metals (D1)
// Turtle System 1: 20-day Donchian breakout entry, 10-day reverse exit, 2N stop.
// Symbols: XTIUSD.DWX / XAGUSD.DWX / XAUUSD.DWX
// ==================================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 12563;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours               = 336;
input string qm_news_min_impact                    = "high";
input QM_NewsMode qm_news_mode_legacy              = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled               = true;
input int    qm_friday_close_hour_broker           = 21;

input group "Stress"
input double qm_stress_reject_probability          = 0.0;

input group "Strategy"
input int    strategy_entry_period     = 20;    // Donchian entry channel lookback (D1 bars)
input int    strategy_exit_period      = 10;    // Donchian exit channel lookback (D1 bars)
input int    strategy_atr_period       = 20;    // ATR period for N-value stop sizing
input double strategy_atr_stop_mult    = 2.0;   // Stop = ATR × this multiple (2N)
input int    strategy_vol_lookback     = 252;   // ATR history window for percentile filter (days)
input double strategy_vol_pct          = 0.5;   // Min ATR percentile; skip below this (0–100)

// ---- File-scope cached bar state (updated once per D1 closed bar) ----
double g_donchian_entry_high = 0.0;
double g_donchian_entry_low  = 0.0;
double g_donchian_exit_high  = 0.0;
double g_donchian_exit_low   = 0.0;
double g_close_last          = 0.0;
double g_atr_last            = 0.0;
bool   g_vol_filter_ok       = true;
bool   g_state_valid         = false;

double g_atr_hist[];
int    g_atr_hist_pos        = 0;
bool   g_atr_hist_full       = false;

// ---- State advance: called once per new D1 bar from Strategy_EntrySignal ----
void AdvanceState_OnNewBar()
{
    int bars_needed = strategy_entry_period + 2;
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    // perf-allowed: Donchian N-bar high/low is bespoke structural OHLC math; no QM_* substitute
    if(CopyRates(_Symbol, PERIOD_D1, 1, bars_needed, rates) < bars_needed)
    {
        g_state_valid = false;
        return;
    }

    // Last closed D1 bar close (shift 1 when new bar fires = rates[0])
    g_close_last = rates[0].close;

    // 20-bar entry channel: max-high / min-low of the N bars before the closed bar
    double h_entry = rates[1].high;
    double l_entry = rates[1].low;
    for(int i = 2; i <= strategy_entry_period; i++)
    {
        if(rates[i].high > h_entry) h_entry = rates[i].high;
        if(rates[i].low  < l_entry) l_entry = rates[i].low;
    }
    g_donchian_entry_high = h_entry;
    g_donchian_entry_low  = l_entry;

    // 10-bar exit channel
    double h_exit = rates[1].high;
    double l_exit = rates[1].low;
    for(int i = 2; i <= strategy_exit_period; i++)
    {
        if(rates[i].high > h_exit) h_exit = rates[i].high;
        if(rates[i].low  < l_exit) l_exit = rates[i].low;
    }
    g_donchian_exit_high = h_exit;
    g_donchian_exit_low  = l_exit;

    // ATR(20) via framework reader (closed bar shift 1)
    g_atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);

    // Volatility percentile filter: keep 1-year rolling ATR distribution
    if(ArraySize(g_atr_hist) != strategy_vol_lookback)
        ArrayResize(g_atr_hist, strategy_vol_lookback, 0.0);

    g_atr_hist[g_atr_hist_pos] = g_atr_last;
    g_atr_hist_pos = (g_atr_hist_pos + 1) % strategy_vol_lookback;
    if(!g_atr_hist_full && g_atr_hist_pos == 0)
        g_atr_hist_full = true;

    int hist_count = g_atr_hist_full ? strategy_vol_lookback : g_atr_hist_pos;
    if(hist_count > strategy_atr_period)
    {
        double sorted[];
        ArrayResize(sorted, hist_count);
        for(int j = 0; j < hist_count; j++)
            sorted[j] = g_atr_hist[j];
        ArraySort(sorted);
        int pct_idx = (int)MathFloor(hist_count * strategy_vol_pct / 100.0);
        if(pct_idx < 0)          pct_idx = 0;
        if(pct_idx >= hist_count) pct_idx = hist_count - 1;
        g_vol_filter_ok = (g_atr_last > sorted[pct_idx]);
    }
    else
        g_vol_filter_ok = true; // insufficient history; allow trading

    g_state_valid = true;
}

// =============================================================================
// No Trade Filter
// =============================================================================

bool Strategy_NoTradeFilter()
{
    return false;
}

// =============================================================================
// Trade Entry — also handles Donchian exit (per closed-bar timing)
// =============================================================================

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
    // Advance cached Donchian + ATR state for this new closed D1 bar
    AdvanceState_OnNewBar();

    if(!g_state_valid)
        return false;

    const long magic = (long)QM_FrameworkMagic();

    // ---- Donchian 10-bar exit: close open positions on reversal ----
    bool closed_any = false;
    for(int i = PositionsTotal() - 1; i >= 0; --i)
    {
        const ulong ticket = PositionGetTicket(i);
        if(!PositionSelectByTicket(ticket))
            continue;
        if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;

        ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        bool should_exit = false;
        if(pt == POSITION_TYPE_BUY  && g_close_last < g_donchian_exit_low)  should_exit = true;
        if(pt == POSITION_TYPE_SELL && g_close_last > g_donchian_exit_high) should_exit = true;
        if(should_exit)
        {
            QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
            closed_any = true;
        }
    }
    // No new entry on the same bar as an exit (let the close settle first)
    if(closed_any)
        return false;

    // No pyramiding — one position per magic
    if(QM_TM_OpenPositionCount((int)magic) > 0)
        return false;

    // Volatility filter: skip dead-volatility regimes
    if(!g_vol_filter_ok)
        return false;

    // Guard against uninitialized ATR
    if(g_atr_last <= 0.0)
        return false;

    // ---- Long entry: last D1 close broke above 20-day prior high ----
    if(g_close_last > g_donchian_entry_high)
    {
        req.type               = QM_BUY;
        req.price              = 0.0;
        double ask             = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        req.sl                 = QM_StopATRFromValue(_Symbol, QM_BUY, ask, g_atr_last, strategy_atr_stop_mult);
        req.tp                 = 0.0;
        req.reason             = "Donchian20 long breakout";
        req.symbol_slot        = qm_magic_slot_offset;
        req.expiration_seconds = 0;
        return true;
    }

    // ---- Short entry: last D1 close broke below 20-day prior low ----
    if(g_close_last < g_donchian_entry_low)
    {
        req.type               = QM_SELL;
        req.price              = 0.0;
        double bid             = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        req.sl                 = QM_StopATRFromValue(_Symbol, QM_SELL, bid, g_atr_last, strategy_atr_stop_mult);
        req.tp                 = 0.0;
        req.reason             = "Donchian20 short breakout";
        req.symbol_slot        = qm_magic_slot_offset;
        req.expiration_seconds = 0;
        return true;
    }

    return false;
}

// =============================================================================
// Trade Management — 2N hard stop is set at entry; no trailing in baseline
// =============================================================================

void Strategy_ManageOpenPosition()
{
}

// =============================================================================
// Trade Close — Donchian exit is handled in Strategy_EntrySignal
// =============================================================================

bool Strategy_ExitSignal()
{
    return false;
}

// =============================================================================
// News Filter Hook
// =============================================================================

bool Strategy_NewsFilterHook(const datetime broker_time)
{
    return false;
}

// =============================================================================
// Framework wiring — do NOT edit below this line
// =============================================================================

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

    QM_LogEvent(QM_INFO, "INIT_OK", "{}");
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
    QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
    QM_FrameworkShutdown();
}

void OnTick()
{
    if(!QM_KillSwitchCheck())
        return;

    const datetime broker_now = TimeCurrent();
    if(Strategy_NewsFilterHook(broker_now))
        return;
    bool news_allows = true;
    if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
        news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
    else
        news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
    if(!news_allows)
        return;
    if(QM_FrameworkHandleFridayClose())
        return;

    if(Strategy_NoTradeFilter())
        return;

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

    if(!QM_IsNewBar())
        return;

    QM_EquityStreamOnNewBar();

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
