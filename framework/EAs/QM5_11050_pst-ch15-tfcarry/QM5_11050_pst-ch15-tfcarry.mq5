#property strict
#property version   "5.0"
#property description "QM5_11050 pst-ch15-tfcarry"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11050;
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
input int    strategy_warmup_bars        = 300;
input int    strategy_vol_period         = 60;
input int    strategy_ewmac_fast_1       = 16;
input int    strategy_ewmac_slow_1       = 64;
input int    strategy_ewmac_fast_2       = 32;
input int    strategy_ewmac_slow_2       = 128;
input int    strategy_ewmac_fast_3       = 64;
input int    strategy_ewmac_slow_3       = 256;
input double strategy_entry_forecast     = 5.0;
input double strategy_exit_forecast      = 1.0;
input int    strategy_atr_period         = 20;
input double strategy_atr_sl_mult        = 3.0;
input bool   strategy_use_carry_proxy    = false;
input int    strategy_spread_filter_days = 60;

double g_last_combined_forecast = 0.0;
bool   g_last_forecast_valid = false;
bool   g_suppress_next_entry = false;
double g_spread_points[60];
int    g_spread_samples = 0;
int    g_spread_cursor = 0;

double ClampForecast(const double value)
  {
   if(value > 20.0)
      return 20.0;
   if(value < -20.0)
      return -20.0;
   return value;
  }

bool HasWarmupBars()
  {
   if(strategy_warmup_bars <= 0)
      return true;

   MqlRates rates[];
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, strategy_warmup_bars, rates); // perf-allowed: D1 warmup check inside framework new-bar entry hook.
   return (copied >= strategy_warmup_bars);
  }

double DailyReturnVolatility()
  {
   if(strategy_vol_period < 2)
      return 0.0;

   MqlRates rates[];
   const int requested = strategy_vol_period + 1;
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, requested, rates); // perf-allowed: D1 return-volatility sample inside framework new-bar entry hook.
   if(copied < requested)
      return 0.0;

   double sum = 0.0;
   double sum_sq = 0.0;
   int samples = 0;
   for(int i = 0; i < copied - 1; ++i)
     {
      if(rates[i].close <= 0.0 || rates[i + 1].close <= 0.0)
         continue;
      const double ret = rates[i].close - rates[i + 1].close;
      sum += ret;
      sum_sq += ret * ret;
      samples++;
     }

   if(samples < 2)
      return 0.0;

   const double mean = sum / samples;
   const double variance = (sum_sq / samples) - (mean * mean);
   if(variance <= 0.0)
      return 0.0;

   return MathSqrt(variance);
  }

double EwmacComponent(const int fast_period,
                      const int slow_period,
                      const double scalar,
                      const double volatility)
  {
   if(fast_period <= 0 || slow_period <= fast_period || volatility <= 0.0)
      return 0.0;

   const double ema_fast = QM_EMA(_Symbol, PERIOD_D1, fast_period, 1);
   const double ema_slow = QM_EMA(_Symbol, PERIOD_D1, slow_period, 1);
   if(ema_fast <= 0.0 || ema_slow <= 0.0)
      return 0.0;

   return ClampForecast(scalar * (ema_fast - ema_slow) / volatility);
  }

bool CalculateCombinedForecast(double &combined)
  {
   combined = 0.0;
   if(!HasWarmupBars())
      return false;

   const double volatility = DailyReturnVolatility();
   if(volatility <= 0.0)
      return false;

   const double ewmac16_64 = EwmacComponent(strategy_ewmac_fast_1, strategy_ewmac_slow_1, 3.75, volatility);
   const double ewmac32_128 = EwmacComponent(strategy_ewmac_fast_2, strategy_ewmac_slow_2, 2.65, volatility);
   const double ewmac64_256 = EwmacComponent(strategy_ewmac_fast_3, strategy_ewmac_slow_3, 1.87, volatility);

   // Carry is intentionally skipped unless a deterministic historical DWX proxy
   // is later supplied; trend coefficients are renormalized from the card's
   // 0.21/0.08/0.21 weights.
   combined = 1.31 * ((0.42 * ewmac16_64) +
                      (0.16 * ewmac32_128) +
                      (0.42 * ewmac64_256));
   return true;
  }

void UpdateSpreadSample()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0 || ask < bid)
      return;

   g_spread_points[g_spread_cursor] = (ask - bid) / point;
   g_spread_cursor = (g_spread_cursor + 1) % 60;
   if(g_spread_samples < 60)
      g_spread_samples++;
  }

double MedianObservedSpread()
  {
   if(g_spread_samples <= 0)
      return 0.0;

   double samples[];
   ArrayResize(samples, g_spread_samples);
   for(int i = 0; i < g_spread_samples; ++i)
      samples[i] = g_spread_points[i];

   ArraySort(samples);
   const int mid = g_spread_samples / 2;
   if((g_spread_samples % 2) == 1)
      return samples[mid];
   return (samples[mid - 1] + samples[mid]) * 0.5;
  }

bool SpreadAllowsEntry()
  {
   if(strategy_spread_filter_days <= 0 || g_spread_samples < MathMin(strategy_spread_filter_days, 60))
      return true;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double median = MedianObservedSpread();
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0 || median <= 0.0)
      return false;

   const double current = (ask - bid) / point;
   return (current <= 2.0 * median);
  }

bool GetOurPosition(ENUM_POSITION_TYPE &position_type)
  {
   position_type = POSITION_TYPE_BUY;

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

      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }

   return false;
  }

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

   UpdateSpreadSample();

   double combined = 0.0;
   if(!CalculateCombinedForecast(combined))
     {
      g_last_forecast_valid = false;
      return false;
     }

   g_last_combined_forecast = combined;
   g_last_forecast_valid = true;

   if(g_suppress_next_entry)
     {
      g_suppress_next_entry = false;
      return false;
     }

   if(!SpreadAllowsEntry())
      return false;

   ENUM_POSITION_TYPE existing_type;
   if(GetOurPosition(existing_type))
      return false;

   if(combined >= strategy_entry_forecast)
      req.type = QM_BUY;
   else if(combined <= -strategy_entry_forecast)
      req.type = QM_SELL;
   else
      return false;

   const double entry = QM_EntryMarketPrice(req.type);
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.reason = (req.type == QM_BUY) ? "PST_CH15_TF_LONG" : "PST_CH15_TF_SHORT";
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   if(!g_last_forecast_valid)
      return false;

   ENUM_POSITION_TYPE position_type;
   if(!GetOurPosition(position_type))
      return false;

   if(position_type == POSITION_TYPE_BUY && g_last_combined_forecast <= strategy_exit_forecast)
     {
      g_suppress_next_entry = true;
      return true;
     }

   if(position_type == POSITION_TYPE_SELL && g_last_combined_forecast >= -strategy_exit_forecast)
     {
      g_suppress_next_entry = true;
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
// Framework wiring — do NOT edit below this line unless you know why.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_11050_pst-ch15-tfcarry\"}");
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
