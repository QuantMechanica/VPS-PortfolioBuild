#property strict
#property version   "5.0"
#property description "QM5_10079 GitHub Victor Algo Ichimoku Kumo Breakout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10079;
input int    qm_magic_slot_offset       = 0;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsMode qm_news_mode          = QM_NEWS_OFF;
input int    qm_news_pause_before_minutes = 30;
input int    qm_news_pause_after_minutes  = 30;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_tenkan_period     = 9;
input int    strategy_kijun_period      = 26;
input int    strategy_senkou_b_period   = 52;
input double strategy_stop_percent      = 3.0;

// -----------------------------------------------------------------------------
// Strategy hooks - implement these against the card mechanically.
// -----------------------------------------------------------------------------

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_tenkan_period <= 0 || strategy_kijun_period <= 0 ||
      strategy_senkou_b_period <= 0 || strategy_stop_percent <= 0.0)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   const datetime prior_bar_open = iTime(_Symbol, (ENUM_TIMEFRAMES)_Period, 1);
   const datetime current_bar_open = iTime(_Symbol, (ENUM_TIMEFRAMES)_Period, 0);
   if(prior_bar_open > 0 && current_bar_open > prior_bar_open &&
      HistorySelect(prior_bar_open, current_bar_open - 1))
     {
      const int deals = HistoryDealsTotal();
      for(int i = 0; i < deals; ++i)
        {
         const ulong deal_ticket = HistoryDealGetTicket(i);
         if(deal_ticket == 0)
            continue;
         if(HistoryDealGetString(deal_ticket, DEAL_SYMBOL) != _Symbol)
            continue;
         if((int)HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) != magic)
            continue;
         const ENUM_DEAL_ENTRY entry_type = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
         if(entry_type == DEAL_ENTRY_IN || entry_type == DEAL_ENTRY_INOUT)
            return false;
        }
     }

   double span_a[2];
   double span_b[2];
   const int shifts[2] = {1, 2};
   for(int sample = 0; sample < 2; ++sample)
     {
      const int origin_shift = shifts[sample] + strategy_kijun_period;

      double highest = -DBL_MAX;
      double lowest = DBL_MAX;
      for(int i = origin_shift; i < origin_shift + strategy_tenkan_period; ++i)
        {
         const double hi = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, i);
         const double lo = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, i);
         if(hi <= 0.0 || lo <= 0.0)
            return false;
         highest = MathMax(highest, hi);
         lowest = MathMin(lowest, lo);
        }
      const double tenkan = (highest + lowest) * 0.5;

      highest = -DBL_MAX;
      lowest = DBL_MAX;
      for(int i = origin_shift; i < origin_shift + strategy_kijun_period; ++i)
        {
         const double hi = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, i);
         const double lo = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, i);
         if(hi <= 0.0 || lo <= 0.0)
            return false;
         highest = MathMax(highest, hi);
         lowest = MathMin(lowest, lo);
        }
      const double kijun = (highest + lowest) * 0.5;

      highest = -DBL_MAX;
      lowest = DBL_MAX;
      for(int i = origin_shift; i < origin_shift + strategy_senkou_b_period; ++i)
        {
         const double hi = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, i);
         const double lo = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, i);
         if(hi <= 0.0 || lo <= 0.0)
            return false;
         highest = MathMax(highest, hi);
         lowest = MathMin(lowest, lo);
        }
      span_a[sample] = (tenkan + kijun) * 0.5;
      span_b[sample] = (highest + lowest) * 0.5;
     }

   const double low1 = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, 1);
   const double low2 = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, 2);
   const double high1 = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, 1);
   const double high2 = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, 2);
   if(low1 <= 0.0 || low2 <= 0.0 || high1 <= 0.0 || high2 <= 0.0)
      return false;

   const bool bullish_kumo = (span_a[0] > span_b[0] && span_a[1] > span_b[1]);
   const bool bearish_kumo = (span_a[0] < span_b[0] && span_a[1] < span_b[1]);
   const double upper_1 = MathMax(span_a[0], span_b[0]);
   const double upper_2 = MathMax(span_a[1], span_b[1]);
   const double lower_1 = MathMin(span_a[0], span_b[0]);
   const double lower_2 = MathMin(span_a[1], span_b[1]);

   QM_OrderType side = QM_BUY;
   string reason = "";
   if(bullish_kumo && low2 <= upper_2 && low1 > upper_1)
     {
      side = QM_BUY;
      reason = "KUMO_BREAKOUT_LONG";
     }
   else if(bearish_kumo && high2 >= lower_2 && high1 < lower_1)
     {
      side = QM_SELL;
      reason = "KUMO_BREAKOUT_SHORT";
     }
   else
      return false;

   const double entry = QM_EntryMarketPrice(side);
   if(entry <= 0.0)
      return false;

   const double stop_distance = entry * strategy_stop_percent / 100.0;
   if(stop_distance <= 0.0)
      return false;

   req.type = side;
   req.sl = (side == QM_BUY) ? entry - stop_distance : entry + stop_distance;
   req.reason = reason;
   return (req.sl > 0.0);
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Source strategy has no trailing, break-even, or partial-close rule.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   bool found_position = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      found_position = true;
      break;
     }
   if(!found_position)
      return false;

   if(strategy_tenkan_period <= 0 || strategy_kijun_period <= 0 ||
      strategy_senkou_b_period <= 0)
      return false;

   const int origin_shift = strategy_kijun_period;

   double highest = -DBL_MAX;
   double lowest = DBL_MAX;
   for(int i = origin_shift; i < origin_shift + strategy_tenkan_period; ++i)
     {
      const double hi = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, i);
      const double lo = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, i);
      if(hi <= 0.0 || lo <= 0.0)
         return false;
      highest = MathMax(highest, hi);
      lowest = MathMin(lowest, lo);
     }
   const double tenkan = (highest + lowest) * 0.5;

   highest = -DBL_MAX;
   lowest = DBL_MAX;
   for(int i = origin_shift; i < origin_shift + strategy_kijun_period; ++i)
     {
      const double hi = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, i);
      const double lo = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, i);
      if(hi <= 0.0 || lo <= 0.0)
         return false;
      highest = MathMax(highest, hi);
      lowest = MathMin(lowest, lo);
     }
   const double kijun = (highest + lowest) * 0.5;

   highest = -DBL_MAX;
   lowest = DBL_MAX;
   for(int i = origin_shift; i < origin_shift + strategy_senkou_b_period; ++i)
     {
      const double hi = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, i);
      const double lo = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, i);
      if(hi <= 0.0 || lo <= 0.0)
         return false;
      highest = MathMax(highest, hi);
      lowest = MathMin(lowest, lo);
     }

   const double span_a = (tenkan + kijun) * 0.5;
   const double span_b = (highest + lowest) * 0.5;
   const double opposite_for_long = MathMin(span_a, span_b);
   const double opposite_for_short = MathMax(span_a, span_b);
   const double current_low = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, 0);
   const double current_high = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, 0);
   if(current_low <= 0.0 || current_high <= 0.0)
      return false;

   if(position_type == POSITION_TYPE_BUY && current_low < opposite_for_long)
      return true;
   if(position_type == POSITION_TYPE_SELL && current_high > opposite_for_short)
      return true;

   return false;
  }

// News Filter Hook
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        qm_news_pause_before_minutes,
                        qm_news_pause_after_minutes,
                        qm_news_stale_max_hours,
                        qm_news_min_impact))
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
   if(!QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: trade management can adjust SL/TP on open positions.
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. time stop). Separate from SL/TP.
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

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes - EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   if(!QM_IsNewBar())
      return;

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

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
