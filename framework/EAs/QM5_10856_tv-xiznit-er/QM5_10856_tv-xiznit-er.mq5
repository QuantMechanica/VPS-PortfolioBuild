#property strict
#property version   "5.0"
#property description "QM5_10856 TradingView Xiznit ER Regime Scalper"

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
input int    qm_ea_id                   = 10856;
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
input int    strategy_fast_ma_period       = 9;
input int    strategy_slow_ma_period       = 21;
input int    strategy_er_length            = 20;
input double strategy_er_trend_threshold   = 0.35;
input int    strategy_atr_period           = 14;
input double strategy_atr_stop_mult        = 1.0;
input double strategy_atr_target_mult      = 1.0;
input double strategy_min_body_atr_frac    = 0.05;
input double strategy_max_spread_stop_frac = 0.15;
input int    strategy_min_session_bars     = 20;
input int    strategy_ny_open_hour_broker  = 16;
input int    strategy_ny_open_minute       = 30;
input int    strategy_open_block_minutes   = 20;
input int    strategy_lunch_start_hour     = 20;
input int    strategy_lunch_end_hour       = 21;
input int    strategy_flat_hour_broker     = 23;
input int    strategy_flat_minute_broker   = 58;

double g_session_vwap = 0.0;
double g_prev_session_vwap = 0.0;
double g_session_volume_sum = 0.0;
double g_last_atr = 0.0;
int    g_session_key = -1;
int    g_session_bars = 0;
int    g_er_regime = 0;
int    g_prev_er_regime = 0;
bool   g_long_signal = false;
bool   g_short_signal = false;

int Strategy_SessionKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 1000 + dt.day_of_year;
  }

int Strategy_MinutesOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

bool Strategy_InsideWindow(const int now_minute, const int start_minute, const int end_minute)
  {
   if(start_minute == end_minute)
      return false;
   if(start_minute < end_minute)
      return (now_minute >= start_minute && now_minute < end_minute);
   return (now_minute >= start_minute || now_minute < end_minute);
  }

void Strategy_ResetSession()
  {
   g_session_vwap = 0.0;
   g_prev_session_vwap = 0.0;
   g_session_volume_sum = 0.0;
   g_session_bars = 0;
   g_er_regime = 0;
   g_prev_er_regime = 0;
   g_long_signal = false;
   g_short_signal = false;
  }

bool Strategy_SelectOurPosition(ulong &ticket, ENUM_POSITION_TYPE &ptype)
  {
   ticket = 0;
   ptype = POSITION_TYPE_BUY;

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
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }

   return false;
  }

double Strategy_EfficiencyRatio(const int length)
  {
   if(length < 2)
      return 0.0;

   const double close_now = iClose(_Symbol, _Period, 1);              // perf-allowed: ER on closed-bar path only.
   const double close_then = iClose(_Symbol, _Period, length + 1);    // perf-allowed: ER on closed-bar path only.
   if(close_now <= 0.0 || close_then <= 0.0)
      return 0.0;

   double path = 0.0;
   for(int i = 1; i <= length; ++i)
     {
      const double c0 = iClose(_Symbol, _Period, i);                 // perf-allowed: bounded ER loop on closed-bar path only.
      const double c1 = iClose(_Symbol, _Period, i + 1);             // perf-allowed: bounded ER loop on closed-bar path only.
      if(c0 <= 0.0 || c1 <= 0.0)
         return 0.0;
      path += MathAbs(c0 - c1);
     }

   if(path <= 0.0)
      return 0.0;
   return MathAbs(close_now - close_then) / path;
  }

bool Strategy_AdvanceClosedBarState()
  {
   g_long_signal = false;
   g_short_signal = false;

   const datetime bar_time = iTime(_Symbol, _Period, 1);             // perf-allowed: session VWAP anchor on closed-bar path.
   if(bar_time <= 0)
      return false;

   const int session_key = Strategy_SessionKey(bar_time);
   if(session_key != g_session_key)
     {
      g_session_key = session_key;
      Strategy_ResetSession();
     }

   const double open1 = iOpen(_Symbol, _Period, 1);                  // perf-allowed: signal candle body on closed-bar path.
   const double high1 = iHigh(_Symbol, _Period, 1);                  // perf-allowed: VWAP typical price on closed-bar path.
   const double low1 = iLow(_Symbol, _Period, 1);                    // perf-allowed: VWAP typical price on closed-bar path.
   const double close1 = iClose(_Symbol, _Period, 1);                // perf-allowed: signal candle close on closed-bar path.
   const double high2 = iHigh(_Symbol, _Period, 2);                  // perf-allowed: prior-bar breakout confirmation.
   const double low2 = iLow(_Symbol, _Period, 2);                    // perf-allowed: prior-bar breakout confirmation.
   const long tick_volume = iVolume(_Symbol, _Period, 1);            // perf-allowed: VWAP volume term on closed-bar path.
   if(open1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0 || high2 <= 0.0 || low2 <= 0.0)
      return false;

   g_prev_session_vwap = g_session_vwap;
   const double volume = (tick_volume > 0) ? (double)tick_volume : 1.0;
   const double typical = (high1 + low1 + close1) / 3.0;
   g_session_vwap = (g_session_bars <= 0)
                    ? typical
                    : ((g_session_vwap * g_session_volume_sum + typical * volume) / (g_session_volume_sum + volume));
   g_session_volume_sum += volume;
   g_session_bars++;

   g_last_atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   const double fast1 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_fast_ma_period, 1);
   const double fast2 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_fast_ma_period, 2);
   const double slow1 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_slow_ma_period, 1);
   const double slow2 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_slow_ma_period, 2);
   if(g_last_atr <= 0.0 || fast1 <= 0.0 || fast2 <= 0.0 || slow1 <= 0.0 || slow2 <= 0.0 ||
      g_session_vwap <= 0.0 || g_prev_session_vwap <= 0.0)
      return false;

   const double er = Strategy_EfficiencyRatio(strategy_er_length);
   const double close_then = iClose(_Symbol, _Period, strategy_er_length + 1); // perf-allowed: ER direction on closed-bar path.
   g_prev_er_regime = g_er_regime;
   if(er >= strategy_er_trend_threshold && close1 > close_then)
      g_er_regime = 1;
   else if(er >= strategy_er_trend_threshold && close1 < close_then)
      g_er_regime = -1;
   else
      g_er_regime = 0;

   if(g_session_bars < strategy_min_session_bars)
      return true;

   const double body = MathAbs(close1 - open1);
   const bool body_ok = (body >= strategy_min_body_atr_frac * g_last_atr);
   const bool long_alignment = (close1 > g_session_vwap &&
                                fast1 > slow1 &&
                                fast1 > g_session_vwap &&
                                slow1 > g_session_vwap &&
                                fast2 > slow2 &&
                                fast2 > g_prev_session_vwap &&
                                slow2 > g_prev_session_vwap);
   const bool short_alignment = (close1 < g_session_vwap &&
                                 fast1 < slow1 &&
                                 fast1 < g_session_vwap &&
                                 slow1 < g_session_vwap &&
                                 fast2 < slow2 &&
                                 fast2 < g_prev_session_vwap &&
                                 slow2 < g_prev_session_vwap);
   const bool long_slope = (fast1 > fast2 && slow1 > slow2);
   const bool short_slope = (fast1 < fast2 && slow1 < slow2);

   g_long_signal = (g_prev_er_regime == 0 &&
                    g_er_regime == 1 &&
                    long_alignment &&
                    long_slope &&
                    body_ok &&
                    close1 > high2);
   g_short_signal = (g_prev_er_regime == 0 &&
                     g_er_regime == -1 &&
                     short_alignment &&
                     short_slope &&
                     body_ok &&
                     close1 < low2);

   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // Time: baseline is the card's M2/M5 intraday cadence.
   if(_Period != PERIOD_M2 && _Period != PERIOD_M5)
      return true;

   if(strategy_fast_ma_period < 1 ||
      strategy_slow_ma_period <= strategy_fast_ma_period ||
      strategy_er_length < 2 ||
      strategy_er_trend_threshold <= 0.0 ||
      strategy_atr_period < 1 ||
      strategy_atr_stop_mult <= 0.0 ||
      strategy_atr_target_mult <= 0.0 ||
      strategy_min_body_atr_frac < 0.0 ||
      strategy_max_spread_stop_frac <= 0.0 ||
      strategy_min_session_bars < 1)
      return true;

   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   if(Strategy_SelectOurPosition(ticket, ptype))
      return false;

   const datetime broker_now = TimeCurrent();
   const int now_minute = Strategy_MinutesOfDay(broker_now);
   const int open_start = MathMax(0, MathMin(1439, strategy_ny_open_hour_broker * 60 + strategy_ny_open_minute));
   const int open_end = MathMax(0, MathMin(1439, open_start + strategy_open_block_minutes));
   if(Strategy_InsideWindow(now_minute, open_start, open_end))
      return true;

   const int lunch_start = MathMax(0, MathMin(1439, strategy_lunch_start_hour * 60));
   const int lunch_end = MathMax(0, MathMin(1439, strategy_lunch_end_hour * 60));
   if(Strategy_InsideWindow(now_minute, lunch_start, lunch_end))
      return true;

   // Spread: card guard skips entries when spread exceeds 15% of ATR stop distance.
   if(g_last_atr > 0.0)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double stop_distance = strategy_atr_stop_mult * g_last_atr;
      if(ask <= 0.0 || bid <= 0.0 || ask <= bid || stop_distance <= 0.0)
         return true;
      if((ask - bid) > strategy_max_spread_stop_frac * stop_distance)
         return true;
     }

   // News: central framework news filter plus Strategy_NewsFilterHook provide P8 compatibility.
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

   if(!Strategy_AdvanceClosedBarState())
      return false;

   const int now_minute = Strategy_MinutesOfDay(TimeCurrent());
   const int flat_minute = MathMax(0, MathMin(1439, strategy_flat_hour_broker * 60 + strategy_flat_minute_broker));
   if(now_minute >= flat_minute)
      return false;

   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   if(Strategy_SelectOurPosition(ticket, ptype))
      return false;

   if(!g_long_signal && !g_short_signal)
      return false;

   const QM_OrderType side = g_long_signal ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_stop_mult);
   const double tp = QM_TakeATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_target_mult);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type = side;
   req.sl = sl;
   req.tp = tp;
   req.reason = (side == QM_BUY) ? "ER_RESET_TO_UP_FULL_FILTER" : "ER_RESET_TO_DOWN_FULL_FILTER";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card P2 baseline disables breakeven and does not specify trailing or partial exits.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   if(!Strategy_SelectOurPosition(ticket, ptype))
      return false;

   const int now_minute = Strategy_MinutesOfDay(TimeCurrent());
   const int flat_minute = MathMax(0, MathMin(1439, strategy_flat_hour_broker * 60 + strategy_flat_minute_broker));
   if(now_minute >= flat_minute)
      return true;

   if(ptype == POSITION_TYPE_BUY && g_er_regime != 1)
      return true;
   if(ptype == POSITION_TYPE_SELL && g_er_regime != -1)
      return true;

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...); callable hook retained for P8.
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
