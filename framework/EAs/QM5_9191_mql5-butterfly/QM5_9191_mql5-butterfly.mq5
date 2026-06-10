#property strict
#property version   "5.0"
#property description "QM5_9191 Butterfly Harmonic Reversal — XABCD pattern with ATR stop"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9191 — Butterfly Harmonic Reversal (H1)
// Strategy: detect XABCD Butterfly harmonic pattern on closed bars.
// B retraces ~78.6% XA; BC 38.2%-88.6% XA; CD extends 127%-161.8% XA.
// D below X (bullish) or above X (bearish). ATR(14) stop, Fib TP at 61.8% AD.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 9191;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

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
input int    strategy_pivot_strength      = 3;     // bars each side for swing pivot confirmation
input int    strategy_pivot_lookback      = 100;   // max bars to scan for pivots
input int    strategy_atr_period          = 14;    // ATR period for stop + min-XA filter
input double strategy_min_xa_atr_mult     = 1.0;  // minimum XA leg as ATR multiple
input double strategy_ratio_tol           = 0.05; // ±tolerance for Fibonacci ratio checks

// Butterfly Fibonacci ratios (card-literal)
#define QM_BFLY_B_RETRACE    0.786
#define QM_BFLY_BC_LOW       0.382
#define QM_BFLY_BC_HIGH      0.886
#define QM_BFLY_CD_LOW       1.270
#define QM_BFLY_CD_HIGH      1.618
#define QM_BFLY_TP1_RATIO    0.618   // TP1 at 61.8% of AD from D

// Cached per-bar pattern state
struct BflySignal
  {
   bool   found;
   int    direction;   // +1 long (bullish D), -1 short (bearish D)
   double d_price;
   double a_price;     // for AD-distance TP calculation
  };

BflySignal g_bfly;

// =============================================================================
// Pivot detection — bespoke structural logic (perf-allowed inside QM_IsNewBar gate)
// =============================================================================

struct SwingPoint
  {
   double price;
   int    ptype;  // +1 swing high, -1 swing low
  };

// Collect alternating swing pivots from bars strength..lookback-strength.
// Returns the count of pivots found (pivots[0] = most recent).
int CollectAlternatingPivots(const string sym, const ENUM_TIMEFRAMES tf,
                              const int lookback, const int strength,
                              SwingPoint &pts[], int &cnt)
  {
   cnt = 0;
   ArrayResize(pts, lookback);
   int last_type = 0;

   for(int i = strength; i <= lookback - strength && cnt < 50; i++)
     {
      const double h = iHigh(sym, tf, i);   // perf-allowed: bespoke structural pivot scan
      const double l = iLow(sym, tf, i);    // perf-allowed

      bool is_h = true, is_l = true;
      for(int j = 1; j <= strength; j++)
        {
         if(iHigh(sym, tf, i - j) >= h || iHigh(sym, tf, i + j) >= h) is_h = false;  // perf-allowed
         if(iLow(sym, tf, i - j)  <= l || iLow(sym, tf, i + j)  <= l) is_l = false;  // perf-allowed
        }

      if(is_h && last_type != 1)
        {
         pts[cnt].price = h;
         pts[cnt].ptype = 1;
         cnt++;
         last_type = 1;
        }
      else if(is_l && last_type != -1)
        {
         pts[cnt].price = l;
         pts[cnt].ptype = -1;
         cnt++;
         last_type = -1;
        }
     }
   return cnt;
  }

// Check Fibonacci ratio within symmetric tolerance
bool FibNear(const double actual, const double target, const double tol)
  {
   return MathAbs(actual - target) <= tol;
  }

// Detect the most recent Butterfly XABCD pattern in the alternating pivot list.
// pivots are ordered most-recent first: [D, C, B, A, X, ...]
// Returns +1 (bullish D=low), -1 (bearish D=high), 0 (none).
int FindButterflyInPivots(const SwingPoint &pts[], const int cnt,
                          const double min_xa, const double tol,
                          double &out_d, double &out_a)
  {
   for(int start = 0; start + 4 < cnt; start++)
     {
      // Pivot order: pts[start]=D (most recent), pts[start+1]=C, [start+2]=B, [start+3]=A, [start+4]=X
      const double D = pts[start  ].price;
      const double C = pts[start+1].price;
      const double B = pts[start+2].price;
      const double A = pts[start+3].price;
      const double X = pts[start+4].price;
      const int    Dt = pts[start  ].ptype;
      const int    Xt = pts[start+4].ptype;

      // D and X must be same type (both lows for bullish, both highs for bearish)
      if(Dt != Xt) continue;

      const double xa = MathAbs(A - X);
      if(xa < min_xa || xa < 1e-10) continue;

      const double ab = MathAbs(B - A);
      const double bc = MathAbs(C - B);
      const double cd = MathAbs(D - C);

      // B retraces ~78.6% of XA
      if(!FibNear(ab / xa, QM_BFLY_B_RETRACE, tol)) continue;
      // BC retraces 38.2%-88.6% of XA (card-literal)
      const double bc_xa = bc / xa;
      if(bc_xa < QM_BFLY_BC_LOW - tol || bc_xa > QM_BFLY_BC_HIGH + tol) continue;
      // CD extends 127%-161.8% of XA
      const double cd_xa = cd / xa;
      if(cd_xa < QM_BFLY_CD_LOW - tol || cd_xa > QM_BFLY_CD_HIGH + tol) continue;

      // D must extend beyond X (Butterfly extension rule)
      if(Dt == -1)
        {
         // Bullish: D is a swing low, must be below X (lower low)
         if(D >= X) continue;
         out_d = D; out_a = A;
         return 1;
        }
      else
        {
         // Bearish: D is a swing high, must be above X (higher high)
         if(D <= X) continue;
         out_d = D; out_a = A;
         return -1;
        }
     }
   return 0;
  }

// =============================================================================
// Per-bar state update — called once per new closed bar inside EntrySignal
// =============================================================================

void AdvanceState_OnNewBar()
  {
   g_bfly.found     = false;
   g_bfly.direction = 0;

   const double atr_val = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_val <= 0.0) return;

   SwingPoint pts[];
   int cnt = 0;
   CollectAlternatingPivots(_Symbol, _Period,
                             strategy_pivot_lookback,
                             strategy_pivot_strength,
                             pts, cnt);
   if(cnt < 5) return;

   double d_px = 0.0, a_px = 0.0;
   const int dir = FindButterflyInPivots(pts, cnt,
                                          atr_val * strategy_min_xa_atr_mult,
                                          strategy_ratio_tol,
                                          d_px, a_px);
   if(dir == 0) return;

   g_bfly.found     = true;
   g_bfly.direction = dir;
   g_bfly.d_price   = d_px;
   g_bfly.a_price   = a_px;
  }

// =============================================================================
// Strategy hooks
// =============================================================================

// No Trade Filter — no session or spread filter required by card
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Entry Signal — Butterfly pattern confirmation at D
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Update per-bar state (called only when QM_IsNewBar() == true in framework OnTick)
   AdvanceState_OnNewBar();

   if(!g_bfly.found) return false;

   // One open position per magic (card: one active pattern trade per symbol/magic)
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) == magic) return false;
     }

   const double atr_val = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_val <= 0.0) return false;

   const double ad_dist = MathAbs(g_bfly.a_price - g_bfly.d_price);
   if(ad_dist < 1e-10) return false;

   if(g_bfly.direction == 1)  // Bullish: buy
     {
      const double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double sl_prc = g_bfly.d_price - atr_val;
      const double tp_prc = g_bfly.d_price + ad_dist * QM_BFLY_TP1_RATIO;
      const double sl_pts = (ask - sl_prc) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(sl_pts <= 0.0) return false;

      req.type    = ORDER_TYPE_BUY;
      req.price   = ask;
      req.sl      = sl_prc;
      req.tp      = tp_prc;
      req.lots    = QM_LotsForRisk(_Symbol, sl_pts);
      req.comment = "Bfly_Long";
     }
   else  // Bearish: sell
     {
      const double bid    = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double sl_prc = g_bfly.d_price + atr_val;
      const double tp_prc = g_bfly.d_price - ad_dist * QM_BFLY_TP1_RATIO;
      const double sl_pts = (sl_prc - bid) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(sl_pts <= 0.0) return false;

      req.type    = ORDER_TYPE_SELL;
      req.price   = bid;
      req.sl      = sl_prc;
      req.tp      = tp_prc;
      req.lots    = QM_LotsForRisk(_Symbol, sl_pts);
      req.comment = "Bfly_Short";
     }

   return true;
  }

// Trade Management — SL/TP handles exits; no active trail for P2 baseline
void Strategy_ManageOpenPosition()
  {
  }

// Exit Signal — close on confirmed opposite Butterfly pattern (reads cached state)
bool Strategy_ExitSignal()
  {
   if(!g_bfly.found) return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pt == POSITION_TYPE_BUY  && g_bfly.direction == -1) return true;
      if(pt == POSITION_TYPE_SELL && g_bfly.direction ==  1) return true;
     }
   return false;
  }

// News Filter Hook — defer to framework QM_NewsAllowsTrade
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// =============================================================================
// Framework wiring — do NOT edit below this line unless you know why.
// =============================================================================

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
