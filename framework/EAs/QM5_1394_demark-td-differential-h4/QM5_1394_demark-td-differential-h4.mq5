#property strict
#property version   "5.0"
#property description "QM5_1394 DeMark TD-Differential H4 (2-bar buying/selling pressure exhaustion)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_1394 — DeMark TD-Differential (H4)
// -----------------------------------------------------------------------------
// TD-Differential (DeMark 1994 ch.5 / Perl 2008 ch.9) is a 2-bar primitive
// comparing buying-pressure vs selling-pressure between two adjacent CLOSED
// bars. With MQL5 shift convention (bar[1] = most-recent closed bar):
//   bp[i]   = close[i] - min(low[i],  close[i+1])     (buying force)
//   sp[i]   = max(high[i], close[i+1]) - close[i]     (selling force)
//   diff[i] = bp[i] - sp[i]
//
// The TD-Differential qualification is the SINGLE trigger EVENT:
//   BUY  : close[2]<close[3] AND close[1]<close[2]    (2 consecutive lower closes)
//          AND bp[1]>bp[2] (buying pressure rising)
//          AND sp[1]<sp[2] (selling pressure falling)
//          AND (diff[1]-diff[2]) >= 0.15*ATR_H4       (differential-magnitude gate)
//   SELL : mirror (2 consecutive higher closes, sp[1]>sp[2], bp[1]<bp[2],
//          (sp[1]-sp[2])-(bp[1]-bp[2]) >= 0.15*ATR_H4).
//
// All other conditions are STATES (5-bar local extreme, macro-bias soft-filter,
// volatility regime, spread, single position).
//
// Exits: TP = close[1] +/- 2.0*ATR; hard SL = low[1]-0.5*ATR (BUY) /
//        high[1]+0.5*ATR (SELL); setup-failure hard-exit (close beyond the
//        setup-bar extreme); time-stop at 12 H4 bars.
//
// .DWX invariants honoured: fail-OPEN spread guard; no swap gate; broker-time
// session window via QM_BrokerToUTC-aware MqlDateTime; prior CLOSE referenced
// (close[i+1], never a gap/range); single QM_IsNewBar consume per OnTick;
// all bar arithmetic in-EA (no ML); RISK_FIXED default; one position per magic.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1394;
input int    qm_magic_slot_offset        = 0;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsMode qm_news_mode           = QM_NEWS_PAUSE;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input double strategy_diff_atr_mult      = 0.15;   // differential-magnitude gate (* ATR_H4)
input int    strategy_local_lookback     = 5;      // bars back for new local extreme (low[1]<=min(low[2..6]))
input int    strategy_sma_period         = 200;    // macro-bias soft-filter SMA (H4)
input double strategy_macro_atr_mult     = 5.0;    // macro-bias tolerance (* ATR_H4)
input int    strategy_atr_period         = 14;     // ATR period (H4) for sizing/gates
input double strategy_tp_atr_mult        = 2.0;    // TP = close[1] +/- 2.0 * ATR
input double strategy_sl_atr_mult        = 0.5;    // SL = setup-bar extreme -/+ 0.5 * ATR
input int    strategy_time_stop_bars     = 12;     // time-stop ~2 trading days
input int    strategy_vol_ref_shift      = 40;     // volatility-gate reference ATR shift
input double strategy_vol_lo_mult        = 0.70;   // volatility floor (* ATR[ref])
input double strategy_vol_hi_mult        = 2.50;   // volatility ceiling (* ATR[ref])
input int    strategy_session_start_hr   = 7;      // broker-time session window (entries)
input int    strategy_session_end_hr     = 21;
input int    strategy_friday_cutoff_hr   = 16;     // no new entries after this broker-hour on Friday
input double strategy_spread_atr_mult    = 0.40;   // fail-OPEN spread guard cap (* ATR)

// File-scope setup-bar latch for the setup-failure hard-exit (§ Exit-3).
// Latched at entry; the BUY thesis is invalidated if a later close prints below
// the setup-bar low (SELL: above the setup-bar high).
double   g_setup_low  = 0.0;
double   g_setup_high = 0.0;

// -----------------------------------------------------------------------------
// TD-Differential bar arithmetic at a given closed-bar shift.
// bp = close[shift] - min(low[shift], close[shift+1])
// sp = max(high[shift], close[shift+1]) - close[shift]
// Returns false on any non-positive / degenerate bar read.
// Direct iX reads are perf-allowed bespoke structural math (gated by new-bar).
// -----------------------------------------------------------------------------
bool TDDifferentialAt(const int shift, double &bp, double &sp, double &diff)
  {
   bp = 0.0; sp = 0.0; diff = 0.0;

   const double close_i    = iClose(_Symbol, PERIOD_H4, shift);
   const double low_i      = iLow(_Symbol,  PERIOD_H4, shift);
   const double high_i     = iHigh(_Symbol, PERIOD_H4, shift);
   const double close_prev = iClose(_Symbol, PERIOD_H4, shift + 1);   // prior CLOSE, never a range

   if(close_i <= 0.0 || low_i <= 0.0 || high_i <= 0.0 || close_prev <= 0.0)
      return false;

   const double lower_ref  = (low_i  < close_prev) ? low_i  : close_prev;
   const double higher_ref = (high_i > close_prev) ? high_i : close_prev;

   bp   = close_i - lower_ref;
   sp   = higher_ref - close_i;
   diff = bp - sp;
   return true;
  }

bool GetOurPosition(ulong &ticket, ENUM_POSITION_TYPE &position_type, double &open_price, datetime &open_time)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   open_price = 0.0;
   open_time = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      ticket = t;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

int BarsSincePositionOpen(const datetime open_time)
  {
   if(open_time <= 0)
      return 0;
   const int shift = iBarShift(_Symbol, PERIOD_H4, open_time, false);
   return (shift < 0) ? 0 : shift;
  }

// Lowest low over bars [from .. to] inclusive (closed bars).
double LowestLow(const int from, const int to)
  {
   double lo = iLow(_Symbol, PERIOD_H4, from);
   for(int i = from + 1; i <= to; ++i)
     {
      const double v = iLow(_Symbol, PERIOD_H4, i);
      if(v < lo)
         lo = v;
     }
   return lo;
  }

// Highest high over bars [from .. to] inclusive (closed bars).
double HighestHigh(const int from, const int to)
  {
   double hi = iHigh(_Symbol, PERIOD_H4, from);
   for(int i = from + 1; i <= to; ++i)
     {
      const double v = iHigh(_Symbol, PERIOD_H4, i);
      if(v > hi)
         hi = v;
     }
   return hi;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No-trade filter: broker-time session window, Friday late-cutoff, fail-OPEN
// spread guard. Never blocks management of an already-open position. Cheap O(1).
bool Strategy_NoTradeFilter()
  {
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price;
   datetime open_time;
   if(GetOurPosition(ticket, position_type, open_price, open_time))
      return false;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   // Session gate: European/US-equity hours only (skip Asian-session bars).
   if(dt.hour < strategy_session_start_hr || dt.hour >= strategy_session_end_hr)
      return true;

   // Friday late-cutoff: no new entries after the cutoff hour (weekend overhang).
   if(dt.day_of_week == 5 && dt.hour >= strategy_friday_cutoff_hr)
      return true;

   // fail-OPEN spread guard: only block a genuinely wide spread.
   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr > 0.0 && ask > 0.0 && bid > 0.0 && ask > bid &&
      (ask - bid) > atr * strategy_spread_atr_mult)
      return true;

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price;
   datetime open_time;
   if(GetOurPosition(ticket, position_type, open_price, open_time))
      return false;

   // Closed-bar prices: bar[1] = setup bar, bar[2] = prior, bar[3] = prior-2.
   const double close1 = iClose(_Symbol, PERIOD_H4, 1);
   const double close2 = iClose(_Symbol, PERIOD_H4, 2);
   const double close3 = iClose(_Symbol, PERIOD_H4, 3);
   const double low1   = iLow(_Symbol,  PERIOD_H4, 1);
   const double high1  = iHigh(_Symbol, PERIOD_H4, 1);
   if(close1 <= 0.0 || close2 <= 0.0 || close3 <= 0.0 || low1 <= 0.0 || high1 <= 0.0)
      return false;

   double bp1, sp1, diff1;
   double bp2, sp2, diff2;
   if(!TDDifferentialAt(1, bp1, sp1, diff1) || !TDDifferentialAt(2, bp2, sp2, diff2))
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   // Volatility regime gate: ATR[1] within [lo, hi] * ATR[ref].
   const double atr_ref = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, strategy_vol_ref_shift);
   if(atr_ref <= 0.0)
      return false;
   if(atr < strategy_vol_lo_mult * atr_ref || atr > strategy_vol_hi_mult * atr_ref)
      return false;

   const double sma200 = QM_SMA(_Symbol, PERIOD_H4, strategy_sma_period, 1);
   if(sma200 <= 0.0)
      return false;

   const double mag_gate = strategy_diff_atr_mult * atr;
   const int lookback    = (strategy_local_lookback > 0) ? strategy_local_lookback : 5;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   // ---- BUY: TD-Differential buy setup (exhaustion-of-selling reversal) ----
   // Trigger EVENT: 2 consecutive lower closes + bp rising + sp falling +
   // differential-magnitude gate.
   const bool buy_two_lower = (close2 < close3) && (close1 < close2);
   const bool buy_pressure  = (bp1 > bp2) && (sp1 < sp2);
   const bool buy_magnitude = (diff1 - diff2) >= mag_gate;
   if(buy_two_lower && buy_pressure && buy_magnitude)
     {
      // STATE: fresh local low over [1 .. 1+lookback].
      const double local_low = LowestLow(2, 1 + lookback);
      const bool buy_local   = (low1 <= local_low);
      // STATE: macro-bias soft-filter (avoid deep bear regime).
      const bool buy_macro   = (close1 > sma200 - strategy_macro_atr_mult * atr);

      if(buy_local && buy_macro)
        {
         const double entry = ask;
         double sl = low1 - strategy_sl_atr_mult * atr;
         double tp = close1 + strategy_tp_atr_mult * atr;
         if(sl <= 0.0 || (entry - sl) < point)
            return false;
         req.type   = QM_BUY;
         req.sl     = sl;
         req.tp     = tp;
         req.reason = "TD_DIFFERENTIAL_BUY";
         g_setup_low  = low1;   // latch for setup-failure hard-exit
         g_setup_high = 0.0;
         return true;
        }
     }

   // ---- SELL: mirror (exhaustion-of-buying reversal) ----
   const bool sell_two_higher = (close2 > close3) && (close1 > close2);
   const bool sell_pressure   = (sp1 > sp2) && (bp1 < bp2);
   const bool sell_magnitude  = ((sp1 - sp2) - (bp1 - bp2)) >= mag_gate;
   if(sell_two_higher && sell_pressure && sell_magnitude)
     {
      const double local_high = HighestHigh(2, 1 + lookback);
      const bool sell_local   = (high1 >= local_high);
      const bool sell_macro   = (close1 < sma200 + strategy_macro_atr_mult * atr);

      if(sell_local && sell_macro)
        {
         const double entry = bid;
         double sl = high1 + strategy_sl_atr_mult * atr;
         double tp = close1 - strategy_tp_atr_mult * atr;
         if(tp <= 0.0 || (sl - entry) < point)
            return false;
         req.type   = QM_SELL;
         req.sl     = sl;
         req.tp     = tp;
         req.reason = "TD_DIFFERENTIAL_SELL";
         g_setup_high = high1;  // latch for setup-failure hard-exit
         g_setup_low  = 0.0;
         return true;
        }
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // SL/TP are fixed at entry (hard SL setup-extreme +/- 0.5*ATR, TP 2*ATR).
   // The card's optional partial-TP/BE refinement is deferred; primary exits are
   // TP, hard SL, setup-failure hard-exit (Strategy_ExitSignal), and time-stop.
  }

bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price;
   datetime open_time;
   if(!GetOurPosition(ticket, position_type, open_price, open_time))
      return false;

   // Time-stop: ~2 trading days (12 H4 bars) without TP/SL/setup-failure.
   const int bars_since = BarsSincePositionOpen(open_time);
   if(strategy_time_stop_bars > 0 && bars_since >= strategy_time_stop_bars)
      return true;

   // Setup-failure hard-exit: a later CLOSE beyond the setup-bar extreme signals
   // real continuation, not exhaustion. Reference the just-closed bar's close.
   const double close1 = iClose(_Symbol, PERIOD_H4, 1);
   if(close1 <= 0.0)
      return false;

   if(position_type == POSITION_TYPE_BUY && g_setup_low > 0.0 && close1 < g_setup_low)
      return true;
   if(position_type == POSITION_TYPE_SELL && g_setup_high > 0.0 && close1 > g_setup_high)
      return true;

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1394\",\"strategy\":\"td_differential_h4\"}");
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
   if(!QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode))
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

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
