#property strict
#property version   "5.0"
#property description "QM5_9724 Alien ADX BBS Expansion H1"

// ForexFactory "Alien's Extraterrestrial Visual Systems" (forexalien, 2013)
// H1 Bollinger squeeze breakout confirmed by multi-speed ADX expansion, RSI/Stochastic,
// and M15 midline direction filter.
// Card: QM5_9724_ff-alien-adx-bbs-h1.md | Source: 6e967762-b26d-59a3-b076-35c17f2e7c36

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                      = 9724;
input int    qm_magic_slot_offset          = 0;
input uint   qm_rng_seed                   = 42;

input group "Risk"
input double RISK_PERCENT                  = 0.0;
input double RISK_FIXED                    = 1000.0;
input double PORTFOLIO_WEIGHT              = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours               = 336;
input string qm_news_min_impact                    = "high";
input QM_NewsMode qm_news_mode_legacy              = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled               = true;
input int    qm_friday_close_hour_broker           = 21;

input group "Stress"
input double qm_stress_reject_probability          = 0.0;

input group "Strategy"
input int    strategy_bb_period                    = 20;
input double strategy_bb_dev                      = 2.0;
input int    strategy_adx_p1                      = 7;
input int    strategy_adx_p2                      = 21;
input int    strategy_adx_p3                      = 42;
input int    strategy_adx_p4                      = 89;
input int    strategy_adx_p5                      = 144;
input double strategy_adx_threshold               = 20.0;
input int    strategy_rsi_period                  = 14;
input int    strategy_stoch_k                     = 21;
input int    strategy_stoch_d                     = 10;
input int    strategy_stoch_slow                  = 10;
input double strategy_sl_atr_mult                 = 0.30;
input double strategy_tp_r                        = 2.0;
input int    strategy_time_stop_bars              = 18;
input int    strategy_atr_pct_lookback            = 60;
input double strategy_atr_pct_floor               = 20.0;

// ---- Per-bar cached entry conditions ----
double  g_bar_close        = 0.0;
double  g_bar_high         = 0.0;
double  g_bar_low          = 0.0;
double  g_bar_bb_upper     = 0.0;
double  g_bar_bb_lower     = 0.0;
double  g_bar_atr          = 0.0;
bool    g_bar_squeeze      = false;
bool    g_bar_adx_ok       = false;
bool    g_bar_atr_ok       = false;
bool    g_bar_rsi_long_ok  = false;
bool    g_bar_rsi_short_ok = false;
bool    g_bar_stoch_long   = false;
bool    g_bar_stoch_short  = false;
bool    g_bar_m15_long_ok  = false;
bool    g_bar_m15_short_ok = false;
int     g_bar_dir          = 0;

// ---- Per-bar cached exit conditions ----
bool    g_exit_adx_down          = false;
bool    g_exit_rsi_vs_50_long    = false;
bool    g_exit_rsi_vs_50_short   = false;

// ---- Position tracking ----
int     g_pos_dir          = 0;
double  g_pos_sl_dist      = 0.0;
bool    g_pos_be_done      = false;
int     g_pos_bars_held    = 0;

// ---- Helpers ----

void QM9724_SortAsc(double &arr[], const int n)
  {
   for(int i = 1; i < n; i++)
     {
      const double key = arr[i];
      int j = i - 1;
      while(j >= 0 && arr[j] > key) { arr[j + 1] = arr[j]; j--; }
      arr[j + 1] = key;
     }
  }

bool QM9724_HasPosition(ulong &out_ticket)
  {
   out_ticket = 0;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      out_ticket = t;
      return true;
     }
   return false;
  }

void QM9724_AdvanceState()
  {
   g_bar_close = iClose(_Symbol, PERIOD_H1, 1);   // perf-allowed — last bar close for BB breakout test
   g_bar_high  = iHigh(_Symbol, PERIOD_H1, 1);    // perf-allowed — breakout bar high for short SL
   g_bar_low   = iLow(_Symbol, PERIOD_H1, 1);     // perf-allowed — breakout bar low for long SL

   g_bar_bb_upper = QM_BB_Upper(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_dev, 1);
   g_bar_bb_lower = QM_BB_Lower(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_dev, 1);
   g_bar_atr      = QM_ATR(_Symbol, PERIOD_H1, 14, 1);

   // BB width squeeze: count bars in last 8 that are below the 20-bar median width
   double widths[20];
   int w;
   for(w = 0; w < 20; w++)
      widths[w] = QM_BB_Upper(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_dev, w + 1)
                - QM_BB_Lower(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_dev, w + 1);
   double sorted_w[20];
   for(w = 0; w < 20; w++) sorted_w[w] = widths[w];
   QM9724_SortAsc(sorted_w, 20);
   const double median_w = (sorted_w[9] + sorted_w[10]) * 0.5;
   int compressed = 0;
   for(w = 0; w < 8; w++) if(widths[w] < median_w) compressed++;
   g_bar_squeeze = (compressed >= 5);

   // ATR percentile filter
   double atrs[60];
   int a;
   for(a = 0; a < 60; a++) atrs[a] = QM_ATR(_Symbol, PERIOD_H1, 14, a + 1);
   double sorted_a[60];
   for(a = 0; a < 60; a++) sorted_a[a] = atrs[a];
   QM9724_SortAsc(sorted_a, 60);
   int pct_idx = (int)MathFloor(strategy_atr_pct_floor / 100.0 * (double)strategy_atr_pct_lookback);
   pct_idx = MathMax(0, MathMin(strategy_atr_pct_lookback - 1, pct_idx));
   g_bar_atr_ok = (g_bar_atr >= sorted_a[pct_idx]);

   // ADX: all 5 periods rising vs 2 bars ago, at least 3 above threshold
   int adx_ps[5];
   adx_ps[0] = strategy_adx_p1; adx_ps[1] = strategy_adx_p2; adx_ps[2] = strategy_adx_p3;
   adx_ps[3] = strategy_adx_p4; adx_ps[4] = strategy_adx_p5;
   bool all_rising = true;
   int above_thr = 0;
   int p;
   for(p = 0; p < 5; p++)
     {
      const double v1 = QM_ADX(_Symbol, PERIOD_H1, adx_ps[p], 1);
      const double v3 = QM_ADX(_Symbol, PERIOD_H1, adx_ps[p], 3);
      if(v1 <= v3) all_rising = false;
      if(v1 > strategy_adx_threshold) above_thr++;
     }
   g_bar_adx_ok = all_rising && (above_thr >= 3);

   // RSI (RSIOMA proxy): above 50 and rising OR above 80 flat/rising for long
   const double rsi1 = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, 1);
   const double rsi2 = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, 2);
   g_bar_rsi_long_ok  = (rsi1 > 50.0 && rsi1 >= rsi2) || (rsi1 > 80.0);
   g_bar_rsi_short_ok = (rsi1 < 50.0 && rsi1 <= rsi2) || (rsi1 < 20.0);

   // Stochastic
   const double sk = QM_Stoch_K(_Symbol, PERIOD_H1, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 1);
   const double sd = QM_Stoch_D(_Symbol, PERIOD_H1, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 1);
   g_bar_stoch_long  = (sk > sd && sk > 50.0);
   g_bar_stoch_short = (sk < sd && sk < 50.0);

   // M15 midline filter: last M15 bar close vs M15 BB(20) midline
   const double m15_close  = iClose(_Symbol, PERIOD_M15, 1);  // perf-allowed — M15 directional filter
   const double m15_middle = QM_BB_Middle(_Symbol, PERIOD_M15, strategy_bb_period, strategy_bb_dev, 1);
   g_bar_m15_long_ok  = (m15_close > m15_middle);
   g_bar_m15_short_ok = (m15_close < m15_middle);

   // Composite entry signal
   const bool long_ok  = g_bar_squeeze && (g_bar_close > g_bar_bb_upper) && g_bar_adx_ok
                       && g_bar_rsi_long_ok  && g_bar_stoch_long  && g_bar_m15_long_ok  && g_bar_atr_ok;
   const bool short_ok = g_bar_squeeze && (g_bar_close < g_bar_bb_lower) && g_bar_adx_ok
                       && g_bar_rsi_short_ok && g_bar_stoch_short && g_bar_m15_short_ok && g_bar_atr_ok;
   g_bar_dir = long_ok ? 1 : (short_ok ? -1 : 0);

   // Exit conditions (ADX declining 2 consecutive bars on the slower periods)
   int exit_ps[3];
   exit_ps[0] = strategy_adx_p3; exit_ps[1] = strategy_adx_p4; exit_ps[2] = strategy_adx_p5;
   g_exit_adx_down = false;
   for(p = 0; p < 3; p++)
     {
      const double ev1 = QM_ADX(_Symbol, PERIOD_H1, exit_ps[p], 1);
      const double ev2 = QM_ADX(_Symbol, PERIOD_H1, exit_ps[p], 2);
      const double ev3 = QM_ADX(_Symbol, PERIOD_H1, exit_ps[p], 3);
      if(ev1 < ev2 && ev2 < ev3) { g_exit_adx_down = true; break; }
     }

   // RSI crossing 50 against position direction
   g_exit_rsi_vs_50_long  = (rsi1 < 50.0 && rsi2 >= 50.0);
   g_exit_rsi_vs_50_short = (rsi1 > 50.0 && rsi2 <= 50.0);

   // Bar count for time stop (only when position is open)
   if(g_pos_dir != 0)
     {
      ulong t;
      if(!QM9724_HasPosition(t)) { g_pos_dir = 0; g_pos_bars_held = 0; g_pos_be_done = false; }
      else g_pos_bars_held++;
     }
  }

// ---- Strategy hooks ----

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   QM9724_AdvanceState();

   if(g_bar_dir == 0) return false;

   ulong existing;
   if(QM9724_HasPosition(existing)) return false;

   const double atr_dist = g_bar_atr * strategy_sl_atr_mult;
   double sl_price;
   if(g_bar_dir > 0) sl_price = g_bar_low  - atr_dist;
   else              sl_price = g_bar_high + atr_dist;

   const double entry_px = (g_bar_dir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                            : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_px <= 0.0 || sl_price <= 0.0) return false;

   const double sl_dist = MathAbs(entry_px - sl_price);
   if(sl_dist <= 0.0) return false;

   const double tp_price = (g_bar_dir > 0) ? (entry_px + sl_dist * strategy_tp_r)
                                            : (entry_px - sl_dist * strategy_tp_r);

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0) return false;
   const double lots = QM_LotsForRisk(_Symbol, sl_dist / point);
   if(lots <= 0.0) return false;

   req.type               = (g_bar_dir > 0) ? QM_BUY : QM_SELL;
   req.price              = 0.0;
   req.sl                 = sl_price;
   req.tp                 = tp_price;
   req.reason             = (g_bar_dir > 0) ? "ALIEN_BBS_LONG" : "ALIEN_BBS_SHORT";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   g_pos_dir       = g_bar_dir;
   g_pos_sl_dist   = sl_dist;
   g_pos_be_done   = false;
   g_pos_bars_held = 0;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   if(g_pos_dir == 0) return;

   ulong ticket;
   if(!QM9724_HasPosition(ticket))
     {
      g_pos_dir = 0; g_pos_bars_held = 0; g_pos_be_done = false;
      return;
     }

   if(g_pos_be_done || g_pos_sl_dist <= 0.0) return;

   const double entry_px  = PositionGetDouble(POSITION_PRICE_OPEN);
   const double current_sl = PositionGetDouble(POSITION_SL);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double mkt_px = (g_pos_dir > 0) ? bid : ask;
   const double profit  = (g_pos_dir > 0) ? (mkt_px - entry_px) : (entry_px - mkt_px);

   if(profit >= g_pos_sl_dist)
     {
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(point <= 0.0) return;
      const double new_sl = (g_pos_dir > 0) ? (entry_px + point) : (entry_px - point);
      const bool improves = (g_pos_dir > 0) ? (new_sl > current_sl) : (new_sl < current_sl);
      if(improves && QM_TM_MoveSL(ticket, new_sl, "BE_1R")) g_pos_be_done = true;
     }
  }

bool Strategy_ExitSignal()
  {
   if(g_pos_dir == 0) return false;
   if(g_pos_bars_held >= strategy_time_stop_bars) return true;
   if(g_exit_adx_down) return true;
   if(g_pos_dir > 0 && g_exit_rsi_vs_50_long)  return true;
   if(g_pos_dir < 0 && g_exit_rsi_vs_50_short) return true;
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// ---- Framework wiring ----

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

   if(Strategy_NoTradeFilter()) return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
      g_pos_dir = 0; g_pos_bars_held = 0; g_pos_be_done = false;
     }

   if(!QM_IsNewBar()) return;

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
                        const MqlTradeRequest      &request,
                        const MqlTradeResult       &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
