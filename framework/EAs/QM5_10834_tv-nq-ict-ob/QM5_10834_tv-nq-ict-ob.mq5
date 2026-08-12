#property strict
#property version   "5.0"
#property description "QM5_10834 TradingView NQ ICT Order Block Sweep"

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
input int    qm_ea_id                   = 10834;
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
enum StrategyBiasMode
  {
   BIAS_CURRENT_PRICE = 0,
   BIAS_PREVIOUS_DAILY_CLOSE = 1
  };

enum StrategyOBRefinement
  {
   OB_DEFENSIVE_ATR55 = 0,
   OB_AGGRESSIVE_FULL = 1,
   OB_FULL_CANDLE = 2
  };

enum StrategySetupPhase
  {
   SETUP_WAIT_SWEEP = 0,
   SETUP_WAIT_MSS = 1,
   SETUP_WAIT_MITIGATION = 2,
   SETUP_DONE = 3
  };

input int                  strategy_entry_start_hhmm  = 945;
input int                  strategy_entry_end_hhmm    = 1015;
input int                  strategy_daily_ema_period  = 20;
input StrategyBiasMode     strategy_bias_mode         = BIAS_CURRENT_PRICE;
input int                  strategy_fractal_width     = 5;
input int                  strategy_fractal_lookback  = 60;
input int                  strategy_ob_lookback       = 20;
input StrategyOBRefinement strategy_ob_refinement     = OB_DEFENSIVE_ATR55;
input int                  strategy_ob_refine_atr_period = 55;
input int                  strategy_atr_period        = 14;
input double               strategy_min_stop_atr      = 0.25;
input double               strategy_max_stop_atr      = 2.0;
input double               strategy_target_r          = 2.0;
input int                  strategy_max_spread_points = 0;

int    g_ny_day_key = 0;
bool   g_trade_taken_today = false;
bool   g_trade_history_ready = false;
bool   g_daily_levels_ready = false;
double g_previous_day_high = 0.0;
double g_previous_day_low = 0.0;
datetime g_previous_day_bar_time = 0;
StrategySetupPhase g_bull_phase = SETUP_WAIT_SWEEP;
StrategySetupPhase g_bear_phase = SETUP_WAIT_SWEEP;
datetime g_bull_sweep_bar_time = 0;
datetime g_bear_sweep_bar_time = 0;
datetime g_bull_mss_bar_time = 0;
datetime g_bear_mss_bar_time = 0;
double g_bull_ob_low = 0.0;
double g_bull_ob_high = 0.0;
double g_bear_ob_low = 0.0;
double g_bear_ob_high = 0.0;

int HHMMToMinutes(const int hhmm)
  {
   const int hour = hhmm / 100;
   const int minute = hhmm % 100;
   return hour * 60 + minute;
  }

datetime BrokerToNewYork(const datetime broker_time)
  {
   const datetime utc_time = QM_BrokerToUTC(broker_time);
   const int offset_hours = QM_IsUSDSTUTC(utc_time) ? -4 : -5;
   return utc_time + offset_hours * 3600;
  }

int NYDayKey(const datetime broker_time)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(BrokerToNewYork(broker_time), dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int NYMinutes(const datetime broker_time)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(BrokerToNewYork(broker_time), dt);
   return dt.hour * 60 + dt.min;
  }

bool TryRestoreTradeState(bool &trade_seen)
  {
   trade_seen = false;
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   if(magic <= 0 || now <= 0)
      return false;
   if(!HistorySelect(now - 7 * 86400, now))
      return false;

   const int total = HistoryDealsTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol)
         continue;
      if((int)HistoryDealGetInteger(ticket, DEAL_MAGIC) != magic)
         continue;
      const long entry_kind = HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry_kind != DEAL_ENTRY_IN && entry_kind != DEAL_ENTRY_INOUT)
         continue;
      const datetime deal_time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
      if(NYDayKey(deal_time) != g_ny_day_key)
         continue;
      trade_seen = true;
      return true;
     }

   return true;
  }

bool TrySnapshotPreviousDayLevels()
  {
   const datetime bar_time = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: once-per-NY-day D1 snapshot.
   const double high = iHigh(_Symbol, PERIOD_D1, 1); // perf-allowed: once-per-NY-day D1 snapshot.
   const double low = iLow(_Symbol, PERIOD_D1, 1); // perf-allowed: once-per-NY-day D1 snapshot.
   if(bar_time <= 0 || bar_time >= TimeCurrent() || high <= 0.0 || low <= 0.0 || high <= low)
      return false;

   g_previous_day_bar_time = bar_time;
   g_previous_day_high = high;
   g_previous_day_low = low;
   return true;
  }

void ResetDailySetupState()
  {
   g_trade_taken_today = false;
   g_trade_history_ready = false;
   g_daily_levels_ready = false;
   g_previous_day_high = 0.0;
   g_previous_day_low = 0.0;
   g_previous_day_bar_time = 0;
   g_bull_phase = SETUP_WAIT_SWEEP;
   g_bear_phase = SETUP_WAIT_SWEEP;
   g_bull_sweep_bar_time = 0;
   g_bear_sweep_bar_time = 0;
   g_bull_mss_bar_time = 0;
   g_bear_mss_bar_time = 0;
   g_bull_ob_low = 0.0;
   g_bull_ob_high = 0.0;
   g_bear_ob_low = 0.0;
   g_bear_ob_high = 0.0;
  }

void RefreshNYDayState()
  {
   const int day_key = NYDayKey(TimeCurrent());
   if(day_key != g_ny_day_key)
     {
      g_ny_day_key = day_key;
      ResetDailySetupState();
     }

   if(!g_daily_levels_ready)
      g_daily_levels_ready = TrySnapshotPreviousDayLevels();

   if(!g_trade_history_ready)
     {
      bool trade_seen = false;
      if(TryRestoreTradeState(trade_seen))
        {
         g_trade_taken_today = trade_seen;
         g_trade_history_ready = true;
         if(trade_seen)
           {
            g_bull_phase = SETUP_DONE;
            g_bear_phase = SETUP_DONE;
           }
        }
     }
  }

bool InEntryWindowAt(const datetime broker_time)
  {
   const int minutes = NYMinutes(broker_time);
   return (minutes >= HHMMToMinutes(strategy_entry_start_hhmm) &&
           minutes < HHMMToMinutes(strategy_entry_end_hhmm));
  }

bool InEntryWindow()
  {
   return InEntryWindowAt(TimeCurrent());
  }

bool EntryWindowEnded()
  {
   return (NYMinutes(TimeCurrent()) >= HHMMToMinutes(strategy_entry_end_hhmm));
  }

bool HasOurOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }

   return false;
  }

bool SpreadAllowed()
  {
   if(strategy_max_spread_points <= 0)
      return true;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   return ((ask - bid) / point <= strategy_max_spread_points);
  }

bool TryDailyBias(bool &bullish)
  {
   bullish = false;
   const double ema = QM_EMA(_Symbol, PERIOD_D1, strategy_daily_ema_period, 1);
   if(ema <= 0.0)
      return false;

   double ref_price = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, 1); // perf-allowed: bespoke ICT bias uses closed-bar price.
   if(strategy_bias_mode == BIAS_PREVIOUS_DAILY_CLOSE)
      ref_price = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: card requires previous daily close bias option.
   if(ref_price <= 0.0)
      return false;

   bullish = (ref_price > ema);
   return true;
  }

bool IsFractalHigh(const int shift, const int wing)
  {
   const double center = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, shift); // perf-allowed: bespoke 5-bar MSS fractal.
   if(center <= 0.0)
      return false;

   for(int j = 1; j <= wing; ++j)
     {
      if(center <= iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, shift - j)) // perf-allowed: bounded fractal window.
         return false;
      if(center <= iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, shift + j)) // perf-allowed: bounded fractal window.
         return false;
     }

   return true;
  }

bool IsFractalLow(const int shift, const int wing)
  {
   const double center = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, shift); // perf-allowed: bespoke 5-bar MSS fractal.
   if(center <= 0.0)
      return false;

   for(int j = 1; j <= wing; ++j)
     {
      if(center >= iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, shift - j)) // perf-allowed: bounded fractal window.
         return false;
      if(center >= iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, shift + j)) // perf-allowed: bounded fractal window.
         return false;
     }

   return true;
  }

double LastFractalHigh(const int width, const int lookback)
  {
   const int wing = MathMax(1, width / 2);
   for(int shift = wing + 1; shift <= lookback; ++shift)
      if(IsFractalHigh(shift, wing))
         return iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, shift); // perf-allowed: returns bounded structural level.
   return 0.0;
  }

double LastFractalLow(const int width, const int lookback)
  {
   const int wing = MathMax(1, width / 2);
   for(int shift = wing + 1; shift <= lookback; ++shift)
      if(IsFractalLow(shift, wing))
         return iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, shift); // perf-allowed: returns bounded structural level.
   return 0.0;
  }

bool RefinedOBLevels(const int shift,
                     const bool bullish,
                     const double refine_atr,
                     double &ob_low,
                     double &ob_high)
  {
   const double open = iOpen(_Symbol, (ENUM_TIMEFRAMES)_Period, shift); // perf-allowed: card-defined order-block candle.
   const double high = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, shift); // perf-allowed: card-defined order-block candle.
   const double low = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, shift); // perf-allowed: card-defined order-block candle.
   const double close = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, shift); // perf-allowed: card-defined order-block candle.
   if(open <= 0.0 || high <= 0.0 || low <= 0.0 || close <= 0.0 || high <= low)
      return false;

   if(strategy_ob_refinement == OB_FULL_CANDLE ||
      strategy_ob_refinement == OB_AGGRESSIVE_FULL)
     {
      ob_low = low;
      ob_high = high;
      return (ob_low < ob_high);
     }

   if(refine_atr <= 0.0)
      return false;

   const double candle_range = high - low;
   if(candle_range <= refine_atr * 0.5)
     {
      ob_low = low;
      ob_high = high;
     }
   else if(bullish)
     {
      // Public Pine v1: defensive bullish OB is low-to-close for a
      // bearish source candle once its range exceeds 0.5*ATR(55).
      ob_low = low;
      ob_high = close;
     }
   else
     {
      // Public Pine v1: defensive bearish OB is close-to-high for a
      // bullish source candle once its range exceeds 0.5*ATR(55).
      ob_low = close;
      ob_high = high;
     }
   return (ob_low < ob_high);
  }

bool FindLastOppositeOrderBlock(const bool bullish,
                                const double refine_atr,
                                double &ob_low,
                                double &ob_high)
  {
   for(int shift = 2; shift <= strategy_ob_lookback; ++shift)
     {
      const double open = iOpen(_Symbol, (ENUM_TIMEFRAMES)_Period, shift); // perf-allowed: bounded search for last opposite candle.
      const double close = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, shift); // perf-allowed: bounded search for last opposite candle.
      if(open <= 0.0 || close <= 0.0)
         continue;

      if(bullish && close < open)
         return RefinedOBLevels(shift, true, refine_atr, ob_low, ob_high);
      if(!bullish && close > open)
         return RefinedOBLevels(shift, false, refine_atr, ob_low, ob_high);
     }

   return false;
  }

bool StopDistanceAllowed(const double entry, const double sl)
  {
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0 || entry <= 0.0 || sl <= 0.0)
      return false;

   const double stop_dist = MathAbs(entry - sl);
   return (stop_dist >= strategy_min_stop_atr * atr &&
           stop_dist <= strategy_max_stop_atr * atr);
  }

void InitRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   RefreshNYDayState();

   if(HasOurOpenPosition())
      return false;

   if(!g_trade_history_ready || !g_daily_levels_ready || g_trade_taken_today)
      return true;

   if(!InEntryWindow())
      return true;

   if(!SpreadAllowed())
      return true;

   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   InitRequest(req);
   RefreshNYDayState();

   if(g_trade_taken_today || !g_trade_history_ready || !g_daily_levels_ready)
      return false;

   const datetime bar_time = iTime(_Symbol, (ENUM_TIMEFRAMES)_Period, 1); // perf-allowed: closed signal-bar session binding.
   if(bar_time <= 0 || bar_time <= g_previous_day_bar_time || !InEntryWindowAt(bar_time))
      return false;

   const double high1 = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, 1); // perf-allowed: current closed bar sweep check.
   const double low1 = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, 1); // perf-allowed: current closed bar sweep check.
   const double close1 = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, 1); // perf-allowed: current closed bar sweep/MSS/mitigation check.
   const double close2 = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, 2); // perf-allowed: fresh-cross confirmation.
   if(high1 <= 0.0 || low1 <= 0.0 || high1 < low1 || close1 <= 0.0 || close2 <= 0.0)
      return false;

   bool bullish_bias = false;
   if(!TryDailyBias(bullish_bias))
      return false;

   // The three setup events are intentionally distinct closed bars. This
   // removes the unknowable intrabar order that the public Pine OHLC logic
   // otherwise permits when sweep, MSS and mitigation share one candle.
   if(g_bull_phase == SETUP_WAIT_SWEEP &&
      low1 < g_previous_day_low && close1 > g_previous_day_low)
     {
      g_bull_phase = SETUP_WAIT_MSS;
      g_bull_sweep_bar_time = bar_time;
     }
   if(g_bear_phase == SETUP_WAIT_SWEEP &&
      high1 > g_previous_day_high && close1 < g_previous_day_high)
     {
      g_bear_phase = SETUP_WAIT_MSS;
      g_bear_sweep_bar_time = bar_time;
     }

   const double swing_high = LastFractalHigh(strategy_fractal_width, strategy_fractal_lookback);
   const double swing_low = LastFractalLow(strategy_fractal_width, strategy_fractal_lookback);

   if(g_bull_phase == SETUP_WAIT_MSS && bar_time > g_bull_sweep_bar_time &&
      bullish_bias && swing_high > 0.0 && close1 > swing_high && close2 <= swing_high)
     {
      const double refine_atr = QM_ATR(_Symbol,
                                       (ENUM_TIMEFRAMES)_Period,
                                       strategy_ob_refine_atr_period,
                                       1);
      double ob_low = 0.0;
      double ob_high = 0.0;
      if(refine_atr > 0.0 && FindLastOppositeOrderBlock(true, refine_atr, ob_low, ob_high))
        {
         g_bull_ob_low = ob_low;
         g_bull_ob_high = ob_high;
         g_bull_mss_bar_time = bar_time;
         g_bull_phase = SETUP_WAIT_MITIGATION;
        }
      else
         g_bull_phase = SETUP_DONE;
     }

   if(g_bear_phase == SETUP_WAIT_MSS && bar_time > g_bear_sweep_bar_time &&
      !bullish_bias && swing_low > 0.0 && close1 < swing_low && close2 >= swing_low)
     {
      const double refine_atr = QM_ATR(_Symbol,
                                       (ENUM_TIMEFRAMES)_Period,
                                       strategy_ob_refine_atr_period,
                                       1);
      double ob_low = 0.0;
      double ob_high = 0.0;
      if(refine_atr > 0.0 && FindLastOppositeOrderBlock(false, refine_atr, ob_low, ob_high))
        {
         g_bear_ob_low = ob_low;
         g_bear_ob_high = ob_high;
         g_bear_mss_bar_time = bar_time;
         g_bear_phase = SETUP_WAIT_MITIGATION;
        }
      else
         g_bear_phase = SETUP_DONE;
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(g_bull_phase == SETUP_WAIT_MITIGATION && bar_time > g_bull_mss_bar_time)
     {
      // Pine invalidates a bullish OB once price has already crossed its
      // opposite side. Do this before considering an entry on the bar.
      if(low1 <= g_bull_ob_low)
         g_bull_phase = SETUP_DONE;
      else if(bullish_bias && low1 <= g_bull_ob_high && close1 >= g_bull_ob_low)
        {
         const double entry = ask;
         const double sl = g_bull_ob_low;
         if(sl <= 0.0 || sl >= entry || !StopDistanceAllowed(entry, sl))
            return false;

         const double risk = entry - sl;
         req.type = QM_BUY;
         req.price = 0.0;
         req.sl = sl;
         req.tp = entry + strategy_target_r * risk;
         req.reason = "TV_NQ_ICT_OB_LONG";
         return true;
        }
     }

   if(g_bear_phase == SETUP_WAIT_MITIGATION && bar_time > g_bear_mss_bar_time)
     {
      if(high1 >= g_bear_ob_high)
         g_bear_phase = SETUP_DONE;
      else if(!bullish_bias && high1 >= g_bear_ob_low && close1 <= g_bear_ob_high)
        {
         const double entry = bid;
         const double sl = g_bear_ob_high;
         if(sl <= 0.0 || sl <= entry || !StopDistanceAllowed(entry, sl))
            return false;

         const double risk = sl - entry;
         req.type = QM_SELL;
         req.price = 0.0;
         req.sl = sl;
         req.tp = entry - strategy_target_r * risk;
         req.reason = "TV_NQ_ICT_OB_SHORT";
         return true;
        }
     }

   return false;
  }

void MarkTradeOpenedToday()
  {
   g_trade_taken_today = true;
   g_trade_history_ready = true;
   g_bull_phase = SETUP_DONE;
   g_bear_phase = SETUP_DONE;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card uses fixed OB stop and fixed R target only; no trailing, BE, or partial close.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(!EntryWindowEnded())
      return false;

   return HasOurOpenPosition();
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
          if(PositionGetString(POSITION_SYMBOL) != _Symbol)
             continue;
          if(PositionGetInteger(POSITION_MAGIC) != magic)
             continue;
          QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
         }
      // Never re-enter from the just-closed 10:10 bar on the force-flat tick.
      return;
     }

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
   QM_EquityStreamOnNewBar();

   // News is an entry authorization only. Position management, Friday close
   // and the mandatory 10:15 New-York flatten above must never be skipped by
   // a blackout.
   if(Strategy_NewsFilterHook(broker_now))
      return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      if(QM_TM_OpenPosition(req, out_ticket) && out_ticket > 0)
         MarkTradeOpenedToday();
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
