#property strict
#property version   "5.0"
#property description "QM5_35003 The 3 Ducks Multi-Timeframe SMA 60 System (Captain Currency)"
// Strategy Card: QM5_35003 (three-ducks-multi-timeframe-system), G0 APPROVED 2026-08-15.

#include <QM/QM_Common.mqh>
#include <Trade/Trade.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_35003
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 35003;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.5;
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
input int    strategy_sma_period          = 60;     // Universal SMA period across H4, H1, M5
input int    strategy_swing_lookback      = 10;     // M5 swing high/low breakout lookback bars
input double strategy_sl_buffer_pips      = 3.0;    // SL buffer below/above M5 60-SMA baseline in pips
input double strategy_tp_rr_mult          = 2.5;    // 1:2.5 Risk:Reward multiplier for Take Profit
input int    strategy_atr_period          = 14;     // ATR period for spread/fallback
input double strategy_spread_atr_mult     = 1.8;    // Spread filter ATR multiplier

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

   const double atr_1 = QM_ATR(_Symbol, PERIOD_M5, strategy_atr_period, 1);
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

   // 1. Duck 1: H4 SMA 60 Trend Alignment on completed bar (Shift = 1)
   const double h4_close_1 = iClose(_Symbol, PERIOD_H4, 1); // perf-allowed: closed-bar close behind QM_IsNewBar()
   const double h4_sma_1   = QM_SMA(_Symbol, PERIOD_H4, strategy_sma_period, 1);
   if(h4_close_1 <= 0.0 || h4_sma_1 <= 0.0)
      return false;

   const bool duck1_bull = (h4_close_1 > h4_sma_1);
   const bool duck1_bear = (h4_close_1 < h4_sma_1);
   if(!duck1_bull && !duck1_bear)
      return false;

   // 2. Duck 2: H1 SMA 60 Trend Alignment on completed bar (Shift = 1)
   const double h1_close_1 = iClose(_Symbol, PERIOD_H1, 1); // perf-allowed: closed-bar close behind QM_IsNewBar()
   const double h1_sma_1   = QM_SMA(_Symbol, PERIOD_H1, strategy_sma_period, 1);
   if(h1_close_1 <= 0.0 || h1_sma_1 <= 0.0)
      return false;

   const bool duck2_bull = (h1_close_1 > h1_sma_1);
   const bool duck2_bear = (h1_close_1 < h1_sma_1);
   if(!duck2_bull && !duck2_bear)
      return false;

   // 3. Duck 3: M5 SMA 60 and local swing breakout on completed bar (Shift = 1)
   const double m5_close_1 = iClose(_Symbol, PERIOD_M5, 1); // perf-allowed: closed-bar close behind QM_IsNewBar()
   const double m5_sma_1   = QM_SMA(_Symbol, PERIOD_M5, strategy_sma_period, 1);
   if(m5_close_1 <= 0.0 || m5_sma_1 <= 0.0)
      return false;

   const int lookback = MathMax(3, strategy_swing_lookback);
   double swing_high = -DBL_MAX;
   double swing_low  = DBL_MAX;

   for(int i = 2; i <= lookback + 1; ++i)
   {
      const double h = iHigh(_Symbol, PERIOD_M5, i); // perf-allowed: closed-bar high behind QM_IsNewBar()
      const double l = iLow(_Symbol, PERIOD_M5, i);  // perf-allowed: closed-bar low behind QM_IsNewBar()
      if(h <= 0.0 || l <= 0.0) return false;

      if(h > swing_high) swing_high = h;
      if(l < swing_low)  swing_low  = l;
   }

   if(swing_high <= 0.0 || swing_low >= DBL_MAX || swing_high <= swing_low)
      return false;

   const double pip_size = QM_StopRulesPipsToPriceDistance(_Symbol, 1.0);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(pip_size <= 0.0 || point <= 0.0)
      return false;

   const double atr_1 = QM_ATR(_Symbol, PERIOD_M5, strategy_atr_period, 1);
   const double min_sl_dist = (atr_1 > 0.0) ? (0.5 * atr_1) : (10.0 * pip_size);
   const double max_sl_dist = (atr_1 > 0.0) ? (3.5 * atr_1) : (80.0 * pip_size);
   const double sl_buffer = strategy_sl_buffer_pips * pip_size;

   // 4. Long Signal: All 3 Ducks Bullish & M5 Breakout above Swing High
   if(duck1_bull && duck2_bull && (m5_close_1 > m5_sma_1) && (m5_close_1 > swing_high))
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double exec_price = (ask > 0.0) ? ask : m5_close_1;
      double sl_price = m5_sma_1 - sl_buffer;
      double sl_dist = exec_price - sl_price;

      if(sl_dist < min_sl_dist)
      {
         sl_dist = min_sl_dist;
         sl_price = exec_price - sl_dist;
      }
      else if(sl_dist > max_sl_dist)
      {
         sl_dist = max_sl_dist;
         sl_price = exec_price - sl_dist;
      }

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl_price;
      req.tp = exec_price + strategy_tp_rr_mult * sl_dist;
      req.reason = "three_ducks_long";
      return true;
   }

   // 5. Short Signal: All 3 Ducks Bearish & M5 Breakout below Swing Low
   if(duck1_bear && duck2_bear && (m5_close_1 < m5_sma_1) && (m5_close_1 < swing_low))
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double exec_price = (bid > 0.0) ? bid : m5_close_1;
      double sl_price = m5_sma_1 + sl_buffer;
      double sl_dist = sl_price - exec_price;

      if(sl_dist < min_sl_dist)
      {
         sl_dist = min_sl_dist;
         sl_price = exec_price + sl_dist;
      }
      else if(sl_dist > max_sl_dist)
      {
         sl_dist = max_sl_dist;
         sl_price = exec_price + sl_dist;
      }

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl_price;
      req.tp = exec_price - strategy_tp_rr_mult * sl_dist;
      req.reason = "three_ducks_short";
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0) return;
   const double pip_size = QM_StopRulesPipsToPriceDistance(_Symbol, 1.0);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(pip_size <= 0.0 || point <= 0.0) return;

   const double m5_sma_1 = QM_SMA(_Symbol, PERIOD_M5, strategy_sma_period, 1);
   const double sl_buffer = strategy_sl_buffer_pips * pip_size;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double current_tp = PositionGetDouble(POSITION_TP);

      if(pos_type == POSITION_TYPE_BUY)
      {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid <= 0.0 || open_price <= 0.0) continue;

         double r_dist = 0.0;
         if(current_tp > open_price)
            r_dist = (current_tp - open_price) / strategy_tp_rr_mult;
         else if(current_sl > 0.0 && current_sl < open_price)
            r_dist = open_price - current_sl;
         else
            r_dist = 20.0 * pip_size;

         // Once in +1.0R profit, trail with M5 SMA 60 baseline
         if((bid - open_price) >= r_dist)
         {
            double target_sl = open_price + 1.0 * pip_size;
            if(m5_sma_1 > 0.0)
            {
               const double sma_sl = m5_sma_1 - sl_buffer;
               if(sma_sl > target_sl)
                  target_sl = sma_sl;
            }
            target_sl = QM_TM_NormalizePrice(_Symbol, target_sl);
            if(target_sl > current_sl + point * 0.5)
               QM_TM_MoveSL(ticket, target_sl, "three_ducks_trail_sma");
         }
      }
      else if(pos_type == POSITION_TYPE_SELL)
      {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask <= 0.0 || open_price <= 0.0) continue;

         double r_dist = 0.0;
         if(current_tp > 0.0 && current_tp < open_price)
            r_dist = (open_price - current_tp) / strategy_tp_rr_mult;
         else if(current_sl > open_price)
            r_dist = current_sl - open_price;
         else
            r_dist = 20.0 * pip_size;

         // Once in +1.0R profit, trail with M5 SMA 60 baseline
         if((open_price - ask) >= r_dist)
         {
            double target_sl = open_price - 1.0 * pip_size;
            if(m5_sma_1 > 0.0)
            {
               const double sma_sl = m5_sma_1 + sl_buffer;
               if(sma_sl < target_sl)
                  target_sl = sma_sl;
            }
            target_sl = QM_TM_NormalizePrice(_Symbol, target_sl);
            if(current_sl <= 0.0 || target_sl < current_sl - point * 0.5)
               QM_TM_MoveSL(ticket, target_sl, "three_ducks_trail_sma");
         }
      }
   }
}

bool Strategy_ExitSignal()
{
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
