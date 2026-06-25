#property strict
#property version   "5.0"
#property description "QM5_11613 RoboForex BB WPR RSI M15 mean reversion"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11613;
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
input ENUM_TIMEFRAMES strategy_signal_tf = PERIOD_M15;
input int    strategy_bb_period         = 20;
input double strategy_bb_deviation      = 2.0;
input int    strategy_wpr_period        = 25;
input double strategy_wpr_oversold      = -80.0;
input double strategy_wpr_overbought    = -20.0;
input int    strategy_rsi_period        = 5;
input double strategy_rsi_oversold      = 30.0;
input double strategy_rsi_overbought    = 70.0;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 2.0;
input double strategy_atr_fallback_tp_mult = 4.0;

// -----------------------------------------------------------------------------
// Strategy hooks.
// -----------------------------------------------------------------------------

// No Trade Filter (time, spread, news): the card specifies no strategy-local
// time or spread filter. Central framework news and Friday-close gates remain on.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Trade Entry: BB(20,2) band touch plus RSI(5) and WPR(25) oversold/overbought.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_bb_period < 2 || strategy_wpr_period < 2 ||
      strategy_rsi_period < 2 || strategy_atr_period < 1 ||
      strategy_atr_sl_mult <= 0.0 || strategy_atr_fallback_tp_mult <= 0.0)
      return false;

   MqlRates rates[2];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, strategy_signal_tf, 1, 2, rates) != 2) // perf-allowed: fixed 2-bar card OHLC read inside framework new-bar entry hook.
      return false;

   const double rsi_1 = QM_RSI(_Symbol, strategy_signal_tf, strategy_rsi_period, 1, PRICE_CLOSE);
   const double rsi_2 = QM_RSI(_Symbol, strategy_signal_tf, strategy_rsi_period, 2, PRICE_CLOSE);
   const double wpr_1 = QM_WPR(_Symbol, strategy_signal_tf, strategy_wpr_period, 1);
   const double lower = QM_BB_Lower(_Symbol, strategy_signal_tf, strategy_bb_period, strategy_bb_deviation, 1, PRICE_CLOSE);
   const double upper = QM_BB_Upper(_Symbol, strategy_signal_tf, strategy_bb_period, strategy_bb_deviation, 1, PRICE_CLOSE);
   const double middle = QM_BB_Middle(_Symbol, strategy_signal_tf, strategy_bb_period, strategy_bb_deviation, 1, PRICE_CLOSE);
   const double atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   if(rsi_1 <= 0.0 || rsi_2 <= 0.0 || lower <= 0.0 || upper <= 0.0 || middle <= 0.0 || atr <= 0.0)
      return false;

   const bool long_signal =
      (rsi_1 < strategy_rsi_oversold && rsi_2 >= strategy_rsi_oversold &&
       wpr_1 < strategy_wpr_oversold &&
       rates[0].low <= lower);

   const bool short_signal =
      (rsi_1 > strategy_rsi_overbought && rsi_2 <= strategy_rsi_overbought &&
       wpr_1 > strategy_wpr_overbought &&
       rates[0].high >= upper);

   if(!long_signal && !short_signal)
      return false;

   const QM_OrderType side = long_signal ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY)
      ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
      : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;

   double tp = 0.0;
   if(side == QM_BUY)
      tp = (middle > entry) ? middle : QM_TakeATRFromValue(_Symbol, side, entry, atr, strategy_atr_fallback_tp_mult);
   else
      tp = (middle < entry) ? middle : QM_TakeATRFromValue(_Symbol, side, entry, atr, strategy_atr_fallback_tp_mult);

   req.type = side;
   req.sl = sl;
   req.tp = tp;
   req.reason = long_signal ? "BB_WPR_RSI_LONG" : "BB_WPR_RSI_SHORT";
   return true;
  }

// Trade Management: the card specifies no trailing, partial close, or break-even.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close: close at the current BB(20,2) middle band.
bool Strategy_ExitSignal()
  {
   if(strategy_bb_period < 2)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   MqlRates rates[1];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, strategy_signal_tf, 1, 1, rates) != 1) // perf-allowed: fixed 1-bar close read inside strategy exit hook.
      return false;

   const double middle = QM_BB_Middle(_Symbol, strategy_signal_tf, strategy_bb_period, strategy_bb_deviation, 1, PRICE_CLOSE);
   if(middle <= 0.0)
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

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && rates[0].close >= middle)
         return true;
      if(ptype == POSITION_TYPE_SELL && rates[0].close <= middle)
         return true;
     }

   return false;
  }

// News Filter Hook: no card-specific override; defer to the framework.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_11613_robo_bb_wpr25_rsi5_m15\"}");
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

   if(!QM_IsNewBar())
      return;

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
