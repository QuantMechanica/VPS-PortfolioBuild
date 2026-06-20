#property strict
#property version   "5.0"
#property description "QM5_11420 macd-stochastic-pullback-scalp-m5 — MACD-state + Stochastic pullback-recovery EVENT (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11420 macd-stochastic-pullback-scalp-m5
// -----------------------------------------------------------------------------
// Source: "M1/M5 Forex Scalping Trading Strategy" (anonymous, XM affiliate PDF).
// Card: artifacts/cards_approved/QM5_11420_macd-stochastic-pullback-scalp-m5.md
//       (g0_status: APPROVED).
//
// Mechanics (closed-bar reads, shift 1 = last closed bar):
//   MACD STATE  : MACD main line sign confirms momentum direction. It is a
//                 STATE, not an event — MACD can be negative for SHORTs.
//                   LONG  regime: MACD_main(1) > 0
//                   SHORT regime: MACD_main(1) < 0
//   Stoch EVENT : The single trigger is the Stochastic %K crossing back through
//                 the oversold/overbought boundary (pullback exhaustion):
//                   LONG  : %K(2) < 20  AND  %K(1) >= 20   (recovery up out of OS)
//                   SHORT : %K(2) > 80  AND  %K(1) <= 80   (recovery down out of OB)
//                 Only ONE event is required per side; MACD is the co-incident
//                 state. This avoids the two-cross-same-bar zero-trade trap.
//   Stop        : ATR(14, M5) * 1.5 from entry, capped at sl_cap_pips.
//   Take profit : fixed tp_pips (25) from entry.
//   Optional H1 : if strategy_use_h1_filter, require H1 MACD main agree in sign.
//
// .DWX invariants honoured: spread guard fails OPEN on zero modeled spread; no
// swap gate; QM_IsNewBar consumed once (framework OnTick); broker-time only via
// framework; no external feed. Only the 5 Strategy_* hooks + Strategy inputs are
// EA-specific; everything else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11420;
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
input int    strategy_macd_fast         = 12;     // MACD fast EMA period
input int    strategy_macd_slow         = 26;     // MACD slow EMA period
input int    strategy_macd_signal       = 9;      // MACD signal SMA period
input int    strategy_stoch_k           = 8;      // Stochastic %K period
input int    strategy_stoch_d           = 3;      // Stochastic %D period
input int    strategy_stoch_slowing     = 3;      // Stochastic slowing
input double strategy_stoch_os          = 20.0;   // oversold boundary (LONG trigger)
input double strategy_stoch_ob          = 80.0;   // overbought boundary (SHORT trigger)
input int    strategy_atr_period        = 14;     // ATR period for the stop
input double strategy_sl_atr_mult       = 1.5;    // stop distance = mult * ATR
input int    strategy_sl_cap_pips       = 25;     // cap the ATR stop at this many pips
input int    strategy_tp_pips           = 25;     // fixed take-profit distance (pips)
input bool   strategy_use_h1_filter     = false;  // optional H1 MACD sign agreement
input double strategy_spread_cap_pips   = 15.0;   // skip only genuinely wide spread

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — fail OPEN on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   if(strategy_spread_cap_pips <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote — do not block on it

   const double spread = ask - bid;
   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_spread_cap_pips);
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(cap > 0.0 && spread > 0.0 && spread > cap)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate, single-consume).
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

   if(strategy_macd_fast <= 0 || strategy_macd_slow <= 0 || strategy_macd_signal <= 0 ||
      strategy_stoch_k <= 0 || strategy_stoch_d <= 0 || strategy_stoch_slowing <= 0 ||
      strategy_atr_period <= 0 || strategy_sl_atr_mult <= 0.0)
      return false;

   // --- MACD STATE (sign of the main line on the last closed bar) ---
   const double macd_main = QM_MACD_Main(_Symbol, _Period,
                                         strategy_macd_fast, strategy_macd_slow,
                                         strategy_macd_signal, 1);

   // --- Stochastic %K, last two closed bars (the cross EVENT) ---
   const double k_now  = QM_Stoch_K(_Symbol, _Period,
                                    strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 1);
   const double k_prev = QM_Stoch_K(_Symbol, _Period,
                                    strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 2);
   if(k_now <= 0.0 && k_prev <= 0.0)
      return false; // no Stochastic data yet

   // --- ATR for the protective stop ---
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // Optional H1 MACD sign filter (state, same fast/slow/signal periods).
   double h1_macd = 0.0;
   if(strategy_use_h1_filter)
      h1_macd = QM_MACD_Main(_Symbol, PERIOD_H1,
                             strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);

   // LONG: MACD positive state + %K crosses back UP through oversold boundary.
   const bool long_event  = (k_prev < strategy_stoch_os && k_now >= strategy_stoch_os);
   const bool short_event = (k_prev > strategy_stoch_ob && k_now <= strategy_stoch_ob);

   if(macd_main > 0.0 && long_event && (!strategy_use_h1_filter || h1_macd > 0.0))
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;

      double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
      // Cap the stop distance at sl_cap_pips (closer of the two stops).
      if(strategy_sl_cap_pips > 0)
        {
         const double capped = QM_StopFixedPips(_Symbol, QM_BUY, entry, strategy_sl_cap_pips);
         if(capped > 0.0 && capped > sl)   // for a BUY, the tighter stop is the higher price
            sl = capped;
        }
      const double tp = QM_TakeFixedPips(_Symbol, QM_BUY, entry, strategy_tp_pips);
      if(sl <= 0.0 || tp <= 0.0)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "macd_pos_stoch_os_recovery_long";
      return true;
     }

   if(macd_main < 0.0 && short_event && (!strategy_use_h1_filter || h1_macd < 0.0))
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;

      double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_sl_atr_mult);
      if(strategy_sl_cap_pips > 0)
        {
         const double capped = QM_StopFixedPips(_Symbol, QM_SELL, entry, strategy_sl_cap_pips);
         if(capped > 0.0 && capped < sl)   // for a SELL, the tighter stop is the lower price
            sl = capped;
        }
      const double tp = QM_TakeFixedPips(_Symbol, QM_SELL, entry, strategy_tp_pips);
      if(sl <= 0.0 || tp <= 0.0)
         return false;

      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "macd_neg_stoch_ob_recovery_short";
      return true;
     }

   return false;
  }

// Fixed ATR stop + fixed TP only; no trailing / break-even / partial close.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit — the position is managed by its SL/TP only.
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
