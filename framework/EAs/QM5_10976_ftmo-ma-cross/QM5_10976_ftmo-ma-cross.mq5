#property strict
#property version   "5.0"
#property description "QM5_10976 ftmo-ma-cross — SMA50/200 trend-cross (long+short, H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_10976 ftmo-ma-cross
// -----------------------------------------------------------------------------
// Source: FTMO, "Technical analysis - why are moving averages so popular?",
//         2022-09-02. Card: artifacts/cards_approved/QM5_10976_ftmo-ma-cross.md
//         (g0_status APPROVED).
//
// Mechanics (long + short, closed-bar reads at shift 1; H4):
//   Long ENTRY:
//     - SMA(50) crosses ABOVE SMA(200)  (EVENT: prev fast<=slow, now fast>slow).
//     - The cross follows >= qualify_bars H4 bars where SMA(50) was BELOW SMA(200)
//       (STATE measured at the bar just before the cross window).
//     - Entry candle (shift 1) closes ABOVE both SMA values.
//   Short ENTRY: mirror (fast crosses below slow, prior state fast above slow,
//     close below both SMAs).
//   Filters (skip the entry):
//     - SMA(200) slope over slope_bars is nearly flat:
//       |sma200[1]-sma200[1+slope_bars]| < slope_atr_mult * ATR(14).
//     - Entry candle range (high1-low1) > range_atr_mult * ATR(14).
//   STOP: swing low/high over swing_bars (closed bars) -/+ swing_atr_buf * ATR(14).
//   TAKE: tp_rr * R (risk = |entry - sl|).
//   MANAGEMENT: after price has reached trail_trigger_rr * R, trail the stop to
//     SMA(50) (only ever tightening, via QM_TM_MoveSL).
//   EXIT (manual, closed bar):
//     - Long: SMA(50) crosses back below SMA(200), OR close < SMA(200) for
//       exit_close_bars consecutive H4 bars.  Short: mirror.
//     - Time exit after max_hold_bars H4 bars in the trade.
//   Spread guard: skip only a genuinely wide spread (fail-open on .DWX zero
//     modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10976;
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
input int    strategy_sma_fast_period    = 50;    // fast SMA period
input int    strategy_sma_slow_period    = 200;   // slow SMA period
input int    strategy_qualify_bars       = 20;    // bars fast must have been on opposite side before cross
input int    strategy_atr_period         = 14;    // ATR period (filters / stop buffer)
input int    strategy_slope_bars         = 20;    // bars over which to measure SMA(200) slope
input double strategy_slope_atr_mult     = 0.25;  // min |slope| as a fraction of ATR (flat-trend skip)
input double strategy_range_atr_mult     = 2.5;   // skip if entry candle range > mult * ATR
input int    strategy_swing_bars         = 12;    // swing lookback for the structural stop
input double strategy_swing_atr_buf      = 0.50;  // ATR buffer added beyond the swing extreme
input double strategy_tp_rr              = 3.0;   // take-profit in R multiples
input double strategy_trail_trigger_rr   = 1.5;   // start trailing to SMA(50) after this R touch
input int    strategy_exit_close_bars    = 2;     // consecutive closes beyond SMA(200) to exit
input int    strategy_max_hold_bars      = 80;    // time exit after this many H4 bars
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Helpers (closed-bar swing extremes — bounded loop, gated by the closed-bar
// entry path. perf-allowed: small fixed lookback structural read).
// -----------------------------------------------------------------------------
double SwingLow(const int lookback)
  {
   double lo = iLow(_Symbol, _Period, 1); // perf-allowed: structural swing read
   for(int s = 2; s <= lookback; ++s)
     {
      const double v = iLow(_Symbol, _Period, s); // perf-allowed
      if(v > 0.0 && v < lo)
         lo = v;
     }
   return lo;
  }

double SwingHigh(const int lookback)
  {
   double hi = iHigh(_Symbol, _Period, 1); // perf-allowed: structural swing read
   for(int s = 2; s <= lookback; ++s)
     {
      const double v = iHigh(_Symbol, _Period, s); // perf-allowed
      if(v > hi)
         hi = v;
     }
   return hi;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

   // Reference stop distance ~ swing_atr_buf * ATR; use ATR as a stable scale.
   const double stop_distance = strategy_swing_atr_buf * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Long + short entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- SMA values at the closed bar (shift 1) and the prior bar (shift 2) ---
   const double fast_now  = QM_SMA(_Symbol, _Period, strategy_sma_fast_period, 1);
   const double slow_now  = QM_SMA(_Symbol, _Period, strategy_sma_slow_period, 1);
   const double fast_prev = QM_SMA(_Symbol, _Period, strategy_sma_fast_period, 2);
   const double slow_prev = QM_SMA(_Symbol, _Period, strategy_sma_slow_period, 2);
   if(fast_now <= 0.0 || slow_now <= 0.0 || fast_prev <= 0.0 || slow_prev <= 0.0)
      return false;

   // --- ATR for the filters / stop buffer ---
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // --- Flat-trend filter: SMA(200) slope over slope_bars must be steep enough.
   //     slope measured on closed bars: sma200[1] vs sma200[1+slope_bars]. ---
   const double slow_back = QM_SMA(_Symbol, _Period, strategy_sma_slow_period, 1 + strategy_slope_bars);
   if(slow_back <= 0.0)
      return false;
   const double slope_abs = MathAbs(slow_now - slow_back);
   if(slope_abs < strategy_slope_atr_mult * atr_value)
      return false; // nearly flat — skip

   // --- Entry-candle range filter (closed bar shift 1). ---
   const double high1 = iHigh(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read
   const double low1  = iLow(_Symbol, _Period, 1);   // perf-allowed
   const double close1 = iClose(_Symbol, _Period, 1);// perf-allowed
   if(high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0)
      return false;
   if((high1 - low1) > strategy_range_atr_mult * atr_value)
      return false; // candle too large — skip

   // --- Cross EVENT (one event/bar) + prior-side STATE qualification ---
   const bool cross_up   = (fast_prev <= slow_prev && fast_now >  slow_now);
   const bool cross_down = (fast_prev >= slow_prev && fast_now <  slow_now);

   if(cross_up)
     {
      // STATE: fast was BELOW slow for >= qualify_bars before the cross.
      // Measure at the bar just before the cross bar (shift 2) going back.
      bool qualified = true;
      for(int s = 2; s <= strategy_qualify_bars + 1; ++s)
        {
         const double f = QM_SMA(_Symbol, _Period, strategy_sma_fast_period, s);
         const double sl = QM_SMA(_Symbol, _Period, strategy_sma_slow_period, s);
         if(f <= 0.0 || sl <= 0.0 || !(f < sl))
           {
            qualified = false;
            break;
           }
        }
      if(!qualified)
         return false;

      // Entry-candle confirmation: close above both SMAs.
      if(!(close1 > fast_now && close1 > slow_now))
         return false;

      // Structural stop: swing low - buffer.
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double swing_lo = SwingLow(strategy_swing_bars);
      if(swing_lo <= 0.0)
         return false;
      double sl_price = swing_lo - strategy_swing_atr_buf * atr_value;
      sl_price = QM_TM_NormalizePrice(_Symbol, sl_price);
      if(!(sl_price > 0.0 && sl_price < entry))
         return false;
      const double tp_price = QM_TakeRR(_Symbol, QM_BUY, entry, sl_price, strategy_tp_rr);
      if(tp_price <= 0.0)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = sl_price;
      req.tp     = tp_price;
      req.reason = "ma_cross_long";
      return true;
     }

   if(cross_down)
     {
      // STATE: fast was ABOVE slow for >= qualify_bars before the cross.
      bool qualified = true;
      for(int s = 2; s <= strategy_qualify_bars + 1; ++s)
        {
         const double f = QM_SMA(_Symbol, _Period, strategy_sma_fast_period, s);
         const double sl = QM_SMA(_Symbol, _Period, strategy_sma_slow_period, s);
         if(f <= 0.0 || sl <= 0.0 || !(f > sl))
           {
            qualified = false;
            break;
           }
        }
      if(!qualified)
         return false;

      // Entry-candle confirmation: close below both SMAs.
      if(!(close1 < fast_now && close1 < slow_now))
         return false;

      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double swing_hi = SwingHigh(strategy_swing_bars);
      if(swing_hi <= 0.0)
         return false;
      double sl_price = swing_hi + strategy_swing_atr_buf * atr_value;
      sl_price = QM_TM_NormalizePrice(_Symbol, sl_price);
      if(!(sl_price > entry))
         return false;
      const double tp_price = QM_TakeRR(_Symbol, QM_SELL, entry, sl_price, strategy_tp_rr);
      if(tp_price <= 0.0)
         return false;

      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl_price;
      req.tp     = tp_price;
      req.reason = "ma_cross_short";
      return true;
     }

   return false;
  }

// Trail the stop to SMA(50) once the trade has reached trail_trigger_rr * R.
// Only ever tightens (QM_TM_MoveSL rejects a non-improving stop).
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   const double fast_now = QM_SMA(_Symbol, _Period, strategy_sma_fast_period, 1);
   if(fast_now <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const long pos_type    = PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double cur_sl     = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || cur_sl <= 0.0)
         continue;

      // Initial R = |open - initial_sl|. We approximate R via the current SL
      // distance only before any trailing has occurred; to stay deterministic
      // we use the distance from open to the *original* stop, which is the SL
      // until the first trail tightens it. Use current bid/ask for progress.
      const double risk = MathAbs(open_price - cur_sl);
      if(risk <= 0.0)
         continue;

      if(pos_type == POSITION_TYPE_BUY)
        {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid <= 0.0)
            continue;
         const double progress_r = (bid - open_price) / risk;
         if(progress_r >= strategy_trail_trigger_rr && fast_now > cur_sl && fast_now < bid)
            QM_TM_MoveSL(ticket, QM_TM_NormalizePrice(_Symbol, fast_now), "trail_sma50");
        }
      else if(pos_type == POSITION_TYPE_SELL)
        {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask <= 0.0)
            continue;
         const double progress_r = (open_price - ask) / risk;
         if(progress_r >= strategy_trail_trigger_rr && fast_now < cur_sl && fast_now > ask)
            QM_TM_MoveSL(ticket, QM_TM_NormalizePrice(_Symbol, fast_now), "trail_sma50");
        }
     }
  }

// Manual exits: SMA cross-back, N consecutive closes beyond SMA(200), or time
// stop after max_hold_bars. Evaluated on the closed-bar path.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Select this EA's position on this symbol to read direction + open time.
   long pos_type = -1;
   datetime open_time = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      pos_type  = PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      break;
     }
   if(pos_type < 0)
      return false;

   // --- Time exit: held >= max_hold_bars H4 bars. ---
   const int period_secs = PeriodSeconds(_Period);
   if(period_secs > 0 && open_time > 0)
     {
      const datetime bar_open = iTime(_Symbol, _Period, 0); // perf-allowed: current bar-open time
      const long held_bars = (long)((bar_open - open_time) / period_secs);
      if(held_bars >= strategy_max_hold_bars)
         return true;
     }

   const double fast_now  = QM_SMA(_Symbol, _Period, strategy_sma_fast_period, 1);
   const double slow_now  = QM_SMA(_Symbol, _Period, strategy_sma_slow_period, 1);
   const double fast_prev = QM_SMA(_Symbol, _Period, strategy_sma_fast_period, 2);
   const double slow_prev = QM_SMA(_Symbol, _Period, strategy_sma_slow_period, 2);
   if(fast_now <= 0.0 || slow_now <= 0.0 || fast_prev <= 0.0 || slow_prev <= 0.0)
      return false;

   if(pos_type == POSITION_TYPE_BUY)
     {
      // SMA(50) crosses back below SMA(200).
      if(fast_prev >= slow_prev && fast_now < slow_now)
         return true;
      // close < SMA(200) for exit_close_bars consecutive H4 bars.
      bool all_below = true;
      for(int s = 1; s <= strategy_exit_close_bars; ++s)
        {
         const double c = iClose(_Symbol, _Period, s); // perf-allowed: single closed-bar read
         const double sma200_s = QM_SMA(_Symbol, _Period, strategy_sma_slow_period, s);
         if(c <= 0.0 || sma200_s <= 0.0 || !(c < sma200_s))
           {
            all_below = false;
            break;
           }
        }
      if(all_below)
         return true;
     }
   else if(pos_type == POSITION_TYPE_SELL)
     {
      // SMA(50) crosses back above SMA(200).
      if(fast_prev <= slow_prev && fast_now > slow_now)
         return true;
      // close > SMA(200) for exit_close_bars consecutive H4 bars.
      bool all_above = true;
      for(int s = 1; s <= strategy_exit_close_bars; ++s)
        {
         const double c = iClose(_Symbol, _Period, s); // perf-allowed
         const double sma200_s = QM_SMA(_Symbol, _Period, strategy_sma_slow_period, s);
         if(c <= 0.0 || sma200_s <= 0.0 || !(c > sma200_s))
           {
            all_above = false;
            break;
           }
        }
      if(all_above)
         return true;
     }

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
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
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
