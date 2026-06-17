#property strict
#property version   "5.0"
#property description "QM5_11038 atc-imex-time — Time-Point Bulls/Bears IMEX Forecast (H1 cadence, D1 bar-color)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11038 atc-imex-time
// -----------------------------------------------------------------------------
// Source: Vladimir Tsyrulnik, ATC 2010 interview, MQL5 Articles #533.
// Card: artifacts/cards_approved/QM5_11038_atc-imex-time.md (g0_status APPROVED).
//
// Mechanic (H1 signal cadence, forecasts the CURRENT D1 bar color):
//   The source evaluates a "what color will the current Daily0 bar be?" forecast
//   only at a few empirically fixed time-points inside the D1 bar's lifetime
//   (P2 baseline 25% / 50% / 75% of the bar). We run on the H1 timeframe so the
//   framework new-bar gate yields intrabar cadence within the D1 bar, and we gate
//   entry to the H1 bars whose timestamp lands inside a permitted time-point
//   window. One entry attempt per (UTC day, time-point window).
//
//   TIME-OF-DAY DISCIPLINE (build NOTE): the time-points are derived from the
//   BAR TIMESTAMP converted to UTC via QM_BrokerToUTC — never a fixed wall-clock
//   broker assumption. The DXZ D1 bar opens at broker 00:00 (NY-close), so the
//   25/50/75% lifetime fractions = broker 06:00/12:00/18:00. Those map to UTC
//   minutes-of-day (default 360/720/1080 = 06:00/12:00/18:00 UTC, matching the
//   broker NY-close day boundary), so the rule stays DST-robust as the DXZ
//   broker shifts UTC+2/+3 across US DST. Per-symbol windows live in the setfile.
//
//   IMEX index (proprietary formula approximated from the disclosed Bulls/Bears
//   Power logic, per the card R2 note):
//     BullsPower[s] = High[s]  - EMA(close, imex_ma_period)[s]   (Bill Williams)
//     BearsPower[s] = Low[s]   - EMA(close, imex_ma_period)[s]
//     imex = zscore(BullsPower, imex_lookback) - zscore(|BearsPower|, imex_lookback)
//   computed on the closed-bar (shift 1) of the configured SIGNAL timeframe.
//
//   Forecast / entry (one open position per symbol/magic):
//     Long  : imex >  imex_threshold  (bar forecast bullish) AND inside a
//             permitted time-point window AND before the latest-entry cutoff.
//     Short : imex < -imex_threshold  (bar forecast bearish) AND same gates.
//   Stop  : sl_atr_mult * ATR(atr_period, atr_tf).  (P2 SL > TP, per source.)
//   Take  : tp_atr_mult * ATR(atr_period, atr_tf).
//   Reversal (optional): if a later time-point yields the OPPOSITE forecast and
//     enough D1-bar time remains, close the current position (reverse next pass).
//   Spread guard fail-OPEN on .DWX zero modeled spread.
//
//   .DWX invariants honoured: prior CLOSE / EMA on gapless CFDs (no range/gap
//   rule), broker-time sessions via QM_BrokerToUTC, fail-OPEN spread, no swap
//   gate, single QM_IsNewBar consume, no external-macro CSV. Price + bar clock
//   only.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11038;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
// --- Time-points (UTC minutes-of-day, derived from the bar timestamp) ---
// P2 baseline = 25/50/75% of the broker D1 bar lifetime (broker day opens 00:00
// NY-close => 06:00/12:00/18:00 broker). Each window is [tp, tp + tp_window_min).
// A value < 0 disables that slot. On H1 a single bar opens per window.
input int    strategy_tp1_utc_minutes     = 360;    // 06:00 UTC = 25% of D1 bar
input int    strategy_tp2_utc_minutes     = 720;    // 12:00 UTC = 50% of D1 bar
input int    strategy_tp3_utc_minutes     = 1080;   // 18:00 UTC = 75% of D1 bar
input int    strategy_tp_window_min       = 60;     // window width (1 H1 bar)
// Latest-entry cutoff: no NEW entry after this UTC minute-of-day (0.75 of the
// broker D1 lifetime by default). Reversal disabled past this point too.
input int    strategy_latest_entry_utc_minutes = 1080;  // 18:00 UTC = 0.75 of D1

// --- IMEX (Bulls/Bears Power z-score balance) ---
input int    strategy_imex_ma_period      = 13;     // EMA period for Bulls/Bears Power (Bill Williams default)
input int    strategy_imex_lookback       = 34;     // z-score lookback window (bars)
input double strategy_imex_threshold      = 0.50;   // |z-balance| must exceed this to forecast a color

// --- ATR stop / target (on atr_tf) ---
input ENUM_TIMEFRAMES strategy_atr_tf     = PERIOD_D1;  // ATR timeframe (source = daily ATR)
input int    strategy_atr_period          = 14;     // ATR period
input double strategy_sl_atr_mult         = 0.70;   // stop distance = mult * ATR (source: larger SL)
input double strategy_tp_atr_mult         = 0.45;   // target distance = mult * ATR (source: smaller TP)

// --- Reversal & filters ---
input bool   strategy_reversal_enabled    = false;  // close on opposite forecast at a later time-point
input double strategy_spread_pct_of_stop  = 25.0;   // skip if spread > this % of stop distance

// File-scope: one entry attempt per (UTC day, time-point slot). This is a
// per-attempt dedupe (the source forecasts once per permitted time-point), NOT a
// new-bar reimplementation — the framework QM_IsNewBar still gates cadence.
datetime g_last_attempt_day_utc[3] = {0, 0, 0};

// -----------------------------------------------------------------------------
// Bar-clock helpers (all derived from the bar TIMESTAMP in broker time -> UTC)
// -----------------------------------------------------------------------------

// UTC minute-of-day of the last closed bar's open time.
int UtcMinuteOfBarOpen()
  {
   const datetime bar_open_broker = iTime(_Symbol, _Period, 1); // perf-allowed: single closed-bar timestamp
   if(bar_open_broker <= 0)
      return -1;
   const datetime bar_open_utc = QM_BrokerToUTC(bar_open_broker);
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(bar_open_utc, dt);
   return dt.hour * 60 + dt.min;
  }

// UTC calendar day (truncated) of the last closed bar's open time.
datetime UtcDayOfBarOpen()
  {
   const datetime bar_open_broker = iTime(_Symbol, _Period, 1);
   if(bar_open_broker <= 0)
      return 0;
   const datetime bar_open_utc = QM_BrokerToUTC(bar_open_broker);
   return (datetime)((bar_open_utc / 86400) * 86400);
  }

// Index (0..2) of the permitted time-point window the current bar lands in, or
// -1 if outside every window. A negative window start disables that slot.
int ActiveTimePointSlot(const int minute_of_day)
  {
   if(minute_of_day < 0)
      return -1;
   const int tp_start[3] = {strategy_tp1_utc_minutes,
                            strategy_tp2_utc_minutes,
                            strategy_tp3_utc_minutes};
   for(int i = 0; i < 3; ++i)
     {
      const int start = tp_start[i];
      if(start < 0)
         continue;
      if(minute_of_day >= start && minute_of_day < start + strategy_tp_window_min)
         return i;
     }
   return -1;
  }

// IMEX index on the signal (current) timeframe, closed-bar (shift 1) anchored.
// Returns false if any input read is invalid (insufficient history / warmup).
bool ComputeImex(double &imex_out)
  {
   const int n = strategy_imex_lookback;
   if(n < 2)
      return false;

   // Collect BullsPower and |BearsPower| over the lookback window ending at the
   // last closed bar (shifts 1 .. n). Bounded loop (n ~ 34) on a closed-bar path.
   double bulls[];
   double bears_abs[];
   ArrayResize(bulls, n);
   ArrayResize(bears_abs, n);

   for(int k = 0; k < n; ++k)
     {
      const int shift = 1 + k;
      const double ema_k  = QM_EMA(_Symbol, _Period, strategy_imex_ma_period, shift);
      const double high_k = iHigh(_Symbol, _Period, shift); // perf-allowed: closed-bar read
      const double low_k  = iLow(_Symbol, _Period, shift);  // perf-allowed: closed-bar read
      if(ema_k <= 0.0 || high_k <= 0.0 || low_k <= 0.0)
         return false;
      bulls[k]     = high_k - ema_k;          // Bulls Power
      bears_abs[k] = MathAbs(low_k - ema_k);  // |Bears Power|
     }

   double mean_bulls = 0.0, mean_bears = 0.0;
   for(int k = 0; k < n; ++k)
     {
      mean_bulls += bulls[k];
      mean_bears += bears_abs[k];
     }
   mean_bulls /= n;
   mean_bears /= n;

   double var_bulls = 0.0, var_bears = 0.0;
   for(int k = 0; k < n; ++k)
     {
      const double db = bulls[k]     - mean_bulls;
      const double dr = bears_abs[k] - mean_bears;
      var_bulls += db * db;
      var_bears += dr * dr;
     }
   var_bulls /= n;
   var_bears /= n;

   const double sd_bulls = MathSqrt(var_bulls);
   const double sd_bears = MathSqrt(var_bears);
   if(sd_bulls <= 0.0 || sd_bears <= 0.0)
      return false; // flat window — no z-score signal

   // z-score of the most-recent (shift 1) value of each series.
   const double z_bulls = (bulls[0]     - mean_bulls) / sd_bulls;
   const double z_bears = (bears_abs[0] - mean_bears) / sd_bears;

   imex_out = z_bulls - z_bears; // IMEX = Bulls z-balance minus |Bears| z-balance
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only; fail-OPEN on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, strategy_atr_tf, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Time-point IMEX forecast entry. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Time-of-day gate (UTC, derived from the bar timestamp) ---
   const int minute_of_day = UtcMinuteOfBarOpen();
   if(minute_of_day < 0)
      return false;

   // Latest-entry cutoff: no NEW entry past this fraction of the D1 bar.
   if(minute_of_day >= strategy_latest_entry_utc_minutes)
      return false;

   const int slot = ActiveTimePointSlot(minute_of_day);
   if(slot < 0)
      return false; // not at a permitted time-point

   // One attempt per (UTC day, time-point slot). Latch regardless of outcome:
   // the source forecasts once per permitted time-point and does not re-poll.
   const datetime day_utc = UtcDayOfBarOpen();
   if(day_utc == 0 || day_utc == g_last_attempt_day_utc[slot])
      return false;
   g_last_attempt_day_utc[slot] = day_utc;

   // --- IMEX forecast of the current D1 bar color ---
   double imex = 0.0;
   if(!ComputeImex(imex))
      return false;

   QM_OrderType side;
   if(imex > strategy_imex_threshold)
      side = QM_BUY;   // forecast bullish
   else if(imex < -strategy_imex_threshold)
      side = QM_SELL;  // forecast bearish
   else
      return false;    // no decisive forecast

   const double atr_value = QM_ATR(_Symbol, strategy_atr_tf, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double entry = (side == QM_BUY)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr_value, strategy_sl_atr_mult);
   const double tp = QM_TakeATRFromValue(_Symbol, side, entry, atr_value, strategy_tp_atr_mult);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = "atc_imex_time";
   return true;
  }

// No active trade management beyond the fixed ATR stop/target.
void Strategy_ManageOpenPosition()
  {
  }

// Optional reversal exit: at a permitted time-point before the latest-entry
// cutoff, if the IMEX forecast has flipped to oppose the open position, close it.
// SL/TP otherwise handle the exit. Runs once per closed bar (caller gates cadence
// for the entry path; this hook reads cached-cheap closed-bar values).
bool Strategy_ExitSignal()
  {
   if(!strategy_reversal_enabled)
      return false;
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const int minute_of_day = UtcMinuteOfBarOpen();
   if(minute_of_day < 0)
      return false;
   // Disable reversal once the remaining D1-bar time is too short.
   if(minute_of_day >= strategy_latest_entry_utc_minutes)
      return false;
   if(ActiveTimePointSlot(minute_of_day) < 0)
      return false; // only re-decide at a permitted time-point

   double imex = 0.0;
   if(!ComputeImex(imex))
      return false;

   // Determine current open-position direction for this magic.
   const int magic = QM_FrameworkMagic();
   bool is_long = false, is_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)  is_long = true;
      if(ptype == POSITION_TYPE_SELL) is_short = true;
     }

   // Close when the forecast has decisively flipped against the open side.
   if(is_long  && imex < -strategy_imex_threshold)
      return true;
   if(is_short && imex >  strategy_imex_threshold)
      return true;
   return false;
  }

// Defer to the central news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
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
   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
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

   Strategy_ManageOpenPosition();

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
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
        }
     }

   if(!QM_IsNewBar())
      return;

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
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
