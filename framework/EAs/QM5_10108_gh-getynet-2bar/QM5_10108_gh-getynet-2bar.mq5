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

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   static int last_entry_day_key = -1;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // Fetch 8 closed bars (shifts 1-8) once per new bar. ArraySetAsSeries=true
   // means bars[0]=shift1 (most-recently-closed), bars[1]=shift2, etc.
   MqlRates bars[]; // perf-allowed: bespoke 2-bar reversal, fixed 8-bar window, called once per closed bar via QM_IsNewBar gate in OnTick
   ArraySetAsSeries(bars, true);
   if(CopyRates(_Symbol, _Period, 1, 8, bars) < 8) // perf-allowed: bespoke 2-bar reversal, fixed 8-bar window, called once per closed bar via QM_IsNewBar gate in OnTick
      return false;

   // bars[0]=shift1="bar6" (confirmatory), bars[1]=shift2="bar5" (pivot),
   // bars[2]=shift3="bar4" (signal), bars[0..6]=7-bar pattern window
   MqlDateTime dt;
   TimeToStruct(bars[0].time, dt);
   if(dt.hour != strategy_open_hour_broker)
      return false;

   const int day_key = dt.year * 1000 + dt.day_of_year;
   if(last_entry_day_key == day_key)
      return false;

   const double o4 = bars[2].open;
   const double h4 = bars[2].high;
   const double l4 = bars[2].low;
   const double c4 = bars[2].close;
   const double o5 = bars[1].open;
   const double h5 = bars[1].high;
   const double l5 = bars[1].low;
   const double c5 = bars[1].close;
   const double h6 = bars[0].high;
   const double l6 = bars[0].low;

   if(h4 <= 0.0 || h5 <= 0.0 || h6 <= 0.0 || l4 <= 0.0 || l5 <= 0.0 || l6 <= 0.0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   double window_high = -DBL_MAX;
   double window_low = DBL_MAX;
   bool low_at_bar5 = true;
   bool high_at_bar5 = true;
   for(int i = 0; i < 7; ++i)
     {
      window_high = MathMax(window_high, bars[i].high);
      window_low = MathMin(window_low, bars[i].low);
      if(i != 1)
        {
         if(l5 >= bars[i].low)
            low_at_bar5 = false;
         if(h5 <= bars[i].high)
            high_at_bar5 = false;
        }
     }

   const double range_points = (window_high - window_low) / point;
   if(range_points <= 0.0)
      return false;
   if(strategy_range_min_points > 0.0 && range_points < strategy_range_min_points)
      return false;
   if(strategy_range_max_points > 0.0 && range_points > strategy_range_max_points)
      return false;

   const int stop_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double spread_points = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / point;
   const double atr = (strategy_max_sl_atr_mult > 0.0) ? QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1) : 0.0;
   if(strategy_max_sl_atr_mult > 0.0 && atr <= 0.0)
      return false;

   if(low_at_bar5 &&
      o4 > c4 &&
      h5 < h4 &&
      h6 > h4 &&
      (!strategy_pinbar_opposite_body || o5 < c5))
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double sl = MathMin(o5, c5);
      const double tp = h4 + (h4 - o5);
      const double accumulation_points = MathAbs(h4 - o5) / point;
      const double risk_points = MathAbs(entry - sl) / point;
      if(tp > entry && sl < entry && risk_points > 0.0 &&
         (stop_level <= 0 || risk_points >= (double)stop_level) &&
         (strategy_min_accum_points <= 0.0 || accumulation_points >= strategy_min_accum_points) &&
         (strategy_max_spread_risk_pct <= 0.0 || spread_points <= risk_points * strategy_max_spread_risk_pct / 100.0) &&
         (strategy_max_sl_atr_mult <= 0.0 || MathAbs(entry - sl) <= atr * strategy_max_sl_atr_mult))
        {
         req.type = QM_BUY;
         req.price = 0.0;
         req.sl = NormalizeDouble(sl, _Digits);
         req.tp = NormalizeDouble(tp, _Digits);
         req.reason = "GETYNET_2BAR_LONG";
         last_entry_day_key = day_key;
         return true;
        }
     }

   if(high_at_bar5 &&
      o4 < c4 &&
      l5 > l4 &&
      l6 < l4 &&
      (!strategy_pinbar_opposite_body || o5 > c5))
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double sl = MathMax(o5, c5);
      const double tp = l4 - (o5 - l4);
      const double accumulation_points = MathAbs(o5 - l4) / point;
      const double risk_points = MathAbs(entry - sl) / point;
      if(tp < entry && sl > entry && risk_points > 0.0 &&
         (stop_level <= 0 || risk_points >= (double)stop_level) &&
         (strategy_min_accum_points <= 0.0 || accumulation_points >= strategy_min_accum_points) &&
         (strategy_max_spread_risk_pct <= 0.0 || spread_points <= risk_points * strategy_max_spread_risk_pct / 100.0) &&
         (strategy_max_sl_atr_mult <= 0.0 || MathAbs(entry - sl) <= atr * strategy_max_sl_atr_mult))
        {
         req.type = QM_SELL;
         req.price = 0.0;
         req.sl = NormalizeDouble(sl, _Digits);
         req.tp = NormalizeDouble(tp, _Digits);
         req.reason = "GETYNET_2BAR_SHORT";
         last_entry_day_key = day_key;
         return true;
        }
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card implements no trailing, break-even, partial close, or add-on logic.
  }

bool Strategy_ExitSignal()
  {
   // Card exits only through the pattern-derived SL/TP and framework Friday close.
   return false;
  }

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
