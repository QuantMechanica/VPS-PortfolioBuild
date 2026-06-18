#property strict
#property version   "5.0"
#property description "QM5_1223 bhatti-fx-zscore-mr — FX z-score mean reversion + H1 momentum regime filter (M15)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1223 bhatti-fx-zscore-mr
// -----------------------------------------------------------------------------
// Source: SSRN abstract 6087107, Amaanullah Bhatti (Symbiosis Intl Univ.),
//   "A Regime-Conditioned Statistical Mean Reversion Framework for Intraday FX".
// Card: artifacts/cards_approved/QM5_1223_bhatti-fx-zscore-mr.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; base TF = M15):
//   z-score STATE : z = (Close - SMA(Close, lookback)) / StdDev(Close, lookback)
//                   on the base (M15) timeframe.
//   Regime FILTER : H1 momentum = Close(H1,1) - Close(H1, 1+mom_bars);
//                   ATR ref = ATR(H1, mom_bars).
//   Entry LONG  EVENT: z just crossed DOWN through -z_entry
//                      (z[1] <= -z_entry AND z[2] > -z_entry)         <- single event
//                      AND H1 momentum NOT strongly negative
//                      (momentum > -mom_block_mult * atr_h1).
//   Entry SHORT EVENT: z just crossed UP through +z_entry
//                      (z[1] >= +z_entry AND z[2] < +z_entry)         <- single event
//                      AND H1 momentum NOT strongly positive
//                      (momentum < +mom_block_mult * atr_h1).
//     The cross is the EVENT; the H1 momentum gate is a STATE. Only ONE fresh
//     cross is required per entry — avoids the two-cross-same-bar zero-trade trap.
//   Stop         : hard ATR stop = sl_atr_mult * ATR(base, lookback) from entry.
//   Exit LONG    : z >= -z_exit, OR held >= max_hold bars, OR H1 momentum flips
//                  strongly negative (momentum < -mom_flip_mult * atr_h1).
//   Exit SHORT   : z <= +z_exit, OR held >= max_hold bars, OR H1 momentum flips
//                  strongly positive (momentum > +mom_flip_mult * atr_h1).
//   Filters      : trade only session_start..session_end broker time;
//                  central news filter via framework hook.
//
// One position per symbol/magic. RISK_FIXED in tester, RISK_PERCENT live.
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific; everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1223;
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
input int    strategy_zscore_lookback   = 96;     // SMA/StdDev lookback for the z-score (base TF)
input double strategy_z_entry           = 2.0;    // entry band: |z| >= this triggers the cross event
input double strategy_z_exit            = 0.25;   // exit band: z reverts to within this of zero
input int    strategy_max_hold_bars     = 24;     // time stop: max bars to hold (base TF)
input int    strategy_mom_bars          = 24;     // H1 momentum lookback + ATR period (H1)
input double strategy_mom_block_mult    = 0.75;   // entry blocked if H1 momentum stronger than this * ATR(H1)
input double strategy_mom_flip_mult     = 1.0;    // exit if H1 momentum flips beyond this * ATR(H1) against us
input double strategy_sl_atr_mult       = 1.5;    // hard stop distance = mult * ATR(base, lookback)
input int    strategy_session_start_hr  = 7;      // first broker hour allowed to OPEN (inclusive)
input int    strategy_session_end_hr    = 20;     // last broker hour allowed to OPEN (exclusive)
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// Rolling z-score of the base-TF close at the given closed-bar shift.
// Returns a large sentinel (-1e9) when warmup data is not yet available, so
// callers can guard with a sane bound.
double ZScore(const int shift)
  {
   const double sma    = QM_SMA(_Symbol, _Period, strategy_zscore_lookback, shift);
   const double stddev = QM_StdDev(_Symbol, _Period, strategy_zscore_lookback, shift);
   if(stddev <= 0.0)
      return -1.0e9;
   const double close_s = iClose(_Symbol, _Period, shift); // perf-allowed: single closed-bar read
   if(close_s <= 0.0)
      return -1.0e9;
   return (close_s - sma) / stddev;
  }

// H1 regime momentum over strategy_mom_bars closed H1 bars.
double H1Momentum()
  {
   const double c_now  = iClose(_Symbol, PERIOD_H1, 1);                       // perf-allowed: single read
   const double c_past = iClose(_Symbol, PERIOD_H1, 1 + strategy_mom_bars);   // perf-allowed: single read
   if(c_now <= 0.0 || c_past <= 0.0)
      return 0.0;
   return c_now - c_past;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — fail-open on .DWX zero spread.
// Session/regime gating lives on the closed-bar entry path.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_zscore_lookback, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Mean-reversion entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Session filter (broker time): only OPEN inside the allowed window ---
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(!(dt.hour >= strategy_session_start_hr && dt.hour < strategy_session_end_hr))
      return false;

   // --- z-score STATE at the last two closed bars ---
   const double z_now  = ZScore(1);
   const double z_prev = ZScore(2);
   if(z_now <= -1.0e8 || z_prev <= -1.0e8)
      return false; // warmup not ready

   // --- H1 regime momentum STATE ---
   const double atr_h1 = QM_ATR(_Symbol, PERIOD_H1, strategy_mom_bars, 1);
   if(atr_h1 <= 0.0)
      return false;
   const double momentum = H1Momentum();

   const double z_band = MathAbs(strategy_z_entry);

   // --- LONG: z just crossed DOWN through -z_band (single fresh event) and the
   //     H1 momentum is NOT strongly negative (do not catch a falling knife). ---
   const bool long_cross  = (z_now <= -z_band && z_prev > -z_band);
   const bool long_regime = (momentum > -strategy_mom_block_mult * atr_h1);

   // --- SHORT: z just crossed UP through +z_band (single fresh event) and the
   //     H1 momentum is NOT strongly positive. ---
   const bool short_cross  = (z_now >=  z_band && z_prev <  z_band);
   const bool short_regime = (momentum <  strategy_mom_block_mult * atr_h1);

   QM_OrderType side;
   if(long_cross && long_regime)
      side = QM_BUY;
   else if(short_cross && short_regime)
      side = QM_SELL;
   else
      return false;

   const double atr_base = QM_ATR(_Symbol, _Period, strategy_zscore_lookback, 1);
   if(atr_base <= 0.0)
      return false;

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr_base, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;   // no fixed TP — exits are z-reversion / time / momentum-flip
   req.reason = (side == QM_BUY) ? "zscore_mr_long" : "zscore_mr_short";
   return true;
  }

// No active SL/TP management beyond the fixed ATR stop; exits live in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Discretionary exit: z reverts toward zero, OR max-hold time stop, OR H1
// momentum flips strongly against the open direction. Evaluated each tick;
// the framework closes the magic's position when this returns true.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Select this EA's open position to read direction + open time.
   bool   is_long      = false;
   datetime open_time  = 0;
   bool   found        = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      is_long   = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      found     = true;
      break;
     }
   if(!found)
      return false;

   // --- Time stop: bars elapsed since entry on the base timeframe ---
   const datetime bar_time   = iTime(_Symbol, _Period, 0); // perf-allowed: single current-bar open time
   const int      period_sec = PeriodSeconds(_Period);
   if(period_sec > 0 && open_time > 0)
     {
      const int held_bars = (int)((bar_time - open_time) / period_sec);
      if(held_bars >= strategy_max_hold_bars)
         return true;
     }

   // --- z-reversion exit ---
   const double z_now = ZScore(1);
   if(z_now > -1.0e8)
     {
      const double z_exit = MathAbs(strategy_z_exit);
      if(is_long && z_now >= -z_exit)
         return true;
      if(!is_long && z_now <=  z_exit)
         return true;
     }

   // --- Momentum-flip exit: H1 momentum turns strongly against the position ---
   const double atr_h1 = QM_ATR(_Symbol, PERIOD_H1, strategy_mom_bars, 1);
   if(atr_h1 > 0.0)
     {
      const double momentum = H1Momentum();
      if(is_long && momentum < -strategy_mom_flip_mult * atr_h1)
         return true;
      if(!is_long && momentum >  strategy_mom_flip_mult * atr_h1)
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
