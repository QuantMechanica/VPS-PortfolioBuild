#property strict
#property version   "5.0"
#property description "QM5_10946 zuck-weekend-cont — Weekend continuation (long-only, H1)"

#include <QM/QM_Common.mqh>
#include <QM/QM_Signals.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_10946 zuck-weekend-cont
// -----------------------------------------------------------------------------
// Source: Gregory Zuckerman, "The Man Who Solved the Market", Portfolio/Penguin,
//   2019, ISBN 9780735217980 — Laufer's day-of-week / weekend effect: the model
//   bought late Friday in a clear uptrend and sold early Monday.
// Card: artifacts/cards_approved/QM5_10946_zuck-weekend-cont.md (g0_status APPROVED).
//
// Mechanics (long-only, H1, closed-bar reads at shift 1):
//   Entry  (Friday, final liquid broker-hour only):
//       clear_uptrend = close[1] > SMA(trend_sma_period)[1]
//                       AND close[1] > close[trend_return_bars]
//       If clear_uptrend and no open position -> BUY at market.
//       Emergency SL = atr_stop_mult * ATR(atr_period) at entry.
//   Exit:
//       - Time stop: first liquid Monday broker-hour -> close.
//       - Gap-adverse: if price is more than gap_atr_mult * ATR below the
//         recorded entry price (Monday weekend gap against us) -> close
//         immediately and do not re-enter that bar.
//
// .DWX invariants honoured:
//   - Spread guard fails OPEN (zero modeled spread never blocks); only a
//     genuinely wide spread > spread_pct_of_atr of ATR blocks the Friday entry.
//   - Session windows are in BROKER time (DXZ NY-Close GMT+2/+3); the entry and
//     exit hours are setfile params per symbol's main session.
//   - No swap gate. No external-macro CSV (the optional event skip from the card
//     is delegated to the central QM news filter — high-impact events on the
//     news calendar already pause trading; no fabricated calendar here).
//   - QM_IsNewBar() consumed ONCE on the entry path by the framework.
//
// IMPORTANT setfile requirement: this EA intentionally HOLDS over the weekend.
// The framework Friday-close guard MUST be disabled for it to work:
//   qm_friday_close_enabled = false
// (otherwise the framework flattens the position Friday evening before Monday).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10946;
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
// MUST be disabled in the setfile — this strategy holds over the weekend.
input bool   qm_friday_close_enabled    = false;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_trend_sma_period   = 20;    // trend filter SMA period
input int    strategy_trend_return_bars  = 5;     // close[1] vs close[N] momentum lookback
input int    strategy_atr_period         = 14;    // ATR period (stop / gap reference)
input double strategy_atr_stop_mult      = 1.5;   // initial SL = mult * ATR
input double strategy_gap_atr_mult       = 2.5;   // adverse-gap emergency close threshold (in ATR)
input int    strategy_entry_hour_broker  = 22;    // Friday final-liquid-hour (broker time) to BUY
input int    strategy_exit_hour_broker   = 9;     // Monday first-liquid-hour (broker time) to close
input double strategy_spread_pct_of_atr  = 20.0;  // skip Friday entry if spread > this % of ATR

// File-scope: ATR value recorded at entry, used for the Monday gap-adverse check.
double g_entry_atr = 0.0;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-OPEN on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to entry gate, do not block here

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_atr / 100.0) * atr_value)
      return true;

   return false;
  }

// Long-only entry, Friday final-liquid broker-hour only. Caller guarantees
// QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Time gate: Friday, at the configured final-liquid broker-hour ---
   const datetime broker_now = TimeCurrent();
   MqlDateTime bt;
   TimeToStruct(broker_now, bt);
   const bool is_friday = (bt.day_of_week == 5); // 0=Sun..6=Sat
   if(!is_friday)
      return false;
   if(bt.hour != strategy_entry_hour_broker)
      return false;

   // --- clear_uptrend = close[1] > SMA(period)[1] AND close[1] > close[N] ---
   const double sma1 = QM_SMA(_Symbol, _Period, strategy_trend_sma_period, 1);
   if(sma1 <= 0.0)
      return false;
   const double close1 = iClose(_Symbol, _Period, 1);                       // perf-allowed: single closed-bar read
   const double closeN = iClose(_Symbol, _Period, strategy_trend_return_bars); // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || closeN <= 0.0)
      return false;
   if(!(close1 > sma1))
      return false;
   if(!(close1 > closeN))
      return false;

   // --- ATR for the emergency stop + recorded for the Monday gap check ---
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_atr_stop_mult);
   if(sl <= 0.0)
      return false;

   g_entry_atr = atr_value; // recorded for the Monday adverse-gap test

   req.type   = QM_BUY;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;   // no fixed take-profit; exit is the Monday time stop
   req.reason = "zuck_weekend_cont_long";
   return true;
  }

// No active trade management beyond the fixed ATR stop. Exit logic (time stop +
// adverse weekend gap) lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Exit: Monday first-liquid broker-hour time stop, OR an adverse weekend gap
// beyond gap_atr_mult * ATR against the recorded entry price.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const datetime broker_now = TimeCurrent();
   MqlDateTime bt;
   TimeToStruct(broker_now, bt);
   const bool is_monday = (bt.day_of_week == 1); // 0=Sun..6=Sat

   // --- Time stop: close at/after the configured Monday liquid hour ---
   if(is_monday && bt.hour >= strategy_exit_hour_broker)
      return true;

   // --- Adverse weekend gap: long under water by > gap_atr_mult * ATR ---
   const int magic = QM_FrameworkMagic();
   const double gap_atr = (g_entry_atr > 0.0)
                          ? g_entry_atr
                          : QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(gap_atr > 0.0)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid > 0.0)
        {
         for(int i = PositionsTotal() - 1; i >= 0; --i)
           {
            const ulong ticket = PositionGetTicket(i);
            if(!PositionSelectByTicket(ticket))
               continue;
            if((int)PositionGetInteger(POSITION_MAGIC) != magic)
               continue;
            const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
            if(open_price > 0.0 && (open_price - bid) > strategy_gap_atr_mult * gap_atr)
               return true; // adverse gap beyond threshold -> close now
           }
        }
     }

   return false;
  }

// Defer to the central news filter. The card's optional "skip known high-impact
// Sunday/Monday events" is satisfied by the framework news calendar — no
// fabricated external event feed.
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
