#property strict
#property version   "5.0"
#property description "QM5_11628 cat-dualma — Catalyst Dual Moving Average cross (long-only, M1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11628 cat-dualma
// -----------------------------------------------------------------------------
// Source: Enigma MPC scrtlabs/catalyst, catalyst/examples/dual_moving_average.py
//   https://github.com/scrtlabs/catalyst/blob/master/catalyst/examples/dual_moving_average.py
// Card: artifacts/cards_approved/QM5_11628_cat-dualma.md (g0_status APPROVED).
//
// Mechanics (long-only, closed-bar reads at shift 1 vs 2, M1 timeframe):
//   Trigger EVENT (entry): SMA(fast) crosses ABOVE SMA(slow). ONE cross only —
//                          prev bar fast<=slow, this bar fast>slow. Not a state.
//   Exit EVENT           : SMA(fast) crosses BELOW SMA(slow) -> close manually.
//   Stop                 : source has NO protective stop; V5 adds an ATR
//                          catastrophic stop (entry - sl_atr_mult * ATR).
//   Take profit          : none — the source holds exposure until the bearish
//                          cross. The cross-down exit is the structural close.
//   Sizing               : framework RISK_FIXED ($1000 backtest) via SL distance.
//   Spread guard         : skip only a genuinely wide spread (> spread_pct_of_stop
//                          of the stop distance). Fail-open on .DWX zero spread.
//
// Two-cross trap avoided: the bullish cross is the SOLE entry trigger; there is
// no second simultaneous cross/oscillator condition. One event per bar.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11628;
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
input int    strategy_sma_fast_period    = 50;    // fast SMA period (cross trigger)
input int    strategy_sma_slow_period    = 200;   // slow SMA period (cross trigger)
input int    strategy_atr_period         = 14;    // ATR period for catastrophic stop
input double strategy_sl_atr_mult        = 3.0;   // catastrophic stop = mult * ATR
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — cross logic is on the closed-bar
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

// Long-only entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
// Trigger EVENT: SMA(fast) crosses above SMA(slow) — one cross only.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic; no pyramiding.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Dual-SMA cross (closed bars): prev = shift 2, now = shift 1. ---
   const double fast_now  = QM_SMA(_Symbol, _Period, strategy_sma_fast_period, 1);
   const double slow_now  = QM_SMA(_Symbol, _Period, strategy_sma_slow_period, 1);
   const double fast_prev = QM_SMA(_Symbol, _Period, strategy_sma_fast_period, 2);
   const double slow_prev = QM_SMA(_Symbol, _Period, strategy_sma_slow_period, 2);
   if(fast_now <= 0.0 || slow_now <= 0.0 || fast_prev <= 0.0 || slow_prev <= 0.0)
      return false;

   // Trigger EVENT: a fresh bullish cross. ONE event per bar.
   const bool crossed_up = (fast_prev <= slow_prev && fast_now > slow_now);
   if(!crossed_up)
      return false;

   // --- ATR catastrophic stop (V5 addition; source has none). ---
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
   req.tp     = 0.0;   // no take-profit; bearish cross is the structural exit
   req.reason = "cat_dualma_cross_long";
   return true;
  }

// No active trade management beyond the fixed ATR catastrophic stop. The
// structural exit (bearish SMA cross) lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Structural exit EVENT: SMA(fast) crosses BELOW SMA(slow). One event at shift 1.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const double fast_now  = QM_SMA(_Symbol, _Period, strategy_sma_fast_period, 1);
   const double slow_now  = QM_SMA(_Symbol, _Period, strategy_sma_slow_period, 1);
   const double fast_prev = QM_SMA(_Symbol, _Period, strategy_sma_fast_period, 2);
   const double slow_prev = QM_SMA(_Symbol, _Period, strategy_sma_slow_period, 2);
   if(fast_now <= 0.0 || slow_now <= 0.0 || fast_prev <= 0.0 || slow_prev <= 0.0)
      return false;

   const bool crossed_down = (fast_prev >= slow_prev && fast_now < slow_now);
   return crossed_down;
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
