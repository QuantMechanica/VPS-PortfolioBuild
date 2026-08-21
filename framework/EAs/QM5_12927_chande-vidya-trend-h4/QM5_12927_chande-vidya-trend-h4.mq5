#property strict
#property version   "5.0"
#property description "QM5_12927 Chande Vidya Volatility-Adaptive Trend Cross (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_12927
// Strategy: Chande Vidya Volatility-Adaptive Trend Cross (H4)
// Source: Tushar Chande 1994 / Stocks & Commodities 1993 / FF cluster
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12927;
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
input int    strategy_cmo_period        = 9;
input double strategy_cmo_threshold     = 20.0;
input int    strategy_vidya_fast_period = 14;
input int    strategy_vidya_slow_period = 50;
input int    strategy_ema_period        = 200;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 1.0;
input double strategy_max_sl_atr_mult   = 3.5;
input double strategy_tp_atr_mult       = 0.0;
input double strategy_max_spread_mult   = 1.5;

// -----------------------------------------------------------------------------
// State tracking
// -----------------------------------------------------------------------------
bool     g_rearm_buy                    = true;
bool     g_rearm_sell                   = true;

#define SPREAD_HISTORY_SIZE 20
int      g_spread_history[SPREAD_HISTORY_SIZE];
int      g_spread_count                 = 0;

void UpdateSpreadHistory()
{
   const int current_spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread < 0) return;
   
   if(g_spread_count < SPREAD_HISTORY_SIZE)
   {
      g_spread_history[g_spread_count] = current_spread;
      g_spread_count++;
   }
   else
   {
      for(int i = 0; i < SPREAD_HISTORY_SIZE - 1; ++i)
         g_spread_history[i] = g_spread_history[i + 1];
      g_spread_history[SPREAD_HISTORY_SIZE - 1] = current_spread;
   }
}

double GetMedianSpread()
{
   if(g_spread_count == 0) return 0.0;
   int temp[SPREAD_HISTORY_SIZE];
   ArrayCopy(temp, g_spread_history, 0, 0, g_spread_count);
   ArraySort(temp);
   return (double)temp[g_spread_count / 2];
}

// -----------------------------------------------------------------------------
// Indicator calculations
// -----------------------------------------------------------------------------

double CalculateCMO(const int cmo_period, const int shift)
{
   if(cmo_period <= 0) return 0.0;
   double su = 0.0;
   double sd = 0.0;
   for(int i = shift; i < shift + cmo_period; ++i)
   {
      const double c_curr = iClose(_Symbol, PERIOD_H4, i);     // perf-allowed: CMO series price reader
      const double c_prev = iClose(_Symbol, PERIOD_H4, i + 1); // perf-allowed: CMO series price reader
      if(c_curr <= 0.0 || c_prev <= 0.0) return 0.0;
      const double diff = c_curr - c_prev;
      if(diff > 0.0) su += diff;
      else if(diff < 0.0) sd += (-diff);
   }
   if(su + sd <= 0.0) return 0.0;
   return 100.0 * (su - sd) / (su + sd);
}

double CalculateVIDYA(const int vidya_period, const int cmo_period, const int shift, const int warmup = 150)
{
   if(vidya_period <= 0 || cmo_period <= 0) return 0.0;
   const int start_bar = shift + warmup;
   const double initial_close = iClose(_Symbol, PERIOD_H4, start_bar); // perf-allowed: VIDYA initialization price reader
   if(initial_close <= 0.0) return 0.0;
   
   double vidya = initial_close;
   const double alpha_base = 2.0 / ((double)vidya_period + 1.0);
   
   for(int k = start_bar - 1; k >= shift; --k)
   {
      const double c = iClose(_Symbol, PERIOD_H4, k); // perf-allowed: VIDYA recurrence price reader
      if(c <= 0.0) return 0.0;
      const double cmo = CalculateCMO(cmo_period, k);
      const double alpha = alpha_base * (MathAbs(cmo) / 100.0);
      vidya = alpha * c + (1.0 - alpha) * vidya;
   }
   return vidya;
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   UpdateSpreadHistory();
   if(g_spread_count >= 10 && strategy_max_spread_mult > 0.0)
   {
      const double median_sp = GetMedianSpread();
      const double current_sp = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(median_sp > 0.0 && current_sp > 0.0 && current_sp > strategy_max_spread_mult * median_sp)
         return true; // spread filter blocks
   }
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

   // Check if already open position
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) == magic && PositionGetString(POSITION_SYMBOL) == _Symbol)
         return false; // 1-pos-per-magic rule
   }

   const double c1 = iClose(_Symbol, PERIOD_H4, 1); // perf-allowed: closed H4 bar 1 close
   const double o1 = iOpen(_Symbol, PERIOD_H4, 1);  // perf-allowed: closed H4 bar 1 open
   if(c1 <= 0.0 || o1 <= 0.0) return false;

   const double vf1 = CalculateVIDYA(strategy_vidya_fast_period, strategy_cmo_period, 1);
   const double vf2 = CalculateVIDYA(strategy_vidya_fast_period, strategy_cmo_period, 2);
   const double vs1 = CalculateVIDYA(strategy_vidya_slow_period, strategy_cmo_period, 1);
   const double vs2 = CalculateVIDYA(strategy_vidya_slow_period, strategy_cmo_period, 2);

   if(vf1 <= 0.0 || vf2 <= 0.0 || vs1 <= 0.0 || vs2 <= 0.0) return false;

   // Track re-arm states on crosses
   if(vf1 < vs1) g_rearm_buy = true;
   if(vf1 > vs1) g_rearm_sell = true;

   const double cmo1 = CalculateCMO(strategy_cmo_period, 1);
   const double ema200 = QM_EMA(_Symbol, PERIOD_H4, strategy_ema_period, 1);
   const double atr14  = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);

   if(ema200 <= 0.0 || atr14 <= 0.0) return false;

   // BUY Entry:
   // 1. Fast VIDYA crossed above Slow VIDYA on bar 1
   // 2. CMO > threshold
   // 3. Close > EMA 200
   // 4. Bar 1 is bullish (close > open)
   // 5. Re-armed
   if(vf2 <= vs2 && vf1 > vs1 && cmo1 > strategy_cmo_threshold && c1 > ema200 && c1 > o1 && g_rearm_buy)
   {
      double lowest_4 = iLow(_Symbol, PERIOD_H4, 1); // perf-allowed: 4-bar low swing stop
      for(int b = 2; b <= 4; ++b)
      {
         const double low_b = iLow(_Symbol, PERIOD_H4, b); // perf-allowed: 4-bar low swing stop
         if(low_b > 0.0 && low_b < lowest_4) lowest_4 = low_b;
      }
      
      double sl_distance = (c1 - lowest_4) + strategy_atr_sl_mult * atr14;
      const double max_sl = strategy_max_sl_atr_mult * atr14;
      if(sl_distance > max_sl) sl_distance = max_sl;
      if(sl_distance <= 0.0) sl_distance = atr14;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = c1 - sl_distance;
      req.tp = (strategy_tp_atr_mult > 0.0) ? (c1 + strategy_tp_atr_mult * atr14) : 0.0;
      req.reason = "VIDYA_BULL_CROSS";
      req.symbol_slot = qm_magic_slot_offset;
      g_rearm_buy = false;
      return true;
   }

   // SELL Entry:
   // 1. Fast VIDYA crossed below Slow VIDYA on bar 1
   // 2. CMO < -threshold
   // 3. Close < EMA 200
   // 4. Bar 1 is bearish (close < open)
   // 5. Re-armed
   if(vf2 >= vs2 && vf1 < vs1 && cmo1 < -strategy_cmo_threshold && c1 < ema200 && c1 < o1 && g_rearm_sell)
   {
      double highest_4 = iHigh(_Symbol, PERIOD_H4, 1); // perf-allowed: 4-bar high swing stop
      for(int b = 2; b <= 4; ++b)
      {
         const double high_b = iHigh(_Symbol, PERIOD_H4, b); // perf-allowed: 4-bar high swing stop
         if(high_b > highest_4) highest_4 = high_b;
      }
      
      double sl_distance = (highest_4 - c1) + strategy_atr_sl_mult * atr14;
      const double max_sl = strategy_max_sl_atr_mult * atr14;
      if(sl_distance > max_sl) sl_distance = max_sl;
      if(sl_distance <= 0.0) sl_distance = atr14;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = c1 + sl_distance;
      req.tp = (strategy_tp_atr_mult > 0.0) ? (c1 - strategy_tp_atr_mult * atr14) : 0.0;
      req.reason = "VIDYA_BEAR_CROSS";
      req.symbol_slot = qm_magic_slot_offset;
      g_rearm_sell = false;
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic || PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      
      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      
      const double c1 = iClose(_Symbol, PERIOD_H4, 1); // perf-allowed: exit signal evaluation close
      if(c1 <= 0.0) continue;

      const double vf1 = CalculateVIDYA(strategy_vidya_fast_period, strategy_cmo_period, 1);
      const double vs1 = CalculateVIDYA(strategy_vidya_slow_period, strategy_cmo_period, 1);
      const double cmo1 = CalculateCMO(strategy_cmo_period, 1);
      const double cmo2 = CalculateCMO(strategy_cmo_period, 2);
      const double ema200 = QM_EMA(_Symbol, PERIOD_H4, strategy_ema_period, 1);

      if(pos_type == POSITION_TYPE_BUY)
      {
         // 1. Opposite VIDYA cross
         if(vf1 > 0.0 && vs1 > 0.0 && vf1 < vs1)
            return true;
         // 2. CMO momentum-flip exit: 2 consecutive closes < 0
         if(cmo1 < 0.0 && cmo2 < 0.0)
            return true;
         // 3. EMA-200 macro-bias flip
         if(ema200 > 0.0 && c1 < ema200)
            return true;
      }
      else if(pos_type == POSITION_TYPE_SELL)
      {
         // 1. Opposite VIDYA cross
         if(vf1 > 0.0 && vs1 > 0.0 && vf1 > vs1)
            return true;
         // 2. CMO momentum-flip exit: 2 consecutive closes > 0
         if(cmo1 > 0.0 && cmo2 > 0.0)
            return true;
         // 3. EMA-200 macro-bias flip
         if(ema200 > 0.0 && c1 > ema200)
            return true;
      }
   }
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

   if(!QM_FrameworkDeclareExecutionContract(PERIOD_H4,
                                            QM_FRIDAY_CLOSE_CARD_RULE,
                                            "QM5_12927 chande vidya trend H4"))
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

   if(!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;
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
   }

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;

   if(!QM_IsNewBar(_Symbol, PERIOD_H4)) return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
   if(Strategy_EntrySignal(req))
   {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
   }
}

void OnTimer() { QM_FrameworkOnTimer(); }

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
