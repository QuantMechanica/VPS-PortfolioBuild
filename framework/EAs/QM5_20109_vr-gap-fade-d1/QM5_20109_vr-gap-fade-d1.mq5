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
input int    qm_ea_id                   = 20109;
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
input int strategy_min_gap_points = 100;
input int strategy_sl_points      = 300;

datetime g_str027_last_entry_d1_bar = 0;
datetime g_str027_last_data_log_bar = 0;
datetime g_str027_pending_signal_bar = 0;
double   g_str027_pending_target = 0.0;
int      g_str027_pending_direction = 0;
ulong    g_str027_cached_position_key = 0;
double   g_str027_cached_target = 0.0;
ulong    g_str027_missing_target_key = 0;
ulong    g_str027_tp_retry_position_key = 0;
datetime g_str027_tp_retry_wait_bar = 0;

datetime Strategy027_CurrentD1Time()
  {
   return (datetime)SeriesInfoInteger(_Symbol,
                                      PERIOD_D1,
                                      SERIES_LASTBAR_DATE);
  }

void Strategy027_LogDataMissing(const string component)
  {
   const datetime bar_time = Strategy027_CurrentD1Time();
   if(bar_time > 0 && bar_time == g_str027_last_data_log_bar)
      return;
   g_str027_last_data_log_bar = bar_time;
   QM_LogEvent(
      QM_WARN,
      SETUP_DATA_MISSING,
      StringFormat(
         "{\"strategy\":\"STR-027\",\"component\":\"%s\",\"bar_time\":%I64d}",
         QM_LoggerEscapeJson(component),
         (long)bar_time));
  }

double Strategy027_TradeTick()
  {
   double tick = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0.0)
      tick = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   return tick;
  }

double Strategy027_AlignPrice(const double raw_price,
                              const int direction)
  {
   const double tick = Strategy027_TradeTick();
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

bool Strategy027_HasOwnPosition()
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

bool Strategy027_StopLegal(const QM_OrderType side,
                           const double sl)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick = Strategy027_TradeTick();
   if(point <= 0.0 || tick <= 0.0 || sl <= 0.0)
      return false;

   const long stops_level =
      SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double minimum =
      MathMax(tick, (double)stops_level * point);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0 || ask < bid)
      return false;

   if(QM_OrderTypeIsBuy(side))
      return (sl < bid &&
              bid - sl + tick * 0.1 >= minimum);
   return (sl > ask &&
           sl - ask + tick * 0.1 >= minimum);
  }

bool Strategy027_RestartTarget(const ulong position_id,
                               const ENUM_POSITION_TYPE position_type,
                               const datetime position_time,
                               double &target)
  {
   target = 0.0;
   if(position_id == 0 || position_time <= 0)
      return false;

   const datetime history_from =
      (position_time > 86400) ? position_time - 86400 : 0;
   if(!HistorySelect(history_from, TimeCurrent()))
      return false;

   const int magic = QM_FrameworkMagic();
   datetime entry_deal_time = 0;
   const int deal_count = HistoryDealsTotal();
   for(int i = 0; i < deal_count; ++i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0 ||
         (ulong)HistoryDealGetInteger(deal, DEAL_POSITION_ID) != position_id ||
         (int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic ||
         HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      const ENUM_DEAL_ENTRY entry_kind =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry_kind != DEAL_ENTRY_IN &&
         entry_kind != DEAL_ENTRY_INOUT)
         continue;
      const datetime deal_time =
         (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
      if(deal_time > 0 &&
         (entry_deal_time == 0 || deal_time < entry_deal_time))
         entry_deal_time = deal_time;
     }
   if(entry_deal_time <= 0)
      return false;

   const int entry_shift =
      iBarShift(_Symbol, PERIOD_D1, entry_deal_time, false); // perf-allowed: restart-only deal-to-D1-bar lookup
   if(entry_shift < 0)
      return false;

   MqlRates entry_bar;
   MqlRates prior_bar;
   if(!QM_ReadBar(_Symbol, PERIOD_D1, entry_shift, entry_bar) ||
      !QM_ReadBar(_Symbol, PERIOD_D1, entry_shift + 1, prior_bar))
      return false;
   // If entry_shift is zero, entry_bar.open is the immutable D1 open. No
   // forming-bar high/low/close participates in the reconstruction.
   if(entry_bar.open <= 0.0 || prior_bar.close <= 0.0)
      return false;
   if(position_type == POSITION_TYPE_BUY &&
      prior_bar.close <= entry_bar.open)
      return false;
   if(position_type == POSITION_TYPE_SELL &&
      prior_bar.close >= entry_bar.open)
      return false;

   target = Strategy027_AlignPrice(prior_bar.close, 0);
   return (target > 0.0);
  }

bool Strategy027_TargetForPosition(const ulong position_key,
                                   const ulong position_id,
                                   const ENUM_POSITION_TYPE position_type,
                                   const datetime position_time,
                                   double &target)
  {
   target = 0.0;
   if(position_key != 0 &&
      position_key == g_str027_cached_position_key &&
      g_str027_cached_target > 0.0)
     {
      target = g_str027_cached_target;
      return true;
     }

   const int expected_direction =
      (position_type == POSITION_TYPE_BUY) ? 1 : -1;
   if(g_str027_pending_signal_bar > 0 &&
      g_str027_pending_target > 0.0 &&
      g_str027_pending_direction == expected_direction &&
      position_time >= g_str027_pending_signal_bar &&
      position_time <
         g_str027_pending_signal_bar + PeriodSeconds(PERIOD_D1))
     {
      target = g_str027_pending_target;
      g_str027_cached_position_key = position_key;
      g_str027_cached_target = target;
      g_str027_missing_target_key = 0;
      return true;
     }

   if(!Strategy027_RestartTarget(position_id,
                                 position_type,
                                 position_time,
                                 target))
      return false;
   g_str027_cached_position_key = position_key;
   g_str027_cached_target = target;
   g_str027_missing_target_key = 0;
   return true;
  }

void Strategy027_LogMissingTarget(const ulong position_key,
                                  const ulong ticket,
                                  const datetime position_time)
  {
   if(position_key != 0 &&
      position_key == g_str027_missing_target_key)
      return;
   g_str027_missing_target_key = position_key;
   QM_LogEvent(
      QM_WARN,
      SETUP_DATA_MISSING,
      StringFormat(
         "{\"strategy\":\"STR-027\",\"component\":\"gap_close_target_restart\",\"ticket\":%I64u,\"position_time\":%I64d}",
         ticket,
         (long)position_time));
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1 ||
      strategy_min_gap_points <= 0 ||
      strategy_sl_points <= 0)
      return true;

   const ENUM_SYMBOL_TRADE_MODE trade_mode =
      (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(_Symbol,
                                                SYMBOL_TRADE_MODE);
   if(trade_mode == SYMBOL_TRADE_MODE_DISABLED)
      return true;
   const long bars_available =
      SeriesInfoInteger(_Symbol, PERIOD_D1, SERIES_BARS_COUNT);
   return (bars_available < 3);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ZeroMemory(req);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   MqlRates forming_bar;
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 0, forming_bar)) // perf-allowed: immutable new-D1 open/time read under owned D1 latch
     {
      Strategy027_LogDataMissing("forming_d1_bar");
      return false;
     }
   if(forming_bar.time <= 0 ||
      forming_bar.open <= 0.0)
     {
      Strategy027_LogDataMissing("forming_d1_open");
      return false;
     }
   if(forming_bar.time == g_str027_last_entry_d1_bar)
      return false;
   g_str027_last_entry_d1_bar = forming_bar.time;

   if(Strategy027_HasOwnPosition())
      return false;

   MqlRates prior_bar;
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 1, prior_bar) ||
      prior_bar.close <= 0.0)
     {
      Strategy027_LogDataMissing("prior_d1_close");
      return false;
     }

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
     {
      Strategy027_LogDataMissing("symbol_point");
      return false;
     }
   const double gap = prior_bar.close - forming_bar.open;
   const double minimum_gap =
      (double)strategy_min_gap_points * point;
   if(MathAbs(gap) <= minimum_gap)
      return false;

   const bool long_signal = (gap > 0.0);
   req.type = long_signal ? QM_BUY : QM_SELL;
   const double entry =
      long_signal
      ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
      : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
     {
      Strategy027_LogDataMissing("market_price");
      return false;
     }

   const double raw_sl =
      long_signal
      ? entry - (double)strategy_sl_points * point
      : entry + (double)strategy_sl_points * point;
   const double sl =
      Strategy027_AlignPrice(raw_sl, long_signal ? -1 : 1);
   if((long_signal && sl >= entry) ||
      (!long_signal && sl <= entry) ||
      !Strategy027_StopLegal(req.type, sl))
     {
      QM_LogEvent(
         QM_WARN,
         "SETUP_CONFIG_INVALID",
         StringFormat(
            "{\"strategy\":\"STR-027\",\"reason\":\"stop_geometry\",\"dir\":\"%s\",\"entry\":%.8f,\"sl\":%.8f,\"point\":%.8f}",
            QM_LoggerEscapeJson(long_signal ? "LONG" : "SHORT"),
            entry,
            sl,
            point));
      return false;
     }

   const double target =
      Strategy027_AlignPrice(prior_bar.close, 0);
   if(target <= 0.0)
     {
      Strategy027_LogDataMissing("gap_close_target");
      return false;
     }

   req.price = entry;
   req.sl = sl;
   req.tp = 0.0;
   req.reason =
      StringFormat("STR027_D1_%I64d", (long)forming_bar.time);

   g_str027_pending_signal_bar = forming_bar.time;
   g_str027_pending_target = target;
   g_str027_pending_direction = long_signal ? 1 : -1;
   g_str027_cached_position_key = 0;
   g_str027_cached_target = 0.0;

   QM_LogEvent(
      QM_INFO,
      "STRATEGY_ENTRY",
      StringFormat(
         "{\"strategy\":\"STR-027\",\"dir\":\"%s\",\"bar_time\":%I64d,\"open0\":%.8f,\"close1\":%.8f,\"gap\":%.8f,\"min_gap\":%.8f,\"entry\":%.8f,\"sl\":%.8f,\"deferred_target\":%.8f}",
         QM_LoggerEscapeJson(long_signal ? "LONG" : "SHORT"),
         (long)forming_bar.time,
         forming_bar.open,
         prior_bar.close,
         gap,
         minimum_gap,
         entry,
         sl,
         target));
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   const datetime current_bar = Strategy027_CurrentD1Time();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetDouble(POSITION_TP) > 0.0)
         continue;

      const ENUM_POSITION_TYPE position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const datetime position_time =
         (datetime)PositionGetInteger(POSITION_TIME);
      const ulong position_id =
         (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      const ulong position_key =
         (position_id != 0) ? position_id : ticket;

      double target = 0.0;
      if(!Strategy027_TargetForPosition(position_key,
                                        position_id,
                                        position_type,
                                        position_time,
                                        target))
        {
         Strategy027_LogMissingTarget(position_key,
                                      ticket,
                                      position_time);
         continue;
        }

      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const bool target_attained =
         (position_type == POSITION_TYPE_BUY)
         ? (bid > 0.0 && bid >= target)
         : (ask > 0.0 && ask <= target);
      if(target_attained)
        {
         QM_LogEvent(
            QM_INFO,
            "STRATEGY_EXIT",
            StringFormat(
               "{\"strategy\":\"STR-027\",\"ticket\":%I64u,\"reason\":\"gap_closed_pre_tp\",\"target\":%.8f,\"bid\":%.8f,\"ask\":%.8f}",
               ticket,
               target,
               bid,
               ask));
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
         continue;
        }

      if(position_key == g_str027_tp_retry_position_key &&
         current_bar > 0 &&
         current_bar == g_str027_tp_retry_wait_bar)
         continue;
      if(!QM_TM_MoveTP(ticket,
                       target,
                       "STR027_GAP_CLOSE"))
        {
         g_str027_tp_retry_position_key = position_key;
         g_str027_tp_retry_wait_bar = current_bar;
        }
      else
        {
         g_str027_tp_retry_position_key = 0;
         g_str027_tp_retry_wait_bar = 0;
        }
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
