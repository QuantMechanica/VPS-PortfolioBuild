#property strict
#property version   "5.0"
#property description "QM5_11450 London Breakfast Asian-range breakout (M15)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA - QM5_11450 london-breakfast-asian-range-m15
// -----------------------------------------------------------------------------
// Card: D:/QM/strategy_farm/artifacts/cards_approved/
//       QM5_11450_london-breakfast-asian-range-m15.md
// Source: London Free Breakfast, anonymous community strategy.
//
// The card states all session windows in GMT. MT5 .DWX bar timestamps are broker
// time (DXZ NY-close GMT+2/+3), so closed-bar timestamps are converted to UTC via
// QM_BrokerToUTC before all session tests.
//
// Asian range: 00:00 <= UTC bar-open < 08:00, built one closed M15 bar at a time.
// Entry: first valid London breakout close among the bars opening 08:00, 08:15,
// and 08:30 UTC. Close above Asian high buys; close below Asian low sells.
// Failed first intrabar break without an outside close ends the day; no flip.
// Exit: fixed 40-pip TP, SL back inside the range by 10 pips capped at 30 pips,
// move-to-breakeven+10 after 20 pips profit, and time stop at 10:00 UTC.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11450;
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
input int    strategy_asian_start_hour    = 0;     // GMT/UTC Asian range start, inclusive
input int    strategy_asian_start_minute  = 0;     // GMT/UTC Asian range start minute
input int    strategy_asian_end_hour      = 8;     // GMT/UTC Asian range end, exclusive
input int    strategy_asian_end_minute    = 0;     // GMT/UTC Asian range end minute
input int    strategy_london_open_hour    = 8;     // GMT/UTC first breakout bar open
input int    strategy_london_open_minute  = 0;     // GMT/UTC first breakout bar minute
input int    strategy_entry_bars_to_check = 3;     // check 08:00, 08:15, 08:30 M15 bars
input int    strategy_time_stop_hour      = 10;    // GMT/UTC close time if TP not reached
input int    strategy_time_stop_minute    = 0;     // GMT/UTC close minute if TP not reached
input int    strategy_range_min_pips      = 15;    // skip too-narrow Asian ranges
input int    strategy_range_max_pips      = 80;    // skip too-wide Asian ranges
input int    strategy_sl_inside_pips      = 10;    // SL back inside Asian range
input int    strategy_sl_cap_pips         = 30;    // P2 max stop distance
input int    strategy_tp_pips             = 40;    // primary target from card
input int    strategy_trail_trigger_pips  = 20;    // activate BE+ move
input int    strategy_trail_buffer_pips   = 10;    // BE+10 pips after trigger
input int    strategy_spread_cap_pips     = 15;    // fail-open on zero, block only genuinely wide

#define LB_PHASE_IDLE   0
#define LB_PHASE_ASIAN  1
#define LB_PHASE_WAIT   2
#define LB_PHASE_DONE   3

int      g_lb_phase       = LB_PHASE_IDLE;
int      g_lb_session_day = -1;
double   g_lb_asian_high  = 0.0;
double   g_lb_asian_low   = 0.0;
bool     g_lb_asian_seen  = false;
int      g_lb_signal_dir  = 0;       // +1 buy, -1 sell, 0 none
datetime g_lb_signal_bar  = 0;

int LB_ConfigMinuteOfDay(const int hour, const int minute)
  {
   const int h = MathMax(0, MathMin(23, hour));
   const int m = MathMax(0, MathMin(59, minute));
   return h * 60 + m;
  }

int LB_UtcMinuteOfDay(const datetime broker_bar_open)
  {
   const datetime utc = QM_BrokerToUTC(broker_bar_open);
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(utc, dt);
   return dt.hour * 60 + dt.min;
  }

int LB_UtcDayOfYear(const datetime broker_bar_open)
  {
   const datetime utc = QM_BrokerToUTC(broker_bar_open);
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(utc, dt);
   return dt.day_of_year;
  }

void LB_ResetForDay(const int day_of_year)
  {
   g_lb_phase       = LB_PHASE_ASIAN;
   g_lb_session_day = day_of_year;
   g_lb_asian_high  = 0.0;
   g_lb_asian_low   = 0.0;
   g_lb_asian_seen  = false;
   g_lb_signal_dir  = 0;
   g_lb_signal_bar  = 0;
  }

bool LB_RangeAllowed()
  {
   const double range = g_lb_asian_high - g_lb_asian_low;
   if(range <= 0.0)
      return false;

   const double min_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_range_min_pips);
   const double max_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_range_max_pips);
   if(min_dist > 0.0 && range < min_dist)
      return false;
   if(max_dist > 0.0 && range > max_dist)
      return false;
   return true;
  }

bool LB_SpreadTooWide()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;
   if(ask <= bid)
      return false; // .DWX tester can model zero spread; never fail-closed on it.

   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   return (cap > 0.0 && (ask - bid) > cap);
  }

void LB_AdvanceState_OnNewBar()
  {
   g_lb_signal_dir = 0;
   g_lb_signal_bar = 0;

   const datetime bar_open = iTime(_Symbol, _Period, 1); // perf-allowed: closed-bar timestamp after framework QM_IsNewBar gate
   if(bar_open <= 0)
      return;

   const int minute = LB_UtcMinuteOfDay(bar_open);
   const int doy    = LB_UtcDayOfYear(bar_open);

   const int asian_start = LB_ConfigMinuteOfDay(strategy_asian_start_hour, strategy_asian_start_minute);
   const int asian_end   = LB_ConfigMinuteOfDay(strategy_asian_end_hour, strategy_asian_end_minute);
   const int london_open = LB_ConfigMinuteOfDay(strategy_london_open_hour, strategy_london_open_minute);
   const int entry_end   = london_open + MathMax(1, strategy_entry_bars_to_check) * PeriodSeconds(PERIOD_M15) / 60;
   const int abandon     = london_open + 60;

   const bool in_asian = (minute >= asian_start && minute < asian_end);
   if(in_asian && doy != g_lb_session_day)
      LB_ResetForDay(doy);

   const double h = iHigh(_Symbol, _Period, 1);  // perf-allowed: one closed M15 bar folded into cached Asian range
   const double l = iLow(_Symbol, _Period, 1);   // perf-allowed: one closed M15 bar folded into cached Asian range
   const double c = iClose(_Symbol, _Period, 1); // perf-allowed: one closed M15 breakout close
   if(h <= 0.0 || l <= 0.0 || c <= 0.0)
      return;

   if(g_lb_phase == LB_PHASE_ASIAN && in_asian && doy == g_lb_session_day)
     {
      if(!g_lb_asian_seen)
        {
         g_lb_asian_high = h;
         g_lb_asian_low  = l;
         g_lb_asian_seen = true;
        }
      else
        {
         if(h > g_lb_asian_high) g_lb_asian_high = h;
         if(l < g_lb_asian_low)  g_lb_asian_low  = l;
        }
      return;
     }

   if(doy != g_lb_session_day || !g_lb_asian_seen)
      return;

   if(g_lb_phase == LB_PHASE_ASIAN && minute >= asian_end)
      g_lb_phase = LB_PHASE_WAIT;

   if(g_lb_phase != LB_PHASE_WAIT)
      return;

   if(minute >= abandon)
     {
      g_lb_phase = LB_PHASE_DONE;
      return;
     }

   if(minute < london_open || minute >= entry_end)
      return;

   if(!LB_RangeAllowed())
     {
      g_lb_phase = LB_PHASE_DONE;
      return;
     }

   const bool broke_high = (h > g_lb_asian_high);
   const bool broke_low  = (l < g_lb_asian_low);

   if(c > g_lb_asian_high && c > g_lb_asian_low)
     {
      g_lb_signal_dir = +1;
      g_lb_signal_bar = bar_open;
      g_lb_phase = LB_PHASE_DONE;
      return;
     }

   if(c < g_lb_asian_low && c < g_lb_asian_high)
     {
      g_lb_signal_dir = -1;
      g_lb_signal_bar = bar_open;
      g_lb_phase = LB_PHASE_DONE;
      return;
     }

   if(broke_high || broke_low)
      g_lb_phase = LB_PHASE_DONE;
  }

bool Strategy_NoTradeFilter()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const int minute = LB_UtcMinuteOfDay(TimeCurrent());
   const int asian_start = LB_ConfigMinuteOfDay(strategy_asian_start_hour, strategy_asian_start_minute);
   const int time_stop = LB_ConfigMinuteOfDay(strategy_time_stop_hour, strategy_time_stop_minute);

   if(minute >= asian_start && minute < time_stop)
      return false;

   return true;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   LB_AdvanceState_OnNewBar();

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;
   if(g_lb_signal_dir == 0 || g_lb_signal_bar <= 0)
      return false;
   if(LB_SpreadTooWide())
      return false;

   const bool is_buy = (g_lb_signal_dir > 0);
   const QM_OrderType side = is_buy ? QM_BUY : QM_SELL;
   const double entry = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                               : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double inside_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_inside_pips);
   const double cap_dist    = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
   const double tp_dist     = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_tp_pips);
   if(inside_dist <= 0.0 || cap_dist <= 0.0 || tp_dist <= 0.0)
      return false;

   double sl = 0.0;
   if(is_buy)
     {
      sl = g_lb_asian_high - inside_dist;
      if((entry - sl) > cap_dist)
         sl = entry - cap_dist;
      if(sl <= 0.0 || sl >= entry)
         return false;
     }
   else
     {
      sl = g_lb_asian_low + inside_dist;
      if((sl - entry) > cap_dist)
         sl = entry + cap_dist;
      if(sl <= entry)
         return false;
     }

   req.type = side;
   req.price = 0.0;
   req.sl = QM_TM_NormalizePrice(_Symbol, sl);
   req.tp = QM_TakeFixedPips(_Symbol, side, entry, strategy_tp_pips);
   req.reason = is_buy ? "london_breakfast_buy" : "london_breakfast_sell";
   return (req.sl > 0.0 && req.tp > 0.0);
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      QM_TM_MoveToBreakEven(ticket, strategy_trail_trigger_pips, strategy_trail_buffer_pips);
     }
  }

bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const int minute = LB_UtcMinuteOfDay(TimeCurrent());
   const int time_stop = LB_ConfigMinuteOfDay(strategy_time_stop_hour, strategy_time_stop_minute);
   return (minute >= time_stop && minute < 20 * 60);
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line unless the framework contract changes.
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
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
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
