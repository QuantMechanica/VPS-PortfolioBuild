#property strict
#property version   "5.0"
#property description "QM5_1623 Hopwood Bermaui-DSS H4 Mean-Reversion"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_1623
// Slug: hopwood-bermaui-dss-h4
// Card: artifacts/cards_approved/QM5_1623_hopwood-bermaui-dss-h4.md (g0 APPROVED)
// Source: Steve Hopwood FF thread/254595 + William Blau 1995 (DSS)
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1623;
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
input int    strategy_dss_stoch_period  = 10;     // DSS raw stochastic lookback (%K)
input int    strategy_dss_inner_ema     = 5;      // DSS first EMA smoothing
input int    strategy_dss_outer_ema     = 5;      // DSS second EMA smoothing
input int    strategy_bermaui_lookback  = 100;    // Rolling completed-H4 DSS window
input double strategy_overbought_percentile = 80.0;
input double strategy_oversold_percentile = 20.0;
input int    strategy_d1_ema_period     = 200;    // Higher-TF (D1) trend filter EMA period
input int    strategy_atr_period        = 14;     // ATR period for protective stop
input double strategy_atr_sl_mult       = 2.0;    // Initial stop loss multiplier in ATR
input int    strategy_max_hold_bars     = 20;     // Time stop in completed H4 bars
input int    strategy_cooldown_bars     = 6;      // Cooldown between entries in H4 bars
input double strategy_spread_max_atr_mult = 0.3;  // Maximum spread threshold in ATR

// -----------------------------------------------------------------------------
// File-scope cached state (advanced once per closed H4 bar)
// -----------------------------------------------------------------------------
double g_dss_outer_1 = 0.0;
double g_dss_outer_2 = 0.0;
double g_upper_thr_1 = 0.0;
double g_upper_thr_2 = 0.0;
double g_lower_thr_1 = 0.0;
double g_lower_thr_2 = 0.0;
double g_atr_1 = 0.0;
int    g_d1_bias = 0;
bool   g_long_signal = false;
bool   g_short_signal = false;
bool   g_long_band_exit = false;
bool   g_short_band_exit = false;
bool   g_state_ready = false;
int    g_bars_since_last_long = 100;
int    g_bars_since_last_short = 100;

// -----------------------------------------------------------------------------
// DSS computation helpers (closed-bar, bounded)
// -----------------------------------------------------------------------------

bool DSS_RawStochAtShift(const int period, const int end_shift, double &out_value)
{
   out_value = 0.0;
   if(period <= 0 || end_shift <= 0)
      return false;

   double hh = -DBL_MAX;
   double ll =  DBL_MAX;
   for(int s = end_shift; s < end_shift + period; ++s)
   {
      const double h = iHigh(_Symbol, PERIOD_H4, s); // perf-allowed: bounded completed-H4 stochastic
      const double l = iLow(_Symbol, PERIOD_H4, s);  // perf-allowed: bounded completed-H4 stochastic
      if(h <= 0.0 || l <= 0.0 || h < l)
         return false;
      if(h > hh) hh = h;
      if(l < ll) ll = l;
   }
   const double c = iClose(_Symbol, PERIOD_H4, end_shift); // perf-allowed: bounded completed-H4 stochastic
   if(c <= 0.0)
      return false;
   const double rng = hh - ll;
   if(rng <= 0.0)
      out_value = 50.0;
   else
      out_value = 100.0 * (c - ll) / rng;
   return true;
}

bool DSS_BuildSeries(const int sample_count, double &out_dss[])
{
   if(sample_count < 2 || strategy_dss_stoch_period <= 0 ||
      strategy_dss_inner_ema <= 0 || strategy_dss_outer_ema <= 0)
      return false;

   // A fixed 200-bar seed makes both EMA layers deterministic and converged
   // while keeping the entire indicator read bounded to one completed-H4 pass.
   const int warmup_count = 200;
   const int total_count = sample_count + warmup_count;
   const int required_bars = total_count + strategy_dss_stoch_period + 1;
   if(Bars(_Symbol, PERIOD_H4) < required_bars)
      return false;

   double raw_values[];
   double inner_values[];
   if(ArrayResize(raw_values, total_count) != total_count ||
      ArrayResize(inner_values, total_count) != total_count ||
      ArrayResize(out_dss, total_count) != total_count)
      return false;
   if(ArraySize(raw_values) < total_count || ArraySize(inner_values) < total_count ||
      ArraySize(out_dss) < total_count)
      return false;

   for(int i = 0; i < total_count; ++i)
   {
      if(!DSS_RawStochAtShift(strategy_dss_stoch_period, 1 + i, raw_values[i]))
         return false;
   }

   const double inner_alpha = 2.0 / (strategy_dss_inner_ema + 1.0);
   const double outer_alpha = 2.0 / (strategy_dss_outer_ema + 1.0);
   inner_values[total_count - 1] = raw_values[total_count - 1];
   for(int i = total_count - 2; i >= 0; --i)
   {
      if(i >= ArraySize(raw_values))
         return false;
      if(i >= ArraySize(inner_values))
         return false;
      if(i + 1 >= ArraySize(inner_values))
         return false;
      inner_values[i] = inner_alpha * raw_values[i] + (1.0 - inner_alpha) * inner_values[i + 1];
   }

   out_dss[total_count - 1] = inner_values[total_count - 1];
   for(int i = total_count - 2; i >= 0; --i)
   {
      if(i >= ArraySize(inner_values))
         return false;
      if(i >= ArraySize(out_dss))
         return false;
      if(i + 1 >= ArraySize(out_dss))
         return false;
      out_dss[i] = outer_alpha * inner_values[i] + (1.0 - outer_alpha) * out_dss[i + 1];
   }

   return true;
}

bool DSS_Percentile(const double &source[],
                    const int offset,
                    const int count,
                    const double percentile,
                    double &out_value)
{
   out_value = 0.0;
   if(offset < 0 || count <= 0 || percentile <= 0.0 || percentile >= 100.0 ||
      ArraySize(source) < offset + count)
      return false;

   double sample[];
   if(ArrayResize(sample, count) != count || ArraySize(sample) < count)
      return false;
   for(int i = 0; i < count; ++i)
      sample[i] = source[offset + i];

   ArraySort(sample);
   int rank = (int)MathCeil(percentile * count / 100.0) - 1;
   if(rank < 0) rank = 0;
   if(rank >= count) rank = count - 1;
   if(rank < 0 || rank >= ArraySize(sample))
      return false;
   out_value = sample[rank];
   return true;
}

bool AdvanceState_OnNewBar()
{
   g_state_ready = false;
   g_long_signal = false;
   g_short_signal = false;
   g_long_band_exit = false;
   g_short_band_exit = false;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const int sample_count = strategy_bermaui_lookback + 1;
   double dss_values[];
   if(!DSS_BuildSeries(sample_count, dss_values) || ArraySize(dss_values) < sample_count)
      return false;

   double upper_1 = 0.0;
   double lower_1 = 0.0;
   double upper_2 = 0.0;
   double lower_2 = 0.0;
   if(!DSS_Percentile(dss_values, 0, strategy_bermaui_lookback,
                      strategy_overbought_percentile, upper_1) ||
      !DSS_Percentile(dss_values, 0, strategy_bermaui_lookback,
                      strategy_oversold_percentile, lower_1) ||
      !DSS_Percentile(dss_values, 1, strategy_bermaui_lookback,
                      strategy_overbought_percentile, upper_2) ||
      !DSS_Percentile(dss_values, 1, strategy_bermaui_lookback,
                      strategy_oversold_percentile, lower_2))
      return false;

   g_atr_1 = atr;
   g_dss_outer_1 = dss_values[0];
   g_dss_outer_2 = dss_values[1];
   g_upper_thr_1 = upper_1;
   g_upper_thr_2 = upper_2;
   g_lower_thr_1 = lower_1;
   g_lower_thr_2 = lower_2;
   g_d1_bias = QM_Sig_Price_Above_MA(_Symbol, PERIOD_D1,
                                      strategy_d1_ema_period, 0.0, 1);

   g_bars_since_last_long++;
   g_bars_since_last_short++;

   const bool long_cross = (g_dss_outer_2 <= g_lower_thr_2 &&
                            g_dss_outer_1 > g_lower_thr_1);
   const bool short_cross = (g_dss_outer_2 >= g_upper_thr_2 &&
                             g_dss_outer_1 < g_upper_thr_1);
   g_long_signal = (long_cross && g_d1_bias > 0 &&
                    g_bars_since_last_long >= strategy_cooldown_bars);
   g_short_signal = (short_cross && g_d1_bias < 0 &&
                     g_bars_since_last_short >= strategy_cooldown_bars);

   g_long_band_exit = (g_dss_outer_2 <= g_upper_thr_2 &&
                       g_dss_outer_1 > g_upper_thr_1);
   g_short_band_exit = (g_dss_outer_2 >= g_lower_thr_2 &&
                        g_dss_outer_1 < g_lower_thr_1);
   g_state_ready = true;
   return true;
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
   if(!g_state_ready || g_atr_1 <= 0.0)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return true;

   const double spread = ask - bid;
   return (spread > strategy_spread_max_atr_mult * g_atr_1);
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

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl;
      req.tp = 0.0;
      req.reason = "BERMAUI_DSS_OVERSOLD_REVERSAL";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
   }
   else if(g_short_signal)
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0) return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, bid, g_atr_1, strategy_atr_sl_mult);
      if(sl <= 0.0) return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl;
      req.tp = 0.0;
      req.reason = "BERMAUI_DSS_OVERBOUGHT_REVERSAL";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 0;
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
      const int bars_held = iBarShift(_Symbol, PERIOD_H4, open_time); // perf-allowed: one bounded position-age lookup
      if(bars_held >= strategy_max_hold_bars)
      {
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
         continue;
      }
   }
}

bool Strategy_ExitSignal(const ulong ticket, QM_ExitReason &out_reason)
{
   out_reason = QM_EXIT_STRATEGY;
   if(!g_state_ready || !PositionSelectByTicket(ticket))
      return false;
   if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
      (int)PositionGetInteger(POSITION_MAGIC) != QM_FrameworkMagic())
      return false;

   const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   if(ptype == POSITION_TYPE_BUY)
   {
      if(g_short_signal)
      {
         out_reason = QM_EXIT_OPPOSITE_SIGNAL;
         return true;
      }
      return (g_long_band_exit || g_d1_bias <= 0);
   }
   if(ptype == POSITION_TYPE_SELL)
   {
      if(g_long_signal)
      {
         out_reason = QM_EXIT_OPPOSITE_SIGNAL;
         return true;
      }
      return (g_short_band_exit || g_d1_bias >= 0);
   }
   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
{
   if(_Period != PERIOD_H4)
   {
      Print("QM5_1623 requires an H4 chart");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(strategy_dss_stoch_period <= 0 || strategy_dss_inner_ema <= 0 ||
      strategy_dss_outer_ema <= 0 || strategy_bermaui_lookback < 2 ||
      strategy_overbought_percentile <= strategy_oversold_percentile ||
      strategy_overbought_percentile >= 100.0 || strategy_oversold_percentile <= 0.0 ||
      strategy_d1_ema_period <= 0 || strategy_atr_period <= 0 ||
      strategy_atr_sl_mult <= 0.0 || strategy_max_hold_bars <= 0 ||
      strategy_cooldown_bars < 0 || strategy_spread_max_atr_mult <= 0.0)
   {
      Print("QM5_1623 invalid strategy parameters");
      return INIT_PARAMETERS_INCORRECT;
   }

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
   if(QM_FrameworkHandleFridayClose())
      return;

   Strategy_ManageOpenPosition();

   if(!QM_IsNewBar(_Symbol, PERIOD_H4))
      return;
   if(!AdvanceState_OnNewBar())
      return;

   QM_EquityStreamOnNewBar();

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      QM_ExitReason exit_reason = QM_EXIT_STRATEGY;
      if(Strategy_ExitSignal(ticket, exit_reason))
         QM_TM_ClosePosition(ticket, exit_reason);
   }

   if(Strategy_NoTradeFilter())
      return;
   if(Strategy_NewsFilterHook(broker_now))
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   QM_EntryRequest req;
   ZeroMemory(req);
   if(Strategy_EntrySignal(req))
   {
      ulong out_ticket = 0;
      if(QM_TM_OpenPosition(req, out_ticket))
      {
         if(req.type == QM_BUY)
            g_bars_since_last_long = 0;
         else if(req.type == QM_SELL)
            g_bars_since_last_short = 0;
      }
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
