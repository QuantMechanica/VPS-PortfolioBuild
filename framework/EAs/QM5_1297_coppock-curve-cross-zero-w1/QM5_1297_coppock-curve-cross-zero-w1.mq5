#property strict
#property version   "5.0"
#property description "QM5_1297 coppock-curve-cross-zero-w1 — Coppock Curve zero-cross (W1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1297 coppock-curve-cross-zero-w1
// -----------------------------------------------------------------------------
// Source: Edwin S. Coppock, Barron's Oct 1962 "Practical Relative Strength
//   Charting" (via ForexFactory Trading-Systems cluster).
// Card: artifacts/cards_approved/QM5_1297_coppock-curve-cross-zero-w1.md
//   (g0_status APPROVED).
//
// Mechanics (W1, closed-bar reads at shift 1 = last closed weekly bar):
//   Coppock Curve  : Coppock = WMA(10) of ( ROC(14) + ROC(11) ),
//                    ROC(n)[k] = (close[k] - close[k+n]) / close[k+n] * 100.
//                    There is NO built-in Coppock indicator — the whole chain
//                    is computed in-EA from a bounded closed-bar seed of weekly
//                    closes (perf-allowed: one bounded CopyClose per new bar).
//   Trigger EVENT  : Coppock crosses ZERO (one event per bar).
//                      LONG : Coppock[2] <= 0 AND Coppock[1] > 0 (cross up).
//                      SELL : Coppock[2] >= 0 AND Coppock[1] < 0 (cross down).
//                    Two crosses cannot coincide on one bar, so each cross is
//                    a single unambiguous trigger (no two-cross trap).
//   Trend STATE    : LONG  needs close > SMA(trend) - 1.0*ATR (not in deep DD).
//                    SELL  needs close < SMA(trend) + 1.0*ATR.
//   Stop           : entry -/+ sl_atr_mult * ATR(atr_period).
//   Take profit    : entry +/- tp_atr_mult * ATR (same ATR value).
//   Manage         : once +be_trigger_atr*ATR in profit, trail SL to
//                    entry +/- be_buffer_atr*ATR (breakeven-plus buffer).
//   Exit (signal)  : Coppock crosses zero in the OPPOSITE direction.
//   Exit (time)    : close at market after time_stop_bars closed W1 bars
//                    (default 26 weeks ~ 6 months).
//
// W1 IS testable in the .DWX tester (unlike MN1). Holds span weeks/months, so
// qm_friday_close_enabled is set FALSE by default (a Friday flat-out would
// destroy a multi-week position) — flagged in build output.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1297;
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
// Coppock W1 positions span weeks/months — a Friday flat-out would liquidate a
// healthy multi-week trade. Disabled by default for this swing horizon.
input bool   qm_friday_close_enabled    = false;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_roc_long_period   = 14;    // long rate-of-change period (weeks)
input int    strategy_roc_short_period  = 11;    // short rate-of-change period (weeks)
input int    strategy_wma_period        = 10;    // weighted-MA smoothing of the ROC sum
input int    strategy_trend_sma_period  = 30;    // long-run trend SMA (W1)
input int    strategy_atr_period        = 14;    // ATR period (filter / stop / target)
input double strategy_trend_atr_mult    = 1.0;   // trend-filter ATR band width
input double strategy_sl_atr_mult       = 2.0;   // stop distance = mult * ATR
input double strategy_tp_atr_mult       = 4.0;   // target distance = mult * ATR
input double strategy_be_trigger_atr    = 2.0;   // profit (in ATR) to arm breakeven trail
input double strategy_be_buffer_atr     = 0.5;   // SL parked at entry +/- this*ATR
input int    strategy_time_stop_bars    = 26;    // hard time stop, closed W1 bars (~6 months)
input bool   strategy_allow_long        = true;  // enable the classic long-only buy signal
input bool   strategy_allow_short       = true;  // enable the symmetric short variant (card)
input double strategy_spread_pct_of_stop = 15.0; // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Coppock chain — computed in-EA from a bounded closed-bar seed.
// -----------------------------------------------------------------------------

// Rate-of-change at shift k over period n, from a closes[] array indexed by
// shift (closes[0]=shift 0 ... closes[N-1]=oldest). ROC(n)[k] uses closes[k]
// and closes[k+n]. Returns 0.0 on any invalid input.
double CoppockROC(const double &closes[], const int k, const int n)
  {
   const int total = ArraySize(closes);
   if(k < 0 || (k + n) >= total)
      return 0.0;
   const double base = closes[k + n];
   if(base <= 0.0)
      return 0.0;
   return (closes[k] - base) / base * 100.0;
  }

// Coppock value at shift `at`: weighted MA (weights wma..1, newest heaviest) of
// the ROC-sum series. Needs closes back to shift at + (wma-1) + roc_long.
// Returns false if the seed is too short.
bool CoppockValue(const double &closes[], const int at,
                  const int roc_long, const int roc_short, const int wma,
                  double &out_value)
  {
   out_value = 0.0;
   if(wma <= 0)
      return false;
   const int deepest_roc = (roc_long > roc_short ? roc_long : roc_short);
   const int needed = at + (wma - 1) + deepest_roc;
   if((needed + 1) > ArraySize(closes))
      return false;

   double weighted_sum = 0.0;
   double weight_total = 0.0;
   // j=0 is the newest member of the WMA window (shift `at`), weight = wma.
   for(int j = 0; j < wma; ++j)
     {
      const int shift  = at + j;
      const double roc_sum = CoppockROC(closes, shift, roc_long)
                           + CoppockROC(closes, shift, roc_short);
      const double weight  = (double)(wma - j);
      weighted_sum += roc_sum * weight;
      weight_total += weight;
     }
   if(weight_total <= 0.0)
      return false;

   out_value = weighted_sum / weight_total;
   return true;
  }

// Seed enough closed weekly closes to evaluate Coppock at shift 1 AND shift 2.
// Deepest close needed = shift 2 + (wma-1) + roc_long. One bounded CopyClose
// per closed bar (perf-allowed structural read; only called from the new-bar
// advance below, never on the per-tick path).
bool CoppockSeedCloses(double &closes[])
  {
   const int deepest_roc = (strategy_roc_long_period > strategy_roc_short_period
                            ? strategy_roc_long_period : strategy_roc_short_period);
   // +2 cross-eval shift, +(wma-1) WMA window, +deepest_roc ROC base, +pad.
   const int need = 2 + (strategy_wma_period - 1) + deepest_roc + 4;
   ArrayResize(closes, need);
   ArraySetAsSeries(closes, true); // index 0 = current/forming, 1 = last closed
   const int got = CopyClose(_Symbol, _Period, 0, need, closes); // perf-allowed: bounded, per closed bar
   if(got < need)
      return false;
   return true;
  }

// -----------------------------------------------------------------------------
// Cached Coppock state — advanced ONCE per closed W1 bar (see OnTick).
// Entry and exit hooks read these caches only; no per-tick CopyClose.
// -----------------------------------------------------------------------------
bool   g_coppock_ready = false;  // true once both Coppock values are valid
double g_coppock_now   = 0.0;    // Coppock at shift 1 (last closed bar)
double g_coppock_prev  = 0.0;    // Coppock at shift 2
double g_close_last    = 0.0;    // close[1], last closed W1 close
bool   g_cross_up      = false;  // Coppock crossed zero upward on the last bar
bool   g_cross_down    = false;  // Coppock crossed zero downward on the last bar

void AdvanceCoppock_OnNewBar()
  {
   g_coppock_ready = false;
   g_cross_up      = false;
   g_cross_down    = false;

   double closes[];
   if(!CoppockSeedCloses(closes))
      return;
   if(!CoppockValue(closes, 1, strategy_roc_long_period, strategy_roc_short_period,
                    strategy_wma_period, g_coppock_now))
      return;
   if(!CoppockValue(closes, 2, strategy_roc_long_period, strategy_roc_short_period,
                    strategy_wma_period, g_coppock_prev))
      return;

   g_close_last    = closes[1];
   g_cross_up      = (g_coppock_prev <= 0.0 && g_coppock_now > 0.0);
   g_cross_down    = (g_coppock_prev >= 0.0 && g_coppock_now < 0.0);
   g_coppock_ready = true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
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

// Coppock zero-cross entry. Caller guarantees QM_IsNewBar() == true and that
// AdvanceCoppock_OnNewBar() ran first this bar (reads cached state only).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(!g_coppock_ready)
      return false;

   // --- Trigger EVENT: single zero-cross. Up = long, down = short. ---
   const bool cross_up   = g_cross_up;
   const bool cross_down = g_cross_down;
   if(!cross_up && !cross_down)
      return false;

   // --- Trend STATE filter + ATR for stop/target ---
   const double close1 = g_close_last; // last closed W1 close (cached)
   if(close1 <= 0.0)
      return false;
   const double trend_sma = QM_SMA(_Symbol, _Period, strategy_trend_sma_period, 1);
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(trend_sma <= 0.0 || atr_value <= 0.0)
      return false;
   const double band = strategy_trend_atr_mult * atr_value;

   QM_OrderType side;
   string reason;
   if(cross_up && strategy_allow_long)
     {
      // LONG: not in catastrophic drawdown.
      if(!(close1 > trend_sma - band))
         return false;
      side   = QM_BUY;
      reason = "coppock_cross_up_long";
     }
   else if(cross_down && strategy_allow_short)
     {
      // SELL (symmetric variant per card).
      if(!(close1 < trend_sma + band))
         return false;
      side   = QM_SELL;
      reason = "coppock_cross_down_short";
     }
   else
      return false; // crossed, but that direction is disabled

   // --- Build the entry. Framework sizes lots (no lots field). ---
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
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
   req.reason = reason;
   return true;
  }

// Breakeven-plus trail once the trade is sufficiently in profit. Runs per tick;
// cheap (one ATR read + position scan), no history loops.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return;
   const double trigger_dist = strategy_be_trigger_atr * atr_value;
   const double buffer_dist  = strategy_be_buffer_atr  * atr_value;
   if(trigger_dist <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const long ptype = PositionGetInteger(POSITION_TYPE);
      const double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      const double cur_sl = PositionGetDouble(POSITION_SL);

      if(ptype == POSITION_TYPE_BUY)
        {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid <= 0.0)
            continue;
         if(bid - entry >= trigger_dist)
           {
            const double new_sl = entry + buffer_dist;
            if(cur_sl <= 0.0 || new_sl > cur_sl)
               QM_TM_MoveSL(ticket, new_sl, "coppock_breakeven_trail");
           }
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask <= 0.0)
            continue;
         if(entry - ask >= trigger_dist)
           {
            const double new_sl = entry - buffer_dist;
            if(cur_sl <= 0.0 || new_sl < cur_sl)
               QM_TM_MoveSL(ticket, new_sl, "coppock_breakeven_trail");
           }
        }
     }
  }

// Signal-invalidation exit: Coppock crosses zero in the OPPOSITE direction of
// the open position. Plus a hard time stop after strategy_time_stop_bars weeks.
// One cross event per bar; caller is on the closed-bar path via OnTick gating.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Determine the open side (single position per magic).
   long open_type = -1;
   datetime open_time = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      open_type = PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      break;
     }
   if(open_type < 0)
      return false;

   // --- Time stop: closed weekly bars elapsed since entry ---
   if(strategy_time_stop_bars > 0)
     {
      const datetime bar_open = iTime(_Symbol, _Period, 0); // perf-allowed: single bar-open read
      if(bar_open > 0 && open_time > 0)
        {
         const long week_secs = 7 * 24 * 60 * 60;
         const long elapsed_bars = (long)((bar_open - open_time) / week_secs);
         if(elapsed_bars >= strategy_time_stop_bars)
            return true;
        }
     }

   // --- Coppock opposite zero-cross (cached, advanced once per closed bar) ---
   if(!g_coppock_ready)
      return false;
   if(open_type == POSITION_TYPE_BUY && g_cross_down)
      return true;  // long invalidated by a downward zero-cross
   if(open_type == POSITION_TYPE_SELL && g_cross_up)
      return true;  // short invalidated by an upward zero-cross

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

   // Latch the new-bar event ONCE (single-consume). On a fresh closed W1 bar,
   // advance the cached Coppock chain so both exit and entry read fresh state.
   const bool is_new_bar = QM_IsNewBar();
   if(is_new_bar)
      AdvanceCoppock_OnNewBar();

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

   if(!is_new_bar)
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
