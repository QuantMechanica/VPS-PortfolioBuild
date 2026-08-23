#property strict
#property version   "5.0"
#property description "QM5_11300 MACD + Parabolic SAR + ATR Trender (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_11300
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11300;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_timeframe          = PERIOD_H4;
input int             strategy_macd_fast          = 12;
input int             strategy_macd_slow          = 26;
input int             strategy_macd_signal        = 9;
input double          strategy_psar_step          = 0.02;
input double          strategy_psar_maximum       = 0.20;
input int             strategy_atr_period         = 14;
input double          strategy_tp_atr_mult        = 2.0;
input double          strategy_sl_max_atr_mult    = 1.5;
input int             strategy_max_spread_pips    = 20;

// -----------------------------------------------------------------------------
// Strategy helper functions
// -----------------------------------------------------------------------------

double Strategy_PipSize(const string symbol)
{
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;
   const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   return point * ((digits == 3 || digits == 5) ? 10.0 : 1.0);
}

bool Strategy_HasOpenPosition()
{
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
   }
   return false;
}

bool Strategy_SpreadAllowsEntry()
{
   if(strategy_max_spread_pips <= 0)
      return true;
   const double pip = Strategy_PipSize(_Symbol);
   if(pip <= 0.0)
      return true;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double spread_pips = (ask - bid) / pip;
   return (spread_pips <= (double)strategy_max_spread_pips);
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

   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   const double macd_main_1 = QM_MACD_Main(_Symbol, strategy_timeframe, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double macd_sig_1  = QM_MACD_Signal(_Symbol, strategy_timeframe, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double macd_main_2 = QM_MACD_Main(_Symbol, strategy_timeframe, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 2);
   const double macd_sig_2  = QM_MACD_Signal(_Symbol, strategy_timeframe, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 2);

   const double hist_1 = macd_main_1 - macd_sig_1;
   const double hist_2 = macd_main_2 - macd_sig_2;

   const double psar_1 = QM_SAR(_Symbol, strategy_timeframe, strategy_psar_step, strategy_psar_maximum, 1);
   const double atr_1  = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   if(atr_1 <= 0.0 || psar_1 <= 0.0)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, strategy_timeframe, 1, 2, rates) != 2)
      return false;

   const double low_1   = rates[0].low;
   const double high_1  = rates[0].high;

   const bool long_signal = (hist_2 <= 0.0 && hist_1 > 0.0 && psar_1 < low_1);
   const bool short_signal = (hist_2 >= 0.0 && hist_1 < 0.0 && psar_1 > high_1);

   if(!long_signal && !short_signal)
      return false;

   const QM_OrderType side = long_signal ? QM_BUY : QM_SELL;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double entry = (side == QM_BUY) ? ask : bid;

   double sl = 0.0;
   double tp = 0.0;

   if(side == QM_BUY)
   {
      sl = psar_1;
      const double max_sl_dist = strategy_sl_max_atr_mult * atr_1;
      if(entry - sl > max_sl_dist || sl >= entry)
         sl = entry - max_sl_dist;
      tp = entry + strategy_tp_atr_mult * atr_1;
   }
   else
   {
      sl = psar_1;
      const double max_sl_dist = strategy_sl_max_atr_mult * atr_1;
      if(sl - entry > max_sl_dist || sl <= entry)
         sl = entry + max_sl_dist;
      tp = entry - strategy_tp_atr_mult * atr_1;
   }

   sl = QM_StopRulesNormalizePrice(_Symbol, sl);
   tp = QM_StopRulesNormalizePrice(_Symbol, tp);

   if((side == QM_BUY && (sl >= entry || tp <= entry)) ||
      (side == QM_SELL && (sl <= entry || tp >= entry)))
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = (side == QM_BUY) ? "MACD_PSAR_LONG" : "MACD_PSAR_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
}

void Strategy_ManageOpenPosition()
{
   const int magic = QM_FrameworkMagic();
   const double psar_1 = QM_SAR(_Symbol, strategy_timeframe, strategy_psar_step, strategy_psar_maximum, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(psar_1 <= 0.0 || point <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      if(pos_type == POSITION_TYPE_BUY)
      {
         const double target = QM_StopRulesNormalizePrice(_Symbol, psar_1);
         if(target > 0.0 && target < bid && (current_sl <= 0.0 || target > current_sl + point * 0.5))
            QM_TM_MoveSL(ticket, target, "PSAR_TRAIL_LONG");
      }
      else if(pos_type == POSITION_TYPE_SELL)
      {
         const double target = QM_StopRulesNormalizePrice(_Symbol, psar_1);
         if(target > 0.0 && target > ask && (current_sl <= 0.0 || target < current_sl - point * 0.5))
            QM_TM_MoveSL(ticket, target, "PSAR_TRAIL_SHORT");
      }
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

   if(!QM_IsNewBar()) return;
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
