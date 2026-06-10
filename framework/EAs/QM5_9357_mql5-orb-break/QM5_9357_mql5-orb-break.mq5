#property strict
#property version   "5.0"
#property description "QM5_9357 - MQL5 Opening Range Breakout (ORB)"

#include <QM/QM_Common.mqh>
#include <QM/QM_Signals.mqh>

// =============================================================================
// QM5_9357 - MQL5 Opening Range Breakout (ORB)
// -----------------------------------------------------------------------------
// Source: Israel Pelumi Abioye, "Introduction to MQL5 (Part 23): Automating
//   Opening Range Breakout Strategy", MQL5 Articles, 2025-10-14
//   mql5.com/en/articles/19886  (internal reference - no external API calls)
//
// Mechanic (card verbatim):
//   - At strategy_session_start_hour:strategy_session_start_min (server time),
//     record the high and low of the first 15-minute candle (opening range).
//   - After that candle closes, trade on M5.
//   - Long  when a bullish M5 candle closes above the OR high.
//   - Short when a bearish M5 candle closes below the OR low.
//   - Only one signal per day; one active position per magic.
//   - TP = 2R (range width) from entry; SL = opposite side of range.
//   - Close any open position at session end.
//   - M5 bars only (closed candles).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9357;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
// Broker-time hour and minute for session open (default 09:30 as per card)
input int    strategy_session_start_hour  = 9;
input int    strategy_session_start_min   = 30;
// Session end: any open position is closed at or after this hour
input int    strategy_session_end_hour    = 17;
input int    strategy_session_end_min     = 30;
// Opening range: number of minutes that define the opening range
// (card specifies 15 minutes = 3 × M5 bars)
input int    strategy_or_minutes          = 15;
// Risk-to-reward ratio for TP (card default 2R)
input double strategy_rr_ratio            = 2.0;

// =============================================================================
// State - one record per day, reset at each new trading day
// =============================================================================
static datetime  s_last_bar_time       = 0;     // last processed M5 bar time
static datetime  s_day_date            = 0;      // date key for current day state
static bool      s_or_captured        = false;   // opening range captured this day
static bool      s_signal_fired       = false;   // first signal has fired today
static double    s_or_high            = 0.0;
static double    s_or_low             = 0.0;
// Time at which the opening range candle ENDS (= session_start + or_minutes)
static datetime  s_or_end_time        = 0;

// =============================================================================
// Helpers
// =============================================================================

// Returns the broker-time datetime for a given date at hour:min
datetime ORB_SessionDT(const MqlDateTime &day, const int h, const int m)
{
   return StringToTime(StringFormat("%04d.%02d.%02d %02d:%02d:00",
                                    day.year, day.mon, day.day, h, m));
}

// Is there currently an open position for this EA's magic?
bool ORB_HasOpenPosition()
{
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      return true;
   }
   return false;
}

// Close the first open position for this EA's magic
void ORB_CloseSessionPosition(const string reason)
{
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      return;
   }
}

// Reset all intra-day state for a new trading day
void ORB_ResetDay(const MqlDateTime &d)
{
   s_day_date      = StructToTime(d);
   s_or_captured   = false;
   s_signal_fired  = false;
   s_or_high       = 0.0;
   s_or_low        = 0.0;
   s_or_end_time   = ORB_SessionDT(d,
                       strategy_session_start_hour,
                       strategy_session_start_min) + strategy_or_minutes * 60;
}

// =============================================================================
// Strategy hooks
// =============================================================================

bool Strategy_NoTradeFilter()
{
   // Block entry outside the session window (session_start..session_end).
   // Management (session-end close) is handled in Strategy_ManageOpenPosition.
   const datetime broker_now = TimeCurrent();
   MqlDateTime t; TimeToStruct(broker_now, t);

   // Build today's session open/close datetimes
   const datetime session_open  = ORB_SessionDT(t, strategy_session_start_hour,
                                                    strategy_session_start_min);
   const datetime session_close = ORB_SessionDT(t, strategy_session_end_hour,
                                                    strategy_session_end_min);

   // Block if outside the session window for new entries
   if(broker_now < session_open || broker_now >= session_close)
      return true;   // blocked

   // Block if we already fired a signal today (one trade per day)
   if(s_signal_fired)
      return true;

   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   const datetime broker_now = TimeCurrent();
   MqlDateTime t; TimeToStruct(broker_now, t);

   // Detect a new calendar day - reset state
   MqlDateTime day_key = t; day_key.hour = 0; day_key.min = 0; day_key.sec = 0;
   const datetime today = StructToTime(day_key);
   if(today != s_day_date)
      ORB_ResetDay(day_key);

   // -------------------------------------------------------------------------
   // Phase 1: Capture opening range
   // The opening range = [session_start, session_start + or_minutes).
   // We capture the OR when we see the first M5 bar that CLOSES AT or AFTER
   // s_or_end_time (i.e. the 15-minute range has elapsed, bars are closed).
   // -------------------------------------------------------------------------
   if(!s_or_captured)
   {
      // Current closed bar opens at iTime(_Symbol, PERIOD_M5, 1)
      const datetime bar1_open = iTime(_Symbol, PERIOD_M5, 1); // perf-allowed: OR range scan - QM_Indicators has no multi-bar range primitive
      if(bar1_open < s_or_end_time)
         return false;   // OR still forming

      // Scan all M5 bars that fall within the opening range window
      const datetime session_open = ORB_SessionDT(day_key,
                                      strategy_session_start_hour,
                                      strategy_session_start_min);

      double or_high = -DBL_MAX;
      double or_low  =  DBL_MAX;
      bool   found   = false;

      // Scan back up to 200 M5 bars to find those in the OR window
      for(int i = 1; i <= 200; ++i)
      {
         const datetime bt = iTime(_Symbol, PERIOD_M5, i); // perf-allowed: OR range scan - bespoke structural logic
         if(bt < session_open) break;           // before session start
         if(bt >= s_or_end_time) continue;      // after OR end (skip newer bars)

         const double h = iHigh(_Symbol, PERIOD_M5, i); // perf-allowed: OR range scan
         const double l = iLow(_Symbol, PERIOD_M5, i);  // perf-allowed: OR range scan
         if(h > or_high) or_high = h;
         if(l < or_low)  or_low  = l;
         found = true;
      }

      if(!found || or_high <= or_low)
         return false;   // no valid OR bars yet

      s_or_high    = or_high;
      s_or_low     = or_low;
      s_or_captured = true;
   }

   // -------------------------------------------------------------------------
   // Phase 2: Entry signal - closed M5 bar breaks above OR high (long)
   //          or below OR low (short).
   // -------------------------------------------------------------------------
   // Guard: only one open position allowed per magic
   if(ORB_HasOpenPosition())
      return false;

   const double close1 = iClose(_Symbol, PERIOD_M5, 1); // perf-allowed: entry bar close - gated by QM_IsNewBar; single read per bar
   const double open1  = iOpen (_Symbol, PERIOD_M5, 1); // perf-allowed: entry bar open - gated by QM_IsNewBar; single read per bar

   const bool long_break  = (close1 > s_or_high) && (close1 > open1);   // bullish candle
   const bool short_break = (close1 < s_or_low)  && (close1 < open1);   // bearish candle

   if(!long_break && !short_break)
      return false;

   // Build entry request
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   if(long_break)
   {
      req.type         = QM_BUY;
      req.price        = 0.0;               // market order
      req.sl           = s_or_low;          // SL = opening range low
      const double range = s_or_high - s_or_low;
      req.tp           = s_or_high + strategy_rr_ratio * range;   // 2R target
      req.reason       = "ORB_LONG";
      req.symbol_slot  = qm_magic_slot_offset;
   }
   else // short_break
   {
      req.type         = QM_SELL;
      req.price        = 0.0;               // market order
      req.sl           = s_or_high;         // SL = opening range high
      const double range = s_or_high - s_or_low;
      req.tp           = s_or_low - strategy_rr_ratio * range;    // 2R target
      req.reason       = "ORB_SHORT";
      req.symbol_slot  = qm_magic_slot_offset;
   }

   s_signal_fired = true;
   return true;
}

void Strategy_ManageOpenPosition()
{
   // Close open position at or after session end
   if(!ORB_HasOpenPosition())
      return;

   const datetime broker_now = TimeCurrent();
   MqlDateTime t; TimeToStruct(broker_now, t);
   MqlDateTime day_key = t; day_key.hour = 0; day_key.min = 0; day_key.sec = 0;
   const datetime session_close = ORB_SessionDT(day_key, strategy_session_end_hour,
                                                          strategy_session_end_min);
   if(broker_now >= session_close)
      ORB_CloseSessionPosition("SESSION_END");
}

bool Strategy_ExitSignal()
{
   // All exits are handled via SL/TP or Strategy_ManageOpenPosition (session end).
   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time)
{
   return false; // defer to QM_NewsAllowsTrade
}

// =============================================================================
// Framework wiring - do NOT edit below this line
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

   // Per-tick: session-end close
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
