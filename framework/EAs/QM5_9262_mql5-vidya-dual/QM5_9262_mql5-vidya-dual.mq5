#property strict
#property version   "5.0"
#property description "QM5_9262 MQL5 Dual VIDYA Crossover"

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
input int    qm_ea_id                   = 9262;
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
input ENUM_TIMEFRAMES strategy_signal_tf       = PERIOD_H1;
input int             strategy_fast_cmo_period = 9;
input int             strategy_fast_ema_period = 12;
input int             strategy_slow_cmo_period = 20;
input int             strategy_slow_ema_period = 50;
input int             strategy_atr_period      = 14;
input double          strategy_atr_sl_mult     = 2.2;
input double          strategy_take_profit_rr  = 2.4;
input int             strategy_max_hold_bars   = 96;
input int             strategy_cooldown_bars   = 3;
input int             strategy_vidya_warmup_bars = 180;

int  g_last_closed_bar_signal = 0;
int  g_cooldown_remaining_bars = 0;
bool g_had_position = false;

double Strategy_CloseAt(const ENUM_TIMEFRAMES tf, const int shift)
  {
   return iClose(_Symbol, tf, shift); // perf-allowed: VIDYA is a bespoke closed-bar indicator and the framework has no OHLC reader/VIDYA wrapper.
  }

double Strategy_CMOAt(const ENUM_TIMEFRAMES tf, const int period, const int shift)
  {
   if(period <= 0 || shift < 1)
      return 0.0;

   double sum_up = 0.0;
   double sum_down = 0.0;
   for(int i = shift; i < shift + period; ++i)
     {
      const double c0 = Strategy_CloseAt(tf, i);
      const double c1 = Strategy_CloseAt(tf, i + 1);
      if(c0 <= 0.0 || c1 <= 0.0)
         return 0.0;

      const double diff = c0 - c1;
      if(diff > 0.0)
         sum_up += diff;
      else
         sum_down -= diff;
     }

   const double denom = sum_up + sum_down;
   if(denom <= 0.0)
      return 0.0;
   return 100.0 * (sum_up - sum_down) / denom;
  }

double Strategy_VIDYAAt(const ENUM_TIMEFRAMES tf,
                        const int ema_period,
                        const int cmo_period,
                        const int shift)
  {
   if(ema_period <= 1 || cmo_period <= 0 || shift < 1)
      return 0.0;

   const int history = MathMax(strategy_vidya_warmup_bars, ema_period + cmo_period + 24);
   const int seed_shift = shift + history;

   double vidya = 0.0;
   for(int i = seed_shift; i < seed_shift + ema_period; ++i)
     {
      const double close_i = Strategy_CloseAt(tf, i);
      if(close_i <= 0.0)
         return 0.0;
      vidya += close_i;
     }
   vidya /= (double)ema_period;

   const double alpha = 2.0 / ((double)ema_period + 1.0);
   for(int s = seed_shift - 1; s >= shift; --s)
     {
      const double close_s = Strategy_CloseAt(tf, s);
      const double cmo_abs = MathAbs(Strategy_CMOAt(tf, cmo_period, s)) / 100.0;
      if(close_s <= 0.0)
         return 0.0;
      vidya = alpha * cmo_abs * close_s + (1.0 - alpha * cmo_abs) * vidya;
     }

   return vidya;
  }

int Strategy_CrossoverSignal()
  {
   const double fast_1 = Strategy_VIDYAAt(strategy_signal_tf, strategy_fast_ema_period, strategy_fast_cmo_period, 1);
   const double fast_2 = Strategy_VIDYAAt(strategy_signal_tf, strategy_fast_ema_period, strategy_fast_cmo_period, 2);
   const double slow_1 = Strategy_VIDYAAt(strategy_signal_tf, strategy_slow_ema_period, strategy_slow_cmo_period, 1);
   const double slow_2 = Strategy_VIDYAAt(strategy_signal_tf, strategy_slow_ema_period, strategy_slow_cmo_period, 2);
   if(fast_1 <= 0.0 || fast_2 <= 0.0 || slow_1 <= 0.0 || slow_2 <= 0.0)
      return 0;

   if(fast_2 <= slow_2 && fast_1 > slow_1)
      return 1;
   if(fast_2 >= slow_2 && fast_1 < slow_1)
      return -1;
   return 0;
  }

bool Strategy_FindOurPosition(ulong &ticket,
                              ENUM_POSITION_TYPE &position_type,
                              datetime &open_time)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   open_time = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = t;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

void Strategy_RefreshPositionLifecycle()
  {
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   datetime open_time;
   const bool has_position = Strategy_FindOurPosition(ticket, position_type, open_time);
   if(g_had_position && !has_position)
      g_cooldown_remaining_bars = MathMax(g_cooldown_remaining_bars, strategy_cooldown_bars);
   g_had_position = has_position;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // Card specifies only the framework default time/spread/news gates.
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

   g_last_closed_bar_signal = Strategy_CrossoverSignal();

   if(g_cooldown_remaining_bars > 0)
     {
      g_cooldown_remaining_bars--;
      return false;
     }

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(g_last_closed_bar_signal == 0)
      return false;

   req.type = (g_last_closed_bar_signal > 0) ? QM_BUY : QM_SELL;
   const double entry = QM_EntryMarketPrice(req.type);
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_sl_mult);
   req.tp = QM_TakeRR(_Symbol, req.type, entry, req.sl, strategy_take_profit_rr);
   req.reason = (g_last_closed_bar_signal > 0) ? "VIDYA_DUAL_CROSS_LONG" : "VIDYA_DUAL_CROSS_SHORT";

   if(req.sl <= 0.0 || req.tp <= 0.0)
      return false;

   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   Strategy_RefreshPositionLifecycle();
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   datetime open_time;
   if(!Strategy_FindOurPosition(ticket, position_type, open_time))
      return false;

   if(position_type == POSITION_TYPE_BUY && g_last_closed_bar_signal < 0)
     {
      g_cooldown_remaining_bars = MathMax(g_cooldown_remaining_bars, strategy_cooldown_bars);
      return true;
     }
   if(position_type == POSITION_TYPE_SELL && g_last_closed_bar_signal > 0)
     {
      g_cooldown_remaining_bars = MathMax(g_cooldown_remaining_bars, strategy_cooldown_bars);
      return true;
     }

   const int seconds_per_bar = PeriodSeconds(strategy_signal_tf);
   if(seconds_per_bar > 0 && open_time > 0 &&
      TimeCurrent() - open_time >= strategy_max_hold_bars * seconds_per_bar)
     {
      g_cooldown_remaining_bars = MathMax(g_cooldown_remaining_bars, strategy_cooldown_bars);
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
