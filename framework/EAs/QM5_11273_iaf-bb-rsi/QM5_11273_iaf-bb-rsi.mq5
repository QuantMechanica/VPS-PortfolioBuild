#property strict
#property version   "5.0"
#property description "QM5_11273 iaf-bb-rsi — Bollinger/RSI mean reversion (long-only, D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11273 iaf-bb-rsi
// -----------------------------------------------------------------------------
// Source: coding-kitties/investing-algorithm-framework,
//   examples/strategies_showcase/02_mean_reversion/strategy.py.
// Card: artifacts/cards_approved/QM5_11273_iaf-bb-rsi.md (g0_status APPROVED).
//
// Mechanics (long-only, mean reversion, closed-bar reads at shift 1):
//   Entry STATE : flat AND close < lower_BB(period, deviation)
//                 AND RSI(rsi_period) < rsi_oversold.
//   Exit  STATE : close > middle_BB(period, deviation) OR RSI > rsi_overbought.
//   Stop        : entry - sl_atr_mult * ATR(atr_period)  (catastrophic only;
//                 the source has no stop — V5 adds a 2.0*ATR safety stop).
//   Take profit : none (exit is the mid-band / RSI overbought rule). The ATR
//                 stop is the sole hard bracket.
//   Spread guard: skip only a genuinely wide spread > spread_pct_of_stop of
//                 the stop distance (fail-open on .DWX zero modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11273;
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
input int    strategy_bb_period          = 20;    // Bollinger Bands period
input double strategy_bb_deviation       = 2.0;   // Bollinger Bands std-dev multiplier
input int    strategy_rsi_period         = 14;    // RSI lookback period
input double strategy_rsi_oversold       = 30.0;  // long entry: RSI below this
input double strategy_rsi_overbought     = 70.0;  // exit: RSI above this
input int    strategy_atr_period         = 14;    // ATR period for the safety stop
input double strategy_sl_atr_mult        = 2.0;   // catastrophic stop distance = mult * ATR
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — entry/exit work is on the
// closed-bar path. Fail-open on .DWX zero modeled spread.
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

// Long-only mean-reversion entry. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Entry STATE: close below the lower Bollinger band (closed bar) ---
   const double lower_bb = QM_BB_Lower(_Symbol, _Period, strategy_bb_period,
                                       strategy_bb_deviation, 1);
   if(lower_bb <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;
   if(!(close1 < lower_bb))
      return false;

   // --- Entry STATE: RSI oversold confirmation ---
   const double rsi_now = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(rsi_now <= 0.0)
      return false;
   if(!(rsi_now < strategy_rsi_oversold))
      return false;

   // --- Build the long entry. Framework sizes lots (no lots field). ---
   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;

   req.type   = QM_BUY;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;   // no fixed TP; exit via mid-band / RSI overbought rule
   req.reason = "bb_rsi_mr_long";
   return true;
  }

// No active trade management beyond the fixed ATR safety stop. The discretionary
// mean-reversion exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Exit: close above the Bollinger mid-band OR RSI overbought. Closed-bar reads.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const double mid_bb = QM_BB_Middle(_Symbol, _Period, strategy_bb_period,
                                      strategy_bb_deviation, 1);
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double rsi_now = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(mid_bb <= 0.0 || close1 <= 0.0 || rsi_now <= 0.0)
      return false;

   if(close1 > mid_bb)
      return true;
   if(rsi_now > strategy_rsi_overbought)
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
