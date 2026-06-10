#property strict
#property version   "5.0"
#property description "QM5_9462 — Bollinger Band outer-band fade (mean-reversion)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9462 gh-bbands-fade
// Source: pipbolt.io, GitHub Bollinger-Bands-EA.mq5
// Logic: Enter LONG when closed-bar close < lower BB(20,2). Enter SHORT when
//        closed-bar close > upper BB(20,2). Exit when close crosses opposite
//        band. Stop = ATR(14)*2. One position per magic.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9462;
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
input int    strategy_bb_period         = 20;
input double strategy_bb_deviation      = 2.0;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 2.0;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Requires one active position max — skip if already in a trade.
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) == magic &&
         PositionGetString(POSITION_SYMBOL) == _Symbol)
         return false;
     }

   const double close1  = QM_SMA(_Symbol, PERIOD_CURRENT, 1, 1); // SMA(1) = close[1] — closed-bar close via framework helper
   const double bb_lower = QM_BB_Lower(_Symbol, PERIOD_CURRENT, strategy_bb_period, strategy_bb_deviation, 1);
   const double bb_upper = QM_BB_Upper(_Symbol, PERIOD_CURRENT, strategy_bb_period, strategy_bb_deviation, 1);

   if(bb_lower == EMPTY_VALUE || bb_upper == EMPTY_VALUE || close1 == 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   if(close1 < bb_lower)
     {
      // Long fade
      req.type   = QM_BUY;
      req.price  = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.sl     = req.price - atr * strategy_atr_sl_mult;
      req.tp     = 0.0; // exit via Strategy_ExitSignal (opposite band)
      req.reason = "gh-bbands-fade LONG";
      return true;
     }

   if(close1 > bb_upper)
     {
      // Short fade
      req.type   = QM_SELL;
      req.price  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      req.sl     = req.price + atr * strategy_atr_sl_mult;
      req.tp     = 0.0;
      req.reason = "gh-bbands-fade SHORT";
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // No intra-trade management beyond SL; exit handled by Strategy_ExitSignal.
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double close1   = QM_SMA(_Symbol, PERIOD_CURRENT, 1, 1); // SMA(1) = close[1] — closed-bar close via framework helper
      const double bb_upper = QM_BB_Upper(_Symbol, PERIOD_CURRENT, strategy_bb_period, strategy_bb_deviation, 1);
      const double bb_lower = QM_BB_Lower(_Symbol, PERIOD_CURRENT, strategy_bb_period, strategy_bb_deviation, 1);

      if(bb_upper == EMPTY_VALUE || bb_lower == EMPTY_VALUE || close1 == 0.0)
         continue;

      if(pos_type == POSITION_TYPE_BUY  && close1 > bb_upper)
         return true;
      if(pos_type == POSITION_TYPE_SELL && close1 < bb_lower)
         return true;
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line.
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
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
   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

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
