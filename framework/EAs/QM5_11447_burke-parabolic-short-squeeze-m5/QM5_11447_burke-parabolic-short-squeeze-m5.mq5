#property strict
#property version   "5.0"
#property description "QM5_11447 Burke parabolic short squeeze (M5+D1)"

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
input int    qm_ea_id                   = 11447;
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
input int    strategy_pattern_bars       = 3;    // P3: 2 / 3 / 4 consecutive D1 closes
input int    strategy_ema_period         = 20;   // P3: 13 / 20 / 34 on M5
input int    strategy_sl_pips            = 20;   // P3: 15 / 20 / 25; card cap = 25
input int    strategy_tp_min_pips        = 50;   // minimum TP; P3: 50 / 100 / 200
input int    strategy_tp_max_pips        = 250;  // cap for prior-swing extension
input int    strategy_london_start_utc   = 7;    // inclusive
input int    strategy_london_end_utc     = 12;   // exclusive
input int    strategy_ny_start_utc       = 13;   // inclusive
input int    strategy_ny_end_utc         = 17;   // exclusive
input int    strategy_spread_cap_pips    = 15;   // card cap; zero tester spread passes

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // No Trade Filter (spread): .DWX Model-4 tests may report ask == bid.
   // Block only missing prices or a genuinely positive spread above 15 pips.
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || strategy_spread_cap_pips <= 0)
      return true;

   const double spread_cap =
      QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   if(spread_cap <= 0.0)
      return true;

   return (ask > bid && (ask - bid) > spread_cap);
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // One entry per D1 squeeze event. The framework calendar key avoids a
   // per-EA iTime/date gate and resets the latch when the closed D1 setup bar
   // changes. This is deterministic event state, not an adaptive parameter.
   static int  latched_setup_key = 0;
   static bool setup_consumed = false;
   const int current_setup_key =
      QM_CalendarPeriodKey(PERIOD_D1, _Symbol, 1);
   if(current_setup_key <= 0)
      return false;
   if(current_setup_key != latched_setup_key)
     {
      latched_setup_key = current_setup_key;
      setup_consumed = false;
     }
   if(setup_consumed)
      return false;

   if(strategy_pattern_bars < 2 || strategy_pattern_bars > 4 ||
      strategy_ema_period < 2 ||
      strategy_sl_pips < 1 || strategy_sl_pips > 25 ||
      strategy_tp_min_pips < 1 ||
      strategy_tp_max_pips < strategy_tp_min_pips || strategy_tp_max_pips > 250 ||
      strategy_london_start_utc < 0 || strategy_london_start_utc > 23 ||
      strategy_london_end_utc < 1 || strategy_london_end_utc > 24 ||
      strategy_ny_start_utc < 0 || strategy_ny_start_utc > 23 ||
      strategy_ny_end_utc < 1 || strategy_ny_end_utc > 24)
      return false;

   // Session STATE: use the just-closed M5 bar, convert broker time to UTC,
   // then admit the card's London or New York liquidity window.
   const datetime bar_broker = iTime(_Symbol, PERIOD_M5, 1); // perf-allowed: one closed-bar timestamp behind the framework new-bar gate.
   if(bar_broker <= 0)
      return false;
   const datetime bar_utc = QM_BrokerToUTC(bar_broker);
   if(bar_utc <= 0)
      return false;

   MqlDateTime utc_dt;
   ZeroMemory(utc_dt);
   TimeToStruct(bar_utc, utc_dt);
   const bool in_london =
      (utc_dt.hour >= strategy_london_start_utc &&
       utc_dt.hour < strategy_london_end_utc);
   const bool in_ny =
      (utc_dt.hour >= strategy_ny_start_utc &&
       utc_dt.hour < strategy_ny_end_utc);
   if(!in_london && !in_ny)
      return false;

   // D1 setup STATE: N consecutive lower closes plus a new low and bullish
   // reversal for LONG; the card-authorized mirror creates the SHORT state.
   bool lower_closes = true;
   bool higher_closes = true;
   for(int k = 1; k <= strategy_pattern_bars; ++k)
     {
      const double close_k = iClose(_Symbol, PERIOD_D1, k); // perf-allowed: bounded bespoke D1 structure behind the framework new-bar gate.
      const double close_prior = iClose(_Symbol, PERIOD_D1, k + 1); // perf-allowed: bounded bespoke D1 structure behind the framework new-bar gate.
      if(close_k <= 0.0 || close_prior <= 0.0)
         return false;
      if(close_k >= close_prior)
         lower_closes = false;
      if(close_k <= close_prior)
         higher_closes = false;
     }

   const double d1_open_1 = iOpen(_Symbol, PERIOD_D1, 1); // perf-allowed: card-authorized reversal bar behind the framework new-bar gate.
   const double d1_close_1 = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: card-authorized reversal bar behind the framework new-bar gate.
   const double d1_low_1 = iLow(_Symbol, PERIOD_D1, 1); // perf-allowed: card-authorized false breakdown behind the framework new-bar gate.
   const double d1_low_2 = iLow(_Symbol, PERIOD_D1, 2); // perf-allowed: card-authorized false breakdown reference behind the framework new-bar gate.
   const double d1_high_1 = iHigh(_Symbol, PERIOD_D1, 1); // perf-allowed: card-authorized false breakout behind the framework new-bar gate.
   const double d1_high_2 = iHigh(_Symbol, PERIOD_D1, 2); // perf-allowed: card-authorized false breakout reference behind the framework new-bar gate.
   const double prior_swing_high = iHigh(_Symbol, PERIOD_D1, 3); // perf-allowed: card-authorized prior swing target behind the framework new-bar gate.
   const double prior_swing_low = iLow(_Symbol, PERIOD_D1, 3); // perf-allowed: literal mirror target behind the framework new-bar gate.
   if(d1_open_1 <= 0.0 || d1_close_1 <= 0.0 ||
      d1_low_1 <= 0.0 || d1_low_2 <= 0.0 ||
      d1_high_1 <= 0.0 || d1_high_2 <= 0.0 ||
      prior_swing_high <= 0.0 || prior_swing_low <= 0.0)
      return false;

   int direction = 0;
   if(lower_closes && d1_low_1 < d1_low_2 && d1_close_1 > d1_open_1)
      direction = 1;
   else if(higher_closes && d1_high_1 > d1_high_2 && d1_close_1 < d1_open_1)
      direction = -1;
   if(direction == 0)
      return false;

   // M5 trigger EVENT: one closed-bar EMA cross in the D1 setup direction.
   const double ema_1 = QM_EMA(_Symbol, PERIOD_M5, strategy_ema_period, 1);
   const double ema_2 = QM_EMA(_Symbol, PERIOD_M5, strategy_ema_period, 2);
   const double m5_close_1 = iClose(_Symbol, PERIOD_M5, 1); // perf-allowed: card-authorized closed M5 cross bar behind the framework new-bar gate.
   const double m5_close_2 = iClose(_Symbol, PERIOD_M5, 2); // perf-allowed: card-authorized prior M5 cross state behind the framework new-bar gate.
   if(ema_1 <= 0.0 || ema_2 <= 0.0 ||
      m5_close_1 <= 0.0 || m5_close_2 <= 0.0)
      return false;

   QM_OrderType side = QM_BUY;
   if(direction > 0)
     {
      if(!(m5_close_1 > ema_1 && m5_close_2 <= ema_2))
         return false;
      side = QM_BUY;
     }
   else
     {
      if(!(m5_close_1 < ema_1 && m5_close_2 >= ema_2))
         return false;
      side = QM_SELL;
     }

   const double entry = (side == QM_BUY)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl =
      QM_StopFixedPips(_Symbol, side, entry, strategy_sl_pips);
   const double min_tp_distance =
      QM_StopRulesPipsToPriceDistance(_Symbol, strategy_tp_min_pips);
   const double max_tp_distance =
      QM_StopRulesPipsToPriceDistance(_Symbol, strategy_tp_max_pips);
   if(sl <= 0.0 || min_tp_distance <= 0.0 || max_tp_distance <= 0.0)
      return false;

   double tp = 0.0;
   if(side == QM_BUY)
     {
      tp = entry + min_tp_distance;
      if(prior_swing_high > tp)
         tp = MathMin(prior_swing_high, entry + max_tp_distance);
     }
   else
     {
      tp = entry - min_tp_distance;
      if(prior_swing_low < tp)
         tp = MathMax(prior_swing_low, entry - max_tp_distance);
     }
   tp = QM_StopRulesNormalizePrice(_Symbol, tp);
   if(tp <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = (side == QM_BUY)
                ? "burke_parabolic_squeeze_long"
                : "burke_parabolic_squeeze_short";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   setup_consumed = true;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed SL/TP only; framework Friday-close remains active.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // Card's mechanical Exit section specifies TP; there is no extra close.
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade2 high-impact blackout
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

   // News hooks and framework blackout modes gate entries only. They stay
   // below management and exits so risk controls remain live during news.
   if(Strategy_NewsFilterHook(broker_now))
      return;

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
