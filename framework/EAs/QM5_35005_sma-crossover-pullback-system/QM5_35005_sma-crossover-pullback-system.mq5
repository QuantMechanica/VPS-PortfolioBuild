#property strict
#property version   "5.0"
#property description "QM5_35005 Robopip SMA Crossover Pullback System"
// Strategy Card: QM5_35005 (sma-crossover-pullback-system), G0 APPROVED 2026-08-15.

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_35005
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 35005;
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
input int    strategy_fast_sma            = 100;    // Fast baseline trend SMA period (H1)
input int    strategy_slow_sma            = 200;    // Slow baseline trend SMA period (H1)
input int    strategy_stoch_k             = 14;     // Stochastic %K period
input int    strategy_stoch_d             = 3;      // Stochastic %D period
input int    strategy_stoch_slowing       = 3;      // Stochastic slowing
input double strategy_stoch_oversold      = 20.0;   // Stochastic oversold pullback threshold
input double strategy_stoch_overbought    = 80.0;   // Stochastic overbought pullback threshold
input int    strategy_tp_pips             = 300;    // Take profit in pips (300 pips)
input int    strategy_sl_pips             = 150;    // Stop loss in pips (150 pips)
input int    strategy_trailing_trigger_pips = 150;  // Trailing stop trigger profit in pips
input int    strategy_trailing_step_pips  = 150;    // Trailing stop step distance in pips
input int    strategy_atr_period          = 14;     // ATR period for spread/volatility
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

   // 1. Evaluate Macro Trend via 100 and 200 SMA on closed bar (Shift = 1)
   const double sma_fast = QM_SMA(_Symbol, tf, strategy_fast_sma, 1);
   const double sma_slow = QM_SMA(_Symbol, tf, strategy_slow_sma, 1);

   if(sma_fast <= 0.0 || sma_slow <= 0.0)
      return false;

   // 2. Evaluate Stochastic Pullback on closed bars (Shift = 1 and Shift = 2)
   const double stoch_k_1 = QM_Stoch_K(_Symbol, tf, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 1);
   const double stoch_d_1 = QM_Stoch_D(_Symbol, tf, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 1);
   const double stoch_k_2 = QM_Stoch_K(_Symbol, tf, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 2);

   // 3. Long Entry: Bullish Trend + Oversold Pullback Reversal
   // SMA(100)[1] > SMA(200)[1] AND Stoch_K[2] <= 20.0 AND Stoch_K[1] > Stoch_D[1]
   if((sma_fast > sma_slow) && (stoch_k_2 <= strategy_stoch_oversold) && (stoch_k_1 > stoch_d_1))
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double exec_price = (ask > 0.0) ? ask : iClose(_Symbol, tf, 1); // perf-allowed: closed-bar reference behind QM_IsNewBar()
      const double sl = QM_StopFixedPips(_Symbol, QM_BUY, exec_price, strategy_sl_pips);
      const double tp = QM_TakeFixedPips(_Symbol, QM_BUY, exec_price, strategy_tp_pips);

      if(sl <= 0.0 || tp <= 0.0)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl;
      req.tp = tp;
      req.reason = "sma_pullback_long";
      return true;
   }

   // 4. Short Entry: Bearish Trend + Overbought Pullback Reversal
   // SMA(100)[1] < SMA(200)[1] AND Stoch_K[2] >= 80.0 AND Stoch_K[1] < Stoch_D[1]
   if((sma_fast < sma_slow) && (stoch_k_2 >= strategy_stoch_overbought) && (stoch_k_1 < stoch_d_1))
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double exec_price = (bid > 0.0) ? bid : iClose(_Symbol, tf, 1); // perf-allowed: closed-bar reference behind QM_IsNewBar()
      const double sl = QM_StopFixedPips(_Symbol, QM_SELL, exec_price, strategy_sl_pips);
      const double tp = QM_TakeFixedPips(_Symbol, QM_SELL, exec_price, strategy_tp_pips);

      if(sl <= 0.0 || tp <= 0.0)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl;
      req.tp = tp;
      req.reason = "sma_pullback_short";
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

      QM_TM_TrailStep(ticket, strategy_trailing_trigger_pips, strategy_trailing_step_pips);
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
