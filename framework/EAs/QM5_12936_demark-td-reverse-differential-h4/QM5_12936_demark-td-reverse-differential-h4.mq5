#property strict
#property version   "5.0"
#property description "QM5_12936 DeMark TD-Reverse-Differential H4"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_12936 DeMark TD-Reverse-Differential H4
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12936;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours    = 336;
input string qm_news_min_impact         = "high";
input QM_NewsMode qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_signal_tf             = PERIOD_H4;
input int             strategy_atr_period            = 14;
input int             strategy_sma_d1_period         = 200;
input double          strategy_min_range_atr_mult    = 0.40;
input double          strategy_max_pullback_atr_mult = 1.50;
input double          strategy_max_spread_atr_mult   = 0.30;
input int             strategy_cooldown_bars         = 4;
input double          strategy_sl_atr_mult           = 1.50;
input double          strategy_tp_atr_mult           = 1.50;
input int             strategy_time_stop_bars        = 8;
input double          strategy_be_trigger_atr_mult   = 0.75;
input double          strategy_trail_trigger_atr_mult = 1.50;

datetime g_last_buy_signal_time = 0;
datetime g_last_sell_signal_time = 0;

// -----------------------------------------------------------------------------
// Helper routines
// -----------------------------------------------------------------------------

bool Strategy_SelectOurPosition(ulong &ticket,
                                ENUM_POSITION_TYPE &position_type,
                                double &open_price,
                                double &sl,
                                double &tp,
                                datetime &open_time)
{
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   open_price = 0.0;
   sl = 0.0;
   tp = 0.0;
   open_time = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0) return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      ticket = candidate;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      sl = PositionGetDouble(POSITION_SL);
      tp = PositionGetDouble(POSITION_TP);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
   }
   return false;
}

bool Strategy_CheckBuyTDReverseDiff(const MqlRates &bar1, const MqlRates &bar2, const MqlRates &bar3)
{
   // 1. Close[2] > Close[3] (upward close progression)
   if(bar2.close <= bar3.close) return false;
   // 2. Close[1] < Close[2] (pullback/fade)
   if(bar1.close >= bar2.close) return false;
   // 3. (Close[1] - Low[1]) > (Close[2] - Low[2]) (rebound-from-low strengthening)
   if((bar1.close - bar1.low) <= (bar2.close - bar2.low)) return false;
   // 4. (High[1] - Close[1]) < (High[2] - Close[2]) (less upper shadow on current bar)
   if((bar1.high - bar1.close) >= (bar2.high - bar2.close)) return false;
   // 5. Low[1] > Low[2] (higher low)
   if(bar1.low <= bar2.low) return false;

   return true;
}

bool Strategy_CheckSellTDReverseDiff(const MqlRates &bar1, const MqlRates &bar2, const MqlRates &bar3)
{
   // 1. Close[2] < Close[3] (downward close progression)
   if(bar2.close >= bar3.close) return false;
   // 2. Close[1] > Close[2] (pullback/bounce)
   if(bar1.close <= bar2.close) return false;
   // 3. (High[1] - Close[1]) > (High[2] - Close[2]) (rebound-from-high strengthening)
   if((bar1.high - bar1.close) <= (bar2.high - bar2.close)) return false;
   // 4. (Close[1] - Low[1]) < (Close[2] - Low[2]) (less lower shadow on current bar)
   if((bar1.close - bar1.low) >= (bar2.close - bar2.low)) return false;
   // 5. High[1] < High[2] (lower high)
   if(bar1.high >= bar2.high) return false;

   return true;
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter() { return false; }

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(_Period != strategy_signal_tf) return false;
   if(strategy_atr_period <= 0 || strategy_sma_d1_period <= 0) return false;

   const double atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   if(atr <= 0.0) return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid) return false;
   const double spread = ask - bid;
   if(strategy_max_spread_atr_mult > 0.0 && spread > strategy_max_spread_atr_mult * atr) return false;

   MqlRates bar1, bar2, bar3;
   if(!QM_ReadBar(_Symbol, strategy_signal_tf, 1, bar1) ||
      !QM_ReadBar(_Symbol, strategy_signal_tf, 2, bar2) ||
      !QM_ReadBar(_Symbol, strategy_signal_tf, 3, bar3))
      return false;

   const double range1 = bar1.high - bar1.low;
   if(range1 < strategy_min_range_atr_mult * atr) return false;

   const double sma_d1 = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_d1_period, 1);
   MqlRates d1_bar;
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 1, d1_bar)) return false;
   if(sma_d1 <= 0.0) return false;

   const int tf_seconds = PeriodSeconds(strategy_signal_tf);

   if(Strategy_CheckBuyTDReverseDiff(bar1, bar2, bar3))
   {
      if(d1_bar.close > sma_d1)
      {
         if(bar1.low >= bar2.low - strategy_max_pullback_atr_mult * atr)
         {
            if(g_last_buy_signal_time == 0 || (bar1.time - g_last_buy_signal_time >= strategy_cooldown_bars * tf_seconds))
            {
               const double entry = ask;
               const double sl = QM_StopRulesNormalizePrice(_Symbol, entry - strategy_sl_atr_mult * atr);
               const double tp = QM_StopRulesNormalizePrice(_Symbol, entry + strategy_tp_atr_mult * atr);
               if(sl > 0.0 && sl < entry && tp > entry)
               {
                  req.type = QM_BUY;
                  req.price = 0.0;
                  req.sl = sl;
                  req.tp = tp;
                  req.reason = "TD_REV_DIFF_BUY";
                  g_last_buy_signal_time = bar1.time;
                  return true;
               }
            }
         }
      }
   }

   if(Strategy_CheckSellTDReverseDiff(bar1, bar2, bar3))
   {
      if(d1_bar.close < sma_d1)
      {
         if(bar1.high <= bar2.high + strategy_max_pullback_atr_mult * atr)
         {
            if(g_last_sell_signal_time == 0 || (bar1.time - g_last_sell_signal_time >= strategy_cooldown_bars * tf_seconds))
            {
               const double entry = bid;
               const double sl = QM_StopRulesNormalizePrice(_Symbol, entry + strategy_sl_atr_mult * atr);
               const double tp = QM_StopRulesNormalizePrice(_Symbol, entry - strategy_tp_atr_mult * atr);
               if(sl > entry && tp > 0.0 && tp < entry)
               {
                  req.type = QM_SELL;
                  req.price = 0.0;
                  req.sl = sl;
                  req.tp = tp;
                  req.reason = "TD_REV_DIFF_SELL";
                  g_last_sell_signal_time = bar1.time;
                  return true;
               }
            }
         }
      }
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price, sl, tp;
   datetime open_time;
   if(!Strategy_SelectOurPosition(ticket, position_type, open_price, sl, tp, open_time))
      return;
   if(open_price <= 0.0) return;

   const double atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   if(atr <= 0.0) return;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0) return;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0) return;
   const double spread = ask - bid;

   MqlRates bar2;
   QM_ReadBar(_Symbol, strategy_signal_tf, 2, bar2);

   if(position_type == POSITION_TYPE_BUY)
   {
      const double profit = bid - open_price;
      double new_sl = 0.0;

      if(strategy_trail_trigger_atr_mult > 0.0 && profit >= strategy_trail_trigger_atr_mult * atr && bar2.low > 0.0)
      {
         new_sl = MathMax(open_price + spread, bar2.low);
      }
      else if(strategy_be_trigger_atr_mult > 0.0 && profit >= strategy_be_trigger_atr_mult * atr)
      {
         new_sl = open_price + spread;
      }

      if(new_sl > 0.0)
      {
         new_sl = QM_StopRulesNormalizePrice(_Symbol, new_sl);
         if((sl <= 0.0 || new_sl > sl + point * 0.5) && new_sl < bid)
         {
            QM_TM_MoveSL(ticket, new_sl, "td_rev_diff_trail_buy");
         }
      }
   }
   else if(position_type == POSITION_TYPE_SELL)
   {
      const double profit = open_price - ask;
      double new_sl = 0.0;

      if(strategy_trail_trigger_atr_mult > 0.0 && profit >= strategy_trail_trigger_atr_mult * atr && bar2.high > 0.0)
      {
         new_sl = MathMin(open_price - spread, bar2.high);
      }
      else if(strategy_be_trigger_atr_mult > 0.0 && profit >= strategy_be_trigger_atr_mult * atr)
      {
         new_sl = open_price - spread;
      }

      if(new_sl > 0.0)
      {
         new_sl = QM_StopRulesNormalizePrice(_Symbol, new_sl);
         if((sl <= 0.0 || new_sl < sl - point * 0.5) && new_sl > ask)
         {
            QM_TM_MoveSL(ticket, new_sl, "td_rev_diff_trail_sell");
         }
      }
   }
}

bool Strategy_ExitSignal()
{
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price, sl, tp;
   datetime open_time;
   if(!Strategy_SelectOurPosition(ticket, position_type, open_price, sl, tp, open_time))
      return false;

   const int tf_seconds = PeriodSeconds(strategy_signal_tf);
   if(tf_seconds > 0 && strategy_time_stop_bars > 0 && open_time > 0)
   {
      if(TimeCurrent() - open_time >= strategy_time_stop_bars * tf_seconds)
         return true;
   }

   if(!QM_IsNewBar(_Symbol, strategy_signal_tf)) return false;

   MqlRates bar1, bar2, bar3;
   if(!QM_ReadBar(_Symbol, strategy_signal_tf, 1, bar1) ||
      !QM_ReadBar(_Symbol, strategy_signal_tf, 2, bar2) ||
      !QM_ReadBar(_Symbol, strategy_signal_tf, 3, bar3))
      return false;

   if(position_type == POSITION_TYPE_BUY && Strategy_CheckSellTDReverseDiff(bar1, bar2, bar3))
      return true;
   if(position_type == POSITION_TYPE_SELL && Strategy_CheckBuyTDReverseDiff(bar1, bar2, bar3))
      return true;

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
   QM_FrameworkTrackOpenPositionMae();
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
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
   }

   if(!QM_IsNewBar(_Symbol, strategy_signal_tf)) return;
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
   {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
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
