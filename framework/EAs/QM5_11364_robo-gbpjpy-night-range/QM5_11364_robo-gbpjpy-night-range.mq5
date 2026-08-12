#property strict
#property version   "5.0"
#property description "QM5_11364 RoboForex GBPJPY Night Range"

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
input int    qm_ea_id                   = 11364;
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
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE60_POST60;
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
input int    strategy_session_start_hour = 22;
input int    strategy_session_end_hour   = 7;
input int    strategy_close_hour         = 17;
input int    strategy_buffer_pips        = 5;
input int    strategy_range_cap_pips     = 70;
input double strategy_tp_multiplier      = 1.0;
input int    strategy_tp_min_pips        = 20;
input int    strategy_tp_max_pips        = 60;
input int    strategy_sl_cap_pips        = 50;
input int    strategy_cancel_hours       = 4;
input int    strategy_spread_cap_pips    = 30;
input bool   strategy_skip_monday        = true;
input int    strategy_news_window_minutes = 120;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // Card scope is GBPJPY M15 only. Entry-only time, spread and news rules
   // remain in their entry/news hooks so open-trade risk management never
   // stops merely because the entry window is closed or spreads are wide.
   if(_Symbol != "GBPJPY.DWX" && _Symbol != "GBPJPY")
      return true;
   if(_Period != PERIOD_M15)
      return true;
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_SELL_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_session_start_hour < 0 || strategy_session_start_hour > 23 ||
      strategy_session_end_hour < 0 || strategy_session_end_hour > 23 ||
      strategy_close_hour < 0 || strategy_close_hour > 23 ||
      strategy_buffer_pips <= 0 || strategy_range_cap_pips <= 0 ||
      strategy_tp_multiplier <= 0.0 || strategy_tp_min_pips <= 0 ||
      strategy_tp_max_pips < strategy_tp_min_pips ||
      strategy_sl_cap_pips <= 0 || strategy_cancel_hours <= 0 ||
      strategy_spread_cap_pips <= 0 || strategy_news_window_minutes < 0)
      return false;

   // perf-allowed: the framework has already consumed the sole M15 new-bar
   // gate; this one current-bar timestamp keys the exact 07:00 placement bar.
   const datetime bar_open = iTime(_Symbol, PERIOD_M15, 0); // perf-allowed: exact closed-bar session cadence
   if(bar_open <= 0)
      return false;

   MqlDateTime bar_tm;
   TimeToStruct(bar_open, bar_tm);
   if(bar_tm.hour != strategy_session_end_hour || bar_tm.min != 0)
      return false;
   if(strategy_skip_monday && bar_tm.day_of_week == 1)
      return false;

   const double pip_distance = QM_StopRulesPipsToPriceDistance(_Symbol, 1);
   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(pip_distance <= 0.0 || spread_cap <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;
   // DWX Model-4 commonly has ask == bid. Only a genuinely positive, wide
   // spread blocks the setup; zero modeled spread remains tradable.
   if(ask > bid && (ask - bid) > spread_cap)
      return false;

   const datetime day_start = bar_open
                              - (bar_tm.hour * 3600)
                              - (bar_tm.min * 60)
                              - bar_tm.sec;
   const datetime session_end = day_start + (strategy_session_end_hour * 3600);
   datetime session_start = day_start + (strategy_session_start_hour * 3600);
   if(strategy_session_start_hour >= strategy_session_end_hour)
      session_start -= 86400;
   if(bar_open != session_end || session_start >= session_end)
      return false;

   MqlRates session_rates[];
   // perf-allowed: one bounded CopyRates call inside the framework new-bar
   // path for the card-authorized 22:00-07:00 structural session range.
   const int copied = CopyRates(_Symbol, // perf-allowed: bounded 36-bar structural session range
                                PERIOD_M15,
                                session_start,
                                session_end - 1,
                                session_rates);
   const int bar_seconds = PeriodSeconds(PERIOD_M15);
   const int expected_bars = (bar_seconds > 0)
                             ? (int)((session_end - session_start) / bar_seconds)
                             : 0;
   if(copied <= 0 || expected_bars <= 0)
      return false;

   double asian_high = 0.0;
   double asian_low = 0.0;
   int valid_bars = 0;
   for(int i = 0; i < copied; ++i)
     {
      if(session_rates[i].time < session_start || session_rates[i].time >= session_end)
         continue;
      if(session_rates[i].high <= 0.0 || session_rates[i].low <= 0.0)
         continue;
      if(valid_bars == 0)
        {
         asian_high = session_rates[i].high;
         asian_low = session_rates[i].low;
        }
      else
        {
         asian_high = MathMax(asian_high, session_rates[i].high);
         asian_low = MathMin(asian_low, session_rates[i].low);
        }
      ++valid_bars;
     }
   if(valid_bars < expected_bars || asian_high <= asian_low)
      return false;

   const double range_pips = (asian_high - asian_low) / pip_distance;
   if(range_pips <= 0.0 || range_pips > (double)strategy_range_cap_pips)
      return false;

   const double buffer_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_buffer_pips);
   const double sl_cap_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
   double tp_pips = range_pips * strategy_tp_multiplier;
   tp_pips = MathMax((double)strategy_tp_min_pips,
                     MathMin((double)strategy_tp_max_pips, tp_pips));
   const double tp_distance = pip_distance * tp_pips;
   if(buffer_distance <= 0.0 || sl_cap_distance <= 0.0 || tp_distance <= 0.0)
      return false;

   const double buy_entry = QM_StopRulesNormalizePrice(_Symbol, asian_high + buffer_distance);
   const double sell_entry = QM_StopRulesNormalizePrice(_Symbol, asian_low - buffer_distance);
   double buy_sl = QM_StopRulesNormalizePrice(_Symbol, asian_low - buffer_distance);
   double sell_sl = QM_StopRulesNormalizePrice(_Symbol, asian_high + buffer_distance);
   buy_sl = MathMax(buy_sl,
                    QM_StopRulesNormalizePrice(_Symbol, buy_entry - sl_cap_distance));
   sell_sl = MathMin(sell_sl,
                     QM_StopRulesNormalizePrice(_Symbol, sell_entry + sl_cap_distance));
   const double buy_tp = QM_StopRulesNormalizePrice(_Symbol, buy_entry + tp_distance);
   const double sell_tp = QM_StopRulesNormalizePrice(_Symbol, sell_entry - tp_distance);

   // Both levels must still be valid pending stops when the 07:00 bar opens.
   if(buy_entry <= ask || sell_entry >= bid ||
      buy_sl <= 0.0 || sell_sl <= 0.0 || buy_tp <= buy_entry || sell_tp >= sell_entry)
      return false;

   QM_EntryRequest buy_req;
   ZeroMemory(buy_req);
   buy_req.type = QM_BUY_STOP;
   buy_req.price = buy_entry;
   buy_req.sl = buy_sl;
   buy_req.tp = buy_tp;
   buy_req.reason = "ROBO_NIGHT_RANGE_BUY_STOP";
   buy_req.symbol_slot = qm_magic_slot_offset;
   buy_req.expiration_seconds = strategy_cancel_hours * 3600;

   ulong buy_ticket = 0;
   if(!QM_TM_OpenPosition(buy_req, buy_ticket))
      return false;

   // The framework caller opens this second leg after this hook returns. The
   // entry framework permits one buy-stop plus one sell-stop for a bracket.
   req.type = QM_SELL_STOP;
   req.price = sell_entry;
   req.sl = sell_sl;
   req.tp = sell_tp;
   req.reason = "ROBO_NIGHT_RANGE_SELL_STOP";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = strategy_cancel_hours * 3600;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   bool has_position = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      has_position = true;
      break;
     }

   int pending_count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic ||
         OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP)
         ++pending_count;
     }

   const datetime broker_now = TimeCurrent();
   MqlDateTime now_tm;
   TimeToStruct(broker_now, now_tm);
   const bool after_session_close = (now_tm.hour >= strategy_close_hour);

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic ||
         OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type != ORDER_TYPE_BUY_STOP && order_type != ORDER_TYPE_SELL_STOP)
         continue;

      const datetime setup_time = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      const bool expired = (setup_time > 0 &&
                            (broker_now - setup_time) >= strategy_cancel_hours * 3600);
      string reason = "";
      if(has_position)
         reason = "sibling_activated";
      else if(expired)
         reason = "four_hour_cancel";
      else if(after_session_close)
         reason = "london_session_close";
      else if(pending_count == 1)
         reason = "incomplete_bracket";

      if(reason != "")
         QM_TM_RemovePendingOrder(ticket, reason);
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   MqlDateTime now_tm;
   TimeToStruct(TimeCurrent(), now_tm);
   return (now_tm.hour >= strategy_close_hour);
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(strategy_news_window_minutes <= 0)
      return false;

   MqlDateTime broker_tm;
   TimeToStruct(broker_time, broker_tm);
   if(broker_tm.hour != strategy_session_end_hour ||
      broker_tm.min >= PeriodSeconds(PERIOD_M15) / 60)
      return false;

   const datetime utc_time = QM_BrokerToUTC(broker_time);
   return QM_NewsInWindow(utc_time,
                          _Symbol,
                          strategy_news_window_minutes,
                          strategy_news_window_minutes,
                          "high");
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
   if(Strategy_NewsFilterHook(broker_now))
      return;

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
