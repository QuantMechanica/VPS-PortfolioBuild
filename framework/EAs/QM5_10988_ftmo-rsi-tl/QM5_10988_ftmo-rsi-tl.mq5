#property strict
#property version   "5.0"
#property description "QM5_10988 FTMO RSI trendline break"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10988;
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
input int    strategy_rsi_period          = 14;
input int    strategy_ema_period          = 20;
input int    strategy_atr_period          = 14;
input double strategy_atr_sl_mult         = 1.20;
input double strategy_tp_r_multiple       = 2.00;
input int    strategy_rsi_swing_lookback  = 30;
input int    strategy_rsi_fractal_wing    = 2;
input int    strategy_stop_lookback       = 10;
input int    strategy_max_hold_bars       = 36;
input double strategy_neutral_low         = 45.0;
input double strategy_neutral_high        = 55.0;
input int    strategy_spread_lookback     = 20;
input double strategy_spread_median_mult  = 1.50;

double g_spread_median_points = 0.0;
bool   g_spread_median_ready  = false;

double PriceClose(const int shift)
  {
   return iClose(_Symbol, _Period, shift); // perf-allowed: bespoke closed-bar price confirmation inside framework-gated EntrySignal.
  }

double BarHigh(const int shift)
  {
   return iHigh(_Symbol, _Period, shift); // perf-allowed: bounded 10-bar structure stop inside framework-gated EntrySignal.
  }

double BarLow(const int shift)
  {
   return iLow(_Symbol, _Period, shift); // perf-allowed: bounded 10-bar structure stop inside framework-gated EntrySignal.
  }

bool HasOurOpenPosition()
  {
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
      return true;
     }

   return false;
  }

bool CurrentSpreadWithinMedian()
  {
   if(!g_spread_median_ready || g_spread_median_points <= 0.0)
      return true;
   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0)
      return true;
   return ((double)current_spread <= g_spread_median_points * strategy_spread_median_mult);
  }

void RefreshSpreadMedian()
  {
   g_spread_median_ready = false;
   g_spread_median_points = 0.0;

   if(strategy_spread_lookback < 3)
      return;

   MqlRates rates[];
   const int copied = CopyRates(_Symbol, _Period, 1, strategy_spread_lookback, rates); // perf-allowed: closed-bar spread median cache; EntrySignal is called only after QM_IsNewBar().
   if(copied < 3)
      return;

   int spreads[];
   ArrayResize(spreads, copied);
   int n = 0;
   for(int i = 0; i < copied; ++i)
     {
      if(rates[i].spread <= 0)
         continue;
      spreads[n] = rates[i].spread;
      n++;
     }

   if(n < 3)
      return;

   ArrayResize(spreads, n);
   ArraySort(spreads);
   if((n % 2) == 1)
      g_spread_median_points = (double)spreads[n / 2];
   else
      g_spread_median_points = 0.5 * (double)(spreads[(n / 2) - 1] + spreads[n / 2]);
   g_spread_median_ready = (g_spread_median_points > 0.0);
  }

bool IsRsiSwingHigh(const int shift)
  {
   const double center = QM_RSI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_rsi_period, shift);
   if(center <= 0.0)
      return false;

   for(int j = 1; j <= strategy_rsi_fractal_wing; ++j)
     {
      if(center <= QM_RSI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_rsi_period, shift + j))
         return false;
      if(center <= QM_RSI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_rsi_period, shift - j))
         return false;
     }

   return true;
  }

bool IsRsiSwingLow(const int shift)
  {
   const double center = QM_RSI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_rsi_period, shift);
   if(center <= 0.0)
      return false;

   for(int j = 1; j <= strategy_rsi_fractal_wing; ++j)
     {
      if(center >= QM_RSI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_rsi_period, shift + j))
         return false;
      if(center >= QM_RSI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_rsi_period, shift - j))
         return false;
     }

   return true;
  }

bool RsiTrendlineBreak(const bool long_side, const int break_shift, double &break_rsi)
  {
   break_rsi = QM_RSI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_rsi_period, break_shift);
   if(break_rsi <= 0.0)
      return false;

   const int min_shift = break_shift + strategy_rsi_fractal_wing;
   const int max_shift = break_shift + strategy_rsi_swing_lookback;

   for(int recent_shift = min_shift; recent_shift <= max_shift; ++recent_shift)
     {
      const bool recent_is_swing = long_side ? IsRsiSwingHigh(recent_shift) : IsRsiSwingLow(recent_shift);
      if(!recent_is_swing)
         continue;

      const double recent_rsi = QM_RSI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_rsi_period, recent_shift);
      for(int older_shift = recent_shift + 1; older_shift <= max_shift; ++older_shift)
        {
         const bool older_is_swing = long_side ? IsRsiSwingHigh(older_shift) : IsRsiSwingLow(older_shift);
         if(!older_is_swing)
            continue;

         const double older_rsi = QM_RSI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_rsi_period, older_shift);
         const bool valid_sequence = long_side ? (recent_rsi < older_rsi) : (recent_rsi > older_rsi);
         if(!valid_sequence)
            continue;

         const double slope = (recent_rsi - older_rsi) / (double)(recent_shift - older_shift);
         const double line_at_break = older_rsi + slope * (double)(break_shift - older_shift);
         if(long_side)
            return (break_rsi > line_at_break);
         return (break_rsi < line_at_break);
        }
     }

   return false;
  }

double LowestLow(const int lookback)
  {
   double lowest = DBL_MAX;
   for(int shift = 1; shift <= lookback; ++shift)
     {
      const double low = BarLow(shift);
      if(low > 0.0)
         lowest = MathMin(lowest, low);
     }
   return (lowest == DBL_MAX) ? 0.0 : lowest;
  }

double HighestHigh(const int lookback)
  {
   double highest = -DBL_MAX;
   for(int shift = 1; shift <= lookback; ++shift)
     {
      const double high = BarHigh(shift);
      if(high > 0.0)
         highest = MathMax(highest, high);
     }
   return (highest == -DBL_MAX) ? 0.0 : highest;
  }

void ResetEntryRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool BuildMarketEntry(const bool long_side, QM_EntryRequest &req)
  {
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double entry = long_side ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                  : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double structure = long_side ? LowestLow(strategy_stop_lookback)
                                      : HighestHigh(strategy_stop_lookback);
   if(structure <= 0.0)
      return false;

   const double atr_stop = long_side ? (entry - strategy_atr_sl_mult * atr)
                                     : (entry + strategy_atr_sl_mult * atr);
   const double sl = long_side ? MathMin(structure, atr_stop)
                               : MathMax(structure, atr_stop);
   const double risk_dist = MathAbs(entry - sl);
   if(risk_dist <= 0.0)
      return false;

   req.type = long_side ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = NormalizeDouble(sl, _Digits);
   req.tp = NormalizeDouble(long_side ? (entry + strategy_tp_r_multiple * risk_dist)
                                      : (entry - strategy_tp_r_multiple * risk_dist), _Digits);
   req.reason = long_side ? "FTMO_RSI_TL_LONG" : "FTMO_RSI_TL_SHORT";
   return true;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(HasOurOpenPosition())
      return true;
   if(!CurrentSpreadWithinMedian())
      return true;
   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ResetEntryRequest(req);
   RefreshSpreadMedian();

   if(strategy_rsi_period < 2 || strategy_ema_period < 2 || strategy_atr_period < 2)
      return false;
   if(strategy_rsi_swing_lookback < 6 || strategy_rsi_fractal_wing < 1 || strategy_stop_lookback < 2)
      return false;
   if(strategy_tp_r_multiple <= 0.0 || strategy_atr_sl_mult <= 0.0 || strategy_spread_median_mult <= 0.0)
      return false;
   if(!CurrentSpreadWithinMedian())
      return false;
   if(HasOurOpenPosition())
      return false;

   const double close1 = PriceClose(1);
   const double ema1 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_period, 1);
   if(close1 <= 0.0 || ema1 <= 0.0)
      return false;

   double long_rsi_now = 0.0;
   double long_rsi_prev = 0.0;
   double short_rsi_now = 0.0;
   double short_rsi_prev = 0.0;

   const bool long_break_now = RsiTrendlineBreak(true, 1, long_rsi_now);
   const bool long_break_prev = RsiTrendlineBreak(true, 2, long_rsi_prev);
   const bool short_break_now = RsiTrendlineBreak(false, 1, short_rsi_now);
   const bool short_break_prev = RsiTrendlineBreak(false, 2, short_rsi_prev);

   const bool price_confirms_long = (close1 > ema1);
   const bool price_confirms_short = (close1 < ema1);
   const bool long_signal = price_confirms_long && (long_break_now || long_break_prev);
   const bool short_signal = price_confirms_short && (short_break_now || short_break_prev);

   if(long_signal && short_signal)
      return false;

   if(long_signal)
      return BuildMarketEntry(true, req);
   if(short_signal)
      return BuildMarketEntry(false, req);

   return false;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card specifies no break-even, trailing, partial close, or add-on management.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
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
      const double rsi1 = QM_RSI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_rsi_period, 1);
      const double rsi2 = QM_RSI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_rsi_period, 2);
      if(rsi1 <= 0.0 || rsi2 <= 0.0)
         return false;

      if(pos_type == POSITION_TYPE_BUY && rsi2 >= 50.0 && rsi1 < 50.0)
         return true;
      if(pos_type == POSITION_TYPE_SELL && rsi2 <= 50.0 && rsi1 > 50.0)
         return true;

      const datetime opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      const int period_seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
      if(opened_at > 0 && period_seconds > 0 &&
         TimeCurrent() - opened_at >= strategy_max_hold_bars * period_seconds)
         return true;
     }

   return false;
  }

// News Filter Hook (callable for P8 News Impact phase)
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10988_ftmo-rsi-tl\",\"source\":\"c11dc4d3-bdfb-5076-aeed-5d943e9ef03f\"}");
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
