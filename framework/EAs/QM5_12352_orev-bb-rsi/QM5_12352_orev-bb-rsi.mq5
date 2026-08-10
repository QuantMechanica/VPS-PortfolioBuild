#property strict
#property version   "5.0"
#property description "QM5_12352 Bollinger RSI Pullback"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_12352
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12352;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.5;
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
input ENUM_TIMEFRAMES strategy_signal_tf = PERIOD_D1;
input int    strategy_rsi_period         = 3;
input double strategy_rsi_entry          = 30.0;
input int    strategy_bb_period          = 21;
input double strategy_bb_deviation       = 2.0;
input int    strategy_sma_fast           = 50;
input int    strategy_sma_slow           = 150;
input int    strategy_max_hold_days      = 4;

// -----------------------------------------------------------------------------
// Helper Functions
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
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

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

   if(_Period != strategy_signal_tf)
      return false;

   // Check if we already have a position
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price, sl, tp;
   datetime open_time;
   if(Strategy_SelectOurPosition(ticket, position_type, open_price, sl, tp, open_time))
      return false;

   // Calculate indicators on closed D1 bar (shift 1)
   const double close1 = iClose(_Symbol, strategy_signal_tf, 1); // perf-allowed: entry signal reference
   const double rsi1 = QM_RSI(_Symbol, strategy_signal_tf, strategy_rsi_period, 1);
   const double sma_fast1 = QM_SMA(_Symbol, strategy_signal_tf, strategy_sma_fast, 1);
   const double sma_slow1 = QM_SMA(_Symbol, strategy_signal_tf, strategy_sma_slow, 1);
   const double bb_lower1 = QM_BB_Lower(_Symbol, strategy_signal_tf, strategy_bb_period, strategy_bb_deviation, 1);

   if(rsi1 <= 0.0 || sma_fast1 <= 0.0 || sma_slow1 <= 0.0 || bb_lower1 <= 0.0)
      return false;

   // Entry conditions (Long-only)
   if(close1 > sma_fast1 && sma_fast1 > sma_slow1 && rsi1 < strategy_rsi_entry && close1 <= bb_lower1)
   {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, entry * (1.0 - 0.20));
      req.tp = QM_StopRulesNormalizePrice(_Symbol, entry * (1.0 + 0.03));
      req.reason = "QM5_12352_LONG";
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
{
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price;
   double sl;
   double tp;
   datetime open_time;
   if(!Strategy_SelectOurPosition(ticket, position_type, open_price, sl, tp, open_time))
      return false;

   // Check time stop (4 calendar days)
   if(open_time > 0 && (TimeCurrent() - open_time) >= strategy_max_hold_days * 24 * 3600)
      return true;

   // Check percent profit/loss
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(bid <= 0.0 || open_price <= 0.0)
      return false;

   const double profit_pct = (bid - open_price) / open_price;
   if(profit_pct >= 0.03 || profit_pct <= -0.20)
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
   QM_FrameworkTrackOpenPositionMae(); // first: no guard may skip Q08 evidence
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
