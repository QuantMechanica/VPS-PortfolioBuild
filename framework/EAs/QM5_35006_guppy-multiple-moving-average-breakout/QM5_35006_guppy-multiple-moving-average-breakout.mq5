#property strict
#property version   "5.0"
#property description "QM5_35006 Daryl Guppy GMMA Breakout System"
// Strategy Card: QM5_35006 (guppy-multiple-moving-average-breakout), G0 APPROVED 2026-08-15.

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_35006
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 35006;
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
input int    strategy_fast_ema1           = 3;      // Trader EMA 1
input int    strategy_fast_ema2           = 5;      // Trader EMA 2
input int    strategy_fast_ema3           = 8;      // Trader EMA 3
input int    strategy_fast_ema4           = 10;     // Trader EMA 4
input int    strategy_fast_ema5           = 12;     // Trader EMA 5
input int    strategy_fast_ema6           = 15;     // Trader EMA 6
input int    strategy_slow_ema1           = 30;     // Investor EMA 1
input int    strategy_slow_ema2           = 35;     // Investor EMA 2
input int    strategy_slow_ema3           = 40;     // Investor EMA 3
input int    strategy_slow_ema4           = 45;     // Investor EMA 4
input int    strategy_slow_ema5           = 50;     // Investor EMA 5
input int    strategy_slow_ema6           = 60;     // Investor EMA 6
input double strategy_tp_rr_mult          = 2.5;    // 1:2.5 Risk:Reward multiplier for TP
input int    strategy_atr_period          = 14;     // ATR period for spread/volatility
input double strategy_spread_atr_mult     = 1.8;    // Spread filter ATR multiplier
input double strategy_min_sl_pips         = 10.0;   // Minimum SL distance in pips

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

int GetBarHhmm(const datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.hour * 100 + dt.min);
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   const datetime now = TimeCurrent();
   const int hhmm = GetBarHhmm(now);
   if(hhmm >= 2355 || hhmm < 5)
      return true;

   const double atr_1 = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask > 0.0 && bid > 0.0 && ask > bid && point > 0.0 && atr_1 > 0.0)
   {
      const double spread_pts = (ask - bid) / point;
      const double atr_pts = atr_1 / point;
      if(spread_pts > strategy_spread_atr_mult * atr_pts)
         return true;
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

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   const ENUM_TIMEFRAMES tf = PERIOD_H1;

   // 1. Fetch Trader Ribbon (Fast EMAs: 3, 5, 8, 10, 12, 15) on Shift = 1
   const double f1 = QM_EMA(_Symbol, tf, strategy_fast_ema1, 1);
   const double f2 = QM_EMA(_Symbol, tf, strategy_fast_ema2, 1);
   const double f3 = QM_EMA(_Symbol, tf, strategy_fast_ema3, 1);
   const double f4 = QM_EMA(_Symbol, tf, strategy_fast_ema4, 1);
   const double f5 = QM_EMA(_Symbol, tf, strategy_fast_ema5, 1);
   const double f6 = QM_EMA(_Symbol, tf, strategy_fast_ema6, 1);

   if(f1 <= 0.0 || f2 <= 0.0 || f3 <= 0.0 || f4 <= 0.0 || f5 <= 0.0 || f6 <= 0.0)
      return false;

   // 2. Fetch Investor Ribbon (Slow EMAs: 30, 35, 40, 45, 50, 60) on Shift = 1
   const double s1 = QM_EMA(_Symbol, tf, strategy_slow_ema1, 1);
   const double s2 = QM_EMA(_Symbol, tf, strategy_slow_ema2, 1);
   const double s3 = QM_EMA(_Symbol, tf, strategy_slow_ema3, 1);
   const double s4 = QM_EMA(_Symbol, tf, strategy_slow_ema4, 1);
   const double s5 = QM_EMA(_Symbol, tf, strategy_slow_ema5, 1);
   const double s6 = QM_EMA(_Symbol, tf, strategy_slow_ema6, 1);

   if(s1 <= 0.0 || s2 <= 0.0 || s3 <= 0.0 || s4 <= 0.0 || s5 <= 0.0 || s6 <= 0.0)
      return false;

   // 3. Closed Bar Prices (Shift = 1)
   const double open_1  = iOpen(_Symbol, tf, 1);   // perf-allowed: closed-bar reference behind QM_IsNewBar()
   const double close_1 = iClose(_Symbol, tf, 1);  // perf-allowed: closed-bar reference behind QM_IsNewBar()

   if(open_1 <= 0.0 || close_1 <= 0.0)
      return false;

   const double pip_size = QM_StopRulesPipsToPriceDistance(_Symbol, 1.0);
   if(pip_size <= 0.0)
      return false;

   const double min_sl_dist = strategy_min_sl_pips * pip_size;

   // 4. Long Breakout Condition
   // Trader ribbon aligned up (f1 > f2 > f3 > f4 > f5 > f6)
   // Investor ribbon aligned up (s1 > s2 > s3 > s4 > s5 > s6)
   // Trader ribbon entirely above Investor ribbon (f6 > s1)
   // Bullish candle on bar 1 (close_1 > open_1)
   const bool fast_aligned_up = (f1 > f2 && f2 > f3 && f3 > f4 && f4 > f5 && f5 > f6);
   const bool slow_aligned_up = (s1 > s2 && s2 > s3 && s3 > s4 && s4 > s5 && s5 > s6);

   if(fast_aligned_up && slow_aligned_up && (f6 > s1) && (close_1 > open_1))
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double exec_price = (ask > 0.0) ? ask : close_1;
      
      // Stop Loss placed at or below outer edge of Investor EMA(60)
      double sl_price = s6;
      double sl_dist = exec_price - sl_price;

      if(sl_dist < min_sl_dist)
      {
         sl_dist = min_sl_dist;
         sl_price = exec_price - sl_dist;
      }

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl_price;
      req.tp = exec_price + strategy_tp_rr_mult * sl_dist;
      req.reason = "gmma_breakout_long";
      return true;
   }

   // 5. Short Breakout Condition
   // Trader ribbon aligned down (f1 < f2 < f3 < f4 < f5 < f6)
   // Investor ribbon aligned down (s1 < s2 < s3 < s4 < s5 < s6)
   // Trader ribbon entirely below Investor ribbon (f6 < s1)
   // Bearish candle on bar 1 (close_1 < open_1)
   const bool fast_aligned_down = (f1 < f2 && f2 < f3 && f3 < f4 && f4 < f5 && f5 < f6);
   const bool slow_aligned_down = (s1 < s2 && s2 < s3 && s3 < s4 && s4 < s5 && s5 < s6);

   if(fast_aligned_down && slow_aligned_down && (f6 < s1) && (close_1 < open_1))
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double exec_price = (bid > 0.0) ? bid : close_1;
      
      // Stop Loss placed at or above outer edge of Investor EMA(60)
      double sl_price = s6;
      double sl_dist = sl_price - exec_price;

      if(sl_dist < min_sl_dist)
      {
         sl_dist = min_sl_dist;
         sl_price = exec_price + sl_dist;
      }

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl_price;
      req.tp = exec_price - strategy_tp_rr_mult * sl_dist;
      req.reason = "gmma_breakout_short";
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
}

bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0) return false;

   const double s1 = QM_EMA(_Symbol, PERIOD_H1, strategy_slow_ema1, 1);
   const double close_1 = iClose(_Symbol, PERIOD_H1, 1); // perf-allowed: closed-bar reference behind QM_IsNewBar()
   if(s1 <= 0.0 || close_1 <= 0.0) return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY && close_1 < s1)
         return true;
      if(pos_type == POSITION_TYPE_SELL && close_1 > s1)
         return true;
   }
   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time)
{
   return false;
}

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

void OnDeinit(const int reason)
{
   QM_FrameworkShutdown();
}

void OnTick()
{
   QM_FrameworkTrackOpenPositionMae();
   if(!QM_KillSwitchCheck()) return;
   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
   {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
   }

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;
   
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;

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

void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{
   QM_FrameworkOnTradeTransaction(t, r, res);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
