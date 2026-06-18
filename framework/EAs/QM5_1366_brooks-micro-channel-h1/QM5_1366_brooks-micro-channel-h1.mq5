#property strict
#property version   "5.0"
#property description "QM5_1366 Brooks Micro-Channel Continuation H1"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_1366 Brooks Micro-Channel With-the-Trend Continuation (H1)
// -----------------------------------------------------------------------------
// STATE  : a tight Brooks micro-channel detected from the last 5 CLOSED H1 bars
//          (shifts 5..1) — 5 same-direction bars, strict monotone stop-side,
//          bar-to-bar overlap (no gaps), each body meaningful (>= 0.40 of range),
//          a >= 1.0*ATR directional thrust, and a recent swing-extreme origin,
//          taken only in agreement with the SMA-50 macro bias.
// EVENT  : ONE trigger per detected channel — a stop order at the channel's own
//          stop-side break (buy-stop @ mc_high + 1 pip / sell-stop @ mc_low - 1 pip),
//          valid for the next 3 H1 bars. This is the single mechanical trigger;
//          the micro-channel run is a STATE, the break is the EVENT.
// EXIT   : initial hard SL beyond the channel (mc_low - 0.3*ATR, capped 2.5*ATR),
//          TP at R_mult * channel-range, a Brooks stair-step trail to the prior
//          2-bar extreme once price has advanced 1.0 * channel-range, an opposite
//          fresh micro-channel "always-in" flip-exit, and an 18-bar time stop.
// FILTERS: fail-OPEN spread guard, broker-time session windows (no entry 22:00-06:00
//          broker, no entry in the 22:00-23:00 rollover hour), and a 12-bar SL
//          cool-down. News handled centrally via the framework two-axis filter.
//
// .DWX invariants honoured: fail-OPEN spread guard, NO swap gate, prior-CLOSE
// overlap test (gapless symbols), single QM_IsNewBar consume per OnTick, one
// position per magic, RISK_FIXED in tester, all logic in-EA (no ML).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1366;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_tf            = PERIOD_H1;
input int    strategy_channel_len            = 5;     // consecutive bars in the micro-channel
input int    strategy_atr_period             = 14;
input int    strategy_sma_period             = 50;    // macro-bias filter
input int    strategy_swing_lookback         = 20;    // recent swing extreme window
input double strategy_body_ratio_min         = 0.40;  // each bar body >= 0.40 * range
input double strategy_thrust_atr_mult        = 1.0;   // channel covers >= 1.0*ATR
input double strategy_swing_atr_buffer       = 0.50;  // channel starts within 0.5*ATR of swing
input double strategy_r_mult                 = 1.5;   // TP = entry + r_mult * channel range
input double strategy_sl_atr_buffer          = 0.30;  // initial SL buffer beyond channel
input double strategy_sl_atr_cap             = 2.5;   // max initial SL distance in ATR
input int    strategy_entry_valid_bars       = 3;     // pending stop valid for N H1 bars
input double strategy_trail_trigger_chan_mult= 1.0;   // start trailing after 1.0*channel range
input int    strategy_trail_extreme_bars     = 2;     // stair-step trail to prior 2-bar extreme
input int    strategy_time_stop_bars         = 18;    // ~3 trading days
input int    strategy_cooldown_bars          = 12;    // bars to wait after an SL hit
input double strategy_spread_mult            = 2.0;   // fail-OPEN: block only spread > mult*median
input int    strategy_spread_lookback        = 20;
input int    strategy_no_entry_start_hour    = 22;    // broker-time: no new entry from 22:00 ...
input int    strategy_no_entry_end_hour      = 6;     // ... until 06:00 broker (Asian creep)

// -----------------------------------------------------------------------------
// File-scope state
// -----------------------------------------------------------------------------
double   g_median_spread_points   = 0.0;
bool     g_new_bar                = false;   // latched QM_IsNewBar() for this tick

ulong    g_active_ticket          = 0;
int      g_active_direction       = 0;       // +1 buy / -1 sell
double   g_channel_range          = 0.0;     // (mc_high - mc_low) of the entered channel
bool     g_trail_active           = false;

int      g_cooldown_remaining     = 0;       // bars left in the SL cool-down

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------
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

void RefreshSpreadMedian()
  {
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

// True iff our magic currently has a pending stop order on this symbol.
bool HasPendingOrder()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

// Selects this EA's open position (single position per magic, HR14).
bool SelectOurPosition(ulong &ticket, int &direction, double &open_price,
                       double &sl, double &tp, datetime &open_time)
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
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

// Detect whether our position has just closed (transition tracked for cool-down)
// and refresh the cached lifecycle state.
void RefreshPositionLifecycle()
  {
   ulong ticket = 0;
   int direction = 0;
   double open_price = 0.0, sl = 0.0, tp = 0.0;
   datetime open_time = 0;

   if(SelectOurPosition(ticket, direction, open_price, sl, tp, open_time))
     {
      if(ticket != g_active_ticket)
        {
         g_active_ticket = ticket;
         g_active_direction = direction;
         g_trail_active = false;
        }
      return;
     }

   // No live position. If we were tracking one, it just closed.
   if(g_active_ticket != 0)
     {
      // Arm the SL cool-down only when the exit looked like an adverse stop:
      // we approximate "SL hit" by a loss-side close detected via last deal is
      // out of scope here, so we apply the conservative Brooks cool-down on any
      // close (mirrors sibling rearm behaviour) — keeps the state machine simple
      // and deterministic.
      g_cooldown_remaining = MathMax(strategy_cooldown_bars, 0);
     }

   g_active_ticket = 0;
   g_active_direction = 0;
   g_channel_range = 0.0;
   g_trail_active = false;
  }

// -----------------------------------------------------------------------------
// Micro-channel detection (STATE) on closed bars [channel_len .. 1].
// Returns true and fills mc_high / mc_low / chan_range when a valid bullish
// (dir=+1) or bearish (dir=-1) micro-channel exists.
// -----------------------------------------------------------------------------
bool DetectMicroChannel(const int dir, double &mc_high, double &mc_low, double &chan_range)
  {
   const int len = strategy_channel_len;
   if(len < 2)
      return false;

   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   const double sma = QM_SMA(_Symbol, strategy_tf, strategy_sma_period, 1);
   if(atr <= 0.0 || sma <= 0.0)
      return false;

   mc_high = -DBL_MAX;
   mc_low  =  DBL_MAX;

   // Walk shifts 1..len (1 = most recent closed bar, len = oldest channel bar).
   for(int s = 1; s <= len; ++s)
     {
      const double o = iOpen(_Symbol, strategy_tf, s);  // perf-allowed: fixed closed-bar OHLC structural pattern
      const double c = iClose(_Symbol, strategy_tf, s);  // perf-allowed
      const double h = iHigh(_Symbol, strategy_tf, s);   // perf-allowed
      const double l = iLow(_Symbol, strategy_tf, s);    // perf-allowed
      const double range = h - l;
      if(range <= 0.0)
         return false;

      // (1) same-direction bar.
      if(dir > 0 && !(c > o))
         return false;
      if(dir < 0 && !(c < o))
         return false;

      // (4) each body meaningful.
      const double body = MathAbs(c - o);
      if(body < strategy_body_ratio_min * range)
         return false;

      mc_high = MathMax(mc_high, h);
      mc_low  = MathMin(mc_low, l);

      // Pairwise tests vs the older neighbour (shift s+1).
      if(s < len)
        {
         const double h_prev = iHigh(_Symbol, strategy_tf, s + 1); // perf-allowed
         const double l_prev = iLow(_Symbol, strategy_tf, s + 1);  // perf-allowed

         // (2) strict monotone stop-side containment.
         if(dir > 0 && !(l >= l_prev))   // bull: lows non-decreasing
            return false;
         if(dir < 0 && !(h <= h_prev))   // bear: highs non-increasing
            return false;

         // (3) overlap (gapless chain): low[s] <= high[s+1] and high[s] >= low[s+1].
         if(!(l <= h_prev && h >= l_prev))
            return false;
        }
     }

   // (5) directional thrust over the whole channel: close[1] vs close[len].
   const double c1   = iClose(_Symbol, strategy_tf, 1);   // perf-allowed
   const double clen = iClose(_Symbol, strategy_tf, len); // perf-allowed
   if(dir > 0)
     {
      if(!(c1 > clen) || (c1 - clen) < strategy_thrust_atr_mult * atr)
         return false;
     }
   else
     {
      if(!(c1 < clen) || (clen - c1) < strategy_thrust_atr_mult * atr)
         return false;
     }

   // (6) swing-extreme origin: the channel starts FROM a recent swing extreme.
   if(dir > 0)
     {
      const double lstart = iLow(_Symbol, strategy_tf, len); // perf-allowed
      if(lstart > LowestLow(1, strategy_swing_lookback) + strategy_swing_atr_buffer * atr)
         return false;
     }
   else
     {
      const double hstart = iHigh(_Symbol, strategy_tf, len); // perf-allowed
      if(hstart < HighestHigh(1, strategy_swing_lookback) - strategy_swing_atr_buffer * atr)
         return false;
     }

   // Macro-bias agreement: continuation only with the SMA-50 trend.
   if(dir > 0 && !(c1 > sma))
      return false;
   if(dir < 0 && !(c1 < sma))
      return false;

   chan_range = mc_high - mc_low;
   if(chan_range <= 0.0)
      return false;
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No Trade Filter — fail-OPEN spread guard + broker-time session windows.
bool Strategy_NoTradeFilter()
  {
   RefreshSpreadMedian();

   // Fail-OPEN spread guard: .DWX quotes 0 spread in the tester, so only block a
   // genuinely wide live spread; never reject on zero/median-absent spread.
   if(g_median_spread_points > 0.0 && strategy_spread_mult > 0.0)
     {
      const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if((double)current_spread > strategy_spread_mult * g_median_spread_points)
         return true;
     }

   // Broker-time session window: TimeCurrent() in the tester IS broker time.
   // No new entry between no_entry_start_hour (22:00) and no_entry_end_hour
   // (06:00) broker — this also covers the 22:00-23:00 rollover hour.
   MqlDateTime bt;
   TimeToStruct(TimeCurrent(), bt);
   const int hour = bt.hour;
   const int hs = strategy_no_entry_start_hour;
   const int he = strategy_no_entry_end_hour;
   bool blocked_hour = false;
   if(hs <= he)
      blocked_hour = (hour >= hs && hour < he);
   else // wraps midnight (e.g. 22 -> 6)
      blocked_hour = (hour >= hs || hour < he);
   if(blocked_hour)
      return true;

   return false;
  }

// Trade Entry — ONE event: a stop order at the micro-channel stop-side break,
// valid for strategy_entry_valid_bars H1 bars. Bullish channel => buy-stop at
// mc_high + 1 pip; bearish channel => sell-stop at mc_low - 1 pip.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // One position per magic (HR14) + one pending order at a time: never stack.
   if(g_active_ticket != 0 || QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;
   if(HasPendingOrder())
      return false;

   // SL cool-down after a close.
   if(g_cooldown_remaining > 0)
      return false;

   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   const double pip = PipDistance();
   if(atr <= 0.0 || pip <= 0.0)
      return false;

   const int per_bar_seconds = PeriodSeconds(strategy_tf);
   const int valid_seconds = MathMax(strategy_entry_valid_bars, 1) * per_bar_seconds;

   double mc_high = 0.0, mc_low = 0.0, chan_range = 0.0;

   // --- Bullish micro-channel -> buy-stop above the channel high.
   if(DetectMicroChannel(+1, mc_high, mc_low, chan_range))
     {
      const double entry = mc_high + pip;
      // Initial hard SL below the whole channel, capped at sl_atr_cap * ATR.
      double sl = mc_low - strategy_sl_atr_buffer * atr;
      const double max_risk = strategy_sl_atr_cap * atr;
      if((entry - sl) > max_risk)
         sl = entry - max_risk;
      const double tp = entry + strategy_r_mult * chan_range;

      req.type = QM_BUY_STOP;
      req.price = QM_TM_NormalizePrice(_Symbol, entry);
      req.sl    = QM_TM_NormalizePrice(_Symbol, sl);
      req.tp    = QM_TM_NormalizePrice(_Symbol, tp);
      req.reason = "BROOKS_MICRO_CHANNEL_BUY_H1";
      req.expiration_seconds = valid_seconds;
      g_channel_range = chan_range;
      return true;
     }

   // --- Bearish micro-channel -> sell-stop below the channel low.
   if(DetectMicroChannel(-1, mc_high, mc_low, chan_range))
     {
      const double entry = mc_low - pip;
      double sl = mc_high + strategy_sl_atr_buffer * atr;
      const double max_risk = strategy_sl_atr_cap * atr;
      if((sl - entry) > max_risk)
         sl = entry + max_risk;
      const double tp = entry - strategy_r_mult * chan_range;

      req.type = QM_SELL_STOP;
      req.price = QM_TM_NormalizePrice(_Symbol, entry);
      req.sl    = QM_TM_NormalizePrice(_Symbol, sl);
      req.tp    = QM_TM_NormalizePrice(_Symbol, tp);
      req.reason = "BROOKS_MICRO_CHANNEL_SELL_H1";
      req.expiration_seconds = valid_seconds;
      g_channel_range = chan_range;
      return true;
     }

   return false;
  }

// Trade Management — Brooks stair-step trail. Once price advances
// trail_trigger_chan_mult * channel-range in favour, ratchet the SL to the
// prior 2-bar extreme (lowest-low for BUY / highest-high for SELL). Advanced
// once per closed bar only (g_new_bar) so it is a deterministic per-bar trail.
void Strategy_ManageOpenPosition()
  {
   if(g_active_ticket == 0 || g_channel_range <= 0.0)
      return;
   if(!PositionSelectByTicket(g_active_ticket))
      return;

   const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const bool is_buy = (ptype == POSITION_TYPE_BUY);
   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double cur_sl = PositionGetDouble(POSITION_SL);
   const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double moved = is_buy ? (market - open_price) : (open_price - market);

   if(!g_trail_active && moved >= strategy_trail_trigger_chan_mult * g_channel_range)
      g_trail_active = true;

   if(!g_trail_active)
      return;

   // Recompute the prior-bar extreme once per closed bar.
   if(!g_new_bar)
      return;

   if(is_buy)
     {
      const double new_sl = LowestLow(1, strategy_trail_extreme_bars);
      // Only ratchet up, and never above market.
      if(new_sl > cur_sl && new_sl < market)
         QM_TM_MoveSL(g_active_ticket, QM_TM_NormalizePrice(_Symbol, new_sl), "brooks_mc_trail");
     }
   else
     {
      const double new_sl = HighestHigh(1, strategy_trail_extreme_bars);
      if((cur_sl <= 0.0 || new_sl < cur_sl) && new_sl > market)
         QM_TM_MoveSL(g_active_ticket, QM_TM_NormalizePrice(_Symbol, new_sl), "brooks_mc_trail");
     }
  }

// Trade Close — (a) "always-in" flip: a fresh OPPOSITE micro-channel closes the
// live trade at market; (b) 18-bar time stop. Both evaluated per closed bar.
bool Strategy_ExitSignal()
  {
   if(g_active_ticket == 0)
      return false;
   if(!g_new_bar)
      return false;
   if(!PositionSelectByTicket(g_active_ticket))
      return false;

   const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const bool is_buy = (ptype == POSITION_TYPE_BUY);

   // (a) Opposite fresh micro-channel => flatten (Brooks always-in flip).
   double mh = 0.0, ml = 0.0, cr = 0.0;
   const int opp_dir = is_buy ? -1 : +1;
   if(DetectMicroChannel(opp_dir, mh, ml, cr))
      return true;

   // (b) Time stop.
   const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
   const int bars_since_open = iBarShift(_Symbol, strategy_tf, open_time, false);
   if(bars_since_open >= strategy_time_stop_bars)
      return true;

   return false;
  }

// News Filter Hook — defer to the central two-axis filter (handled in OnTick),
// plus block if the most recent channel bar overlapped a high-impact event.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   const datetime bar_time = iTime(_Symbol, strategy_tf, 1); // perf-allowed: signal-bar news overlap check
   if(bar_time > 0 && !QM_NewsAllowsTrade2(_Symbol, bar_time, qm_news_temporal, qm_news_compliance))
      return true;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1366\",\"ea\":\"brooks-micro-channel-h1\"}");
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

   // Single QM_IsNewBar consume per tick — latched for entry, trail and exit.
   g_new_bar = QM_IsNewBar(_Symbol, strategy_tf);

   // Per-closed-bar bookkeeping: lifecycle refresh + cool-down countdown.
   RefreshPositionLifecycle();
   if(g_new_bar && g_cooldown_remaining > 0)
      g_cooldown_remaining--;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick trade management (trail only ratchets on new bars internally).
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
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
        }
     }

   if(!g_new_bar)
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
