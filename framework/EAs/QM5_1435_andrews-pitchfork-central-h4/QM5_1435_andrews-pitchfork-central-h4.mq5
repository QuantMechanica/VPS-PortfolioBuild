#property strict
#property version   "5.0"
#property description "QuantMechanica V5 EA skeleton template"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  — closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        — risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() — use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly —
//     use the QM_* readers above. The framework pools handles and releases them
//     on shutdown.
//   - CopyRates over warmup windows on every tick. If you genuinely need raw
//     bar arrays, gate by QM_IsNewBar so the work runs once per closed bar.
//   - Hand-edit framework/include/QM/QM_MagicResolver.mqh. After adding rows
//     to magic_numbers.csv, run:
//         python framework/scripts/update_magic_resolver.py
//     This is idempotent and preserves all rows.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1435;
input int    qm_magic_slot_offset       = 0;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsMode qm_news_mode          = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_tf       = PERIOD_H4;
input int    strategy_atr_period        = 14;
input int    strategy_fractal_wing      = 2;
input int    strategy_min_window_bars   = 40;
input int    strategy_max_window_bars   = 200;
input double strategy_pivot_range_atr   = 0.70;
input double strategy_p0p1_atr          = 1.50;
input double strategy_p1p2_atr          = 1.00;
input double strategy_p0p2_atr          = 0.80;
input double strategy_min_slope_atr     = 0.05;
input double strategy_max_slope_atr     = 0.50;
input double strategy_median_near_atr   = 0.50;
input double strategy_stop_atr          = 0.80;
input double strategy_max_stop_atr      = 3.00;
input double strategy_spread_atr        = 0.20;
input double strategy_trigger_strength  = 0.60;
input int    strategy_d1_sma_period     = 50;
input int    strategy_tp1_bars          = 12;
input int    strategy_tp2_bars          = 25;
input int    strategy_failure_bars      = 8;
input int    strategy_time_stop_bars    = 30;
input int    strategy_reuse_guard_bars  = 18;

struct QM_Pivot
  {
   int      shift;
   double   price;
   int      type;
   datetime time;
  };

struct QM_Fork
  {
   bool     valid;
   int      direction;
   int      p0_shift;
   int      p1_shift;
   int      p2_shift;
   double   p0_price;
   double   slope;
   double   upper_intercept;
   double   lower_intercept;
   datetime key_time;
  };

datetime g_last_pattern_key = 0;
datetime g_guard_until_bar = 0;
double   g_active_slope = 0.0;
double   g_active_upper_intercept = 0.0;
double   g_active_lower_intercept = 0.0;
int      g_active_direction = 0;
bool     g_tp1_done = false;

double PF_LineAtShift(const double p0_price, const int p0_shift, const double slope, const int shift)
  {
   return p0_price + slope * (double)(p0_shift - shift);
  }

double PF_ParallelAtShift(const double slope, const double intercept, const int shift)
  {
   return slope * (double)(-shift) + intercept;
  }

bool PF_IsFractalHigh(const int shift)
  {
   const double h = iHigh(_Symbol, strategy_tf, shift);
   if(h <= 0.0)
      return false;
   for(int j = 1; j <= strategy_fractal_wing; ++j)
      if(h <= iHigh(_Symbol, strategy_tf, shift - j) || h <= iHigh(_Symbol, strategy_tf, shift + j))
         return false;
   return true;
  }

bool PF_IsFractalLow(const int shift)
  {
   const double l = iLow(_Symbol, strategy_tf, shift);
   if(l <= 0.0)
      return false;
   for(int j = 1; j <= strategy_fractal_wing; ++j)
      if(l >= iLow(_Symbol, strategy_tf, shift - j) || l >= iLow(_Symbol, strategy_tf, shift + j))
         return false;
   return true;
  }

bool PF_SignificantPivot(const int shift, const int type, const double atr)
  {
   double hi = 0.0;
   double lo = DBL_MAX;
   for(int j = shift - 5; j <= shift + 5; ++j)
     {
      if(j < 1)
         continue;
      hi = MathMax(hi, iHigh(_Symbol, strategy_tf, j));
      lo = MathMin(lo, iLow(_Symbol, strategy_tf, j));
     }
   if(hi <= 0.0 || lo == DBL_MAX)
      return false;
   const double pivot_price = (type > 0) ? iHigh(_Symbol, strategy_tf, shift) : iLow(_Symbol, strategy_tf, shift);
   const double distance = (type > 0) ? (pivot_price - lo) : (hi - pivot_price);
   return (distance >= strategy_pivot_range_atr * atr);
  }

bool PF_D1SlopeAgrees(const int direction)
  {
   const double sma1 = QM_SMA(_Symbol, PERIOD_D1, strategy_d1_sma_period, 1);
   const double sma6 = QM_SMA(_Symbol, PERIOD_D1, strategy_d1_sma_period, 6);
   if(sma1 <= 0.0 || sma6 <= 0.0)
      return false;
   return (direction > 0) ? (sma1 > sma6) : (sma1 < sma6);
  }

bool PF_ContextSlopeAgrees(const int p0_shift, const double pitchfork_slope)
  {
   const double c0 = iClose(_Symbol, strategy_tf, p0_shift);
   const double c1 = iClose(_Symbol, strategy_tf, 1);
   if(c0 <= 0.0 || c1 <= 0.0)
      return false;
   const double close_slope = (c1 - c0) / (double)MathMax(1, p0_shift - 1);
   return (pitchfork_slope > 0.0) ? (close_slope > 0.0) : (close_slope < 0.0);
  }

bool PF_BuildFork(QM_Fork &fork_out)
  {
   fork_out.valid = false;
   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   QM_Pivot pivots[80];
   int count = 0;
   const int max_shift = strategy_max_window_bars + strategy_fractal_wing + 5;
   for(int shift = max_shift; shift >= strategy_fractal_wing + 1 && count < 80; --shift)
     {
      int type = 0;
      double price = 0.0;
      if(PF_IsFractalHigh(shift) && PF_SignificantPivot(shift, 1, atr))
        {
         type = 1;
         price = iHigh(_Symbol, strategy_tf, shift);
        }
      else if(PF_IsFractalLow(shift) && PF_SignificantPivot(shift, -1, atr))
        {
         type = -1;
         price = iLow(_Symbol, strategy_tf, shift);
        }
      if(type == 0)
         continue;
      if(count > 0 && pivots[count - 1].type == type)
        {
         const bool replace = (type > 0) ? (price > pivots[count - 1].price) : (price < pivots[count - 1].price);
         if(replace)
           {
            pivots[count - 1].shift = shift;
            pivots[count - 1].price = price;
            pivots[count - 1].time = iTime(_Symbol, strategy_tf, shift);
           }
         continue;
        }
      pivots[count].shift = shift;
      pivots[count].price = price;
      pivots[count].type = type;
      pivots[count].time = iTime(_Symbol, strategy_tf, shift);
      ++count;
     }

   for(int i = count - 3; i >= 0; --i)
     {
      QM_Pivot p0 = pivots[i];
      QM_Pivot p1 = pivots[i + 1];
      QM_Pivot p2 = pivots[i + 2];
      const int span = p0.shift - p2.shift;
      if(span < strategy_min_window_bars || span > strategy_max_window_bars)
         continue;
      if(!(p0.type == -p1.type && p1.type == -p2.type))
         continue;
      const int direction = (p0.type < 0 && p1.type > 0 && p2.type < 0) ? 1 :
                            ((p0.type > 0 && p1.type < 0 && p2.type > 0) ? -1 : 0);
      if(direction == 0)
         continue;
      if(MathAbs(p1.price - p0.price) < strategy_p0p1_atr * atr)
         continue;
      if(MathAbs(p2.price - p1.price) < strategy_p1p2_atr * atr)
         continue;
      if(MathAbs(p2.price - p0.price) < strategy_p0p2_atr * atr)
         continue;

      const double ca_x = ((double)(p0.shift - p1.shift) + (double)(p0.shift - p2.shift)) * 0.5;
      const double ca_y = (p1.price + p2.price) * 0.5;
      if(ca_x <= 0.0)
         continue;
      const double slope = (ca_y - p0.price) / ca_x;
      const double slope_abs = MathAbs(slope);
      if(slope_abs < strategy_min_slope_atr * atr || slope_abs > strategy_max_slope_atr * atr)
         continue;

      const int projection_shift = MathMax(1, p2.shift - 20);
      const double central_projection = PF_LineAtShift(p0.price, p0.shift, slope, projection_shift);
      const double standard_projection = PF_LineAtShift(p0.price, p0.shift, slope, projection_shift);
      if(MathAbs(central_projection - standard_projection) < 0.30 * atr)
         continue;

      const double upper_anchor = MathMax(p1.price, p2.price);
      const int upper_shift = (p1.price >= p2.price) ? p1.shift : p2.shift;
      const double lower_anchor = MathMin(p1.price, p2.price);
      const int lower_shift = (p1.price <= p2.price) ? p1.shift : p2.shift;
      const double upper_intercept = upper_anchor - slope * (double)(-upper_shift);
      const double lower_intercept = lower_anchor - slope * (double)(-lower_shift);

      bool rail_touched = false;
      for(int s = p2.shift - 1; s >= 1; --s)
        {
         const double rail = (direction > 0) ? PF_ParallelAtShift(slope, upper_intercept, s)
                                             : PF_ParallelAtShift(slope, lower_intercept, s);
         if(direction > 0 && iHigh(_Symbol, strategy_tf, s) >= rail)
            rail_touched = true;
         if(direction < 0 && iLow(_Symbol, strategy_tf, s) <= rail)
            rail_touched = true;
         if(rail_touched)
            break;
        }
      if(!rail_touched)
         continue;

      if(!PF_ContextSlopeAgrees(p0.shift, slope))
         continue;
      if(!PF_D1SlopeAgrees(direction))
         continue;

      fork_out.valid = true;
      fork_out.direction = direction;
      fork_out.p0_shift = p0.shift;
      fork_out.p1_shift = p1.shift;
      fork_out.p2_shift = p2.shift;
      fork_out.p0_price = p0.price;
      fork_out.slope = slope;
      fork_out.upper_intercept = upper_intercept;
      fork_out.lower_intercept = lower_intercept;
      fork_out.key_time = p2.time;
      return true;
     }

   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return true;
   if((ask - bid) > strategy_spread_atr * atr)
      return true;
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const datetime current_bar = iTime(_Symbol, strategy_tf, 0);
   if(g_guard_until_bar > 0 && current_bar <= g_guard_until_bar)
      return false;

   QM_Fork fork;
   if(!PF_BuildFork(fork))
      return false;
   if(fork.key_time == g_last_pattern_key)
      return false;

   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   const double open1 = iOpen(_Symbol, strategy_tf, 1);
   const double close1 = iClose(_Symbol, strategy_tf, 1);
   const double high1 = iHigh(_Symbol, strategy_tf, 1);
   const double low1 = iLow(_Symbol, strategy_tf, 1);
   const double close2 = iClose(_Symbol, strategy_tf, 2);
   if(atr <= 0.0 || open1 <= 0.0 || close1 <= 0.0 || high1 <= low1 || close2 <= 0.0)
      return false;

   const double cml1 = PF_LineAtShift(fork.p0_price, fork.p0_shift, fork.slope, 1);
   const double cml2 = PF_LineAtShift(fork.p0_price, fork.p0_shift, fork.slope, 2);
   if(MathAbs(close1 - cml1) > strategy_median_near_atr * atr)
      return false;

   const double range = high1 - low1;
   bool trigger = false;
   if(fork.direction > 0)
      trigger = (close2 > cml2 && close1 > open1 && (close1 - low1) >= strategy_trigger_strength * range);
   else
      trigger = (close2 < cml2 && close1 < open1 && (high1 - close1) >= strategy_trigger_strength * range);
   if(!trigger)
      return false;

   const double market = (fork.direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                              : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = (fork.direction > 0) ? (cml1 - strategy_stop_atr * atr)
                                    : (cml1 + strategy_stop_atr * atr);
   const double max_stop = strategy_max_stop_atr * atr;
   if(fork.direction > 0 && market - sl > max_stop)
      sl = market - max_stop;
   if(fork.direction < 0 && sl - market > max_stop)
      sl = market + max_stop;

   const double target_rail = (fork.direction > 0) ? PF_ParallelAtShift(fork.slope, fork.upper_intercept, -strategy_tp1_bars)
                                                  : PF_ParallelAtShift(fork.slope, fork.lower_intercept, -strategy_tp1_bars);
   req.type = (fork.direction > 0) ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = NormalizeDouble(sl, _Digits);
   req.tp = NormalizeDouble(target_rail, _Digits);
   req.reason = "central_pitchfork_h4";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   g_last_pattern_key = fork.key_time;
   g_guard_until_bar = iTime(_Symbol, strategy_tf, 0) + (datetime)(strategy_reuse_guard_bars * PeriodSeconds(strategy_tf));
   g_active_slope = fork.slope;
   g_active_upper_intercept = fork.upper_intercept;
   g_active_lower_intercept = fork.lower_intercept;
   g_active_direction = fork.direction;
   g_tp1_done = false;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (type == POSITION_TYPE_BUY);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int entry_shift = iBarShift(_Symbol, strategy_tf, open_time, false);
      if(entry_shift < 0)
         continue;
      const double tp1 = is_buy ? PF_ParallelAtShift(g_active_slope, g_active_upper_intercept, entry_shift - strategy_tp1_bars)
                                : PF_ParallelAtShift(g_active_slope, g_active_lower_intercept, entry_shift - strategy_tp1_bars);
      const double tp2_base = is_buy ? PF_ParallelAtShift(g_active_slope, g_active_upper_intercept, entry_shift - strategy_tp2_bars)
                                     : PF_ParallelAtShift(g_active_slope, g_active_lower_intercept, entry_shift - strategy_tp2_bars);
      const double rail_width = MathAbs(g_active_upper_intercept - g_active_lower_intercept);
      const double tp2 = is_buy ? (tp2_base + 0.5 * rail_width) : (tp2_base - 0.5 * rail_width);
      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(!g_tp1_done && ((is_buy && market >= tp1) || (!is_buy && market <= tp1)))
        {
         QM_TM_PartialClose(ticket, volume * 0.5, QM_EXIT_STRATEGY);
         QM_TM_MoveSL(ticket, open_price, "central_pitchfork_tp1_be");
         QM_TM_MoveTP(ticket, tp2, "central_pitchfork_tp2");
         g_tp1_done = true;
        }
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (type == POSITION_TYPE_BUY);
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int entry_shift = iBarShift(_Symbol, strategy_tf, open_time, false);
      if(entry_shift < 0)
         continue;
      const int held_bars = entry_shift;
      if(held_bars >= strategy_time_stop_bars)
         return true;
      if(held_bars <= strategy_failure_bars)
        {
         const double close1 = iClose(_Symbol, strategy_tf, 1);
         const double cml1 = PF_LineAtShift(iClose(_Symbol, strategy_tf, entry_shift), entry_shift, g_active_slope, 1);
         if(is_buy && close1 < cml1 - atr)
            return true;
         if(!is_buy && close1 > cml1 + atr)
            return true;
        }
     }
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(qm_news_mode == QM_NEWS_OFF)
      return false;
   return !QM_NewsAllowsTrade(_Symbol, broker_time, qm_news_mode);
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
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
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
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
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
