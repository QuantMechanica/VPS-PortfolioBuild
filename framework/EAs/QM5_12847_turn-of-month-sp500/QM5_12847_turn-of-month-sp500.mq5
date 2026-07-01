#property strict
#property version   "5.0"
#property description "QM5_12847 Turn-of-Month SP500 calendar seasonal"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12847 — Turn-of-Month / Ultimo (SP500 index seasonal)
// Entry at the close of the Nth-last trading day of each calendar month.
// Exit at the close of the Mth trading day of the following calendar month.
// Regime gate: close[1] > SMA(regime_sma_period) on D1.
// Long-only, one trade/month, single-position-per-magic, closed-bar D1.
// Trading-day counting uses actual D1 bar sequence (skips weekends/holidays).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 12847;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    entry_td_from_end  = 5;     // Nth-last trading day of month (sweep 4/5/6)
input int    exit_td_of_next    = 3;     // Mth trading day of next month (sweep 2/3/4)
input int    regime_sma_period  = 200;   // Bull-regime D1 SMA period
input bool   use_regime_filter  = true;  // Enable 200-SMA bull-regime gate
input int    sl_atr_period      = 14;    // ATR period for safety-stop (lot sizing only)
input double sl_atr_mult        = 3.0;   // ATR multiplier for safety-stop (lot sizing only)

// File-scope calendar arrays (populated once at OnInit)
datetime g_entry_dates[];
datetime g_exit_dates[];
bool     g_should_exit = false;

// -----------------------------------------------------------------------------
// Calendar helpers
// -----------------------------------------------------------------------------

bool IsInDateArray(const datetime &arr[], const datetime val)
{
    int n = ArraySize(arr);
    for(int i = 0; i < n; i++)
        if(arr[i] == val) return true;
    return false;
}

// Build entry-date and exit-date arrays from the full D1 bar history.
// Uses actual bar sequence so weekends/holidays are naturally excluded.
// Called once from OnInit after QM_FrameworkInit succeeds.
void PrecomputeCalendar()
{
    ArrayResize(g_entry_dates, 0);
    ArrayResize(g_exit_dates, 0);

    int total = Bars(_Symbol, PERIOD_D1); // perf-allowed
    if(total < 30) return;

    // Closed bars: shifts 1..(total-1). Collect oldest-first (init-time only).
    int n_closed = total - 1;
    datetime all_times[];
    ArrayResize(all_times, n_closed);

    for(int k = 0; k < n_closed; k++)
        all_times[k] = iTime(_Symbol, PERIOD_D1, total - 1 - k); // perf-allowed

    // Process one calendar month at a time (oldest first)
    int i = 0;
    while(i < n_closed)
    {
        MqlDateTime sd;
        TimeToStruct(all_times[i], sd);
        int cur_ym = sd.year * 100 + sd.mon;

        // Find end of this month's bar block
        int j = i;
        while(j < n_closed)
        {
            MqlDateTime sj;
            TimeToStruct(all_times[j], sj);
            if(sj.year * 100 + sj.mon != cur_ym) break;
            j++;
        }
        // all_times[i..j-1] = trading days in cur_ym (oldest first), count = j-i

        int n_bars = j - i;

        // Entry: Nth-last trading day of this month
        if(n_bars >= entry_td_from_end)
        {
            int sz = ArraySize(g_entry_dates);
            ArrayResize(g_entry_dates, sz + 1);
            g_entry_dates[sz] = all_times[j - entry_td_from_end];
        }

        // Exit: Mth trading day of NEXT month
        if(j + exit_td_of_next - 1 < n_closed)
        {
            MqlDateTime snext;
            TimeToStruct(all_times[j], snext);
            int next_ym = snext.year * 100 + snext.mon;

            MqlDateTime sexit;
            TimeToStruct(all_times[j + exit_td_of_next - 1], sexit);

            // Verify the exit bar is still in the same next month (guards short month edge)
            if(sexit.year * 100 + sexit.mon == next_ym)
            {
                int sz = ArraySize(g_exit_dates);
                ArrayResize(g_exit_dates, sz + 1);
                g_exit_dates[sz] = all_times[j + exit_td_of_next - 1];
            }
        }

        i = j;
    }

    QM_LogEvent(QM_INFO, "CALENDAR_PRECOMPUTED",
                StringFormat("{\"entry_count\":%d,\"exit_count\":%d}",
                             ArraySize(g_entry_dates), ArraySize(g_exit_dates)));
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No additional trade filter beyond regime (applied in EntrySignal)
bool Strategy_NoTradeFilter()
{
    return false;
}

// Called once per closed D1 bar (after QM_IsNewBar gate in OnTick).
// Handles both exit scheduling for open positions and new entry signals.
bool Strategy_EntrySignal(QM_EntryRequest &req)
{
    datetime bar1_time = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed

    // If we hold a position, check whether today is the scheduled exit bar
    if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
    {
        if(IsInDateArray(g_exit_dates, bar1_time))
            g_should_exit = true;
        return false;
    }

    // No open position: check entry calendar
    if(!IsInDateArray(g_entry_dates, bar1_time))
        return false;

    // Bull-regime gate: close[1] > daily SMA (200 SMA per card)
    if(use_regime_filter)
    {
        const double sma  = QM_SMA(_Symbol, PERIOD_D1, regime_sma_period, 1);
        const double cls1 = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: regime read
        if(cls1 <= 0.0 || sma <= 0.0 || cls1 <= sma)
            return false;
    }

    // Build entry: long at market, ATR safety stop for lot sizing, time-based exit
    req.type              = QM_BUY;
    req.price             = 0.0;  // framework fills market ask
    req.sl                = QM_StopATR(_Symbol, QM_BUY,
                                        SymbolInfoDouble(_Symbol, SYMBOL_BID),
                                        sl_atr_period, sl_atr_mult);
    req.tp                = 0.0;  // no hard TP; exit is time-based via g_should_exit
    req.reason            = "ToM_Entry";
    req.symbol_slot       = qm_magic_slot_offset;
    req.expiration_seconds = 0;

    return true;
}

// No intra-hold management; hold is short (~8 TD) and exits at fixed calendar date
void Strategy_ManageOpenPosition()
{
}

// g_should_exit is set inside Strategy_EntrySignal when the exit bar is detected.
// ExitSignal fires on the next tick after EntrySignal sets the flag.
bool Strategy_ExitSignal()
{
    if(!g_should_exit) return false;
    if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) == 0)
    {
        g_should_exit = false;
        return false;
    }
    return true;
}

bool Strategy_NewsFilterHook(const datetime broker_time)
{
    return false;  // defer to framework 2-axis news gate
}

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------

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

    PrecomputeCalendar();

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
            if(!PositionSelectByTicket(ticket))
                continue;
            if(PositionGetInteger(POSITION_MAGIC) != magic)
                continue;
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
