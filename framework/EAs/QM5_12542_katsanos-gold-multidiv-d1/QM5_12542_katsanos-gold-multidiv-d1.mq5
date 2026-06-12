#property strict
#property version   "5.0"
#property description "QM5_12542 Katsanos Gold Multiple Intermarket Divergence"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12542;
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
input int    strategy_yield_lookback       = 15;
input int    strategy_regression_lookback  = 300;
input int    strategy_imo_lookback         = 200;
input int    strategy_imo_ma_period        = 3;
input double strategy_upper_extreme        = 80.0;
input double strategy_lower_extreme        = 20.0;
input int    strategy_alert_valid_bars     = 3;
input int    strategy_stoch_k_period       = 5;
input int    strategy_stoch_ma_period      = 3;
input int    strategy_roc_period           = 10;
input int    strategy_atr_period           = 14;
input double strategy_atr_sl_mult          = 2.5;
input int    strategy_time_exit_bars       = 50;
input int    strategy_history_bars         = 620;
input string strategy_base_symbol          = "XAUUSD.DWX";
input string strategy_xag_symbol           = "XAGUSD.DWX";
input string strategy_eurusd_symbol        = "EURUSD.DWX";
input string strategy_usdjpy_symbol        = "USDJPY.DWX";
input string strategy_gbpusd_symbol        = "GBPUSD.DWX";
input string strategy_usdcad_symbol        = "USDCAD.DWX";
input string strategy_usdchf_symbol        = "USDCHF.DWX";

bool g_exit_long_on_opposite = false;
bool g_exit_short_on_opposite = false;

bool EnsureBasketReady()
  {
   static bool ready = false;
   if(ready)
      return true;

   string symbols[];
   ArrayResize(symbols, 7);
   symbols[0] = strategy_base_symbol;
   symbols[1] = strategy_xag_symbol;
   symbols[2] = strategy_eurusd_symbol;
   symbols[3] = strategy_usdjpy_symbol;
   symbols[4] = strategy_gbpusd_symbol;
   symbols[5] = strategy_usdcad_symbol;
   symbols[6] = strategy_usdchf_symbol;

   QM_SymbolGuardInit(symbols);
   QM_BasketWarmupHistory(symbols, PERIOD_D1, strategy_history_bars);

   for(int i = 0; i < ArraySize(symbols); ++i)
     {
      if(!SymbolSelect(symbols[i], true))
         return false;
     }

   ready = true;
   return true;
  }

bool LoadCloseSeries(const string symbol, double &close_values[])
  {
   ArrayResize(close_values, strategy_history_bars);
   ArraySetAsSeries(close_values, true);
   const int copied = CopyClose(symbol, PERIOD_D1, 0, strategy_history_bars, close_values); // perf-allowed: fixed D1 basket window, called from the skeleton's closed-bar entry gate.
   return (copied >= strategy_history_bars);
  }

bool BuildDxyProxy(const double &eurusd[],
                   const double &usdjpy[],
                   const double &gbpusd[],
                   const double &usdcad[],
                   const double &usdchf[],
                   double &dxy_proxy[])
  {
   const int n = strategy_history_bars;
   ArrayResize(dxy_proxy, n);
   ArraySetAsSeries(dxy_proxy, true);

   for(int i = 0; i < n; ++i)
     {
      if(eurusd[i] <= 0.0 || usdjpy[i] <= 0.0 || gbpusd[i] <= 0.0 ||
         usdcad[i] <= 0.0 || usdchf[i] <= 0.0)
         return false;

      dxy_proxy[i] = -0.601 * MathLog(eurusd[i])
                     +0.142 * MathLog(usdjpy[i])
                     -0.124 * MathLog(gbpusd[i])
                     +0.095 * MathLog(usdcad[i])
                     +0.038 * MathLog(usdchf[i]);
     }

   return true;
  }

bool SeriesYield(const double &values[], const int shift, const int lookback, double &out_yield)
  {
   out_yield = 0.0;
   const int later_shift = shift + lookback;
   if(shift < 0 || later_shift >= ArraySize(values))
      return false;
   if(values[later_shift] == 0.0)
      return false;

   out_yield = 100.0 * (values[shift] - values[later_shift]) / MathAbs(values[later_shift]);
   return true;
  }

bool RegressionDivergence(const double &base_values[],
                          const double &partner_values[],
                          const int shift,
                          const int corr_sign,
                          double &out_divergence)
  {
   out_divergence = 0.0;
   if(shift + strategy_regression_lookback + strategy_yield_lookback >= ArraySize(base_values) ||
      shift + strategy_regression_lookback + strategy_yield_lookback >= ArraySize(partner_values))
      return false;

   double sum_x = 0.0;
   double sum_y = 0.0;
   for(int i = 0; i < strategy_regression_lookback; ++i)
     {
      double x = 0.0;
      double y = 0.0;
      if(!SeriesYield(partner_values, shift + i, strategy_yield_lookback, x) ||
         !SeriesYield(base_values, shift + i, strategy_yield_lookback, y))
         return false;
      sum_x += x;
      sum_y += y;
     }

   const double mean_x = sum_x / strategy_regression_lookback;
   const double mean_y = sum_y / strategy_regression_lookback;

   double cov_xy = 0.0;
   double var_x = 0.0;
   for(int i = 0; i < strategy_regression_lookback; ++i)
     {
      double x = 0.0;
      double y = 0.0;
      if(!SeriesYield(partner_values, shift + i, strategy_yield_lookback, x) ||
         !SeriesYield(base_values, shift + i, strategy_yield_lookback, y))
         return false;
      const double dx = x - mean_x;
      cov_xy += dx * (y - mean_y);
      var_x += dx * dx;
     }

   double current_x = 0.0;
   double current_y = 0.0;
   if(var_x <= 0.0 ||
      !SeriesYield(partner_values, shift, strategy_yield_lookback, current_x) ||
      !SeriesYield(base_values, shift, strategy_yield_lookback, current_y))
      return false;

   const double regressed_y = (cov_xy / var_x) * current_x;
   out_divergence = ((double)corr_sign) * regressed_y - current_y;
   return true;
  }

bool BuildDivergenceSeries(const double &base_values[],
                           const double &partner_values[],
                           const int corr_sign,
                           const int first_shift,
                           const int count,
                           double &divergences[])
  {
   ArrayResize(divergences, count);
   ArraySetAsSeries(divergences, false);

   for(int i = 0; i < count; ++i)
     {
      if(!RegressionDivergence(base_values, partner_values, first_shift + i, corr_sign, divergences[i]))
         return false;
     }
   return true;
  }

bool DivRange(const double &divergences[],
              const int first_shift,
              const int shift,
              double &lowest,
              double &highest)
  {
   lowest = DBL_MAX;
   highest = -DBL_MAX;
   const int start = shift - first_shift;
   if(start < 0 || start + strategy_imo_lookback > ArraySize(divergences))
      return false;

   for(int i = 0; i < strategy_imo_lookback; ++i)
     {
      const double v = divergences[start + i];
      if(v < lowest)
         lowest = v;
      if(v > highest)
         highest = v;
     }

   return (highest > lowest);
  }

bool RawIMOFromDivs(const double &divergences[],
                    const int first_shift,
                    const int shift,
                    double &out_imo)
  {
   out_imo = 50.0;
   double num_sum = 0.0;
   double range_sum = 0.0;

   for(int i = 0; i < strategy_imo_ma_period; ++i)
     {
      const int s = shift + i;
      const int idx = s - first_shift;
      if(idx < 0 || idx >= ArraySize(divergences))
         return false;

      double lowest = 0.0;
      double highest = 0.0;
      if(!DivRange(divergences, first_shift, s, lowest, highest))
         return false;

      num_sum += divergences[idx] - lowest;
      range_sum += highest - lowest;
     }

   if(range_sum <= 0.0)
      return false;

   out_imo = 100.0 * num_sum / range_sum;
   return true;
  }

bool CombinedSmoothedIMO(const double &xag_divs[],
                         const double &dxy_divs[],
                         const int first_shift,
                         const int shift,
                         double &out_imo)
  {
   double xag_imo = 0.0;
   double dxy_imo = 0.0;
   if(!RawIMOFromDivs(xag_divs, first_shift, shift, xag_imo) ||
      !RawIMOFromDivs(dxy_divs, first_shift, shift, dxy_imo))
      return false;

   out_imo = (xag_imo + dxy_imo) * 0.5;
   return true;
  }

bool CrossedBelowExtreme(const double &xag_divs[],
                         const double &dxy_divs[],
                         const int first_shift,
                         const int shift,
                         const double level)
  {
   double now_imo = 0.0;
   double prev_imo = 0.0;
   if(!CombinedSmoothedIMO(xag_divs, dxy_divs, first_shift, shift, now_imo) ||
      !CombinedSmoothedIMO(xag_divs, dxy_divs, first_shift, shift + 1, prev_imo))
      return false;

   return (prev_imo >= level && now_imo < level);
  }

bool CrossedAboveExtreme(const double &xag_divs[],
                         const double &dxy_divs[],
                         const int first_shift,
                         const int shift,
                         const double level)
  {
   double now_imo = 0.0;
   double prev_imo = 0.0;
   if(!CombinedSmoothedIMO(xag_divs, dxy_divs, first_shift, shift, now_imo) ||
      !CombinedSmoothedIMO(xag_divs, dxy_divs, first_shift, shift + 1, prev_imo))
      return false;

   return (prev_imo <= level && now_imo > level);
  }

bool CrossedBelowWithin(const double &xag_divs[],
                        const double &dxy_divs[],
                        const int first_shift,
                        const double level,
                        const int valid_bars)
  {
   for(int s = 1; s <= valid_bars; ++s)
      if(CrossedBelowExtreme(xag_divs, dxy_divs, first_shift, s, level))
         return true;
   return false;
  }

bool CrossedAboveWithin(const double &xag_divs[],
                        const double &dxy_divs[],
                        const int first_shift,
                        const double level,
                        const int valid_bars)
  {
   for(int s = 1; s <= valid_bars; ++s)
      if(CrossedAboveExtreme(xag_divs, dxy_divs, first_shift, s, level))
         return true;
   return false;
  }

bool StochasticCrossUp()
  {
   const double k_now = QM_Stoch_K(_Symbol, PERIOD_D1, strategy_stoch_k_period, strategy_stoch_ma_period, 1, 1);
   const double d_now = QM_Stoch_D(_Symbol, PERIOD_D1, strategy_stoch_k_period, strategy_stoch_ma_period, 1, 1);
   const double k_prev = QM_Stoch_K(_Symbol, PERIOD_D1, strategy_stoch_k_period, strategy_stoch_ma_period, 1, 2);
   const double d_prev = QM_Stoch_D(_Symbol, PERIOD_D1, strategy_stoch_k_period, strategy_stoch_ma_period, 1, 2);
   return (k_prev <= d_prev && k_now > d_now);
  }

bool StochasticCrossDown()
  {
   const double k_now = QM_Stoch_K(_Symbol, PERIOD_D1, strategy_stoch_k_period, strategy_stoch_ma_period, 1, 1);
   const double d_now = QM_Stoch_D(_Symbol, PERIOD_D1, strategy_stoch_k_period, strategy_stoch_ma_period, 1, 1);
   const double k_prev = QM_Stoch_K(_Symbol, PERIOD_D1, strategy_stoch_k_period, strategy_stoch_ma_period, 1, 2);
   const double d_prev = QM_Stoch_D(_Symbol, PERIOD_D1, strategy_stoch_k_period, strategy_stoch_ma_period, 1, 2);
   return (k_prev >= d_prev && k_now < d_now);
  }

bool CurrentPositionType(ENUM_POSITION_TYPE &position_type)
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
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }
   return false;
  }

bool TimeExitDue()
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

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      const int bars_held = iBarShift(_Symbol, PERIOD_D1, opened, false);
      if(bars_held >= strategy_time_exit_bars)
         return true;
     }
   return false;
  }

bool BuildSignalState(bool &long_entry,
                      bool &short_entry,
                      bool &long_exit,
                      bool &short_exit)
  {
   long_entry = false;
   short_entry = false;
   long_exit = false;
   short_exit = false;

   if(strategy_yield_lookback <= 0 ||
      strategy_regression_lookback <= 20 ||
      strategy_imo_lookback <= 20 ||
      strategy_imo_ma_period <= 0 ||
      strategy_alert_valid_bars <= 0 ||
      strategy_roc_period <= 0)
      return false;

   if(!EnsureBasketReady())
      return false;

   double xau[];
   double xag[];
   double eurusd[];
   double usdjpy[];
   double gbpusd[];
   double usdcad[];
   double usdchf[];
   double dxy[];

   if(!LoadCloseSeries(strategy_base_symbol, xau) ||
      !LoadCloseSeries(strategy_xag_symbol, xag) ||
      !LoadCloseSeries(strategy_eurusd_symbol, eurusd) ||
      !LoadCloseSeries(strategy_usdjpy_symbol, usdjpy) ||
      !LoadCloseSeries(strategy_gbpusd_symbol, gbpusd) ||
      !LoadCloseSeries(strategy_usdcad_symbol, usdcad) ||
      !LoadCloseSeries(strategy_usdchf_symbol, usdchf) ||
      !BuildDxyProxy(eurusd, usdjpy, gbpusd, usdcad, usdchf, dxy))
      return false;

   const int first_shift = 1;
   const int div_count = strategy_imo_lookback + strategy_alert_valid_bars +
                         strategy_imo_ma_period + 8;
   double xag_divs[];
   double dxy_divs[];
   if(!BuildDivergenceSeries(xau, xag, +1, first_shift, div_count, xag_divs) ||
      !BuildDivergenceSeries(xau, dxy, -1, first_shift, div_count, dxy_divs))
      return false;

   double xag_roc = 0.0;
   double dxy_roc = 0.0;
   if(!SeriesYield(xag, 1, strategy_roc_period, xag_roc) ||
      !SeriesYield(dxy, 1, strategy_roc_period, dxy_roc))
      return false;

   const double combined_divergence = (xag_divs[0] + dxy_divs[0]) * 0.5;

   const bool high_reversal = CrossedBelowWithin(xag_divs, dxy_divs, first_shift,
                                                 strategy_upper_extreme,
                                                 strategy_alert_valid_bars);
   const bool low_reversal = CrossedAboveWithin(xag_divs, dxy_divs, first_shift,
                                                strategy_lower_extreme,
                                                strategy_alert_valid_bars);

   long_entry = high_reversal &&
                StochasticCrossUp() &&
                xag_roc > 0.0 &&
                dxy_roc < 0.0 &&
                combined_divergence > 0.0;

   short_entry = low_reversal &&
                 StochasticCrossDown() &&
                 xag_roc < 0.0 &&
                 dxy_roc > 0.0 &&
                 combined_divergence < 0.0;

   long_exit = low_reversal;
   short_exit = high_reversal;
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Symbol != strategy_base_symbol)
      return true;
   return !EnsureBasketReady();
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

   bool long_entry = false;
   bool short_entry = false;
   bool long_exit = false;
   bool short_exit = false;
   if(!BuildSignalState(long_entry, short_entry, long_exit, short_exit))
      return false;

   g_exit_long_on_opposite = long_exit;
   g_exit_short_on_opposite = short_exit;

   if(!long_entry && !short_entry)
      return false;

   req.type = long_entry ? QM_BUY : QM_SELL;
   const double entry_price = long_entry ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.reason = long_entry ? "KATSANOS_MULTIDIV_LONG" : "KATSANOS_MULTIDIV_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies only the initial 2.5x ATR disaster stop; no BE, trailing,
   // partial close, or add-on management is authorized.
  }

bool Strategy_ExitSignal()
  {
   if(TimeExitDue())
      return true;

   ENUM_POSITION_TYPE position_type;
   if(!CurrentPositionType(position_type))
      return false;

   if(position_type == POSITION_TYPE_BUY && g_exit_long_on_opposite)
      return true;
   if(position_type == POSITION_TYPE_SELL && g_exit_short_on_opposite)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12542_katsanos_gold_multidiv_d1\"}");
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
