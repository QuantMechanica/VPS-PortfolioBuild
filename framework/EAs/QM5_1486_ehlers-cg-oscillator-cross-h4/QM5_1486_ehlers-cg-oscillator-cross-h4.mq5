#property strict
#property version   "5.0"
#property description "QM5_1486 Ehlers CG Oscillator Cross H4"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1486;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE60_POST60;
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
input int    strategy_cg_period             = 10;
input int    strategy_cg_range_lookback     = 200;
input double strategy_extreme_fraction      = 0.40;
input int    strategy_macro_sma_period      = 50;
input int    strategy_macro_slope_bars      = 5;
input int    strategy_atr_period            = 14;
input int    strategy_atr_mean_lookback     = 200;
input double strategy_atr_floor_mult        = 0.60;
input int    strategy_no_opposite_bars      = 20;
input double strategy_stability_fraction    = 0.05;
input double strategy_sl_atr_mult           = 2.0;
input double strategy_tp1_atr_mult          = 1.5;
input double strategy_tp1_close_fraction    = 0.60;
input int    strategy_time_stop_h4_bars     = 24;
input int    strategy_spread_lookback       = 20;
input double strategy_spread_median_mult    = 1.5;

bool          g_strategy_new_bar = false;
bool          g_tp1_done = false;
QM_ExitReason g_strategy_exit_reason = QM_EXIT_STRATEGY;

bool LoadRates(const ENUM_TIMEFRAMES tf, const int bars_needed, MqlRates &rates[])
  {
   if(bars_needed <= 0)
      return false;
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, tf, 0, bars_needed, rates); // perf-allowed: bespoke CG/D1 arithmetic, called only from the framework new-bar path.
   ArraySetAsSeries(rates, true);
   return (copied >= bars_needed);
  }

double CGFromRates(MqlRates &rates[], const int shift, const int period)
  {
   if(period <= 1 || shift < 0)
      return 0.0;

   double numerator = 0.0;
   double denominator = 0.0;
   for(int i = 0; i < period; ++i)
     {
      const double median = (rates[shift + i].high + rates[shift + i].low) * 0.5;
      if(median <= 0.0)
         return 0.0;
      numerator += (double)(1 + i) * median;
      denominator += median;
     }

   if(MathAbs(denominator) <= DBL_EPSILON)
      return 0.0;
   return (-numerator / denominator) + ((double)(period + 1) * 0.5);
  }

bool BullishCGCross(MqlRates &rates[], const int shift)
  {
   const double cg0 = CGFromRates(rates, shift, strategy_cg_period);
   const double cg1 = CGFromRates(rates, shift + 1, strategy_cg_period);
   const double cg2 = CGFromRates(rates, shift + 2, strategy_cg_period);
   return (cg0 > cg1 && cg1 <= cg2);
  }

bool BearishCGCross(MqlRates &rates[], const int shift)
  {
   const double cg0 = CGFromRates(rates, shift, strategy_cg_period);
   const double cg1 = CGFromRates(rates, shift + 1, strategy_cg_period);
   const double cg2 = CGFromRates(rates, shift + 2, strategy_cg_period);
   return (cg0 < cg1 && cg1 >= cg2);
  }

bool CGRange(MqlRates &rates[], const int start_shift, const int lookback, double &out_min, double &out_max)
  {
   out_min = DBL_MAX;
   out_max = -DBL_MAX;
   if(lookback <= 1)
      return false;

   for(int i = 0; i < lookback; ++i)
     {
      const double value = CGFromRates(rates, start_shift + i, strategy_cg_period);
      if(value == 0.0)
         return false;
      if(value < out_min)
         out_min = value;
      if(value > out_max)
         out_max = value;
     }

   return (out_max > out_min);
  }

bool HasRecentOppositeCross(MqlRates &rates[], const int direction)
  {
   for(int shift = 2; shift < 2 + strategy_no_opposite_bars; ++shift)
     {
      if(direction > 0 && BearishCGCross(rates, shift))
         return true;
      if(direction < 0 && BullishCGCross(rates, shift))
         return true;
     }
   return false;
  }

double MeanATR(const int period, const int lookback)
  {
   if(period <= 0 || lookback <= 0)
      return 0.0;

   double sum = 0.0;
   int samples = 0;
   for(int shift = 1; shift <= lookback; ++shift)
     {
      const double value = QM_ATR(_Symbol, PERIOD_H4, period, shift);
      if(value <= 0.0)
         return 0.0;
      sum += value;
      samples++;
     }

   if(samples <= 0)
      return 0.0;
   return sum / (double)samples;
  }

bool MacroBiasAllows(const int direction)
  {
   MqlRates d1[];
   if(!LoadRates(PERIOD_D1, strategy_macro_slope_bars + 7, d1))
      return false;

   const double d1_close = d1[1].close;
   const double sma_now = QM_SMA(_Symbol, PERIOD_D1, strategy_macro_sma_period, 1, PRICE_CLOSE);
   const double sma_then = QM_SMA(_Symbol, PERIOD_D1, strategy_macro_sma_period, 1 + strategy_macro_slope_bars, PRICE_CLOSE);
   if(d1_close <= 0.0 || sma_now <= 0.0 || sma_then <= 0.0)
      return false;

   if(direction > 0)
      return (d1_close > sma_now && sma_now > sma_then);
   return (d1_close < sma_now && sma_now < sma_then);
  }

double MedianSpreadDistance(MqlRates &rates[])
  {
   if(strategy_spread_lookback <= 0)
      return 0.0;

   double spreads[];
   ArrayResize(spreads, strategy_spread_lookback);
   int count = 0;
   for(int i = 1; i <= strategy_spread_lookback; ++i)
     {
      if(rates[i].spread <= 0)
         continue;
      spreads[count] = (double)rates[i].spread;
      count++;
     }

   if(count <= 0)
      return 0.0;

   ArrayResize(spreads, count);
   ArraySort(spreads);

   double median_points = spreads[count / 2];
   if((count % 2) == 0)
      median_points = (spreads[(count / 2) - 1] + spreads[count / 2]) * 0.5;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;
   return median_points * point;
  }

bool SpreadAllows(MqlRates &rates[])
  {
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return false;

   const double current_spread = ask - bid;
   if(current_spread <= 0.0)
      return true;

   const double median_spread = MedianSpreadDistance(rates);
   if(median_spread <= 0.0)
      return true;

   return (current_spread <= strategy_spread_median_mult * median_spread);
  }

bool BuildSignal(const int direction, MqlRates &rates[], double &atr_value)
  {
   atr_value = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double atr_mean = MeanATR(strategy_atr_period, strategy_atr_mean_lookback);
   if(atr_value <= 0.0 || atr_mean <= 0.0)
      return false;
   if(atr_value <= strategy_atr_floor_mult * atr_mean)
      return false;

   double cg_min = 0.0;
   double cg_max = 0.0;
   if(!CGRange(rates, 2, strategy_cg_range_lookback, cg_min, cg_max))
      return false;

   const double range = cg_max - cg_min;
   if(range <= 0.0)
      return false;

   const double cg_prev = CGFromRates(rates, 2, strategy_cg_period);
   const double cg_prev2 = CGFromRates(rates, 3, strategy_cg_period);
   if(MathAbs(cg_prev - cg_prev2) <= strategy_stability_fraction * range)
      return false;

   if(direction > 0)
     {
      if(cg_prev > cg_min + strategy_extreme_fraction * range)
         return false;
     }
   else
     {
      if(cg_prev < cg_max - strategy_extreme_fraction * range)
         return false;
     }

   if(!MacroBiasAllows(direction))
      return false;
   if(HasRecentOppositeCross(rates, direction))
      return false;
   if(!SpreadAllows(rates))
      return false;

   return true;
  }

bool SelectOurPosition(ulong &ticket, ENUM_POSITION_TYPE &position_type)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      ticket = candidate;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }

   return false;
  }

bool Strategy_NoTradeFilter()
  {
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

   if(strategy_cg_period < 2 || strategy_cg_range_lookback < 20 || strategy_atr_period < 2)
      return false;

   const int bars_needed = strategy_cg_range_lookback + strategy_cg_period + 5;
   MqlRates h4[];
   if(!LoadRates(PERIOD_H4, bars_needed, h4))
      return false;

   const bool bullish = BullishCGCross(h4, 1);
   const bool bearish = BearishCGCross(h4, 1);
   if(!bullish && !bearish)
      return false;

   const int direction = bullish ? 1 : -1;
   double atr_value = 0.0;
   if(!BuildSignal(direction, h4, atr_value))
      return false;

   req.type = bullish ? QM_BUY : QM_SELL;
   const double entry = bullish ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry, atr_value, strategy_sl_atr_mult);
   req.tp = 0.0;
   req.reason = bullish ? "CG_BULL_CROSS_H4" : "CG_BEAR_CROSS_H4";
   if(req.sl <= 0.0)
      return false;

   g_tp1_done = false;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   if(!SelectOurPosition(ticket, position_type))
     {
      g_tp1_done = false;
      return;
     }

   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double sl_price = PositionGetDouble(POSITION_SL);
   const double volume = PositionGetDouble(POSITION_VOLUME);
   if(open_price <= 0.0 || sl_price <= 0.0 || volume <= 0.0 || g_tp1_done)
      return;

   const double atr_distance = MathAbs(open_price - sl_price) / strategy_sl_atr_mult;
   if(atr_distance <= 0.0)
      return;

   const bool is_buy = (position_type == POSITION_TYPE_BUY);
   const double trigger = is_buy ? (open_price + strategy_tp1_atr_mult * atr_distance)
                                 : (open_price - strategy_tp1_atr_mult * atr_distance);
   const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(market <= 0.0)
      return;

   const bool hit_tp1 = is_buy ? (market >= trigger) : (market <= trigger);
   if(!hit_tp1)
      return;

   const double close_lots = QM_TM_NormalizeVolume(_Symbol, volume * strategy_tp1_close_fraction);
   if(close_lots > 0.0 && QM_TM_PartialClose(ticket, close_lots, QM_EXIT_PARTIAL))
      g_tp1_done = true;
  }

bool Strategy_ExitSignal()
  {
   g_strategy_exit_reason = QM_EXIT_STRATEGY;

   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   if(!SelectOurPosition(ticket, position_type))
      return false;

   if(!g_tp1_done)
     {
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      const int h4_seconds = PeriodSeconds(PERIOD_H4);
      if(opened > 0 && h4_seconds > 0 &&
         TimeCurrent() - opened >= strategy_time_stop_h4_bars * h4_seconds)
        {
         g_strategy_exit_reason = QM_EXIT_TIME_STOP;
         return true;
        }
     }

   if(!g_strategy_new_bar)
      return false;

   MqlRates h4[];
   if(!LoadRates(PERIOD_H4, strategy_cg_period + 5, h4))
      return false;

   const bool is_buy = (position_type == POSITION_TYPE_BUY);
   if(is_buy && BearishCGCross(h4, 1))
     {
      g_strategy_exit_reason = QM_EXIT_OPPOSITE_SIGNAL;
      return true;
     }
   if(!is_buy && BullishCGCross(h4, 1))
     {
      g_strategy_exit_reason = QM_EXIT_OPPOSITE_SIGNAL;
      return true;
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
                        60,
                        60,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1486_ehlers-cg-oscillator-cross-h4\"}");
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

   g_strategy_new_bar = QM_IsNewBar();

   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, g_strategy_exit_reason);
        }
     }

   if(!g_strategy_new_bar)
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
