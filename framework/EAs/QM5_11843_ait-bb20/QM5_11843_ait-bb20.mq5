#property strict
#property version   "5.0"
#property description "QM5_11843 ait-bb20 — Bollinger(20,2) lower-band reversion (long-only, D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11843 ait-bb20
// -----------------------------------------------------------------------------
// Source: whchien/ai-trader, ai_trader/backtesting/strategies/classic/bbands.py,
//         BBandsStrategy. Card: artifacts/cards_approved/QM5_11843_ait-bb20.md
//         (g0_status APPROVED).
//
// Mechanics (long-only, closed-bar reads at shift 1; deviation arg mandatory):
//   Bollinger : period 20, deviation 2.0 on D1 close.
//   Entry EVENT : close PENETRATES the lower band — close[2] >= lower[2] AND
//                 close[1] < lower[1]. The penetration is the fresh trigger
//                 (one event per dip); a persistent "close below band" STATE
//                 would re-fire every bar while price walks the lower band, so
//                 we require the cross-from-inside to below.
//   Exit  EVENT : close above the upper band — close[1] > upper[1] (mean
//                 reversion complete). This is the source's defined exit.
//   Stop        : entry - sl_atr_mult * ATR(period) hard stop (card P2 baseline,
//                 source defines none). No fixed TP: the upper-band close is the
//                 profit target, so req.tp = 0 and Strategy_ExitSignal closes.
//   Warmup      : Bollinger needs >= bb_period bars; framework feeds history.
//   Spread guard: skip only a genuinely wide spread > spread_pct_of_stop of the
//                 stop distance (fail-open on .DWX zero modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11843;
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
input int    strategy_bb_period          = 20;    // Bollinger period
input double strategy_bb_deviation       = 2.0;   // Bollinger deviation factor
input int    strategy_atr_period         = 14;    // ATR period for the protective stop
input double strategy_sl_atr_mult        = 2.0;   // stop distance = mult * ATR
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — band/signal work is on the
// closed-bar path in Strategy_EntrySignal. Fail-open on .DWX zero spread.
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

// Long-only entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Bollinger lower band on the two most recent closed bars ---
   // deviation arg is MANDATORY (omitting it would shift the other args).
   const double lower_prev = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 2);
   const double lower_now  = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   if(lower_prev <= 0.0 || lower_now <= 0.0)
      return false;

   const double close_prev = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   const double close_now  = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close_prev <= 0.0 || close_now <= 0.0)
      return false;

   // --- Entry EVENT: fresh penetration of the lower band. close was at-or-above
   //     the lower band on the prior bar and is below it now. The cross is the
   //     trigger (one event per dip); a standing "below band" STATE would re-fire
   //     every bar while price walks below the band.
   const bool penetrated = (close_prev >= lower_prev && close_now < lower_now);
   if(!penetrated)
      return false;

   // --- Protective stop from ATR (source defines no stop; card P2 baseline) ---
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;

   req.type   = QM_BUY;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;   // no fixed TP — upper-band close exit is the target
   req.reason = "bb20_lower_reversion_long";
   return true;
  }

// No active management beyond the fixed ATR stop. Exit is the upper-band close,
// handled in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Exit EVENT: close above the upper Bollinger band (mean reversion complete).
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const double upper_now = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   if(upper_now <= 0.0)
      return false;

   const double close_now = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close_now <= 0.0)
      return false;

   return (close_now > upper_now);
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
