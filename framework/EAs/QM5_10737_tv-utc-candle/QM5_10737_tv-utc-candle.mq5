#property strict
#property version   "5.0"
#property description "QM5_10737 TradingView UTC Candle Breakout (timed-range breakout)"

#include <QM/QM_Common.mqh>
// QM_DSTAware.mqh (QM_BrokerToUTC / QM_UTCToBroker) is pulled in transitively
// via QM_Common.mqh; the include guard makes a direct include redundant.

// =============================================================================
// QuantMechanica V5 EA — QM5_10737 tv-utc-candle
// -----------------------------------------------------------------------------
// Source: TradingView `Candle Breakout Strategy` (hashem-trader), card
//   artifacts/cards_approved/QM5_10737_tv-utc-candle.md (g0_status: APPROVED).
//
// Mechanic (M15):
//   - At a configured TargetHour:TargetMinute *UTC*, record that M15 candle's
//     high and low (the "range"). The UTC target is converted to BROKER time
//     (DST-aware) so the correct M15 bar is captured in the .DWX tester.
//   - Range stays active after the candle closes until an entry fires or the
//     session-end time is reached.
//   - Long  : a later CONFIRMED close (shift-1 closed bar) above the range high.
//   - Short : a later CONFIRMED close (shift-1 closed bar) below the range low.
//   - After one entry, the day's range is deactivated until the next target time.
//   - SL = opposite range boundary. TP = entry +/- initial-risk * RiskReward.
//   - Skip if range width < broker min stop distance OR > 2.5 * ATR(14).
//   - Optional time stop: close any open position at session-end broker time.
//   - One position per symbol/magic (framework single-entry path sizes lots).
//
// Only the five Strategy_* hooks + Strategy inputs are EA-specific; all OnTick /
// lifecycle wiring below the corset line is framework boilerplate.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10737;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
// Target range-candle time, specified in UTC and converted to broker time
// (DST-aware) at run time. Card baselines per symbol (set via setfile):
//   EURUSD/GBPUSD 07:00 UTC (London), NDX/WS30 13:30 UTC (US cash open),
//   XAUUSD 12:30 UTC (COMEX/NY overlap). Default = London 07:00.
input int    target_hour_utc            = 7;     // UTC hour of the range candle
input int    target_minute_utc          = 0;     // UTC minute of the range candle (M15 boundary)
input double RiskReward                  = 2.0;   // TP = entry +/- risk * RR (card baseline 2.0)
input int    atr_period                  = 14;    // ATR(14) for the max-width filter
input double max_range_atr_mult          = 2.5;   // skip if range width > this * ATR(14)
input bool   use_session_time_stop       = true;  // close at session-end if neither SL nor TP fired
input int    session_end_hour_utc        = 21;    // session-end (UTC) for the optional time stop
input int    session_end_minute_utc      = 0;

// -----------------------------------------------------------------------------
// Cached per-day range state (advanced once per closed M15 bar).
// All times below are BROKER time (what iTime returns in the tester).
// -----------------------------------------------------------------------------
bool     g_range_recorded   = false;  // today's target candle captured?
bool     g_range_active     = false;  // range armed for breakout (not yet consumed)
double   g_range_high       = 0.0;
double   g_range_low        = 0.0;
datetime g_range_day        = 0;      // broker-date (00:00) the active range belongs to

// Returns the broker-time datetime of the target range candle's OPEN for the
// broker day that `bar_open_broker` falls on. UTC target is converted DST-aware.
datetime TargetCandleBrokerOpen(const datetime bar_open_broker)
  {
   // UTC instant of the target time on the same UTC day as this bar.
   datetime bar_utc = QM_BrokerToUTC(bar_open_broker);
   MqlDateTime ut;
   ZeroMemory(ut);
   TimeToStruct(bar_utc, ut);
   ut.hour = target_hour_utc;
   ut.min  = target_minute_utc;
   ut.sec  = 0;
   datetime target_utc = StructToTime(ut);
   return QM_UTCToBroker(target_utc);
  }

// Broker-time instant of session end for the UTC day of `bar_open_broker`.
datetime SessionEndBrokerTime(const datetime bar_open_broker)
  {
   datetime bar_utc = QM_BrokerToUTC(bar_open_broker);
   MqlDateTime ut;
   ZeroMemory(ut);
   TimeToStruct(bar_utc, ut);
   ut.hour = session_end_hour_utc;
   ut.min  = session_end_minute_utc;
   ut.sec  = 0;
   datetime end_utc = StructToTime(ut);
   return QM_UTCToBroker(end_utc);
  }

// Broker-date floor (00:00) of a broker datetime.
datetime BrokerDateFloor(const datetime t)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(t, dt);
   dt.hour = 0;
   dt.min  = 0;
   dt.sec  = 0;
   return StructToTime(dt);
  }

// Advance cached range state. Called ONCE per closed M15 bar (after QM_IsNewBar).
// Reads the just-closed bar at shift 1 — closed-bar reads only.
void AdvanceRange_OnNewBar()
  {
   // perf-allowed: fixed-shift closed-bar reads for bespoke session-range logic.
   const datetime bar_open = iTime(_Symbol, _Period, 1);   // open time of last closed bar
   if(bar_open <= 0)
      return;

   const datetime today_floor = BrokerDateFloor(bar_open);

   // New broker day -> reset the day's range bookkeeping.
   if(g_range_day != today_floor)
     {
      g_range_day      = today_floor;
      g_range_recorded = false;
      g_range_active   = false;
      g_range_high     = 0.0;
      g_range_low      = 0.0;
     }

   // Is the just-closed bar the target range candle for this broker day?
   const datetime target_open = TargetCandleBrokerOpen(bar_open);
   if(!g_range_recorded && bar_open == target_open)
     {
      g_range_high     = iHigh(_Symbol, _Period, 1);
      g_range_low      = iLow(_Symbol, _Period, 1);
      g_range_recorded = true;
      g_range_active   = (g_range_high > g_range_low);
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// O(1) per-tick block check. Only allow trading once the day's range is armed.
bool Strategy_NoTradeFilter()
  {
   if(!g_range_active)
      return true;   // no armed range yet -> block
   return false;
  }

// Fire a NEW entry on a confirmed close beyond the recorded range. Caller
// guarantees QM_IsNewBar()==true. SL = opposite boundary, TP = RR multiple.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(!g_range_active)
      return false;

   // Width filters: skip if too narrow (< broker min stop distance) or too wide.
   const double width = g_range_high - g_range_low;
   if(width <= 0.0)
      return false;

   const long   stops_level_pts = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double point           = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double min_stop_dist    = (stops_level_pts > 0 && point > 0.0)
                                   ? (double)stops_level_pts * point : 0.0;
   if(min_stop_dist > 0.0 && width < min_stop_dist)
      return false;

   const double atr = QM_ATR(_Symbol, _Period, atr_period, 1);
   if(atr > 0.0 && width > max_range_atr_mult * atr)
      return false;

   // Confirmed close of the last closed bar (shift 1).
   const double close_confirm = iClose(_Symbol, _Period, 1);
   if(close_confirm <= 0.0)
      return false;

   if(close_confirm > g_range_high)
     {
      req.type   = QM_BUY;
      req.price  = 0.0;                 // market fill at send
      req.sl     = QM_StopRulesNormalizePrice(_Symbol, g_range_low);
      req.tp     = QM_TakeRR(_Symbol, QM_BUY, g_range_high, g_range_low, RiskReward);
      req.reason = "tv_utc_candle_long_breakout";
      g_range_active = false;          // consume the day's range after one entry
      return true;
     }

   if(close_confirm < g_range_low)
     {
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = QM_StopRulesNormalizePrice(_Symbol, g_range_high);
      req.tp     = QM_TakeRR(_Symbol, QM_SELL, g_range_low, g_range_high, RiskReward);
      req.reason = "tv_utc_candle_short_breakout";
      g_range_active = false;
      return true;
     }

   return false;
  }

// No active trade management beyond the fixed SL/TP set at entry.
void Strategy_ManageOpenPosition()
  {
  }

// Optional time stop: close the open position at/after session-end broker time.
bool Strategy_ExitSignal()
  {
   if(!use_session_time_stop)
      return false;

   const datetime bar_open = iTime(_Symbol, _Period, 0);  // current (forming) bar open
   if(bar_open <= 0)
      return false;

   const datetime session_end = SessionEndBrokerTime(bar_open);
   return (bar_open >= session_end);
  }

// Defer to the central news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
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
                        qm_news_mode_legacy,           // legacy back-compat
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,                            // pause-before (legacy hint)
                        30,                            // pause-after (legacy hint)
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,              // FW1 Axis A
                        qm_news_compliance))           // FW1 Axis B
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

   // Per-closed-bar: advance cached range state FIRST (single-consume new-bar).
   const bool is_new_bar = QM_IsNewBar();
   if(is_new_bar)
      AdvanceRange_OnNewBar();

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: trade management (no-op for this EA).
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (session time stop). Separate from SL/TP.
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
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
        }
     }

   if(!is_new_bar)
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
