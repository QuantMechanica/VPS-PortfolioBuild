#property strict
#property version   "5.0"
#property description "QM5_1327 Brooks Pin-Bar Reversal H4"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_1327 Brooks-Style Pin-Bar Reversal (H4)
// -----------------------------------------------------------------------------
// Single-candle reversal (pinocchio / hammer / shooting-star) detected purely
// from the CLOSED signal bar's geometry: small body, one long rejection wick,
// one tiny opposite wick, located at a swing extreme, with an SMA-50 macro-trend
// gate. Entry confirmed on the NEXT closed bar (Brooks next-bar-open semantics).
// Two-stage RR exit (TP1 = 2.0R partial + break-even, TP2 = 3.5R), wick-anchored
// hard SL, and a 12-bar time stop. Mirrors sibling QM5_1328 (Brooks 3-bar) for
// layout, rearm, partial/BE and time-stop handling — only the candle primitive
// differs (single pin-bar vs 3-bar sequence).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1327;
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
input ENUM_TIMEFRAMES strategy_tf        = PERIOD_H4;
input int    strategy_atr_period         = 14;
input int    strategy_sma_period         = 50;
input int    strategy_swing_lookback     = 10;
input double strategy_body_max_frac      = 0.30;  // body <= 0.30 * range
input double strategy_long_wick_min_frac = 0.60;  // rejection wick >= 0.60 * range
input double strategy_short_wick_max_frac= 0.10;  // opposite wick <= 0.10 * range
input double strategy_sma_atr_buffer     = 0.50;  // half-ATR macro-trend buffer
input double strategy_tp1_rr             = 2.0;
input double strategy_tp2_rr             = 3.5;
input double strategy_tp1_close_fraction = 0.50;
input int    strategy_time_stop_bars     = 12;
input int    strategy_rearm_bars         = 3;
input double strategy_spread_mult        = 2.0;
input int    strategy_spread_lookback    = 20;

double   g_median_spread_points   = 0.0;
ulong    g_active_ticket          = 0;
int      g_active_direction       = 0;
double   g_initial_risk_price     = 0.0;
bool     g_tp1_done               = false;
bool     g_strategy_cadence_ready = false;
int      g_rearm_direction        = 0;
int      g_rearm_remaining        = 0;

double PipDistance()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const int pip_factor = (digits == 3 || digits == 5) ? 10 : 1;
   return point * pip_factor;
  }

double BarRange(const int shift)
  {
   return iHigh(_Symbol, strategy_tf, shift) - iLow(_Symbol, strategy_tf, shift); // perf-allowed: fixed closed-bar OHLC structural pattern
  }

double LowestLow(const int first_shift, const int count)
  {
   double low = DBL_MAX;
   for(int shift = first_shift; shift < first_shift + count; ++shift)
      low = MathMin(low, iLow(_Symbol, strategy_tf, shift)); // perf-allowed: bounded swing-low structural scan
   return low;
  }

double HighestHigh(const int first_shift, const int count)
  {
   double high = -DBL_MAX;
   for(int shift = first_shift; shift < first_shift + count; ++shift)
      high = MathMax(high, iHigh(_Symbol, strategy_tf, shift)); // perf-allowed: bounded swing-high structural scan
   return high;
  }

void RefreshSpreadMedian()
  {
   if(!g_strategy_cadence_ready && g_median_spread_points > 0.0)
      return;

   double spreads[];
   ArrayResize(spreads, strategy_spread_lookback);
   int n = 0;
   for(int shift = 1; shift <= strategy_spread_lookback; ++shift)
     {
      const long spread = iSpread(_Symbol, strategy_tf, shift);
      if(spread > 0)
        {
         spreads[n] = (double)spread;
         n++;
        }
     }

   if(n <= 0)
     {
      g_median_spread_points = 0.0;
      return;
     }

   ArrayResize(spreads, n);
   ArraySort(spreads);
   if((n % 2) == 1)
      g_median_spread_points = spreads[n / 2];
   else
      g_median_spread_points = 0.5 * (spreads[n / 2 - 1] + spreads[n / 2]);
  }

bool SelectOurPosition(ulong &ticket, int &direction, double &open_price, double &sl, double &tp, double &volume, datetime &open_time)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong pos_ticket = PositionGetTicket(i);
      if(pos_ticket == 0 || !PositionSelectByTicket(pos_ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = pos_ticket;
      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      direction = (ptype == POSITION_TYPE_BUY) ? 1 : -1;
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      sl = PositionGetDouble(POSITION_SL);
      tp = PositionGetDouble(POSITION_TP);
      volume = PositionGetDouble(POSITION_VOLUME);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

void RefreshPositionLifecycle()
  {
   ulong ticket = 0;
   int direction = 0;
   double open_price = 0.0;
   double sl = 0.0;
   double tp = 0.0;
   double volume = 0.0;
   datetime open_time = 0;

   if(SelectOurPosition(ticket, direction, open_price, sl, tp, volume, open_time))
     {
      if(ticket != g_active_ticket)
        {
         g_active_ticket = ticket;
         g_active_direction = direction;
         g_initial_risk_price = MathAbs(open_price - sl);
         g_tp1_done = false;
        }
      return;
     }

   if(g_active_ticket != 0)
     {
      g_rearm_direction = g_active_direction;
      g_rearm_remaining = MathMax(strategy_rearm_bars, 0);
     }

   g_active_ticket = 0;
   g_active_direction = 0;
   g_initial_risk_price = 0.0;
   g_tp1_done = false;
  }

void AdvanceRearmCountdown()
  {
   if(g_rearm_remaining <= 0)
     {
      g_rearm_remaining = 0;
      g_rearm_direction = 0;
      return;
     }

   g_rearm_remaining--;
   if(g_rearm_remaining <= 0)
      g_rearm_direction = 0;
  }

bool RearmBlocksDirection(const int direction)
  {
   if(g_rearm_remaining <= 0 || g_rearm_direction != direction)
      return false;
   return true;
  }

// Bullish pin-bar (hammer) on the last CLOSED signal bar (shift 1).
//   body  <= body_max_frac * range
//   lower_wick >= long_wick_min_frac * range   (rejection from below)
//   upper_wick <= short_wick_max_frac * range
//   low == LowestLow(swing_lookback)            (swing extreme)
//   close > SMA50 - 0.5*ATR                      (macro-trend gate)
bool PatternBuy(double &entry_sl, double &entry_tp)
  {
   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   const double sma = QM_SMA(_Symbol, strategy_tf, strategy_sma_period, 1);
   const double pip = PipDistance();
   if(atr <= 0.0 || sma <= 0.0 || pip <= 0.0)
      return false;

   const double o1 = iOpen(_Symbol, strategy_tf, 1);  // perf-allowed: fixed closed-bar OHLC structural pattern
   const double c1 = iClose(_Symbol, strategy_tf, 1); // perf-allowed: fixed closed-bar OHLC structural pattern
   const double h1 = iHigh(_Symbol, strategy_tf, 1);  // perf-allowed: fixed closed-bar OHLC structural pattern
   const double l1 = iLow(_Symbol, strategy_tf, 1);   // perf-allowed: fixed closed-bar OHLC structural pattern

   const double total_range = h1 - l1;
   if(total_range <= 0.0)
      return false;

   const double body       = MathAbs(c1 - o1);
   const double upper_wick = h1 - MathMax(o1, c1);
   const double lower_wick = MathMin(o1, c1) - l1;

   if(body > strategy_body_max_frac * total_range)
      return false;
   if(lower_wick < strategy_long_wick_min_frac * total_range)
      return false;
   if(upper_wick > strategy_short_wick_max_frac * total_range)
      return false;

   // Swing-low test: the signal-bar low is the lowest over the lookback window
   // (the window includes the signal bar itself at shift 1).
   if(l1 > LowestLow(1, strategy_swing_lookback) + _Point * 0.5)
      return false;

   // Macro-trend gate: trade longs only at/above SMA-50 minus half-ATR.
   if(c1 <= sma - strategy_sma_atr_buffer * atr)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   entry_sl = NormalizeDouble(l1 - pip, _Digits);
   const double risk = ask - entry_sl;
   if(ask <= 0.0 || risk <= 0.0)
      return false;
   entry_tp = NormalizeDouble(ask + strategy_tp2_rr * risk, _Digits);
   return true;
  }

// Bearish pin-bar (shooting star) — mirror of PatternBuy.
bool PatternSell(double &entry_sl, double &entry_tp)
  {
   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   const double sma = QM_SMA(_Symbol, strategy_tf, strategy_sma_period, 1);
   const double pip = PipDistance();
   if(atr <= 0.0 || sma <= 0.0 || pip <= 0.0)
      return false;

   const double o1 = iOpen(_Symbol, strategy_tf, 1);  // perf-allowed: fixed closed-bar OHLC structural pattern
   const double c1 = iClose(_Symbol, strategy_tf, 1); // perf-allowed: fixed closed-bar OHLC structural pattern
   const double h1 = iHigh(_Symbol, strategy_tf, 1);  // perf-allowed: fixed closed-bar OHLC structural pattern
   const double l1 = iLow(_Symbol, strategy_tf, 1);   // perf-allowed: fixed closed-bar OHLC structural pattern

   const double total_range = h1 - l1;
   if(total_range <= 0.0)
      return false;

   const double body       = MathAbs(c1 - o1);
   const double upper_wick = h1 - MathMax(o1, c1);
   const double lower_wick = MathMin(o1, c1) - l1;

   if(body > strategy_body_max_frac * total_range)
      return false;
   if(upper_wick < strategy_long_wick_min_frac * total_range)
      return false;
   if(lower_wick > strategy_short_wick_max_frac * total_range)
      return false;

   if(h1 < HighestHigh(1, strategy_swing_lookback) - _Point * 0.5)
      return false;

   if(c1 >= sma + strategy_sma_atr_buffer * atr)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   entry_sl = NormalizeDouble(h1 + pip, _Digits);
   const double risk = entry_sl - bid;
   if(bid <= 0.0 || risk <= 0.0)
      return false;
   entry_tp = NormalizeDouble(bid - strategy_tp2_rr * risk, _Digits);
   return true;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   RefreshPositionLifecycle();
   RefreshSpreadMedian();

   // Fail-OPEN spread guard: .DWX quotes 0 spread in the tester, so only block
   // a genuinely wide live spread. Never reject on zero/median-absent spread.
   if(g_median_spread_points > 0.0 && strategy_spread_mult > 0.0)
     {
      const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if((double)current_spread > strategy_spread_mult * g_median_spread_points)
         return true;
     }

   return false;
  }

// Trade Entry — fires on the bar AFTER the signal bar (signal bar = shift 1),
// i.e. Brooks next-bar-open confirmation: we evaluate on each new closed bar
// and enter at market against the just-closed pin bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   RefreshPositionLifecycle();
   if(g_active_ticket != 0)
      return false;

   double sl = 0.0;
   double tp = 0.0;
   if(!RearmBlocksDirection(1) && PatternBuy(sl, tp))
     {
      req.type = QM_BUY;
      req.sl = sl;
      req.tp = tp;
      req.reason = "BROOKS_PINBAR_REVERSAL_BUY_H4";
      g_initial_risk_price = MathAbs(SymbolInfoDouble(_Symbol, SYMBOL_ASK) - sl);
      g_tp1_done = false;
      return true;
     }

   if(!RearmBlocksDirection(-1) && PatternSell(sl, tp))
     {
      req.type = QM_SELL;
      req.sl = sl;
      req.tp = tp;
      req.reason = "BROOKS_PINBAR_REVERSAL_SELL_H4";
      g_initial_risk_price = MathAbs(sl - SymbolInfoDouble(_Symbol, SYMBOL_BID));
      g_tp1_done = false;
      return true;
     }

   return false;
  }

// Trade Management — TP1 at 2.0R: close 50%, move SL to break-even (one-time
// static shift, not an adaptive trail). The remaining 50% rides to the TP2
// price set at entry (3.5R) or the break-even SL.
void Strategy_ManageOpenPosition()
  {
   RefreshPositionLifecycle();
   if(g_active_ticket == 0 || g_tp1_done || g_initial_risk_price <= 0.0)
      return;

   if(!PositionSelectByTicket(g_active_ticket))
      return;

   const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const bool is_buy = (ptype == POSITION_TYPE_BUY);
   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double volume = PositionGetDouble(POSITION_VOLUME);
   const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double moved = is_buy ? (market - open_price) : (open_price - market);

   if(moved >= strategy_tp1_rr * g_initial_risk_price)
     {
      const double close_lots = volume * strategy_tp1_close_fraction;
      if(QM_TM_PartialClose(g_active_ticket, close_lots, QM_EXIT_PARTIAL))
        {
         QM_TM_MoveSL(g_active_ticket, NormalizeDouble(open_price, _Digits), "brooks_pinbar_tp1_move_sl_to_be");
         g_tp1_done = true;
        }
     }
  }

// Trade Close — time stop: if neither TP1 nor SL hit within strategy_time_stop_bars
// (12 H4 bars = 2 trading days), close at the next H4 close. Once TP1 has fired
// (g_tp1_done) the remainder rides to TP2/BE, so the time stop no longer applies.
bool Strategy_ExitSignal()
  {
   RefreshPositionLifecycle();
   if(g_active_ticket == 0 || g_tp1_done)
      return false;
   if(!g_strategy_cadence_ready)
      return false;

   if(!PositionSelectByTicket(g_active_ticket))
      return false;

   const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
   const int bars_since_open = iBarShift(_Symbol, strategy_tf, open_time, false);
   return (bars_since_open >= strategy_time_stop_bars);
  }

// News Filter Hook (callable for P8 News Impact phase) — also blocks if the
// candidate signal bar overlapped a high-impact event (±2h handled centrally).
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(!QM_NewsAllowsTrade(_Symbol, broker_time, qm_news_mode))
      return true;

   const datetime bar_time = iTime(_Symbol, strategy_tf, 1); // perf-allowed: signal-bar news overlap check
   if(bar_time > 0 && !QM_NewsAllowsTrade(_Symbol, bar_time, qm_news_mode))
      return true;

   return false;
  }

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1327\",\"ea\":\"brooks-pin-bar-reversal-h4\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   g_strategy_cadence_ready = false;

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(!QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   g_strategy_cadence_ready = QM_IsNewBar(_Symbol, strategy_tf);
   if(g_strategy_cadence_ready)
      AdvanceRearmCountdown();

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

   if(!g_strategy_cadence_ready)
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
