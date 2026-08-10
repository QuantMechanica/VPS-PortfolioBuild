#property strict
#property version   "5.0"
#property description "QM5_11533 Carter-T H1 -- EMA(3/5/13/21/80) Ribbon + RSI(21)"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11533;
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
input int    strategy_ema_fast               = 3;
input int    strategy_ema_signal              = 5;
input int    strategy_ema_medium              = 13;
input int    strategy_ema_slow                = 21;
input int    strategy_ema_structural          = 80;
input int    strategy_rsi_period              = 21;
input double strategy_rsi_threshold           = 50.0;
input int    strategy_sl_pips                 = 25;
input bool   strategy_skip_friday_setup       = true;
input int    strategy_max_spread_pips         = 15;

// -----------------------------------------------------------------------------
// Card: Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)",
// System #7. Source: D:/QM/strategy_farm/artifacts/cards_approved/
// QM5_11533_carter-t-h1-ema3-5-13-21-80-rsi21.md
//
// 5-EMA ribbon (3/5/13/21/80). Entry: EMA3 crosses EMA5 in the ribbon's
// established direction (EMA13/21 both on the same side of the EMA80
// structural baseline), confirmed by RSI(21) vs 50. Exit on EMA3/5 reverse
// cross or RSI crossing back through 50; fixed pip SL as a hard backstop.
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   if(strategy_sl_pips <= 0 || strategy_rsi_period <= 0)
      return true;

   if(strategy_max_spread_pips > 0)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double max_spread_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_max_spread_pips);
      if(ask > bid && max_spread_dist > 0.0 && (ask - bid) > max_spread_dist)
         return true;
     }
   return false;
  }

bool Strategy_HasOpenPosition(int &out_pos_type)
  {
   out_pos_type = -1;
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
      out_pos_type = (int)PositionGetInteger(POSITION_TYPE);
      return true;
     }
   return false;
  }

bool Strategy_ExitSignal()
  {
   int pos_type = -1;
   if(!Strategy_HasOpenPosition(pos_type))
      return false;

   const double ema3_2 = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_fast, 2);
   const double ema3_1 = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_fast, 1);
   const double ema5_2 = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_signal, 2);
   const double ema5_1 = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_signal, 1);
   const double rsi_1  = QM_RSI(_Symbol, PERIOD_CURRENT, strategy_rsi_period, 1);
   if(ema3_2 <= 0.0 || ema3_1 <= 0.0 || ema5_2 <= 0.0 || ema5_1 <= 0.0 || rsi_1 <= 0.0)
      return false;

   if(pos_type == POSITION_TYPE_BUY)
     {
      const bool cross_down = (ema3_2 >= ema5_2) && (ema3_1 < ema5_1);
      return (cross_down || rsi_1 < strategy_rsi_threshold);
     }

   const bool cross_up = (ema3_2 <= ema5_2) && (ema3_1 > ema5_1);
   return (cross_up || rsi_1 > strategy_rsi_threshold);
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
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;

   if(strategy_skip_friday_setup)
     {
      const datetime t1 = iTime(_Symbol, PERIOD_CURRENT, 1);
      MqlDateTime dt;
      TimeToStruct(t1, dt);
      if(dt.day_of_week == 5)
         return false;
     }

   const double ema3_2 = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_fast, 2);
   const double ema3_1 = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_fast, 1);
   const double ema5_2 = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_signal, 2);
   const double ema5_1 = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_signal, 1);
   const double ema13_1 = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_medium, 1);
   const double ema21_1 = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_slow, 1);
   const double ema80_1 = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_structural, 1);
   const double rsi_1   = QM_RSI(_Symbol, PERIOD_CURRENT, strategy_rsi_period, 1);
   if(ema3_2 <= 0.0 || ema3_1 <= 0.0 || ema5_2 <= 0.0 || ema5_1 <= 0.0 ||
      ema13_1 <= 0.0 || ema21_1 <= 0.0 || ema80_1 <= 0.0 || rsi_1 <= 0.0)
      return false;

   const bool cross_up   = (ema3_2 <= ema5_2) && (ema3_1 > ema5_1);
   const bool cross_down = (ema3_2 >= ema5_2) && (ema3_1 < ema5_1);

   const bool go_long  = cross_up   && (ema13_1 > ema80_1) && (ema21_1 > ema80_1) && (rsi_1 > strategy_rsi_threshold);
   const bool go_short = cross_down && (ema13_1 < ema80_1) && (ema21_1 < ema80_1) && (rsi_1 < strategy_rsi_threshold);
   if(!go_long && !go_short)
      return false;

   const QM_OrderType side = go_long ? QM_BUY : QM_SELL;
   const double entry = go_long ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_pips);
   if(sl_dist <= 0.0)
      return false;

   const double sl_price = go_long ? (entry - sl_dist) : (entry + sl_dist);

   req.type = side;
   req.price = 0.0;
   req.sl = NormalizeDouble(sl_price, _Digits);
   req.tp = 0.0;
   req.reason = go_long ? "CARTERT_EMARIBBON_RSI_LONG" : "CARTERT_EMARIBBON_RSI_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return (req.sl > 0.0);
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED,
                        PORTFOLIO_WEIGHT, qm_news_mode_legacy, qm_friday_close_enabled,
                        qm_friday_close_hour_broker, 30, 30, qm_news_stale_max_hours,
                        qm_news_min_impact, qm_rng_seed, qm_stress_reject_probability,
                        qm_news_temporal, qm_news_compliance))
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
