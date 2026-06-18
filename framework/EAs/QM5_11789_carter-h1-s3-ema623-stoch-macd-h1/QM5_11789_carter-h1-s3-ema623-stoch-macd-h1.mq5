#property strict
#property version   "5.0"
#property description "QM5_11789 carter-h1-s3-ema623-stoch-macd-h1 — EMA6/23 + Stoch + slow MACD triple-confirmed (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11789 carter-h1-s3-ema623-stoch-macd-h1
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "Strategy #3", in 20 Forex Trading Strategies
//         (1 Hour Time Frame), 2014, page 9.
// Card: artifacts/cards_approved/QM5_11789_carter-h1-s3-ema623-stoch-macd-h1.md
//       (g0_status APPROVED).
//
// Mechanics (H1, closed-bar reads at shift 1; one position per magic):
//   Triple-confirmed entry. To avoid the two-cross-same-bar zero-trade trap
//   (HR DWX invariant #4), exactly ONE of the card's two cross conditions is
//   the trigger EVENT; the rest are confirming STATES:
//
//     TRIGGER  EVENT : Stochastic %K crosses %D
//                      long  -> K[2] <= D[2] AND K[1] > D[1]
//                      short -> K[2] >= D[2] AND K[1] < D[1]
//     TREND    STATE : EMA(6) vs EMA(23) on the closed bar
//                      long  -> ema6 > ema23   short -> ema6 < ema23
//     MOMENTUM STATE : slow MACD(30,60,30) main line side
//                      long  -> macd_main > 0  short -> macd_main < 0
//
//   The card lists the EMA6/23 cross AND the Stochastic cross AND the MACD
//   side. Requiring TWO fresh crossovers on the same bar almost never fires;
//   the Stochastic cross is the short-term timing trigger and the EMA stack
//   (medium trend) + slow-MACD side (medium momentum) are read as persistent
//   states — the literal "all three align" reading without the dead-bar trap.
//
//   Stop Loss   : fixed 25 pips (card: 20-30, factory default 25).
//   Take Profit : fixed 55 pips (card: 50-60, factory default 55).
//   Exit        : managed by the fixed SL/TP; whichever is hit first.
//   Spread guard: skip only a genuinely wide spread (fail-open on .DWX zero
//                 modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11789;
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
input int    strategy_ema_fast_period   = 6;      // fast EMA (trend state)
input int    strategy_ema_slow_period   = 23;     // slow EMA (trend state)
input int    strategy_stoch_k           = 5;      // Stochastic %K period
input int    strategy_stoch_d           = 3;      // Stochastic %D period
input int    strategy_stoch_slowing     = 3;      // Stochastic slowing
input int    strategy_macd_fast         = 30;     // slow-MACD fast EMA
input int    strategy_macd_slow         = 60;     // slow-MACD slow EMA
input int    strategy_macd_signal       = 30;     // slow-MACD signal SMA
input int    strategy_sl_pips           = 25;     // fixed stop loss (pips)
input int    strategy_tp_pips           = 55;     // fixed take profit (pips)
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — signal work is on the
// closed-bar path in Strategy_EntrySignal. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_pips);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Triple-confirmed entry. Caller guarantees QM_IsNewBar() == true (closed bar).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- TREND STATE: EMA(6) vs EMA(23) on the closed bar ---
   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   if(ema_fast <= 0.0 || ema_slow <= 0.0)
      return false;
   const bool trend_long  = (ema_fast > ema_slow);
   const bool trend_short = (ema_fast < ema_slow);
   if(!trend_long && !trend_short)
      return false;

   // --- MOMENTUM STATE: slow MACD(30,60,30) main line side ---
   const double macd_main = QM_MACD_Main(_Symbol, _Period,
                                         strategy_macd_fast, strategy_macd_slow,
                                         strategy_macd_signal, 1);
   const bool macd_long  = (macd_main > 0.0);
   const bool macd_short = (macd_main < 0.0);

   // --- TRIGGER EVENT: Stochastic %K crosses %D (the one fresh crossover) ---
   // K/D at shift 1 (last closed bar) vs shift 2 (prior closed bar).
   const double k_now  = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 1);
   const double d_now  = QM_Stoch_D(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 1);
   const double k_prev = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 2);
   const double d_prev = QM_Stoch_D(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 2);
   if(k_now <= 0.0 || d_now <= 0.0 || k_prev <= 0.0 || d_prev <= 0.0)
      return false;

   const bool stoch_cross_up   = (k_prev <= d_prev && k_now > d_now);
   const bool stoch_cross_down = (k_prev >= d_prev && k_now < d_now);

   // --- Combine: trigger + both confirming states must align ---
   QM_OrderType side;
   if(stoch_cross_up && trend_long && macd_long)
      side = QM_BUY;
   else if(stoch_cross_down && trend_short && macd_short)
      side = QM_SELL;
   else
      return false;

   // --- Build the entry. Framework sizes lots (no lots field). ---
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopFixedPips(_Symbol, side, entry, strategy_sl_pips);
   const double tp = QM_TakeFixedPips(_Symbol, side, entry, strategy_tp_pips);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (side == QM_BUY) ? "carter_s3_long" : "carter_s3_short";
   return true;
  }

// Fixed SL/TP only — no active management.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit; the fixed SL/TP closes the trade.
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
