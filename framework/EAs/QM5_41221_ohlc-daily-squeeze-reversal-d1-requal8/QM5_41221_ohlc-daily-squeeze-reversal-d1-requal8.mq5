#property strict
#property version   "5.0"
#property description "QM5_41221 OHLC Daily Squeeze Reversal — Q09 REQUAL-8"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_41221 ohlc-daily-squeeze-reversal-d1-requal8
// -----------------------------------------------------------------------------
// New-identity requalification port of
// QM5_11421_ohlc-daily-squeeze-reversal-d1 under
// OWNER-DEC-Q09HOLD-REQUAL-8-20260829. Strategy mechanics are unchanged:
// a completed D1 squeeze arms a reversal stop one squeeze range beyond the
// close, with a range target and capped range-based stop.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 41221;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode       qm_news_temporal        = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance      = QM_NEWS_COMPLIANCE_DXZ;
input int                       qm_news_stale_max_hours = 336;
input string                    qm_news_min_impact      = "high";
input QM_NewsMode               qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input double strategy_entry_range_mult = 1.0;
input double strategy_sl_range_mult    = 1.5;
input double strategy_tp_range_mult    = 1.0;
input double strategy_min_range_pips   = 30.0;
input double strategy_sl_cap_pips      = 80.0;
input int    strategy_pending_ttl_bars = 1;
input double strategy_spread_cap_pips  = 25.0;
input bool   strategy_enable_long      = true;

double SqueezePipFactor()
  {
   return QM_StopRulesPipsToPriceDistance(_Symbol, 1);
  }

int QM_PendingTTLSeconds()
  {
   const int bars = (strategy_pending_ttl_bars > 0)
                    ? strategy_pending_ttl_bars : 1;
   return bars * 86400;
  }

// -----------------------------------------------------------------------------
// No Trade Filter
// -----------------------------------------------------------------------------
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double pip = SqueezePipFactor();
   if(pip <= 0.0)
      return false;

   const double spread = ask - bid;
   const double cap_price = strategy_spread_cap_pips * pip;
   return (spread > 0.0 && cap_price > 0.0 && spread > cap_price);
  }

// -----------------------------------------------------------------------------
// Trade Entry
// -----------------------------------------------------------------------------
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_entry_range_mult <= 0.0 ||
      strategy_sl_range_mult <= 0.0 ||
      strategy_tp_range_mult <= 0.0 ||
      strategy_min_range_pips < 0.0 ||
      strategy_sl_cap_pips <= 0.0 ||
      strategy_pending_ttl_bars <= 0 ||
      strategy_spread_cap_pips < 0.0)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;

   // Current bounded series-access pattern: three single completed D1 bars,
   // read through the framework rather than raw per-field series functions.
   MqlRates day2;
   MqlRates day1;
   MqlRates day0;
   ZeroMemory(day2);
   ZeroMemory(day1);
   ZeroMemory(day0);
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 1, day2) ||
      !QM_ReadBar(_Symbol, PERIOD_D1, 2, day1) ||
      !QM_ReadBar(_Symbol, PERIOD_D1, 3, day0))
      return false;
   if(day2.high <= 0.0 || day2.low <= 0.0 || day2.close <= 0.0 ||
      day1.close <= 0.0 || day0.close <= 0.0)
      return false;

   const bool asc_closes =
      (day2.close > day1.close && day1.close > day0.close);
   const bool desc_closes =
      (day2.close < day1.close && day1.close < day0.close);

   // Preserve the parent's one-pending-or-position lifecycle. A continuing
   // squeeze cancels the matching stop; any other valid pending remains armed.
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE order_type =
         (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type == ORDER_TYPE_SELL_STOP && asc_closes)
         QM_TM_RemovePendingOrder(
            ticket, "squeeze_continues_cancel_sellstop");
      else if(order_type == ORDER_TYPE_BUY_STOP && desc_closes)
         QM_TM_RemovePendingOrder(
            ticket, "squeeze_continues_cancel_buystop");
      else
         return false;
     }

   const double day2_range = day2.high - day2.low;
   const double pip = SqueezePipFactor();
   if(day2_range <= 0.0 || pip <= 0.0 ||
      day2_range < strategy_min_range_pips * pip)
      return false;

   const double sl_cap_price = strategy_sl_cap_pips * pip;

   if(asc_closes &&
      (day2.high - day1.close) >= day2_range * 0.5)
     {
      const double entry =
         day2.close - strategy_entry_range_mult * day2_range;
      double sl = day2.high + strategy_sl_range_mult * day2_range;
      if(sl - entry > sl_cap_price)
         sl = entry + sl_cap_price;
      const double tp = entry - strategy_tp_range_mult * day2_range;

      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0 || tp <= 0.0 || sl <= entry ||
         bid <= 0.0 || entry >= bid)
         return false;

      req.type = QM_SELL_STOP;
      req.price = NormalizeDouble(entry, _Digits);
      req.sl = NormalizeDouble(sl, _Digits);
      req.tp = NormalizeDouble(tp, _Digits);
      req.reason = "squeeze_short_sellstop";
      req.expiration_seconds = QM_PendingTTLSeconds();
      return true;
     }

   if(strategy_enable_long && desc_closes &&
      (day1.close - day2.low) >= day2_range * 0.5)
     {
      const double entry =
         day2.close + strategy_entry_range_mult * day2_range;
      double sl = day2.low - strategy_sl_range_mult * day2_range;
      if(entry - sl > sl_cap_price)
         sl = entry - sl_cap_price;
      const double tp = entry + strategy_tp_range_mult * day2_range;

      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0 || sl <= 0.0 || tp <= 0.0 || sl >= entry ||
         ask <= 0.0 || entry <= ask)
         return false;

      req.type = QM_BUY_STOP;
      req.price = NormalizeDouble(entry, _Digits);
      req.sl = NormalizeDouble(sl, _Digits);
      req.tp = NormalizeDouble(tp, _Digits);
      req.reason = "squeeze_long_buystop";
      req.expiration_seconds = QM_PendingTTLSeconds();
      return true;
     }

   return false;
  }

// -----------------------------------------------------------------------------
// Trade Management
// -----------------------------------------------------------------------------
void Strategy_ManageOpenPosition()
  {
  }

// -----------------------------------------------------------------------------
// Trade Close
// -----------------------------------------------------------------------------
bool Strategy_ExitSignal()
  {
   return false;
  }

// -----------------------------------------------------------------------------
// News Filter Hook
// -----------------------------------------------------------------------------
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Current V5 framework wiring
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

   if(!QM_FrameworkDeclareExecutionContract(
         PERIOD_D1,
         QM_FRIDAY_CLOSE_FRAMEWORK_OVERRIDE,
         "DXZ_LEGACY_BOOK_POLICY_REQUAL_REQUIRED"))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT",
               StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   // Q08 evidence lifecycle: no guard may skip open-position MAE sampling.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
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
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   // Mandatory news blackout gates new entries only. Management and exits
   // above remain reachable throughout restricted windows.
   if(Strategy_NewsFilterHook(broker_now))
      return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now,
                                        qm_news_temporal,
                                        qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now,
                                       qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar(_Symbol, PERIOD_D1))
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
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
