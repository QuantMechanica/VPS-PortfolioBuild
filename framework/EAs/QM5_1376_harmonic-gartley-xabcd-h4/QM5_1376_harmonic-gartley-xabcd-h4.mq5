#property strict
#property version   "5.0"
#property description "QM5_1376 Harmonic Gartley XABCD H4"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1376;
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
input int    strategy_pivot_window       = 5;       // 5-bar fractal half-window (card k=5)
input int    strategy_pivot_lookback     = 200;     // confirmed-pivot search depth (H4 bars)
input int    strategy_atr_period         = 14;
input int    strategy_sma_macro_period   = 200;
// --- Gartley Fibonacci ratio corridors (card tol=0.05) ---
input double strategy_ab_xa_min          = 0.568;   // AB/XA in [0.618-tol, 0.618+tol]
input double strategy_ab_xa_max          = 0.668;
input double strategy_bc_ab_min          = 0.332;   // BC/AB in [0.382-tol, 0.886+tol]
input double strategy_bc_ab_max          = 0.936;
input double strategy_cd_bc_min          = 1.222;   // CD/BC in [1.272-tol, 1.618+tol]
input double strategy_cd_bc_max          = 1.668;
input double strategy_ad_xa_min          = 0.736;   // AD/XA in [0.786-tol, 0.786+tol]
input double strategy_ad_xa_max          = 0.836;
// --- structural / regime gates ---
input double strategy_xa_atr_min         = 1.5;     // |A-X| >= 1.5 * ATR(14,H4)
input double strategy_d_extreme_lookback = 8;       // D = extreme of last 8 H4 bars
input double strategy_d_thrust_atr       = 0.3;     // confirmation: close > D + 0.3*ATR
input double strategy_sma_atr_band       = 3.0;     // non-extreme regime: |close[1]-SMA200| <= 3*ATR
input double strategy_spread_atr_mult    = 0.4;     // spread guard cap
// --- exits / stops ---
input double strategy_sl_atr_mult        = 0.5;     // SL = D -/+ 0.5*ATR
input double strategy_sl_cap_atr         = 2.5;     // initial-SL distance cap
input double strategy_tp1_ad_retrace     = 0.382;   // TP1 = entry +/- 0.382*(A-D)
input double strategy_tp2_ad_retrace     = 0.618;   // TP2 = entry +/- 0.618*(A-D)
input double strategy_tp1_close_fraction = 0.50;
input int    strategy_time_stop_bars     = 30;      // 30 H4 bars time-stop
input int    strategy_overlap_guard_bars = 50;      // same-dir overlap guard
input int    strategy_cooldown_bars      = 12;      // post-SL cooldown
input int    strategy_session_start_hour = 6;       // skip 22:00-06:00 broker (illiquid Asia)
input int    strategy_session_end_hour   = 22;

struct PivotPoint
  {
   int      type;     // +1 high, -1 low
   int      shift;
   datetime time;
   double   price;
  };

struct GartleyPattern
  {
   int      side;     // +1 bullish, -1 bearish
   PivotPoint x;
   PivotPoint a;
   PivotPoint b;
   PivotPoint c;
   PivotPoint d;
   double   atr_h4;
   double   tp1;
   double   tp2;
  };

datetime g_last_x_time          = 0;
int      g_active_side          = 0;
double   g_active_tp1           = 0.0;
bool     g_tp1_done             = false;
datetime g_last_entry_time_buy  = 0;
datetime g_last_entry_time_sell = 0;
datetime g_last_sl_time         = 0;

double BarOpen(const int shift)  { return iOpen(_Symbol, PERIOD_H4, shift); }
double BarHigh(const int shift)  { return iHigh(_Symbol, PERIOD_H4, shift); }
double BarLow(const int shift)   { return iLow(_Symbol, PERIOD_H4, shift); }
double BarClose(const int shift) { return iClose(_Symbol, PERIOD_H4, shift); }

bool SameSymbolMagicPosition(ulong &ticket)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      ticket = t;
      return true;
     }
   ticket = 0;
   return false;
  }

bool IsSwingHigh(const int shift)
  {
   const double h = BarHigh(shift);
   if(h <= 0.0)
      return false;
   for(int k = 1; k <= strategy_pivot_window; ++k)
      if(h <= BarHigh(shift - k) || h <= BarHigh(shift + k))
         return false;
   return true;
  }

bool IsSwingLow(const int shift)
  {
   const double l = BarLow(shift);
   if(l <= 0.0)
      return false;
   for(int k = 1; k <= strategy_pivot_window; ++k)
      if(l >= BarLow(shift - k) || l >= BarLow(shift + k))
         return false;
   return true;
  }

void AddPivot(PivotPoint &pivots[], int &count, const int type, const int shift, const double price)
  {
   if(count >= ArraySize(pivots))
      return;
   pivots[count].type = type;
   pivots[count].shift = shift;
   pivots[count].time = iTime(_Symbol, PERIOD_H4, shift);
   pivots[count].price = price;
   count++;
  }

// Collect confirmed 5-bar fractal pivots, oldest-first, older than the D window.
int CollectConfirmedPivots(PivotPoint &pivots[])
  {
   int count = 0;
   const int oldest = MathMax(strategy_pivot_window + 2, strategy_pivot_lookback);
   for(int shift = oldest; shift >= strategy_pivot_window + 1; --shift)
     {
      if(IsSwingHigh(shift))
         AddPivot(pivots, count, 1, shift, BarHigh(shift));
      if(IsSwingLow(shift))
         AddPivot(pivots, count, -1, shift, BarLow(shift));
     }
   return count;
  }

// Walk back from the most recent confirmed pivot before D, matching the
// alternating X-A-B-C type sequence for the requested side.
bool ExtractXABC(const int side, const int before_shift, GartleyPattern &pattern)
  {
   PivotPoint pivots[80];
   const int count = CollectConfirmedPivots(pivots);
   const int x_type = (side > 0) ? -1 : 1;   // bullish: X is a low
   const int a_type = -x_type;
   const int b_type = x_type;
   const int c_type = a_type;

   int c_idx = -1;
   int b_idx = -1;
   int a_idx = -1;
   int x_idx = -1;

   for(int i = count - 1; i >= 0; --i)
     {
      if(pivots[i].shift <= before_shift + strategy_pivot_window)
         continue;
      if(c_idx < 0 && pivots[i].type == c_type)
        {
         c_idx = i;
         continue;
        }
      if(c_idx >= 0 && b_idx < 0 && i < c_idx && pivots[i].type == b_type)
        {
         b_idx = i;
         continue;
        }
      if(b_idx >= 0 && a_idx < 0 && i < b_idx && pivots[i].type == a_type)
        {
         a_idx = i;
         continue;
        }
      if(a_idx >= 0 && x_idx < 0 && i < a_idx && pivots[i].type == x_type)
        {
         x_idx = i;
         break;
        }
     }

   if(x_idx < 0 || a_idx < 0 || b_idx < 0 || c_idx < 0)
      return false;

   pattern.x = pivots[x_idx];
   pattern.a = pivots[a_idx];
   pattern.b = pivots[b_idx];
   pattern.c = pivots[c_idx];
   return true;
  }

bool RatioInRange(const double value, const double lo, const double hi)
  {
   return (value >= lo && value <= hi);
  }

// D is the extreme of the last N H4 bars (card: min/max of low/high over lookback).
bool IsFreshDExtreme(const int side, const int d_shift, const double d_price)
  {
   const int win = (int)strategy_d_extreme_lookback;
   for(int k = 1; k < win; ++k)
     {
      if(side > 0)
        {
         if(BarLow(d_shift + k) <= d_price)
            return false;
        }
      else
        {
         if(BarHigh(d_shift + k) >= d_price)
            return false;
        }
     }
   return true;
  }

bool ValidatePattern(const int side, const int d_shift, GartleyPattern &pattern)
  {
   pattern.side = side;
   if(!ExtractXABC(side, d_shift, pattern))
      return false;

   pattern.d.type  = (side > 0) ? -1 : 1;
   pattern.d.shift = d_shift;
   pattern.d.time  = iTime(_Symbol, PERIOD_H4, d_shift);
   pattern.d.price = (side > 0) ? BarLow(d_shift) : BarHigh(d_shift);

   pattern.atr_h4 = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double sma200 = QM_SMA(_Symbol, PERIOD_H4, strategy_sma_macro_period, 1);
   if(pattern.atr_h4 <= 0.0 || sma200 <= 0.0)
      return false;

   const double xa = MathAbs(pattern.x.price - pattern.a.price);
   const double ab = MathAbs(pattern.a.price - pattern.b.price);
   const double bc = MathAbs(pattern.c.price - pattern.b.price);
   if(xa <= 0.0 || ab <= 0.0 || bc <= 0.0)
      return false;

   // --- Gartley geometry: D retraces 0.786 of XA, so D stays inside the XA leg ---
   if(side > 0)
     {
      // X low, A high, B low (above X), C high (below A), D low (above X, below B-side)
      if(!(pattern.x.price < pattern.a.price &&
           pattern.b.price > pattern.x.price && pattern.b.price < pattern.a.price &&
           pattern.c.price < pattern.a.price && pattern.c.price > pattern.b.price &&
           pattern.d.price > pattern.x.price && pattern.d.price < pattern.c.price))
         return false;
     }
   else
     {
      // X high, A low, B high (below X), C low (above A), D high (below X)
      if(!(pattern.x.price > pattern.a.price &&
           pattern.b.price < pattern.x.price && pattern.b.price > pattern.a.price &&
           pattern.c.price > pattern.a.price && pattern.c.price < pattern.b.price &&
           pattern.d.price < pattern.x.price && pattern.d.price > pattern.c.price))
         return false;
     }

   // --- Fibonacci ratio cluster (Gartley signature) ---
   const double ab_xa = ab / xa;
   const double bc_ab = bc / ab;
   const double cd    = MathAbs(pattern.c.price - pattern.d.price);
   const double cd_bc = cd / bc;
   const double ad    = MathAbs(pattern.a.price - pattern.d.price);
   const double ad_xa = ad / xa;

   if(!RatioInRange(ab_xa, strategy_ab_xa_min, strategy_ab_xa_max))
      return false;
   if(!RatioInRange(bc_ab, strategy_bc_ab_min, strategy_bc_ab_max))
      return false;
   if(!RatioInRange(cd_bc, strategy_cd_bc_min, strategy_cd_bc_max))
      return false;
   if(!RatioInRange(ad_xa, strategy_ad_xa_min, strategy_ad_xa_max))
      return false;

   // --- XA leg meaningfulness ---
   if(xa < strategy_xa_atr_min * pattern.atr_h4)
      return false;

   // --- D is a fresh local extreme of the last N H4 bars ---
   if(!IsFreshDExtreme(side, d_shift, pattern.d.price))
      return false;

   // --- bullish/bearish thrust off D, on the confirmation bar (shift 1) ---
   if(side > 0)
     {
      if(!(BarClose(1) > pattern.d.price + strategy_d_thrust_atr * pattern.atr_h4 &&
           BarClose(1) > BarOpen(1)))
         return false;
     }
   else
     {
      if(!(BarClose(1) < pattern.d.price - strategy_d_thrust_atr * pattern.atr_h4 &&
           BarClose(1) < BarOpen(1)))
         return false;
     }

   // --- non-extreme regime gate ---
   if(MathAbs(BarClose(1) - sma200) > strategy_sma_atr_band * pattern.atr_h4)
      return false;

   // --- scaling targets toward A (Carney BC retracement targets) ---
   if(side > 0)
     {
      pattern.tp1 = pattern.d.price + strategy_tp1_ad_retrace * (pattern.a.price - pattern.d.price);
      pattern.tp2 = pattern.d.price + strategy_tp2_ad_retrace * (pattern.a.price - pattern.d.price);
     }
   else
     {
      pattern.tp1 = pattern.d.price - strategy_tp1_ad_retrace * (pattern.d.price - pattern.a.price);
      pattern.tp2 = pattern.d.price - strategy_tp2_ad_retrace * (pattern.d.price - pattern.a.price);
     }

   return true;
  }

// Same-direction overlap guard: skip if a same-side pattern (same X) entered
// within the last overlap-guard bars.
bool OverlapBlocked(const int side, const int d_shift)
  {
   const datetime last = (side > 0) ? g_last_entry_time_buy : g_last_entry_time_sell;
   if(last <= 0)
      return false;
   const int last_shift = iBarShift(_Symbol, PERIOD_H4, last, false);
   if(last_shift < 0)
      return false;
   return (last_shift - d_shift <= strategy_overlap_guard_bars);
  }

// Cooldown after a stop-loss hit on this symbol.
bool CooldownBlocked(const int d_shift)
  {
   if(g_last_sl_time <= 0)
      return false;
   const int sl_shift = iBarShift(_Symbol, PERIOD_H4, g_last_sl_time, false);
   if(sl_shift < 0)
      return false;
   return (sl_shift - d_shift <= strategy_cooldown_bars);
  }

bool BuildSignal(GartleyPattern &pattern)
  {
   // D is the just-completed confirmed extreme; the confirmation bar is shift 1.
   // Search D over a small recent window (shift 2..3) so the thrust bar (1) is closed.
   for(int d_shift = 2; d_shift <= 3; ++d_shift)
     {
      GartleyPattern bullish;
      if(ValidatePattern(1, d_shift, bullish) &&
         !OverlapBlocked(1, d_shift) && !CooldownBlocked(d_shift))
        {
         pattern = bullish;
         return true;
        }

      GartleyPattern bearish;
      if(ValidatePattern(-1, d_shift, bearish) &&
         !OverlapBlocked(-1, d_shift) && !CooldownBlocked(d_shift))
        {
         pattern = bearish;
         return true;
        }
     }
   return false;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(Period() != PERIOD_H4)
      return true;

   // Session: skip 22:00-06:00 broker-time (illiquid Asia distorts H4 pivots).
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.hour < strategy_session_start_hour || dt.hour >= strategy_session_end_hour)
      return true;

   // Spread guard: fail-OPEN on zero spread (.DWX quotes ask==bid in tester).
   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return true;
   if(ask > bid && (ask - bid) >= strategy_spread_atr_mult * atr)
      return true;

   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   ulong existing_ticket = 0;
   if(SameSymbolMagicPosition(existing_ticket))
      return false;

   GartleyPattern pattern;
   if(!BuildSignal(pattern))
      return false;

   const double entry = (pattern.side > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                           : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(entry <= 0.0 || point <= 0.0)
      return false;

   // Initial SL = D -/+ 0.5*ATR, capped at sl_cap_atr * ATR from entry.
   double sl;
   if(pattern.side > 0)
     {
      sl = pattern.d.price - strategy_sl_atr_mult * pattern.atr_h4;
      const double cap = entry - strategy_sl_cap_atr * pattern.atr_h4;
      if(sl < cap)
         sl = cap;
      req.type = QM_BUY;
      req.reason = "BULLISH_GARTLEY_XABCD_H4";
     }
   else
     {
      sl = pattern.d.price + strategy_sl_atr_mult * pattern.atr_h4;
      const double cap = entry + strategy_sl_cap_atr * pattern.atr_h4;
      if(sl > cap)
         sl = cap;
      req.type = QM_SELL;
      req.reason = "BEARISH_GARTLEY_XABCD_H4";
     }
   req.sl = sl;
   req.tp = pattern.tp2;

   if(MathAbs(entry - req.sl) / point <= 0.0)
      return false;

   g_active_side = pattern.side;
   g_active_tp1  = pattern.tp1;
   g_last_x_time = pattern.x.time;
   g_tp1_done    = false;
   if(pattern.side > 0)
      g_last_entry_time_buy = TimeCurrent();
   else
      g_last_entry_time_sell = TimeCurrent();
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   ulong ticket = 0;
   if(!SameSymbolMagicPosition(ticket) || !PositionSelectByTicket(ticket))
      return;
   if(g_tp1_done || g_active_side == 0 || g_active_tp1 <= 0.0)
      return;

   const double volume = PositionGetDouble(POSITION_VOLUME);
   if(volume <= 0.0)
      return;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const bool tp1_hit = (g_active_side > 0) ? (bid >= g_active_tp1) : (ask <= g_active_tp1);
   if(!tp1_hit)
      return;

   const double lots_to_close = volume * strategy_tp1_close_fraction;
   if(QM_TM_PartialClose(ticket, lots_to_close, QM_EXIT_PARTIAL))
     {
      g_tp1_done = true;
      // Trail SL to break-even (entry) on TP1 hit.
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      if(open_price > 0.0)
         QM_TM_MoveSL(ticket, open_price, "gartley_tp1_move_to_breakeven");
     }
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   if(!SameSymbolMagicPosition(ticket) || !PositionSelectByTicket(ticket))
      return false;

   const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
   const int open_shift = iBarShift(_Symbol, PERIOD_H4, open_time, false);
   // Time-stop: 30 H4 bars without TP/SL resolution.
   if(open_shift >= strategy_time_stop_bars)
      return true;

   return false;
  }

// News Filter Hook (callable for P8 News Impact phase)
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1376\",\"ea\":\"QM5_1376_harmonic_gartley_xabcd_h4\"}");
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

   // Detect a stop-loss close to arm the cooldown guard (position vanished while
   // an active side was tracked and TP1 had not yet been taken near the target).
   ulong probe_ticket = 0;
   const bool has_pos = SameSymbolMagicPosition(probe_ticket);
   if(!has_pos && g_active_side != 0 && !g_tp1_done)
     {
      g_last_sl_time = broker_now;
      g_active_side = 0;
     }
   else if(!has_pos)
     {
      g_active_side = 0;
     }

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
