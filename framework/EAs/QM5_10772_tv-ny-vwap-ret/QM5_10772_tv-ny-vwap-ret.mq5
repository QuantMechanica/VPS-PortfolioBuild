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
input int    qm_ea_id                   = 9999;
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
input ENUM_TIMEFRAMES strategy_htf_tf                  = PERIOD_H1;
input int             strategy_htf_ema_period          = 100;
input int             strategy_exit_ema_period         = 20;
input int             strategy_fast_ema_period         = 20;
input int             strategy_entry_model             = 1;      // 1=VWAP, 2=premarket, 3=EMA, 4=combined
input int             strategy_premarket_breakout_mode = 0;      // 0=close beyond, 1=retest
input int             strategy_atr_period              = 14;
input double          strategy_atr_stop_buffer         = 0.50;
input double          strategy_vwap_retest_atr         = 0.20;
input double          strategy_min_range_atr           = 0.25;
input double          strategy_min_vwap_slope_points   = 0.0;
input double          strategy_exit_body_atr           = 0.20;
input int             strategy_cooldown_bars           = 5;
input int             strategy_max_spread_points       = 80;
input int             strategy_premarket_start_hour    = 12;
input int             strategy_premarket_start_minute  = 0;
input int             strategy_ny_start_hour           = 16;
input int             strategy_ny_start_minute         = 30;
input int             strategy_ny_end_hour             = 21;
input int             strategy_ny_end_minute           = 0;

double g_vwap_num = 0.0;
double g_vwap_den = 0.0;
double g_session_vwap = 0.0;
double g_prev_session_vwap = 0.0;
double g_premarket_high = 0.0;
double g_premarket_low = 0.0;
double g_bar_open = 0.0;
double g_bar_high = 0.0;
double g_bar_low = 0.0;
double g_bar_close = 0.0;
double g_prev_close = 0.0;
bool   g_exit_long = false;
bool   g_exit_short = false;
int    g_session_day_key = -1;
int    g_cooldown_bars_remaining = 0;

int Strategy_MinuteOfDay(const datetime when)
  {
   MqlDateTime dt;
   TimeToStruct(when, dt);
   return dt.hour * 60 + dt.min;
  }

int Strategy_DayKey(const datetime when)
  {
   MqlDateTime dt;
   TimeToStruct(when, dt);
   return dt.year * 1000 + dt.day_of_year;
  }

int Strategy_ConfigMinute(const int hour, const int minute)
  {
   int h = hour;
   int m = minute;
   if(h < 0) h = 0;
   if(h > 23) h = 23;
   if(m < 0) m = 0;
   if(m > 59) m = 59;
   return h * 60 + m;
  }

bool Strategy_InWindow(const int minute_now, const int start_minute, const int end_minute)
  {
   if(start_minute == end_minute)
      return true;
   if(start_minute < end_minute)
      return (minute_now >= start_minute && minute_now < end_minute);
   return (minute_now >= start_minute || minute_now < end_minute);
  }

int Strategy_PremarketStartMinute()
  {
   return Strategy_ConfigMinute(strategy_premarket_start_hour, strategy_premarket_start_minute);
  }

int Strategy_NYStartMinute()
  {
   return Strategy_ConfigMinute(strategy_ny_start_hour, strategy_ny_start_minute);
  }

int Strategy_NYEndMinute()
  {
   return Strategy_ConfigMinute(strategy_ny_end_hour, strategy_ny_end_minute);
  }

bool Strategy_IsPremarketMinute(const int minute_now)
  {
   return Strategy_InWindow(minute_now, Strategy_PremarketStartMinute(), Strategy_NYStartMinute());
  }

bool Strategy_IsNYMinute(const int minute_now)
  {
   return Strategy_InWindow(minute_now, Strategy_NYStartMinute(), Strategy_NYEndMinute());
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      return true;
     }
   return false;
  }

void Strategy_ResetSessionState(const int day_key)
  {
   g_vwap_num = 0.0;
   g_vwap_den = 0.0;
   g_session_vwap = 0.0;
   g_prev_session_vwap = 0.0;
   g_premarket_high = 0.0;
   g_premarket_low = 0.0;
   g_exit_long = false;
   g_exit_short = false;
   g_session_day_key = day_key;
  }

bool Strategy_AdvanceStateOnClosedBar()
  {
   MqlRates bar[1];
   if(CopyRates(_Symbol, _Period, 1, 1, bar) != 1) // perf-allowed: Strategy_EntrySignal is called only after the framework QM_IsNewBar gate.
      return false;

   const int day_key = Strategy_DayKey(bar[0].time);
   if(day_key != g_session_day_key)
      Strategy_ResetSessionState(day_key);

   g_prev_close = g_bar_close;
   g_bar_open = bar[0].open;
   g_bar_high = bar[0].high;
   g_bar_low = bar[0].low;
   g_bar_close = bar[0].close;

   const int minute_now = Strategy_MinuteOfDay(bar[0].time);
   if(Strategy_IsPremarketMinute(minute_now))
     {
      if(g_premarket_high <= 0.0 || g_bar_high > g_premarket_high)
         g_premarket_high = g_bar_high;
      if(g_premarket_low <= 0.0 || g_bar_low < g_premarket_low)
         g_premarket_low = g_bar_low;
     }

   if(Strategy_IsPremarketMinute(minute_now) || Strategy_IsNYMinute(minute_now))
     {
      const double typical = (g_bar_high + g_bar_low + g_bar_close) / 3.0;
      const double vol = (bar[0].tick_volume > 0) ? (double)bar[0].tick_volume : 1.0;
      g_prev_session_vwap = g_session_vwap;
      g_vwap_num += typical * vol;
      g_vwap_den += vol;
      if(g_vwap_den > 0.0)
         g_session_vwap = g_vwap_num / g_vwap_den;
     }

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   const double exit_ema = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_exit_ema_period, 1);
   const double body = MathAbs(g_bar_close - g_bar_open);
   const bool body_ok = (atr <= 0.0 || strategy_exit_body_atr <= 0.0 || body >= atr * strategy_exit_body_atr);
   g_exit_long = (exit_ema > 0.0 && body_ok && g_bar_open >= exit_ema && g_bar_close < exit_ema);
   g_exit_short = (exit_ema > 0.0 && body_ok && g_bar_open <= exit_ema && g_bar_close > exit_ema);

   if(g_cooldown_bars_remaining > 0)
      g_cooldown_bars_remaining--;

   return true;
  }

bool Strategy_RegimeAllowsEntry(const double atr)
  {
   if(g_session_vwap <= 0.0 || atr <= 0.0)
      return false;
   if(strategy_min_range_atr > 0.0 && (g_bar_high - g_bar_low) < atr * strategy_min_range_atr)
      return false;
   if(strategy_min_vwap_slope_points > 0.0)
     {
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(point <= 0.0)
         return false;
      const double slope_points = MathAbs(g_session_vwap - g_prev_session_vwap) / point;
      if(slope_points < strategy_min_vwap_slope_points)
         return false;
     }
   return true;
  }

bool Strategy_BuildRequest(QM_EntryRequest &req,
                           const QM_OrderType side,
                           const double stop_anchor,
                           const double atr,
                           const string reason)
  {
   const double entry = QM_OrderTypeIsBuy(side) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                                : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0 || atr <= 0.0 || stop_anchor <= 0.0)
      return false;

   const double buffer = atr * strategy_atr_stop_buffer;
   double sl = 0.0;
   if(QM_OrderTypeIsBuy(side))
      sl = NormalizeDouble(stop_anchor - buffer, _Digits);
   else
      sl = NormalizeDouble(stop_anchor + buffer, _Digits);

   if(QM_OrderTypeIsBuy(side) && sl >= entry)
      return false;
   if(!QM_OrderTypeIsBuy(side) && sl <= entry)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(strategy_max_spread_points > 0 && spread > strategy_max_spread_points)
      return true;

   const int minute_now = Strategy_MinuteOfDay(TimeCurrent());
   if(Strategy_IsPremarketMinute(minute_now) || Strategy_IsNYMinute(minute_now))
      return false;

   if(Strategy_HasOpenPosition())
      return false;

   return true;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(!Strategy_AdvanceStateOnClosedBar())
      return false;

   if(g_cooldown_bars_remaining > 0)
      return false;

   const int minute_now = Strategy_MinuteOfDay(TimeCurrent());
   if(!Strategy_IsNYMinute(minute_now))
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(!Strategy_RegimeAllowsEntry(atr))
      return false;

   const double htf_ema = QM_EMA(_Symbol, strategy_htf_tf, strategy_htf_ema_period, 1);
   const double fast_ema = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_fast_ema_period, 1);
   if(htf_ema <= 0.0 || fast_ema <= 0.0)
      return false;

   const bool bullish = (g_bar_close > htf_ema);
   const bool bearish = (g_bar_close < htf_ema);
   const double retest_tolerance = atr * strategy_vwap_retest_atr;

   bool long_signal = false;
   bool short_signal = false;
   double long_anchor = 0.0;
   double short_anchor = 0.0;
   string reason = "";

   if(strategy_entry_model == 1 || strategy_entry_model == 4)
     {
      const bool long_vwap = bullish && g_bar_low <= g_session_vwap + retest_tolerance && g_bar_close > g_session_vwap;
      const bool short_vwap = bearish && g_bar_high >= g_session_vwap - retest_tolerance && g_bar_close < g_session_vwap;
      if(long_vwap)
        {
         long_signal = true;
         long_anchor = MathMin(g_bar_low, g_session_vwap);
         reason = "vwap_retest_long";
        }
      if(short_vwap)
        {
         short_signal = true;
         short_anchor = MathMax(g_bar_high, g_session_vwap);
         reason = "vwap_retest_short";
        }
     }

   if((strategy_entry_model == 2 || strategy_entry_model == 4) && !long_signal && !short_signal &&
      g_premarket_high > 0.0 && g_premarket_low > 0.0)
     {
      const bool close_beyond_long = (g_bar_close > g_premarket_high);
      const bool close_beyond_short = (g_bar_close < g_premarket_low);
      const bool retest_long = (g_bar_low <= g_premarket_high && g_bar_close > g_premarket_high);
      const bool retest_short = (g_bar_high >= g_premarket_low && g_bar_close < g_premarket_low);
      const bool use_retest = (strategy_premarket_breakout_mode == 1);
      if(bullish && (use_retest ? retest_long : close_beyond_long))
        {
         long_signal = true;
         long_anchor = MathMin(g_bar_low, g_premarket_high);
         reason = "premarket_breakout_long";
        }
      if(bearish && (use_retest ? retest_short : close_beyond_short))
        {
         short_signal = true;
         short_anchor = MathMax(g_bar_high, g_premarket_low);
         reason = "premarket_breakout_short";
        }
     }

   if((strategy_entry_model == 3 || strategy_entry_model == 4) && !long_signal && !short_signal)
     {
      const bool long_ema = bullish && g_bar_low <= fast_ema + retest_tolerance && g_bar_close > fast_ema;
      const bool short_ema = bearish && g_bar_high >= fast_ema - retest_tolerance && g_bar_close < fast_ema;
      if(long_ema)
        {
         long_signal = true;
         long_anchor = MathMin(g_bar_low, fast_ema);
         reason = "ema_retest_long";
        }
      if(short_ema)
        {
         short_signal = true;
         short_anchor = MathMax(g_bar_high, fast_ema);
         reason = "ema_retest_short";
        }
     }

   if(long_signal)
      return Strategy_BuildRequest(req, QM_BUY, long_anchor, atr, reason);
   if(short_signal)
      return Strategy_BuildRequest(req, QM_SELL, short_anchor, atr, reason);

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card collapses partial-profit and breakeven handling to full-position exits.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const int minute_now = Strategy_MinuteOfDay(TimeCurrent());
   const bool session_done = !Strategy_IsPremarketMinute(minute_now) && !Strategy_IsNYMinute(minute_now);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      if(session_done)
        {
         g_cooldown_bars_remaining = strategy_cooldown_bars;
         return true;
        }

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(position_type == POSITION_TYPE_BUY && g_exit_long)
        {
         g_cooldown_bars_remaining = strategy_cooldown_bars;
         return true;
        }
      if(position_type == POSITION_TYPE_SELL && g_exit_short)
        {
         g_cooldown_bars_remaining = strategy_cooldown_bars;
         return true;
        }
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
