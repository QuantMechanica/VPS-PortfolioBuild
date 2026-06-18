#property strict
#property version   "5.0"
#property description "QM5_11549 carter-t-m5-bb503234-rsi3-stoch633 — BB(50,2/3/4)+RSI(3)+Stoch(6,3,3) mean-reversion (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11549 carter-t-m5-bb503234-rsi3-stoch633
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)",
//   System #8 (self-published 2014).
// Card: artifacts/cards_approved/QM5_11549_carter-t-m5-bb503234-rsi3-stoch633.md
//   (g0_status: APPROVED).
//
// Mechanic (M5 mean-reversion pullback after an extreme push):
//   Three Bollinger Bands share the same 50-period center: 2sigma (entry band),
//   3sigma, 4sigma (stop band). After price pushes into/through the 2sigma band
//   with RSI(3) at an extreme, we wait for price to retrace back inside the
//   2sigma band, RSI to recover off its extreme, and the Stochastic(6,3,3) lines
//   to cross out of OB/OS — then enter toward the mean.
//
// Closed-bar mapping (the framework gates the entry on QM_IsNewBar, so the last
// CLOSED bar is shift 1, the bar before it is shift 2):
//   "bar[1]" in the card (the extreme push)        -> shift 2
//   "bar[0]"/confirmation (the retrace + cross)     -> shift 1
//
// TRIGGER EVENT (exactly one, to avoid the two-cross-same-bar zero-trade trap):
//   Stochastic K crosses D out of the extreme zone on the last closed bar
//   (K<=D at shift 2 and K>D at shift 1 for longs; mirror for shorts).
// Confirming STATES (no second cross event):
//   - Extreme push touch at shift 2:  low<=BB2_lower (long) / high>=BB2_upper.
//   - RSI(3) extreme at shift 2:      rsi<rsi_long_lo (long) / rsi>rsi_short_hi.
//   - RSI(3) recovery at shift 1:     rsi>=rsi_long_lo (long) / rsi<=rsi_short_hi.
//   - Price back inside the 2sigma band at shift 1: close>BB2_lower (long).
//   - Stoch level filter at shift 1:  K<stoch_long_level (long, still low-ish)
//                                     so the cross is out of OS, not mid-range.
//
// Exit / risk:
//   TP = BB(50,2) MIDDLE band (mean-reversion target), captured at entry.
//   SL = BB(50,4) outer band at entry, but capped to sl_cap_pips (card P2 cap
//        = 40 pips) so a far-away 4sigma band cannot create an oversized stop.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11549;
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
input int    strategy_bb_period         = 50;    // common center period for all three BBs
input double strategy_bb_entry_dev      = 2.0;   // 2sigma entry band
input double strategy_bb_stop_dev       = 4.0;   // 4sigma outer band -> raw stop reference
input int    strategy_rsi_period        = 3;     // RSI(3)
input double strategy_rsi_long_lo       = 20.0;  // long: oversold RSI threshold
input double strategy_rsi_short_hi      = 80.0;  // short: overbought RSI threshold
input int    strategy_stoch_k           = 6;     // Stochastic %K period
input int    strategy_stoch_d           = 3;     // Stochastic %D period
input int    strategy_stoch_slow        = 3;     // Stochastic slowing
input double strategy_stoch_long_level  = 40.0;  // long: K must cross while still <= this
input double strategy_stoch_short_level = 60.0;  // short: K must cross while still >= this
input double strategy_sl_cap_pips       = 40.0;  // P2 cap on the BB(4sigma)-derived stop
input bool   strategy_no_friday_entry   = true;  // card filter: no Friday entry
input double strategy_spread_cap_pips   = 5.0;   // card filter: spread cap 5 pips

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard + no-Friday-entry. Fail-open on the
// .DWX zero modeled spread (never block on a zero/narrow spread).
bool Strategy_NoTradeFilter()
  {
   // No-Friday-entry: card filter. Broker time; blocks entries all of Friday.
   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5) // Friday
         return true;
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   const double spread = ask - bid;
   if(spread > 0.0)
     {
      const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_spread_cap_pips);
      if(cap > 0.0 && spread > cap)
         return true;
     }
   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Bollinger bands at the confirmation bar (shift 1) and push bar (2) ---
   const double bb2_lo_1 = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_entry_dev, 1);
   const double bb2_up_1 = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_entry_dev, 1);
   const double bb2_mid_1= QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_entry_dev, 1);
   const double bb2_lo_2 = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_entry_dev, 2);
   const double bb2_up_2 = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_entry_dev, 2);
   const double bb4_lo_1 = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_stop_dev, 1);
   const double bb4_up_1 = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_stop_dev, 1);
   if(bb2_lo_1 <= 0.0 || bb2_up_1 <= 0.0 || bb2_mid_1 <= 0.0 ||
      bb2_lo_2 <= 0.0 || bb2_up_2 <= 0.0 || bb4_lo_1 <= 0.0 || bb4_up_1 <= 0.0)
      return false;

   // --- RSI(3) at push (2) and confirmation (1) ---
   const double rsi_2 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 2);
   const double rsi_1 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(rsi_2 <= 0.0 || rsi_1 <= 0.0)
      return false;

   // --- Stochastic(6,3,3) K & D at push (2) and confirmation (1) ---
   const double k_2 = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 2);
   const double d_2 = QM_Stoch_D(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 2);
   const double k_1 = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 1);
   const double d_1 = QM_Stoch_D(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 1);
   if(k_2 < 0.0 || d_2 < 0.0 || k_1 < 0.0 || d_1 < 0.0)
      return false;

   // Closed-bar OHLC reads (perf-allowed: single closed-bar references).
   const double low_2   = iLow(_Symbol, _Period, 2);   // perf-allowed
   const double high_2  = iHigh(_Symbol, _Period, 2);  // perf-allowed
   const double close_1 = iClose(_Symbol, _Period, 1); // perf-allowed
   if(low_2 <= 0.0 || high_2 <= 0.0 || close_1 <= 0.0)
      return false;

   // === LONG ============================================================
   // STATES: push bar touched/penetrated 2sigma lower with RSI oversold;
   //         confirm bar back inside the band with RSI recovered; Stoch K
   //         still in the lower zone. TRIGGER EVENT: Stoch K crosses above D.
   const bool long_push    = (low_2 <= bb2_lo_2) && (rsi_2 < strategy_rsi_long_lo);
   const bool long_reentry = (close_1 > bb2_lo_1) && (rsi_1 >= strategy_rsi_long_lo);
   const bool long_zone    = (k_1 <= strategy_stoch_long_level);
   const bool long_cross   = (k_2 <= d_2) && (k_1 > d_1); // single trigger event
   if(long_push && long_reentry && long_zone && long_cross)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;

      // TP = 2sigma middle band (mean). SL = 4sigma lower band, capped.
      double sl = bb4_lo_1;
      const double cap_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_sl_cap_pips);
      if(cap_dist > 0.0 && (entry - sl) > cap_dist)
         sl = entry - cap_dist;          // tighten an oversized 4sigma stop to the cap
      if(sl >= entry)
         return false;                   // degenerate / inverted stop — skip

      double tp = bb2_mid_1;
      if(tp <= entry)
         return false;                   // mean already below price — no edge

      req.type   = QM_BUY;
      req.price  = 0.0;                  // framework fills market price at send
      req.sl     = QM_TM_NormalizePrice(_Symbol, sl);
      req.tp     = QM_TM_NormalizePrice(_Symbol, tp);
      req.reason = "carter_bb_rsi_stoch_long";
      return true;
     }

   // === SHORT ===========================================================
   const bool short_push    = (high_2 >= bb2_up_2) && (rsi_2 > strategy_rsi_short_hi);
   const bool short_reentry = (close_1 < bb2_up_1) && (rsi_1 <= strategy_rsi_short_hi);
   const bool short_zone    = (k_1 >= strategy_stoch_short_level);
   const bool short_cross   = (k_2 >= d_2) && (k_1 < d_1); // single trigger event
   if(short_push && short_reentry && short_zone && short_cross)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;

      double sl = bb4_up_1;
      const double cap_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_sl_cap_pips);
      if(cap_dist > 0.0 && (sl - entry) > cap_dist)
         sl = entry + cap_dist;
      if(sl <= entry)
         return false;

      double tp = bb2_mid_1;
      if(tp >= entry)
         return false;

      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = QM_TM_NormalizePrice(_Symbol, sl);
      req.tp     = QM_TM_NormalizePrice(_Symbol, tp);
      req.reason = "carter_bb_rsi_stoch_short";
      return true;
     }

   return false;
  }

// Fixed BB-middle TP / BB-outer SL set at entry. No active management.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit beyond the SL/TP set at entry.
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
