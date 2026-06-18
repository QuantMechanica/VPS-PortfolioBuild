#property strict
#property version   "5.0"
#property description "QM5_11630 cat-rsi-pt — Catalyst RSI oversold + profit-target exit (long-only, M30)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11630 cat-rsi-pt
// -----------------------------------------------------------------------------
// Source: scrtlabs/catalyst, catalyst/examples/rsi_profit_target.py
//   https://github.com/scrtlabs/catalyst/blob/master/catalyst/examples/rsi_profit_target.py
// Card: artifacts/cards_approved/QM5_11630_cat-rsi-pt.md (g0_status APPROVED).
//
// Mechanics (long-only mean-reversion, closed-bar reads at shift 1, M30):
//   Entry EVENT  : RSI(period) crosses DOWN through the oversold level
//                  (rsi@2 >= lo  AND  rsi@1 < lo). The cross is one event per
//                  bar — using the cross (not the bare "RSI < lo" state) avoids
//                  the zero-trade two-cross trap and stops re-firing every bar
//                  while RSI sits below the level.
//   Stop         : ATR-normalized stop below entry (source 10% initial stop,
//                  expressed as sl_atr_mult * ATR so it scales per-symbol).
//   Profit target: RR-multiple take-profit (source 15% ratchet target, mapped
//                  to tp_rr * stop-distance). This is the "pt" exit.
//   Ratchet/trail: once price has advanced trail_arm_rr * stop-distance in
//                  profit, an ATR trailing stop is armed (source resets the
//                  cost basis at the target then trails 3% — expressed as an
//                  ATR trail so gains are protected after the target zone).
//   One position per symbol/magic; no pyramiding; no new order while open.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
//
// Symbol porting: all card symbols (EURUSD/GBPUSD/USDJPY/XAUUSD/NDX) are
// present in dwx_symbol_matrix.csv as *.DWX — no ports required.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11630;
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
input int    strategy_rsi_period         = 16;    // Catalyst RSI(16)
input double strategy_rsi_oversold       = 30.0;  // oversold entry level
input int    strategy_atr_period         = 14;    // ATR for stop/target scaling
input double strategy_sl_atr_mult        = 2.0;   // stop distance = mult * ATR (source 10% initial)
input double strategy_tp_rr              = 1.5;   // take-profit = tp_rr * stop dist (source 15% target vs 10% stop)
input double strategy_trail_arm_rr       = 1.0;   // arm ATR trail once price gains this * stop dist
input double strategy_trail_atr_mult     = 1.5;   // ATR trailing-stop distance after target zone
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
      return false; // no ATR yet — defer to entry gate, do not block here

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
   // One open position per symbol/magic; no pyramiding.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Entry EVENT: RSI crosses DOWN through the oversold level ---
   // rsi@2 >= level (was at/above), rsi@1 < level (now oversold): a single
   // fresh downward cross per bar. Using the cross — not the bare "RSI < level"
   // state — avoids re-firing every bar while RSI stays oversold and avoids
   // the two-cross same-bar zero-trade trap.
   const double rsi_now  = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   const double rsi_prev = QM_RSI(_Symbol, _Period, strategy_rsi_period, 2);
   if(rsi_now <= 0.0 || rsi_prev <= 0.0)
      return false;
   const bool crossed_down = (rsi_prev >= strategy_rsi_oversold &&
                              rsi_now  <  strategy_rsi_oversold);
   if(!crossed_down)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // --- Build the long entry. Framework sizes lots (no lots field). ---
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
   req.reason = "cat_rsi_pt_long";
   return true;
  }

// Profit-target ratchet: once price has advanced trail_arm_rr * stop-distance
// in our favour, arm an ATR trailing stop to protect the gain (source resets
// the cost basis at the 15% target then trails 3%). Runs per tick on open
// positions belonging to this magic.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
         continue;

      const double entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double sl_price     = PositionGetDouble(POSITION_SL);
      if(entry_price <= 0.0 || sl_price <= 0.0)
         continue;

      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0)
         continue;

      // Stop-distance reference is the original risk (entry - initial SL).
      const double stop_distance = entry_price - sl_price;
      if(stop_distance <= 0.0)
         continue;

      // Arm the ATR trail only after price has advanced far enough in profit.
      const double gain = bid - entry_price;
      if(gain < strategy_trail_arm_rr * stop_distance)
         continue;

      QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr_mult);
     }
  }

// No discretionary close beyond the SL / profit-target TP / armed ATR trail.
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
