#property strict
#property version   "5.0"
#property description "QM5_1228 Carver volatility-attenuated EWMAC"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 1228;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

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

input group "Strategy"
input int    strategy_fast_period         = 16;
input int    strategy_slow_multiplier     = 4;
input int    strategy_vol_period          = 25;
input int    strategy_vol_history_bars    = 2500;
input int    strategy_attenuation_ema     = 10;
input double strategy_forecast_scalar     = 10.0;
input double strategy_entry_threshold     = 4.0;
input double strategy_forecast_cap        = 20.0;
input double strategy_attenuation_min     = 0.25;
input double strategy_attenuation_max     = 2.0;
input int    strategy_atr_period          = 20;
input double strategy_atr_stop_mult       = 2.5;
input int    strategy_min_bars            = 500;
input int    strategy_spread_median_days  = 20;
input double strategy_spread_cap_mult     = 2.0;

double g_last_forecast = 0.0;
bool   g_have_forecast = false;

double Strategy_Clamp(const double value, const double lo, const double hi)
  {
   if(value < lo)
      return lo;
   if(value > hi)
      return hi;
   return value;
  }

double Strategy_DailyReturnStdDev(const MqlRates &rates[],
                                  const int shift,
                                  const int period,
                                  const int copied)
  {
   if(period <= 1 || shift < 0 || shift + period >= copied)
      return 0.0;

   double sum = 0.0;
   double sum_sq = 0.0;
   int samples = 0;
   for(int i = 0; i < period; ++i)
     {
      const double c0 = rates[shift + i].close;
      const double c1 = rates[shift + i + 1].close;
      if(c0 <= 0.0 || c1 <= 0.0)
         return 0.0;
      const double r = (c0 / c1) - 1.0;
      sum += r;
      sum_sq += r * r;
      samples++;
     }

   if(samples <= 1)
      return 0.0;
   const double mean = sum / samples;
   const double variance = (sum_sq / samples) - (mean * mean);
   if(variance <= 0.0)
      return 0.0;
   return MathSqrt(variance);
  }

double Strategy_VolAverage(const double &vols[], const int start, const int count)
  {
   if(count <= 0)
      return 0.0;
   double sum = 0.0;
   int samples = 0;
   for(int i = 0; i < count; ++i)
     {
      const double v = vols[start + i];
      if(v <= 0.0)
         return 0.0;
      sum += v;
      samples++;
     }
   if(samples <= 0)
      return 0.0;
   return sum / samples;
  }

double Strategy_VolQuantile(const double &vols[], const int shift, const int history)
  {
   if(history <= 0 || vols[shift] <= 0.0)
      return 0.0;

   int below_or_equal = 0;
   int samples = 0;
   const double current_vol = vols[shift];
   for(int i = 1; i <= history; ++i)
     {
      const double prior_vol = vols[shift + i];
      if(prior_vol <= 0.0)
         continue;
      if(prior_vol <= current_vol)
         below_or_equal++;
      samples++;
     }

   if(samples <= 0)
      return 0.0;
   return (double)below_or_equal / (double)samples;
  }

double Strategy_MedianSpreadPrice(const MqlRates &rates[],
                                  const int copied,
                                  const int lookback)
  {
   if(lookback <= 0 || copied <= 0)
      return 0.0;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;

   double spreads[];
   ArrayResize(spreads, lookback);
   int samples = 0;
   for(int i = 0; i < lookback && i < copied; ++i)
     {
      if(rates[i].spread < 0)
         continue;
      spreads[samples] = (double)rates[i].spread * point;
      samples++;
     }

   if(samples <= 0)
      return 0.0;

   ArrayResize(spreads, samples);
   ArraySort(spreads);
   const int mid = samples / 2;
   if((samples % 2) == 1)
      return spreads[mid];
   return 0.5 * (spreads[mid - 1] + spreads[mid]);
  }

bool Strategy_SpreadAllowsEntry(const MqlRates &rates[], const int copied)
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;
   if(ask <= bid)
      return true;

   const double median_spread = Strategy_MedianSpreadPrice(rates, copied, strategy_spread_median_days);
   if(median_spread <= 0.0)
      return true;

   const double current_spread = ask - bid;
   return (current_spread <= strategy_spread_cap_mult * median_spread);
  }

bool Strategy_ComputeForecast(double &forecast, MqlRates &rates[], int &copied)
  {
   forecast = 0.0;
   copied = 0;

   const int slow_period = strategy_fast_period * strategy_slow_multiplier;
   if(strategy_fast_period <= 1 || strategy_slow_multiplier <= 1 || slow_period <= strategy_fast_period)
      return false;
   if(strategy_vol_period <= 1 || strategy_vol_history_bars <= 10 || strategy_attenuation_ema <= 0)
      return false;

   const int requested = strategy_vol_history_bars + strategy_vol_period + strategy_attenuation_ema + 5;
   ArraySetAsSeries(rates, true);
   copied = CopyRates(_Symbol, PERIOD_D1, 1, requested, rates); // perf-allowed: called from framework QM_IsNewBar-gated entry path.
   if(copied <= 0)
      return false;

   const int effective_history = MathMin(strategy_vol_history_bars,
                                         copied - strategy_vol_period - strategy_attenuation_ema - 1);
   const int required_warmup = MathMax(slow_period + 50, strategy_min_bars);
   if(effective_history < required_warmup)
      return false;

   const int vol_count = effective_history + strategy_attenuation_ema + 1;
   double vols[];
   ArrayResize(vols, vol_count);
   for(int shift = 0; shift < vol_count; ++shift)
     {
      vols[shift] = Strategy_DailyReturnStdDev(rates, shift, strategy_vol_period, copied);
      if(vols[shift] <= 0.0)
         return false;
     }

   const double ema_fast = QM_EMA(_Symbol, PERIOD_D1, strategy_fast_period, 1, PRICE_CLOSE);
   const double ema_slow = QM_EMA(_Symbol, PERIOD_D1, slow_period, 1, PRICE_CLOSE);
   if(ema_fast <= 0.0 || ema_slow <= 0.0 || rates[0].close <= 0.0 || vols[0] <= 0.0)
      return false;

   const double alpha = 2.0 / ((double)strategy_attenuation_ema + 1.0);
   double attenuation_ema = 0.0;
   bool have_attenuation = false;
   for(int shift = strategy_attenuation_ema - 1; shift >= 0; --shift)
     {
      const double ten_year_vol = Strategy_VolAverage(vols, shift, effective_history);
      if(ten_year_vol <= 0.0)
         return false;

      const double vol_quantile = Strategy_VolQuantile(vols, shift, effective_history);
      double attenuation = 2.0 - (1.5 * vol_quantile);
      attenuation = Strategy_Clamp(attenuation, strategy_attenuation_min, strategy_attenuation_max);

      if(!have_attenuation)
        {
         attenuation_ema = attenuation;
         have_attenuation = true;
        }
      else
         attenuation_ema = (alpha * attenuation) + ((1.0 - alpha) * attenuation_ema);
     }

   if(!have_attenuation)
      return false;

   const double ewmac_pct = (ema_fast - ema_slow) / rates[0].close;
   double raw_forecast = (ewmac_pct / vols[0]) * strategy_forecast_scalar;
   forecast = Strategy_Clamp(raw_forecast * attenuation_ema,
                             -strategy_forecast_cap,
                             strategy_forecast_cap);
   return true;
  }

bool Strategy_GetOurPosition(ENUM_POSITION_TYPE &ptype)
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
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
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

   double forecast = 0.0;
   MqlRates rates[];
   int copied = 0;
   if(!Strategy_ComputeForecast(forecast, rates, copied))
      return false;

   g_last_forecast = forecast;
   g_have_forecast = true;

   if(!Strategy_SpreadAllowsEntry(rates, copied))
      return false;

   QM_OrderType order_type = QM_BUY;
   if(forecast > strategy_entry_threshold)
      order_type = QM_BUY;
   else if(forecast < -strategy_entry_threshold)
      order_type = QM_SELL;
   else
      return false;

   const double entry_price = QM_OrderTypeIsBuy(order_type)
                              ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                              : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(entry_price <= 0.0 || atr <= 0.0)
      return false;

   const double stop_price = QM_StopATRFromValue(_Symbol, order_type, entry_price, atr, strategy_atr_stop_mult);
   if(stop_price <= 0.0)
      return false;

   req.type = order_type;
   req.price = 0.0;
   req.sl = stop_price;
   req.tp = 0.0;
   req.reason = QM_OrderTypeIsBuy(order_type) ? "CARVER_VOLATTEN_EWMAC_LONG" : "CARVER_VOLATTEN_EWMAC_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   if(!Strategy_GetOurPosition(ptype))
      return false;

   const int slow_period = strategy_fast_period * strategy_slow_multiplier;
   if(strategy_fast_period <= 1 || strategy_slow_multiplier <= 1 || slow_period <= strategy_fast_period)
      return false;

   const double ema_fast = QM_EMA(_Symbol, PERIOD_D1, strategy_fast_period, 1, PRICE_CLOSE);
   const double ema_slow = QM_EMA(_Symbol, PERIOD_D1, slow_period, 1, PRICE_CLOSE);
   if(ema_fast <= 0.0 || ema_slow <= 0.0)
      return false;

   const double ewmac = ema_fast - ema_slow;
   if(ptype == POSITION_TYPE_BUY && ewmac <= 0.0)
      return true;
   if(ptype == POSITION_TYPE_SELL && ewmac >= 0.0)
      return true;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1228\",\"ea\":\"carver-volatten-ewmac\"}");
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
