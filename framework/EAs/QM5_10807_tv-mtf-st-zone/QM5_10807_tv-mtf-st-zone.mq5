#property strict
#property version   "5.0"
#property description "QM5_10807 TradingView MTF SuperTrend Pullback Zone"

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
input int    qm_ea_id                   = 10807;
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
input ENUM_TIMEFRAMES strategy_entry_tf             = PERIOD_CURRENT;
input ENUM_TIMEFRAMES strategy_confirm_tf_1         = PERIOD_H1;
input ENUM_TIMEFRAMES strategy_confirm_tf_2         = PERIOD_H4;
input int             strategy_supertrend_period    = 10;
input double          strategy_supertrend_mult      = 3.0;
input int             strategy_supertrend_warmup    = 160;
input int             strategy_ema_period           = 200;
input int             strategy_ema_slope_bars       = 20;
input int             strategy_atr_period           = 14;
input double          strategy_pullback_atr_mult    = 0.5;
input double          strategy_body_threshold       = 0.60;
input int             strategy_swing_lookback_bars  = 5;
input double          strategy_stop_atr_mult        = 1.5;
input double          strategy_target_rr            = 2.0;

int  g_cached_zone = 0;
bool g_cached_zone_valid = false;

ENUM_TIMEFRAMES Strategy_EntryTF()
  {
   return (strategy_entry_tf == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)_Period : strategy_entry_tf;
  }

bool Strategy_HasOpenPosition(ENUM_POSITION_TYPE &ptype)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }
   return false;
  }

bool Strategy_ReadBar(const ENUM_TIMEFRAMES tf, const int shift, MqlRates &bar)
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, tf, shift, 1, rates) != 1) // perf-allowed: single closed-bar OHLC read for candle structure in framework new-bar path.
      return false;
   bar = rates[0];
   return (bar.high > 0.0 && bar.low > 0.0 && bar.close > 0.0 && bar.high >= bar.low);
  }

int Strategy_SupertrendDirection(const ENUM_TIMEFRAMES tf)
  {
   if(strategy_supertrend_period <= 0 || strategy_supertrend_mult <= 0.0)
      return 0;

   const int bars_needed = MathMax(strategy_supertrend_warmup, strategy_supertrend_period + 10);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, tf, 1, bars_needed, rates); // perf-allowed: bounded closed-bar SuperTrend OHLC reconstruction; no framework SuperTrend helper exists.
   if(copied < strategy_supertrend_period + 5)
      return 0;

   double prev_final_upper = 0.0;
   double prev_final_lower = 0.0;
   int prev_dir = 0;

   for(int i = copied - 1; i >= 0; --i)
     {
      const int shift = i + 1;
      const double high = rates[i].high;
      const double low = rates[i].low;
      const double close = rates[i].close;
      const double prev_close = (i == copied - 1) ? close : rates[i + 1].close;
      const double atr = QM_ATR(_Symbol, tf, strategy_supertrend_period, shift);
      if(high <= 0.0 || low <= 0.0 || close <= 0.0 || atr <= 0.0 || high < low)
         return 0;

      const double mid = (high + low) * 0.5;
      const double basic_upper = mid + strategy_supertrend_mult * atr;
      const double basic_lower = mid - strategy_supertrend_mult * atr;
      double final_upper = basic_upper;
      double final_lower = basic_lower;
      int dir = prev_dir;

      if(prev_dir == 0)
         dir = (close >= mid) ? 1 : -1;
      else
        {
         final_upper = (basic_upper < prev_final_upper || prev_close > prev_final_upper)
                       ? basic_upper : prev_final_upper;
         final_lower = (basic_lower > prev_final_lower || prev_close < prev_final_lower)
                       ? basic_lower : prev_final_lower;

         if(prev_dir < 0 && close > final_upper)
            dir = 1;
         else if(prev_dir > 0 && close < final_lower)
            dir = -1;
        }

      prev_final_upper = final_upper;
      prev_final_lower = final_lower;
      prev_dir = dir;
     }

   return prev_dir;
  }

int Strategy_Zone()
  {
   const ENUM_TIMEFRAMES entry_tf = Strategy_EntryTF();
   MqlRates bar1;
   if(!Strategy_ReadBar(entry_tf, 1, bar1))
      return 0;

   const double ema_1 = QM_EMA(_Symbol, entry_tf, strategy_ema_period, 1, PRICE_CLOSE);
   const double ema_old = QM_EMA(_Symbol, entry_tf, strategy_ema_period, 1 + strategy_ema_slope_bars, PRICE_CLOSE);
   if(ema_1 <= 0.0 || ema_old <= 0.0)
      return 0;

   const int st_entry = Strategy_SupertrendDirection(entry_tf);
   const int st_tf1 = Strategy_SupertrendDirection(strategy_confirm_tf_1);
   const int st_tf2 = Strategy_SupertrendDirection(strategy_confirm_tf_2);
   if(st_entry > 0 && st_tf1 > 0 && st_tf2 > 0 && bar1.close > ema_1 && ema_1 > ema_old)
      return 1;
   if(st_entry < 0 && st_tf1 < 0 && st_tf2 < 0 && bar1.close < ema_1 && ema_1 < ema_old)
      return -1;
   return 0;
  }

bool Strategy_CandleConfirms(const int dir)
  {
   const ENUM_TIMEFRAMES tf = Strategy_EntryTF();
   MqlRates bar1;
   MqlRates bar2;
   if(!Strategy_ReadBar(tf, 1, bar1) || !Strategy_ReadBar(tf, 2, bar2))
      return false;

   const double range = bar1.high - bar1.low;
   const double body = MathAbs(bar1.close - bar1.open);
   if(range <= 0.0 || body / range < strategy_body_threshold)
      return false;

   if(dir > 0)
      return (bar1.close > bar1.open && bar1.high > bar2.high);
   if(dir < 0)
      return (bar1.close < bar1.open && bar1.low < bar2.low);
   return false;
  }

bool Strategy_PullbackToEMA(const int dir)
  {
   const ENUM_TIMEFRAMES tf = Strategy_EntryTF();
   MqlRates bar1;
   if(!Strategy_ReadBar(tf, 1, bar1))
      return false;

   const double ema = QM_EMA(_Symbol, tf, strategy_ema_period, 1, PRICE_CLOSE);
   const double atr = QM_ATR(_Symbol, tf, strategy_atr_period, 1);
   if(ema <= 0.0 || atr <= 0.0 || strategy_pullback_atr_mult <= 0.0)
      return false;

   const double tolerance = strategy_pullback_atr_mult * atr;
   if(dir > 0)
      return (bar1.low <= ema + tolerance && bar1.close >= ema);
   if(dir < 0)
      return (bar1.high >= ema - tolerance && bar1.close <= ema);
   return false;
  }

bool Strategy_SwingExtreme(double &lowest, double &highest)
  {
   lowest = DBL_MAX;
   highest = -DBL_MAX;
   if(strategy_swing_lookback_bars <= 0)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, Strategy_EntryTF(), 1, strategy_swing_lookback_bars, rates); // perf-allowed: bounded pullback swing-low/high reconstruction in framework new-bar path.
   if(copied < 1)
      return false;

   for(int i = 0; i < copied; ++i)
     {
      if(rates[i].low > 0.0 && rates[i].low < lowest)
         lowest = rates[i].low;
      if(rates[i].high > 0.0 && rates[i].high > highest)
         highest = rates[i].high;
     }

   return (lowest < DBL_MAX && highest > 0.0);
  }

double Strategy_NormalizePrice(const double price)
  {
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   return NormalizeDouble(price, digits);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // Mixed M15/H1/H4 alignment is enforced inside Strategy_EntrySignal so
   // this hook never suppresses an opposite-zone exit for an open position.
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

   const int zone = Strategy_Zone();
   g_cached_zone = zone;
   g_cached_zone_valid = true;
   if(zone == 0)
      return false;

   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   if(Strategy_HasOpenPosition(ptype))
      return false;

   if(!Strategy_PullbackToEMA(zone) || !Strategy_CandleConfirms(zone))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double atr = QM_ATR(_Symbol, Strategy_EntryTF(), strategy_atr_period, 1);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0 || atr <= 0.0 ||
      strategy_stop_atr_mult <= 0.0 || strategy_target_rr <= 0.0)
      return false;

   double swing_low = 0.0;
   double swing_high = 0.0;
   if(!Strategy_SwingExtreme(swing_low, swing_high))
      return false;

   const double entry = (zone > 0) ? ask : bid;
   const QM_OrderType side = (zone > 0) ? QM_BUY : QM_SELL;
   double stop = 0.0;
   if(zone > 0)
      stop = MathMin(swing_low, entry - strategy_stop_atr_mult * atr);
   else
      stop = MathMax(swing_high, entry + strategy_stop_atr_mult * atr);
   stop = Strategy_NormalizePrice(stop);
   if(stop <= 0.0)
      return false;

   const double sl_points = MathAbs(entry - stop) / point;
   if(sl_points <= 0.0 || QM_LotsForRisk(_Symbol, sl_points) <= 0.0)
      return false;

   const double take = QM_TakeRR(_Symbol, side, entry, stop, strategy_target_rr);
   if(take <= 0.0)
      return false;

   req.type = side;
   req.sl = stop;
   req.tp = take;
   req.reason = (zone > 0) ? "MTF_ST_ZONE_LONG" : "MTF_ST_ZONE_SHORT";
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
   if(!g_cached_zone_valid || g_cached_zone == 0)
      return false;

   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   if(!Strategy_HasOpenPosition(ptype))
      return false;

   if(ptype == POSITION_TYPE_BUY && g_cached_zone < 0)
      return true;
   if(ptype == POSITION_TYPE_SELL && g_cached_zone > 0)
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
