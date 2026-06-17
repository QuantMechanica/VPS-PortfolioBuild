#property strict
#property version   "5.0"
#property description "QM5_11031 atc-ohlc-pend — D1 prior-OHLC pending-order breakout (FX, D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11031 atc-ohlc-pend
// -----------------------------------------------------------------------------
// Source: Francisco Garcia Garcia, Interview (ATC 2012), MQL5 Articles
//         https://www.mql5.com/en/articles/563
// Card: artifacts/cards_approved/QM5_11031_atc-ohlc-pend.md (g0_status APPROVED).
//
// Mechanics (D1, closed-bar reads at shift 1, no indicators except ATR for
// sizing the buffer / stop / target / breakeven):
//   Cadence    : evaluate once every `eval_cadence_bars` closed D1 bars. The
//                cadence counter advances on framework-confirmed new bars only
//                (caller guarantees QM_IsNewBar()==true before EntrySignal).
//   At each evaluation:
//     - Cancel any still-pending order for this magic (carried from the prior
//       evaluation — "cancel unfilled pending orders at the next evaluation").
//     - If a position is already open for this magic, leave it to its SL/TP and
//       Strategy_ManageOpenPosition (breakeven); place no new pending order.
//     - Otherwise read prior D1 bar O/H/L/C (shift 1) and current bid:
//         Long  : current price > prior close ->
//                 BUY STOP  at prior_high + entry_buffer_atr * ATR.
//         Short : current price < prior close ->
//                 SELL STOP at prior_low  - entry_buffer_atr * ATR.
//       Long takes precedence if both somehow qualify (price cannot be both).
//   Stop / Take: SL = sl_atr_mult * ATR, TP = tp_atr_mult * ATR, measured from
//                the PENDING price (gapless .DWX CFDs: lots size off pending->SL).
//   Expiry     : pending order expires after eval_cadence_bars D1 windows so an
//                untouched level is cancelled even if a tick never re-evaluates.
//   Breakeven  : once open profit >= breakeven_atr * ATR, move SL to entry.
//   No trailing (matches the source).
//   Range filter: only arm when the recent average D1 range is >= the median
//                 D1 range over `range_filter_bars` (regime/liquidity gate).
//   Spread guard : skip only a genuinely wide spread (fail-open on .DWX zero
//                  modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
//
// NOTE (open question): the card lists OPTIONAL secondary buy-limit/sell-limit
// reversal triggers. The V5 single-entry framework path is one pending order
// per magic, so this build implements only the PRIMARY stop-breakout order
// (the literal, always-present rule). Secondary limit legs are a P3 sweep idea.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11031;
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
input int    strategy_eval_cadence_bars   = 2;      // evaluate every N closed D1 bars
input int    strategy_atr_period          = 14;     // ATR period (buffer / stop / target / BE)
input double strategy_entry_buffer_atr    = 0.05;   // breakout buffer beyond prior H/L, in ATR
input double strategy_sl_atr_mult         = 0.75;   // stop distance  = mult * ATR
input double strategy_tp_atr_mult         = 1.5;    // target distance = mult * ATR
input double strategy_breakeven_atr       = 1.0;    // move SL to entry once profit >= mult * ATR
input int    strategy_range_filter_bars   = 60;     // median-range lookback (0 disables filter)
input double strategy_spread_pct_of_stop  = 15.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// File-scope state
// -----------------------------------------------------------------------------
// Cadence counter advanced ONLY on framework-confirmed new bars (inside
// Strategy_EntrySignal, which the framework gates with QM_IsNewBar()). This is a
// cadence accumulator, NOT a per-EA new-bar reimplementation — it never reads
// iTime/timestamps to decide "is this a new bar".
int g_bars_since_eval = 0;

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// Remove any live pending order owned by this EA's magic. Returns count removed.
int CancelOwnPendingOrders()
  {
   const int magic = QM_FrameworkMagic();
   int removed = 0;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if(QM_TM_RemovePendingOrder(ticket, "atc_ohlc_cadence_cancel"))
         removed++;
     }
   return removed;
  }

// True if this EA's magic already has a live pending order on this symbol.
bool HasOwnPendingOrder()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_SYMBOL) == _Symbol)
         return true;
     }
   return false;
  }

// Regime/liquidity gate: recent average D1 range >= median D1 range over the
// lookback window. Closed-bar reads only (shift 1..N). Returns true when armed.
bool RangeFilterPasses()
  {
   const int n = strategy_range_filter_bars;
   if(n <= 1)
      return true; // filter disabled

   double ranges[];
   if(ArrayResize(ranges, n) != n)
      return true; // cannot evaluate -> fail-open (do not silently block)

   double recent_sum = 0.0;
   const int recent_window = (n >= 5) ? 5 : n; // "recent" = last few D1 bars
   for(int s = 1; s <= n; ++s)
     {
      const double hi = iHigh(_Symbol, _Period, s); // perf-allowed: closed-bar OHLC
      const double lo = iLow(_Symbol, _Period, s);  // perf-allowed: closed-bar OHLC
      const double rng = hi - lo;
      ranges[s - 1] = (rng > 0.0) ? rng : 0.0;
      if(s <= recent_window)
         recent_sum += ranges[s - 1];
     }

   ArraySort(ranges); // ascending
   const double median = (n % 2 == 1)
                         ? ranges[n / 2]
                         : 0.5 * (ranges[n / 2 - 1] + ranges[n / 2]);
   if(median <= 0.0)
      return true; // degenerate -> fail-open

   const double recent_avg = recent_sum / (double)recent_window;
   return (recent_avg >= median);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only; signal/regime work is on the
// closed-bar path. Fail-open on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer, do not block here

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Pending-order placement on the cadence. Caller guarantees QM_IsNewBar()==true,
// so this fires once per closed D1 bar; we self-throttle to the eval cadence.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // --- Cadence accumulator (advances once per closed bar) ---
   g_bars_since_eval++;
   const int cadence = (strategy_eval_cadence_bars > 0) ? strategy_eval_cadence_bars : 1;
   if(g_bars_since_eval < cadence)
      return false;
   g_bars_since_eval = 0;

   // --- Evaluation tick: cancel any stale pending order from last evaluation ---
   CancelOwnPendingOrders();

   // One position per symbol/magic — if filled, manage it, place nothing new.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Defensive: never stack pending orders (cancel above should have cleared it).
   if(HasOwnPendingOrder())
      return false;

   // --- Regime/liquidity gate ---
   if(!RangeFilterPasses())
      return false;

   // --- Prior completed D1 bar OHLC (shift 1) ---
   const double prior_high  = iHigh(_Symbol, _Period, 1);  // perf-allowed: closed-bar OHLC
   const double prior_low   = iLow(_Symbol, _Period, 1);   // perf-allowed: closed-bar OHLC
   const double prior_close = iClose(_Symbol, _Period, 1); // perf-allowed: closed-bar OHLC
   if(prior_high <= 0.0 || prior_low <= 0.0 || prior_close <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return false;

   const double buffer = strategy_entry_buffer_atr * atr_value;

   // --- Directional decision vs prior close ---
   QM_OrderType otype;
   double pending_price = 0.0;
   if(bid > prior_close)
     {
      // Long breakout: buy stop above prior high.
      otype = QM_BUY_STOP;
      pending_price = prior_high + buffer;
      // Stop entry must sit strictly above current ask to be a valid buy stop.
      if(pending_price <= ask)
         return false;
     }
   else if(bid < prior_close)
     {
      // Short breakout: sell stop below prior low.
      otype = QM_SELL_STOP;
      pending_price = prior_low - buffer;
      // Stop entry must sit strictly below current bid to be a valid sell stop.
      if(pending_price >= bid)
         return false;
     }
   else
     {
      return false; // exactly at prior close — no signal
     }

   pending_price = QM_TM_NormalizePrice(_Symbol, pending_price);
   if(pending_price <= 0.0)
      return false;

   // SL / TP measured from the PENDING price (lots sized off pending->SL).
   const double sl = QM_StopATRFromValue(_Symbol, otype, pending_price, atr_value, strategy_sl_atr_mult);
   const double tp = QM_TakeATRFromValue(_Symbol, otype, pending_price, atr_value, strategy_tp_atr_mult);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type               = otype;
   req.price              = pending_price; // pending entry level
   req.sl                 = sl;
   req.tp                 = tp;
   req.reason             = (otype == QM_BUY_STOP) ? "atc_ohlc_buystop" : "atc_ohlc_sellstop";
   // Expire after the cadence window so an untouched level self-cancels even if
   // no later tick re-evaluates. 86400s per D1 bar.
   req.expiration_seconds = cadence * 86400;
   return true;
  }

// Breakeven only: move SL to entry once open profit >= breakeven_atr * ATR.
// No trailing (matches the source).
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return;
   const double be_distance = strategy_breakeven_atr * atr_value;
   if(be_distance <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double cur_sl     = PositionGetDouble(POSITION_SL);

      if(ptype == POSITION_TYPE_BUY)
        {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid <= 0.0)
            continue;
         if(bid - open_price < be_distance)
            continue; // not yet at breakeven trigger
         // Only move SL up to entry (never backwards / never widen).
         if(cur_sl >= open_price)
            continue;
         QM_TM_MoveSL(ticket, open_price, "atc_ohlc_breakeven");
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask <= 0.0)
            continue;
         if(open_price - ask < be_distance)
            continue;
         if(cur_sl > 0.0 && cur_sl <= open_price)
            continue;
         QM_TM_MoveSL(ticket, open_price, "atc_ohlc_breakeven");
        }
     }
  }

// No discretionary exit beyond SL/TP and the breakeven shift. Opposite-signal
// handling is covered by cadence re-evaluation (pending cancel + one-position
// guard); the source moved stops, it did not flip on a fresh bar.
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
