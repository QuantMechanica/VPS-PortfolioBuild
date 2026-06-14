#property strict
#property version   "5.0"
#property description "QM5_10784 TradingView ORBO Basic"

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
input int    qm_ea_id                   = 10784;
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
input int    strategy_range_start_hour  = 9;
input int    strategy_range_start_min   = 30;
input int    strategy_range_end_hour    = 9;
input int    strategy_range_end_min     = 50;
input int    strategy_flat_hour         = 16;
input int    strategy_flat_min          = 0;
input int    strategy_atr_period        = 14;
input bool   strategy_use_atr_buffer    = true;
input double strategy_atr_buffer_mult   = 0.10;
input double strategy_rr_target         = 1.50;
input bool   strategy_use_range_filter  = false;
input double strategy_min_range_atr     = 0.25;
input double strategy_max_range_atr     = 4.00;
input int    strategy_max_spread_points = 80;

int    g_orbo_day_key       = 0;
bool   g_orbo_have_range    = false;
bool   g_orbo_range_done    = false;
double g_orbo_high          = 0.0;
double g_orbo_low           = 0.0;

int Strategy_Hhmm(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

int Strategy_DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int Strategy_RangeStartHhmm()
  {
   return strategy_range_start_hour * 100 + strategy_range_start_min;
  }

int Strategy_RangeEndHhmm()
  {
   return strategy_range_end_hour * 100 + strategy_range_end_min;
  }

int Strategy_FlatHhmm()
  {
   return strategy_flat_hour * 100 + strategy_flat_min;
  }

void Strategy_ResetRange(const int day_key)
  {
   g_orbo_day_key = day_key;
   g_orbo_have_range = false;
   g_orbo_range_done = false;
   g_orbo_high = 0.0;
   g_orbo_low = 0.0;
  }

bool Strategy_ReadClosedBars(MqlRates &last_bar, MqlRates &prev_bar)
  {
   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, 2, bars); // perf-allowed: closed-bar OR state read, caller is gated by QM_IsNewBar().
   if(copied < 2)
      return false;

   last_bar = bars[0];
   prev_bar = bars[1];
   return true;
  }

void Strategy_AdvanceOpeningRange(const MqlRates &bar)
  {
   const int day_key = Strategy_DayKey(bar.time);
   if(day_key != g_orbo_day_key)
      Strategy_ResetRange(day_key);

   const int hhmm = Strategy_Hhmm(bar.time);
   if(hhmm >= Strategy_RangeStartHhmm() && hhmm < Strategy_RangeEndHhmm())
     {
      if(!g_orbo_have_range)
        {
         g_orbo_high = bar.high;
         g_orbo_low = bar.low;
         g_orbo_have_range = true;
        }
      else
        {
         g_orbo_high = MathMax(g_orbo_high, bar.high);
         g_orbo_low = MathMin(g_orbo_low, bar.low);
        }
     }

   if(g_orbo_have_range && hhmm >= Strategy_RangeEndHhmm())
      g_orbo_range_done = true;
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;
   return (QM_TM_OpenPositionCount(magic) > 0);
  }

bool Strategy_RangeWidthAllowed()
  {
   if(!strategy_use_range_filter)
      return true;
   if(!g_orbo_have_range || g_orbo_high <= g_orbo_low)
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double width = g_orbo_high - g_orbo_low;
   if(strategy_min_range_atr > 0.0 && width < atr * strategy_min_range_atr)
      return false;
   if(strategy_max_range_atr > 0.0 && width > atr * strategy_max_range_atr)
      return false;

   return true;
  }

double Strategy_StopBuffer()
  {
   if(!strategy_use_atr_buffer || strategy_atr_buffer_mult <= 0.0)
      return 0.0;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return -1.0;

   return atr * strategy_atr_buffer_mult;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(Strategy_HasOpenPosition())
      return false;

   if(strategy_max_spread_points > 0)
     {
      const int spread_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return true;
     }

   const int now_hhmm = Strategy_Hhmm(TimeCurrent());
   if(now_hhmm < Strategy_RangeStartHhmm() || now_hhmm >= Strategy_FlatHhmm())
      return true;

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

   MqlRates last_bar;
   MqlRates prev_bar;
   if(!Strategy_ReadClosedBars(last_bar, prev_bar))
      return false;

   Strategy_AdvanceOpeningRange(last_bar);
   if(!g_orbo_range_done || !g_orbo_have_range || g_orbo_high <= g_orbo_low)
      return false;

   const int bar_hhmm = Strategy_Hhmm(last_bar.time);
   if(bar_hhmm < Strategy_RangeEndHhmm() || bar_hhmm >= Strategy_FlatHhmm())
      return false;
   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_RangeWidthAllowed())
      return false;

   const double buffer = Strategy_StopBuffer();
   if(buffer < 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(prev_bar.close <= g_orbo_high && last_bar.close > g_orbo_high)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      const double entry = ask;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, g_orbo_low - buffer);
      req.tp = QM_TakeRR(_Symbol, req.type, entry, req.sl, strategy_rr_target);
      req.reason = "ORBO_LONG_CLOSE_CROSS";
      return (req.sl > 0.0 && req.tp > 0.0 && req.sl < entry);
     }

   if(prev_bar.close >= g_orbo_low && last_bar.close < g_orbo_low)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      const double entry = bid;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, g_orbo_high + buffer);
      req.tp = QM_TakeRR(_Symbol, req.type, entry, req.sl, strategy_rr_target);
      req.reason = "ORBO_SHORT_CLOSE_CROSS";
      return (req.sl > 0.0 && req.tp > 0.0 && req.sl > entry);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card has no trailing, partial, or break-even management.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOpenPosition())
      return false;

   return (Strategy_Hhmm(TimeCurrent()) >= Strategy_FlatHhmm());
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
