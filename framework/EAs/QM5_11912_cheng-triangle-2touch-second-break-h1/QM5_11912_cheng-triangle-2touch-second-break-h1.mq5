#property strict
#property version   "5.0"
#property description "QM5_11912 Cheng Triangle Breakout 2-Touch (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_11912
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11912;
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
input int    strategy_zigzag_depth      = 8;
input int    strategy_zigzag_deviation  = 8;
input int    strategy_zigzag_backstep   = 3;
input int    strategy_triangle_min_bars = 30;
input int    strategy_triangle_max_bars = 200;
input double strategy_entry_buffer_pips = 10.0;
input double strategy_stop_buffer_pips  = 10.0;
input int    strategy_time_stop_bars    = 240;
input int    strategy_max_spread_points = 0;

int g_zigzag_handle = INVALID_HANDLE;

struct StrategyPivot
  {
   int    shift;
   double price;
  };

enum ENUM_TRIANGLE_KIND
  {
   TRIANGLE_KIND_NONE = 0,
   TRIANGLE_ASCENDING,
   TRIANGLE_DESCENDING
  };

enum ENUM_TRIANGLE_STATE {
   TRIANGLE_NONE = 0,
   TRIANGLE_FORMED,
   TRIANGLE_FIRST_BROKEN,
   TRIANGLE_REENTERED,
   TRIANGLE_SECOND_BROKEN
};

ENUM_TRIANGLE_STATE g_triangle_state = TRIANGLE_NONE;
ENUM_TRIANGLE_KIND  g_triangle_kind = TRIANGLE_KIND_NONE;
datetime g_triangle_detection_bar = 0;
double   g_triangle_upper_base = 0.0;
double   g_triangle_lower_base = 0.0;
double   g_triangle_upper_slope = 0.0;
double   g_triangle_lower_slope = 0.0;
double   g_triangle_height = 0.0;
int      g_bars_since_first_break = 0;
int      g_bars_since_reentry = 0;

const int STRATEGY_REENTRY_MAX_BARS = 10;
const int STRATEGY_PENDING_VALID_BARS = 50;

double Strategy_PipSize()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(point <= 0.0)
      return 0.0;
   return ((digits == 3 || digits == 5) ? point * 10.0 : point);
  }

bool Strategy_SpreadAllowsEntry()
  {
   if(strategy_max_spread_points <= 0)
      return true;
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0 || ask < bid)
      return false;
   return ((ask - bid) / point <= (double)strategy_max_spread_points);
  }

int Strategy_IndZigZag()
  {
   const int deviation_points = (int)MathRound(strategy_zigzag_deviation * Strategy_PipSize() / _Point);
   const string key = StringFormat("ZIGZAG|%s|%d|%d|%d|%d",
                                   _Symbol,
                                   (int)PERIOD_H1,
                                   strategy_zigzag_depth,
                                   deviation_points,
                                   strategy_zigzag_backstep);
   int handle = QM_IndicatorsLookup(key);
   if(handle != INVALID_HANDLE)
      return handle;
   handle = iCustom(_Symbol, PERIOD_H1, "Examples\\ZigZag", strategy_zigzag_depth, deviation_points, strategy_zigzag_backstep); // perf-allowed: one-time creation registered in the framework indicator pool for the card-defined structural ZigZag.
   return QM_IndicatorsRegister(key, handle);
  }

bool Strategy_IsOurPositionOpen()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

int Strategy_OurPendingStopCount()
  {
   const int magic = QM_FrameworkMagic();
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_STOP)
         ++count;
     }
   return count;
  }

void Strategy_DeleteOurPendingStops(const string reason)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(type != ORDER_TYPE_BUY_STOP && type != ORDER_TYPE_SELL_STOP)
         continue;
      QM_TM_RemovePendingOrder(ticket, reason);
     }
  }

void Strategy_ResetTriangle(const bool cancel_pending, const string reason)
  {
   if(cancel_pending)
      Strategy_DeleteOurPendingStops(reason);
   g_triangle_state = TRIANGLE_NONE;
   g_triangle_kind = TRIANGLE_KIND_NONE;
   g_triangle_detection_bar = 0;
   g_triangle_upper_base = 0.0;
   g_triangle_lower_base = 0.0;
   g_triangle_upper_slope = 0.0;
   g_triangle_lower_slope = 0.0;
   g_triangle_height = 0.0;
   g_bars_since_first_break = 0;
   g_bars_since_reentry = 0;
  }

bool Strategy_ReadPivots(StrategyPivot &highs[], StrategyPivot &lows[])
  {
   ArrayResize(highs, 0);
   ArrayResize(lows, 0);
   if(g_zigzag_handle == INVALID_HANDLE || strategy_triangle_max_bars < 4)
      return false;
   if(BarsCalculated(g_zigzag_handle) < strategy_triangle_max_bars + 2)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   for(int shift = 1; shift <= strategy_triangle_max_bars; ++shift)
     {
      const double price = QM_IndicatorReadBuffer(g_zigzag_handle, 0, shift);
      if(price == EMPTY_VALUE || price <= 0.0)
         continue;
      const double high = iHigh(_Symbol, PERIOD_H1, shift); // perf-allowed: bounded closed-H1 structural pivot classification; no QM_High reader exists.
      const double low = iLow(_Symbol, PERIOD_H1, shift); // perf-allowed: bounded closed-H1 structural pivot classification; no QM_Low reader exists.
      if(high <= 0.0 || low <= 0.0)
         continue;

      StrategyPivot pivot;
      pivot.shift = shift;
      pivot.price = price;
      if(MathAbs(price - high) <= MathAbs(price - low) + point)
        {
         const int n = ArraySize(highs);
         if(n < 12)
           {
            ArrayResize(highs, n + 1);
            highs[n] = pivot;
           }
        }
      else
        {
         const int n = ArraySize(lows);
         if(n < 12)
           {
            ArrayResize(lows, n + 1);
            lows[n] = pivot;
           }
        }
     }
   return (ArraySize(highs) >= 2 && ArraySize(lows) >= 2);
  }

bool Strategy_FindTriangle()
  {
   StrategyPivot highs[];
   StrategyPivot lows[];
   if(!Strategy_ReadPivots(highs, lows))
      return false;

   const double pip = Strategy_PipSize();
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(pip <= 0.0 || point <= 0.0)
      return false;
   const double touch_tolerance = MathMax(point * 2.0, strategy_zigzag_deviation * pip);

   bool found = false;
   int best_oldest_shift = INT_MAX;
   ENUM_TRIANGLE_KIND best_kind = TRIANGLE_KIND_NONE;
   double best_upper_base = 0.0;
   double best_lower_base = 0.0;
   double best_upper_slope = 0.0;
   double best_lower_slope = 0.0;
   double best_height = 0.0;

   const int high_count = ArraySize(highs);
   const int low_count = ArraySize(lows);
   for(int hn = 0; hn < high_count - 1; ++hn)
     {
      for(int ho = hn + 1; ho < high_count; ++ho)
        {
         const int high_gap = highs[ho].shift - highs[hn].shift;
         if(high_gap <= 0)
            continue;
         for(int ln = 0; ln < low_count - 1; ++ln)
           {
            for(int lo = ln + 1; lo < low_count; ++lo)
              {
               const int low_gap = lows[lo].shift - lows[ln].shift;
               if(low_gap <= 0)
                  continue;
               const int oldest_shift = MathMax(MathMax(highs[ho].shift, highs[hn].shift),
                                                MathMax(lows[lo].shift, lows[ln].shift));
               const int newest_shift = MathMin(MathMin(highs[ho].shift, highs[hn].shift),
                                                MathMin(lows[lo].shift, lows[ln].shift));
               const int formation_bars = oldest_shift - newest_shift;
               if(formation_bars < strategy_triangle_min_bars ||
                  formation_bars > strategy_triangle_max_bars ||
                  oldest_shift >= best_oldest_shift)
                  continue;

               // Ascending: two approximately level highs and two rising lows.
               if(MathAbs(highs[hn].price - highs[ho].price) <= touch_tolerance &&
                  lows[ln].price > lows[lo].price + point)
                 {
                  const double lower_slope = (lows[ln].price - lows[lo].price) / low_gap;
                  const double upper_base = (highs[hn].price + highs[ho].price) * 0.5;
                  const double lower_base = lows[ln].price + lower_slope * (lows[ln].shift - 1);
                  const double lower_oldest = lower_base - lower_slope * (oldest_shift - 1);
                  const double height = upper_base - lower_oldest;
                  if(lower_base < upper_base - point && height > point)
                    {
                     found = true;
                     best_oldest_shift = oldest_shift;
                     best_kind = TRIANGLE_ASCENDING;
                     best_upper_base = upper_base;
                     best_lower_base = lower_base;
                     best_upper_slope = 0.0;
                     best_lower_slope = lower_slope;
                     best_height = height;
                    }
                 }

               // Descending: two approximately level lows and two falling highs.
               if(MathAbs(lows[ln].price - lows[lo].price) <= touch_tolerance &&
                  highs[hn].price < highs[ho].price - point)
                 {
                  const double upper_slope = (highs[hn].price - highs[ho].price) / high_gap;
                  const double lower_base = (lows[ln].price + lows[lo].price) * 0.5;
                  const double upper_base = highs[hn].price + upper_slope * (highs[hn].shift - 1);
                  const double upper_oldest = upper_base - upper_slope * (oldest_shift - 1);
                  const double height = upper_oldest - lower_base;
                  if(upper_base > lower_base + point && height > point)
                    {
                     found = true;
                     best_oldest_shift = oldest_shift;
                     best_kind = TRIANGLE_DESCENDING;
                     best_upper_base = upper_base;
                     best_lower_base = lower_base;
                     best_upper_slope = upper_slope;
                     best_lower_slope = 0.0;
                     best_height = height;
                    }
                 }
              }
           }
        }
     }

   if(!found)
      return false;

   g_triangle_kind = best_kind;
   g_triangle_state = TRIANGLE_FORMED;
   g_triangle_detection_bar = iTime(_Symbol, PERIOD_H1, 1); // perf-allowed: one closed-H1 timestamp anchors deterministic trendline projection; no QM_Time reader exists.
   g_triangle_upper_base = best_upper_base;
   g_triangle_lower_base = best_lower_base;
   g_triangle_upper_slope = best_upper_slope;
   g_triangle_lower_slope = best_lower_slope;
   g_triangle_height = best_height;
   g_bars_since_first_break = 0;
   g_bars_since_reentry = 0;
   QM_LogEvent(QM_INFO,
               "TRIANGLE_FORMED",
               StringFormat("{\"kind\":\"%s\",\"upper\":%.8f,\"lower\":%.8f,\"height\":%.8f,\"oldest_shift\":%d}",
                            (best_kind == TRIANGLE_ASCENDING ? "ascending" : "descending"),
                            best_upper_base,
                            best_lower_base,
                            best_height,
                            best_oldest_shift));
   return true;
  }

bool Strategy_CurrentTriangleLevels(double &upper, double &lower)
  {
   upper = 0.0;
   lower = 0.0;
   if(g_triangle_detection_bar <= 0 || g_triangle_kind == TRIANGLE_KIND_NONE)
      return false;
   const int detection_shift = iBarShift(_Symbol, PERIOD_H1, g_triangle_detection_bar, false);
   if(detection_shift < 1)
      return false;
   const int elapsed = detection_shift - 1;
   upper = g_triangle_upper_base + g_triangle_upper_slope * elapsed;
   lower = g_triangle_lower_base + g_triangle_lower_slope * elapsed;
   return (upper > lower && lower > 0.0);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_H1)
      return true;
   if(strategy_zigzag_depth < 2 || strategy_zigzag_deviation <= 0 ||
      strategy_zigzag_backstep < 1 || strategy_triangle_min_bars < 4 ||
      strategy_triangle_max_bars <= strategy_triangle_min_bars ||
      strategy_entry_buffer_pips <= 0.0 || strategy_stop_buffer_pips <= 0.0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.symbol_slot = qm_magic_slot_offset;
   if(Strategy_IsOurPositionOpen())
     {
      g_triangle_state = TRIANGLE_SECOND_BROKEN;
      Strategy_DeleteOurPendingStops("position_already_open");
      return false;
     }

   if(g_triangle_state == TRIANGLE_SECOND_BROKEN)
     {
      if(Strategy_OurPendingStopCount() == 0)
         Strategy_ResetTriangle(false, "trade_cycle_complete");
      return false;
     }

   if(g_triangle_state == TRIANGLE_NONE)
     {
      Strategy_FindTriangle();
      return false;
     }

   double upper = 0.0;
   double lower = 0.0;
   if(!Strategy_CurrentTriangleLevels(upper, lower))
     {
      Strategy_ResetTriangle(true, "invalid_projected_triangle");
      return false;
     }

   const double close1 = iClose(_Symbol, PERIOD_H1, 1); // perf-allowed: one closed-H1 state-machine close; no QM_Close reader exists.
   if(close1 <= 0.0)
      return false;

   if(g_triangle_state == TRIANGLE_FORMED)
     {
      if(close1 > upper || close1 < lower)
        {
         g_triangle_state = TRIANGLE_FIRST_BROKEN;
         g_bars_since_first_break = 0;
         QM_LogEvent(QM_INFO, "TRIANGLE_FIRST_BREAK_IGNORED", "{}");
        }
      return false;
     }

   if(g_triangle_state == TRIANGLE_FIRST_BROKEN)
     {
      ++g_bars_since_first_break;
      if(close1 <= upper && close1 >= lower)
        {
         g_triangle_state = TRIANGLE_REENTERED;
         g_bars_since_reentry = 0;
        }
      else if(g_bars_since_first_break > STRATEGY_REENTRY_MAX_BARS)
         Strategy_ResetTriangle(true, "first_break_no_reentry");
      return false;
     }

   if(g_triangle_state != TRIANGLE_REENTERED)
      return false;

   ++g_bars_since_reentry;
   if(g_bars_since_reentry > STRATEGY_PENDING_VALID_BARS)
     {
      Strategy_ResetTriangle(true, "second_break_order_expired");
      return false;
     }
   if(Strategy_OurPendingStopCount() > 0)
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   const double pip = Strategy_PipSize();
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(pip <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   req.expiration_seconds = STRATEGY_PENDING_VALID_BARS * PeriodSeconds(PERIOD_H1);
   if(g_triangle_kind == TRIANGLE_ASCENDING)
     {
      req.type = QM_BUY_STOP;
      req.price = QM_TM_NormalizePrice(_Symbol, upper + strategy_entry_buffer_pips * pip);
      req.sl = QM_TM_NormalizePrice(_Symbol, lower - strategy_stop_buffer_pips * pip);
      const double initial_risk = req.price - req.sl;
      const double target_distance = MathMin(g_triangle_height, 2.0 * initial_risk);
      req.tp = QM_TM_NormalizePrice(_Symbol, req.price + target_distance);
      req.reason = "CHENG_TRIANGLE_SECOND_BREAK_LONG";
      return (req.price > ask && req.sl > 0.0 && req.sl < req.price && req.tp > req.price);
     }
   if(g_triangle_kind == TRIANGLE_DESCENDING)
     {
      req.type = QM_SELL_STOP;
      req.price = QM_TM_NormalizePrice(_Symbol, lower - strategy_entry_buffer_pips * pip);
      req.sl = QM_TM_NormalizePrice(_Symbol, upper + strategy_stop_buffer_pips * pip);
      const double initial_risk = req.sl - req.price;
      const double target_distance = MathMin(g_triangle_height, 2.0 * initial_risk);
      req.tp = QM_TM_NormalizePrice(_Symbol, req.price - target_distance);
      req.reason = "CHENG_TRIANGLE_SECOND_BREAK_SHORT";
      return (req.price < bid && req.price > 0.0 && req.sl > req.price && req.tp > 0.0 && req.tp < req.price);
     }
   return false;
  }

void Strategy_ManageOpenPosition()
  {
   if(Strategy_IsOurPositionOpen())
     {
      g_triangle_state = TRIANGLE_SECOND_BROKEN;
      Strategy_DeleteOurPendingStops("position_filled");
     }
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      if(!PositionSelectByTicket(PositionGetTicket(i))) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      if(strategy_time_stop_bars > 0)
      {
         datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
         int bars = iBarShift(_Symbol, PERIOD_H1, opened);
         if(bars >= strategy_time_stop_bars) 
         {
            Strategy_ResetTriangle(true, "position_time_stop");
            return true;
         }
      }
   }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
{
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                        qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;

   g_zigzag_handle = Strategy_IndZigZag();
   if(g_zigzag_handle == INVALID_HANDLE)
     {
      QM_LogEvent(QM_ERROR, "SETUP_DATA_MISSING", "{\"component\":\"Examples/ZigZag\"}");
      QM_FrameworkShutdown();
      return INIT_FAILED;
     }

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) 
{ 
   QM_FrameworkShutdown(); 
}

void OnTick()
{
   if(!QM_KillSwitchCheck())
     {
      Strategy_ResetTriangle(true, "kill_switch");
      return;
     }
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;
   
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
     {
      Strategy_ResetTriangle(true, "news_gate");
      return;
     }

   if(QM_FrameworkFridayCloseNow())
      Strategy_ResetTriangle(true, "friday_close");
   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
   {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
   }

   if(!QM_IsNewBar()) return;
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
   {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
   }
}

void OnTimer() { QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{
   QM_FrameworkOnTradeTransaction(t, r, res);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
