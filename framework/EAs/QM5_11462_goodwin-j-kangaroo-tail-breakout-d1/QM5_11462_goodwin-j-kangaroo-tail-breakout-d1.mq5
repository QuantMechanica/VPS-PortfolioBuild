#property strict
#property version   "5.0"
#property description "QM5_11462 Goodwin-J Kangaroo Tail Breakout D1"

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
input int    qm_ea_id                   = 11462;
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
input double strategy_filter_pct        = 0.5;   // skip an overextended bar-3 close; 0 disables
input int    strategy_offset_pips       = 1;     // entry and stop offset beyond bar-3 extremes
input int    strategy_range_cap_pips    = 80;    // maximum bar-3 high-low range
input int    strategy_spread_cap_pips   = 20;    // maximum positive spread; zero spread remains valid
input bool   strategy_block_friday      = true;  // do not arm a Friday-session entry
input int    strategy_eod_hour_et       = 17;    // same-session exit hour in US Eastern time
input int    strategy_eod_minute_et     = 0;     // same-session exit minute in US Eastern time

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // Keep per-tick management and the EOD exit live. The card's Friday,
   // spread, and range filters are entry-only and are applied in EntrySignal.
   return (_Period != PERIOD_D1);
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

   if(strategy_filter_pct < 0.0 || strategy_offset_pips <= 0 ||
      strategy_range_cap_pips <= 0 || strategy_spread_cap_pips < 0 ||
      strategy_eod_hour_et < 0 || strategy_eod_hour_et > 23 ||
      strategy_eod_minute_et < 0 || strategy_eod_minute_et > 59)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;

   // The card permits one pending order at a time. Inspect only this
   // magic+symbol and leave all foreign orders untouched.
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_SYMBOL) == _Symbol)
         return false;
     }

   const datetime broker_now = TimeCurrent();
   if(strategy_block_friday)
     {
      MqlDateTime broker_parts;
      TimeToStruct(broker_now, broker_parts);
      if(broker_parts.day_of_week == 5)
         return false;
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   if(ask > bid && spread_cap > 0.0 && (ask - bid) > spread_cap)
      return false;

   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, 3, bars); // perf-allowed: fixed three-bar kangaroo structure, called only after framework QM_IsNewBar().
   if(copied != 3)
      return false;

   const double high1 = bars[0].high;
   const double low1 = bars[0].low;
   const double close1 = bars[0].close;
   const double high2 = bars[1].high;
   const double low2 = bars[1].low;
   const double close2 = bars[1].close;
   const double high3 = bars[2].high;
   const double low3 = bars[2].low;
   if(high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0 ||
      high2 <= 0.0 || low2 <= 0.0 || close2 <= 0.0 ||
      high3 <= 0.0 || low3 <= 0.0 || high1 < low1)
      return false;

   const double range_cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_range_cap_pips);
   if(range_cap <= 0.0 || (high1 - low1) > range_cap)
      return false;

   const bool tail_low = (low2 < low3 && low2 < low1);
   const bool tail_high = (high2 > high3 && high2 > high1);
   // The card requires one order but does not define a tie-break when the
   // middle bar is simultaneously an outside high and low, so skip that bar.
   if(tail_low == tail_high)
      return false;

   const double filter_fraction = strategy_filter_pct / 100.0;
   if(tail_low && strategy_filter_pct > 0.0 && close1 > close2 &&
      (close1 - close2) / close2 > filter_fraction)
      return false;
   if(tail_high && strategy_filter_pct > 0.0 && close1 < close2 &&
      (close2 - close1) / close2 > filter_fraction)
      return false;

   const double offset = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_offset_pips);
   if(offset <= 0.0)
      return false;

   // Pending lifetime ends at the next configured US-Eastern EOD. The
   // framework helper converts broker time to UTC; the US-DST helper then
   // selects the Eastern offset without hard-coding a seasonal broker clock.
   const datetime utc_now = QM_BrokerToUTC(broker_now);
   const int eastern_offset_hours = QM_IsUSDSTUTC(utc_now) ? 4 : 5;
   const datetime eastern_now = utc_now - eastern_offset_hours * 3600;
   MqlDateTime eod_parts;
   TimeToStruct(eastern_now, eod_parts);
   eod_parts.hour = strategy_eod_hour_et;
   eod_parts.min = strategy_eod_minute_et;
   eod_parts.sec = 0;
   datetime eod_eastern = StructToTime(eod_parts);
   if(eod_eastern <= eastern_now)
      eod_eastern += 86400;
   datetime eod_utc = eod_eastern + 5 * 3600;
   if(QM_IsUSDSTUTC(eod_utc))
      eod_utc = eod_eastern + 4 * 3600;
   const long lifetime = (long)(eod_utc - utc_now);
   if(lifetime <= 0 || lifetime > 172800)
      return false;

   if(tail_low)
     {
      const double entry_price = QM_StopRulesNormalizePrice(_Symbol, high1 + offset);
      const double stop_price = QM_StopRulesNormalizePrice(_Symbol, low1 - offset);
      if(entry_price <= ask || stop_price <= 0.0 || stop_price >= entry_price)
         return false;

      req.type = QM_BUY_STOP;
      req.price = entry_price;
      req.sl = stop_price;
      req.tp = 0.0;
      req.reason = "KANGAROO_TAIL_LONG";
      req.expiration_seconds = (int)lifetime;
      return true;
     }

   const double entry_price = QM_StopRulesNormalizePrice(_Symbol, low1 - offset);
   const double stop_price = QM_StopRulesNormalizePrice(_Symbol, high1 + offset);
   if(entry_price >= bid || entry_price <= 0.0 || stop_price <= entry_price)
      return false;

   req.type = QM_SELL_STOP;
   req.price = entry_price;
   req.sl = stop_price;
   req.tp = 0.0;
   req.reason = "KANGAROO_TAIL_SHORT";
   req.expiration_seconds = (int)lifetime;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial-close, or scale-in rule.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(strategy_eod_hour_et < 0 || strategy_eod_hour_et > 23 ||
      strategy_eod_minute_et < 0 || strategy_eod_minute_et > 59)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const datetime utc_now = QM_BrokerToUTC(TimeCurrent());
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const datetime opened_broker = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened_broker <= 0)
         continue;
      const datetime opened_utc = QM_BrokerToUTC(opened_broker);
      const int opened_et_offset_hours = QM_IsUSDSTUTC(opened_utc) ? 4 : 5;
      const datetime opened_eastern = opened_utc - opened_et_offset_hours * 3600;

      MqlDateTime target_parts;
      TimeToStruct(opened_eastern, target_parts);
      target_parts.hour = strategy_eod_hour_et;
      target_parts.min = strategy_eod_minute_et;
      target_parts.sec = 0;
      datetime target_eastern = StructToTime(target_parts);
      if(target_eastern <= opened_eastern)
         target_eastern += 86400;

      datetime target_utc = target_eastern + 5 * 3600;
      if(QM_IsUSDSTUTC(target_utc))
         target_utc = target_eastern + 4 * 3600;
      if(utc_now >= target_utc)
         return true;
     }

   return false;
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
