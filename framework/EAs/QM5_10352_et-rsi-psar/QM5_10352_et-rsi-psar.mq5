#property strict
#property version   "5.0"
#property description "QM5_10352 Elite Trader RSI of PSAR Reversal"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 10352;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal        = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance      = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_timeframe       = PERIOD_M30;
input int             strategy_rsi_period      = 14;
input double          strategy_psar_step       = 0.02;
input double          strategy_psar_max        = 0.20;
input int             strategy_swing_window    = 2;
input int             strategy_swing_lookback  = 20;
input int             strategy_atr_period      = 14;
input double          strategy_atr_fallback    = 1.5;
input double          strategy_atr_max_stop    = 3.0;
input int             strategy_spread_median_bars = 50;
input double          strategy_spread_median_mult = 2.5;

bool g_cached_long_exit = false;
bool g_cached_short_exit = false;

double Strategy_NormalizePrice(const double price)
  {
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   return NormalizeDouble(price, digits);
  }

bool Strategy_LoadRates(MqlRates &rates[], const int bars_needed)
  {
   ArrayResize(rates, bars_needed);
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, strategy_timeframe, 1, bars_needed, rates); // perf-allowed: called only from the framework new-bar entry hook.
   return (copied >= bars_needed);
  }

void Strategy_ComputePSAR(const MqlRates &rates[], const int bars, double &psar[])
  {
   ArrayResize(psar, bars);
   if(bars < 3)
      return;

   double high[];
   double low[];
   ArrayResize(high, bars);
   ArrayResize(low, bars);
   for(int j = 0; j < bars; ++j)
     {
      const int src = bars - 1 - j;
      high[j] = rates[src].high;
      low[j] = rates[src].low;
     }

   bool rising = (rates[bars - 2].close > rates[bars - 1].close);
   double af = strategy_psar_step;
   double ep = rising ? high[0] : low[0];
   psar[0] = rising ? low[0] : high[0];

   for(int j = 1; j < bars; ++j)
     {
      double next = psar[j - 1] + af * (ep - psar[j - 1]);
      if(rising)
        {
         next = MathMin(next, low[j - 1]);
         if(j > 1)
            next = MathMin(next, low[j - 2]);
         if(low[j] < next)
           {
            rising = false;
            psar[j] = ep;
            ep = low[j];
            af = strategy_psar_step;
           }
         else
           {
            psar[j] = next;
            if(high[j] > ep)
              {
               ep = high[j];
               af = MathMin(strategy_psar_max, af + strategy_psar_step);
              }
           }
        }
      else
        {
         next = MathMax(next, high[j - 1]);
         if(j > 1)
            next = MathMax(next, high[j - 2]);
         if(high[j] > next)
           {
            rising = true;
            psar[j] = ep;
            ep = high[j];
            af = strategy_psar_step;
           }
         else
           {
            psar[j] = next;
            if(low[j] < ep)
              {
               ep = low[j];
               af = MathMin(strategy_psar_max, af + strategy_psar_step);
              }
           }
        }
     }
  }

bool Strategy_ComputeRsiSeries(const double &value[], const int bars, const int period, double &rsi[])
  {
   ArrayResize(rsi, bars);
   for(int i = 0; i < bars; ++i)
      rsi[i] = 50.0;
   if(period <= 1 || bars <= period + 3)
      return false;

   double gain = 0.0;
   double loss = 0.0;
   for(int i = 1; i <= period; ++i)
     {
      const double change = value[i] - value[i - 1];
      if(change > 0.0)
         gain += change;
      else
         loss -= change;
     }

   double avg_gain = gain / period;
   double avg_loss = loss / period;
   rsi[period] = (avg_loss <= 0.0) ? 100.0 : 100.0 - (100.0 / (1.0 + avg_gain / avg_loss));

   for(int i = period + 1; i < bars; ++i)
     {
      const double change = value[i] - value[i - 1];
      const double up = (change > 0.0) ? change : 0.0;
      const double down = (change < 0.0) ? -change : 0.0;
      avg_gain = ((avg_gain * (period - 1)) + up) / period;
      avg_loss = ((avg_loss * (period - 1)) + down) / period;
      rsi[i] = (avg_loss <= 0.0) ? 100.0 : 100.0 - (100.0 / (1.0 + avg_gain / avg_loss));
     }

   return true;
  }

bool Strategy_LatestSwing(const MqlRates &rates[], const int bars, const bool want_low, double &price)
  {
   price = 0.0;
   const int w = MathMax(1, strategy_swing_window);
   const int min_chrono = w;
   const int max_chrono = bars - 1 - w;
   if(max_chrono <= min_chrono)
      return false;

   const int lower = MathMax(min_chrono, bars - 1 - strategy_swing_lookback);
   for(int j = max_chrono; j >= lower; --j)
     {
      const int series_idx = bars - 1 - j;
      const double candidate = want_low ? rates[series_idx].low : rates[series_idx].high;
      bool ok = true;
      for(int k = 1; k <= w; ++k)
        {
         const int old_idx = bars - 1 - (j - k);
         const int new_idx = bars - 1 - (j + k);
         if(want_low)
           {
            if(candidate >= rates[old_idx].low || candidate >= rates[new_idx].low)
              {
               ok = false;
               break;
              }
           }
         else
           {
            if(candidate <= rates[old_idx].high || candidate <= rates[new_idx].high)
              {
               ok = false;
               break;
              }
           }
        }
      if(ok)
        {
         price = candidate;
         return true;
        }
     }
   return false;
  }

double Strategy_MedianSpreadPoints(const MqlRates &rates[], const int bars)
  {
   const int n = MathMin(MathMin(strategy_spread_median_bars, bars), 100);
   if(n <= 0)
      return 0.0;

   double spreads[];
   ArrayResize(spreads, n);
   int count = 0;
   for(int i = 0; i < n; ++i)
     {
      if(rates[i].spread <= 0)
         continue;
      spreads[count] = (double)rates[i].spread;
      count++;
     }
   if(count <= 0)
      return 0.0;

   for(int i = 1; i < count; ++i)
     {
      const double x = spreads[i];
      int j = i - 1;
      while(j >= 0 && spreads[j] > x)
        {
         spreads[j + 1] = spreads[j];
         j--;
        }
      spreads[j + 1] = x;
     }

   if((count % 2) == 1)
      return spreads[count / 2];
   return 0.5 * (spreads[count / 2 - 1] + spreads[count / 2]);
  }

bool Strategy_RefreshState(int &signal, double &swing_low, double &swing_high, double &median_spread)
  {
   signal = 0;
   swing_low = 0.0;
   swing_high = 0.0;
   median_spread = 0.0;
   g_cached_long_exit = false;
   g_cached_short_exit = false;

   if(strategy_rsi_period < 2 || strategy_swing_window < 1 || strategy_swing_lookback < (strategy_swing_window * 2 + 1))
      return false;

   const int bars_needed = MathMax(80, strategy_rsi_period + strategy_swing_lookback + strategy_swing_window + 10);
   MqlRates rates[];
   if(!Strategy_LoadRates(rates, bars_needed))
      return false;

   double psar[];
   double rsi[];
   Strategy_ComputePSAR(rates, bars_needed, psar);
   if(!Strategy_ComputeRsiSeries(psar, bars_needed, strategy_rsi_period, rsi))
      return false;

   const int latest = bars_needed - 1;
   const double rsi_1 = rsi[latest];
   const double rsi_2 = rsi[latest - 1];
   const double rsi_3 = rsi[latest - 2];
   const bool latest_blue = (rsi_1 > rsi_2);
   const bool prev_blue = (rsi_2 > rsi_3);
   const bool long_signal = (latest_blue && !prev_blue && rsi_1 < 50.0);
   const bool short_signal = (!latest_blue && prev_blue && rsi_1 > 50.0);

   if(long_signal)
      signal = 1;
   else if(short_signal)
      signal = -1;

   const bool has_low = Strategy_LatestSwing(rates, bars_needed, true, swing_low);
   const bool has_high = Strategy_LatestSwing(rates, bars_needed, false, swing_high);
   median_spread = Strategy_MedianSpreadPoints(rates, bars_needed);

   const double close_1 = rates[0].close;
   g_cached_long_exit = short_signal || (has_low && close_1 < swing_low);
   g_cached_short_exit = long_signal || (has_high && close_1 > swing_high);
   return true;
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

   int signal = 0;
   double swing_low = 0.0;
   double swing_high = 0.0;
   double median_spread = 0.0;
   if(!Strategy_RefreshState(signal, swing_low, swing_high, median_spread))
      return false;
   if(signal == 0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   const double current_spread_points = (ask - bid) / point;
   if(median_spread > 0.0 && current_spread_points > strategy_spread_median_mult * median_spread)
      return false;

   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   double entry = (signal > 0) ? ask : bid;
   double sl = 0.0;
   if(signal > 0)
     {
      sl = (swing_low > 0.0 && swing_low < entry) ? swing_low : entry - strategy_atr_fallback * atr;
      req.type = QM_BUY;
      req.reason = "RSIOFPSAR_LONG_BLUE_TURN_BELOW_50";
     }
   else
     {
      sl = (swing_high > 0.0 && swing_high > entry) ? swing_high : entry + strategy_atr_fallback * atr;
      req.type = QM_SELL;
      req.reason = "RSIOFPSAR_SHORT_RED_TURN_ABOVE_50";
     }

   const double stop_distance = MathAbs(entry - sl);
   const double stop_points = stop_distance / point;
   if(stop_points < 4.0 * current_spread_points)
      return false;
   if(stop_distance > strategy_atr_max_stop * atr)
      return false;

   req.sl = Strategy_NormalizePrice(sl);
   req.tp = 0.0;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
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

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY && g_cached_long_exit)
         return true;
      if(type == POSITION_TYPE_SELL && g_cached_short_exit)
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
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10352\",\"ea\":\"QM5_10352_et_rsi_psar\"}");
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
