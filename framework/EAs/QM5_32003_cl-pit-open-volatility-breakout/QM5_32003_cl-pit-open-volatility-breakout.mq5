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
input int    qm_ea_id                   = 32003;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
// All other phases use 42 by default. Stress / noise dimensions read from
// this single seed so reproducibility is guaranteed across re-runs.
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;    // Live setfiles use 0.5%; tester default is fixed risk.
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
input string InpBoxStart                = "08:50"; // Energy opening-box start, US Eastern time.
input string InpBoxEnd                  = "09:00"; // Energy opening-box end, US Eastern time.
input double InpTPDollars               = 0.50;    // Take-profit distance in CL dollars per barrel.
input double InpSLDollars               = 0.25;    // Stop-loss distance in CL dollars per barrel.

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const int magic = QM_FrameworkMagic();
   const int open_positions = QM_TM_OpenPositionCount(magic);

   bool has_pending = false;
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
        {
         has_pending = true;
         break;
        }
     }

   // Existing exposure must continue through management and the 14:30 ET
   // close path. EntrySignal separately enforces the one-position ceiling.
   if(open_positions > 0 || has_pending)
      return false;

   const datetime utc_now = QM_BrokerToUTC(TimeCurrent());
   MqlDateTime utc_parts;
   if(!TimeToStruct(utc_now, utc_parts))
      return true;

   // Card rollover blackout: 23:55 through 00:05 GMT/UTC.
   const int utc_minute = utc_parts.hour * 60 + utc_parts.min;
   if(utc_minute >= 23 * 60 + 55 || utc_minute <= 5)
      return true;

   const double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   const double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   static double initial_equity = 0.0;
   if(initial_equity <= 0.0 && equity > 0.0)
      initial_equity = equity;

   // Card entry circuit breakers. Hard equity exits are evaluated in the
   // Trade Close hook so they cannot suspend management of existing risk.
   if(g_qm_ks_day_start_equity > 0.0 &&
      balance <= g_qm_ks_day_start_equity * 0.98)
      return true;
   if(initial_equity > 0.0 && equity <= initial_equity * 0.95)
      return true;

   // The ATR-relative spread gate is evaluated once per closed bar inside
   // EntrySignal, avoiding a pooled-indicator read on every M5 tick.
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
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
   if(QM_TM_OpenPositionCount(magic) >= 1)
      return false;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) == magic &&
         OrderGetString(ORDER_SYMBOL) == _Symbol)
         return false;
     }

   if(StringLen(InpBoxStart) != 5 || StringLen(InpBoxEnd) != 5 ||
      StringFind(InpBoxStart, ":") != 2 || StringFind(InpBoxEnd, ":") != 2)
      return false;

   const int start_hour = (int)StringToInteger(StringSubstr(InpBoxStart, 0, 2));
   const int start_minute_part = (int)StringToInteger(StringSubstr(InpBoxStart, 3, 2));
   const int end_hour = (int)StringToInteger(StringSubstr(InpBoxEnd, 0, 2));
   const int end_minute_part = (int)StringToInteger(StringSubstr(InpBoxEnd, 3, 2));
   if(start_hour < 0 || start_hour > 23 || end_hour < 0 || end_hour > 23 ||
      start_minute_part < 0 || start_minute_part > 59 ||
      end_minute_part < 0 || end_minute_part > 59)
      return false;

   const int box_start_minute = start_hour * 60 + start_minute_part;
   const int box_end_minute = end_hour * 60 + end_minute_part;
   const int box_minutes = box_end_minute - box_start_minute;
   if(box_minutes <= 0 || box_minutes % 5 != 0)
      return false;

   const datetime broker_now = TimeCurrent();
   const datetime utc_now = QM_BrokerToUTC(broker_now);
   const int et_offset_hours = QM_IsUSDSTUTC(utc_now) ? -4 : -5;
   const datetime et_now = utc_now + (datetime)(et_offset_hours * 3600);
   MqlDateTime et_parts;
   if(!TimeToStruct(et_now, et_parts))
      return false;

   // The framework calls this hook on a new M5 bar. Accept the first tick of
   // the bar whose open follows the box, even if that tick arrives after :00.
   const int et_minute = et_parts.hour * 60 + et_parts.min;
   if(et_minute < box_end_minute || et_minute >= box_end_minute + 5)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_M5, 14, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   // DWX-safe spread rule: zero modeled spread is valid and never fail-closed.
   if(ask > bid && (ask - bid) > 1.8 * atr)
      return false;

   const int range_bars = box_minutes / 5;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_M5, 1, range_bars, rates); // perf-allowed: bounded opening-box read after the framework new-bar gate.
   if(copied != range_bars)
      return false;

   double box_high = -DBL_MAX;
   double box_low = DBL_MAX;
   int matched_bars = 0;
   for(int i = 0; i < copied; ++i)
     {
      const datetime bar_utc = QM_BrokerToUTC(rates[i].time);
      const int bar_et_offset_hours = QM_IsUSDSTUTC(bar_utc) ? -4 : -5;
      const datetime bar_et = bar_utc + (datetime)(bar_et_offset_hours * 3600);
      MqlDateTime bar_et_parts;
      if(!TimeToStruct(bar_et, bar_et_parts))
         continue;
      if(bar_et_parts.year != et_parts.year ||
         bar_et_parts.mon != et_parts.mon ||
         bar_et_parts.day != et_parts.day)
         continue;

      const int bar_minute = bar_et_parts.hour * 60 + bar_et_parts.min;
      if(bar_minute < box_start_minute || bar_minute >= box_end_minute)
         continue;

      box_high = MathMax(box_high, rates[i].high);
      box_low = MathMin(box_low, rates[i].low);
      ++matched_bars;
     }

   if(matched_bars != range_bars || box_high <= 0.0 || box_low <= 0.0 ||
      box_high <= box_low || InpSLDollars <= 0.0 || InpTPDollars <= 0.0)
      return false;

   MqlDateTime close_parts = et_parts;
   close_parts.hour = 14;
   close_parts.min = 30;
   close_parts.sec = 0;
   const datetime et_close = StructToTime(close_parts);
   const int expiration_seconds = (int)(et_close - et_now);
   if(expiration_seconds <= 0)
      return false;

   const double buy_entry = QM_StopRulesNormalizePrice(_Symbol, box_high + 0.03);
   const double sell_entry = QM_StopRulesNormalizePrice(_Symbol, box_low - 0.03);
   if(buy_entry <= ask || sell_entry >= bid || buy_entry <= sell_entry)
      return false;

   QM_EntryRequest buy_req;
   buy_req.type = QM_BUY_STOP;
   buy_req.price = buy_entry;
   buy_req.sl = QM_StopRulesNormalizePrice(_Symbol, buy_entry - InpSLDollars);
   buy_req.tp = QM_StopRulesNormalizePrice(_Symbol, buy_entry + InpTPDollars);
   buy_req.reason = "CL_PIT_OPEN_BUY_STOP";
   buy_req.symbol_slot = qm_magic_slot_offset;
   buy_req.expiration_seconds = expiration_seconds;

   QM_EntryRequest sell_req;
   sell_req.type = QM_SELL_STOP;
   sell_req.price = sell_entry;
   sell_req.sl = QM_StopRulesNormalizePrice(_Symbol, sell_entry + InpSLDollars);
   sell_req.tp = QM_StopRulesNormalizePrice(_Symbol, sell_entry - InpTPDollars);
   sell_req.reason = "CL_PIT_OPEN_SELL_STOP";
   sell_req.symbol_slot = qm_magic_slot_offset;
   sell_req.expiration_seconds = expiration_seconds;

   if(buy_req.sl <= 0.0 || buy_req.sl >= buy_entry || buy_req.tp <= buy_entry ||
      sell_req.sl <= sell_entry || sell_req.tp <= 0.0 || sell_req.tp >= sell_entry)
      return false;

   // Submit one bracket leg here; the framework submits the returned peer.
   ulong buy_ticket = 0;
   if(!QM_TM_OpenPosition(buy_req, buy_ticket))
      return false;

   req = sell_req;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   const bool has_position = (QM_TM_OpenPositionCount(magic) > 0);

   const double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   const double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   static double initial_equity = 0.0;
   if(initial_equity <= 0.0 && equity > 0.0)
      initial_equity = equity;

   const bool daily_realized_halt =
      (g_qm_ks_day_start_equity > 0.0 &&
       balance <= g_qm_ks_day_start_equity * 0.98);
   const bool daily_drawdown_halt =
      (g_qm_ks_day_start_equity > 0.0 &&
       equity <= g_qm_ks_day_start_equity * 0.975);
   const bool total_drawdown_halt =
      (initial_equity > 0.0 && equity <= initial_equity * 0.95);

   const datetime utc_now = QM_BrokerToUTC(TimeCurrent());
   const int et_offset_hours = QM_IsUSDSTUTC(utc_now) ? -4 : -5;
   const datetime et_now = utc_now + (datetime)(et_offset_hours * 3600);
   MqlDateTime et_parts;
   if(!TimeToStruct(et_now, et_parts))
      return;
   const bool time_stop = (et_parts.hour * 60 + et_parts.min >= 14 * 60 + 30);

   // OCO: once either stop fills, cancel its peer. Also remove unfilled stops
   // at the card's time stop or whenever a card loss circuit breaker trips.
   if(!has_position && !time_stop && !daily_realized_halt &&
      !daily_drawdown_halt && !total_drawdown_halt)
      return;

   string cancel_reason = "cl_pit_open_oco_peer";
   if(time_stop)
      cancel_reason = "cl_pit_open_time_stop";
   else if(daily_realized_halt || daily_drawdown_halt || total_drawdown_halt)
      cancel_reason = "cl_pit_open_loss_halt";

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
      QM_TM_RemovePendingOrder(ticket, cancel_reason);
     }

   // The card's state diagram names BE/trailing states but supplies no
   // trigger values; no discretionary SL mutation is introduced here.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   static double initial_equity = 0.0;
   if(initial_equity <= 0.0 && equity > 0.0)
      initial_equity = equity;

   // Card capital-preservation exits: 2.5% broker-day drawdown and 5.0%
   // total drawdown from this EA instance's starting equity.
   if(g_qm_ks_day_start_equity > 0.0 &&
      equity <= g_qm_ks_day_start_equity * 0.975)
      return true;
   if(initial_equity > 0.0 && equity <= initial_equity * 0.95)
      return true;

   const datetime utc_now = QM_BrokerToUTC(TimeCurrent());
   const int et_offset_hours = QM_IsUSDSTUTC(utc_now) ? -4 : -5;
   const datetime et_now = utc_now + (datetime)(et_offset_hours * 3600);
   MqlDateTime et_parts;
   if(!TimeToStruct(et_now, et_parts))
      return false;

   // Card time stop: flatten at 14:30 US Eastern time.
   return (et_parts.hour * 60 + et_parts.min >= 14 * 60 + 30);
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
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
