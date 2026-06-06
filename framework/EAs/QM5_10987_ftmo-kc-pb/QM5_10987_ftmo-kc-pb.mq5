#property strict
#property version   "5.0"
#property description "QM5_10987 FTMO Keltner Breakout Pullback"

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
input int    qm_ea_id                   = 10987;
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
// TODO: declare strategy-specific input params here, e.g.:
//   input int    strategy_atr_period   = 14;
//   input double strategy_atr_sl_mult  = 2.0;
//   input double strategy_atr_tp_mult  = 3.0;
input int    strategy_keltner_period        = 20;
input double strategy_keltner_atr_mult      = 2.0;
input int    strategy_pullback_window_bars  = 8;
input double strategy_min_band_tp_rr        = 1.2;
input double strategy_tp_rr_fallback        = 2.0;
input double strategy_max_entry_risk_atr    = 2.5;
input double strategy_be_trigger_r          = 1.0;
input double strategy_trail_trigger_r       = 1.5;
input int    strategy_max_hold_bars         = 48;
input double strategy_spread_median_mult    = 1.5;

double g_strategy_spread_median_points = 0.0;
double g_strategy_two_bar_swing_low = 0.0;
double g_strategy_two_bar_swing_high = 0.0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

bool Strategy_ReadRecentH1(MqlRates &rates[], const int bars_needed)
  {
   if(bars_needed <= 0)
      return false;
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_H1, 0, bars_needed, rates); // perf-allowed: bounded H1 OHLC/spread snapshot inside framework new-bar entry hook.
   return (copied >= bars_needed);
  }

double Strategy_MedianSpread(const MqlRates &rates[], const int first_shift, const int bars)
  {
   if(bars <= 0)
      return 0.0;

   double spreads[];
   ArrayResize(spreads, bars);
   int count = 0;
   for(int i = 0; i < bars; ++i)
     {
      const int idx = first_shift + i;
      const int spread = rates[idx].spread;
      if(spread <= 0)
         continue;
      spreads[count] = (double)spread;
      count++;
     }

   if(count < MathMax(3, bars / 2))
      return 0.0;

   ArrayResize(spreads, count);
   ArraySort(spreads);
   if(count % 2 == 1)
      return spreads[count / 2];
   return 0.5 * (spreads[count / 2 - 1] + spreads[count / 2]);
  }

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // No Trade Filter (time, spread, news): no card time filter; framework handles news.
   if(strategy_spread_median_mult <= 0.0 || g_strategy_spread_median_points <= 0.0)
      return false;

   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0)
      return false;

   return ((double)current_spread > g_strategy_spread_median_points * strategy_spread_median_mult);
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

   static bool long_armed = false;
   static bool short_armed = false;
   static bool long_pullback = false;
   static bool short_pullback = false;
   static int  long_age = 0;
   static int  short_age = 0;

   const ENUM_TIMEFRAMES tf = PERIOD_H1;
   if(strategy_keltner_period <= 0 ||
      strategy_keltner_atr_mult <= 0.0 ||
      strategy_pullback_window_bars <= 0 ||
      strategy_min_band_tp_rr <= 0.0 ||
      strategy_tp_rr_fallback <= 0.0 ||
      strategy_max_entry_risk_atr <= 0.0)
      return false;

   const double ema1 = QM_EMA(_Symbol, tf, strategy_keltner_period, 1);
   const double ema2 = QM_EMA(_Symbol, tf, strategy_keltner_period, 2);
   const double atr1 = QM_ATR(_Symbol, tf, strategy_keltner_period, 1);
   const double atr2 = QM_ATR(_Symbol, tf, strategy_keltner_period, 2);
   if(ema1 <= 0.0 || ema2 <= 0.0 || atr1 <= 0.0 || atr2 <= 0.0)
      return false;

   const double upper1 = ema1 + strategy_keltner_atr_mult * atr1;
   const double lower1 = ema1 - strategy_keltner_atr_mult * atr1;
   const double upper2 = ema2 + strategy_keltner_atr_mult * atr2;
   const double lower2 = ema2 - strategy_keltner_atr_mult * atr2;

   MqlRates rates[];
   if(!Strategy_ReadRecentH1(rates, 22))
      return false;

   g_strategy_spread_median_points = Strategy_MedianSpread(rates, 1, 20);
   g_strategy_two_bar_swing_low = MathMin(rates[1].low, rates[2].low);
   g_strategy_two_bar_swing_high = MathMax(rates[1].high, rates[2].high);

   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(strategy_spread_median_mult > 0.0 &&
      g_strategy_spread_median_points > 0.0 &&
      current_spread > 0 &&
      (double)current_spread > g_strategy_spread_median_points * strategy_spread_median_mult)
      return false;

   const double open1 = rates[1].open;
   const double high1 = rates[1].high;
   const double low1 = rates[1].low;
   const double close1 = rates[1].close;
   const double close2 = rates[2].close;
   if(open1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0 || close2 <= 0.0)
      return false;

   bool enter_long = false;
   bool enter_short = false;

   if(long_armed)
     {
      long_age++;
      if(long_age > strategy_pullback_window_bars || close1 < lower1)
        {
         long_armed = false;
         long_pullback = false;
         long_age = 0;
        }
      else
        {
         if(low1 <= ema1)
            long_pullback = true;
         if(long_pullback && close1 > ema1 && close1 > open1)
            enter_long = true;
        }
     }

   if(short_armed)
     {
      short_age++;
      if(short_age > strategy_pullback_window_bars || close1 > upper1)
        {
         short_armed = false;
         short_pullback = false;
         short_age = 0;
        }
      else
        {
         if(high1 >= ema1)
            short_pullback = true;
         if(short_pullback && close1 < ema1 && close1 < open1)
            enter_short = true;
        }
     }

   if(enter_long || enter_short)
     {
      const bool is_long = enter_long;
      const double entry = is_long ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;

      const double raw_sl = is_long ? lower1 : upper1;
      const double risk = MathAbs(entry - raw_sl);
      if(risk <= 0.0 || risk > strategy_max_entry_risk_atr * atr1)
         return false;

      const double band_target = is_long ? upper1 : lower1;
      const double band_reward = is_long ? (band_target - entry) : (entry - band_target);
      double raw_tp = band_target;
      if(band_reward < strategy_min_band_tp_rr * risk)
         raw_tp = is_long ? (entry + strategy_tp_rr_fallback * risk)
                          : (entry - strategy_tp_rr_fallback * risk);

      req.type = is_long ? QM_BUY : QM_SELL;
      req.price = entry;
      req.sl = QM_TM_NormalizePrice(_Symbol, raw_sl);
      req.tp = QM_TM_NormalizePrice(_Symbol, raw_tp);
      req.reason = is_long ? "QM5_10987_KC_PULLBACK_LONG" : "QM5_10987_KC_PULLBACK_SHORT";

      long_armed = false;
      short_armed = false;
      long_pullback = false;
      short_pullback = false;
      long_age = 0;
      short_age = 0;

      return (req.sl > 0.0 && req.tp > 0.0 &&
              (is_long ? (req.sl < entry && req.tp > entry) : (req.sl > entry && req.tp < entry)));
     }

   if(close2 <= upper2 && close1 > upper1)
     {
      long_armed = true;
      long_pullback = false;
      long_age = 0;
      short_armed = false;
      short_pullback = false;
      short_age = 0;
     }
   else if(close2 >= lower2 && close1 < lower1)
     {
      short_armed = true;
      short_pullback = false;
      short_age = 0;
      long_armed = false;
      long_pullback = false;
      long_age = 0;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   static ulong tracked_ticket = 0;
   static double tracked_risk = 0.0;
   static bool be_done = false;

   const int magic = QM_FrameworkMagic();
   bool found = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      found = true;
      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (position_type == POSITION_TYPE_BUY);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(open_price <= 0.0 || current_sl <= 0.0 || market <= 0.0 || point <= 0.0)
         continue;

      if(tracked_ticket != ticket)
        {
         tracked_ticket = ticket;
         tracked_risk = MathAbs(open_price - current_sl);
         be_done = false;
        }
      if(tracked_risk <= 0.0)
         continue;

      const double favorable = is_buy ? (market - open_price) : (open_price - market);
      if(!be_done && favorable >= strategy_be_trigger_r * tracked_risk)
        {
         const double be_sl = QM_TM_NormalizePrice(_Symbol, open_price);
         const bool improves = is_buy ? (be_sl > current_sl + 0.5 * point)
                                      : (be_sl < current_sl - 0.5 * point);
         if(improves)
            QM_TM_MoveSL(ticket, be_sl, "kc_pullback_breakeven_1r");
         be_done = true;
        }

      if(favorable >= strategy_trail_trigger_r * tracked_risk)
        {
         if(g_strategy_two_bar_swing_low <= 0.0 || g_strategy_two_bar_swing_high <= 0.0)
            continue;

         const double raw_trail = is_buy ? g_strategy_two_bar_swing_low : g_strategy_two_bar_swing_high;
         const double trail_sl = QM_TM_NormalizePrice(_Symbol, raw_trail);
         const bool improves = is_buy ? (trail_sl > current_sl + 0.5 * point && trail_sl < market)
                                      : (trail_sl < current_sl - 0.5 * point && trail_sl > market);
         if(improves)
            QM_TM_MoveSL(ticket, trail_sl, "kc_pullback_two_bar_swing_trail");
        }
     }

   if(!found)
     {
      tracked_ticket = 0;
      tracked_risk = 0.0;
      be_done = false;
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(strategy_max_hold_bars <= 0)
      return false;

   const int hold_seconds = strategy_max_hold_bars * PeriodSeconds(PERIOD_H1);
   if(hold_seconds <= 0)
      return false;

   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && now - opened >= hold_seconds)
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
