#property strict
#property version   "5.0"
#property description "QM5_35008 Robopip Short-Term Bollinger Reversion System"
// Strategy Card: QM5_35008 (short-term-bollinger-reversion-system), G0 APPROVED 2026-08-15.

#include <QM/QM_Common.mqh>
#include <Trade/Trade.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_35008
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 35008;
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
input int    strategy_bb_period           = 20;     // Bollinger Bands MA period
input double strategy_bb_dev              = 2.50;   // Bollinger Bands standard deviation
input int    strategy_rsi_period          = 14;     // RSI oscillator period
input double strategy_rsi_oversold        = 30.0;   // RSI oversold threshold
input double strategy_rsi_overbought      = 70.0;   // RSI overbought threshold
input int    strategy_atr_period          = 14;     // ATR period for stop loss and spread filter
input double strategy_sl_atr_mult         = 1.50;   // Stop loss distance as ATR multiplier
input int    strategy_entry_start_hhmm    = 1800;   // Session entry window start (GMT hhmm)
input int    strategy_entry_end_hhmm      = 2200;   // Session entry window end (GMT hhmm)
input int    strategy_exit_hhmm           = 2300;   // Time exit cutoff before rollover (GMT hhmm)
input double strategy_spread_atr_mult     = 1.80;   // Spread filter ATR multiplier

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

   const double atr_1 = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1);
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

   // 1. Evaluate Time Window: strictly 18:00 to 22:00
   const datetime bar_time_1 = iTime(_Symbol, PERIOD_M15, 1); // perf-allowed: closed-bar reference behind QM_IsNewBar()
   if(bar_time_1 <= 0)
      return false;
   const int hhmm_1 = GetBarHhmm(bar_time_1);
   if(hhmm_1 < strategy_entry_start_hhmm || hhmm_1 > strategy_entry_end_hhmm)
      return false;

   // 2. Fetch completed bar data (Shift = 1)
   const double open_1  = iOpen(_Symbol, PERIOD_M15, 1);  // perf-allowed: closed-bar reference behind QM_IsNewBar()
   const double high_1  = iHigh(_Symbol, PERIOD_M15, 1);  // perf-allowed: closed-bar reference behind QM_IsNewBar()
   const double low_1   = iLow(_Symbol, PERIOD_M15, 1);   // perf-allowed: closed-bar reference behind QM_IsNewBar()
   const double close_1 = iClose(_Symbol, PERIOD_M15, 1); // perf-allowed: closed-bar reference behind QM_IsNewBar()

   if(open_1 <= 0.0 || high_1 <= 0.0 || low_1 <= 0.0 || close_1 <= 0.0)
      return false;

   const double upper_bb  = QM_BB_Upper(_Symbol, PERIOD_M15, strategy_bb_period, strategy_bb_dev, 1);
   const double middle_bb = QM_BB_Middle(_Symbol, PERIOD_M15, strategy_bb_period, strategy_bb_dev, 1);
   const double lower_bb  = QM_BB_Lower(_Symbol, PERIOD_M15, strategy_bb_period, strategy_bb_dev, 1);
   const double rsi_1     = QM_RSI(_Symbol, PERIOD_M15, strategy_rsi_period, 1);
   const double atr_1     = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1);

   if(upper_bb <= 0.0 || middle_bb <= 0.0 || lower_bb <= 0.0 || rsi_1 <= 0.0 || atr_1 <= 0.0)
      return false;

   const double pip_size = QM_StopRulesPipsToPriceDistance(_Symbol, 1.0);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(pip_size <= 0.0 || point <= 0.0)
      return false;

   const double sl_dist = MathMax(strategy_sl_atr_mult * atr_1, 5.0 * pip_size);

   // 3. Evaluate Long Conditions: Low[1] <= LowerBB[1] AND Close[1] > Open[1] AND RSI[1] <= 30.0
   if(low_1 <= lower_bb && close_1 > open_1 && rsi_1 <= strategy_rsi_oversold)
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double exec_price = (ask > 0.0) ? ask : close_1;
      const double sl_price = QM_TM_NormalizePrice(_Symbol, exec_price - sl_dist);

      double tp_price = 0.0;
      if(middle_bb > exec_price + 3.0 * pip_size)
         tp_price = QM_TM_NormalizePrice(_Symbol, middle_bb);
      else
         tp_price = QM_TM_NormalizePrice(_Symbol, exec_price + 1.5 * sl_dist);

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl_price;
      req.tp = tp_price;
      req.reason = "bb_reversion_long";
      return true;
   }

   // 4. Evaluate Short Conditions: High[1] >= UpperBB[1] AND Close[1] < Open[1] AND RSI[1] >= 70.0
   if(high_1 >= upper_bb && close_1 < open_1 && rsi_1 >= strategy_rsi_overbought)
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double exec_price = (bid > 0.0) ? bid : close_1;
      const double sl_price = QM_TM_NormalizePrice(_Symbol, exec_price + sl_dist);

      double tp_price = 0.0;
      if(middle_bb < exec_price - 3.0 * pip_size)
         tp_price = QM_TM_NormalizePrice(_Symbol, middle_bb);
      else
         tp_price = QM_TM_NormalizePrice(_Symbol, exec_price - 1.5 * sl_dist);

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl_price;
      req.tp = tp_price;
      req.reason = "bb_reversion_short";
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
         if(current_sl > 0.0 && current_sl < open_price)
            r_dist = open_price - current_sl;
         else if(current_tp > open_price)
            r_dist = (current_tp - open_price) / 1.5;
         else
            r_dist = 15.0 * pip_size;

         // Break-even trigger at +1.0R open profit
         if((bid - open_price) >= r_dist)
         {
            const double target_sl = QM_TM_NormalizePrice(_Symbol, open_price + 1.0 * pip_size);
            if(target_sl > current_sl + point * 0.5)
               QM_TM_MoveSL(ticket, target_sl, "bb_reversion_be_plus_1");
         }
      }
      else if(pos_type == POSITION_TYPE_SELL)
      {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask <= 0.0 || open_price <= 0.0) continue;

         double r_dist = 0.0;
         if(current_sl > open_price)
            r_dist = current_sl - open_price;
         else if(current_tp > 0.0 && current_tp < open_price)
            r_dist = (open_price - current_tp) / 1.5;
         else
            r_dist = 15.0 * pip_size;

         // Break-even trigger at +1.0R open profit
         if((open_price - ask) >= r_dist)
         {
            const double target_sl = QM_TM_NormalizePrice(_Symbol, open_price - 1.0 * pip_size);
            if(current_sl <= 0.0 || target_sl < current_sl - point * 0.5)
               QM_TM_MoveSL(ticket, target_sl, "bb_reversion_be_plus_1");
         }
      }
   }
}

bool Strategy_ExitSignal()
{
   // Card §3.4: Time exit at 23:00 GMT before rollover
   const datetime now = TimeCurrent();
   const int hhmm = GetBarHhmm(now);
   if(hhmm >= strategy_exit_hhmm && hhmm < 2355)
      return true;

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
