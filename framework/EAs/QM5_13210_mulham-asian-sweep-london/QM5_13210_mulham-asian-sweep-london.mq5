#property strict
#property version   "5.0"
#property description "QM5_13210 Mulham Asian-range London-window wick sweep"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 strategy implementation
// -----------------------------------------------------------------------------
// Card mechanics:
//   - Record the 03:00-07:00 broker-time Asian M5 range.
//   - Trade only a ranging (Type-3) Asian session.
//   - Re-anchor a one-way 07:00-08:30 extension, then require a wick-only
//     sweep during 08:30-10:00.
//   - Confirm with a close through the last opposing two-left/two-right M5
//     swing plus a
//     three-candle FVG; place a limit at the FVG midpoint, expiring at 12:00.
//   - Stop beyond the sweep extreme by 0.1 ATR(M5); target the opposite Asian
//     body extreme (default) or fixed 3R; flatten at 20:00 broker time.
//
// The structural state is advanced exactly once behind the framework's
// QM_IsNewBar gate. Fixed-shift OHLC reads below are the documented
// perf-allowed exception for this bespoke session/swing/FVG structure.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 13210;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

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

enum QM13210_TakeProfitMode
  {
   QM13210_TP_OPPOSITE_BODY = 0,
   QM13210_TP_FIXED_R       = 1
  };

input group "Strategy"
input int    strategy_asia_start_hour       = 3;
input int    strategy_asia_start_minute     = 0;
input int    strategy_asia_end_hour         = 7;
input int    strategy_asia_end_minute       = 0;
input int    strategy_sweep_start_hour      = 8;
input int    strategy_sweep_start_minute    = 30;
input int    strategy_sweep_end_hour        = 10;
input int    strategy_sweep_end_minute      = 0;
input int    strategy_entry_cancel_hour     = 12;
input int    strategy_entry_cancel_minute   = 0;
input int    strategy_flatten_hour          = 20;
input int    strategy_flatten_minute        = 0;
input int    strategy_atr_period             = 14;
input double strategy_asia_trend_max_frac    = 0.50;
input double strategy_asia_range_min_atr     = 0.30;
input double strategy_sl_buffer_atr          = 0.10;
input double strategy_spread_max_atr_frac    = 0.10;
input QM13210_TakeProfitMode strategy_tp_mode = QM13210_TP_OPPOSITE_BODY;
input double strategy_fixed_rr               = 3.0;

enum QM13210_Phase
  {
   QM13210_IDLE = 0,
   QM13210_RANGE_RECORDING,
   QM13210_WAIT_SWEEP,
   QM13210_WAIT_CONFIRM,
   QM13210_ENTRY_READY,
   QM13210_ORDER_PLACED,
   QM13210_DONE
  };

QM13210_Phase g_phase = QM13210_IDLE;
int      g_session_day_key   = -1;
double   g_asia_high         = 0.0;
double   g_asia_low          = 0.0;
double   g_asia_body_high    = 0.0;
double   g_asia_body_low     = 0.0;
double   g_asia_first_open   = 0.0;
double   g_asia_last_close   = 0.0;
int      g_asia_bars         = 0;
double   g_sweep_high_ref    = 0.0;
double   g_sweep_low_ref     = 0.0;
double   g_last_swing_high   = 0.0;
double   g_last_swing_low    = 0.0;
int      g_sweep_direction   = 0; // +1 long after low sweep; -1 short after high sweep
double   g_sweep_extreme     = 0.0;
double   g_structure_level   = 0.0;
bool     g_entry_ready       = false;
double   g_entry_price       = 0.0;
double   g_entry_sl          = 0.0;
double   g_entry_tp          = 0.0;

int QM13210_MinuteOfDay(const datetime broker_time)
  {
   MqlDateTime tm;
   ZeroMemory(tm);
   TimeToStruct(broker_time, tm);
   return tm.hour * 60 + tm.min;
  }

int QM13210_DayKey(const datetime broker_time)
  {
   MqlDateTime tm;
   ZeroMemory(tm);
   TimeToStruct(broker_time, tm);
   return tm.year * 1000 + tm.day_of_year;
  }

int QM13210_ConfigMinute(const int hour_value, const int minute_value)
  {
   return hour_value * 60 + minute_value;
  }

bool QM13210_ValidClock(const int hour_value, const int minute_value)
  {
   return (hour_value >= 0 && hour_value <= 23 &&
           minute_value >= 0 && minute_value <= 59);
  }

bool QM13210_InputsValid()
  {
   if(!QM13210_ValidClock(strategy_asia_start_hour, strategy_asia_start_minute) ||
      !QM13210_ValidClock(strategy_asia_end_hour, strategy_asia_end_minute) ||
      !QM13210_ValidClock(strategy_sweep_start_hour, strategy_sweep_start_minute) ||
      !QM13210_ValidClock(strategy_sweep_end_hour, strategy_sweep_end_minute) ||
      !QM13210_ValidClock(strategy_entry_cancel_hour, strategy_entry_cancel_minute) ||
      !QM13210_ValidClock(strategy_flatten_hour, strategy_flatten_minute))
      return false;

   const int asia_start = QM13210_ConfigMinute(strategy_asia_start_hour, strategy_asia_start_minute);
   const int asia_end = QM13210_ConfigMinute(strategy_asia_end_hour, strategy_asia_end_minute);
   const int sweep_start = QM13210_ConfigMinute(strategy_sweep_start_hour, strategy_sweep_start_minute);
   const int sweep_end = QM13210_ConfigMinute(strategy_sweep_end_hour, strategy_sweep_end_minute);
   const int cancel_time = QM13210_ConfigMinute(strategy_entry_cancel_hour, strategy_entry_cancel_minute);
   const int flatten_time = QM13210_ConfigMinute(strategy_flatten_hour, strategy_flatten_minute);
   if(!(asia_start < asia_end && asia_end < sweep_start && sweep_start < sweep_end &&
        sweep_end < cancel_time && cancel_time < flatten_time))
      return false;

   return (strategy_atr_period >= 2 &&
           strategy_asia_trend_max_frac > 0.0 &&
           strategy_asia_range_min_atr > 0.0 &&
           strategy_sl_buffer_atr > 0.0 &&
           strategy_spread_max_atr_frac > 0.0 &&
           strategy_fixed_rr > 0.0);
  }

void QM13210_ResetForDay(const int day_key)
  {
   g_phase              = QM13210_RANGE_RECORDING;
   g_session_day_key    = day_key;
   g_asia_high          = 0.0;
   g_asia_low           = 0.0;
   g_asia_body_high     = 0.0;
   g_asia_body_low      = 0.0;
   g_asia_first_open    = 0.0;
   g_asia_last_close    = 0.0;
   g_asia_bars          = 0;
   g_sweep_high_ref     = 0.0;
   g_sweep_low_ref      = 0.0;
   g_last_swing_high    = 0.0;
   g_last_swing_low     = 0.0;
   g_sweep_direction    = 0;
   g_sweep_extreme      = 0.0;
   g_structure_level    = 0.0;
   g_entry_ready        = false;
   g_entry_price        = 0.0;
   g_entry_sl           = 0.0;
   g_entry_tp           = 0.0;
  }

void QM13210_UpdateLastSwings()
  {
   // perf-allowed: ten fixed-shift OHLC reads, called once behind QM_IsNewBar.
   // Shift 3 is now fully confirmed by two closed bars on its right.
   const datetime pivot_open = iTime(_Symbol, PERIOD_M5, 3); // perf-allowed: fixed closed pivot bar
   if(pivot_open <= 0 || QM13210_DayKey(pivot_open) != g_session_day_key)
      return;
   const int asia_start = QM13210_ConfigMinute(strategy_asia_start_hour, strategy_asia_start_minute);
   if(QM13210_MinuteOfDay(pivot_open) < asia_start)
      return;

   const double high_1 = iHigh(_Symbol, PERIOD_M5, 1); // perf-allowed: fixed closed swing window
   const double high_2 = iHigh(_Symbol, PERIOD_M5, 2); // perf-allowed: fixed closed swing window
   const double high_3 = iHigh(_Symbol, PERIOD_M5, 3); // perf-allowed: fixed closed swing window
   const double high_4 = iHigh(_Symbol, PERIOD_M5, 4); // perf-allowed: fixed closed swing window
   const double high_5 = iHigh(_Symbol, PERIOD_M5, 5); // perf-allowed: fixed closed swing window
   const double low_1  = iLow(_Symbol, PERIOD_M5, 1);  // perf-allowed: fixed closed swing window
   const double low_2  = iLow(_Symbol, PERIOD_M5, 2);  // perf-allowed: fixed closed swing window
   const double low_3  = iLow(_Symbol, PERIOD_M5, 3);  // perf-allowed: fixed closed swing window
   const double low_4  = iLow(_Symbol, PERIOD_M5, 4);  // perf-allowed: fixed closed swing window
   const double low_5  = iLow(_Symbol, PERIOD_M5, 5);  // perf-allowed: fixed closed swing window
   if(high_1 <= 0.0 || high_2 <= 0.0 || high_3 <= 0.0 || high_4 <= 0.0 || high_5 <= 0.0 ||
      low_1 <= 0.0 || low_2 <= 0.0 || low_3 <= 0.0 || low_4 <= 0.0 || low_5 <= 0.0)
      return;

   if(high_3 > high_4 && high_3 > high_5 && high_3 >= high_2 && high_3 >= high_1)
      g_last_swing_high = high_3;
   if(low_3 < low_4 && low_3 < low_5 && low_3 <= low_2 && low_3 <= low_1)
      g_last_swing_low = low_3;
  }

bool QM13210_SpreadAllowsEntry(const double atr_m5)
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;
   if(ask < bid)
      return false; // crossed quote is invalid; equality is not.
   if(ask == bid)
      return true; // .DWX tester spread is legitimately zero.
   if(atr_m5 <= 0.0)
      return false;
   return ((ask - bid) <= strategy_spread_max_atr_frac * atr_m5);
  }

bool QM13210_HasOwnedPendingOrder()
  {
   const long magic = (long)QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_SYMBOL) == _Symbol)
         return true;
     }
   return false;
  }

void QM13210_RemoveOwnedPendingOrders(const string reason)
  {
   const long magic = (long)QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(OrderGetInteger(ORDER_MAGIC) != magic || OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      QM_TM_RemovePendingOrder(ticket, reason);
     }
  }

void QM13210_CacheConfirmedEntry(const int direction,
                                 const double fvg_near,
                                 const double fvg_far,
                                 const double atr_m5)
  {
   if(direction == 0 || fvg_near <= 0.0 || fvg_far <= 0.0 || atr_m5 <= 0.0)
      return;

   const double entry = 0.5 * (fvg_near + fvg_far);
   const double buffer = strategy_sl_buffer_atr * atr_m5;
   double sl = 0.0;
   double tp = 0.0;
   if(direction > 0)
     {
      sl = g_sweep_extreme - buffer;
      if(strategy_tp_mode == QM13210_TP_FIXED_R)
         tp = entry + strategy_fixed_rr * (entry - sl);
      else
         tp = g_asia_body_high;
      if(!(sl < entry && tp > entry))
         return;
     }
   else
     {
      sl = g_sweep_extreme + buffer;
      if(strategy_tp_mode == QM13210_TP_FIXED_R)
         tp = entry - strategy_fixed_rr * (sl - entry);
      else
         tp = g_asia_body_low;
      if(!(sl > entry && tp > 0.0 && tp < entry))
         return;
     }

   g_entry_price = entry;
   g_entry_sl = sl;
   g_entry_tp = tp;
   g_entry_ready = true;
   g_phase = QM13210_ENTRY_READY;
  }

void QM13210_AdvanceStateOnNewBar()
  {
   // perf-allowed: fixed closed M5 bars only; caller consumed QM_IsNewBar once.
   const datetime bar_open = iTime(_Symbol, PERIOD_M5, 1); // perf-allowed: one closed structural bar
   const double o = iOpen(_Symbol, PERIOD_M5, 1);          // perf-allowed: one closed structural bar
   const double h = iHigh(_Symbol, PERIOD_M5, 1);          // perf-allowed: one closed structural bar
   const double l = iLow(_Symbol, PERIOD_M5, 1);           // perf-allowed: one closed structural bar
   const double c = iClose(_Symbol, PERIOD_M5, 1);         // perf-allowed: one closed structural bar
   if(bar_open <= 0 || o <= 0.0 || h <= 0.0 || l <= 0.0 || c <= 0.0)
      return;

   const int minute = QM13210_MinuteOfDay(bar_open);
   const int day_key = QM13210_DayKey(bar_open);
   const int asia_start = QM13210_ConfigMinute(strategy_asia_start_hour, strategy_asia_start_minute);
   const int asia_end = QM13210_ConfigMinute(strategy_asia_end_hour, strategy_asia_end_minute);
   const int sweep_start = QM13210_ConfigMinute(strategy_sweep_start_hour, strategy_sweep_start_minute);
   const int sweep_end = QM13210_ConfigMinute(strategy_sweep_end_hour, strategy_sweep_end_minute);
   const int cancel_time = QM13210_ConfigMinute(strategy_entry_cancel_hour, strategy_entry_cancel_minute);

   if(minute >= asia_start && minute < asia_end && day_key != g_session_day_key)
      QM13210_ResetForDay(day_key);
   if(day_key != g_session_day_key)
      return;

   QM13210_UpdateLastSwings();

   if(g_phase == QM13210_RANGE_RECORDING && minute >= asia_start && minute < asia_end)
     {
      const double body_high = MathMax(o, c);
      const double body_low = MathMin(o, c);
      if(g_asia_bars == 0)
        {
         g_asia_high = h;
         g_asia_low = l;
         g_asia_body_high = body_high;
         g_asia_body_low = body_low;
         g_asia_first_open = o;
        }
      else
        {
         if(h > g_asia_high) g_asia_high = h;
         if(l < g_asia_low) g_asia_low = l;
         if(body_high > g_asia_body_high) g_asia_body_high = body_high;
         if(body_low < g_asia_body_low) g_asia_body_low = body_low;
        }
      g_asia_last_close = c;
      g_asia_bars++;
      return;
     }

   if(g_phase == QM13210_RANGE_RECORDING && minute >= asia_end)
     {
      const double range = g_asia_high - g_asia_low;
      const double atr_h1 = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
      if(g_asia_bars <= 0 || range <= 0.0 || atr_h1 <= 0.0)
        {
         g_phase = QM13210_DONE;
         return;
        }
      const double net_move = MathAbs(g_asia_last_close - g_asia_first_open);
      if(net_move > strategy_asia_trend_max_frac * range ||
         range < strategy_asia_range_min_atr * atr_h1)
        {
         g_phase = QM13210_DONE;
         return;
        }
      g_sweep_high_ref = g_asia_high;
      g_sweep_low_ref = g_asia_low;
      g_phase = QM13210_WAIT_SWEEP;
     }

   if(g_phase == QM13210_WAIT_SWEEP && minute >= asia_end && minute < sweep_start)
     {
      // Extension rule: only a close beyond the range is a non-reversing
      // extension; re-anchor that side to the new wick extreme.
      if(c > g_sweep_high_ref && h > g_sweep_high_ref)
         g_sweep_high_ref = h;
      if(c < g_sweep_low_ref && l < g_sweep_low_ref)
         g_sweep_low_ref = l;
      return;
     }

   if(g_phase == QM13210_WAIT_SWEEP && minute >= sweep_start && minute < sweep_end)
     {
      if(c > g_sweep_high_ref || c < g_sweep_low_ref)
        {
         g_phase = QM13210_DONE; // body close through an extreme invalidates the fade.
         return;
        }

      const bool high_wick_sweep = (h > g_sweep_high_ref && MathMax(o, c) <= g_sweep_high_ref);
      const bool low_wick_sweep = (l < g_sweep_low_ref && MathMin(o, c) >= g_sweep_low_ref);
      if(high_wick_sweep && low_wick_sweep)
        {
         g_phase = QM13210_DONE;
         return;
        }
      if(high_wick_sweep)
        {
         if(g_last_swing_low <= 0.0)
            return;
         g_sweep_direction = -1;
         g_sweep_extreme = h;
         g_structure_level = g_last_swing_low;
         g_phase = QM13210_WAIT_CONFIRM;
        }
      else if(low_wick_sweep)
        {
         if(g_last_swing_high <= 0.0)
            return;
         g_sweep_direction = +1;
         g_sweep_extreme = l;
         g_structure_level = g_last_swing_high;
         g_phase = QM13210_WAIT_CONFIRM;
        }
     }

   if(g_phase == QM13210_WAIT_SWEEP && minute >= sweep_end)
     {
      g_phase = QM13210_DONE;
      return;
     }

   if(g_phase != QM13210_WAIT_CONFIRM)
      return;
   if(minute >= cancel_time)
     {
      g_phase = QM13210_DONE;
      return;
     }

   if(g_sweep_direction < 0)
     {
      if(c > g_sweep_high_ref)
        {
         g_phase = QM13210_DONE;
         return;
        }
      if(h > g_sweep_extreme)
         g_sweep_extreme = h;
     }
   else
     {
      if(c < g_sweep_low_ref)
        {
         g_phase = QM13210_DONE;
         return;
        }
      if(l < g_sweep_extreme)
         g_sweep_extreme = l;
     }

   // Standard three-candle FVG: current closed bar (shift 1) does not overlap
   // the first candle (shift 3). The middle candle is shift 2.
   const double high_3 = iHigh(_Symbol, PERIOD_M5, 3); // perf-allowed fixed shift
   const double low_3 = iLow(_Symbol, PERIOD_M5, 3);   // perf-allowed fixed shift
   if(high_3 <= 0.0 || low_3 <= 0.0)
      return;

   const double atr_m5 = QM_ATR(_Symbol, PERIOD_M5, strategy_atr_period, 1);
   if(g_sweep_direction > 0 && c > g_structure_level && l > high_3)
      QM13210_CacheConfirmedEntry(+1, l, high_3, atr_m5);
   else if(g_sweep_direction < 0 && c < g_structure_level && h < low_3)
      QM13210_CacheConfirmedEntry(-1, h, low_3, atr_m5);
  }

// -----------------------------------------------------------------------------
// Five strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   if((ENUM_TIMEFRAMES)_Period != PERIOD_M5)
      return true;
   if(_Symbol != "EURUSD.DWX" && _Symbol != "XAUUSD.DWX")
      return true;
   return false;
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

   if(!g_entry_ready || g_phase != QM13210_ENTRY_READY)
      return false;
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0 || QM13210_HasOwnedPendingOrder())
      return false;

   const datetime broker_now = TimeCurrent();
   if(QM13210_DayKey(broker_now) != g_session_day_key)
      return false;
   const int minute = QM13210_MinuteOfDay(broker_now);
   const int cancel_time = QM13210_ConfigMinute(strategy_entry_cancel_hour, strategy_entry_cancel_minute);
   if(minute >= cancel_time)
     {
      g_entry_ready = false;
      g_phase = QM13210_DONE;
      return false;
     }

   const double atr_m5 = QM_ATR(_Symbol, PERIOD_M5, strategy_atr_period, 1);
   if(!QM13210_SpreadAllowsEntry(atr_m5))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;
   if((g_sweep_direction > 0 && g_entry_price >= ask) ||
      (g_sweep_direction < 0 && g_entry_price <= bid))
     {
      g_entry_ready = false; // midpoint already crossed; never chase at market.
      g_phase = QM13210_DONE;
      return false;
     }

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const long stop_level_points = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double broker_min_distance = (point > 0.0 && stop_level_points > 0)
                                      ? point * (double)stop_level_points
                                      : 0.0;
   if(g_sweep_direction > 0 && broker_min_distance > 0.0 &&
      ((ask - g_entry_price) < broker_min_distance ||
       (g_entry_price - g_entry_sl) < broker_min_distance ||
       (g_entry_tp - g_entry_price) < broker_min_distance))
      return false;
   if(g_sweep_direction < 0 && broker_min_distance > 0.0 &&
      ((g_entry_price - bid) < broker_min_distance ||
       (g_entry_sl - g_entry_price) < broker_min_distance ||
       (g_entry_price - g_entry_tp) < broker_min_distance))
      return false;

   MqlDateTime expiry_tm;
   ZeroMemory(expiry_tm);
   TimeToStruct(broker_now, expiry_tm);
   expiry_tm.hour = strategy_entry_cancel_hour;
   expiry_tm.min = strategy_entry_cancel_minute;
   expiry_tm.sec = 0;
   const datetime expiry = StructToTime(expiry_tm);
   const int expiry_seconds = (int)(expiry - broker_now);
   if(expiry_seconds <= 0)
      return false;

   req.type = (g_sweep_direction > 0) ? QM_BUY_LIMIT : QM_SELL_LIMIT;
   req.price = QM_TM_NormalizePrice(_Symbol, g_entry_price);
   req.sl = QM_TM_NormalizePrice(_Symbol, g_entry_sl);
   req.tp = QM_TM_NormalizePrice(_Symbol, g_entry_tp);
   req.reason = (g_sweep_direction > 0) ? "asian_sweep_fvg_long" : "asian_sweep_fvg_short";
   req.expiration_seconds = expiry_seconds;

   g_entry_ready = false;
   g_phase = QM13210_ORDER_PLACED;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const int minute = QM13210_MinuteOfDay(TimeCurrent());
   const int cancel_time = QM13210_ConfigMinute(strategy_entry_cancel_hour, strategy_entry_cancel_minute);
   if(minute >= cancel_time && QM13210_HasOwnedPendingOrder())
      QM13210_RemoveOwnedPendingOrders("asian_sweep_entry_cancel");
  }

bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;
   const int minute = QM13210_MinuteOfDay(TimeCurrent());
   const int flatten_time = QM13210_ConfigMinute(strategy_flatten_hour, strategy_flatten_minute);
   return (minute >= flatten_time);
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // The central two-axis high-impact calendar filter implements the card's
   // news blackout. No additional event taxonomy was mechanically specified.
   return false;
  }

// -----------------------------------------------------------------------------
// Framework lifecycle and canonical OnTick corset
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!QM13210_InputsValid())
     {
      Print("QM5_13210 invalid strategy inputs");
      return INIT_PARAMETERS_INCORRECT;
     }

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13210_mulham-asian-sweep-london\",\"version\":\"5.0\"}");
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

   // News gates only the entry path; management and the 20:00 flatten above
   // keep running during high-impact windows.
   if(Strategy_NewsFilterHook(broker_now))
      return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   QM13210_AdvanceStateOnNewBar();
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
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
