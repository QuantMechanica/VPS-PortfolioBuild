#property strict
#property version   "5.0"
#property description "QM5_1379 Forex Profit Loader — Bounded ATR-Grid Pullback Ladder (H1, single-position cancel-and-replace)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1379 forex-profit-loader-bounded-grid-h1
// -----------------------------------------------------------------------------
// Source: Forex Profit Loader (FPL) community reverse-engineering, ForexFactory
//   Trading-Systems forum 2011-2016. Card:
//   artifacts/cards_approved/QM5_1379_forex-profit-loader-bounded-grid-h1.md
//   (g0_status APPROVED). Card frontmatter ea_id = QM5_12163 but BUILD TARGET
//   ea_id = 1379 (board-advisor handoff) — frontmatter_mismatch flagged.
//
// HR14 BOUNDED-WORST-CASE GRID COMPLIANCE
// ---------------------------------------
// The card title says "grid" but the card body EXPLICITLY reduces the original
// multi-position FPL grid to a SINGLE-POSITION cancel-and-replace ladder:
//   "only the deepest filled order is held as a single open position
//    (subsequent fills cancel-and-replace, not stack)";
//   "Position count remains 1 always"; "Single position per magic (HR14)".
// This EA therefore holds AT MOST ONE open position and AT MOST ONE pending
// limit order per symbol/magic at any instant. There is NO lot multiplication,
// NO averaging-in, NO position stacking, NO unbounded grid.
//
//   max_legs (open positions)  = 1  (hard — enforced by QM_TM_OpenPositionCount
//                                    gate + single pending-order refresh)
//   lot schedule               = single FIXED-risk lot via QM_LotsForRisk against
//                                    the hard SL distance (no per-leg scaling)
//   hard SL                    = entry -/+ strategy_sl_atr_mult * ATR (2.5*ATR)
//                                    on the OPEN position (a real broker SL price)
//   worst-case bound           = exactly RISK_FIXED. QM_LotsForRisk sizes the lot
//                                    so a full 2.5*ATR stop loss = RISK_FIXED.
//                                    Because the ladder cancels-and-replaces
//                                    (never stacks), only ONE such position can
//                                    ever be open, so the worst-case loss across
//                                    the whole ladder is capped at RISK_FIXED.
//                                    Card's "3.0*ATR from origin" is the distance
//                                    from the ladder ORIGIN to the stop; the
//                                    DOLLAR risk is still bounded to RISK_FIXED
//                                    because lots are sized off the actual stop.
//
// Mechanics (closed-bar reads at shift 1; pending BUY/SELL LIMIT pullback entry):
//   Trend regime (bull): close[1] > EMA20[1] > EMA50[1]
//                        AND (EMA20[1]-EMA20[6]) > slope_atr_frac * ATR
//                        AND close[1] >= Donchian_upper(don_period)[1]
//                                        - breakout_atr_frac * ATR
//                        (bear = mirror with Donchian_lower).
//   Ladder entry        : place ONE BUY LIMIT at origin (close[1]) minus
//                        ladder_entry_atr * ATR (pullback into the bounded
//                        envelope). Re-placed once per closed bar while the trend
//                        regime holds and we are flat — this IS the bounded
//                        cancel-and-replace: each bar the prior unfilled pending
//                        is removed and re-placed at the current bar's deepest
//                        envelope step, so the deepest pullback gets captured by a
//                        single position. envelope is bounded to
//                        envelope_atr * ATR below origin.
//   Stop / Take         : SL = sl_atr_mult * ATR (hard, 2.5) from LIMIT price;
//                        TP = tp_atr_mult * ATR (1.5) from LIMIT price.
//   BE ratchet          : once price advances be_trigger_atr * ATR (0.8) in
//                        favour, SL ratchets to break-even (entry).
//   Time-stop           : close after time_stop_bars (36) H1 bars without TP/SL.
//   Trend-flip exit      : close if the trend regime flips against the position.
//   No-trade windows    : night session (22:00-06:00 broker), regime-collapse
//                        guard (H1 ATR < atr_floor_frac * D1-ATR/24), SL cool-down
//                        (cooldown_bars after a stop-out).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific; framework wiring
// below MUST stay intact. No ML, no per-EA IsNewBar, no raw indicator calls
// except a documented bounded Donchian high/low read inside the new-bar gate.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1379;
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
input int    strategy_ema_fast_period     = 20;    // EMA fast (trend filter)
input int    strategy_ema_slow_period     = 50;    // EMA slow (trend filter)
input int    strategy_slope_lookback      = 5;     // EMA20 slope = EMA20[1]-EMA20[1+lb]
input int    strategy_atr_period          = 14;    // ATR period (H1)
input int    strategy_don_period          = 50;    // Donchian channel period
input double strategy_slope_atr_frac      = 0.20;  // min EMA20 up-slope = frac * ATR
input double strategy_breakout_atr_frac   = 1.50;  // within frac*ATR of Donchian extreme
input double strategy_ladder_entry_atr    = 0.50;  // pending LIMIT offset = frac*ATR below origin
input double strategy_envelope_atr        = 2.00;  // bounded envelope depth (frac*ATR) — context only
input double strategy_sl_atr_mult         = 2.50;  // hard SL distance = mult * ATR (worst-case cap)
input double strategy_tp_atr_mult         = 1.50;  // TP distance = mult * ATR
input double strategy_be_trigger_atr      = 0.80;  // break-even ratchet trigger = frac * ATR
input int    strategy_pending_expiry_bars = 6;     // ladder lifetime: cancel pending after N bars
input int    strategy_time_stop_bars      = 36;    // close after N bars without TP/SL
input int    strategy_cooldown_bars       = 18;    // no new ladder for N bars after a SL hit
input int    strategy_night_start_hour    = 22;    // no new ladder from this broker hour ...
input int    strategy_night_end_hour      = 6;     // ... until this broker hour (low-liquidity)
input double strategy_atr_floor_frac      = 0.20;  // regime-collapse: skip if H1 ATR < frac*D1ATR/24
input double strategy_spread_pct_of_stop  = 40.0;  // skip if spread > this % of stop (card: 0.4*ATR)

// -----------------------------------------------------------------------------
// EA-local cool-down state. Set when we detect that our open position vanished
// at/through its stop (a SL hit). Bespoke ladder lifecycle state — not a
// new-bar or indicator reimplementation.
// -----------------------------------------------------------------------------
datetime g_cooldown_until = 0;     // broker time until which no new ladder may start
double   g_last_pos_sl    = 0.0;   // last seen SL price of our open position
int      g_last_pos_dir   = 0;     // +1 buy / -1 sell of last seen open position
double   g_last_pos_close = 0.0;   // last seen approx close (bid/ask) of our position

// -----------------------------------------------------------------------------
// Helpers (EA-local). Donchian channel via a bounded closed-bar high/low read.
// -----------------------------------------------------------------------------

// Donchian upper = highest HIGH over [1 .. period]; lower = lowest LOW.
// Bounded read (<= strategy_don_period iterations) called ONLY from the
// QM_IsNewBar-gated entry path, so it runs once per closed bar.
bool Strategy_Donchian(const int period, double &upper, double &lower)
  {
   upper = 0.0;
   lower = 0.0;
   if(period <= 0)
      return false;
   double hi = -DBL_MAX;
   double lo =  DBL_MAX;
   for(int s = 1; s <= period; ++s)
     {
      const double h = iHigh(_Symbol, _Period, s); // perf-allowed: bounded Donchian high read, new-bar-gated entry path only.
      const double l = iLow(_Symbol, _Period, s);  // perf-allowed: bounded Donchian low read, new-bar-gated entry path only.
      if(h <= 0.0 || l <= 0.0)
         return false;
      if(h > hi)
         hi = h;
      if(l < lo)
         lo = l;
     }
   if(hi <= 0.0 || lo <= 0.0 || hi == -DBL_MAX || lo == DBL_MAX)
      return false;
   upper = hi;
   lower = lo;
   return true;
  }

// Trend regime: +1 bullish ladder allowed, -1 bearish, 0 none.
int Strategy_TrendRegime()
  {
   const double ema_f = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_s = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   if(ema_f <= 0.0 || ema_s <= 0.0)
      return 0;

   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return 0;

   const int slope_shift = 1 + ((strategy_slope_lookback > 0) ? strategy_slope_lookback : 1);
   const double ema_f_prev = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, slope_shift);
   if(ema_f_prev <= 0.0)
      return 0;
   const double slope = ema_f - ema_f_prev;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar close, new-bar-gated entry path only.
   if(close1 <= 0.0)
      return 0;

   double don_up = 0.0;
   double don_lo = 0.0;
   if(!Strategy_Donchian(strategy_don_period, don_up, don_lo))
      return 0;

   const double slope_min = strategy_slope_atr_frac * atr;
   const double breakout_band = strategy_breakout_atr_frac * atr;

   // Bullish: close>EMA20>EMA50, meaningful up-slope, within band of recent high.
   if(close1 > ema_f && ema_f > ema_s &&
      slope > slope_min &&
      close1 >= (don_up - breakout_band))
      return 1;

   // Bearish: mirror.
   if(close1 < ema_f && ema_f < ema_s &&
      slope < -slope_min &&
      close1 <= (don_lo + breakout_band))
      return -1;

   return 0;
  }

// Remove any pending order belonging to this EA's magic on this symbol.
void Strategy_RemoveOwnPending(const int magic)
  {
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      QM_TM_RemovePendingOrder(ticket, "ladder_refresh_or_cancel");
     }
  }

// Select this EA's open position on this symbol; returns its ticket or 0.
ulong Strategy_OwnPositionTicket(const int magic)
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
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

// Cheap O(1) per-tick gate: night session, regime-collapse, cool-down, spread.
bool Strategy_NoTradeFilter()
  {
   // Cool-down after a stop-out: block NEW ladders (open position is still
   // managed elsewhere; this only gates fresh entries via the entry hook, but a
   // hard block here is safe because management runs before this filter).
   if(g_cooldown_until > 0 && TimeCurrent() < g_cooldown_until)
     {
      const int magic_cd = QM_FrameworkMagic();
      // Only block when flat — never suppress management of an open position.
      if(QM_TM_OpenPositionCount(magic_cd) <= 0)
         return true;
     }

   // Night-session no-new-ladder window in BROKER time (low liquidity).
   if(strategy_night_start_hour != strategy_night_end_hour)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      const int h = dt.hour;
      bool in_night;
      if(strategy_night_start_hour < strategy_night_end_hour)
         in_night = (h >= strategy_night_start_hour && h < strategy_night_end_hour);
      else // wrap over midnight (e.g. 22 -> 06)
         in_night = (h >= strategy_night_start_hour || h < strategy_night_end_hour);
      if(in_night)
        {
         const int magic_n = QM_FrameworkMagic();
         if(QM_TM_OpenPositionCount(magic_n) <= 0)
            return true;
        }
     }

   // Wide-spread guard: fail-OPEN on .DWX zero modeled spread; block only a
   // genuinely wide quoted spread vs the stop distance (card: spread < 0.4*ATR).
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask > 0.0 && bid > 0.0 && ask > bid)
     {
      const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
      if(atr > 0.0)
        {
         const double stop_dist = strategy_sl_atr_mult * atr;
         const double spread = ask - bid;
         if(stop_dist > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_dist)
            return true;
        }
     }

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true. Places/refreshes/cancels the
// single pending LIMIT once per closed bar (bounded cancel-and-replace ladder).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const int magic = QM_FrameworkMagic();

   // One position at a time: while filled, keep no pending and stand down.
   if(QM_TM_OpenPositionCount(magic) > 0)
     {
      Strategy_RemoveOwnPending(magic);
      return false;
     }

   // Regime-collapse guard: skip ladders in dead-range markets.
   if(strategy_atr_floor_frac > 0.0)
     {
      const double atr_h1 = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
      const double atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
      if(atr_h1 > 0.0 && atr_d1 > 0.0)
        {
         const double floor_val = strategy_atr_floor_frac * (atr_d1 / 24.0);
         if(atr_h1 < floor_val)
           {
            Strategy_RemoveOwnPending(magic);
            return false;
           }
        }
     }

   const int trend = Strategy_TrendRegime();
   if(trend == 0)
     {
      Strategy_RemoveOwnPending(magic); // trend gone -> cancel stale ladder
      return false;
     }

   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double origin = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar close, new-bar-gated entry path.
   if(origin <= 0.0)
      return false;

   const double offset = strategy_ladder_entry_atr * atr;
   if(offset <= 0.0)
      return false;

   // Refresh: drop prior pending, re-place at this bar's envelope step
   // (bounded cancel-and-replace; deepest reachable pullback captured by one pos).
   Strategy_RemoveOwnPending(magic);

   const int expiry_seconds = (strategy_pending_expiry_bars > 0)
                              ? strategy_pending_expiry_bars * PeriodSeconds(_Period)
                              : 0;

   if(trend > 0)
     {
      // BUY LIMIT below origin (pullback into bounded envelope).
      const double limit_price = QM_TM_NormalizePrice(_Symbol, origin - offset);
      if(limit_price <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY_LIMIT, limit_price, atr, strategy_sl_atr_mult);
      if(sl <= 0.0)
         return false;
      const double tp = QM_TakeATRFromValue(_Symbol, QM_BUY_LIMIT, limit_price, atr, strategy_tp_atr_mult);
      if(tp <= 0.0)
         return false;

      req.type               = QM_BUY_LIMIT;
      req.price              = limit_price;
      req.sl                 = sl;
      req.tp                 = tp;
      req.reason             = "fpl_ladder_buy";
      req.expiration_seconds = expiry_seconds;
      return true;
     }

   // trend < 0 -> SELL LIMIT above origin.
   const double limit_price = QM_TM_NormalizePrice(_Symbol, origin + offset);
   if(limit_price <= 0.0)
      return false;
   const double sl = QM_StopATRFromValue(_Symbol, QM_SELL_LIMIT, limit_price, atr, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;
   const double tp = QM_TakeATRFromValue(_Symbol, QM_SELL_LIMIT, limit_price, atr, strategy_tp_atr_mult);
   if(tp <= 0.0)
      return false;

   req.type               = QM_SELL_LIMIT;
   req.price              = limit_price;
   req.sl                 = sl;
   req.tp                 = tp;
   req.reason             = "fpl_ladder_sell";
   req.expiration_seconds = expiry_seconds;
   return true;
  }

// Trade management (per tick): break-even ratchet at +be_trigger_atr*ATR, and
// remember the open position's SL/direction so we can detect a SL-hit cool-down.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   const ulong ticket = Strategy_OwnPositionTicket(magic);
   if(ticket == 0)
      return;
   if(!PositionSelectByTicket(ticket))
      return;

   const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const bool is_buy = (ptype == POSITION_TYPE_BUY);
   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);

   // Cache for SL-hit cool-down detection (used in ExitSignal when pos vanishes).
   g_last_pos_sl    = PositionGetDouble(POSITION_SL);
   g_last_pos_dir   = is_buy ? 1 : -1;
   g_last_pos_close = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                             : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   if(open_price <= 0.0)
      return;

   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return;

   // Break-even ratchet: once price advances be_trigger_atr*ATR in favour, move
   // SL to entry (only if it improves the current SL).
   const double trigger = strategy_be_trigger_atr * atr;
   if(trigger <= 0.0)
      return;

   const double mkt = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                             : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(mkt <= 0.0)
      return;

   const double moved = is_buy ? (mkt - open_price) : (open_price - mkt);
   if(moved < trigger)
      return;

   const double cur_sl = PositionGetDouble(POSITION_SL);
   const double be = QM_TM_NormalizePrice(_Symbol, open_price);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(be <= 0.0 || point <= 0.0)
      return;

   const bool improves = (cur_sl <= 0.0) ||
                         (is_buy ? (be > cur_sl + point * 0.5)
                                 : (be < cur_sl - point * 0.5));
   if(improves)
      QM_TM_MoveSL(ticket, be, "fpl_breakeven_ratchet");
  }

// Trade close: time-stop + trend-flip exit. Also detects a SL-hit (position
// gone, last seen price was at/through its SL) to arm the cool-down timer.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const ulong ticket = Strategy_OwnPositionTicket(magic);

   if(ticket == 0)
     {
      // Position is gone. If the last seen price was at/through the SL, treat it
      // as a stop-out and arm the cool-down. One-shot: clear cache after.
      if(g_last_pos_dir != 0 && g_last_pos_sl > 0.0 && g_last_pos_close > 0.0)
        {
         const bool stopped = (g_last_pos_dir > 0)
                              ? (g_last_pos_close <= g_last_pos_sl)
                              : (g_last_pos_close >= g_last_pos_sl);
         if(stopped && strategy_cooldown_bars > 0)
            g_cooldown_until = TimeCurrent() + strategy_cooldown_bars * PeriodSeconds(_Period);
        }
      g_last_pos_dir   = 0;
      g_last_pos_sl    = 0.0;
      g_last_pos_close = 0.0;
      return false;
     }

   if(!PositionSelectByTicket(ticket))
      return false;

   // Time-stop: close after strategy_time_stop_bars without TP/SL.
   if(strategy_time_stop_bars > 0)
     {
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0)
        {
         const long age = (long)(TimeCurrent() - opened);
         if(age >= (long)strategy_time_stop_bars * PeriodSeconds(_Period))
            return true;
        }
     }

   // Trend-flip exit: regime turned against the open position.
   const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const int trend = Strategy_TrendRegime();
   if(trend < 0 && ptype == POSITION_TYPE_BUY)
      return true;
   if(trend > 0 && ptype == POSITION_TYPE_SELL)
      return true;

   return false;
  }

// Defer to the central two-axis news filter.
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
