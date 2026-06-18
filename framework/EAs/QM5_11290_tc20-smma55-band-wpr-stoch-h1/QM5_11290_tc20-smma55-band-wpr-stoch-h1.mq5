#property strict
#property version   "5.0"
#property description "QM5_11290 tc20-smma55-band-wpr-stoch-h1 — SMMA(55) High/Low band + WPR(55) trigger + Stoch state (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11290 tc20-smma55-band-wpr-stoch-h1
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)",
//   Strategy #5. Card: artifacts/cards_approved/QM5_11290_tc20-smma55-band-wpr-stoch-h1.md
//   (g0_status APPROVED). source_id e78a9f1f-4e6a-563c-a080-915133d6ed28.
//
// Mechanics (conservative entry only, closed-bar reads at shift 1):
//   Two SMMA(55) lines on PRICE_HIGH and PRICE_LOW form a price channel.
//
//   Multi-indicator confluence — ONE trigger EVENT, the rest are STATES
//   (per .DWX invariant #4: two fresh crosses on one bar almost never coincide):
//     Trigger EVENT (LONG) : WPR(55) crosses UP through -25 (prev<=-25, now>-25).
//     STATE 1       (LONG) : closed bar above the upper band -> close[1] > SMMA(55,HIGH).
//     STATE 2       (LONG) : Stochastic(5,5,5) %K > %D (momentum aligned up).
//   SHORT mirrors: WPR crosses DOWN through -75, close[1] < SMMA(55,LOW), %K < %D.
//
//   Stop          : ATR(14) * sl_atr_mult (card P2: 1.5).
//   Take profit   : RR multiple of the stop distance (card: TP = 2 x SL).
//   Conservative exit (LONG): close[1] back below SMMA(55,HIGH); mirror for SHORT.
//   Spread guard  : skip only a genuinely wide spread > spread_cap_pips
//                   (fail-OPEN on .DWX zero modeled spread).
//
// One position per magic. RISK_FIXED in tester, RISK_PERCENT for live.
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11290;
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
input int    strategy_smma_period       = 55;     // SMMA period on High and Low
input int    strategy_wpr_period        = 55;     // Williams %R period (trigger)
input double strategy_wpr_long_level    = -25.0;  // WPR cross-up level for LONG
input double strategy_wpr_short_level   = -75.0;  // WPR cross-down level for SHORT
input int    strategy_stoch_k           = 5;      // Stochastic %K period
input int    strategy_stoch_d           = 5;      // Stochastic %D period
input int    strategy_stoch_slowing     = 5;      // Stochastic slowing
input int    strategy_atr_period        = 14;     // ATR period for the stop
input double strategy_sl_atr_mult       = 1.5;    // stop distance = mult * ATR
input double strategy_tp_rr             = 2.0;    // take-profit = RR x stop distance
input double strategy_spread_cap_pips   = 20.0;   // skip if spread wider than this (pips)

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-OPEN on .DWX zero spread:
// only a genuinely wide spread blocks; ask==bid (0 modeled spread) passes.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double cap_price = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_spread_cap_pips);
   if(cap_price <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(ask > bid && spread > cap_price)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- SMMA(55) High/Low band (closed bar, shift 1) ---
   const double smma_high = QM_SMMA(_Symbol, _Period, strategy_smma_period, 1, PRICE_HIGH);
   const double smma_low  = QM_SMMA(_Symbol, _Period, strategy_smma_period, 1, PRICE_LOW);
   if(smma_high <= 0.0 || smma_low <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   // --- WPR(55) trigger EVENT: fresh cross of the level (shift 2 -> shift 1) ---
   const double wpr_now  = QM_WPR(_Symbol, _Period, strategy_wpr_period, 1);
   const double wpr_prev = QM_WPR(_Symbol, _Period, strategy_wpr_period, 2);
   // WPR range is [-100, 0]; 0.0 is a legal value, so guard only the degenerate
   // out-of-range read (handle warmup returns 0.0 for BOTH shifts -> no cross).

   // --- Stochastic(5,5,5) state: %K vs %D alignment (closed bar) ---
   const double stoch_k = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 1);
   const double stoch_d = QM_Stoch_D(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 1);

   // === LONG ===
   const bool wpr_cross_up = (wpr_prev <= strategy_wpr_long_level &&
                              wpr_now  >  strategy_wpr_long_level);
   const bool long_band    = (close1 > smma_high);          // STATE: above upper band
   const bool long_stoch   = (stoch_k > stoch_d);           // STATE: momentum up
   if(wpr_cross_up && long_band && long_stoch)
     {
      const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
      if(atr_value <= 0.0)
         return false;
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
      if(sl <= 0.0)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_tp_rr);
      if(tp <= 0.0)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "smma_band_wpr_stoch_long";
      return true;
     }

   // === SHORT (mirror) ===
   const bool wpr_cross_dn = (wpr_prev >= strategy_wpr_short_level &&
                              wpr_now  <  strategy_wpr_short_level);
   const bool short_band   = (close1 < smma_low);           // STATE: below lower band
   const bool short_stoch  = (stoch_k < stoch_d);           // STATE: momentum down
   if(wpr_cross_dn && short_band && short_stoch)
     {
      const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
      if(atr_value <= 0.0)
         return false;
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_sl_atr_mult);
      if(sl <= 0.0)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_tp_rr);
      if(tp <= 0.0)
         return false;

      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "smma_band_wpr_stoch_short";
      return true;
     }

   return false;
  }

// Fixed ATR stop / RR take-profit only; no active trade management.
void Strategy_ManageOpenPosition()
  {
  }

// Conservative exit: price closes back inside the band.
//   LONG  closes when close[1] < SMMA(55,HIGH).
//   SHORT closes when close[1] > SMMA(55,LOW).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double smma_high = QM_SMMA(_Symbol, _Period, strategy_smma_period, 1, PRICE_HIGH);
   const double smma_low  = QM_SMMA(_Symbol, _Period, strategy_smma_period, 1, PRICE_LOW);
   if(smma_high <= 0.0 || smma_low <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   // Determine open-position direction for this magic.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
         return (close1 < smma_high);
      if(ptype == POSITION_TYPE_SELL)
         return (close1 > smma_low);
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
