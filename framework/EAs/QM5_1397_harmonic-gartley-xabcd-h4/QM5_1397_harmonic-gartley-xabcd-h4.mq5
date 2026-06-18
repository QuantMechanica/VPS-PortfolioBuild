#property strict
#property version   "5.0"
#property description "QM5_1397 Harmonic Gartley XABCD H4 (Carney-canonical, pending-STOP entry)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_1397 — Harmonic Gartley XABCD (H4)
// Card: QM5_1397_harmonic-gartley-xabcd-h4.md (frontmatter ea_id QM5_12175 — stale;
// build target ea_id = 1397, used as qm_ea_id; mismatch flagged in build_result).
//
// Distinct from sibling QM5_1376 (same slug): 1397 uses the card-canonical
//   * Williams 5-bar fractal with a 2-bar half-window (high[k]>high[k-2..k-1] &
//     high[k]>high[k+1..k+2]); confirmed at bar[k+2].
//   * ±3% Fibonacci ratio corridors (AB/XA 0.618, AD/XA 0.786, BC/AB [0.382,0.886],
//     CD/BC [1.13,1.618]).
//   * Time-shape gate (t_D - t_X) in [20,60] H4 bars.
//   * Pending BUY-STOP / SELL-STOP above/below the confirmation-bar high/low,
//     valid for 4 H4 bars (1376 uses a market thrust-close trigger).
//   * SL beyond the X pivot (X -/+ 0.5*ATR), hard-capped at 4.0*ATR (1376 = D +/- 0.5*ATR @ 2.5*ATR).
//   * Pattern-invalidation hard exit on close beyond X.
//   * 60 H4 bar time-stop; pattern-reuse guard 20 H4 bars.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1397;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_pivot_half_window   = 2;       // Williams fractal half-window (card: k-2..k-1 / k+1..k+2)
input int    strategy_pivot_lookback      = 220;     // confirmed-pivot search depth (H4 bars)
input int    strategy_atr_period          = 14;
// --- Gartley Fibonacci ratio corridors (card tolerance +/-3%) ---
input double strategy_ab_xa_min           = 0.598;   // AB/XA in [0.618-0.020, 0.618+0.020]
input double strategy_ab_xa_max           = 0.638;
input double strategy_bc_ab_min           = 0.382;   // BC/AB wide acceptance per Carney
input double strategy_bc_ab_max           = 0.886;
input double strategy_cd_bc_min           = 1.130;   // CD/BC extension projection from C
input double strategy_cd_bc_max           = 1.618;
input double strategy_ad_xa_min           = 0.766;   // AD/XA in [0.786-0.020, 0.786+0.020] (Gartley D-completion)
input double strategy_ad_xa_max           = 0.806;
// --- time-shape anti-degenerate gate ---
input int    strategy_time_shape_min_bars = 20;      // (t_D - t_X) >= 20 H4 bars
input int    strategy_time_shape_max_bars = 60;      // (t_D - t_X) <= 60 H4 bars
// --- entry trigger ---
input int    strategy_entry_valid_bars    = 4;       // pending BUY/SELL-STOP valid for 4 H4 bars
input double strategy_entry_buffer_points  = 0.5;     // trigger = confirm high/low +/- 0.5 * point
// --- stops / targets ---
input double strategy_sl_atr_mult         = 0.5;     // SL = X -/+ 0.5*ATR(14,H4)
input double strategy_sl_cap_atr          = 4.0;     // ABORT if entry-SL > 4.0*ATR (loose pattern)
input double strategy_tp1_ad_retrace      = 0.382;   // TP1 = D + 0.382*|A-D|
input double strategy_tp2_ad_retrace      = 0.618;   // TP2 = D + 0.618*|A-D|
input double strategy_tp1_close_fraction  = 0.50;    // close 50% at TP1, BE on remainder
input int    strategy_time_stop_bars      = 60;      // close at market 60 H4 bars after entry
// --- filters ---
input double strategy_spread_atr_mult     = 0.25;    // skip if spread > 0.25*ATR(14,H4)
input int    strategy_pattern_reuse_bars  = 20;      // no new pattern sharing a pivot within 20 H4 bars

struct PivotPoint
  {
   int      type;     // +1 high, -1 low
   int      shift;
   datetime time;
   double   price;
  };

struct GartleyPattern
  {
   int      side;     // +1 bullish (D low), -1 bearish (D high)
   PivotPoint x;
   PivotPoint a;
   PivotPoint b;
   PivotPoint c;
   PivotPoint d;
   double   atr_h4;
   double   trigger;  // pending-stop price (above confirm-high / below confirm-low)
   double   sl;       // X -/+ 0.5*ATR (capped)
   double   tp1;
   double   tp2;
  };

// --- live-trade tracking state ---
double   g_x_price              = 0.0;       // structural invalidation level for the open trade
int      g_active_side          = 0;
double   g_active_tp1           = 0.0;
double   g_active_tp2           = 0.0;
bool     g_tp1_done             = false;
// --- pattern-reuse guard: last consumed D-pivot time per direction ---
datetime g_last_pattern_d_buy   = 0;
datetime g_last_pattern_d_sell  = 0;

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

bool SameSymbolMagicPending(ulong &ticket)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong t = OrderGetTicket(i);
      if(t == 0 || !OrderSelect(t))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      ticket = t;
      return true;
     }
   ticket = 0;
   return false;
  }

// Williams 5-bar fractal: high[k] strictly greater than the 2 bars either side.
bool IsSwingHigh(const int shift)
  {
   const double h = BarHigh(shift);
   if(h <= 0.0)
      return false;
   for(int k = 1; k <= strategy_pivot_half_window; ++k)
      if(h <= BarHigh(shift - k) || h <= BarHigh(shift + k))
         return false;
   return true;
  }

bool IsSwingLow(const int shift)
  {
   const double l = BarLow(shift);
   if(l <= 0.0)
      return false;
   for(int k = 1; k <= strategy_pivot_half_window; ++k)
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

// Collect confirmed fractal pivots, oldest-first. A pivot at bar[k] is confirmed
// once bar[k+half_window] has closed, so the youngest searchable pivot is at
// shift = half_window + 1 (the confirmation lag the card describes as +2 bars).
int CollectConfirmedPivots(PivotPoint &pivots[])
  {
   int count = 0;
   const int oldest = MathMax(strategy_pivot_half_window + 2, strategy_pivot_lookback);
   for(int shift = oldest; shift >= strategy_pivot_half_window + 1; --shift)
     {
      if(IsSwingHigh(shift))
         AddPivot(pivots, count, 1, shift, BarHigh(shift));
      if(IsSwingLow(shift))
         AddPivot(pivots, count, -1, shift, BarLow(shift));
     }
   return count;
  }

// Walk back from the confirmed pivot just before D, matching the alternating
// X-A-B-C type sequence required for the requested side.
bool ExtractXABC(const int side, const int d_shift, GartleyPattern &pattern)
  {
   PivotPoint pivots[120];
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
      if(pivots[i].shift <= d_shift + strategy_pivot_half_window)
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

// Pattern-reuse guard: do not re-detect a D-pivot that coincides with the last
// traded D for this direction within strategy_pattern_reuse_bars H4 bars.
bool PatternReuseBlocked(const int side, const datetime d_time)
  {
   const datetime last = (side > 0) ? g_last_pattern_d_buy : g_last_pattern_d_sell;
   if(last <= 0)
      return false;
   const int last_shift = iBarShift(_Symbol, PERIOD_H4, last, false);
   const int d_shift    = iBarShift(_Symbol, PERIOD_H4, d_time, false);
   if(last_shift < 0 || d_shift < 0)
      return false;
   return (MathAbs(last_shift - d_shift) <= strategy_pattern_reuse_bars);
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
   if(pattern.atr_h4 <= 0.0)
      return false;

   const double xa = MathAbs(pattern.x.price - pattern.a.price);
   const double ab = MathAbs(pattern.a.price - pattern.b.price);
   const double bc = MathAbs(pattern.c.price - pattern.b.price);
   if(xa <= 0.0 || ab <= 0.0 || bc <= 0.0)
      return false;

   // --- Gartley geometry: D retraces 0.786 of XA, so D stays inside the XA leg ---
   if(side > 0)
     {
      // X low, A high, B low (above X, below A), C high (below A, above B), D low (above X)
      if(!(pattern.x.price < pattern.a.price &&
           pattern.b.price > pattern.x.price && pattern.b.price < pattern.a.price &&
           pattern.c.price < pattern.a.price && pattern.c.price > pattern.b.price &&
           pattern.d.price > pattern.x.price && pattern.d.price < pattern.c.price))
         return false;
     }
   else
     {
      // X high, A low, B high (below X, above A), C low (above A, below B), D high (below X)
      if(!(pattern.x.price > pattern.a.price &&
           pattern.b.price < pattern.x.price && pattern.b.price > pattern.a.price &&
           pattern.c.price > pattern.a.price && pattern.c.price < pattern.b.price &&
           pattern.d.price < pattern.x.price && pattern.d.price > pattern.c.price))
         return false;
     }

   // --- Fibonacci ratio cluster (Gartley signature, +/-3% corridors) ---
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

   // --- time-shape gate: (t_D - t_X) in [20,60] H4 bars (anti-degenerate) ---
   const int span_bars = pattern.x.shift - pattern.d.shift;
   if(span_bars < strategy_time_shape_min_bars || span_bars > strategy_time_shape_max_bars)
      return false;

   // --- TP ladder toward A: TP1 = D + 0.382*|A-D|, TP2 = D + 0.618*|A-D| ---
   const double ad_abs = MathAbs(pattern.a.price - pattern.d.price);
   if(side > 0)
     {
      pattern.tp1 = pattern.d.price + strategy_tp1_ad_retrace * ad_abs;
      pattern.tp2 = pattern.d.price + strategy_tp2_ad_retrace * ad_abs;
     }
   else
     {
      pattern.tp1 = pattern.d.price - strategy_tp1_ad_retrace * ad_abs;
      pattern.tp2 = pattern.d.price - strategy_tp2_ad_retrace * ad_abs;
     }

   // --- pending-STOP trigger above/below the confirmation bar (shift 1) ---
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;
   if(side > 0)
      pattern.trigger = BarHigh(1) + strategy_entry_buffer_points * point;
   else
      pattern.trigger = BarLow(1) - strategy_entry_buffer_points * point;

   // --- initial SL beyond X (the structural invalidation), capped at 4.0*ATR ---
   if(side > 0)
      pattern.sl = pattern.x.price - strategy_sl_atr_mult * pattern.atr_h4;
   else
      pattern.sl = pattern.x.price + strategy_sl_atr_mult * pattern.atr_h4;

   const double risk_dist = MathAbs(pattern.trigger - pattern.sl);
   if(risk_dist <= 0.0)
      return false;
   if(risk_dist > strategy_sl_cap_atr * pattern.atr_h4)   // loose pattern -> abort (HR14 bounded worst-case)
      return false;

   return true;
  }

// D is the just-confirmed extreme; search a small recent window so the
// confirmation bar (shift 1) has closed and the trigger references a closed high/low.
bool BuildSignal(GartleyPattern &pattern)
  {
   const int lo = strategy_pivot_half_window;          // youngest confirmed-D shift
   const int hi = strategy_pivot_half_window + 1;
   for(int d_shift = lo; d_shift <= hi; ++d_shift)
     {
      GartleyPattern bullish;
      if(ValidatePattern(1, d_shift, bullish) &&
         !PatternReuseBlocked(1, bullish.d.time))
        {
         pattern = bullish;
         return true;
        }

      GartleyPattern bearish;
      if(ValidatePattern(-1, d_shift, bearish) &&
         !PatternReuseBlocked(-1, bearish.d.time))
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

   // Spread guard: fail-OPEN on zero spread (.DWX quotes ask==bid in the tester);
   // only block a genuinely wide spread.
   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return true;
   if(ask > bid && (ask - bid) > strategy_spread_atr_mult * atr)
      return true;

   return false;
  }

// Trade Entry — place a pending BUY-STOP / SELL-STOP at the card trigger,
// expiring after strategy_entry_valid_bars H4 bars.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // One pattern per symbol per direction: never stack a position or a pending order.
   ulong existing = 0;
   if(SameSymbolMagicPosition(existing))
      return false;
   if(SameSymbolMagicPending(existing))
      return false;

   GartleyPattern pattern;
   if(!BuildSignal(pattern))
      return false;

   req.price = pattern.trigger;
   req.sl    = pattern.sl;
   req.tp    = pattern.tp2;
   req.expiration_seconds = strategy_entry_valid_bars * 4 * 3600;   // 4 H4 bars

   if(pattern.side > 0)
     {
      req.type = QM_BUY_STOP;
      req.reason = "BULLISH_GARTLEY_XABCD_H4_STOP";
      g_last_pattern_d_buy = pattern.d.time;
     }
   else
     {
      req.type = QM_SELL_STOP;
      req.reason = "BEARISH_GARTLEY_XABCD_H4_STOP";
      g_last_pattern_d_sell = pattern.d.time;
     }

   // Track for management/invalidation once (and if) the stop fills.
   g_active_side = pattern.side;
   g_active_tp1  = pattern.tp1;
   g_active_tp2  = pattern.tp2;
   g_x_price     = pattern.x.price;
   g_tp1_done    = false;
   return true;
  }

// Trade Management — TP1 partial (50%) then move SL to break-even.
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
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      if(open_price > 0.0)
         QM_TM_MoveSL(ticket, open_price, "gartley_tp1_move_to_breakeven");
     }
  }

// Trade Close — Gartley invalidation (close beyond X) and 60-bar time-stop.
bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   if(!SameSymbolMagicPosition(ticket) || !PositionSelectByTicket(ticket))
      return false;

   const long ptype = PositionGetInteger(POSITION_TYPE);

   // --- pattern-invalidation hard exit: prior CLOSE beyond X (gapless .DWX) ---
   if(g_x_price > 0.0)
     {
      const double close_last = BarClose(1);
      if(ptype == POSITION_TYPE_BUY  && close_last < g_x_price)
         return true;
      if(ptype == POSITION_TYPE_SELL && close_last > g_x_price)
         return true;
     }

   // --- time-stop: 60 H4 bars after entry ---
   const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
   const int open_shift = iBarShift(_Symbol, PERIOD_H4, open_time, false);
   if(open_shift >= strategy_time_stop_bars)
      return true;

   return false;
  }

// News Filter Hook (callable for Q09 News Impact phase)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1397\",\"ea\":\"QM5_1397_harmonic_gartley_xabcd_h4\"}");
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

   // Reset tracking once no position AND no pending order remains for this magic.
   ulong probe = 0;
   if(!SameSymbolMagicPosition(probe) && !SameSymbolMagicPending(probe))
     {
      g_active_side = 0;
      g_x_price     = 0.0;
     }

   // Per-tick: management of an open position (TP1 partial + BE).
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (invalidation / time-stop).
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

   // Per-closed-bar: pattern scan + pending-STOP placement.
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
