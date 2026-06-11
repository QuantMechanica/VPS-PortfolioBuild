#property strict
#property version   "5.0"
#property description "QM5_10099 MQL5 Three-Swing Trendline Breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10099;
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
input int    strategy_swing_lookback          = 3;
input int    strategy_scan_bars               = 160;
input int    strategy_atr_period              = 14;
input double strategy_min_swing_atr_mult      = 0.0;
input double strategy_line_tolerance_atr_mult = 0.25;
input double strategy_breakout_atr_mult       = 0.10;
input double strategy_sl_atr_buffer_mult      = 0.50;
input double strategy_tp_r_multiple           = 2.0;
input bool   strategy_breakout_use_close      = true;
input double strategy_max_spread_points       = 0.0;

struct SwingPoint
  {
   int      shift;
   datetime time;
   double   price;
  };

struct TrendLineState
  {
   SwingPoint first;
   SwingPoint middle;
   SwingPoint recent;
  };

datetime g_buy_breakout_signal_time = 0;
datetime g_sell_breakout_signal_time = 0;
datetime g_cached_signal_time = 0;
datetime g_exit_consumed_signal_time = 0;
int      g_cached_signal_side = 0;

double NormalizeStrategyPrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   return NormalizeDouble(price, _Digits);
  }

void PushSwing(SwingPoint &points[],
               int &count,
               const int shift,
               const datetime time,
               const double price)
  {
   ArrayResize(points, count + 1);
   points[count].shift = shift;
   points[count].time = time;
   points[count].price = price;
   count++;
  }

bool IsSwingHigh(MqlRates &rates[],
                 const int copied,
                 const int shift,
                 const int wing,
                 const double min_move)
  {
   if(shift - wing < 1 || shift + wing >= copied)
      return false;

   const double pivot = rates[shift].high;
   double local_low = DBL_MAX;
   for(int j = 1; j <= wing; ++j)
     {
      if(rates[shift - j].high >= pivot || rates[shift + j].high >= pivot)
         return false;
      local_low = MathMin(local_low, rates[shift - j].low);
      local_low = MathMin(local_low, rates[shift + j].low);
     }

   return (min_move <= 0.0 || pivot - local_low >= min_move);
  }

bool IsSwingLow(MqlRates &rates[],
                const int copied,
                const int shift,
                const int wing,
                const double min_move)
  {
   if(shift - wing < 1 || shift + wing >= copied)
      return false;

   const double pivot = rates[shift].low;
   double local_high = -DBL_MAX;
   for(int j = 1; j <= wing; ++j)
     {
      if(rates[shift - j].low <= pivot || rates[shift + j].low <= pivot)
         return false;
      local_high = MathMax(local_high, rates[shift - j].high);
      local_high = MathMax(local_high, rates[shift + j].high);
     }

   return (min_move <= 0.0 || local_high - pivot >= min_move);
  }

int LoadBarWindow(MqlRates &rates[])
  {
   const int wing = MathMax(1, strategy_swing_lookback);
   const int scan = MathMax(strategy_scan_bars, wing * 4 + 20);
   const int bars_to_copy = scan + wing + 5;
   ArrayResize(rates, bars_to_copy);
   ArraySetAsSeries(rates, true);
   // perf-allowed: bounded closed-bar OHLC window for bespoke three-swing trendline geometry; called only after the skeleton QM_IsNewBar gate.
   return CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 0, bars_to_copy, rates);
  }

void ScanSwings(MqlRates &rates[],
                const int copied,
                const double atr_value,
                SwingPoint &highs[],
                int &high_count,
                SwingPoint &lows[],
                int &low_count)
  {
   high_count = 0;
   low_count = 0;
   ArrayResize(highs, 0);
   ArrayResize(lows, 0);

   const int wing = MathMax(1, strategy_swing_lookback);
   const int max_shift = MathMin(copied - wing - 1, strategy_scan_bars);
   if(max_shift <= wing + 1)
      return;

   const double min_move = MathMax(0.0, atr_value * strategy_min_swing_atr_mult);
   for(int shift = max_shift; shift >= wing + 1; --shift)
     {
      if(IsSwingHigh(rates, copied, shift, wing, min_move))
         PushSwing(highs, high_count, shift, rates[shift].time, rates[shift].high);
      if(IsSwingLow(rates, copied, shift, wing, min_move))
         PushSwing(lows, low_count, shift, rates[shift].time, rates[shift].low);
     }
  }

double LineValueAtShift(const TrendLineState &line, const int shift)
  {
   const double span = (double)(line.first.shift - line.recent.shift);
   if(MathAbs(span) < 0.5)
      return line.recent.price;
   const double progress = (double)(line.first.shift - shift) / span;
   return line.first.price + (line.recent.price - line.first.price) * progress;
  }

bool BuildValidatedLine(SwingPoint &points[],
                        const int count,
                        const double tolerance,
                        TrendLineState &line)
  {
   if(count < 3)
      return false;

   line.first = points[count - 3];
   line.middle = points[count - 2];
   line.recent = points[count - 1];

   const double expected_middle = LineValueAtShift(line, line.middle.shift);
   return (MathAbs(line.middle.price - expected_middle) <= tolerance);
  }

int EvaluateBreakout(MqlRates &rates[],
                     const TrendLineState &resistance,
                     const bool has_resistance,
                     const TrendLineState &support,
                     const bool has_support,
                     const double recent_swing_low,
                     const double recent_swing_high,
                     const double atr_value,
                     double &entry_price,
                     double &sl_price,
                     double &tp_price)
  {
   entry_price = 0.0;
   sl_price = 0.0;
   tp_price = 0.0;

   if(atr_value <= 0.0 || strategy_tp_r_multiple <= 0.0)
      return 0;

   const double breakout_buffer = atr_value * MathMax(0.0, strategy_breakout_atr_mult);
   const double sl_buffer = atr_value * MathMax(0.0, strategy_sl_atr_buffer_mult);

   if(has_resistance && recent_swing_low > 0.0)
     {
      const double line_now = LineValueAtShift(resistance, 1);
      const double line_prev = LineValueAtShift(resistance, 2);
      const double now_value = strategy_breakout_use_close ? rates[1].close : rates[1].high;
      const double prev_value = strategy_breakout_use_close ? rates[2].close : rates[2].high;
      if(now_value > line_now + breakout_buffer && prev_value <= line_prev + breakout_buffer)
        {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         entry_price = (ask > 0.0) ? ask : rates[1].close;
         sl_price = recent_swing_low - sl_buffer;
         if(sl_price > 0.0 && sl_price < entry_price)
           {
            const double risk = entry_price - sl_price;
            tp_price = entry_price + risk * strategy_tp_r_multiple;
            return 1;
           }
        }
     }

   if(has_support && recent_swing_high > 0.0)
     {
      const double line_now = LineValueAtShift(support, 1);
      const double line_prev = LineValueAtShift(support, 2);
      const double now_value = strategy_breakout_use_close ? rates[1].close : rates[1].low;
      const double prev_value = strategy_breakout_use_close ? rates[2].close : rates[2].low;
      if(now_value < line_now - breakout_buffer && prev_value >= line_prev - breakout_buffer)
        {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         entry_price = (bid > 0.0) ? bid : rates[1].close;
         sl_price = recent_swing_high + sl_buffer;
         if(sl_price > entry_price)
           {
            const double risk = sl_price - entry_price;
            tp_price = entry_price - risk * strategy_tp_r_multiple;
            return -1;
           }
        }
     }

   return 0;
  }

bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_points <= 0.0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return true;

   return ((ask - bid) / point > strategy_max_spread_points);
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

   MqlRates rates[];
   const int copied = LoadBarWindow(rates);
   const int min_copied = MathMax(30, strategy_swing_lookback * 4 + 10);
   if(copied < min_copied)
      return false;

   g_cached_signal_time = rates[1].time;
   g_cached_signal_side = 0;

   const double atr_value = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   SwingPoint highs[];
   SwingPoint lows[];
   int high_count = 0;
   int low_count = 0;
   ScanSwings(rates, copied, atr_value, highs, high_count, lows, low_count);

   const double tolerance = atr_value * MathMax(0.0, strategy_line_tolerance_atr_mult);
   TrendLineState resistance;
   TrendLineState support;
   const bool has_resistance = BuildValidatedLine(highs, high_count, tolerance, resistance);
   const bool has_support = BuildValidatedLine(lows, low_count, tolerance, support);
   const double recent_low = (low_count > 0) ? lows[low_count - 1].price : 0.0;
   const double recent_high = (high_count > 0) ? highs[high_count - 1].price : 0.0;

   double entry_price = 0.0;
   double sl_price = 0.0;
   double tp_price = 0.0;
   const int signal = EvaluateBreakout(rates, resistance, has_resistance, support, has_support,
                                       recent_low, recent_high, atr_value,
                                       entry_price, sl_price, tp_price);
   g_cached_signal_side = signal;

   if(signal == 0)
      return false;

   if(signal > 0)
     {
      if(g_buy_breakout_signal_time == rates[1].time)
         return false;
      g_buy_breakout_signal_time = rates[1].time;
      req.type = QM_BUY;
      req.reason = "THREE_SWING_RESISTANCE_BREAK";
     }
   else
     {
      if(g_sell_breakout_signal_time == rates[1].time)
         return false;
      g_sell_breakout_signal_time = rates[1].time;
      req.type = QM_SELL;
      req.reason = "THREE_SWING_SUPPORT_BREAK";
     }

   req.sl = NormalizeStrategyPrice(sl_price);
   req.tp = NormalizeStrategyPrice(tp_price);
   return (req.sl > 0.0 && req.tp > 0.0);
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, partial close, or break-even management.
  }

bool Strategy_ExitSignal()
  {
   if(g_cached_signal_side == 0 || g_cached_signal_time <= 0)
      return false;
   if(g_exit_consumed_signal_time == g_cached_signal_time)
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
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool opposite = (pos_type == POSITION_TYPE_BUY && g_cached_signal_side < 0) ||
                            (pos_type == POSITION_TYPE_SELL && g_cached_signal_side > 0);
      if(opposite)
        {
         g_exit_consumed_signal_time = g_cached_signal_time;
         return true;
        }
     }

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10099_mql5_trend3\"}");
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
