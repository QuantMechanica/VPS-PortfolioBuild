#property strict
#property version   "5.0"
#property description "QM5_11366 connors-double7s-sma200-d1 — Connors Double 7's, SMA(200) trend + 7-day close extreme (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11366 connors-double7s-sma200-d1
// -----------------------------------------------------------------------------
// Source: Larry Connors & Cesar Alvarez, "Short-Term Trading Strategies That
// Work" (2009), "Double 7's Strategy". Card:
// artifacts/cards_approved/QM5_11366_connors-double7s-sma200-d1.md (APPROVED).
//
// Mechanics (D1, closed-bar reads at shift 1..N; gapless-safe = closes only):
//   Trend STATE  : close[1] vs SMA(200) — above = uptrend, below = downtrend.
//   Entry EVENT  : close[1] is the lowest close of the last N=7 closed bars
//                  (long, in uptrend) / highest close of last 7 (short, in
//                  downtrend). The "next bar open" entry is realised by firing
//                  on the first tick of the new bar after that close.
//   Exit  EVENT  : long  -> close[1] is the highest close of last 7 closes.
//                  short -> close[1] is the lowest  close of last 7 closes.
//   Trend break  : long  -> close[1] < SMA(200) ; short -> close[1] > SMA(200).
//   Time stop    : exit after strategy_max_hold_bars closed bars.
//   P2 stops/take: SL = ATR(14) * sl_atr_mult ; TP = ATR(14) * tp_atr_mult.
//   Spread guard : fail-open on .DWX zero modeled spread; block only a
//                  genuinely wide spread > spread_pct_of_stop of the stop dist.
//
// All extremes are computed from PRIOR CLOSED CLOSES (shift 1..N) — no range,
// no intrabar, gapless-CFD safe. Only the 5 Strategy_* hooks + Strategy inputs
// are EA-specific; the rest is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11366;
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
input int    strategy_sma_period         = 200;    // trend-filter SMA period (close)
input int    strategy_extreme_lookback   = 7;      // N-day close extreme lookback (Connors "7")
input int    strategy_atr_period         = 14;     // ATR period for P2 stop / target
input double strategy_sl_atr_mult        = 1.5;    // SL distance = mult * ATR (card P2)
input double strategy_tp_atr_mult        = 2.0;    // TP distance = mult * ATR (card P2)
input int    strategy_max_hold_bars      = 10;     // time-stop: exit after N closed bars
input double strategy_spread_pct_of_stop = 15.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Helper: is close[1] the lowest/highest close over shifts 1..lookback?
// Pure arithmetic over prior CLOSED closes (gapless-safe). perf-allowed:
// single-shift iClose reads, bounded loop (lookback ~7), gated by QM_IsNewBar.
// -----------------------------------------------------------------------------
bool IsNDayLowClose(const int lookback)
  {
   const double c1 = iClose(_Symbol, _Period, 1); // perf-allowed: closed-bar read
   if(c1 <= 0.0)
      return false;
   for(int s = 2; s <= lookback; ++s)
     {
      const double cs = iClose(_Symbol, _Period, s); // perf-allowed: closed-bar read
      if(cs <= 0.0)
         return false;
      if(c1 > cs)
         return false; // a more-recent-window close is lower -> not the N-day low
     }
   return true;
  }

bool IsNDayHighClose(const int lookback)
  {
   const double c1 = iClose(_Symbol, _Period, 1); // perf-allowed: closed-bar read
   if(c1 <= 0.0)
      return false;
   for(int s = 2; s <= lookback; ++s)
     {
      const double cs = iClose(_Symbol, _Period, s); // perf-allowed: closed-bar read
      if(cs <= 0.0)
         return false;
      if(c1 < cs)
         return false; // a window close is higher -> not the N-day high
     }
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only; regime/signal work runs on the
// closed-bar path in Strategy_EntrySignal. Fail-open on .DWX zero spread.
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

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate). One open
// position per symbol/magic. Long in uptrend on a fresh 7-day low close; short
// in downtrend on a fresh 7-day high close.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double sma = QM_SMA(_Symbol, _Period, strategy_sma_period, 1);
   if(sma <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: closed-bar read
   if(close1 <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double entry_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0 || entry_bid <= 0.0)
      return false;

   // LONG: macro uptrend + 7-day low close (pullback in uptrend).
   if(close1 > sma && IsNDayLowClose(strategy_extreme_lookback))
     {
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
      const double tp = QM_TakeATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_tp_atr_mult);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "connors_double7s_long";
      return true;
     }

   // SHORT: macro downtrend + 7-day high close (rally in downtrend).
   if(close1 < sma && IsNDayHighClose(strategy_extreme_lookback))
     {
      const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry_bid, atr_value, strategy_sl_atr_mult);
      const double tp = QM_TakeATRFromValue(_Symbol, QM_SELL, entry_bid, atr_value, strategy_tp_atr_mult);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "connors_double7s_short";
      return true;
     }

   return false;
  }

// No active trade management beyond the fixed ATR stop/target plus the
// discretionary exits handled in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Discretionary exit (closed-bar logic; framework only fires this branch on the
// open-position magic). Returns TRUE to close. Connors exit = opposite N-day
// close extreme; plus trend-break short-circuit and a max-hold time stop.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Exit reads are cheap closed-bar reads (shift 1) + handle-pooled SMA/ATR,
   // so they are O(1) and safe to evaluate per tick. SL/TP are enforced by the
   // broker; this hook adds the Connors opposite-extreme / trend-break / time
   // stop on top.
   const double sma = QM_SMA(_Symbol, _Period, strategy_sma_period, 1);
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: closed-bar read
   if(sma <= 0.0 || close1 <= 0.0)
      return false;

   // Determine the side of the currently open position for this magic.
   bool is_long = false;
   bool found = false;
   datetime open_time = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      is_long = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      found = true;
      break;
     }
   if(!found)
      return false;

   // Time stop: exit if the position has been held >= max_hold_bars closed bars.
   if(strategy_max_hold_bars > 0)
     {
      const datetime cur_bar = iTime(_Symbol, _Period, 0); // perf-allowed: bar-open time
      const long held_secs = (long)(cur_bar - open_time);
      const long bar_secs = (long)PeriodSeconds(_Period);
      if(bar_secs > 0 && held_secs >= (long)strategy_max_hold_bars * bar_secs)
         return true;
     }

   if(is_long)
     {
      // Trend break: close fell below SMA(200).
      if(close1 < sma)
         return true;
      // Connors exit: 7-day high close reached.
      if(IsNDayHighClose(strategy_extreme_lookback))
         return true;
     }
   else
     {
      // Trend break: close rose above SMA(200).
      if(close1 > sma)
         return true;
      // Connors exit: 7-day low close reached.
      if(IsNDayLowClose(strategy_extreme_lookback))
         return true;
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
