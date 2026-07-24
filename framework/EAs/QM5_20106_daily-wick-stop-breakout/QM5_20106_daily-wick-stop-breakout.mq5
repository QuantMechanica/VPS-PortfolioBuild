#property strict
#property version   "5.0"
#property description "QuantMechanica V5 EA skeleton template"

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
input int    qm_ea_id                   = 20106;
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
input double strategy_pips_above_high = 2.0;
input double strategy_pips_below_low  = 2.0;
input double strategy_sl_pips         = 30.0;
input double strategy_tp_pips         = 100.0;

const string g_str012_order_prefix = "S012_D1_";

datetime g_str012_last_manage_d1_bar = 0;
datetime g_str012_last_entry_d1_bar = 0;
datetime g_str012_last_data_log_bar = 0;

double Strategy012_TradeTick()
  {
   double tick = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0.0)
      tick = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   return tick;
  }

double Strategy012_PipSize()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits =
      (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(point <= 0.0)
      return 0.0;
   return (digits == 3 || digits == 5) ? point * 10.0 : point;
  }

double Strategy012_AlignPrice(const double raw_price,
                              const int direction)
  {
   const double tick = Strategy012_TradeTick();
   if(raw_price <= 0.0 || tick <= 0.0)
      return 0.0;
   const double scaled = raw_price / tick;
   double units = MathRound(scaled);
   if(direction < 0)
      units = MathFloor(scaled + 1e-9);
   else if(direction > 0)
      units = MathCeil(scaled - 1e-9);
   return QM_TM_NormalizePrice(_Symbol, units * tick);
  }

void Strategy012_LogDataMissing(const string component,
                                const datetime bar_time)
  {
   if(bar_time > 0 && bar_time == g_str012_last_data_log_bar)
      return;
   g_str012_last_data_log_bar = bar_time;
   QM_LogEvent(
      QM_WARN,
      SETUP_DATA_MISSING,
      StringFormat(
         "{\"strategy\":\"STR-012\",\"component\":\"%s\",\"bar_time\":%I64d}",
         QM_LoggerEscapeJson(component),
         (long)bar_time));
  }

bool Strategy012_HasOwnPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      return true;
     }
   return false;
  }

bool Strategy012_IsStopOrder(const ENUM_ORDER_TYPE order_type)
  {
   return (order_type == ORDER_TYPE_BUY_STOP ||
           order_type == ORDER_TYPE_SELL_STOP);
  }

bool Strategy012_HasOwnPending()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic ||
         OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      return true;
     }
   return false;
  }

string Strategy012_OrderReason(const datetime source_d1_time)
  {
   return StringFormat("%s%I64d",
                       g_str012_order_prefix,
                       (long)source_d1_time);
  }

bool Strategy012_ParseSourceTime(const string comment,
                                 datetime &source_d1_time)
  {
   source_d1_time = 0;
   if(StringFind(comment, g_str012_order_prefix) != 0)
      return false;
   const string encoded =
      StringSubstr(comment, StringLen(g_str012_order_prefix));
   if(StringLen(encoded) < 1)
      return false;
   const long parsed = StringToInteger(encoded);
   if(parsed <= 0)
      return false;
   source_d1_time = (datetime)parsed;
   return true;
  }

bool Strategy012_AlreadyAttempted(const datetime source_d1_time,
                                  const datetime current_d1_time)
  {
   if(source_d1_time <= 0 ||
      current_d1_time <= 0 ||
      !HistorySelect(current_d1_time, TimeCurrent()))
      return false;
   const string expected =
      Strategy012_OrderReason(source_d1_time);
   const int magic = QM_FrameworkMagic();

   const int history_orders = HistoryOrdersTotal();
   for(int i = 0; i < history_orders; ++i)
     {
      const ulong ticket = HistoryOrderGetTicket(i);
      if(ticket == 0 ||
         (int)HistoryOrderGetInteger(ticket, ORDER_MAGIC) != magic ||
         HistoryOrderGetString(ticket, ORDER_SYMBOL) != _Symbol)
         continue;
      if(HistoryOrderGetString(ticket, ORDER_COMMENT) == expected)
         return true;
     }

   const int history_deals = HistoryDealsTotal();
   for(int i = 0; i < history_deals; ++i)
     {
      const ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0 ||
         (int)HistoryDealGetInteger(ticket, DEAL_MAGIC) != magic ||
         HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol)
         continue;
      const ENUM_DEAL_ENTRY entry_kind =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry_kind != DEAL_ENTRY_IN &&
         entry_kind != DEAL_ENTRY_INOUT)
         continue;
      if(HistoryDealGetString(ticket, DEAL_COMMENT) == expected)
         return true;
     }
   return false;
  }

bool Strategy012_PendingStopsValid(const QM_OrderType side,
                                   const double entry,
                                   const double sl,
                                   const double tp,
                                   const double bid,
                                   const double ask)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick = Strategy012_TradeTick();
   if(point <= 0.0 || tick <= 0.0 ||
      entry <= 0.0 || sl <= 0.0 || tp <= 0.0 ||
      bid <= 0.0 || ask <= 0.0 || ask < bid)
      return false;
   const long stops_level =
      SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const long freeze_level =
      SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   const long broker_level =
      (stops_level > freeze_level) ? stops_level : freeze_level;
   const double minimum =
      MathMax(tick, (double)broker_level * point);

   if(side == QM_BUY_STOP)
      return (entry > ask && sl < entry && tp > entry &&
              entry - ask + tick * 0.1 >= minimum &&
              entry - sl + tick * 0.1 >= minimum &&
              tp - entry + tick * 0.1 >= minimum);
   if(side == QM_SELL_STOP)
      return (entry < bid && sl > entry && tp < entry &&
              bid - entry + tick * 0.1 >= minimum &&
              sl - entry + tick * 0.1 >= minimum &&
              entry - tp + tick * 0.1 >= minimum);
   return false;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1 ||
      !MathIsValidNumber(strategy_pips_above_high) ||
      !MathIsValidNumber(strategy_pips_below_low) ||
      !MathIsValidNumber(strategy_sl_pips) ||
      !MathIsValidNumber(strategy_tp_pips) ||
      strategy_pips_above_high <= 0.0 ||
      strategy_pips_below_low <= 0.0 ||
      strategy_sl_pips <= 0.0 ||
      strategy_tp_pips <= 0.0)
      return true;
   const ENUM_SYMBOL_TRADE_MODE trade_mode =
      (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(_Symbol,
                                                SYMBOL_TRADE_MODE);
   if(trade_mode == SYMBOL_TRADE_MODE_DISABLED)
      return true;
   const long bars =
      SeriesInfoInteger(_Symbol, PERIOD_D1, SERIES_BARS_COUNT);
   return (bars < 3);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ZeroMemory(req);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   MqlRates forming_d1;
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 0, forming_d1))
     {
      Strategy012_LogDataMissing("forming_d1_bar", 0);
      return false;
     }
   if(forming_d1.time == g_str012_last_entry_d1_bar)
      return false;
   g_str012_last_entry_d1_bar = forming_d1.time;

   if(Strategy012_HasOwnPosition() ||
      Strategy012_HasOwnPending())
      return false;

   MqlRates source_d1;
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 1, source_d1) ||
      source_d1.open <= 0.0 ||
      source_d1.high <= 0.0 ||
      source_d1.low <= 0.0 ||
      source_d1.high < source_d1.open ||
      source_d1.open < source_d1.low)
     {
      Strategy012_LogDataMissing("source_d1_bar",
                                 forming_d1.time);
      return false;
     }
   if(Strategy012_AlreadyAttempted(source_d1.time,
                                   forming_d1.time))
      return false;

   const double wick_buy = source_d1.open - source_d1.low;
   const double wick_sell = source_d1.high - source_d1.open;
   if(wick_buy == wick_sell)
      return false;
   const bool buy_signal = (wick_buy > wick_sell);

   const double pip = Strategy012_PipSize();
   if(pip <= 0.0)
     {
      Strategy012_LogDataMissing("pip_size",
                                 forming_d1.time);
      return false;
     }

   req.type = buy_signal ? QM_BUY_STOP : QM_SELL_STOP;
   double entry = 0.0;
   double sl = 0.0;
   double tp = 0.0;
   if(buy_signal)
     {
      entry =
         Strategy012_AlignPrice(
            source_d1.high + strategy_pips_above_high * pip,
            1);
      sl =
         Strategy012_AlignPrice(
            source_d1.high - strategy_sl_pips * pip,
            -1);
      tp =
         Strategy012_AlignPrice(
            entry + strategy_tp_pips * pip,
            1);
     }
   else
     {
      entry =
         Strategy012_AlignPrice(
            source_d1.low - strategy_pips_below_low * pip,
            -1);
      sl =
         Strategy012_AlignPrice(
            source_d1.low + strategy_sl_pips * pip,
            1);
      tp =
         Strategy012_AlignPrice(
            entry - strategy_tp_pips * pip,
            -1);
     }

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
     {
      Strategy012_LogDataMissing("market_price",
                                 forming_d1.time);
      return false;
     }
   const bool gap_through =
      buy_signal ? (ask >= entry) : (bid <= entry);
   if(gap_through)
     {
      QM_LogEvent(
         QM_WARN,
         "SETUP_CONFIG_INVALID",
         StringFormat(
            "{\"strategy\":\"STR-012\",\"reason\":\"gap_through_entry\",\"dir\":\"%s\",\"source_d1\":%I64d,\"entry\":%.8f,\"bid\":%.8f,\"ask\":%.8f}",
            buy_signal ? "BUY" : "SELL",
            (long)source_d1.time,
            entry,
            bid,
            ask));
      return false;
     }
   if(!Strategy012_PendingStopsValid(req.type,
                                     entry,
                                     sl,
                                     tp,
                                     bid,
                                     ask))
     {
      QM_LogEvent(
         QM_WARN,
         "SETUP_CONFIG_INVALID",
         StringFormat(
            "{\"strategy\":\"STR-012\",\"reason\":\"stops_or_freeze_level\",\"dir\":\"%s\",\"source_d1\":%I64d,\"entry\":%.8f,\"sl\":%.8f,\"tp\":%.8f}",
            buy_signal ? "BUY" : "SELL",
            (long)source_d1.time,
            entry,
            sl,
            tp));
      return false;
     }

   const int d1_seconds = PeriodSeconds(PERIOD_D1);
   const datetime next_d1_open =
      (d1_seconds > 0)
      ? forming_d1.time + d1_seconds
      : forming_d1.time + 86400;
   const datetime now = TimeCurrent();
   if(next_d1_open <= now)
     {
      QM_LogEvent(
         QM_WARN,
         "SETUP_CONFIG_INVALID",
         StringFormat(
            "{\"strategy\":\"STR-012\",\"reason\":\"pending_expiry\",\"source_d1\":%I64d,\"next_d1\":%I64d,\"now\":%I64d}",
            (long)source_d1.time,
            (long)next_d1_open,
            (long)now));
      return false;
     }

   req.price = entry;
   req.sl = sl;
   req.tp = tp;
   req.reason = Strategy012_OrderReason(source_d1.time);
   req.expiration_seconds = (int)(next_d1_open - now);

   QM_LogEvent(
      QM_INFO,
      "STRATEGY_ENTRY",
      StringFormat(
         "{\"strategy\":\"STR-012\",\"dir\":\"%s\",\"source_d1\":%I64d,\"wick_buy\":%.8f,\"wick_sell\":%.8f,\"entry\":%.8f,\"sl\":%.8f,\"tp\":%.8f,\"expiry_seconds\":%d}",
         buy_signal ? "BUY" : "SELL",
         (long)source_d1.time,
         wick_buy,
         wick_sell,
         entry,
         sl,
         tp,
         req.expiration_seconds));
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const datetime forming_d1_time =
      (datetime)SeriesInfoInteger(_Symbol,
                                  PERIOD_D1,
                                  SERIES_LASTBAR_DATE);
   if(forming_d1_time <= 0)
     {
      Strategy012_LogDataMissing("forming_d1_time", 0);
      return;
     }
   if(forming_d1_time == g_str012_last_manage_d1_bar)
      return;

   MqlRates closed_d1;
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 1, closed_d1))
     {
      Strategy012_LogDataMissing("day_roll_bar",
                                 forming_d1_time);
      return;
     }
   g_str012_last_manage_d1_bar = forming_d1_time;

   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic ||
         OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      const ENUM_ORDER_TYPE order_type =
         (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(!Strategy012_IsStopOrder(order_type))
         continue;

      datetime source_d1_time = 0;
      const string comment = OrderGetString(ORDER_COMMENT);
      if(!Strategy012_ParseSourceTime(comment, source_d1_time))
        {
         QM_LogEvent(
            QM_WARN,
            "SETUP_CONFIG_INVALID",
            StringFormat(
               "{\"strategy\":\"STR-012\",\"reason\":\"pending_source_tag\",\"ticket\":%I64u,\"comment\":\"%s\"}",
               ticket,
               QM_LoggerEscapeJson(comment)));
         continue;
        }
      if(source_d1_time < closed_d1.time)
         QM_TM_RemovePendingOrder(ticket, "day_roll");
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
