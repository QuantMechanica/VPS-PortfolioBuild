#property strict
#property version   "5.0"
#property description "QM5_20092 PriceBob reference-bar breakout on XAGUSD"

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
input int    qm_ea_id                   = 20092;
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
input int    strategy_reference_hour_et             = 8;
input int    strategy_reference_minute_et           = 20;
input int    strategy_session_end_hour_broker       = 21;
input int    strategy_daily_atr_period              = 14;
input double strategy_ref_range_min_atr_ratio       = 0.30;
input double strategy_ref_range_max_atr_ratio       = 2.50;
input double strategy_max_spread_ref_range_ratio    = 0.20;
input double strategy_target_ref_range_mult         = 1.00;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // Card time, range and spread filters gate only new entries. Keeping them
   // out of this per-tick hook lets management and the 21:00 exit keep running.
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

   // The approved card is M5-native and single-symbol. This check gates only
   // entries; an accidental chart mismatch never suspends position exits.
   if((ENUM_TIMEFRAMES)_Period != PERIOD_M5)
      return false;

   if(strategy_reference_hour_et < 0 || strategy_reference_hour_et > 23 ||
      strategy_reference_minute_et < 0 || strategy_reference_minute_et > 59 ||
      strategy_session_end_hour_broker < 0 || strategy_session_end_hour_broker > 23 ||
      strategy_daily_atr_period < 2 ||
      strategy_ref_range_min_atr_ratio < 0.0 ||
      strategy_ref_range_max_atr_ratio <= strategy_ref_range_min_atr_ratio ||
      strategy_max_spread_ref_range_ratio < 0.0 ||
      strategy_target_ref_range_mult <= 0.0)
      return false;

   // Static hook-local state is advanced once per closed M5 bar by the
   // framework's single QM_IsNewBar() gate. No history window is rescanned.
   static int    session_day_key = 0;
   static bool   reference_seen = false;
   static bool   reference_valid = false;
   static bool   trade_taken_today = false;
   static double reference_high = 0.0;
   static double reference_low = 0.0;
   static double reference_range = 0.0;

   MqlRates closed_bar;
   ZeroMemory(closed_bar);
   if(!QM_ReadBar(_Symbol, PERIOD_M5, 1, closed_bar))
      return false;

   // Darwinex NY-close broker time and Eastern time observe the same US DST
   // transitions. The framework conversion therefore maps the 08:20 ET anchor
   // to the correct broker bar year-round without a hard-coded seasonal offset.
   const datetime utc_time = QM_BrokerToUTC(closed_bar.time);
   const int eastern_offset_seconds = QM_IsUSDSTUTC(utc_time) ? 4 * 3600 : 5 * 3600;
   const datetime eastern_time = utc_time - eastern_offset_seconds;
   MqlDateTime eastern_dt;
   ZeroMemory(eastern_dt);
   TimeToStruct(eastern_time, eastern_dt);

   const int current_day_key =
      eastern_dt.year * 10000 + eastern_dt.mon * 100 + eastern_dt.day;
   if(current_day_key != session_day_key)
     {
      session_day_key = current_day_key;
      reference_seen = false;
      reference_valid = false;
      trade_taken_today = false;
      reference_high = 0.0;
      reference_low = 0.0;
      reference_range = 0.0;
     }

   // Capture exactly the first 08:20-08:25 ET M5 bar after it closes.
   if(eastern_dt.hour == strategy_reference_hour_et &&
      eastern_dt.min == strategy_reference_minute_et)
     {
      reference_seen = true;
      reference_high = closed_bar.high;
      reference_low = closed_bar.low;
      reference_range = reference_high - reference_low;

      const double daily_atr =
         QM_ATR(_Symbol, PERIOD_D1, strategy_daily_atr_period, 1);
      reference_valid =
         reference_low > 0.0 &&
         reference_range > 0.0 &&
         daily_atr > 0.0 &&
         reference_range >= strategy_ref_range_min_atr_ratio * daily_atr &&
         reference_range <= strategy_ref_range_max_atr_ratio * daily_atr;
      return false;
     }

   if(!reference_seen || !reference_valid || trade_taken_today)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;
   if(QM_TM_OpenPositionCount(magic) > 0)
     {
      trade_taken_today = true;
      return false;
     }

   MqlDateTime broker_now;
   ZeroMemory(broker_now);
   TimeToStruct(TimeCurrent(), broker_now);
   if(broker_now.hour >= strategy_session_end_hour_broker)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   // .DWX Every-Real-Tick tests legitimately model ask==bid. Only a genuinely
   // positive, wide spread blocks entry.
   if(ask > bid &&
      (ask - bid) > strategy_max_spread_ref_range_ratio * reference_range)
      return false;

   if(closed_bar.close > reference_high)
     {
      const double entry_price = ask;
      const double sl_price =
         QM_StopRulesNormalizePrice(_Symbol, reference_low);
      const double tp_price =
         QM_StopRulesNormalizePrice(
            _Symbol,
            entry_price + strategy_target_ref_range_mult * reference_range);
      if(sl_price <= 0.0 || tp_price <= entry_price || sl_price >= entry_price)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl_price;
      req.tp = tp_price;
      req.reason = "REFBAR_CLOSE_BREAKOUT_LONG";
      trade_taken_today = true;
      return true;
     }

   if(closed_bar.close < reference_low)
     {
      const double entry_price = bid;
      const double sl_price =
         QM_StopRulesNormalizePrice(_Symbol, reference_high);
      const double tp_price =
         QM_StopRulesNormalizePrice(
            _Symbol,
            entry_price - strategy_target_ref_range_mult * reference_range);
      if(sl_price <= entry_price || tp_price <= 0.0 || tp_price >= entry_price)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl_price;
      req.tp = tp_price;
      req.reason = "REFBAR_CLOSE_BREAKOUT_SHORT";
      trade_taken_today = true;
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card: no trailing stop, break-even move, partial close or scale-in.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(strategy_session_end_hour_broker < 0 ||
      strategy_session_end_hour_broker > 23)
      return false;

   MqlDateTime broker_now;
   ZeroMemory(broker_now);
   TimeToStruct(TimeCurrent(), broker_now);
   return (broker_now.hour >= strategy_session_end_hour_broker);
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // The card uses the standing high-impact calendar convention, supplied by
   // the framework's entry-only two-axis news gate.
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
