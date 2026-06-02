#property strict
#property version   "5.0"
#property description "QM5_10568_v2 MQL5 XDPO Histogram Direction Change"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10568;
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
input ENUM_TIMEFRAMES strategy_signal_tf = PERIOD_H12;
input int    strategy_dpo_period       = 14;
input int    strategy_atr_period       = 14;
input double strategy_atr_sl_mult      = 2.0;
input double strategy_rr_target        = 1.5;

double Strategy_XdpoValue(const string sym, const ENUM_TIMEFRAMES tf, const int period, const int shift)
  {
   if(period <= 1 || shift < 0)
      return 0.0;
   const int dpo_shift = period / 2 + 1;
   const double close_value = iClose(sym, tf, shift);
   const double average = QM_SMA(sym, tf, period, shift + dpo_shift, PRICE_CLOSE);
   if(close_value <= 0.0 || average <= 0.0)
      return 0.0;
   return close_value - average;
  }

int Strategy_XdpoTurn()
  {
   const double h1 = Strategy_XdpoValue(_Symbol, strategy_signal_tf, strategy_dpo_period, 1);
   const double h2 = Strategy_XdpoValue(_Symbol, strategy_signal_tf, strategy_dpo_period, 2);
   const double h3 = Strategy_XdpoValue(_Symbol, strategy_signal_tf, strategy_dpo_period, 3);
   const double d1 = h1 - h2;
   const double d2 = h2 - h3;
   if(h1 > 0.0 && d2 <= 0.0 && d1 > 0.0)
      return 1;
   if(h1 < 0.0 && d2 >= 0.0 && d1 < 0.0)
      return -1;
   return 0;
  }

bool Strategy_HasOurPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool Strategy_ReadOurPositionType(ENUM_POSITION_TYPE &position_type)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }
   return false;
  }

bool Strategy_NoTradeFilter()
  {
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
   if(strategy_dpo_period <= 1 || strategy_atr_period <= 0 ||
      strategy_atr_sl_mult <= 0.0 || strategy_rr_target <= 0.0)
      return false;
   if(Strategy_HasOurPosition())
      return false;
   const int turn = Strategy_XdpoTurn();
   if(turn == 0)
      return false;
   const QM_OrderType side = (turn > 0) ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;
   const double atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;
   req.type = side;
   req.sl = QM_StopATRFromValue(_Symbol, side, entry, atr, strategy_atr_sl_mult);
   req.tp = QM_TakeRR(_Symbol, side, entry, req.sl, strategy_rr_target);
   req.reason = (side == QM_BUY) ? "MQL5_XDPO_HIST_LONG" : "MQL5_XDPO_HIST_SHORT";
   return (req.sl > 0.0 && req.tp > 0.0);
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE position_type;
   if(!Strategy_ReadOurPositionType(position_type))
      return false;
   const int turn = Strategy_XdpoTurn();
   if(position_type == POSITION_TYPE_BUY && turn < 0)
      return true;
   if(position_type == POSITION_TYPE_SELL && turn > 0)
      return true;
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact,
                        qm_rng_seed, qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
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

void OnTimer()        { QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  { QM_FrameworkOnTradeTransaction(trans, request, result); }
double OnTester()     { QM_ChartUI_Refresh(); return QM_DefaultObjective(); }
