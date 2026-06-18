#property strict
#property version   "5.0"
#property description "QM5_1362 Brooks 2-Bar Reversal H4"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_1362 Brooks-Style 2-Bar Reversal (H4)
// -----------------------------------------------------------------------------
// Two-bar reversal sequence detected purely from the last two CLOSED bars'
// geometry. A meaningful trend-bar (bar[2]) is followed immediately by an
// opposite-direction reversal-bar (bar[1]) that closes back THROUGH the
// trend-bar's body midpoint after dipping into trend-bar territory
// (failed-extension primitive), located at a 10-bar swing extreme, with an
// optional SMA-50 macro-bias gate.
//
// The pattern COMPLETION on bar[1]'s close is the single trigger EVENT; the
// swing-extreme location and macro-bias are STATE. Entry fires at market on
// the next bar open (Brooks next-bar-open confirmation). Exit: R-multiple TP
// on the reversal-bar range, a one-time break-even shift at +1R(range), and a
// 12-bar time stop. Hard wick-anchored SL, no adaptive trailing. Layout mirrors
// sibling QM5_1327 (Brooks pin-bar) — only the candle primitive differs
// (two-bar sequence vs single pin-bar).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1362;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_tf            = PERIOD_H4;
input int    strategy_atr_period             = 14;
input int    strategy_sma_period             = 50;
input int    strategy_swing_lookback         = 10;
input double strategy_body_min_frac          = 0.55;  // both bars: body >= 0.55 * range
input double strategy_trend_range_atr_frac   = 0.50;  // trend-bar range >= 0.50 * ATR
input double strategy_rev_range_frac         = 0.70;  // reversal range >= 0.70 * trend range
input double strategy_rev_range_atr_frac     = 0.70;  // reversal range >= 0.70 * ATR (entry gate)
input double strategy_swing_atr_frac         = 0.50;  // pattern extreme within 0.50*ATR of swing
input bool   strategy_use_macro_bias         = true;  // require close[1] vs SMA50 agreement
input double strategy_sl_buffer_atr          = 0.30;  // SL buffer beyond pattern extreme
input double strategy_sl_cap_atr             = 2.50;  // cap on initial SL distance
input double strategy_tp_range_mult          = 2.0;   // TP = entry + R_mult * reversal range
input double strategy_be_trigger_range_mult  = 1.0;   // BE shift after +1.0 * reversal range
input int    strategy_time_stop_bars         = 12;
input int    strategy_rearm_bars             = 3;
input double strategy_spread_atr_frac        = 0.40;  // spread guard: spread < 0.40 * ATR

ulong    g_active_ticket          = 0;
int      g_active_direction       = 0;
double   g_signal_range           = 0.0;   // reversal-bar range at entry (for BE + ref)
bool     g_be_done                = false;
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
         g_be_done = false;
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
   g_signal_range = 0.0;
   g_be_done = false;
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

// Bullish 2-bar reversal on the last two CLOSED bars: trend-bar=bar[2],
// reversal-bar=bar[1]. Returns the reversal-bar range via out_range.
//   bar[2]: bear, body>=0.55*range, range>=0.50*ATR              (trend-down-bar)
//   bar[1]: bull, body>=0.55*range,
//           close[1] > (open[2]+close[2])/2,                     (close-through-midpoint)
//           low[1] <= low[2],                                    (failed-extension dip)
//           range[1] >= 0.70*range[2] AND range[1] >= 0.70*ATR   (committed body)
//   swing: low[1] within 0.50*ATR of swing-low(10)               (at swing extreme)
//   macro: close[1] > SMA50 (optional)                           (bias agreement)
bool PatternBuy(double &entry_sl, double &entry_tp, double &out_range)
  {
   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   const double pip = PipDistance();
   if(atr <= 0.0 || pip <= 0.0)
      return false;

   const double o2 = iOpen(_Symbol, strategy_tf, 2);  // perf-allowed: fixed closed-bar OHLC structural pattern
   const double c2 = iClose(_Symbol, strategy_tf, 2); // perf-allowed: fixed closed-bar OHLC structural pattern
   const double h2 = iHigh(_Symbol, strategy_tf, 2);  // perf-allowed: fixed closed-bar OHLC structural pattern
   const double l2 = iLow(_Symbol, strategy_tf, 2);   // perf-allowed: fixed closed-bar OHLC structural pattern

   const double o1 = iOpen(_Symbol, strategy_tf, 1);  // perf-allowed: fixed closed-bar OHLC structural pattern
   const double c1 = iClose(_Symbol, strategy_tf, 1); // perf-allowed: fixed closed-bar OHLC structural pattern
   const double h1 = iHigh(_Symbol, strategy_tf, 1);  // perf-allowed: fixed closed-bar OHLC structural pattern
   const double l1 = iLow(_Symbol, strategy_tf, 1);   // perf-allowed: fixed closed-bar OHLC structural pattern

   const double range2 = h2 - l2;
   const double range1 = h1 - l1;
   if(range2 <= 0.0 || range1 <= 0.0)
      return false;

   // Trend-bar (bar[2]): meaningful down-bar.
   if(!(c2 < o2))
      return false;
   if(MathAbs(c2 - o2) < strategy_body_min_frac * range2)
      return false;
   if(range2 < strategy_trend_range_atr_frac * atr)
      return false;

   // Reversal-bar (bar[1]): up-bar closing through trend-bar midpoint.
   if(!(c1 > o1))
      return false;
   if(MathAbs(c1 - o1) < strategy_body_min_frac * range1)
      return false;
   const double midpoint2 = 0.5 * (o2 + c2);
   if(c1 <= midpoint2)
      return false;
   if(l1 > l2)                                  // failed-extension: dip into trend-bar territory
      return false;

   // Range agreement: reversal-bar isn't a doji + meaningful absolute range.
   if(range1 < strategy_rev_range_frac * range2)
      return false;
   if(range1 < strategy_rev_range_atr_frac * atr)
      return false;

   // Swing-extreme context: pattern low at/near the 10-bar swing low.
   const double swing_low = LowestLow(1, strategy_swing_lookback);
   if(l1 > swing_low + strategy_swing_atr_frac * atr)
      return false;

   // Macro-bias agreement (optional).
   if(strategy_use_macro_bias)
     {
      const double sma = QM_SMA(_Symbol, strategy_tf, strategy_sma_period, 1);
      if(sma <= 0.0 || c1 <= sma)
         return false;
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0.0)
      return false;

   double sl = l1 - strategy_sl_buffer_atr * atr;
   const double sl_cap = strategy_sl_cap_atr * atr;
   if(ask - sl > sl_cap)                        // cap initial SL distance
      sl = ask - sl_cap;
   entry_sl = NormalizeDouble(sl, _Digits);
   const double risk = ask - entry_sl;
   if(risk <= 0.0)
      return false;

   entry_tp = NormalizeDouble(ask + strategy_tp_range_mult * range1, _Digits);
   out_range = range1;
   return true;
  }

// Bearish 2-bar reversal — mirror of PatternBuy.
bool PatternSell(double &entry_sl, double &entry_tp, double &out_range)
  {
   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   const double pip = PipDistance();
   if(atr <= 0.0 || pip <= 0.0)
      return false;

   const double o2 = iOpen(_Symbol, strategy_tf, 2);  // perf-allowed: fixed closed-bar OHLC structural pattern
   const double c2 = iClose(_Symbol, strategy_tf, 2); // perf-allowed: fixed closed-bar OHLC structural pattern
   const double h2 = iHigh(_Symbol, strategy_tf, 2);  // perf-allowed: fixed closed-bar OHLC structural pattern
   const double l2 = iLow(_Symbol, strategy_tf, 2);   // perf-allowed: fixed closed-bar OHLC structural pattern

   const double o1 = iOpen(_Symbol, strategy_tf, 1);  // perf-allowed: fixed closed-bar OHLC structural pattern
   const double c1 = iClose(_Symbol, strategy_tf, 1); // perf-allowed: fixed closed-bar OHLC structural pattern
   const double h1 = iHigh(_Symbol, strategy_tf, 1);  // perf-allowed: fixed closed-bar OHLC structural pattern
   const double l1 = iLow(_Symbol, strategy_tf, 1);   // perf-allowed: fixed closed-bar OHLC structural pattern

   const double range2 = h2 - l2;
   const double range1 = h1 - l1;
   if(range2 <= 0.0 || range1 <= 0.0)
      return false;

   // Trend-bar (bar[2]): meaningful up-bar.
   if(!(c2 > o2))
      return false;
   if(MathAbs(c2 - o2) < strategy_body_min_frac * range2)
      return false;
   if(range2 < strategy_trend_range_atr_frac * atr)
      return false;

   // Reversal-bar (bar[1]): down-bar closing through trend-bar midpoint.
   if(!(c1 < o1))
      return false;
   if(MathAbs(c1 - o1) < strategy_body_min_frac * range1)
      return false;
   const double midpoint2 = 0.5 * (o2 + c2);
   if(c1 >= midpoint2)
      return false;
   if(h1 < h2)                                  // failed-extension: poke above trend-bar high
      return false;

   if(range1 < strategy_rev_range_frac * range2)
      return false;
   if(range1 < strategy_rev_range_atr_frac * atr)
      return false;

   const double swing_high = HighestHigh(1, strategy_swing_lookback);
   if(h1 < swing_high - strategy_swing_atr_frac * atr)
      return false;

   if(strategy_use_macro_bias)
     {
      const double sma = QM_SMA(_Symbol, strategy_tf, strategy_sma_period, 1);
      if(sma <= 0.0 || c1 >= sma)
         return false;
     }

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(bid <= 0.0)
      return false;

   double sl = h1 + strategy_sl_buffer_atr * atr;
   const double sl_cap = strategy_sl_cap_atr * atr;
   if(sl - bid > sl_cap)
      sl = bid + sl_cap;
   entry_sl = NormalizeDouble(sl, _Digits);
   const double risk = entry_sl - bid;
   if(risk <= 0.0)
      return false;

   entry_tp = NormalizeDouble(bid - strategy_tp_range_mult * range1, _Digits);
   out_range = range1;
   return true;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   RefreshPositionLifecycle();

   // Fail-OPEN spread guard: .DWX quotes ask==bid (0 spread) in the tester, so
   // only block a genuinely wide live spread; never reject on zero spread.
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask > 0.0 && bid > 0.0 && ask > bid && strategy_spread_atr_frac > 0.0)
     {
      const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
      if(atr > 0.0 && (ask - bid) > strategy_spread_atr_frac * atr)
         return true;
     }

   return false;
  }

// Trade Entry — pattern COMPLETION on the just-closed reversal bar is the
// trigger EVENT; swing/macro context is STATE. Enter at next-bar-open market.
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
   double range = 0.0;

   if(!RearmBlocksDirection(1) && PatternBuy(sl, tp, range))
     {
      req.type = QM_BUY;
      req.sl = sl;
      req.tp = tp;
      req.reason = "BROOKS_2BAR_REVERSAL_BUY_H4";
      g_signal_range = range;
      g_be_done = false;
      return true;
     }

   if(!RearmBlocksDirection(-1) && PatternSell(sl, tp, range))
     {
      req.type = QM_SELL;
      req.sl = sl;
      req.tp = tp;
      req.reason = "BROOKS_2BAR_REVERSAL_SELL_H4";
      g_signal_range = range;
      g_be_done = false;
      return true;
     }

   return false;
  }

// Trade Management — one-time break-even shift: when price advances
// 1.0 * reversal-range in favour, move SL to entry + 1 pip (BUY) / entry - 1 pip
// (SELL). No further trailing (Brooks-style: TP or reversal-against, not a trail).
void Strategy_ManageOpenPosition()
  {
   RefreshPositionLifecycle();
   if(g_active_ticket == 0 || g_be_done || g_signal_range <= 0.0)
      return;

   if(!PositionSelectByTicket(g_active_ticket))
      return;

   const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const bool is_buy = (ptype == POSITION_TYPE_BUY);
   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double moved = is_buy ? (market - open_price) : (open_price - market);
   const double pip = PipDistance();

   if(moved >= strategy_be_trigger_range_mult * g_signal_range)
     {
      const double be_price = is_buy ? (open_price + pip) : (open_price - pip);
      if(QM_TM_MoveSL(g_active_ticket, NormalizeDouble(be_price, _Digits), "brooks_2bar_be_shift"))
         g_be_done = true;
     }
  }

// Trade Close — time stop: if neither TP nor SL hit within strategy_time_stop_bars
// (12 H4 bars ~ 2 trading days), close at the next H4 close.
bool Strategy_ExitSignal()
  {
   RefreshPositionLifecycle();
   if(g_active_ticket == 0)
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
// candidate reversal bar overlapped a high-impact event.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(!QM_NewsAllowsTrade(_Symbol, broker_time, qm_news_mode_legacy))
      return true;

   const datetime bar_time = iTime(_Symbol, strategy_tf, 1); // perf-allowed: signal-bar news overlap check
   if(bar_time > 0 && !QM_NewsAllowsTrade(_Symbol, bar_time, qm_news_mode_legacy))
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
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1362\",\"ea\":\"brooks-2bar-reversal-h4\"}");
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

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
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
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
        }
     }

   if(!g_strategy_cadence_ready)
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
