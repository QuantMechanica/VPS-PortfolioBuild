#property strict
#property version   "5.0"
#property description "QM5_11192 ft-bandtastic — Bollinger mean-reversion long (M15)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11192 ft-bandtastic
// -----------------------------------------------------------------------------
// Source: Robert Roman, Bandtastic.py, freqtrade-strategies (GitHub).
// Card: artifacts/cards_approved/QM5_11192_ft-bandtastic.md (g0_status APPROVED).
//
// Mechanics (long-only mean reversion, closed-bar reads at shift 1):
//   Entry  EVENT : Close(1) < lower Bollinger Band(20, bb_entry_std). The source
//                  "volume > 0" guard is a no-op on .DWX (tick volume is always
//                  positive on closed bars) and is therefore omitted. Source
//                  defaults disable the RSI / MFI / EMA buy guards; an OPTIONAL
//                  RSI buy guard is provided (off by default) for the P3 sweep.
//   Exit   STATE : MFI(14) > mfi_exit  AND  Close(1) > upper BB(20, bb_exit_std).
//                  Both source signal-exit conditions must hold (logical AND).
//   Stop         : QM_StopATR(atr_period, atr_stop_mult) — MT5 baseline per card
//                  (the source -34.5% stoploss is a crypto figure, not ported).
//   Spread guard : skip only a genuinely wide spread (fail-open on .DWX zero
//                  modeled spread).
//
// The source ROI ladder and 1% trailing-after-5.8% offset are crypto-tuned and
// expressed as percentage-of-price; the card's MT5 baseline replaces them with
// the ATR stop above plus the deterministic MFI/Bollinger signal exit. No TP is
// set — the position closes on the signal exit or the ATR stop.
//
// MFI is computed on TICK volume (QM_MFI) because .DWX symbols carry no real
// exchange volume in the tester (card: "map exchange volume to tick volume").
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11192;
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
input int    strategy_bb_period          = 20;    // Bollinger period (source: 20)
input double strategy_bb_entry_std       = 1.0;   // lower-band deviation for entry (source: 1)
input double strategy_bb_exit_std        = 2.0;   // upper-band deviation for exit (source: 2)
input int    strategy_mfi_period         = 14;    // MFI period (source: 14)
input double strategy_mfi_exit           = 46.0;  // MFI exit threshold (source: 46)
input bool   strategy_enable_rsi_guard   = false; // source default: RSI buy guard off
input int    strategy_rsi_period         = 14;    // RSI period for optional buy guard
input double strategy_rsi_guard_max      = 50.0;  // if guard on: require RSI(1) < this
input int    strategy_atr_period         = 14;    // ATR period for the stop
input double strategy_atr_stop_mult      = 2.0;   // stop distance = mult * ATR
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

   const double stop_distance = strategy_atr_stop_mult * atr_value;
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

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   // --- Entry EVENT: close below the lower Bollinger band (mean reversion) ---
   const double bb_lower = QM_BB_Lower(_Symbol, _Period, strategy_bb_period,
                                       strategy_bb_entry_std, 1);
   if(bb_lower <= 0.0)
      return false;
   if(!(close1 < bb_lower))
      return false;

   // --- Optional RSI buy guard (source default OFF). Require RSI below max. ---
   if(strategy_enable_rsi_guard)
     {
      const double rsi1 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
      if(rsi1 <= 0.0)
         return false;
      if(!(rsi1 < strategy_rsi_guard_max))
         return false;
     }

   // --- Build the long entry. Framework sizes lots (no lots field). ---
   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, QM_BUY, entry, strategy_atr_period,
                                strategy_atr_stop_mult);
   if(sl <= 0.0)
      return false;

   req.type   = QM_BUY;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;   // no fixed TP — exit on signal or ATR stop
   req.reason = "bandtastic_bb_long";
   return true;
  }

// No active trade management beyond the fixed ATR stop. Signal exit is in
// Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Signal exit (source AND of both conditions): MFI above threshold AND close
// above the upper Bollinger band. Evaluated on the closed bar.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const double mfi1 = QM_MFI(_Symbol, _Period, strategy_mfi_period, 1);
   if(mfi1 <= 0.0)
      return false;
   if(!(mfi1 > strategy_mfi_exit))
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   const double bb_upper = QM_BB_Upper(_Symbol, _Period, strategy_bb_period,
                                       strategy_bb_exit_std, 1);
   if(bb_upper <= 0.0)
      return false;

   return (close1 > bb_upper);
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
