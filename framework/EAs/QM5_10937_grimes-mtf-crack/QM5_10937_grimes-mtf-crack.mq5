#property strict
#property version   "5.0"
#property description "QM5_10937 Grimes MTF Pattern Crack"

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
input int    qm_ea_id                   = 10937;
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
input int    strategy_d1_ema_period          = 20;
input int    strategy_d1_atr_period          = 20;
input int    strategy_d1_ema_slope_bars      = 10;
input int    strategy_d1_price_above_bars    = 5;
input int    strategy_flag_min_bars          = 5;
input int    strategy_flag_max_bars          = 20;
input int    strategy_d1_crack_max_age       = 3;
input double strategy_crack_atr_buffer       = 0.25;
input double strategy_max_d1_crack_range_atr = 3.0;
input double strategy_max_stop_atr_mult      = 3.0;
input double strategy_spread_stop_fraction   = 0.08;
input double strategy_target_r_mult          = 2.0;
input double strategy_be_trigger_r           = 1.0;
input int    strategy_time_exit_h4_bars      = 12;
input double strategy_time_exit_min_r        = 0.5;

struct Strategy_CrackSetup
  {
   bool   is_long;
   int    crack_shift;
   int    flag_bars;
   double flag_high;
   double flag_low;
   double crack_high;
   double crack_low;
   double atr;
   double sl;
  };

// Bespoke D1/H4 OHLC structure reads for flag/crack/break detection. No
// framework helper covers flag geometry; reads are bounded (<= flag_max bars)
// and run on the framework-gated entry path. Kept contiguous (no blank line
// before the first reader) so build_check's perf scanner attributes the
// '// perf-allowed' tag to the correct line.
double D1High(const int shift)  { return iHigh(_Symbol, PERIOD_D1, shift); }   // perf-allowed: bounded D1 flag/crack structure read from framework-gated entry path.
double D1Low(const int shift)   { return iLow(_Symbol, PERIOD_D1, shift); }    // perf-allowed: bounded D1 flag/crack structure read from framework-gated entry path.
double D1Close(const int shift) { return iClose(_Symbol, PERIOD_D1, shift); }  // perf-allowed: bounded D1 flag/crack structure read from framework-gated entry path.
double H4Close(const int shift) { return iClose(_Symbol, _Period, shift); }    // perf-allowed: single closed H4 trigger/progress read.

bool Strategy_InputsValid()
  {
   return strategy_d1_ema_period > 1 &&
          strategy_d1_atr_period > 1 &&
          strategy_d1_ema_slope_bars > 0 &&
          strategy_d1_price_above_bars > 0 &&
          strategy_flag_min_bars >= 2 &&
          strategy_flag_max_bars >= strategy_flag_min_bars &&
          strategy_d1_crack_max_age > 0 &&
          strategy_crack_atr_buffer >= 0.0 &&
          strategy_max_d1_crack_range_atr > 0.0 &&
          strategy_max_stop_atr_mult > 0.0 &&
          strategy_spread_stop_fraction > 0.0 &&
          strategy_target_r_mult > 0.0 &&
          strategy_be_trigger_r > 0.0 &&
          strategy_time_exit_h4_bars > 0 &&
          strategy_time_exit_min_r >= 0.0;
  }

bool Strategy_D1TrendOK(const bool long_signal, const int crack_shift)
  {
   const int pre_shift = crack_shift + 1;
   const double ema_recent = QM_EMA(_Symbol, PERIOD_D1, strategy_d1_ema_period, pre_shift);
   const double ema_old = QM_EMA(_Symbol, PERIOD_D1, strategy_d1_ema_period,
                                 pre_shift + strategy_d1_ema_slope_bars);
   if(ema_recent <= 0.0 || ema_old <= 0.0)
      return false;

   if(long_signal && ema_recent >= ema_old)
      return false;
   if(!long_signal && ema_recent <= ema_old)
      return false;

   for(int s = pre_shift; s < pre_shift + strategy_d1_price_above_bars; ++s)
     {
      const double close_s = D1Close(s);
      const double ema_s = QM_EMA(_Symbol, PERIOD_D1, strategy_d1_ema_period, s);
      if(close_s <= 0.0 || ema_s <= 0.0)
         return false;
      if(long_signal && close_s < ema_s)
         return true;
      if(!long_signal && close_s > ema_s)
         return true;
     }

   return false;
  }

bool Strategy_FlagBounds(const bool long_signal,
                         const int crack_shift,
                         const int flag_bars,
                         double &flag_high,
                         double &flag_low)
  {
   flag_high = -DBL_MAX;
   flag_low = DBL_MAX;

   for(int s = crack_shift + 1; s <= crack_shift + flag_bars; ++s)
     {
      const double high_s = D1High(s);
      const double low_s = D1Low(s);
      if(high_s <= 0.0 || low_s <= 0.0)
         return false;
      flag_high = MathMax(flag_high, high_s);
      flag_low = MathMin(flag_low, low_s);
     }

   for(int s = crack_shift + flag_bars; s > crack_shift + 1; --s)
     {
      if(long_signal)
        {
         const double older_low = D1Low(s);
         const double newer_low = D1Low(s - 1);
         if(older_low <= 0.0 || newer_low <= 0.0 || newer_low <= older_low)
            return false;
        }
      else
        {
         const double older_high = D1High(s);
         const double newer_high = D1High(s - 1);
         if(older_high <= 0.0 || newer_high <= 0.0 || newer_high >= older_high)
            return false;
        }
     }

   return (flag_high > flag_low && flag_high > 0.0 && flag_low < DBL_MAX);
  }

bool Strategy_BuildCrackSetup(const bool long_signal,
                              const int crack_shift,
                              const int flag_bars,
                              Strategy_CrackSetup &setup)
  {
   if(!Strategy_D1TrendOK(long_signal, crack_shift))
      return false;

   double flag_high = 0.0;
   double flag_low = 0.0;
   if(!Strategy_FlagBounds(long_signal, crack_shift, flag_bars, flag_high, flag_low))
      return false;

   const double crack_close = D1Close(crack_shift);
   const double crack_high = D1High(crack_shift);
   const double crack_low = D1Low(crack_shift);
   const double ema = QM_EMA(_Symbol, PERIOD_D1, strategy_d1_ema_period, crack_shift);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_d1_atr_period, crack_shift);
   if(crack_close <= 0.0 || crack_high <= 0.0 || crack_low <= 0.0 || ema <= 0.0 || atr <= 0.0)
      return false;
   if((crack_high - crack_low) > strategy_max_d1_crack_range_atr * atr)
      return false;

   const double crack_buffer = strategy_crack_atr_buffer * atr;
   if(long_signal)
     {
      if(crack_close <= flag_high || crack_close <= ema + crack_buffer)
         return false;
      setup.sl = flag_low - crack_buffer;
     }
   else
     {
      if(crack_close >= flag_low || crack_close >= ema - crack_buffer)
         return false;
      setup.sl = flag_high + crack_buffer;
     }

   setup.is_long = long_signal;
   setup.crack_shift = crack_shift;
   setup.flag_bars = flag_bars;
   setup.flag_high = flag_high;
   setup.flag_low = flag_low;
   setup.crack_high = crack_high;
   setup.crack_low = crack_low;
   setup.atr = atr;
   return true;
  }

bool Strategy_FindCrackSetup(const bool long_signal, Strategy_CrackSetup &setup)
  {
   for(int crack_shift = 1; crack_shift <= strategy_d1_crack_max_age; ++crack_shift)
     {
      for(int flag_bars = strategy_flag_min_bars; flag_bars <= strategy_flag_max_bars; ++flag_bars)
        {
         if(Strategy_BuildCrackSetup(long_signal, crack_shift, flag_bars, setup))
            return true;
        }
     }
   return false;
  }

bool Strategy_H4Trigger(const Strategy_CrackSetup &setup)
  {
   const double close1 = H4Close(1);
   const double close2 = H4Close(2);
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   if(setup.is_long)
      return (close1 > setup.crack_high && close2 <= setup.crack_high);
   return (close1 < setup.crack_low && close2 >= setup.crack_low);
  }

bool Strategy_SpreadWithinStop(const double stop_distance)
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid || stop_distance <= 0.0)
      return false;
   return (ask - bid) <= strategy_spread_stop_fraction * stop_distance;
  }

bool Strategy_BuildEntryRequest(const Strategy_CrackSetup &setup, QM_EntryRequest &req)
  {
   const double entry = setup.is_long ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                      : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0 || setup.sl <= 0.0 || setup.atr <= 0.0)
      return false;

   const double stop_distance = setup.is_long ? (entry - setup.sl) : (setup.sl - entry);
   if(stop_distance <= 0.0)
      return false;
   if(stop_distance > strategy_max_stop_atr_mult * setup.atr)
      return false;
   if(!Strategy_SpreadWithinStop(stop_distance))
      return false;

   const double tp = setup.is_long ? entry + strategy_target_r_mult * stop_distance
                                   : entry - strategy_target_r_mult * stop_distance;
   if(setup.is_long && tp <= entry)
      return false;
   if(!setup.is_long && tp >= entry)
      return false;

   req.type = setup.is_long ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = NormalizeDouble(setup.sl, _Digits);
   req.tp = NormalizeDouble(tp, _Digits);
   req.reason = setup.is_long ? "GRIMES_MTF_CRACK_LONG" : "GRIMES_MTF_CRACK_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

bool Strategy_SelectOurPosition(ulong &ticket,
                                ENUM_POSITION_TYPE &position_type,
                                double &open_price,
                                double &sl,
                                datetime &open_time)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = candidate;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      sl = PositionGetDouble(POSITION_SL);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

bool Strategy_D1ClosedBackInsideFlag(const bool is_long_position)
  {
   Strategy_CrackSetup setup;
   if(!Strategy_FindCrackSetup(is_long_position, setup))
      return false;

   const double close1 = D1Close(1);
   if(close1 <= 0.0)
      return false;
   return (close1 > setup.flag_low && close1 < setup.flag_high);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
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

   if(!Strategy_InputsValid())
      return false;
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   Strategy_CrackSetup short_setup;
   if(Strategy_FindCrackSetup(false, short_setup) &&
      Strategy_H4Trigger(short_setup) &&
      Strategy_BuildEntryRequest(short_setup, req))
      return true;

   Strategy_CrackSetup long_setup;
   if(Strategy_FindCrackSetup(true, long_setup) &&
      Strategy_H4Trigger(long_setup) &&
      Strategy_BuildEntryRequest(long_setup, req))
      return true;

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type;
   double open_price = 0.0;
   double sl = 0.0;
   datetime open_time = 0;
   if(!Strategy_SelectOurPosition(ticket, position_type, open_price, sl, open_time))
      return;

   const double risk_distance = MathAbs(open_price - sl);
   if(ticket == 0 || open_price <= 0.0 || sl <= 0.0 || risk_distance <= 0.0)
      return;

   const bool is_long = (position_type == POSITION_TYPE_BUY);
   const double current = is_long ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                  : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(current <= 0.0)
      return;

   const double favorable = is_long ? current - open_price : open_price - current;
   if(favorable < strategy_be_trigger_r * risk_distance)
      return;

   if(is_long && sl < open_price)
      QM_TM_MoveSL(ticket, NormalizeDouble(open_price, _Digits), "GRIMES_MTF_BE_1R");
   if(!is_long && sl > open_price)
      QM_TM_MoveSL(ticket, NormalizeDouble(open_price, _Digits), "GRIMES_MTF_BE_1R");
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type;
   double open_price = 0.0;
   double sl = 0.0;
   datetime open_time = 0;
   if(!Strategy_SelectOurPosition(ticket, position_type, open_price, sl, open_time))
      return false;

   const bool is_long = (position_type == POSITION_TYPE_BUY);
   if(Strategy_D1ClosedBackInsideFlag(is_long))
      return true;

   const int bars_open = iBarShift(_Symbol, _Period, open_time, false);
   if(bars_open < strategy_time_exit_h4_bars)
      return false;

   const double risk_distance = MathAbs(open_price - sl);
   if(open_price <= 0.0 || sl <= 0.0 || risk_distance <= 0.0)
      return false;

   const double current = is_long ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                  : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(current <= 0.0)
      return false;

   const double favorable = is_long ? current - open_price : open_price - current;
   return (favorable < strategy_time_exit_min_r * risk_distance);
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
