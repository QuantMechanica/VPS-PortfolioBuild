#property strict
#property version   "5.0"
#property description "QM5_12940 Bressert Cycle-Trigger-Line on DSS (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_12940
// Slug: bressert-cycle-trigger-line-h4-card
// Card: artifacts/cards_approved/QM5_12940_bressert-cycle-trigger-line-h4-card.md
// Source: Walter Bressert 1991 / 1995 / FF thread/187693 / 277401
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12940;
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
input int    strategy_dss_stoch_period  = 13;     // DSS raw stochastic lookback (%K)
input int    strategy_dss_inner_ema     = 8;      // DSS first EMA smoothing
input int    strategy_dss_outer_ema     = 8;      // DSS second EMA smoothing
input int    strategy_trigger_period    = 3;      // Trigger line SMA period on DSS
input double strategy_dss_os_zone       = 30.0;   // Oversold zone gate for BUY
input double strategy_dss_ob_zone       = 70.0;   // Overbought zone gate for SELL
input int    strategy_d1_ema_period     = 50;     // Higher-TF (D1) trend filter EMA period
input int    strategy_momentum_window   = 5;      // Prior bars extreme comparison window
input int    strategy_atr_period        = 14;     // ATR period for stops and targets
input double strategy_atr_sl_mult       = 1.5;    // Stop loss multiplier in ATR
input double strategy_atr_tp_mult       = 1.5;    // Take profit multiplier in ATR
input double strategy_trail_atr_mult    = 1.0;    // Trailing stop distance in ATR
input int    strategy_max_hold_bars     = 24;     // Time stop: max holding period in H4 bars
input int    strategy_cooldown_bars     = 12;     // Cooldown between entries in H4 bars
input double strategy_spread_max_atr_mult = 0.3;  // Maximum spread threshold in ATR

// -----------------------------------------------------------------------------
// File-scope cached state (advanced once per closed H4 bar)
// -----------------------------------------------------------------------------
double g_dss_1 = 0.0;
double g_dss_2 = 0.0;
double g_trigger_1 = 0.0;
double g_trigger_2 = 0.0;
double g_atr_1 = 0.0;
bool   g_long_signal = false;
bool   g_short_signal = false;
bool   g_long_exit_signal = false;
bool   g_short_exit_signal = false;
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
      const double h = iHigh(_Symbol, _Period, s);   // perf-allowed
      const double l = iLow(_Symbol, _Period, s);    // perf-allowed
      if(h > hh) hh = h;
      if(l < ll) ll = l;
   }
   const double c = iClose(_Symbol, _Period, end_shift); // perf-allowed
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

double DSS_ComputeAtShift(const int end_shift)
{
   const int p1 = strategy_dss_stoch_period;
   const int p2 = strategy_dss_inner_ema;
   const int p3 = strategy_dss_stoch_period;
   const int p4 = strategy_dss_outer_ema;

   const int k1_count = p3 + p4 + 4;
   double k1[];
   ArrayResize(k1, k1_count);

   const int rawk_len = p2 + 6;
   double rawk[];
   ArrayResize(rawk, rawk_len);

   for(int j = 0; j < k1_count; ++j)
   {
      const int base = end_shift + j;
      for(int r = 0; r < rawk_len; ++r)
         rawk[r] = DSS_RawStochAtShift(p1, base + r);
      k1[j] = DSS_EMAofSeries(rawk, rawk_len, p2);
   }

   double rawk2[];
   const int rawk2_len = p4 + 6;
   ArrayResize(rawk2, rawk2_len);

   for(int m = 0; m < rawk2_len; ++m)
   {
      double hh = -DBL_MAX;
      double ll =  DBL_MAX;
      for(int s = m; s < m + p3; ++s)
      {
         const double v = k1[s];
         if(v > hh) hh = v;
         if(v < ll) ll = v;
      }
      const double cc = k1[m];
      const double rng = hh - ll;
      rawk2[m] = (rng <= 0.0) ? 50.0 : 100.0 * (cc - ll) / rng;
   }

   return DSS_EMAofSeries(rawk2, rawk2_len, p4);
}

void AdvanceState_OnNewBar()
{
   g_long_signal = false;
   g_short_signal = false;
   g_long_exit_signal = false;
   g_short_exit_signal = false;

   g_bars_since_last_long++;
   g_bars_since_last_short++;

   const int needed_bars = strategy_dss_stoch_period * 2 + strategy_dss_inner_ema + strategy_dss_outer_ema + strategy_trigger_period + 30;
   if(iBars(_Symbol, _Period) < needed_bars || iBars(_Symbol, PERIOD_D1) < strategy_d1_ema_period + 10) // perf-allowed
   {
      g_state_ready = false;
      return;
   }

   const double dss1 = DSS_ComputeAtShift(1);
   const double dss2 = DSS_ComputeAtShift(2);
   const double dss3 = DSS_ComputeAtShift(3);
   const double dss4 = DSS_ComputeAtShift(4);

   const double trig1 = (dss1 + dss2 + dss3) / 3.0;
   const double trig2 = (dss2 + dss3 + dss4) / 3.0;

   g_dss_1 = dss1;
   g_dss_2 = dss2;
   g_trigger_1 = trig1;
   g_trigger_2 = trig2;

   g_atr_1 = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(g_atr_1 <= 0.0)
   {
      g_state_ready = false;
      return;
   }
   g_state_ready = true;

   // Opposite crossover exit signals
   if(dss2 >= trig2 && dss1 < trig1)
      g_long_exit_signal = true;
   if(dss2 <= trig2 && dss1 > trig1)
      g_short_exit_signal = true;

   // Bullish crossover
   const bool bull_cross = (dss2 <= trig2 && dss1 > trig1 && dss1 < strategy_dss_os_zone);
   // Bearish crossover
   const bool bear_cross = (dss2 >= trig2 && dss1 < trig1 && dss1 > strategy_dss_ob_zone);

   // Higher TF D1 trend filter
   const double d1_close = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed
   const double d1_ema = QM_EMA(_Symbol, PERIOD_D1, strategy_d1_ema_period, 1);

   // Momentum confirmation on H4 closed bar (shift 1)
   const double h4_open1  = iOpen(_Symbol, _Period, 1);   // perf-allowed
   const double h4_close1 = iClose(_Symbol, _Period, 1);  // perf-allowed

   double prior_hh = -DBL_MAX;
   double prior_ll =  DBL_MAX;
   for(int k = 2; k < 2 + strategy_momentum_window; ++k)
   {
      const double h = iHigh(_Symbol, _Period, k); // perf-allowed
      const double l = iLow(_Symbol, _Period, k);  // perf-allowed
      if(h > prior_hh) prior_hh = h;
      if(l < prior_ll) prior_ll = l;
   }

   const bool bull_momentum = (h4_close1 > h4_open1 && h4_close1 > prior_hh);
   const bool bear_momentum = (h4_close1 < h4_open1 && h4_close1 < prior_ll);

   if(bull_cross && d1_close > d1_ema && bull_momentum && g_bars_since_last_long >= strategy_cooldown_bars)
   {
      g_long_signal = true;
   }

   if(bear_cross && d1_close < d1_ema && bear_momentum && g_bars_since_last_short >= strategy_cooldown_bars)
   {
      g_short_signal = true;
   }
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   if(!g_state_ready) return true;
   const double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   if(g_atr_1 > 0.0 && spread > strategy_spread_max_atr_mult * g_atr_1)
      return true;
   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   if(!g_state_ready) return false;

   if(g_long_signal)
   {
      req.type = QM_BUY;
      req.reason = "QM5_12940_BUY";
      req.price = 0.0;
      req.sl = iLow(_Symbol, _Period, 1) - strategy_atr_sl_mult * g_atr_1; // perf-allowed
      req.tp = SymbolInfoDouble(_Symbol, SYMBOL_ASK) + strategy_atr_tp_mult * g_atr_1;
      req.symbol_slot = qm_magic_slot_offset;

      g_bars_since_last_long = 0;
      return true;
   }

   if(g_short_signal)
   {
      req.type = QM_SELL;
      req.reason = "QM5_12940_SELL";
      req.price = 0.0;
      req.sl = iHigh(_Symbol, _Period, 1) + strategy_atr_sl_mult * g_atr_1; // perf-allowed
      req.tp = SymbolInfoDouble(_Symbol, SYMBOL_BID) - strategy_atr_tp_mult * g_atr_1;
      req.symbol_slot = qm_magic_slot_offset;

      g_bars_since_last_short = 0;
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0) return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int bars_open = iBarShift(_Symbol, _Period, open_time); // perf-allowed

      // Time stop exit
      if(bars_open >= strategy_max_hold_bars)
      {
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
         continue;
      }

      // Opposite signal exit
      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY && g_long_exit_signal)
      {
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
         continue;
      }
      else if(pos_type == POSITION_TYPE_SELL && g_short_exit_signal)
      {
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
         continue;
      }

      QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr_mult);
   }
}

bool Strategy_ExitSignal()
{
   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
{
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                        qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { QM_FrameworkShutdown(); }

void OnTick()
{
   if(!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;
   
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;
   
   if(QM_FrameworkHandleFridayClose()) return;

   if(QM_IsNewBar(_Symbol, _Period))
   {
      AdvanceState_OnNewBar();
   }

   if(Strategy_NoTradeFilter()) return;

   Strategy_ManageOpenPosition();

   const int magic = QM_FrameworkMagic();
   bool has_position = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) == magic && PositionGetString(POSITION_SYMBOL) == _Symbol)
      {
         has_position = true;
         break;
      }
   }

   if(!has_position && QM_IsNewBar(_Symbol, _Period))
   {
      QM_EntryRequest req;
      if(Strategy_EntrySignal(req))
      {
         ulong ticket = 0;
         QM_TM_OpenPosition(req, ticket);
      }
   }
}

void OnTimer() { QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{
   QM_FrameworkOnTradeTransaction(t, r, res);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
