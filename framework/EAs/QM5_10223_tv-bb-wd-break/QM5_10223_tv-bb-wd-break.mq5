#property strict
#property version   "5.0"
#property description "QM5_10223 TradingView Bollinger WD Breakout"

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
input int    qm_ea_id                   = 10223;
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
input ENUM_TIMEFRAMES strategy_signal_tf        = PERIOD_H4;
input int             strategy_bb_period        = 20;
input double          strategy_bb_deviation     = 2.0;
input int             strategy_trend_ema_period = 55;
input int             strategy_atr_period       = 14;
input double          strategy_atr_stop_mult    = 0.20;
input int             strategy_cooldown_bars    = 1;
input double          strategy_min_wick_body_x  = 10.0;
input double          strategy_upper_lower_max_x= 3.0;
input bool            strategy_time_filter_enabled = false;
input int             strategy_trade_start_hour = 0;
input int             strategy_trade_end_hour   = 24;
input double          strategy_max_spread_points = 0.0;
input bool            strategy_seasonal_windows_enabled = false;
input int             strategy_bad_start_month  = 5;
input int             strategy_bad_start_day    = 1;
input int             strategy_bad_end_month    = 10;
input int             strategy_bad_end_day      = 31;
input bool            strategy_qmonth_matrix_enabled = false;
input string          strategy_block_qmonths    = "";
input string          strategy_exit_qmonths     = "";

datetime g_recent_entry_signal_time = 0;

bool Strategy_HourAllowed(const datetime broker_time)
  {
   if(!strategy_time_filter_enabled)
      return true;

   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   const int start_hour = MathMax(0, MathMin(23, strategy_trade_start_hour));
   const int end_hour = MathMax(0, MathMin(24, strategy_trade_end_hour));
   if(start_hour == end_hour)
      return true;
   if(start_hour < end_hour)
      return (dt.hour >= start_hour && dt.hour < end_hour);
   return (dt.hour >= start_hour || dt.hour < end_hour);
  }

int Strategy_DayOfYear(const int month, const int day)
  {
   static const int month_starts[12] = {0,31,59,90,120,151,181,212,243,273,304,334};
   const int m = MathMax(1, MathMin(12, month));
   const int d = MathMax(1, MathMin(31, day));
   return month_starts[m - 1] + d;
  }

bool Strategy_InSeasonWindow(const datetime broker_time)
  {
   if(!strategy_seasonal_windows_enabled)
      return false;

   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   const int now_doy = Strategy_DayOfYear(dt.mon, dt.day);
   const int start_doy = Strategy_DayOfYear(strategy_bad_start_month, strategy_bad_start_day);
   const int end_doy = Strategy_DayOfYear(strategy_bad_end_month, strategy_bad_end_day);
   if(start_doy <= end_doy)
      return (now_doy >= start_doy && now_doy <= end_doy);
   return (now_doy >= start_doy || now_doy <= end_doy);
  }

int Strategy_QuarterMonth(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   int q = 4;
   if(dt.day <= 7)
      q = 1;
   else if(dt.day <= 14)
      q = 2;
   else if(dt.day <= 21)
      q = 3;
   return (dt.mon * 10 + q);
  }

bool Strategy_ListContainsQMonth(const string csv, const int qmonth)
  {
   if(StringLen(csv) <= 0)
      return false;
   const string needle = IntegerToString(qmonth);
   string parts[];
   const int n = StringSplit(csv, ',', parts);
   for(int i = 0; i < n; ++i)
     {
      string token = parts[i];
      StringTrimLeft(token);
      StringTrimRight(token);
      if(token == needle)
         return true;
     }
   return false;
  }

bool Strategy_SeasonBlocksEntry(const datetime broker_time)
  {
   if(Strategy_InSeasonWindow(broker_time))
      return true;
   if(strategy_qmonth_matrix_enabled &&
      Strategy_ListContainsQMonth(strategy_block_qmonths, Strategy_QuarterMonth(broker_time)))
      return true;
   return false;
  }

bool Strategy_SeasonForcesExit(const datetime broker_time)
  {
   if(Strategy_InSeasonWindow(broker_time))
      return true;
   if(strategy_qmonth_matrix_enabled &&
      Strategy_ListContainsQMonth(strategy_exit_qmonths, Strategy_QuarterMonth(broker_time)))
      return true;
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const datetime broker_now = TimeCurrent();
   if(!Strategy_HourAllowed(broker_now))
      return true;

   if(strategy_max_spread_points > 0.0)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(ask <= 0.0 || bid <= 0.0 || point <= 0.0 || ask < bid)
         return true;
      if((ask - bid) / point > strategy_max_spread_points)
         return true;
     }

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

   if(strategy_bb_period <= 1 || strategy_bb_deviation <= 0.0 ||
      strategy_trend_ema_period <= 1 || strategy_atr_period <= 0 ||
      strategy_atr_stop_mult <= 0.0 || strategy_min_wick_body_x <= 0.0 ||
      strategy_upper_lower_max_x <= 0.0)
      return false;

   const int warmup = MathMax(strategy_bb_period, MathMax(strategy_trend_ema_period, strategy_atr_period)) + 5;
   if(Bars(_Symbol, strategy_signal_tf) < warmup)
      return false;

   const datetime bar_time = iTime(_Symbol, strategy_signal_tf, 1);
   if(bar_time <= 0)
      return false;
   if(strategy_cooldown_bars > 0 && g_recent_entry_signal_time > 0)
     {
      const int tf_seconds = PeriodSeconds(strategy_signal_tf);
      if(tf_seconds > 0 && (bar_time - g_recent_entry_signal_time) < strategy_cooldown_bars * tf_seconds)
         return false;
     }

   if(Strategy_SeasonBlocksEntry(bar_time))
      return false;

   const double close1 = iClose(_Symbol, strategy_signal_tf, 1);
   const double close3 = iClose(_Symbol, strategy_signal_tf, 3);
   const double open1 = iOpen(_Symbol, strategy_signal_tf, 1);
   const double high1 = iHigh(_Symbol, strategy_signal_tf, 1);
   const double low1 = iLow(_Symbol, strategy_signal_tf, 1);
   if(close1 <= 0.0 || close3 <= 0.0 || open1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0)
      return false;

   const double upper = QM_BB_Upper(_Symbol, strategy_signal_tf, strategy_bb_period, strategy_bb_deviation, 1);
   const double ema = QM_EMA(_Symbol, strategy_signal_tf, strategy_trend_ema_period, 1);
   if(upper <= 0.0 || ema <= 0.0)
      return false;

   const double body = MathAbs(close1 - open1);
   if(body <= 0.0)
      return false;
   const double upper_shadow = high1 - MathMax(open1, close1);
   const double lower_shadow = MathMin(open1, close1) - low1;
   const double total_wick = upper_shadow + lower_shadow;
   if(upper_shadow < 0.0 || lower_shadow < 0.0)
      return false;

   if(close1 <= upper)
      return false;
   if(close1 <= ema)
      return false;
   if(close1 <= close3)
      return false;
   if(total_wick < strategy_min_wick_body_x * body)
      return false;
   if(upper_shadow > strategy_upper_lower_max_x * lower_shadow)
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;
   req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_stop_mult);
   if(req.sl <= 0.0 || req.sl >= entry)
      return false;

   req.reason = "TV_BB_WD_BREAK_LONG";
   g_recent_entry_signal_time = bar_time;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, or add-on logic.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   bool has_position = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      has_position = true;
      break;
     }
   if(!has_position)
      return false;

   const datetime bar_time = iTime(_Symbol, strategy_signal_tf, 1);
   if(bar_time > 0 && Strategy_SeasonForcesExit(bar_time))
      return true;

   const double close1 = iClose(_Symbol, strategy_signal_tf, 1);
   const double lower = QM_BB_Lower(_Symbol, strategy_signal_tf, strategy_bb_period, strategy_bb_deviation, 1);
   if(close1 <= 0.0 || lower <= 0.0)
      return false;
   if(close1 < lower)
      return true;

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(!QM_NewsAllowsTrade2(_Symbol, broker_time, qm_news_temporal, qm_news_compliance))
      return true;
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
