#property strict
#property version   "5.0"
#property description "QM5_11666 td-ema9-30-momentum-h1 — EMA(9/30) cross + Momentum filter (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11666 td-ema9-30-momentum-h1
// -----------------------------------------------------------------------------
// Source: Anonymous, "Tom Demark FX System", 9 Forex Systems (MoneyTec
//   compilation, ~2006). Card: artifacts/cards_approved/
//   QM5_11666_td-ema9-30-momentum-h1.md (g0_status APPROVED). The discretionary
//   TD trendline element is intentionally omitted (card R2); the mechanical edge
//   is EMA(9/30) crossover confirmed by Momentum direction.
//
// Mechanics (closed-bar reads at shift 1, H1):
//   Trigger EVENT (long) : EMA(9) crosses ABOVE EMA(30)
//                          [ema9@2 <= ema30@2 AND ema9@1 > ema30@1].
//   Confirm STATE (long) : Momentum(N) > 100  (close[1] / close[1+N] * 100).
//   Trigger EVENT (short): EMA(9) crosses BELOW EMA(30)
//                          [ema9@2 >= ema30@2 AND ema9@1 < ema30@1].
//   Confirm STATE (short): Momentum(N) < 100.
//   Entry                : at the open of the next H1 bar after the cross bar
//                          closes (framework fires on the new closed bar).
//   Stop  : fixed pips (source: 40 pips hard stop).
//   Take  : fixed pips (source midpoint of 40-150 → 80 pips).
//   Exit  : SL/TP only (source: close at fixed SL or TP, whichever first).
//   Spread guard: blocks only a genuinely wide spread (> spread_pct_of_stop of
//                 the stop distance); fail-open on .DWX zero modeled spread.
//
// Two-cross trap avoided: the EMA cross is the SINGLE trigger EVENT; Momentum is
// a STATE (currently >/< 100), not a second fresh cross on the same bar.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11666;
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
input int    strategy_ema_fast_period    = 9;      // fast EMA (trigger leg)
input int    strategy_ema_slow_period    = 30;     // slow EMA (trigger leg)
input int    strategy_momentum_period    = 14;     // Momentum lookback (confirm state)
input double strategy_momentum_level     = 100.0;  // Momentum threshold (>up / <down)
input double strategy_sl_pips            = 40.0;   // fixed stop, pips (source hard stop)
input double strategy_tp_pips            = 80.0;   // fixed take, pips (source midpoint)
input double strategy_spread_pct_of_stop = 15.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// Momentum at a given closed-bar shift: close[shift] / close[shift+period] * 100.
// Mirrors MT5 iMomentum(PRICE_CLOSE). >100 = price above N bars ago (up momentum).
double Momentum(const int shift)
  {
   const double c_now  = iClose(_Symbol, _Period, shift);                          // perf-allowed: single closed-bar read
   const double c_back = iClose(_Symbol, _Period, shift + strategy_momentum_period); // perf-allowed: single closed-bar read
   if(c_now <= 0.0 || c_back <= 0.0)
      return 0.0;
   return (c_now / c_back) * 100.0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only; regime/signal work is in
// Strategy_EntrySignal on the closed-bar path. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   // Fixed-pip stop distance as the spread-cap reference (scale-correct).
   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_sl_pips);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- EMA(9/30) values on the two most recent closed bars ---
   const double ema_fast_1 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow_1 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double ema_fast_2 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double ema_slow_2 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   if(ema_fast_1 <= 0.0 || ema_slow_1 <= 0.0 || ema_fast_2 <= 0.0 || ema_slow_2 <= 0.0)
      return false;

   // --- Trigger EVENT: a fresh EMA cross on the last closed bar (one event) ---
   const bool cross_up   = (ema_fast_2 <= ema_slow_2 && ema_fast_1 >  ema_slow_1);
   const bool cross_down = (ema_fast_2 >= ema_slow_2 && ema_fast_1 <  ema_slow_1);
   if(!cross_up && !cross_down)
      return false;

   // --- Confirm STATE: Momentum direction on the last closed bar ---
   const double mom = Momentum(1);
   if(mom <= 0.0)
      return false;

   QM_OrderType side;
   string reason;
   if(cross_up && mom > strategy_momentum_level)
     {
      side   = QM_BUY;
      reason = "ema930_cross_up_mom";
     }
   else if(cross_down && mom < strategy_momentum_level)
     {
      side   = QM_SELL;
      reason = "ema930_cross_dn_mom";
     }
   else
      return false; // cross without confirming momentum → no trade

   // --- Build the entry. Framework sizes lots (no lots field). Fixed-pip SL/TP. ---
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopFixedPips(_Symbol, side, entry, strategy_sl_pips);
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_tp_pips / strategy_sl_pips);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = reason;
   return true;
  }

// No active management beyond the fixed SL/TP (source: SL or TP, whichever first).
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit — SL/TP only per the card.
bool Strategy_ExitSignal()
  {
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
