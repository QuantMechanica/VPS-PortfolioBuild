#property strict
#property version   "5.0"
#property description "QM5_11816 carter-m5-s3-bb20-stoch-trend-reversal-m5 — BB(20) band extreme + Stoch reversal, trend-filtered (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11816 carter-m5-s3-bb20-stoch-trend-reversal-m5
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)",
//         2014, Strategy 3.
// Card: artifacts/cards_approved/QM5_11816_carter-m5-s3-bb20-stoch-trend-reversal-m5.md
//       (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; M5):
//   Trend STATE (filter): BB(period) midline slope. Rising midline
//                         (bbmid[1] > bbmid[3]) = uptrend -> longs only.
//                         Falling (bbmid[1] < bbmid[3]) = downtrend -> shorts only.
//   Overextension STATE : Long  -> prior bar low pierced the BB lower band
//                         (Low[1] <= BB_Lower[1]).
//                         Short -> prior bar high pierced the BB upper band
//                         (High[1] >= BB_Upper[1]).
//   Trigger EVENT (single): Stochastic(%K) crosses back OUT of the extreme.
//                         Long  -> K[2] <= os_level AND K[1] > os_level.
//                         Short -> K[2] >= ob_level AND K[1] < ob_level.
//   The Stoch cross is the only EVENT; band-pierce + trend are STATES — they are
//   never required to coincide as two same-bar cross events (two-cross trap).
//   Stop        : QM_StopATR, sl_atr_mult * ATR(atr_period).
//   Take profit : QM_TakeRR at tp_rr (RR multiple of the stop distance; with
//                 sl_atr_mult=2 / tp_rr=2 this equals the card's 4*ATR target).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11816;
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
input int    strategy_bb_period         = 20;     // Bollinger Band period
input double strategy_bb_deviation      = 2.0;    // Bollinger Band deviation
input int    strategy_stoch_k           = 5;      // Stochastic %K period
input int    strategy_stoch_d           = 3;      // Stochastic %D period
input int    strategy_stoch_slowing     = 3;      // Stochastic slowing
input double strategy_stoch_oversold    = 20.0;   // Stochastic oversold threshold
input double strategy_stoch_overbought  = 80.0;   // Stochastic overbought threshold
input int    strategy_trend_lookback    = 2;      // midline slope lookback (bars before shift 1)
input int    strategy_atr_period        = 14;     // ATR period for stop/target
input double strategy_sl_atr_mult       = 2.0;    // stop distance = mult * ATR
input double strategy_tp_rr             = 2.0;    // take-profit RR multiple of the stop
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

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

// Reversal entry (both directions). Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Bollinger bands at the prior closed bar (deviation arg mandatory) ---
   const double bb_upper = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double bb_lower = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   if(bb_upper <= 0.0 || bb_lower <= 0.0)
      return false;

   // --- Trend STATE: BB midline slope over the trend lookback window ---
   const double bb_mid_now  = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double bb_mid_prev = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation,
                                           1 + strategy_trend_lookback);
   if(bb_mid_now <= 0.0 || bb_mid_prev <= 0.0)
      return false;
   const bool trend_up   = (bb_mid_now > bb_mid_prev);
   const bool trend_down = (bb_mid_now < bb_mid_prev);

   // --- Overextension STATE: prior bar pierced a band (perf-allowed single reads) ---
   const double low1  = iLow(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read
   const double high1 = iHigh(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(low1 <= 0.0 || high1 <= 0.0)
      return false;
   const bool pierced_lower = (low1  <= bb_lower);
   const bool pierced_upper = (high1 >= bb_upper);

   // --- Trigger EVENT: single Stochastic %K cross out of the extreme zone ---
   const double k_now  = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d,
                                    strategy_stoch_slowing, 1);
   const double k_prev = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d,
                                    strategy_stoch_slowing, 2);
   if(k_now < 0.0 || k_prev < 0.0)
      return false;
   const bool cross_up_oversold   = (k_prev <= strategy_stoch_oversold &&
                                     k_now  >  strategy_stoch_oversold);
   const bool cross_down_overbought = (k_prev >= strategy_stoch_overbought &&
                                       k_now  <  strategy_stoch_overbought);

   // --- Compose: long fade in an uptrend, short fade in a downtrend ---
   const bool long_setup  = trend_up   && pierced_lower && cross_up_oversold;
   const bool short_setup = trend_down && pierced_upper && cross_down_overbought;
   if(!long_setup && !short_setup)
      return false;

   const QM_OrderType side = long_setup ? QM_BUY : QM_SELL;
   const double entry = long_setup ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = long_setup ? "bb_stoch_rev_long" : "bb_stoch_rev_short";
   return true;
  }

// Fixed ATR stop/target only; no active management.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit beyond SL/TP (TP = opposite-band proxy via RR).
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
