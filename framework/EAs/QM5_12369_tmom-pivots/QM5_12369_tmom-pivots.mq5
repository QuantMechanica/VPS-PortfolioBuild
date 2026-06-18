#property strict
#property version   "5.0"
#property description "QM5_12369 tmom-pivots — Time-series momentum + classic pivot break (long/short, D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_12369 tmom-pivots
// -----------------------------------------------------------------------------
// Source: ThewindMom/151-trading-strategies, src/strategies/stocks/
//         support_resistance.py — "Strategy 3.14: Support and Resistance".
// Card: artifacts/cards_approved/QM5_12369_tmom-pivots.md (g0_status APPROVED).
//
// Mechanics (long/short, closed-bar reads at shift 1 on the card timeframe D1):
//
//   Pivot levels (classic) are computed in-EA from the PRIOR completed D1 bar's
//   OHLC, read in BROKER time at shift 1 (the just-closed bar):
//       P  = (H1 + L1 + C1) / 3
//       R1 = 2*P - L1      S1 = 2*P - H1
//       R2 = P + (H1-L1)   S2 = P - (H1-L1)
//   These are static for the whole current bar (a horizontal level), exactly as
//   classic pivots are intended to be used. (perf-allowed: 3 single-shift OHLC
//   reads per closed bar — no warmup loop, no CopyRates.)
//
//   TMOM trend STATE = sign of the N-period return over the card timeframe:
//       ret = close[1] - close[1 + tmom_period]
//       trend = +1 if ret > 0, -1 if ret < 0, 0 if flat.
//   This is a STATE, not an event — it persists bar to bar.
//
//   Trigger EVENT = a single pivot interaction in the TMOM direction:
//       LONG  : trend > 0 AND close crossed UP through the pivot this bar
//               (close[2] <= P AND close[1] > P).
//       SHORT : trend < 0 AND close crossed DOWN through the pivot this bar
//               (close[2] >= P AND close[1] < P).
//   ONE event (the pivot cross) gated by ONE persistent state (TMOM sign). The
//   two-cross-same-bar trap is avoided: TMOM is a state, not a second crossover.
//   The pivot P used for the cross is the CURRENT bar's pivot (from prior OHLC);
//   close[2] vs close[1] is the price moving across that level over one bar.
//
//   Optional level-distance gate (card P3): require room to the next level in
//   the trade direction — long only if (R1 - close1) >= dist_atr_mult * ATR;
//   short only if (close1 - S1) >= dist_atr_mult * ATR. Default off (mult 0).
//
//   Exit EVENT (signal reversal): pivot recross against the position —
//       long  closes when close[1] falls back below the current pivot;
//       short closes when close[1] rises back above the current pivot.
//   Stop : entry +/- sl_atr_mult * ATR(atr_period) hard stop (card P2 1.25*ATR).
//   No protective TP by default (source defines none); RR TP optional (0 = off).
//
//   Spread guard : block only a genuinely wide spread (fail-open on .DWX zero
//                  modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12369;
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
input int    strategy_tmom_period       = 20;     // N-period return lookback for TMOM sign
input int    strategy_warmup_bars       = 30;     // min closed bars before trading (card: 30 D1)
input int    strategy_atr_period        = 14;     // ATR period (stop / distance gate)
input double strategy_sl_atr_mult       = 1.25;   // hard stop = mult * ATR (card P2 baseline)
input double strategy_tp_rr             = 0.0;    // RR-multiple TP (0 = no TP, source defines none)
input double strategy_dist_atr_mult     = 0.0;    // P3 gate: min room to next level in ATR (0 = off)
input double strategy_spread_pct_of_stop = 15.0;  // block if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Classic pivot computation from the prior completed D1 bar (shift 1).
// Returns false if the OHLC is not yet available (warmup). All reads are single
// closed-bar shifts — perf-allowed, no loop, no CopyRates.
// -----------------------------------------------------------------------------
bool ComputePivots(double &P, double &R1, double &S1, double &R2, double &S2)
  {
   const double h1 = iHigh(_Symbol, _Period, 1);   // perf-allowed: single closed-bar read
   const double l1 = iLow(_Symbol, _Period, 1);    // perf-allowed
   const double c1 = iClose(_Symbol, _Period, 1);  // perf-allowed
   if(h1 <= 0.0 || l1 <= 0.0 || c1 <= 0.0 || h1 < l1)
      return false;

   P  = (h1 + l1 + c1) / 3.0;
   R1 = 2.0 * P - l1;
   S1 = 2.0 * P - h1;
   R2 = P + (h1 - l1);
   S2 = P - (h1 - l1);
   return true;
  }

// TMOM trend state: sign of the N-period return measured on closed bars.
// +1 up, -1 down, 0 flat / insufficient data.
int TmomTrend()
  {
   const double c_now  = iClose(_Symbol, _Period, 1);                       // perf-allowed
   const double c_back = iClose(_Symbol, _Period, 1 + strategy_tmom_period); // perf-allowed
   if(c_now <= 0.0 || c_back <= 0.0)
      return 0;
   const double ret = c_now - c_back;
   if(ret > 0.0) return  1;
   if(ret < 0.0) return -1;
   return 0;
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

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Long/short entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Warmup: require enough closed bars for TMOM + pivots.
   if(Bars(_Symbol, _Period) < strategy_warmup_bars + strategy_tmom_period + 2)
      return false;

   // --- Pivot levels from the prior completed D1 bar (current bar's static P) ---
   double P, R1, S1, R2, S2;
   if(!ComputePivots(P, R1, S1, R2, S2))
      return false;

   // --- TMOM trend STATE (sign of N-period return) ---
   const int trend = TmomTrend();
   if(trend == 0)
      return false;

   // --- Price path across the pivot over the last closed bar ---
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: prior closed bar
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: bar before that
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // Trigger EVENT: a single pivot cross in the TMOM direction. One crossover
   // (state-gated), never two simultaneous crossovers.
   const bool crossed_up   = (close2 <= P && close1 > P);
   const bool crossed_down = (close2 >= P && close1 < P);

   QM_OrderType side;
   if(trend > 0 && crossed_up)
     {
      // Optional P3 level-distance gate: require room up to R1.
      if(strategy_dist_atr_mult > 0.0 &&
         (R1 - close1) < strategy_dist_atr_mult * atr_value)
         return false;
      side = QM_BUY;
     }
   else if(trend < 0 && crossed_down)
     {
      // Optional P3 level-distance gate: require room down to S1.
      if(strategy_dist_atr_mult > 0.0 &&
         (close1 - S1) < strategy_dist_atr_mult * atr_value)
         return false;
      side = QM_SELL;
     }
   else
      return false;

   // --- Build the entry. Framework sizes lots (no lots field). ---
   const double entry = (side == QM_BUY)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr_value, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;

   double tp = 0.0; // source defines no protective TP
   if(strategy_tp_rr > 0.0)
     {
      tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_tp_rr);
      if(tp <= 0.0)
         return false;
     }

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (side == QM_BUY) ? "tmom_pivot_break_long" : "tmom_pivot_break_short";
   return true;
  }

// No active trade management beyond the fixed ATR stop. Exit is the pivot
// recross in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Signal-reversal exit: pivot recross against the open position.
//   long  closes when the last closed bar falls back below the current pivot;
//   short closes when the last closed bar rises back above the current pivot.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   double P, R1, S1, R2, S2;
   if(!ComputePivots(P, R1, S1, R2, S2))
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed
   if(close1 <= 0.0)
      return false;

   // Determine our current side from the open position for this magic.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && close1 < P)
         return true;   // long: price fell back below pivot
      if(ptype == POSITION_TYPE_SELL && close1 > P)
         return true;   // short: price rose back above pivot
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
