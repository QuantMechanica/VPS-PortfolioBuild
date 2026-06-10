#property strict
#property version   "5.0"
#property description "QM5_10108 GitHub getYourNet Two-Bar London Reversal"

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
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
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
input int    qm_ea_id                   = 10108;
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
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
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
input int    strategy_open_hour_broker      = 9;
input bool   strategy_pinbar_opposite_body  = false;
input double strategy_range_min_points      = 0.0;
input double strategy_range_max_points      = 0.0;
input double strategy_min_accum_points      = 0.0;
input double strategy_max_spread_risk_pct   = 5.0;
input int    strategy_atr_period            = 14;
input double strategy_max_sl_atr_mult       = 3.0;

int g_last_entry_day_key = -1;

int Strategy_DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 1000 + dt.day_of_year;
  }

void Strategy_ResetRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool Strategy_HasWindowData()
  {
   return (iTime(_Symbol, _Period, 7) > 0); // perf-allowed: structural candle-window availability check, one-off closed-bar read
  }

bool Strategy_ExtremeAtIndex5(const bool want_low)
  {
   const double target = want_low ? iLow(_Symbol, _Period, 2) : iHigh(_Symbol, _Period, 2); // perf-allowed: bespoke 7-bar reversal pattern, fixed shifts, closed-bar only
   if(target <= 0.0)
      return false;

   for(int shift = 1; shift <= 7; ++shift)
     {
      if(shift == 2)
         continue;
      const double v = want_low ? iLow(_Symbol, _Period, shift) : iHigh(_Symbol, _Period, shift); // perf-allowed: structural extreme scan, 7-bar bounded, closed-bar only
      if(v <= 0.0)
         return false;
      if(want_low && target >= v)
         return false;
      if(!want_low && target <= v)
         return false;
     }
   return true;
  }

double Strategy_WindowRangePoints()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;

   double hi = -DBL_MAX;
   double lo = DBL_MAX;
   for(int shift = 1; shift <= 7; ++shift)
     {
      const double h = iHigh(_Symbol, _Period, shift); // perf-allowed: bespoke range filter, 7-bar bounded, closed-bar only
      const double l = iLow(_Symbol, _Period, shift);  // perf-allowed: bespoke range filter, 7-bar bounded, closed-bar only
      if(h <= 0.0 || l <= 0.0)
         return 0.0;
      hi = MathMax(hi, h);
      lo = MathMin(lo, l);
     }
   return (hi - lo) / point;
  }

bool Strategy_FilterRanges(const double accumulation_points)
  {
   const double range_points = Strategy_WindowRangePoints();
   if(range_points <= 0.0)
      return false;
   if(strategy_range_min_points > 0.0 && range_points < strategy_range_min_points)
      return false;
   if(strategy_range_max_points > 0.0 && range_points > strategy_range_max_points)
      return false;
   if(strategy_min_accum_points > 0.0 && accumulation_points < strategy_min_accum_points)
      return false;
   return true;
  }

bool Strategy_FilterRiskDistance(const double entry_price, const double sl_price)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || entry_price <= 0.0 || sl_price <= 0.0)
      return false;

   const double risk_points = MathAbs(entry_price - sl_price) / point;
   if(risk_points <= 0.0)
      return false;

   const int stop_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(stop_level > 0 && risk_points < (double)stop_level)
      return false;

   if(strategy_max_spread_risk_pct > 0.0)
     {
      const double spread_points = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / point;
      if(spread_points > risk_points * strategy_max_spread_risk_pct / 100.0)
         return false;
     }

   if(strategy_max_sl_atr_mult > 0.0)
     {
      const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
      if(atr <= 0.0)
         return false;
      if(MathAbs(entry_price - sl_price) > atr * strategy_max_sl_atr_mult)
         return false;
     }

   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_ResetRequest(req);
   if(!Strategy_HasWindowData())
      return false;

   const datetime setup_bar_time = iTime(_Symbol, _Period, 1); // perf-allowed: London-open hour gate, single closed-bar read
   if(setup_bar_time <= 0)
      return false;

   MqlDateTime dt;
   TimeToStruct(setup_bar_time, dt);
   if(dt.hour != strategy_open_hour_broker)
      return false;

   const int day_key = Strategy_DayKey(setup_bar_time);
   if(g_last_entry_day_key == day_key)
      return false;

   const double o4 = iOpen(_Symbol, _Period, 3);   // perf-allowed: bespoke 2-bar reversal OHLC, fixed shifts, closed-bar only
   const double h4 = iHigh(_Symbol, _Period, 3);   // perf-allowed: bespoke 2-bar reversal OHLC, fixed shifts, closed-bar only
   const double l4 = iLow(_Symbol, _Period, 3);    // perf-allowed: bespoke 2-bar reversal OHLC, fixed shifts, closed-bar only
   const double c4 = iClose(_Symbol, _Period, 3);  // perf-allowed: bespoke 2-bar reversal OHLC, fixed shifts, closed-bar only
   const double o5 = iOpen(_Symbol, _Period, 2);   // perf-allowed: bespoke 2-bar reversal OHLC, fixed shifts, closed-bar only
   const double h5 = iHigh(_Symbol, _Period, 2);   // perf-allowed: bespoke 2-bar reversal OHLC, fixed shifts, closed-bar only
   const double l5 = iLow(_Symbol, _Period, 2);    // perf-allowed: bespoke 2-bar reversal OHLC, fixed shifts, closed-bar only
   const double c5 = iClose(_Symbol, _Period, 2);  // perf-allowed: bespoke 2-bar reversal OHLC, fixed shifts, closed-bar only
   const double h6 = iHigh(_Symbol, _Period, 1);   // perf-allowed: bespoke 2-bar reversal OHLC, fixed shifts, closed-bar only
   const double l6 = iLow(_Symbol, _Period, 1);    // perf-allowed: bespoke 2-bar reversal OHLC, fixed shifts, closed-bar only
   if(o4 <= 0.0 || h4 <= 0.0 || l4 <= 0.0 || c4 <= 0.0 ||
      o5 <= 0.0 || h5 <= 0.0 || l5 <= 0.0 || c5 <= 0.0 ||
      h6 <= 0.0 || l6 <= 0.0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   if(Strategy_ExtremeAtIndex5(true) &&
      o4 > c4 &&
      h5 < h4 &&
      h6 > h4 &&
      (!strategy_pinbar_opposite_body || o5 < c5))
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double sl = MathMin(o5, c5);
      const double tp = h4 + (h4 - o5);
      const double accumulation_points = MathAbs(h4 - o5) / point;
      if(tp > entry && sl < entry &&
         Strategy_FilterRanges(accumulation_points) &&
         Strategy_FilterRiskDistance(entry, sl))
        {
         req.type = QM_BUY;
         req.price = 0.0;
         req.sl = NormalizeDouble(sl, _Digits);
         req.tp = NormalizeDouble(tp, _Digits);
         req.reason = "GETYNET_2BAR_LONG";
         g_last_entry_day_key = day_key;
         return true;
        }
     }

   if(Strategy_ExtremeAtIndex5(false) &&
      o4 < c4 &&
      l5 > l4 &&
      l6 < l4 &&
      (!strategy_pinbar_opposite_body || o5 > c5))
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double sl = MathMax(o5, c5);
      const double tp = l4 - (o5 - l4);
      const double accumulation_points = MathAbs(o5 - l4) / point;
      if(tp < entry && sl > entry &&
         Strategy_FilterRanges(accumulation_points) &&
         Strategy_FilterRiskDistance(entry, sl))
        {
         req.type = QM_SELL;
         req.price = 0.0;
         req.sl = NormalizeDouble(sl, _Digits);
         req.tp = NormalizeDouble(tp, _Digits);
         req.reason = "GETYNET_2BAR_SHORT";
         g_last_entry_day_key = day_key;
         return true;
        }
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card implements no trailing, break-even, partial close, or add-on logic.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // Card exits only through the pattern-derived SL/TP and framework Friday close.
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
   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults.
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

   // Per-tick: trade management can adjust SL/TP on open positions.
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
   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
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
   // FW4: feeds closing-deal net-profits to the KS kill-switch.
   // No-op outside Q13 (when no baseline.json exists).
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
