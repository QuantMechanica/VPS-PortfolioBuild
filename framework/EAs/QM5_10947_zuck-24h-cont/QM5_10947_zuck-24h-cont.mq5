#property strict
#property version   "5.0"
#property description "QM5_10947 zuck-24h-cont — Twenty-Four-Hour Continuation (symmetric long/short, D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_10947 zuck-24h-cont
// -----------------------------------------------------------------------------
// Source: Gregory Zuckerman, "The Man Who Solved the Market" (2019),
//         ISBN 9780735217980 — Laufer "twenty-four-hour effect": prior-day
//         trading often predicts the next day's activity.
// Card: artifacts/cards_approved/QM5_10947_zuck-24h-cont.md (g0_status APPROVED).
//
// Mechanics (symmetric continuation, D1, closed-bar reads):
//   Prior-day return : ret1 = close_D1[1] / close_D1[2] - 1.
//   Threshold        : thr = trigger_atr_frac * ATR(atr_period,D1) / close_D1[2].
//   Entry EVENT      : on each new D1 bar -
//                        ret1 >  +thr  -> BUY  (continuation up)
//                        ret1 <  -thr  -> SELL (continuation down)
//                      No trade if |ret1| <= thr.
//   Exit (time stop) : hold ~24h. On D1 that is one full daily bar - close the
//                      position once a NEW D1 bar has opened since entry.
//   Stop loss        : entry -/+ atr_stop_mult * ATR(atr_period,D1).  No TP
//                      (time exit governs the win side).
//   Friday skip      : no NEW entries on broker-time Friday (avoid weekend hold).
//   Spread guard     : skip only a genuinely wide spread > spread_pct_of_atr_h1
//                      of ATR(14,H1); fail-open on .DWX zero modeled spread.
//   One position per magic; no pyramiding.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10947;
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
input double strategy_trigger_atr_frac  = 0.25;   // |prior-day ret| threshold as fraction of ATR/close
input int    strategy_atr_period        = 14;     // ATR period on D1 (threshold + stop)
input double strategy_atr_stop_mult     = 1.25;   // emergency SL distance = mult * ATR(D1)
input bool   strategy_skip_friday       = true;   // no new entries on broker-time Friday
input int    strategy_spread_atr_h1_pd  = 14;     // ATR period on H1 for the spread cap
input double strategy_spread_pct_of_atr_h1 = 10.0; // skip if spread > this % of ATR(14,H1)

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

   const double atr_h1 = QM_ATR(_Symbol, PERIOD_H1, strategy_spread_atr_h1_pd, 1);
   if(atr_h1 <= 0.0)
      return false; // no ATR yet — defer to entry gate, do not block here

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_atr_h1 / 100.0) * atr_h1)
      return true;

   return false;
  }

// Symmetric continuation entry. Caller guarantees QM_IsNewBar() == true on the
// chart timeframe (D1 per the card).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic; no pyramiding.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Friday skip — no NEW entries on broker-time Friday (avoid weekend hold).
   if(strategy_skip_friday)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5) // 0=Sun .. 5=Fri
         return false;
     }

   // --- Prior-day closes (closed bars: shift 1 = yesterday, shift 2 = day before) ---
   const double close1 = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, PERIOD_D1, 2); // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   const double ret1 = close1 / close2 - 1.0;

   // --- Threshold scaled by ATR(D1) as a fraction of price ---
   const double atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_d1 <= 0.0)
      return false;
   const double thr = strategy_trigger_atr_frac * (atr_d1 / close2);
   if(thr <= 0.0)
      return false;

   QM_OrderType side;
   if(ret1 > thr)
      side = QM_BUY;
   else if(ret1 < -thr)
      side = QM_SELL;
   else
      return false; // move below threshold — no trade

   // --- Emergency stop = atr_stop_mult * ATR(D1) from entry. No TP (time exit). ---
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr_d1, strategy_atr_stop_mult);
   if(sl <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;   // no take-profit; 24h time stop governs the exit
   req.reason = (side == QM_BUY) ? "zuck_24h_cont_long" : "zuck_24h_cont_short";
   return true;
  }

// No active trade management beyond the fixed ATR emergency stop. The 24h
// time exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Time-stop exit: hold ~24h. On D1 that means one full daily bar has elapsed —
// close once a NEW D1 bar has opened since the entry bar.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Open time of the current D1 bar. If the position opened on an earlier D1
   // bar, at least one full daily bar has closed → time stop fires.
   const datetime cur_bar_open = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: single bar-time read
   if(cur_bar_open <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      const datetime pos_open = (datetime)PositionGetInteger(POSITION_TIME);
      if(pos_open > 0 && pos_open < cur_bar_open)
         return true; // entry bar has fully closed — exit on the new daily bar
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
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
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
