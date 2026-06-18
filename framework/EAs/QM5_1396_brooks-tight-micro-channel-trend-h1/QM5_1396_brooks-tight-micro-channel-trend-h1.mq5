#property strict
#property version   "5.0"
#property description "QM5_1396 Brooks Tight Micro-Channel Trade-With-Trend (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_1396 Brooks Tight Micro-Channel Trade-With-Trend (H1)
// -----------------------------------------------------------------------------
// STATE  : a TIGHT micro-channel of length N in {3,4,5} detected on the last N
//          CLOSED H1 bars (shifts N..1, where shift 1 = most-recent closed bar
//          = the channel extreme). Long case: each bar makes a higher high and
//          its low does not break the prior bar's low by more than 0.10*ATR; no
//          single dominant thrust bar (body-ratio <= 0.80); channel slope
//          >= 0.20*ATR (tight but not flat); whole-channel range <= 1.30*ATR
//          (compactness). Taken only WITH the SMA-50 macro bias.
// EVENT  : ONE trigger per detected channel — a bear inside-bar PULLBACK at the
//          currently-forming bar[0] (evaluated at its close): high[0] <= high[1]
//          AND low[0] >= low[1] - 0.20*ATR AND close[0] < open[0]. A buy-stop is
//          placed at high[0] + 1 point, valid for the NEXT bar only. The channel
//          run is the STATE; the pullback-bar break is the EVENT.
// EXIT   : (1) hard TP at entry + 2.0*ATR; (2) Brooks bar-by-bar trail to
//          low[1] - 0.2*ATR updated each closed bar; (3) macro-bias flip
//          (SMA-50 slope sign change) -> hard close; (4) 24-bar time stop.
// STOP   : initial SL at low[N] - 0.3*ATR (deepest channel point + buffer);
//          worst-case (entry - SL) capped at 2.5*ATR -> ABORT the trade if the
//          computed SL is further than 2.5*ATR (channel too loose).
// FILTERS: time window 08:00-21:00 broker, fail-OPEN spread guard (block only a
//          genuinely-wide live spread > 0.30*ATR), news via central two-axis
//          filter, and a same-bar re-entry guard after a close.
//
// .DWX invariants honoured: fail-OPEN spread guard (never block on 0 spread),
// NO swap gate, broker-time via TimeCurrent()/QM_BrokerToUTC, prior-CLOSE not
// range for the pullback overlap, single QM_IsNewBar consume per OnTick, one
// position per magic, RISK_FIXED in tester, all logic in-EA (no ML).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1396;
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
input int    strategy_atr_period             = 14;
input int    strategy_sma_period             = 50;    // macro-bias filter
input int    strategy_sma_slope_lookback     = 20;    // SMA slope = SMA[1] - SMA[slope_lookback]
input int    strategy_chan_len_min           = 3;     // tight micro-channel N in {min..max}
input int    strategy_chan_len_max           = 5;
input double strategy_low_break_atr          = 0.10;  // low may break prior low by <= this*ATR
input double strategy_body_ratio_max         = 0.80;  // no single dominant thrust bar
input double strategy_slope_atr_min          = 0.20;  // channel slope >= this*ATR (tight, not flat)
input double strategy_compact_atr_max        = 1.30;  // whole-channel range <= this*ATR
input double strategy_pullback_low_atr       = 0.20;  // pullback low may sit <= this*ATR below low[1]
input double strategy_tp_atr_mult            = 2.0;   // hard TP = entry + 2.0*ATR
input double strategy_trail_atr_buffer       = 0.20;  // trail to low[1] - 0.2*ATR each bar
input double strategy_sl_atr_buffer          = 0.30;  // initial SL = low[N] - 0.3*ATR
input double strategy_sl_atr_cap             = 2.5;   // ABORT if SL distance > this*ATR
input int    strategy_time_stop_bars         = 24;    // close after 24 H1 bars
input double strategy_spread_atr_mult        = 0.30;  // fail-OPEN: block spread > this*ATR
input int    strategy_session_start_hour     = 8;     // broker-time: entries 08:00 ...
input int    strategy_session_end_hour       = 21;    // ... to 21:00 broker

// -----------------------------------------------------------------------------
// File-scope state
// -----------------------------------------------------------------------------
bool     g_new_bar                = false;   // latched QM_IsNewBar() for this tick

ulong    g_active_ticket          = 0;
int      g_active_direction       = 0;       // +1 buy / -1 sell
int      g_entry_macro_sign       = 0;       // SMA slope sign captured at entry (flip-exit ref)

datetime g_last_close_bar_time    = 0;       // re-entry guard: bar on which we last closed

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------
double PipDistance()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   return (point > 0.0) ? point : 0.0;
  }

int SmaSlopeSign()
  {
   const double sma_now = QM_SMA(_Symbol, strategy_tf, strategy_sma_period, 1);
   const double sma_old = QM_SMA(_Symbol, strategy_tf, strategy_sma_period,
                                 1 + strategy_sma_slope_lookback);
   if(sma_now <= 0.0 || sma_old <= 0.0)
      return 0;
   if(sma_now > sma_old)
      return +1;
   if(sma_now < sma_old)
      return -1;
   return 0;
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
bool SelectOurPosition(ulong &ticket, int &direction, datetime &open_time)
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
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

// Refresh cached lifecycle + record the bar on which a close happened (re-entry guard).
void RefreshPositionLifecycle()
  {
   ulong ticket = 0;
   int direction = 0;
   datetime open_time = 0;

   if(SelectOurPosition(ticket, direction, open_time))
     {
      if(ticket != g_active_ticket)
        {
         g_active_ticket = ticket;
         g_active_direction = direction;
        }
      return;
     }

   // No live position. If we were tracking one, it just closed on this bar.
   if(g_active_ticket != 0)
      g_last_close_bar_time = iTime(_Symbol, strategy_tf, 0); // perf-allowed: re-entry guard bar stamp

   g_active_ticket = 0;
   g_active_direction = 0;
   g_entry_macro_sign = 0;
  }

// -----------------------------------------------------------------------------
// Tight micro-channel detection (STATE) on closed bars [N .. 1].
// shift 1 = most-recent closed bar = the channel extreme (highest high for long).
// Returns the matched length N (in {min..max}) and fills mc deepest/peak levels;
// 0 = no channel for this direction.
// -----------------------------------------------------------------------------
int DetectTightMicroChannel(const int dir, const double atr,
                            double &deepest, double &peak)
  {
   if(atr <= 0.0)
      return 0;

   const int nmin = MathMax(strategy_chan_len_min, 2);
   const int nmax = MathMax(strategy_chan_len_max, nmin);

   // Prefer the longest qualifying channel (most established run).
   for(int N = nmax; N >= nmin; --N)
     {
      bool ok = true;
      double hi_max = -DBL_MAX, lo_min = DBL_MAX;

      // Walk the N channel bars: shift 1 (newest) .. N (oldest).
      for(int s = 1; s <= N && ok; ++s)
        {
         const double o = iOpen(_Symbol, strategy_tf, s);  // perf-allowed: fixed closed-bar structural pattern
         const double c = iClose(_Symbol, strategy_tf, s);  // perf-allowed
         const double h = iHigh(_Symbol, strategy_tf, s);   // perf-allowed
         const double l = iLow(_Symbol, strategy_tf, s);    // perf-allowed
         const double range = h - l;
         if(range <= 0.0) { ok = false; break; }

         // (2) no single dominant thrust bar — body-ratio <= max.
         if((MathAbs(c - o) / range) > strategy_body_ratio_max) { ok = false; break; }

         hi_max = MathMax(hi_max, h);
         lo_min = MathMin(lo_min, l);

         // (1) directional grind vs the older neighbour (shift s+1).
         if(s < N)
           {
            const double h_prev = iHigh(_Symbol, strategy_tf, s + 1); // perf-allowed
            const double l_prev = iLow(_Symbol, strategy_tf, s + 1);  // perf-allowed
            if(dir > 0)
              {
               // higher high AND low does not break prior low by > low_break*ATR.
               if(!(h > h_prev)) { ok = false; break; }
               if(l < l_prev - strategy_low_break_atr * atr) { ok = false; break; }
              }
            else
              {
               // lower low AND high does not break prior high by > low_break*ATR.
               if(!(l < l_prev)) { ok = false; break; }
               if(h > h_prev + strategy_low_break_atr * atr) { ok = false; break; }
              }
           }
        }
      if(!ok)
         continue;

      const double h1 = iHigh(_Symbol, strategy_tf, 1); // perf-allowed
      const double hN = iHigh(_Symbol, strategy_tf, N); // perf-allowed
      const double l1 = iLow(_Symbol, strategy_tf, 1);  // perf-allowed
      const double lN = iLow(_Symbol, strategy_tf, N);  // perf-allowed

      // (3) channel slope >= slope_min*ATR (tight, not flat).
      double slope;
      if(dir > 0)
         slope = (h1 - hN) / N;        // rising highs
      else
         slope = (lN - l1) / N;        // falling lows
      if(slope < strategy_slope_atr_min * atr)
         continue;

      // (4) compactness: whole-channel range <= compact_max*ATR.
      if((hi_max - lo_min) > strategy_compact_atr_max * atr)
         continue;

      if(dir > 0)
        {
         deepest = lo_min;  // for SL = low[N] - buffer (lo_min == low[N] for a clean rising channel)
         peak    = h1;      // most-recent high (pullback reference)
        }
      else
        {
         deepest = hi_max;
         peak    = l1;
        }
      return N;
     }
   return 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No Trade Filter — broker-time session window + fail-OPEN spread guard.
bool Strategy_NoTradeFilter()
  {
   // Broker-time session window: TimeCurrent() in the tester IS broker time.
   MqlDateTime bt;
   TimeToStruct(TimeCurrent(), bt);
   if(bt.hour < strategy_session_start_hour || bt.hour >= strategy_session_end_hour)
      return true;

   // Fail-OPEN spread guard: .DWX quotes ask==bid (0 spread) in the tester.
   // Block ONLY a genuinely-wide live spread > spread_atr_mult * ATR.
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   if(ask > 0.0 && bid > 0.0 && ask > bid && atr > 0.0 && strategy_spread_atr_mult > 0.0)
     {
      if((ask - bid) > strategy_spread_atr_mult * atr)
         return true;
     }

   return false;
  }

// Trade Entry — ONE event: a bear/bull inside-bar PULLBACK at bar[0] following a
// detected tight micro-channel, in agreement with the SMA-50 macro bias. Bullish
// channel => buy-stop at high[0] + 1 point, valid for the next bar only.
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

   // Re-entry guard: do not re-enter on the same H1 bar we just closed on.
   if(g_last_close_bar_time != 0 && iTime(_Symbol, strategy_tf, 0) == g_last_close_bar_time)
      return false;

   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   const double pip = PipDistance();
   if(atr <= 0.0 || pip <= 0.0)
      return false;

   const int macro_sign = SmaSlopeSign();
   if(macro_sign == 0)
      return false;   // stand-down on flat macro bias

   const double sma1   = QM_SMA(_Symbol, strategy_tf, strategy_sma_period, 1);
   const double close1 = iClose(_Symbol, strategy_tf, 1); // perf-allowed: macro-bias confirmation

   // Pullback bar[0] OHLC (currently-forming bar evaluated at its close).
   const double o0 = iOpen(_Symbol, strategy_tf, 0);  // perf-allowed
   const double c0 = iClose(_Symbol, strategy_tf, 0);  // perf-allowed
   const double h0 = iHigh(_Symbol, strategy_tf, 0);   // perf-allowed
   const double l0 = iLow(_Symbol, strategy_tf, 0);    // perf-allowed
   const double h1 = iHigh(_Symbol, strategy_tf, 1);   // perf-allowed
   const double l1 = iLow(_Symbol, strategy_tf, 1);    // perf-allowed

   const int per_bar_seconds = PeriodSeconds(strategy_tf);
   const int valid_seconds = per_bar_seconds; // order valid for the NEXT bar only.

   double deepest = 0.0, peak = 0.0;

   // --- LONG: positive macro bias only.
   if(macro_sign > 0 && close1 > sma1)
     {
      const int N = DetectTightMicroChannel(+1, atr, deepest, peak);
      if(N > 0)
        {
         // Pullback = small bear inside-bar at bar[0].
         const bool pullback = (h0 <= h1) &&
                               (l0 >= l1 - strategy_pullback_low_atr * atr) &&
                               (c0 < o0);
         if(pullback)
           {
            const double entry = h0 + pip;
            const double sl = deepest - strategy_sl_atr_buffer * atr;   // low[N] - 0.3*ATR
            // Worst-case cap: ABORT if SL further than sl_atr_cap*ATR from entry.
            if((entry - sl) > strategy_sl_atr_cap * atr)
               return false;
            const double tp = entry + strategy_tp_atr_mult * atr;

            req.type   = QM_BUY_STOP;
            req.price  = QM_TM_NormalizePrice(_Symbol, entry);
            req.sl     = QM_TM_NormalizePrice(_Symbol, sl);
            req.tp     = QM_TM_NormalizePrice(_Symbol, tp);
            req.reason = "BROOKS_TIGHT_MC_BUY_H1";
            req.expiration_seconds = valid_seconds;
            g_entry_macro_sign = macro_sign;
            return true;
           }
        }
     }

   // --- SHORT: negative macro bias only.
   if(macro_sign < 0 && close1 < sma1)
     {
      const int N = DetectTightMicroChannel(-1, atr, deepest, peak);
      if(N > 0)
        {
         // Pullback = small bull inside-bar at bar[0].
         const bool pullback = (l0 >= l1) &&
                               (h0 <= h1 + strategy_pullback_low_atr * atr) &&
                               (c0 > o0);
         if(pullback)
           {
            const double entry = l0 - pip;
            const double sl = deepest + strategy_sl_atr_buffer * atr;   // high[N] + 0.3*ATR
            if((sl - entry) > strategy_sl_atr_cap * atr)
               return false;
            const double tp = entry - strategy_tp_atr_mult * atr;

            req.type   = QM_SELL_STOP;
            req.price  = QM_TM_NormalizePrice(_Symbol, entry);
            req.sl     = QM_TM_NormalizePrice(_Symbol, sl);
            req.tp     = QM_TM_NormalizePrice(_Symbol, tp);
            req.reason = "BROOKS_TIGHT_MC_SELL_H1";
            req.expiration_seconds = valid_seconds;
            g_entry_macro_sign = macro_sign;
            return true;
           }
        }
     }

   return false;
  }

// Trade Management — Brooks bar-by-bar trail. Each closed bar, ratchet the SL to
// low[1] - 0.2*ATR (long) / high[1] + 0.2*ATR (short). Only tightens, never above
// market, never loosens.
void Strategy_ManageOpenPosition()
  {
   if(g_active_ticket == 0 || !g_new_bar)
      return;
   if(!PositionSelectByTicket(g_active_ticket))
      return;

   const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const bool is_buy = (ptype == POSITION_TYPE_BUY);
   const double cur_sl = PositionGetDouble(POSITION_SL);

   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   if(atr <= 0.0)
      return;

   if(is_buy)
     {
      const double market = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double l1 = iLow(_Symbol, strategy_tf, 1); // perf-allowed: bar-by-bar trail reference
      const double new_sl = l1 - strategy_trail_atr_buffer * atr;
      if(new_sl > cur_sl && new_sl < market)
         QM_TM_MoveSL(g_active_ticket, QM_TM_NormalizePrice(_Symbol, new_sl), "brooks_tight_mc_trail");
     }
   else
     {
      const double market = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double h1 = iHigh(_Symbol, strategy_tf, 1); // perf-allowed: bar-by-bar trail reference
      const double new_sl = h1 + strategy_trail_atr_buffer * atr;
      if((cur_sl <= 0.0 || new_sl < cur_sl) && new_sl > market)
         QM_TM_MoveSL(g_active_ticket, QM_TM_NormalizePrice(_Symbol, new_sl), "brooks_tight_mc_trail");
     }
  }

// Trade Close — (a) macro-bias flip: SMA-50 slope sign changed vs entry => close;
// (b) 24-bar time stop. Both evaluated once per closed bar.
bool Strategy_ExitSignal()
  {
   if(g_active_ticket == 0 || !g_new_bar)
      return false;
   if(!PositionSelectByTicket(g_active_ticket))
      return false;

   // (a) Macro-bias flip.
   const int macro_sign = SmaSlopeSign();
   if(g_entry_macro_sign != 0 && macro_sign != 0 && macro_sign != g_entry_macro_sign)
      return true;

   // (b) Time stop — 24 H1 bars after entry.
   const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
   const int bars_since_open = iBarShift(_Symbol, strategy_tf, open_time, false);
   if(bars_since_open >= strategy_time_stop_bars)
      return true;

   return false;
  }

// News Filter Hook — defer to the central two-axis filter, plus block if the most
// recent channel bar overlapped a high-impact event.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1396\",\"ea\":\"brooks-tight-micro-channel-trend-h1\"}");
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

   // Per-closed-bar bookkeeping: lifecycle refresh (records close bar for re-entry guard).
   RefreshPositionLifecycle();

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
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
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
