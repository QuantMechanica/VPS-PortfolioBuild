#property strict
#property version   "5.0"
#property description "QM5_10210 TradingView Turtle Soup NY Sweep"

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
input int    qm_ea_id                   = 10210;
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
input int    strategy_timeframe_minutes       = 5;
input int    strategy_preopen_start_hhmm_ny   = 0;
input int    strategy_ny_open_hhmm            = 930;
input int    strategy_ny_flat_hhmm            = 1600;
input int    strategy_atr_period              = 14;
input double strategy_stop_atr_buffer         = 0.25;
input double strategy_expansion_atr_mult      = 1.20;
input double strategy_expansion_body_ratio    = 0.60;
input double strategy_retrace_body_fraction   = 0.50;
input int    strategy_max_scan_bars           = 240;
input int    strategy_pending_expiry_minutes  = 120;
input double strategy_max_spread_atr_fraction = 0.20;

int  g_session_key = 0;
bool g_long_taken = false;
bool g_short_taken = false;

ENUM_TIMEFRAMES StrategyTF()
  {
   if(strategy_timeframe_minutes == 15)
      return PERIOD_M15;
   return PERIOD_M5;
  }

datetime BrokerToNewYork(const datetime broker_time)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   return utc + (QM_IsUSDSTUTC(utc) ? -4 * 3600 : -5 * 3600);
  }

int DayKeyNY(const datetime broker_time)
  {
   MqlDateTime t;
   TimeToStruct(BrokerToNewYork(broker_time), t);
   return t.year * 10000 + t.mon * 100 + t.day;
  }

int HhmmNY(const datetime broker_time)
  {
   MqlDateTime t;
   TimeToStruct(BrokerToNewYork(broker_time), t);
   return t.hour * 100 + t.min;
  }

void ResetSessionIfNeeded(const datetime broker_time)
  {
   const int key = DayKeyNY(broker_time);
   if(key == g_session_key)
      return;
   g_session_key = key;
   g_long_taken = false;
   g_short_taken = false;
  }

bool HasOpenStrategyPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

bool SessionReferenceRange(const datetime signal_time, double &ref_high, double &ref_low)
  {
   ref_high = -DBL_MAX;
   ref_low = DBL_MAX;
   const int signal_day = DayKeyNY(signal_time);
   const ENUM_TIMEFRAMES tf = StrategyTF();
   const int bars = MathMax(30, strategy_max_scan_bars);

   for(int shift = 1; shift <= bars; ++shift)
     {
      const datetime bt = iTime(_Symbol, tf, shift);
      if(bt <= 0)
         break;
      if(DayKeyNY(bt) != signal_day)
         continue;
      const int hhmm = HhmmNY(bt);
      if(hhmm < strategy_preopen_start_hhmm_ny || hhmm >= strategy_ny_open_hhmm)
         continue;

      const double high = iHigh(_Symbol, tf, shift);
      const double low = iLow(_Symbol, tf, shift);
      if(high <= 0.0 || low <= 0.0)
         continue;
      ref_high = MathMax(ref_high, high);
      ref_low = MathMin(ref_low, low);
     }

   return (ref_high > ref_low && ref_low < DBL_MAX);
  }

bool SweepExtremesSinceOpen(const datetime signal_time,
                            const double ref_high,
                            const double ref_low,
                            double &sweep_high,
                            double &sweep_low)
  {
   sweep_high = 0.0;
   sweep_low = 0.0;
   const int signal_day = DayKeyNY(signal_time);
   const ENUM_TIMEFRAMES tf = StrategyTF();
   const int bars = MathMax(30, strategy_max_scan_bars);

   for(int shift = 1; shift <= bars; ++shift)
     {
      const datetime bt = iTime(_Symbol, tf, shift);
      if(bt <= 0)
         break;
      if(DayKeyNY(bt) != signal_day)
         continue;
      const int hhmm = HhmmNY(bt);
      if(hhmm < strategy_ny_open_hhmm || hhmm > HhmmNY(signal_time))
         continue;

      const double high = iHigh(_Symbol, tf, shift);
      const double low = iLow(_Symbol, tf, shift);
      if(high > ref_high)
         sweep_high = MathMax(sweep_high, high);
      if(low < ref_low)
         sweep_low = (sweep_low <= 0.0) ? low : MathMin(sweep_low, low);
     }

   return (sweep_high > 0.0 || sweep_low > 0.0);
  }

bool ExpansionCandle(const int dir,
                     const double open1,
                     const double high1,
                     const double low1,
                     const double close1,
                     const double atr)
  {
   const double range = high1 - low1;
   const double body = MathAbs(close1 - open1);
   if(range <= 0.0 || body <= 0.0 || atr <= 0.0)
      return false;
   if(body < strategy_expansion_atr_mult * atr && body < strategy_expansion_body_ratio * range)
      return false;
   if(dir > 0)
      return (close1 > open1);
   return (close1 < open1);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const double atr = QM_ATR(_Symbol, StrategyTF(), strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;
   return ((ask - bid) > strategy_max_spread_atr_fraction * atr);
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

   const ENUM_TIMEFRAMES tf = StrategyTF();
   const datetime bar_time = iTime(_Symbol, tf, 1);
   if(bar_time <= 0)
      return false;

   ResetSessionIfNeeded(bar_time);
   if(HasOpenStrategyPosition())
      return false;

   const int hhmm = HhmmNY(bar_time);
   if(hhmm < strategy_ny_open_hhmm || hhmm >= strategy_ny_flat_hhmm)
      return false;

   const double open1 = iOpen(_Symbol, tf, 1);
   const double high1 = iHigh(_Symbol, tf, 1);
   const double low1 = iLow(_Symbol, tf, 1);
   const double close1 = iClose(_Symbol, tf, 1);
   const double atr = QM_ATR(_Symbol, tf, strategy_atr_period, 1);
   if(open1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0 || atr <= 0.0)
      return false;

   double ref_high = 0.0;
   double ref_low = 0.0;
   if(!SessionReferenceRange(bar_time, ref_high, ref_low))
      return false;

   double sweep_high = 0.0;
   double sweep_low = 0.0;
   if(!SweepExtremesSinceOpen(bar_time, ref_high, ref_low, sweep_high, sweep_low))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(!g_long_taken &&
      sweep_low > 0.0 &&
      low1 <= ref_low &&
      close1 > ref_low &&
      ExpansionCandle(1, open1, high1, low1, close1, atr))
     {
      const double retrace = NormalizeDouble(open1 + strategy_retrace_body_fraction * (close1 - open1), _Digits);
      const double sl = NormalizeDouble(sweep_low - strategy_stop_atr_buffer * atr, _Digits);
      const double entry = (ask <= retrace) ? ask : retrace;
      if(entry <= sl || ref_high <= entry)
         return false;

      req.type = (ask <= retrace) ? QM_BUY : QM_BUY_LIMIT;
      req.price = (req.type == QM_BUY) ? 0.0 : retrace;
      req.sl = sl;
      req.tp = NormalizeDouble(ref_high, _Digits);
      req.reason = "TV_TURTLE_NY_SWEEP_LONG";
      req.expiration_seconds = MathMax(1, strategy_pending_expiry_minutes) * 60;
      g_long_taken = true;
      return true;
     }

   if(!g_short_taken &&
      sweep_high > 0.0 &&
      high1 >= ref_high &&
      close1 < ref_high &&
      ExpansionCandle(-1, open1, high1, low1, close1, atr))
     {
      const double retrace = NormalizeDouble(open1 - strategy_retrace_body_fraction * (open1 - close1), _Digits);
      const double sl = NormalizeDouble(sweep_high + strategy_stop_atr_buffer * atr, _Digits);
      const double entry = (bid >= retrace) ? bid : retrace;
      if(entry >= sl || ref_low >= entry)
         return false;

      req.type = (bid >= retrace) ? QM_SELL : QM_SELL_LIMIT;
      req.price = (req.type == QM_SELL) ? 0.0 : retrace;
      req.sl = sl;
      req.tp = NormalizeDouble(ref_low, _Digits);
      req.reason = "TV_TURTLE_NY_SWEEP_SHORT";
      req.expiration_seconds = MathMax(1, strategy_pending_expiry_minutes) * 60;
      g_short_taken = true;
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card baseline: no trailing, partial close, or break-even rule.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(!HasOpenStrategyPosition())
      return false;
   return (HhmmNY(TimeCurrent()) >= strategy_ny_flat_hhmm);
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
