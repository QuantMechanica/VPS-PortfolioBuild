#property strict
#property version   "5.0"
#property description "QM5_11704 fsr-macd-stoch-m5-scalp — MACD-state + Stochastic-cross M5 scalp"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11704 fsr-macd-stoch-m5-scalp
// -----------------------------------------------------------------------------
// Source: Anonymous, "M1/M5 Forex Scalping Strategy", self-published PDF (~2014).
// Card: artifacts/cards_approved/QM5_11704_fsr-macd-stoch-m5-scalp.md (g0 APPROVED).
//
// Mechanics (M5, closed-bar reads at shift 1):
//   MACD establishes trend direction (STATE, the confirming filter);
//   Stochastic identifies the reversal out of an extreme zone (EVENT, the trigger).
//
//   Trigger EVENT (one per bar): Stochastic %K crosses BACK over the OB/OS level.
//     Long : %K[2] < os_level  AND  %K[1] >= os_level   (cross up out of oversold)
//     Short: %K[2] > ob_level  AND  %K[1] <= ob_level   (cross down out of overbought)
//   Confirming STATE: MACD main line sign on the same closed bar.
//     Long  needs MACD_Main[1] > 0  (bullish trend).
//     Short needs MACD_Main[1] < 0  (bearish trend).
//
//   This is deliberately ONE event + ONE state, never two fresh crosses on the
//   same bar (the .DWX two-cross zero-trade trap). The MACD sign is a level
//   STATE, not a fresh MACD crossover event.
//
//   Stop loss   : factory default 2 x ATR(14, M5).
//   Take profit : fixed pip target (card: 25 pips on M5), pip-scaled to price.
//   Exit        : SL or TP only (no discretionary close).
//   Spread guard: skip only a genuinely wide spread (fail-open on .DWX 0 spread).
//
// Symbols: EURUSD.DWX, GBPUSD.DWX — both present in dwx_symbol_matrix.csv (no port).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11704;
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
input int    strategy_macd_fast         = 12;     // MACD fast EMA
input int    strategy_macd_slow         = 26;     // MACD slow EMA
input int    strategy_macd_signal       = 9;      // MACD signal SMA
input int    strategy_stoch_k           = 8;      // Stochastic %K period (non-standard, per source)
input int    strategy_stoch_d           = 3;      // Stochastic %D period
input int    strategy_stoch_slowing     = 3;      // Stochastic slowing
input double strategy_stoch_oversold    = 20.0;   // oversold level (long trigger)
input double strategy_stoch_overbought  = 80.0;   // overbought level (short trigger)
input int    strategy_atr_period        = 14;     // ATR period for the stop
input double strategy_sl_atr_mult       = 2.0;    // stop distance = mult * ATR
input double strategy_tp_pips           = 25.0;   // fixed take-profit in pips
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — signal work is on the closed-bar
// path in Strategy_EntrySignal. Fail-open on .DWX zero modeled spread.
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

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
// EVENT = Stochastic %K cross out of OB/OS; STATE = MACD line sign.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Confirming STATE: MACD main line sign on the last closed bar ---
   const double macd_main = QM_MACD_Main(_Symbol, _Period,
                                         strategy_macd_fast, strategy_macd_slow,
                                         strategy_macd_signal, 1);

   // --- Trigger EVENT: Stochastic %K cross of the OB/OS level (one per bar) ---
   // Use %K at shift 1 (just-closed bar) vs shift 2 (prior closed bar).
   const double k_now  = QM_Stoch_K(_Symbol, _Period,
                                    strategy_stoch_k, strategy_stoch_d,
                                    strategy_stoch_slowing, 1);
   const double k_prev = QM_Stoch_K(_Symbol, _Period,
                                    strategy_stoch_k, strategy_stoch_d,
                                    strategy_stoch_slowing, 2);
   if(k_now <= 0.0 || k_prev <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double tp_distance = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_tp_pips);
   if(tp_distance <= 0.0)
      return false;

   // LONG: %K crossed up out of oversold AND MACD line bullish (>0).
   const bool long_cross = (k_prev <  strategy_stoch_oversold &&
                            k_now  >= strategy_stoch_oversold);
   if(long_cross && macd_main > 0.0)
     {
      const double entry = ask;
      const double sl    = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
      const double tp    = QM_StopRulesNormalizePrice(_Symbol, entry + tp_distance);
      if(sl <= 0.0 || tp <= 0.0)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "macd_stoch_long";
      return true;
     }

   // SHORT: %K crossed down out of overbought AND MACD line bearish (<0).
   const bool short_cross = (k_prev >  strategy_stoch_overbought &&
                             k_now  <= strategy_stoch_overbought);
   if(short_cross && macd_main < 0.0)
     {
      const double entry = bid;
      const double sl    = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_sl_atr_mult);
      const double tp    = QM_StopRulesNormalizePrice(_Symbol, entry - tp_distance);
      if(sl <= 0.0 || tp <= 0.0)
         return false;

      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "macd_stoch_short";
      return true;
     }

   return false;
  }

// Fixed ATR stop / fixed-pip target only — no active management.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit; positions close on SL or TP.
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
