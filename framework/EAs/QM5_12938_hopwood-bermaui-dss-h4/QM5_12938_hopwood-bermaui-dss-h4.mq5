#property strict
#property version   "5.0"
#property description "QM5_12938 Hopwood Bermaui-DSS H4 Mean-Reversion"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_12938
// Slug: hopwood-bermaui-dss-h4
// Card: artifacts/cards_approved/QM5_12938_hopwood-bermaui-dss-h4.md (g0 APPROVED)
// Source: Steve Hopwood FF thread/254595 + William Blau 1995 (DSS)
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12938;
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
input int    strategy_dss_stoch_period  = 8;      // DSS raw stochastic lookback (%K)
input int    strategy_dss_inner_ema     = 5;      // DSS first EMA smoothing
input int    strategy_dss_outer_ema     = 3;      // DSS second EMA smoothing
input int    strategy_bermaui_lookback  = 20;     // Bermaui dynamic threshold lookback
input double strategy_bermaui_k         = 1.8;    // Bermaui std multiplier (upper/lower threshold)
input double strategy_min_overshoot_mult = 2.0;   // Minimum overshoot gate in std deviations
input int    strategy_d1_ema_period     = 200;    // Higher-TF (D1) trend filter EMA period
input int    strategy_atr_period        = 14;     // ATR period for stops and targets
input double strategy_atr_sl_mult       = 1.5;    // Stop loss multiplier in ATR
input double strategy_atr_tp_mult       = 1.5;    // Take profit multiplier in ATR
input int    strategy_max_hold_bars     = 10;     // Time stop: max holding period in H4 bars
input int    strategy_cooldown_bars     = 6;      // Cooldown between entries in H4 bars
input double strategy_be_atr_mult       = 0.75;   // Break-even profit trigger in ATR
input double strategy_spread_max_atr_mult = 0.3;  // Maximum spread threshold in ATR

// -----------------------------------------------------------------------------
// File-scope cached state (advanced once per closed H4 bar)
// -----------------------------------------------------------------------------
double g_dss_outer_1 = 0.0;
double g_dss_outer_2 = 0.0;
double g_mean_1 = 0.0;
double g_mean_2 = 0.0;
double g_std_1 = 0.0;
double g_std_2 = 0.0;
double g_upper_thr_1 = 0.0;
double g_upper_thr_2 = 0.0;
double g_lower_thr_1 = 0.0;
double g_lower_thr_2 = 0.0;
double g_atr_1 = 0.0;
bool   g_long_signal = false;
bool   g_short_signal = false;
bool   g_state_ready = false;
int    g_bars_since_last_long = 100;
int    g_bars_since_last_short = 100;

// -----------------------------------------------------------------------------
// DSS computation helpers (closed-bar, bounded)
// -----------------------------------------------------------------------------

double DSS_RawStochAtShift(const int period, const int end_shift)
{
   double hh = -DBL_MAX;
   double ll =  DBL_MAX;
   for(int s = end_shift; s < end_shift + period; ++s)
   {
      const double h = iHigh(_Symbol, _Period, s);   // perf-allowed: bounded closed-bar stochastic
      const double l = iLow(_Symbol, _Period, s);    // perf-allowed: bounded closed-bar stochastic
      if(h > hh) hh = h;
      if(l < ll) ll = l;
   }
   const double c = iClose(_Symbol, _Period, end_shift); // perf-allowed: bounded closed-bar stochastic
   const double rng = hh - ll;
   if(rng <= 0.0)
      return 50.0;
   return 100.0 * (c - ll) / rng;
}

double DSS_EMAofSeries(const double &arr[], const int count, const int period)
{
   if(count <= 0) return 0.0;
   const double k = 2.0 / (period + 1.0);
   double ema = arr[count - 1];
   for(int i = count - 2; i >= 0; --i)
      ema = arr[i] * k + ema * (1.0 - k);
   return ema;
}

double DSS_ComputeOuterAtShift(const int end_shift)
{
   const int p1 = strategy_dss_stoch_period;
   const int p2 = strategy_dss_inner_ema;
   const int p3 = strategy_dss_outer_ema;

   const int inner_len = p3 + 8;
   double inner[];
   ArrayResize(inner, inner_len);

   const int rawk_len = p2 + 8;
   double rawk[];
   ArrayResize(rawk, rawk_len);

   for(int j = 0; j < inner_len; ++j)
   {
      const int base = end_shift + j;
      for(int r = 0; r < rawk_len; ++r)
         rawk[r] = DSS_RawStochAtShift(p1, base + r);
      inner[j] = DSS_EMAofSeries(rawk, rawk_len, p2);
   }

   return DSS_EMAofSeries(inner, inner_len, p3);
}

void AdvanceState_OnNewBar()
{
   g_bars_since_last_long++;
   g_bars_since_last_short++;

   g_atr_1 = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);

   const int total_samples = strategy_bermaui_lookback + 2;
   double dss_arr[];
   ArrayResize(dss_arr, total_samples);
   for(int i = 0; i < total_samples; ++i)
   {
      dss_arr[i] = DSS_ComputeOuterAtShift(1 + i);
   }

   g_dss_outer_1 = dss_arr[0];
   g_dss_outer_2 = dss_arr[1];

   double sum1 = 0.0;
   for(int i = 0; i < strategy_bermaui_lookback; ++i)
      sum1 += dss_arr[i];
   g_mean_1 = sum1 / (double)strategy_bermaui_lookback;

   double var1 = 0.0;
   for(int i = 0; i < strategy_bermaui_lookback; ++i)
   {
      double diff = dss_arr[i] - g_mean_1;
      var1 += diff * diff;
   }
   g_std_1 = MathSqrt(var1 / (double)strategy_bermaui_lookback);
   g_upper_thr_1 = g_mean_1 + strategy_bermaui_k * g_std_1;
   g_lower_thr_1 = g_mean_1 - strategy_bermaui_k * g_std_1;

   double sum2 = 0.0;
   for(int i = 0; i < strategy_bermaui_lookback; ++i)
      sum2 += dss_arr[1 + i];
   g_mean_2 = sum2 / (double)strategy_bermaui_lookback;

   double var2 = 0.0;
   for(int i = 0; i < strategy_bermaui_lookback; ++i)
   {
      double diff = dss_arr[1 + i] - g_mean_2;
      var2 += diff * diff;
   }
   g_std_2 = MathSqrt(var2 / (double)strategy_bermaui_lookback);
   g_upper_thr_2 = g_mean_2 + strategy_bermaui_k * g_std_2;
   g_lower_thr_2 = g_mean_2 - strategy_bermaui_k * g_std_2;

   const int d1_bias = QM_Sig_Price_Above_MA(_Symbol, PERIOD_D1, strategy_d1_ema_period, 0.0, 1);

   const bool long_oversold_prev = (g_dss_outer_2 < g_lower_thr_2);
   const bool long_cross_back    = (g_dss_outer_1 >= g_lower_thr_1);
   const bool long_overshoot     = (g_mean_2 - g_dss_outer_2 > strategy_min_overshoot_mult * g_std_2);
   const bool long_d1_trend      = (d1_bias > 0);
   const bool long_cooldown      = (g_bars_since_last_long >= strategy_cooldown_bars);

   g_long_signal = (long_oversold_prev && long_cross_back && long_overshoot && long_d1_trend && long_cooldown);

   const bool short_overbought_prev = (g_dss_outer_2 > g_upper_thr_2);
   const bool short_cross_back      = (g_dss_outer_1 <= g_upper_thr_1);
   const bool short_overshoot       = (g_dss_outer_2 - g_mean_2 > strategy_min_overshoot_mult * g_std_2);
   const bool short_d1_trend        = (d1_bias < 0);
   const bool short_cooldown        = (g_bars_since_last_short >= strategy_cooldown_bars);

   g_short_signal = (short_overbought_prev && short_cross_back && short_overshoot && short_d1_trend && short_cooldown);

   g_state_ready = true;
}

bool Strategy_HasOurPosition()
{
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      return true;
   }
   return false;
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(ask > bid && g_atr_1 > 0.0)
   {
      const double spread = ask - bid;
      if(spread > strategy_spread_max_atr_mult * g_atr_1)
         return true;
   }
   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   if(!g_state_ready)
      return false;

   if(Strategy_HasOurPosition())
      return false;

   if(g_long_signal)
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask <= 0.0) return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, ask, g_atr_1, strategy_atr_sl_mult);
      if(sl <= 0.0) return false;
      const double tp = QM_TakeATRFromValue(_Symbol, QM_BUY, ask, g_atr_1, strategy_atr_tp_mult);

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl;
      req.tp = tp;
      req.reason = "BERMAUI_DSS_OVERSOLD_REVERSAL";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 0;

      g_bars_since_last_long = 0;
      return true;
   }
   else if(g_short_signal)
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0) return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, bid, g_atr_1, strategy_atr_sl_mult);
      if(sl <= 0.0) return false;
      const double tp = QM_TakeATRFromValue(_Symbol, QM_SELL, bid, g_atr_1, strategy_atr_tp_mult);

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl;
      req.tp = tp;
      req.reason = "BERMAUI_DSS_OVERBOUGHT_REVERSAL";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 0;

      g_bars_since_last_short = 0;
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int bars_held = iBarShift(_Symbol, _Period, open_time);
      if(bars_held >= strategy_max_hold_bars)
      {
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
         continue;
      }

      if(g_atr_1 > 0.0)
      {
         const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
         const double current_sl = PositionGetDouble(POSITION_SL);
         const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

         if(ptype == POSITION_TYPE_BUY)
         {
            const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            if(bid - open_price >= strategy_be_atr_mult * g_atr_1)
            {
               const double new_sl = QM_TM_NormalizePrice(_Symbol, open_price + 10.0 * point);
               if(current_sl < open_price && new_sl > current_sl)
               {
                  QM_TM_MoveSL(ticket, new_sl, "BE");
               }
            }
         }
         else if(ptype == POSITION_TYPE_SELL)
         {
            const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            if(open_price - ask >= strategy_be_atr_mult * g_atr_1)
            {
               const double new_sl = QM_TM_NormalizePrice(_Symbol, open_price - 10.0 * point);
               if((current_sl == 0.0 || current_sl > open_price) && (current_sl == 0.0 || new_sl < current_sl))
               {
                  QM_TM_MoveSL(ticket, new_sl, "BE");
               }
            }
         }
      }
   }
}

bool Strategy_ExitSignal()
{
   if(!g_state_ready) return false;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && g_short_signal)
         return true;
      if(ptype == POSITION_TYPE_SELL && g_long_signal)
         return true;
   }
   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

// -----------------------------------------------------------------------------
// Framework wiring
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
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
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
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
   }

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   AdvanceState_OnNewBar();

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
