#property strict
#property version   "5.0"
#property description "QM5_11698 pl-daily-engulfing-swing-d1 — Paul Langer daily engulfing swing, SMA200 trend filter"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11698 pl-daily-engulfing-swing-d1
// -----------------------------------------------------------------------------
// Source: Paul Langer, "A Swing Trading Strategy", in: The Black Book of Forex
//         Trading, Alura Publishing, 2015 (pp.57-63). Card:
//         artifacts/cards_approved/QM5_11698_pl-daily-engulfing-swing-d1.md
//         (g0_status: APPROVED). Sibling of QM5_11501 (same strategy family),
//         implemented against THIS card's exit/stop specification.
//
// Mechanics (D1 swing, closed-bar reads at shift 1 = the engulfing bar):
//   Trend STATE  : LONG  iff close[1] > SMA(200)[1];  SHORT iff close[1] < SMA(200)[1].
//   Trigger EVENT: a completed bullish (long) / bearish (short) ENGULFING D1 bar
//                  at shift 1. ONE event per closed bar (the QM_IsNewBar gate
//                  guarantees this hook runs once per new D1 bar). The engulfing
//                  bar is the only trigger; the trend MA is a pure state filter,
//                  so the two-cross-same-bar zero-trade trap cannot occur.
//   Gapless CFD  : .DWX FX CFDs are gapless (open[0] == close[1]). Body engulf
//                  therefore uses prior CLOSE/OPEN with >=/<= (not a strict gap),
//                  so the rule still fires (DWX invariant 6).
//   Entry order  : pending STOP a few pips beyond the engulfing bar's extreme
//                  (card: BUY STOP 4-6 pips above High[1]). The order expires
//                  after ~1 D1 bar so only immediate follow-through is taken.
//   Stop         : the opposite extreme of the engulfing bar (Low[1]-buffer for
//                  long), or 2*ATR(14,D1) if that distance is SMALLER (card:
//                  "or 2*ATR(14,D1) if smaller"). Capped at strategy_sl_cap_pips.
//   Take profit  : Entry + 1.5 * (High[1]-Low[1]) for long (mirror for short) —
//                  card "TP at 150% of the engulfing candle range from entry".
//   Management   : break-even after the first D1 bar that closes in profit.
//                  Time stop after strategy_max_hold_bars D1 bars.
//   No-Friday    : suppress NEW entries on Friday (card filter, optional input).
//   Spread guard : block only a genuinely wide spread (fail-open on .DWX zero
//                  modeled spread — DWX invariant 1).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11698;
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
input int    strategy_sma_period         = 200;    // D1 trend-filter SMA period
input double strategy_entry_buffer_pips  = 5.0;    // stop-order offset beyond engulfing extreme (4-6 pips)
input int    strategy_atr_period         = 14;     // ATR period for the alt stop
input double strategy_atr_sl_mult        = 2.0;    // alt stop distance = mult * ATR (used if smaller)
input double strategy_tp_range_mult      = 1.5;    // TP = entry +/- mult * engulfing range
input double strategy_sl_cap_pips        = 100.0;  // P2 stop-loss cap (pips)
input int    strategy_max_hold_bars      = 10;     // time stop: close after this many D1 bars
input double strategy_spread_cap_pips    = 30.0;   // skip only a genuinely wide spread (pips)
input bool   strategy_no_friday_entry    = true;   // suppress NEW entries on Friday

// -----------------------------------------------------------------------------
// File-scope state (one open position per magic, so single-slot bookkeeping).
// -----------------------------------------------------------------------------
datetime g_entry_bar_time = 0;   // D1 bar-open time when the current position opened
bool     g_be_done        = false; // break-even already applied for current position

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// pip size for the active symbol (5-digit / JPY aware). Uses the framework
// pips->price-distance converter so a 1-pip distance is scale-correct.
double PipSize()
  {
   return QM_StopRulesPipsToPriceDistance(_Symbol, 1);
  }

// Find this EA's open ticket (one position per magic). Returns 0 if none.
ulong CurrentTicket()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      return ticket;
     }
   return 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only (fail-open on .DWX zero spread);
// the no-Friday-entry rule is applied in Strategy_EntrySignal so it suppresses
// only NEW entries, not position management.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double spread = ask - bid;
   const double cap    = strategy_spread_cap_pips * PipSize();
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(cap > 0.0 && spread > 0.0 && spread > cap)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate). Detects a
// completed D1 engulfing bar in the direction of the SMA(200) trend and places a
// pending stop order beyond the engulfing extreme.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic; also skip if a pending order waits.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;
   if(OrdersTotal() > 0)
     {
      const int magic = QM_FrameworkMagic();
      for(int i = OrdersTotal() - 1; i >= 0; --i)
        {
         const ulong oticket = OrderGetTicket(i);
         if(oticket == 0)
            continue;
         if(OrderGetInteger(ORDER_MAGIC) == magic &&
            OrderGetString(ORDER_SYMBOL) == _Symbol)
            return false; // a pending engulfing stop order is already live
        }
     }

   // No new entries on Friday (card filter). TimeCurrent() == broker time;
   // the new D1 bar opens at the broker day roll, so day-of-week is exact.
   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5) // Friday
         return false;
     }

   // --- Closed-bar OHLC of the engulfing bar (shift 1) and prior bar (shift 2).
   // perf-allowed: bespoke candle-pattern math, single closed-bar reads only.
   const double o1 = iOpen(_Symbol,  PERIOD_D1, 1);
   const double h1 = iHigh(_Symbol,  PERIOD_D1, 1);
   const double l1 = iLow(_Symbol,   PERIOD_D1, 1);
   const double c1 = iClose(_Symbol, PERIOD_D1, 1);
   const double o2 = iOpen(_Symbol,  PERIOD_D1, 2);
   const double h2 = iHigh(_Symbol,  PERIOD_D1, 2);
   const double l2 = iLow(_Symbol,   PERIOD_D1, 2);
   const double c2 = iClose(_Symbol, PERIOD_D1, 2);
   if(o1 <= 0.0 || h1 <= 0.0 || l1 <= 0.0 || c1 <= 0.0 ||
      o2 <= 0.0 || h2 <= 0.0 || l2 <= 0.0 || c2 <= 0.0)
      return false;

   // --- Trend STATE filter: SMA(200) on D1, closed bar (shift 1) ---
   const double sma = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 1, PRICE_CLOSE);
   if(sma <= 0.0)
      return false;

   const double pip = PipSize();
   if(pip <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);

   // Engulfing-bar range used for the 150%-range take-profit target.
   const double engulf_range = h1 - l1;
   if(engulf_range <= 0.0)
      return false;

   // --- Bullish engulfing (gapless-safe body engulf + outer range engulf) ---
   //   engulfing bar up: c1 > o1 ; prior bar down: c2 < o2 ;
   //   body engulfs prior body: o1 <= c2 (open <= prior close) AND c1 >= o2 ;
   //   outer range engulf: h1 > h2 AND l1 < l2.
   const bool bull_engulf = (c1 > o1) && (c2 < o2) &&
                            (o1 <= c2) && (c1 >= o2) &&
                            (h1 > h2) && (l1 < l2);
   // --- Bearish engulfing (symmetric) ---
   const bool bear_engulf = (c1 < o1) && (c2 > o2) &&
                            (o1 >= c2) && (c1 <= o2) &&
                            (h1 > h2) && (l1 < l2);

   const bool uptrend   = (c1 > sma);
   const bool downtrend = (c1 < sma);

   if(bull_engulf && uptrend)
     {
      // Pending BuyStop above the engulfing high.
      double entry = h1 + strategy_entry_buffer_pips * pip;

      // Stop: engulfing low minus buffer, OR 2*ATR below entry if that is SMALLER
      // (closer to entry, i.e. tighter) — card: "or 2*ATR(14,D1) if smaller".
      double sl = l1 - strategy_entry_buffer_pips * pip;
      if(atr_value > 0.0)
        {
         const double atr_sl = entry - strategy_atr_sl_mult * atr_value;
         if(atr_sl > sl) // atr_sl closer to entry => smaller stop distance
            sl = atr_sl;
        }
      // Enforce the P2 stop-loss cap (distance entry->sl).
      const double cap_dist = strategy_sl_cap_pips * pip;
      if((entry - sl) > cap_dist)
         sl = entry - cap_dist;
      if(entry <= 0.0 || sl <= 0.0 || entry <= sl)
         return false;

      // TP at 150% of the engulfing range from entry.
      const double tp = entry + strategy_tp_range_mult * engulf_range;

      req.type               = QM_BUY_STOP;
      req.price              = QM_TM_NormalizePrice(_Symbol, entry);
      req.sl                 = QM_TM_NormalizePrice(_Symbol, sl);
      req.tp                 = QM_TM_NormalizePrice(_Symbol, tp);
      req.reason             = "langer_engulf_long";
      req.symbol_slot        = qm_magic_slot_offset;
      req.expiration_seconds = 26 * 3600; // ~1 D1 bar: cancel if not triggered
      return true;
     }

   if(bear_engulf && downtrend)
     {
      // Pending SellStop below the engulfing low.
      double entry = l1 - strategy_entry_buffer_pips * pip;

      // Stop: engulfing high plus buffer, OR 2*ATR above entry if that is SMALLER.
      double sl = h1 + strategy_entry_buffer_pips * pip;
      if(atr_value > 0.0)
        {
         const double atr_sl = entry + strategy_atr_sl_mult * atr_value;
         if(atr_sl < sl) // atr_sl closer to entry => smaller stop distance
            sl = atr_sl;
        }
      const double cap_dist = strategy_sl_cap_pips * pip;
      if((sl - entry) > cap_dist)
         sl = entry + cap_dist;
      if(entry <= 0.0 || sl <= 0.0 || sl <= entry)
         return false;

      const double tp = entry - strategy_tp_range_mult * engulf_range;
      if(tp <= 0.0)
         return false;

      req.type               = QM_SELL_STOP;
      req.price              = QM_TM_NormalizePrice(_Symbol, entry);
      req.sl                 = QM_TM_NormalizePrice(_Symbol, sl);
      req.tp                 = QM_TM_NormalizePrice(_Symbol, tp);
      req.reason             = "langer_engulf_short";
      req.symbol_slot        = qm_magic_slot_offset;
      req.expiration_seconds = 26 * 3600;
      return true;
     }

   return false;
  }

// Trade management: break-even after the first profitable D1 close + bar
// accounting for the time stop. Runs every tick; reads pooled closed-bar data.
void Strategy_ManageOpenPosition()
  {
   const ulong ticket = CurrentTicket();
   if(ticket == 0)
     {
      // No open position — reset per-trade state for the next fill.
      g_entry_bar_time = 0;
      g_be_done        = false;
      return;
     }

   if(!PositionSelectByTicket(ticket))
      return;

   const long   pos_type   = PositionGetInteger(POSITION_TYPE);
   const double entry_px   = PositionGetDouble(POSITION_PRICE_OPEN);
   const double cur_sl     = PositionGetDouble(POSITION_SL);

   // Latch the entry bar-open time once, so the time stop counts D1 bars held.
   if(g_entry_bar_time == 0)
      g_entry_bar_time = (datetime)PositionGetInteger(POSITION_TIME);

   // --- Break-even after the first D1 bar closes in the profit direction ---
   if(!g_be_done && g_entry_bar_time > 0)
     {
      const datetime last_closed = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: bar-time read
      if(last_closed > g_entry_bar_time)
        {
         const double close1 = iClose(_Symbol, PERIOD_D1, 1);
         if(pos_type == POSITION_TYPE_BUY && close1 > entry_px)
           {
            if(cur_sl < entry_px)
               QM_TM_MoveSL(ticket, QM_TM_NormalizePrice(_Symbol, entry_px), "break_even");
            g_be_done = true;
           }
         else if(pos_type == POSITION_TYPE_SELL && close1 < entry_px)
           {
            if(cur_sl <= 0.0 || cur_sl > entry_px)
               QM_TM_MoveSL(ticket, QM_TM_NormalizePrice(_Symbol, entry_px), "break_even");
            g_be_done = true;
           }
        }
     }
  }

// Discretionary exit: time stop after strategy_max_hold_bars D1 bars held.
bool Strategy_ExitSignal()
  {
   const ulong ticket = CurrentTicket();
   if(ticket == 0)
      return false;
   if(g_entry_bar_time <= 0)
      return false;

   const datetime now_bar = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: current bar-open time
   if(now_bar <= 0)
      return false;

   const long bars_held = (long)((now_bar - g_entry_bar_time) / (PeriodSeconds(PERIOD_D1)));
   if(bars_held >= strategy_max_hold_bars)
      return true;

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
