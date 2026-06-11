#property strict
#property version   "5.0"
#property description "QM5_9901 ForexFactory Alien DDS Rubber-Band H1"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9901 ff-alien-dds-rubber-h1
// Source: forexalien, Alien's Extraterrestrial Visual Systems, ForexFactory
// Card: D:\QM\strategy_farm\artifacts\cards_approved\QM5_9901_ff-alien-dds-rubber-h1.md
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 9901;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal      = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance    = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours                  = 336;
input string qm_news_min_impact                       = "high";
input QM_NewsMode qm_news_mode_legacy                 = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_rsioma_period       = 14;   // RSIOMA / RSI period
input int    strategy_dds_k               = 8;    // DDS %K period
input int    strategy_dds_d               = 3;    // DDS %D period
input int    strategy_dds_slow            = 3;    // DDS slow period
input int    strategy_stoch_k             = 21;   // Confirmation stoch %K
input int    strategy_stoch_d             = 10;   // Confirmation stoch %D
input int    strategy_stoch_slow          = 10;   // Confirmation stoch slow
input int    strategy_adx_fast            = 21;   // Fast ADX period
input int    strategy_adx_slow            = 42;   // Slow ADX period
input int    strategy_atr_period          = 14;   // ATR period
input int    strategy_lookback_bars       = 5;    // Lookback for DDS/RSI setup check
input double strategy_sl_atr_buffer       = 0.30; // SL buffer as fraction of ATR
input double strategy_sl_min_atr          = 0.50; // Min stop distance (ATR multiples)
input double strategy_sl_max_atr          = 2.00; // Max stop distance (ATR multiples)
input double strategy_tp_r_mult           = 1.80; // TP R-multiple
input int    strategy_time_stop_bars      = 14;   // Max hold in H1 bars
input double strategy_dds_long_max        = 20.0; // DDS must have been below this for long setup
input double strategy_dds_long_cap        = 45.0; // DDS must still be below this at long cross
input double strategy_dds_short_min       = 80.0; // DDS must have been above this for short setup
input double strategy_dds_short_floor     = 55.0; // DDS must still be above this at short cross
input double strategy_adx_min             = 14.0; // Minimum ADX (both periods)
input int    strategy_atr_pct_lookback    = 60;   // Bars for ATR percentile filter
input double strategy_spread_atr_pct      = 0.15; // Max spread as fraction of ATR

// -----------------------------------------------------------------------------
// File-scope state: ATR 20th-percentile, updated once per new bar
// -----------------------------------------------------------------------------
double g_atr_pct20 = 0.0;

// Compute the 20th percentile of the last n ATR values
double ComputeAtrPct20(const int n)
  {
   if(n <= 0)
      return 0.0;
   double arr[];
   ArrayResize(arr, n);
   for(int i = 0; i < n; i++)
      arr[i] = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, i + 1);
   ArraySort(arr);
   int idx = (int)MathFloor(0.20 * (double)n);
   if(idx < 0) idx = 0;
   if(idx >= n) idx = n - 1;
   return arr[idx];
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Block trading if spread too wide or ATR below 20th-percentile volatility floor
bool Strategy_NoTradeFilter()
  {
   const double atr = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, 1);
   if(atr <= 0.0)
      return true;

   // ATR volatility-floor filter (reads cached value; initially passes)
   if(g_atr_pct20 > 0.0 && atr < g_atr_pct20)
      return true;

   // Spread filter: block if spread > 15% of ATR
   const double spread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(spread > strategy_spread_atr_pct * atr)
      return true;

   return false;
  }

// Build entry request from DDS rubber-band conditions on closed H1 bars
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Refresh ATR percentile cache once per new bar
   g_atr_pct20 = ComputeAtrPct20(strategy_atr_pct_lookback);

   const double atr = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const int lb = strategy_lookback_bars;

   // RSI values: index 0 = shift 1 (signal bar), index lb = shift lb+1
   double rsi_arr[];
   ArrayResize(rsi_arr, lb + 1);
   for(int i = 0; i <= lb; i++)
      rsi_arr[i] = QM_RSI(_Symbol, PERIOD_CURRENT, strategy_rsioma_period, i + 1);

   // DDS (double-smoothed stochastic) K/D values
   double dk[], dd[];
   ArrayResize(dk, lb + 1);
   ArrayResize(dd, lb + 1);
   for(int i = 0; i <= lb; i++)
     {
      dk[i] = QM_Stoch_K(_Symbol, PERIOD_CURRENT, strategy_dds_k, strategy_dds_d, strategy_dds_slow, i + 1);
      dd[i] = QM_Stoch_D(_Symbol, PERIOD_CURRENT, strategy_dds_k, strategy_dds_d, strategy_dds_slow, i + 1);
     }

   // Confirmation stochastic (signal bar)
   const double stk1 = QM_Stoch_K(_Symbol, PERIOD_CURRENT, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 1);
   const double std1 = QM_Stoch_D(_Symbol, PERIOD_CURRENT, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 1);

   // ADX values (shift 1 and shift 3 for slope check)
   const double adx21_1 = QM_ADX(_Symbol, PERIOD_CURRENT, strategy_adx_fast, 1);
   const double adx21_3 = QM_ADX(_Symbol, PERIOD_CURRENT, strategy_adx_fast, 3);
   const double adx42_1 = QM_ADX(_Symbol, PERIOD_CURRENT, strategy_adx_slow, 1);
   const double adx42_3 = QM_ADX(_Symbol, PERIOD_CURRENT, strategy_adx_slow, 3);

   // ADX gate: at least one ADX rising vs 2 bars ago AND both >= minimum
   if(!(adx21_1 > adx21_3 || adx42_1 > adx42_3))
      return false;
   if(adx21_1 < strategy_adx_min || adx42_1 < strategy_adx_min)
      return false;

   // Signal-bar structure: low/high of shift=1 bar via framework stop helper
   double bar_low = 0.0, bar_high = 0.0;
   if(!QM_StopRulesReadStructureExtremes(_Symbol, 1, bar_low, bar_high))
      return false;

   // --- LONG setup ---
   // Condition 1: RSIOMA above 50 OR crossed above 50 within last `lb` bars
   bool rsi_long_ok = (rsi_arr[0] > 50.0);
   for(int i = 0; i < lb && !rsi_long_ok; i++)
      if(rsi_arr[i] > 50.0 && rsi_arr[i + 1] <= 50.0)
         rsi_long_ok = true;

   // Condition 2: DDS was below 20 within last lb bars
   bool dds_been_low = false;
   for(int i = 0; i < lb; i++)
      if(dk[i] < strategy_dds_long_max) { dds_been_low = true; break; }

   // Condition 2b: DDS crosses above signal line on signal bar
   const bool dds_cross_up  = (dk[0] > dd[0] && dk[1] <= dd[1]);
   // Condition 2c: DDS still below 45 at the cross (early-turn rubber-band)
   const bool dds_cap_ok    = (dk[0] < strategy_dds_long_cap);
   // Condition 3: confirmation stochastic bullish
   const bool stoch_long    = (stk1 > std1);

   if(rsi_long_ok && dds_been_low && dds_cross_up && dds_cap_ok && stoch_long)
     {
      const double sl_price = bar_low - strategy_sl_atr_buffer * atr;
      const double ask      = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double sl_dist  = ask - sl_price;
      // Reject if stop distance out of ATR bounds
      if(sl_dist < strategy_sl_min_atr * atr || sl_dist > strategy_sl_max_atr * atr)
         return false;

      req.type              = QM_BUY;
      req.price             = 0.0;  // market order
      req.sl                = sl_price;
      req.tp                = QM_TakeRR(_Symbol, QM_BUY, ask, sl_price, strategy_tp_r_mult);
      req.reason            = "DDS_RUBBER_LONG";
      req.symbol_slot       = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
     }

   // --- SHORT setup ---
   // Condition 1: RSIOMA below 50 OR crossed below 50 within last lb bars
   bool rsi_short_ok = (rsi_arr[0] < 50.0);
   for(int i = 0; i < lb && !rsi_short_ok; i++)
      if(rsi_arr[i] < 50.0 && rsi_arr[i + 1] >= 50.0)
         rsi_short_ok = true;

   // Condition 2: DDS was above 80 within last lb bars
   bool dds_been_high = false;
   for(int i = 0; i < lb; i++)
      if(dk[i] > strategy_dds_short_min) { dds_been_high = true; break; }

   // Condition 2b: DDS crosses below signal line on signal bar
   const bool dds_cross_down = (dk[0] < dd[0] && dk[1] >= dd[1]);
   // Condition 2c: DDS still above 55 at the cross (early-turn rubber-band)
   const bool dds_floor_ok   = (dk[0] > strategy_dds_short_floor);
   // Condition 3: confirmation stochastic bearish
   const bool stoch_short    = (stk1 < std1);

   if(rsi_short_ok && dds_been_high && dds_cross_down && dds_floor_ok && stoch_short)
     {
      const double sl_price = bar_high + strategy_sl_atr_buffer * atr;
      const double bid      = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double sl_dist  = sl_price - bid;
      if(sl_dist < strategy_sl_min_atr * atr || sl_dist > strategy_sl_max_atr * atr)
         return false;

      req.type              = QM_SELL;
      req.price             = 0.0;  // market order
      req.sl                = sl_price;
      req.tp                = QM_TakeRR(_Symbol, QM_SELL, bid, sl_price, strategy_tp_r_mult);
      req.reason            = "DDS_RUBBER_SHORT";
      req.symbol_slot       = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
     }

   return false;
  }

// No dynamic trade management: SL/TP set at entry; exits via ExitSignal
void Strategy_ManageOpenPosition()
  {
  }

// Exit: DDS or RSI cross against position, or time stop (14 H1 bars)
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   ENUM_POSITION_TYPE pos_type = POSITION_TYPE_BUY;
   datetime open_time = 0;
   bool found = false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      pos_type  = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      found = true;
      break;
     }
   if(!found)
      return false;

   // Time stop: close after strategy_time_stop_bars H1 periods
   if((int)(TimeCurrent() - open_time) >= strategy_time_stop_bars * PeriodSeconds(PERIOD_H1))
      return true;

   // DDS signal-line reversal cross against position direction
   const double dk1 = QM_Stoch_K(_Symbol, PERIOD_CURRENT, strategy_dds_k, strategy_dds_d, strategy_dds_slow, 1);
   const double dd1 = QM_Stoch_D(_Symbol, PERIOD_CURRENT, strategy_dds_k, strategy_dds_d, strategy_dds_slow, 1);
   const double dk2 = QM_Stoch_K(_Symbol, PERIOD_CURRENT, strategy_dds_k, strategy_dds_d, strategy_dds_slow, 2);
   const double dd2 = QM_Stoch_D(_Symbol, PERIOD_CURRENT, strategy_dds_k, strategy_dds_d, strategy_dds_slow, 2);

   // RSI cross through 50 against position direction
   const double rsi1 = QM_RSI(_Symbol, PERIOD_CURRENT, strategy_rsioma_period, 1);
   const double rsi2 = QM_RSI(_Symbol, PERIOD_CURRENT, strategy_rsioma_period, 2);

   if(pos_type == POSITION_TYPE_BUY)
     {
      if(dk1 < dd1 && dk2 >= dd2)     return true;  // DDS crossed below signal
      if(rsi1 < 50.0 && rsi2 >= 50.0) return true;  // RSI crossed below 50
     }
   else
     {
      if(dk1 > dd1 && dk2 <= dd2)     return true;  // DDS crossed above signal
      if(rsi1 > 50.0 && rsi2 <= 50.0) return true;  // RSI crossed above 50
     }

   return false;
  }

// News filter hook: defer entirely to the 2-axis framework filter
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line
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
