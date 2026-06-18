#property strict
#property version   "5.0"
#property description "QM5_11495 carter-t-ema3-8-macd-stoch-psar-sd-m5 — EMA3/8 cross + MACD/Stoch/PSAR/SD confluence (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11495 carter-t-ema3-8-macd-stoch-psar-sd-m5
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)",
//         System #17 (self-published 2014).
// Card: artifacts/cards_approved/QM5_11495_carter-t-ema3-8-macd-stoch-psar-sd-m5.md
//       (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1, M5):
//   Trigger EVENT : EMA(3) crosses EMA(8). ONE fresh cross per bar — this is the
//                   sole entry EVENT. Every other indicator is a confirming STATE
//                   evaluated on the SAME closed bar (avoids the two-cross trap).
//   STATE  PSAR   : SAR below the bar's low (long) / above the bar's high (short).
//   STATE  MACD   : MACD main > 0 (long) / < 0 (short).
//   STATE  Stoch  : %K > %D (long) / %K < %D (short)  — momentum side, not a cross.
//   STATE  SD     : StdDev(20) >= per-symbol-family medium threshold (vol regime).
//   Stop          : prior swing low/high over a structural lookback (5 bars),
//                   capped to a max pip distance.
//   Take profit   : entry +/- tp_atr_mult * ATR (QM adds; no source TP).
//   Defensive exit: EMA(3) reverses against the open position -> close manually.
//   Spread guard  : block only a genuinely wide spread (fail-open on .DWX 0 spread).
//   Friday gate   : no NEW entries on Friday (broker time).
//
// Symbols (card): EURUSD.DWX, GBPUSD.DWX, AUDUSD.DWX, USDJPY.DWX — all present in
//   dwx_symbol_matrix.csv, no porting needed.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11495;
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
input int    strategy_ema_fast_period   = 3;      // fast EMA (cross trigger)
input int    strategy_ema_slow_period   = 8;      // slow EMA (cross trigger)
input int    strategy_macd_fast         = 12;     // MACD fast EMA
input int    strategy_macd_slow         = 26;     // MACD slow EMA
input int    strategy_macd_signal       = 9;      // MACD signal EMA
input int    strategy_stoch_k           = 10;     // Stochastic %K period
input int    strategy_stoch_d           = 15;     // Stochastic %D period
input int    strategy_stoch_slowing     = 15;     // Stochastic slowing
input double strategy_sar_step          = 0.02;   // Parabolic SAR step
input double strategy_sar_max           = 0.2;    // Parabolic SAR maximum
input int    strategy_sd_period         = 20;     // StdDev period (vol filter)
input double strategy_sd_threshold      = 0.0;    // SD medium threshold; 0 = auto per-symbol family
input bool   strategy_sd_filter_on      = true;   // enable the SD volatility filter
input int    strategy_struct_lookback   = 5;      // swing high/low lookback for the stop
input int    strategy_sl_max_pips       = 20;     // P2 cap on stop distance (pips)
input int    strategy_atr_period        = 14;     // ATR period (take profit)
input double strategy_tp_atr_mult       = 2.0;    // take-profit = mult * ATR
input bool   strategy_no_friday_entry   = true;   // skip NEW entries on Friday
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// Per-symbol-family SD "medium" threshold (card §"Standard Deviation Thresholds").
// AUD/NZD pairs: 0.0001 ; JPY pairs: 0.05 ; all others (EUR/GBP/CHF): 0.005.
// Returns the absolute StdDev value at/above which volatility is MEDIUM+.
double SD_MediumThreshold()
  {
   if(strategy_sd_threshold > 0.0)
      return strategy_sd_threshold; // explicit override (P3 sweeps)

   const string s = _Symbol;
   if(StringFind(s, "JPY") >= 0)
      return 0.05;
   if(StringFind(s, "AUD") >= 0 || StringFind(s, "NZD") >= 0)
      return 0.0001;
   return 0.005; // EUR / GBP / CHF and all other FX
  }

// Structural stop distance in PRICE units: distance from entry to the swing
// low/high over the lookback window, capped to strategy_sl_max_pips.
double StructStopDistance(const double entry, const bool is_long)
  {
   const int look = MathMax(2, strategy_struct_lookback);
   double dist = 0.0;
   if(is_long)
     {
      // lowest low over the lookback window (closed bars 1..look)
      double lo = iLow(_Symbol, _Period, 1); // perf-allowed: small structural scan
      for(int i = 2; i <= look + 1; ++i)
        {
         const double l = iLow(_Symbol, _Period, i);
         if(l > 0.0 && l < lo)
            lo = l;
        }
      dist = entry - lo;
     }
   else
     {
      double hi = iHigh(_Symbol, _Period, 1); // perf-allowed: small structural scan
      for(int i = 2; i <= look + 1; ++i)
        {
         const double h = iHigh(_Symbol, _Period, i);
         if(h > hi)
            hi = h;
        }
      dist = hi - entry;
     }

   if(dist <= 0.0)
      return 0.0;

   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_max_pips);
   if(cap > 0.0 && dist > cap)
      dist = cap;
   return dist;
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
      return false; // no ATR yet — defer to the entry gate

   const double stop_distance = strategy_tp_atr_mult * atr_value; // scale reference
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
// Trigger EVENT = EMA3/8 cross; MACD / Stoch / PSAR / SD are confirming STATES.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // No NEW entries on Friday (broker time).
   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5)
         return false;
     }

   // --- Trigger EVENT: EMA(3) crosses EMA(8) on the just-closed bar ---
   const double ema_fast_1 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow_1 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double ema_fast_2 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double ema_slow_2 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   if(ema_fast_1 <= 0.0 || ema_slow_1 <= 0.0 || ema_fast_2 <= 0.0 || ema_slow_2 <= 0.0)
      return false;

   const bool cross_up   = (ema_fast_2 <= ema_slow_2 && ema_fast_1 > ema_slow_1);
   const bool cross_down = (ema_fast_2 >= ema_slow_2 && ema_fast_1 < ema_slow_1);
   if(!cross_up && !cross_down)
      return false; // no fresh cross — nothing to do this bar

   const bool is_long = cross_up;

   // --- Confirming STATES (same closed bar) ---
   // PSAR side
   const double sar = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 1);
   if(sar <= 0.0)
      return false;
   const double low1  = iLow(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read
   const double high1 = iHigh(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(low1 <= 0.0 || high1 <= 0.0)
      return false;
   if(is_long && !(sar < low1))
      return false;
   if(!is_long && !(sar > high1))
      return false;

   // MACD side (zero line)
   const double macd = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                    strategy_macd_slow, strategy_macd_signal, 1);
   if(is_long && !(macd > 0.0))
      return false;
   if(!is_long && !(macd < 0.0))
      return false;

   // Stochastic side: %K vs %D (momentum direction STATE, not a cross event)
   const double k = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k,
                               strategy_stoch_d, strategy_stoch_slowing, 1);
   const double d = QM_Stoch_D(_Symbol, _Period, strategy_stoch_k,
                               strategy_stoch_d, strategy_stoch_slowing, 1);
   if(is_long && !(k > d))
      return false;
   if(!is_long && !(k < d))
      return false;

   // SD volatility regime: medium or stronger (per-symbol-family threshold)
   if(strategy_sd_filter_on)
     {
      const double sd = QM_StdDev(_Symbol, _Period, strategy_sd_period, 1, PRICE_CLOSE, MODE_SMA);
      if(sd < SD_MediumThreshold())
         return false;
     }

   // --- Build the entry. Framework sizes lots (no lots field). ---
   const double entry = (is_long ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                  : SymbolInfoDouble(_Symbol, SYMBOL_BID));
   if(entry <= 0.0)
      return false;

   const double stop_dist = StructStopDistance(entry, is_long);
   if(stop_dist <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;
   const double tp_dist = strategy_tp_atr_mult * atr_value;
   if(tp_dist <= 0.0)
      return false;

   double sl, tp;
   if(is_long)
     {
      sl = QM_TM_NormalizePrice(_Symbol, entry - stop_dist);
      tp = QM_TM_NormalizePrice(_Symbol, entry + tp_dist);
     }
   else
     {
      sl = QM_TM_NormalizePrice(_Symbol, entry + stop_dist);
      tp = QM_TM_NormalizePrice(_Symbol, entry - tp_dist);
     }
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type   = (is_long ? QM_BUY : QM_SELL);
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (is_long ? "carter_ema38_long" : "carter_ema38_short");
   return true;
  }

// No active trade management beyond the fixed structural stop / ATR target.
// The defensive EMA reversal exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: fast EMA(3) reverses against the open position vs EMA(8).
// LONG closes when EMA(3) < EMA(8); SHORT closes when EMA(3) > EMA(8).
// Evaluated as a STATE on the closed bar (the SL/TP handle the rest).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   if(ema_fast <= 0.0 || ema_slow <= 0.0)
      return false;

   // Determine direction of the held position.
   bool have_long = false, have_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
         have_long = true;
      else if(ptype == POSITION_TYPE_SELL)
         have_short = true;
     }

   if(have_long && ema_fast < ema_slow)
      return true;
   if(have_short && ema_fast > ema_slow)
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
