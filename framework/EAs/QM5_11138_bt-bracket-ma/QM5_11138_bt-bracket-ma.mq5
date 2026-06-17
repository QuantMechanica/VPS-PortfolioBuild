#property strict
#property version   "5.0"
#property description "QM5_11138 bt-bracket-ma — SMA-cross pullback BUY_LIMIT bracket (long-only, D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11138 bt-bracket-ma
// -----------------------------------------------------------------------------
// Source: backtrader sample `samples/bracket/bracket.py` (Daniel Rodriguez).
// Card: artifacts/cards_approved/QM5_11138_bt-bracket-ma.md (g0_status APPROVED).
//
// Mechanics (long-only, closed-bar reads at shift 1 = signal bar):
//   Trigger EVENT : SMA(fast) crosses ABOVE SMA(slow) on the just-closed bar
//                   (fast@2 <= slow@2  AND  fast@1 > slow@1) — one event/bar.
//   Entry         : place a BUY_LIMIT below the signal close at
//                   limit = close1 * (1 - pullback_pct).
//   Validity      : limit order expires after `limit_validity_bars` D1 bars
//                   (expiration_seconds = bars * 86400) if not filled.
//   Bracket       : attached SL/TP travel with the pending order (native MT5
//                   OCO — when one side fills the sibling is auto-removed):
//                     SL = limit - stop_pct  * close1
//                     TP = limit + target_pct * close1
//   One position/pending per symbol/magic; do not stack a new limit each bar.
//
// .DWX invariants honoured:
//   - SMA cross is a single EVENT (#4); the pullback is expressed as the limit
//     offset, not a second same-bar event.
//   - No spread/swap gate (#1/#2): the bracket is price-defined; the framework
//     fail-opens on .DWX zero spread.
//   - Percent distances are scaled to symbol price via NormalizeDouble at send
//     (the framework normalizes sl/tp/price to _Digits).
//   - D1 native — no MN1 logic (#10), no external macro CSV (#11).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11138;
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
input int    strategy_sma_fast_period   = 5;      // fast SMA (signal)
input int    strategy_sma_slow_period   = 15;     // slow SMA (signal)
input double strategy_pullback_pct      = 0.5;    // buy-limit offset below close, percent
input double strategy_stop_pct          = 2.0;    // bracket stop distance, percent of signal close
input double strategy_target_pct        = 2.0;    // bracket target distance, percent of signal close
input int    strategy_limit_validity_bars = 3;    // pending-order validity in D1 bars

// -----------------------------------------------------------------------------
// EA-local helper: count live pending orders for this EA's magic on this symbol.
// Order-management bookkeeping (not strategy indicator math). Prevents stacking
// a fresh BUY_LIMIT on every cross while a prior limit is still working.
// -----------------------------------------------------------------------------
int PendingOrderCount(const int magic)
  {
   int n = 0;
   const int total = OrdersTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(!OrderSelect(ticket))
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      ++n;
     }
   return n;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No session/spread/regime gate. The bracket order is price-defined; .DWX
// fail-open spread handling lives in the framework. O(1) per tick.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Long-only entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
// On a fresh SMA(fast)>SMA(slow) crossover, arm a BUY_LIMIT bracket below the
// signal close.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const int magic = QM_FrameworkMagic();

   // One bracket per symbol/magic: skip if a position is open OR a limit is live.
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;
   if(PendingOrderCount(magic) > 0)
      return false;

   // --- Trigger EVENT: SMA(fast) crosses above SMA(slow) on the closed bar ---
   const double fast_now  = QM_SMA(_Symbol, _Period, strategy_sma_fast_period, 1);
   const double slow_now  = QM_SMA(_Symbol, _Period, strategy_sma_slow_period, 1);
   const double fast_prev = QM_SMA(_Symbol, _Period, strategy_sma_fast_period, 2);
   const double slow_prev = QM_SMA(_Symbol, _Period, strategy_sma_slow_period, 2);
   if(fast_now <= 0.0 || slow_now <= 0.0 || fast_prev <= 0.0 || slow_prev <= 0.0)
      return false;

   const bool crossed_up = (fast_prev <= slow_prev && fast_now > slow_now);
   if(!crossed_up)
      return false;

   // --- Signal close (shift 1) anchors the limit/bracket distances ---
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   // --- Pullback BUY_LIMIT below the signal close ---
   const double limit_price = close1 * (1.0 - strategy_pullback_pct / 100.0);
   if(limit_price <= 0.0 || limit_price >= close1)
      return false;

   // --- Bracket: SL/TP as fixed percent of the signal close around the limit ---
   const double sl = limit_price - (strategy_stop_pct   / 100.0) * close1;
   const double tp = limit_price + (strategy_target_pct / 100.0) * close1;
   if(sl <= 0.0 || tp <= limit_price)
      return false; // reject impossible / inverted bracket (card: reject impossible stops)

   req.type               = QM_BUY_LIMIT;
   req.price              = limit_price;
   req.sl                 = sl;
   req.tp                 = tp;
   req.reason             = "bt_bracket_ma_long";
   req.expiration_seconds = strategy_limit_validity_bars * 86400; // D1 bars -> seconds
   return true;
  }

// Bracket SL/TP are native on the order; no active management. Sibling-cancel
// is handled by MT5 attached-stop OCO when one side fills.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit beyond the native bracket SL/TP.
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
