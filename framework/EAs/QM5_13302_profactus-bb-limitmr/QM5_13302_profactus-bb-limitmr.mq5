#property strict
#property version   "5.0"
#property description "QM5_13302 Profactus BB+RSI limit-order mean reversion"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  — closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        — risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkTrackOpenPositionMae / QM_FrameworkHandleFridayClose /
//     QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() — use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly —
//     use the QM_* readers above. The framework pools handles and releases them
//     on shutdown.
//   - CopyRates over warmup windows on every tick. If you genuinely need raw
//     bar arrays, gate by QM_IsNewBar so the work runs once per closed bar.
//   - Hand-edit framework/include/QM/QM_MagicResolver.mqh. After adding rows
//     to magic_numbers.csv, run:
//         python framework/scripts/update_magic_resolver.py
//     This is idempotent and preserves all rows.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 13302;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
// All other phases use 42 by default. Stress / noise dimensions read from
// this single seed so reproducibility is guaranteed across re-runs.
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// FW1 2026-05-23 — Two-axis news filter per Vault Q09.
//   AXIS A (temporal): per-event behaviour. Default mode 3 = pause 30min pre+post.
//   AXIS B (compliance): prop-firm blackout overlay. Default DXZ = no extra rules.
// A trade is allowed only if BOTH axes allow. See Vault `Q09 News Impact Mode`.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
// Legacy single-mode input kept for back-compat with pre-FW1 setfiles.
// New EAs use qm_news_temporal + qm_news_compliance above and leave this OFF.
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
// FW2 2026-05-23 — only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_bb_period             = 20;
input double strategy_bb_deviation          = 2.0;
input int    strategy_rsi_period            = 14;
input double strategy_rsi_filter            = 20.0;
input int    strategy_atr_period            = 14;
input double strategy_sl_atr_mult           = 3.0;
input double strategy_entry_offset_pips     = 2.0;
input int    strategy_order_expiry_bars     = 1;
input int    strategy_session_start_hour    = 2;
input int    strategy_session_end_hour      = 20;
input int    strategy_max_spread_points     = 0;  // 0 until a measured per-symbol DWX cap exists

// -----------------------------------------------------------------------------
// Strategy hooks — implemented mechanically from the approved Strategy Card.
// -----------------------------------------------------------------------------

// No Trade Filter (time, spread, news): outside the broker-time session, on
// invalid prices, or on a genuinely wide positive spread, remove this EA's
// pending limits and block only the entry path. An open position is allowed
// through so Strategy_ExitSignal can flatten it at the session boundary.
bool Strategy_NoTradeFilter()
  {
   MqlDateTime now_parts;
   TimeToStruct(TimeCurrent(), now_parts);

   bool in_session = false;
   if(strategy_session_start_hour >= 0 && strategy_session_start_hour <= 23 &&
      strategy_session_end_hour >= 0 && strategy_session_end_hour <= 23)
     {
      if(strategy_session_start_hour < strategy_session_end_hour)
         in_session = (now_parts.hour >= strategy_session_start_hour &&
                       now_parts.hour < strategy_session_end_hour);
      else if(strategy_session_start_hour > strategy_session_end_hour)
         in_session = (now_parts.hour >= strategy_session_start_hour ||
                       now_parts.hour < strategy_session_end_hour);
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const bool prices_invalid = (ask <= 0.0 || bid <= 0.0 || point <= 0.0);
   const bool spread_wide = (!prices_invalid && ask > bid &&
                             strategy_max_spread_points > 0 &&
                             (ask - bid) > (double)strategy_max_spread_points * point);

   if(in_session && !prices_invalid && !spread_wide)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic > 0)
     {
      string remove_reason = "BB_LIMITMR_SESSION_CLOSED";
      if(prices_invalid)
         remove_reason = "BB_LIMITMR_PRICE_INVALID";
      else if(spread_wide)
         remove_reason = "BB_LIMITMR_SPREAD_WIDE";

      for(int i = OrdersTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = OrderGetTicket(i);
         if(ticket == 0 || !OrderSelect(ticket))
            continue;
         if(OrderGetString(ORDER_SYMBOL) != _Symbol)
            continue;
         if((int)OrderGetInteger(ORDER_MAGIC) != magic)
            continue;
         const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         if(order_type != ORDER_TYPE_BUY_LIMIT && order_type != ORDER_TYPE_SELL_LIMIT)
            continue;
         QM_TM_RemovePendingOrder(ticket, remove_reason);
        }

      if(QM_TM_OpenPositionCount(magic) > 0)
         return false;
     }

   return true;
  }

// Trade Entry: on each newly closed M15 bar, place one passive limit only when
// M15 BB stretch + RSI exhaustion + the last closed H1 BB extreme all agree.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_LIMIT;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_bb_period < 2 || strategy_bb_deviation <= 0.0 ||
      strategy_rsi_period < 2 || strategy_rsi_filter <= 0.0 || strategy_rsi_filter >= 50.0 ||
      strategy_atr_period < 2 || strategy_sl_atr_mult <= 0.0 ||
      strategy_entry_offset_pips <= 0.0 || strategy_order_expiry_bars <= 0)
      return false;

   MqlDateTime now_parts;
   TimeToStruct(TimeCurrent(), now_parts);
   bool in_session = false;
   if(strategy_session_start_hour >= 0 && strategy_session_start_hour <= 23 &&
      strategy_session_end_hour >= 0 && strategy_session_end_hour <= 23)
     {
      if(strategy_session_start_hour < strategy_session_end_hour)
         in_session = (now_parts.hour >= strategy_session_start_hour &&
                       now_parts.hour < strategy_session_end_hour);
      else if(strategy_session_start_hour > strategy_session_end_hour)
         in_session = (now_parts.hour >= strategy_session_start_hour ||
                       now_parts.hour < strategy_session_end_hour);
     }
   if(!in_session)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;
   if(ask > bid && strategy_max_spread_points > 0 &&
      (ask - bid) > (double)strategy_max_spread_points * point)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) == _Symbol &&
         (int)OrderGetInteger(ORDER_MAGIC) == magic)
         return false;
     }

   MqlRates m15_bar;
   MqlRates h1_bar;
   if(!QM_ReadBar(_Symbol, PERIOD_M15, 1, m15_bar) ||
      !QM_ReadBar(_Symbol, PERIOD_H1, 1, h1_bar))
      return false;

   const double m15_upper = QM_BB_Upper(_Symbol, PERIOD_M15,
                                        strategy_bb_period, strategy_bb_deviation,
                                        1, PRICE_CLOSE);
   const double m15_middle = QM_BB_Middle(_Symbol, PERIOD_M15,
                                          strategy_bb_period, strategy_bb_deviation,
                                          1, PRICE_CLOSE);
   const double m15_lower = QM_BB_Lower(_Symbol, PERIOD_M15,
                                        strategy_bb_period, strategy_bb_deviation,
                                        1, PRICE_CLOSE);
   const double h1_upper = QM_BB_Upper(_Symbol, PERIOD_H1,
                                       strategy_bb_period, strategy_bb_deviation,
                                       1, PRICE_CLOSE);
   const double h1_lower = QM_BB_Lower(_Symbol, PERIOD_H1,
                                       strategy_bb_period, strategy_bb_deviation,
                                       1, PRICE_CLOSE);
   const double rsi = QM_RSI(_Symbol, PERIOD_M15, strategy_rsi_period, 1, PRICE_CLOSE);
   const double atr = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1);
   if(m15_bar.close <= 0.0 || h1_bar.high <= 0.0 || h1_bar.low <= 0.0 ||
      m15_upper <= 0.0 || m15_middle <= 0.0 || m15_lower <= 0.0 ||
      h1_upper <= 0.0 || h1_lower <= 0.0 || rsi <= 0.0 || rsi >= 100.0 || atr <= 0.0)
      return false;

   const int offset_pips = (int)MathRound(strategy_entry_offset_pips);
   const double offset = QM_StopRulesPipsToPriceDistance(_Symbol, offset_pips);
   const int expiry_seconds = strategy_order_expiry_bars * PeriodSeconds(PERIOD_M15);
   if(offset <= 0.0 || expiry_seconds <= 0)
      return false;

   if(m15_bar.close > m15_upper &&
      rsi > 50.0 + strategy_rsi_filter &&
      h1_bar.high > h1_upper)
     {
      req.type = QM_SELL_LIMIT;
      req.price = QM_StopRulesNormalizePrice(_Symbol, m15_bar.close + offset);
      if(req.price <= ask)
         return false;
      req.sl = QM_StopATRFromValue(_Symbol, req.type, req.price, atr, strategy_sl_atr_mult);
      req.tp = QM_StopRulesNormalizePrice(_Symbol, m15_middle);
      req.reason = "PROFACTUS_BB_LIMITMR_SHORT";
     }
   else if(m15_bar.close < m15_lower &&
           rsi < 50.0 - strategy_rsi_filter &&
           h1_bar.low < h1_lower)
     {
      req.type = QM_BUY_LIMIT;
      req.price = QM_StopRulesNormalizePrice(_Symbol, m15_bar.close - offset);
      if(req.price >= bid)
         return false;
      req.sl = QM_StopATRFromValue(_Symbol, req.type, req.price, atr, strategy_sl_atr_mult);
      req.tp = QM_StopRulesNormalizePrice(_Symbol, m15_middle);
      req.reason = "PROFACTUS_BB_LIMITMR_LONG";
     }
   else
      return false;

   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = expiry_seconds;
   if(req.sl <= 0.0 || req.tp <= 0.0)
      return false;
   if(QM_OrderTypeIsBuy(req.type))
      return (req.sl < req.price && req.tp > req.price);
   return (req.sl > req.price && req.tp < req.price);
  }

// Trade Management: no trailing, break-even, partial close, or scale-in.
// The only pending-order management is the card's one-M15-bar expiry fallback.
void Strategy_ManageOpenPosition()
  {
   if(strategy_order_expiry_bars <= 0)
      return;

   const int magic = QM_FrameworkMagic();
   const int expiry_seconds = strategy_order_expiry_bars * PeriodSeconds(PERIOD_M15);
   if(magic <= 0 || expiry_seconds <= 0)
      return;

   const datetime now = TimeCurrent();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type != ORDER_TYPE_BUY_LIMIT && order_type != ORDER_TYPE_SELL_LIMIT)
         continue;
      const datetime setup_time = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      if(setup_time > 0 && now - setup_time >= expiry_seconds)
         QM_TM_RemovePendingOrder(ticket, "BB_LIMITMR_ONE_BAR_EXPIRY");
     }
  }

// Trade Close: SL/TP are server-side and static; outside the broker-time
// session, flatten any filled position. Friday close remains framework-owned.
bool Strategy_ExitSignal()
  {
   MqlDateTime now_parts;
   TimeToStruct(TimeCurrent(), now_parts);

   bool in_session = false;
   if(strategy_session_start_hour >= 0 && strategy_session_start_hour <= 23 &&
      strategy_session_end_hour >= 0 && strategy_session_end_hour <= 23)
     {
      if(strategy_session_start_hour < strategy_session_end_hour)
         in_session = (now_parts.hour >= strategy_session_start_hour &&
                       now_parts.hour < strategy_session_end_hour);
      else if(strategy_session_start_hour > strategy_session_end_hour)
         in_session = (now_parts.hour >= strategy_session_start_hour ||
                       now_parts.hour < strategy_session_end_hour);
     }
   return !in_session;
  }

// News Filter Hook: the central two-axis P8-callable news gate owns blackout
// decisions; this strategy has no card-authorized custom override.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,           // legacy back-compat
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,                            // pause-before (legacy hint)
                        30,                            // pause-after (legacy hint)
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,              // FW1 Axis A
                        qm_news_compliance))           // FW1 Axis B
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
   // Q08 evidence lifecycle: sample floating P&L before any per-tick guard can
   // return. QM_KillSwitchCheck retains the same call as a compatibility
   // fallback for pre-template EAs; keep this explicit hook in all new builds.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: trade management can adjust SL/TP on open positions.
   // Management, rule-based exits and the Friday sweep above MUST keep
   // running through news windows — the news gate below blocks NEW entries
   // only (2026-07-02 audit rule; canonical order per QM5_12821 OnTick,
   // commit dc418a720).
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. time stop). Separate from SL/TP.
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

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults. Gates NEW entries only —
   // never the management/exit paths above.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req); // symbol_slot=0 (host slot) + expiration=0 defaults; garbage
                    // in unset fields = the silent-zero-trades class (9e4cfedb1)
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
   // FW4: feeds closing-deal net-profits to the KS kill-switch.
   // No-op outside Q13 (when no baseline.json exists).
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
