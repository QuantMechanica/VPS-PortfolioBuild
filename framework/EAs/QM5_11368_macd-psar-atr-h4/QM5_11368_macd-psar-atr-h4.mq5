#property strict
#property version   "5.0"
#property description "QM5_11368 macd-psar-atr-h4 — MACD zero-cross + Parabolic SAR + ATR (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11368 macd-psar-atr-h4
// -----------------------------------------------------------------------------
// Source: Anonymous, "MACD Trend Forex Trading Strategy with Parabolic SAR and
//         ATR" (local PDF). Card: artifacts/cards_approved/
//         QM5_11368_macd-psar-atr-h4.md (g0_status APPROVED).
//
// Mechanics (H4, closed-bar reads at shift 1):
//   Direction is driven by ONE EVENT confirmed by ONE STATE. To avoid the
//   "two crosses on the same bar never coincide" zero-trade trap, EITHER the
//   MACD MAIN-line zero-cross OR the Parabolic SAR flip can be the trigger
//   EVENT; whichever fires, the OTHER indicator must merely AGREE as a STATE.
//
//   LONG:
//     EVENT  = MACD MAIN crosses ABOVE zero  (main[2] <= 0 && main[1] > 0)
//              OR  PSAR flips below price     (sar[2] >= close[2] && sar[1] < close[1])
//     STATE  = PSAR below price (sar[1] < close[1]) AND MACD MAIN > 0 (main[1] > 0)
//   SHORT (mirror):
//     EVENT  = MACD MAIN crosses BELOW zero   (main[2] >= 0 && main[1] < 0)
//              OR  PSAR flips above price      (sar[2] <= close[2] && sar[1] > close[1])
//     STATE  = PSAR above price (sar[1] > close[1]) AND MACD MAIN < 0 (main[1] < 0)
//   MACD MAIN may be negative — the cross is about SIGN, not magnitude.
//
//   Stop  : Parabolic SAR value at entry (structural trailing stop). An ATR
//           floor caps the SL distance so a SAR sitting on top of price still
//           yields a usable, risk-sane stop.
//   Take  : entry + tp_atr_mult * ATR (single TP, per card P2 note).
//   Trail : each H4 bar, ratchet SL toward the current SAR (never backward).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
//
// .DWX invariants observed:
//   - Spread guard fails OPEN on zero modeled spread (only a genuinely wide
//     spread blocks).
//   - No swap gating, no external-macro CSV feed, gapless-CFD prior-CLOSE
//     comparisons (PSAR-vs-close on the same closed bar — no gap assumption).
//   - QM_IsNewBar() consumed exactly ONCE on the entry path.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11368;
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
input double strategy_sar_step          = 0.02;   // Parabolic SAR step (AF)
input double strategy_sar_max           = 0.2;    // Parabolic SAR max AF
input int    strategy_atr_period        = 14;     // ATR period (stop floor + target)
input double strategy_tp_atr_mult       = 2.0;    // take-profit distance = mult * ATR
input double strategy_sl_atr_floor_mult = 1.0;    // min SL distance = mult * ATR (SAR cap)
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — signal work is on the closed-bar
// path in Strategy_EntrySignal. Fails OPEN on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

   const double stop_distance = strategy_sl_atr_floor_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Closed-bar reads. Trigger bar = shift 1; prior bar = shift 2.
   const double macd1 = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                     strategy_macd_slow, strategy_macd_signal, 1);
   const double macd2 = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                     strategy_macd_slow, strategy_macd_signal, 2);
   const double sar1  = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 1);
   const double sar2  = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 2);
   if(sar1 <= 0.0 || sar2 <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // --- LONG ---
   // EVENT: MACD MAIN crosses above zero, OR PSAR flips below price.
   const bool macd_cross_up = (macd2 <= 0.0 && macd1 > 0.0);
   const bool sar_flip_up   = (sar2 >= close2 && sar1 < close1);
   const bool long_event    = (macd_cross_up || sar_flip_up);
   // STATE: PSAR below price AND MACD MAIN positive (both agree bullish).
   const bool long_state    = (sar1 < close1 && macd1 > 0.0);

   // --- SHORT (mirror) ---
   const bool macd_cross_dn = (macd2 >= 0.0 && macd1 < 0.0);
   const bool sar_flip_dn   = (sar2 <= close2 && sar1 > close1);
   const bool short_event   = (macd_cross_dn || sar_flip_dn);
   const bool short_state   = (sar1 > close1 && macd1 < 0.0);

   const bool go_long  = (long_event  && long_state);
   const bool go_short = (short_event && short_state);

   // If somehow both fire (opposing), stand aside — ambiguous bar.
   if(go_long == go_short)
      return false;

   if(go_long)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;

      // SL = PSAR value at entry, but never closer than the ATR floor.
      double sl = sar1;
      const double atr_floor_sl = entry - strategy_sl_atr_floor_mult * atr_value;
      if(sl >= entry || sl > atr_floor_sl)
         sl = atr_floor_sl;

      const double tp = entry + strategy_tp_atr_mult * atr_value;
      sl = QM_TM_NormalizePrice(_Symbol, sl);
      if(sl <= 0.0 || sl >= entry || tp <= entry)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = QM_TM_NormalizePrice(_Symbol, tp);
      req.reason = "macd_psar_atr_long";
      return true;
     }

   if(go_short)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;

      // SL = PSAR value at entry, but never closer than the ATR floor.
      double sl = sar1;
      const double atr_floor_sl = entry + strategy_sl_atr_floor_mult * atr_value;
      if(sl <= entry || sl < atr_floor_sl)
         sl = atr_floor_sl;

      const double tp = entry - strategy_tp_atr_mult * atr_value;
      sl = QM_TM_NormalizePrice(_Symbol, sl);
      if(sl <= 0.0 || sl <= entry || tp <= 0.0 || tp >= entry)
         return false;

      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = QM_TM_NormalizePrice(_Symbol, tp);
      req.reason = "macd_psar_atr_short";
      return true;
     }

   return false;
  }

// Trail the SL toward the current Parabolic SAR each H4 closed bar; never move
// the stop backward (looser). Per-tick safe: QM_SAR is handle-pooled and reads
// a fixed closed-bar shift.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return;

   const double sar1 = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 1);
   if(sar1 <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const long  ptype  = PositionGetInteger(POSITION_TYPE);
      const double cur_sl = PositionGetDouble(POSITION_SL);
      const double new_sl = QM_TM_NormalizePrice(_Symbol, sar1);

      if(ptype == POSITION_TYPE_BUY)
        {
         // Ratchet up only; SAR must sit below current price to be a valid stop.
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(new_sl < bid && (cur_sl <= 0.0 || new_sl > cur_sl))
            QM_TM_MoveSL(ticket, new_sl, "psar_trail");
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(new_sl > ask && (cur_sl <= 0.0 || new_sl < cur_sl))
            QM_TM_MoveSL(ticket, new_sl, "psar_trail");
        }
     }
  }

// No discretionary exit beyond the PSAR trailing stop + ATR target. Reversal
// handling is covered by the SAR trail catching adverse moves.
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
