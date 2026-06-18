#property strict
#property version   "5.0"
#property description "QM5_1391 Harmonic Bat XABCD H4"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1391;
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
input int    strategy_pivot_window       = 5;       // 5-bar fractal half-window (card: pivot-window 5)
input int    strategy_pivot_lookback     = 200;     // confirmed-pivot search depth (H4 bars)
input int    strategy_atr_period         = 14;
input int    strategy_sma_macro_period   = 200;
// --- Bat Fibonacci ratio acceptance windows (Carney FT Press 2010 ch.4) ---
input double strategy_b_retrace_min      = 0.382;   // |B-A|/|X-A| in [0.382, 0.500] (Bat shallow B)
input double strategy_b_retrace_max      = 0.500;
input double strategy_c_retrace_min      = 0.382;   // |C-B|/|A-B| in [0.382, 0.886]
input double strategy_c_retrace_max      = 0.886;
input double strategy_bc_proj_min        = 1.618;   // |D-C|/|A-B| in [1.618, 2.618] (extended C-leg)
input double strategy_bc_proj_max        = 2.618;
input double strategy_d_retrace_min      = 0.870;   // |D-X|/|A-X| in [0.870, 0.902] (0.886 PRZ +/-tol)
input double strategy_d_retrace_max      = 0.902;
// --- structural / regime gates ---
input double strategy_xa_atr_d1_min      = 2.0;     // |X-A| >= 2.0 * ATR(14,D1)
input double strategy_conf_body_min      = 0.40;    // confirmation-bar body_ratio floor
input double strategy_prz_tag_atr        = 0.3;     // |low[1]-D| <= 0.3*ATR(14,H4) PRZ tag
input double strategy_sma_regime_band    = 5.0;     // macro-bias soft-filter band (5*ATR)
input double strategy_vol_lo_mult        = 0.7;     // ATR[1] >= 0.7 * ATR[40]
input double strategy_vol_hi_mult        = 2.5;     // ATR[1] <= 2.5 * ATR[40]
input int    strategy_vol_ref_shift      = 40;      // volatility-regime reference bar
input double strategy_vol_shock_mult     = 2.5;     // ATR[1] > 2.5 * ATR[60] => shock skip
input int    strategy_vol_shock_shift    = 60;      // shock-regime reference bar
input double strategy_spread_atr_mult    = 0.4;     // spread guard cap (fail-OPEN)
// --- exits / stops ---
input double strategy_sl_atr_mult        = 0.5;     // SL = X -/+ 0.5*ATR(14,H4)
input double strategy_tp1_ad_retrace     = 0.382;   // TP1 = D +/- 0.382*(A-D)
input double strategy_tp2_ad_retrace     = 0.618;   // TP2 = D +/- 0.618*(A-D)
input double strategy_tp1_close_fraction = 0.50;
input int    strategy_time_stop_bars     = 40;      // 40 H4 bars time-stop (~7 trading days)
input int    strategy_reuse_guard_bars   = 24;      // no re-trade on same X-anchor for 24 bars
input int    strategy_session_start_hour = 7;       // session gate 07:00-21:00 broker
input int    strategy_session_end_hour   = 21;
input int    strategy_friday_cutoff_hour = 16;      // no new entries Fri after 16:00 broker

struct PivotPoint
  {
   int      type;     // +1 high, -1 low
   int      shift;
   datetime time;
   double   price;
  };

struct BatPattern
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

datetime g_active_x_time        = 0;
int      g_active_side          = 0;
double   g_active_x_price       = 0.0;
double   g_active_tp1           = 0.0;
bool     g_tp1_done             = false;
datetime g_last_traded_x_time   = 0;   // X-anchor of last entry (re-use guard)
int      g_last_traded_side     = 0;

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
bool ExtractXABC(const int side, const int before_shift, BatPattern &pattern)
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

double BodyRatio(const int shift)
  {
   const double rng = BarHigh(shift) - BarLow(shift);
   return MathAbs(BarClose(shift) - BarOpen(shift)) / (rng + 1e-9);
  }

bool ValidatePattern(const int side, const int d_shift, BatPattern &pattern)
  {
   pattern.side = side;
   if(!ExtractXABC(side, d_shift, pattern))
      return false;

   pattern.d.type  = (side > 0) ? -1 : 1;
   pattern.d.shift = d_shift;
   pattern.d.time  = iTime(_Symbol, PERIOD_H4, d_shift);
   pattern.d.price = (side > 0) ? BarLow(d_shift) : BarHigh(d_shift);

   pattern.atr_h4 = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double sma200 = QM_SMA(_Symbol, PERIOD_H4, strategy_sma_macro_period, 1);
   if(pattern.atr_h4 <= 0.0 || atr_d1 <= 0.0 || sma200 <= 0.0)
      return false;

   const double xa = MathAbs(pattern.x.price - pattern.a.price);
   const double ab = MathAbs(pattern.a.price - pattern.b.price);
   if(xa <= 0.0 || ab <= 0.0)
      return false;

   // --- Bat geometry: D retraces 0.886 of XA, so D stays inside the XA leg ---
   if(side > 0)
     {
      // X low, A high, B higher-low (above X, below A), C lower-high (below A, above B),
      // D higher-low (above X, the 0.886 retracement).
      if(!(pattern.x.price < pattern.a.price &&
           pattern.b.price > pattern.x.price && pattern.b.price < pattern.a.price &&
           pattern.c.price < pattern.a.price && pattern.c.price > pattern.b.price &&
           pattern.d.price > pattern.x.price && pattern.d.price < pattern.c.price))
         return false;
     }
   else
     {
      // X high, A low, B lower-high (below X, above A), C higher-low (above A, below B),
      // D lower-high (below X, the 0.886 retracement from above).
      if(!(pattern.x.price > pattern.a.price &&
           pattern.b.price < pattern.x.price && pattern.b.price > pattern.a.price &&
           pattern.c.price > pattern.a.price && pattern.c.price < pattern.b.price &&
           pattern.d.price < pattern.x.price && pattern.d.price > pattern.c.price))
         return false;
     }

   // --- Bat Fibonacci ratio cluster (all four gates MUST PASS simultaneously) ---
   const double b_retrace  = MathAbs(pattern.b.price - pattern.a.price) / xa;             // |B-A|/|X-A|
   const double c_retrace  = MathAbs(pattern.c.price - pattern.b.price) / ab;             // |C-B|/|A-B|
   const double bc_proj    = MathAbs(pattern.d.price - pattern.c.price) / ab;             // |D-C|/|A-B|
   const double d_retrace  = MathAbs(pattern.d.price - pattern.x.price)
                             / MathAbs(pattern.a.price - pattern.x.price);                // |D-X|/|A-X|

   if(!RatioInRange(b_retrace, strategy_b_retrace_min, strategy_b_retrace_max))
      return false;
   if(!RatioInRange(c_retrace, strategy_c_retrace_min, strategy_c_retrace_max))
      return false;
   if(!RatioInRange(bc_proj, strategy_bc_proj_min, strategy_bc_proj_max))
      return false;
   if(!RatioInRange(d_retrace, strategy_d_retrace_min, strategy_d_retrace_max))
      return false;

   // --- Magnitude gate: XA leg >= 2.0 * ATR(14,D1) ---
   if(xa < strategy_xa_atr_d1_min * atr_d1)
      return false;

   // --- D-confirmation bar (shift 1): direction + body + PRZ tag ---
   if(side > 0)
     {
      if(!(BarClose(1) > BarOpen(1)))
         return false;
      if(BodyRatio(1) < strategy_conf_body_min)
         return false;
      if(MathAbs(BarLow(1) - pattern.d.price) > strategy_prz_tag_atr * pattern.atr_h4)
         return false;
      // Bar-2 confirmation: momentum reversal in progress.
      if(!(BarClose(1) > BarClose(2)))
         return false;
      // Macro-bias soft-filter: not in a deep bear regime.
      if(!(BarClose(1) > sma200 - strategy_sma_regime_band * pattern.atr_h4))
         return false;
     }
   else
     {
      if(!(BarClose(1) < BarOpen(1)))
         return false;
      if(BodyRatio(1) < strategy_conf_body_min)
         return false;
      if(MathAbs(BarHigh(1) - pattern.d.price) > strategy_prz_tag_atr * pattern.atr_h4)
         return false;
      if(!(BarClose(1) < BarClose(2)))
         return false;
      if(!(BarClose(1) < sma200 + strategy_sma_regime_band * pattern.atr_h4))
         return false;
     }

   // --- Volatility regime gate: ATR[1] within [0.7, 2.5] * ATR[ref] band ---
   const double atr_ref = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, strategy_vol_ref_shift);
   if(atr_ref > 0.0)
     {
      if(pattern.atr_h4 < strategy_vol_lo_mult * atr_ref ||
         pattern.atr_h4 > strategy_vol_hi_mult * atr_ref)
         return false;
     }
   // --- Shock-regime guard: skip if ATR[1] > 2.5 * ATR[60] ---
   const double atr_shock = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, strategy_vol_shock_shift);
   if(atr_shock > 0.0 && pattern.atr_h4 > strategy_vol_shock_mult * atr_shock)
      return false;

   // --- TP ladder: 38.2% / 61.8% of AD toward A ---
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

// Pattern re-use guard: no new trade on the same X-anchor for N H4 bars.
bool ReuseBlocked(const int side, const datetime x_time)
  {
   if(g_last_traded_x_time <= 0 || g_last_traded_side != side)
      return false;
   if(g_last_traded_x_time != x_time)
      return false;
   const int last_shift = iBarShift(_Symbol, PERIOD_H4, x_time, false);
   const int now_shift  = iBarShift(_Symbol, PERIOD_H4, TimeCurrent(), false);
   if(last_shift < 0 || now_shift < 0)
      return false;
   return ((last_shift - now_shift) <= strategy_reuse_guard_bars);
  }

bool BuildSignal(BatPattern &pattern)
  {
   // D-completion is the single trigger EVENT. The confirmation bar is shift 1
   // (just-closed bar). D completed on the most recent or just-prior closed bar
   // (card pattern-freshness: D_time = bar[1] or bar[2]); search d_shift 1..2.
   for(int d_shift = 1; d_shift <= 2; ++d_shift)
     {
      BatPattern bullish;
      if(ValidatePattern(1, d_shift, bullish) && !ReuseBlocked(1, bullish.x.time))
        {
         pattern = bullish;
         return true;
        }

      BatPattern bearish;
      if(ValidatePattern(-1, d_shift, bearish) && !ReuseBlocked(-1, bearish.x.time))
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

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   // Session gate: enter only on bars closing 07:00-21:00 broker (skip Asia).
   if(dt.hour < strategy_session_start_hour || dt.hour >= strategy_session_end_hour)
      return true;
   // Friday gate: no new entries after 16:00 broker on Friday.
   if(dt.day_of_week == 5 && dt.hour >= strategy_friday_cutoff_hour)
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

   BatPattern pattern;
   if(!BuildSignal(pattern))
      return false;

   const double entry = (pattern.side > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                           : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(entry <= 0.0 || point <= 0.0)
      return false;

   // SL anchored at X (the Bat invalidation level): X -/+ 0.5*ATR(14,H4).
   double sl;
   if(pattern.side > 0)
     {
      sl = pattern.x.price - strategy_sl_atr_mult * pattern.atr_h4;
      if(sl >= entry)
         return false;
      req.type = QM_BUY;
      req.reason = "BULLISH_BAT_XABCD_H4";
     }
   else
     {
      sl = pattern.x.price + strategy_sl_atr_mult * pattern.atr_h4;
      if(sl <= entry)
         return false;
      req.type = QM_SELL;
      req.reason = "BEARISH_BAT_XABCD_H4";
     }
   req.sl = sl;
   req.tp = pattern.tp2;

   if(MathAbs(entry - req.sl) / point <= 0.0)
      return false;

   g_active_side    = pattern.side;
   g_active_tp1     = pattern.tp1;
   g_active_x_time  = pattern.x.time;
   g_active_x_price = pattern.x.price;
   g_tp1_done       = false;
   g_last_traded_x_time = pattern.x.time;
   g_last_traded_side   = pattern.side;
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

   // TP1: close 50%, move SL to break-even.
   const double lots_to_close = volume * strategy_tp1_close_fraction;
   if(QM_TM_PartialClose(ticket, lots_to_close, QM_EXIT_PARTIAL))
     {
      g_tp1_done = true;
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      if(open_price > 0.0)
         QM_TM_MoveSL(ticket, open_price, "bat_tp1_move_to_breakeven");
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
   // Time-stop: 40 H4 bars without TP/SL resolution.
   if(open_shift >= strategy_time_stop_bars)
      return true;

   // Pattern-invalidation hard-exit: foundational X-anchor violated.
   if(g_active_side != 0 && g_active_x_price > 0.0)
     {
      if(g_active_side > 0 && BarLow(1) < g_active_x_price)
         return true;
      if(g_active_side < 0 && BarHigh(1) > g_active_x_price)
         return true;
     }

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1391\",\"ea\":\"QM5_1391_harmonic_bat_xabcd_h4\"}");
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

   // Clear active tracking when the position has closed (SL/TP/manual).
   ulong probe_ticket = 0;
   if(!SameSymbolMagicPosition(probe_ticket))
      g_active_side = 0;

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
