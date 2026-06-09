#property strict
#property version   "5.0"
#property description "QM5_10080 GitHub Victor Algo Gap Reversal"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10080;
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
input double strategy_gap_threshold_pct  = 1.0;
input int    strategy_sma_period         = 250;
input int    strategy_atr_period         = 250;
input double strategy_atr_sl_mult        = 1.0;
input double strategy_atr_tp_mult        = 1.0;

// -----------------------------------------------------------------------------
// Strategy hooks.
// -----------------------------------------------------------------------------

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

   if(strategy_gap_threshold_pct <= 0.0 ||
      strategy_sma_period <= 0 ||
      strategy_atr_period <= 0 ||
      strategy_atr_sl_mult <= 0.0 ||
      strategy_atr_tp_mult <= 0.0)
      return false;

   MqlRates rates[2];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, 2, rates) != 2) // perf-allowed: card requires two closed OHLC bars for gap math; caller is QM_IsNewBar-gated.
      return false;

   const double open1 = rates[0].open;
   const double close1 = rates[0].close;
   const double close2 = rates[1].close;
   if(open1 <= 0.0 || close1 <= 0.0 || close2 <= 0.0)
      return false;

   const double gap_pct = 100.0 * (open1 - close2) / close2;
   const double sma = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_sma_period, 1, PRICE_CLOSE);
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(sma <= 0.0 || atr <= 0.0)
      return false;

   const bool bullish_gap_bar = (close1 > open1);
   const bool bearish_gap_bar = (close1 < open1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(gap_pct <= -strategy_gap_threshold_pct && bullish_gap_bar && close1 > sma)
     {
      req.type = QM_BUY;
      req.price = ask;
      req.sl = NormalizeDouble(req.price - atr * strategy_atr_sl_mult, _Digits);
      req.tp = NormalizeDouble(req.price + atr * strategy_atr_tp_mult, _Digits);
      req.reason = "GH_VICTOR_GAP_LONG";
      return (req.sl > 0.0 && req.sl < req.price && req.tp > req.price);
     }

   if(gap_pct >= strategy_gap_threshold_pct && bearish_gap_bar && close1 < sma)
     {
      req.type = QM_SELL;
      req.price = bid;
      req.sl = NormalizeDouble(req.price + atr * strategy_atr_sl_mult, _Digits);
      req.tp = NormalizeDouble(req.price - atr * strategy_atr_tp_mult, _Digits);
      req.reason = "GH_VICTOR_GAP_SHORT";
      return (req.sl > req.price && req.tp > 0.0 && req.tp < req.price);
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return;

   MqlRates trail_rates[1];
   ArraySetAsSeries(trail_rates, true);
   if(CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, 1, trail_rates) != 1) // perf-allowed: one closed bar for the card's trailing-stop close.
      return;
   const double close1 = trail_rates[0].close;
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(close1 <= 0.0 || atr <= 0.0 || point <= 0.0 || bid <= 0.0 || ask <= 0.0)
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

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double target_sl = (ptype == POSITION_TYPE_BUY)
                               ? NormalizeDouble(close1 - atr * strategy_atr_sl_mult, _Digits)
                               : NormalizeDouble(close1 + atr * strategy_atr_sl_mult, _Digits);
      if(target_sl <= 0.0)
         continue;

      if(ptype == POSITION_TYPE_BUY && target_sl >= bid)
         continue;
      if(ptype == POSITION_TYPE_SELL && target_sl <= ask)
         continue;

      const bool improves = (current_sl <= 0.0) ||
                            (ptype == POSITION_TYPE_BUY
                             ? target_sl > current_sl + point * 0.5
                             : target_sl < current_sl - point * 0.5);
      if(improves)
         QM_TM_MoveSL(ticket, target_sl, "GH_VICTOR_GAP_ATR_TRAIL");
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
// Framework wiring - do NOT edit below this line.
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
