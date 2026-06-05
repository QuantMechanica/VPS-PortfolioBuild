#property strict
#property version   "5.0"
#property description "QM5_10822 TradingView VWAP Breakout Retest Trend"

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
input int    qm_ea_id                   = 10822;
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
input int    strategy_ema_period          = 50;    // Card: trend EMA baseline 50, P3 sweeps 100/200.
input int    strategy_atr_period          = 14;    // Card: ATR(14) risk and retest buffer.
input double strategy_retest_buffer_atr   = 0.25;  // Card: retest buffer = 0.25 * ATR baseline.
input int    strategy_retest_lookback     = 10;    // Card: retest lookback baseline 10 bars.
input int    strategy_min_session_bars    = 8;     // Card: session VWAP available for at least 8 bars.
input double strategy_atr_sl_mult         = 1.5;   // Card: stop = 1.5 * ATR baseline.
input double strategy_atr_tp_mult         = 2.5;   // Card: target = 2.5 * ATR baseline.
input double strategy_max_spread_atr_frac = 0.20;  // Build filter: block abnormal spread relative to ATR.
input bool   strategy_vwap_exit_enabled   = true;  // Card: optional exit on adverse VWAP cross.

double g_session_vwap = 0.0;
double g_prev_session_vwap = 0.0;
double g_prev_close = 0.0;
double g_last_atr = 0.0;
double g_session_volume_sum = 0.0;
int    g_session_key = -1;
int    g_session_bars = 0;
int    g_long_setup_age = -1;
int    g_short_setup_age = -1;
bool   g_long_retest_seen = false;
bool   g_short_retest_seen = false;
bool   g_long_signal = false;
bool   g_short_signal = false;

int Strategy_SessionKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.year * 1000 + dt.day_of_year);
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

void Strategy_ResetSession()
  {
   g_session_vwap = 0.0;
   g_prev_session_vwap = 0.0;
   g_prev_close = 0.0;
   g_last_atr = 0.0;
   g_session_volume_sum = 0.0;
   g_session_bars = 0;
   g_long_setup_age = -1;
   g_short_setup_age = -1;
   g_long_retest_seen = false;
   g_short_retest_seen = false;
   g_long_signal = false;
   g_short_signal = false;
  }

bool Strategy_AdvanceClosedBarState()
  {
   g_long_signal = false;
   g_short_signal = false;

   const datetime bar_time = iTime(_Symbol, _Period, 1); // perf-allowed: session VWAP anchor on closed-bar path.
   if(bar_time <= 0)
      return false;

   const int session_key = Strategy_SessionKey(bar_time);
   if(session_key != g_session_key)
     {
      g_session_key = session_key;
      Strategy_ResetSession();
     }

   const double open1 = iOpen(_Symbol, _Period, 1);       // perf-allowed: VWAP confirmation candle.
   const double high1 = iHigh(_Symbol, _Period, 1);       // perf-allowed: VWAP typical price.
   const double low1 = iLow(_Symbol, _Period, 1);         // perf-allowed: VWAP retest touch.
   const double close1 = iClose(_Symbol, _Period, 1);     // perf-allowed: VWAP cross/confirmation close.
   const long tick_volume = iVolume(_Symbol, _Period, 1); // perf-allowed: session VWAP volume term.
   if(open1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0)
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
   const double ema = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_period, 1);
   if(g_last_atr <= 0.0 || ema <= 0.0 || g_session_vwap <= 0.0)
     {
      g_prev_close = close1;
      return false;
     }

   const bool state_ready = (g_session_bars >= strategy_min_session_bars &&
                             g_prev_close > 0.0 &&
                             g_prev_session_vwap > 0.0);
   const double buffer = strategy_retest_buffer_atr * g_last_atr;

   if(g_long_setup_age >= 0)
      g_long_setup_age++;
   if(g_short_setup_age >= 0)
      g_short_setup_age++;

   if(state_ready && g_prev_close <= g_prev_session_vwap && close1 > g_session_vwap)
     {
      g_long_setup_age = 0;
      g_long_retest_seen = false;
      g_short_setup_age = -1;
      g_short_retest_seen = false;
     }
   else if(state_ready && g_prev_close >= g_prev_session_vwap && close1 < g_session_vwap)
     {
      g_short_setup_age = 0;
      g_short_retest_seen = false;
      g_long_setup_age = -1;
      g_long_retest_seen = false;
     }

   if(g_long_setup_age > strategy_retest_lookback)
     {
      g_long_setup_age = -1;
      g_long_retest_seen = false;
     }
   if(g_short_setup_age > strategy_retest_lookback)
     {
      g_short_setup_age = -1;
      g_short_retest_seen = false;
     }

   const bool long_confirmation = (close1 > open1 && close1 > g_session_vwap && close1 > ema);
   const bool short_confirmation = (close1 < open1 && close1 < g_session_vwap && close1 < ema);
   const bool long_retest_now = (g_long_setup_age >= 0 && low1 <= g_session_vwap + buffer && close1 >= g_session_vwap);
   const bool short_retest_now = (g_short_setup_age >= 0 && high1 >= g_session_vwap - buffer && close1 <= g_session_vwap);

   if(g_long_setup_age >= 0 && g_long_retest_seen && long_confirmation)
      g_long_signal = true;
   if(g_short_setup_age >= 0 && g_short_retest_seen && short_confirmation)
      g_short_signal = true;

   if(long_retest_now)
      g_long_retest_seen = true;
   if(short_retest_now)
      g_short_retest_seen = true;

   g_prev_close = close1;
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // Time: this intraday card is defined for M15/M30/H1 only.
   if(_Period != PERIOD_M15 && _Period != PERIOD_M30 && _Period != PERIOD_H1)
      return true;

   if(strategy_ema_period < 2 ||
      strategy_atr_period < 1 ||
      strategy_retest_buffer_atr <= 0.0 ||
      strategy_retest_lookback < 1 ||
      strategy_min_session_bars < 1 ||
      strategy_atr_sl_mult <= 0.0 ||
      strategy_atr_tp_mult <= 0.0 ||
      strategy_max_spread_atr_frac <= 0.0)
      return true;

   // Spread: block abnormal spread once ATR state is available.
   if(g_last_atr > 0.0)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
         return true;
      if((ask - bid) > g_last_atr * strategy_max_spread_atr_frac)
         return true;
     }

   // News: central framework filter and Strategy_NewsFilterHook handle news.
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

   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   if(Strategy_SelectOurPosition(ticket, ptype))
      return false;

   if(!g_long_signal && !g_short_signal)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double entry = g_long_signal ? ask : bid;
   if(entry <= 0.0 || g_last_atr <= 0.0)
      return false;

   if(g_long_signal)
     {
      req.type = QM_BUY;
      req.sl = entry - strategy_atr_sl_mult * g_last_atr;
      req.tp = entry + strategy_atr_tp_mult * g_last_atr;
      req.reason = "VWAP_BREAK_RETEST_LONG";
      g_long_setup_age = -1;
      g_long_retest_seen = false;
      g_long_signal = false;
      return true;
     }

   req.type = QM_SELL;
   req.sl = entry + strategy_atr_sl_mult * g_last_atr;
   req.tp = entry - strategy_atr_tp_mult * g_last_atr;
   req.reason = "VWAP_BREAK_RETEST_SHORT";
   g_short_setup_age = -1;
   g_short_retest_seen = false;
   g_short_signal = false;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies static ATR SL/TP; no trailing, partial, or break-even rule.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(!strategy_vwap_exit_enabled || g_session_vwap <= 0.0)
      return false;

   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   if(!Strategy_SelectOurPosition(ticket, ptype))
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ptype == POSITION_TYPE_BUY && bid > 0.0 && bid < g_session_vwap)
      return true;
   if(ptype == POSITION_TYPE_SELL && ask > 0.0 && ask > g_session_vwap)
      return true;
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
