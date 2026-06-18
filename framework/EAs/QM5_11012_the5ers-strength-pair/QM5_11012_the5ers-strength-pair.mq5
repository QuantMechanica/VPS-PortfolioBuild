#property strict
#property version   "5.0"
#property description "QM5_11012 the5ers-strength-pair — Strongest-vs-Weakest currency trend (H1 entry, D1 strength)"

#include <QM/QM_Common.mqh>
#include <QM/QM_Indicators.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11012 the5ers-strength-pair
// -----------------------------------------------------------------------------
// Source: The5ers blog "How to Use Forex Strength Meter Indicator on the MT5
// Platform" (the5ers.com/forex-strength-meter/, source_id 1d445184). Card:
// artifacts/cards_approved/QM5_11012_the5ers-strength-pair.md (g0_status APPROVED).
//
// BASKET EA. Currency strength is computed across the 28 major/minor FX pairs
// covering the 8 currencies USD, EUR, GBP, JPY, AUD, CHF, NZD, CAD. The EA runs
// on each tradable host symbol but only enters when the HOST symbol IS the pair
// formed by the rank-1 (strongest) and rank-8 (weakest) currency, with the
// correct direction, and the host symbol confirms on H1.
//
// Mechanics (closed-bar reads):
//   Strength (D1) : per currency = mean signed 5-day % return of every pair
//                   containing it (+ when base, - when quote). Rank desc.
//   Pair select   : strong=rank1, weak=rank8. The host must contain BOTH.
//                   Direction long if strong is the host's base, short if quote.
//   Confirm (H1)  : long  -> close>EMA50, EMA50 slope up,  H1 return > 0.
//                   short -> close<EMA50, EMA50 slope down, H1 return < 0.
//   Stop          : 1.5 * ATR(H1,14) from entry.
//   Take profit   : 1.8R (R = stop distance).
//   Signal exit   : host no longer the rank1-vs-rank8 pair on the next D1 close.
//   Momentum exit : long closes below EMA50 / short closes above EMA50 (H1).
//   Time stop     : 48 H1 bars held.
//   Filters       : skip if |strength(rank1)-strength(rank8)| < 0.35% ;
//                   skip if host spread > spread_pct_of_atr% of ATR(H1,14) ;
//                   central news blackout for the host symbol.
//
// Only the five Strategy_* hooks + the OnInit basket wiring are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11012;
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
input int    strategy_strength_lookback = 5;     // D1 bars for % return (P3 sweep {3,5,10})
input int    strategy_ema_period        = 50;    // H1 confirmation EMA (P3 sweep {20,50,100})
input int    strategy_atr_period        = 14;    // ATR period for the stop
input double strategy_atr_sl_mult       = 1.5;   // SL = mult * ATR(H1) (P3 sweep {1.0,1.5,2.0})
input double strategy_tp_rr             = 1.8;   // TP in R multiples (P3 sweep {1.2,1.8,2.5})
input double strategy_min_spread_pct    = 0.35;  // skip if rank1-rank8 strength spread < this %
input double strategy_spread_pct_of_atr = 20.0;  // skip if host spread > this % of ATR(H1)
input int    strategy_time_stop_bars    = 48;    // close after N H1 bars held
input int    strategy_session_start_brk = 9;     // London ~09:00 broker (NY-close GMT+2/+3)
input int    strategy_session_end_brk   = 21;    // through NY liquid hours, broker time
input int    strategy_min_d1_bars       = 60;    // skip until enough D1 history per pair

// -----------------------------------------------------------------------------
// Static currency / pair model (the 8 currencies and the 28 covering pairs).
// -----------------------------------------------------------------------------
#define QM_NCCY  8
#define QM_NPAIR 28

string   g_ccy[QM_NCCY];      // currency codes
string   g_pair[QM_NPAIR];    // ".DWX" pair symbols
int      g_pair_base[QM_NPAIR];  // index into g_ccy of base currency
int      g_pair_quote[QM_NPAIR]; // index into g_ccy of quote currency

// Cached strength state, advanced once per closed H1 bar.
double   g_strength[QM_NCCY];     // current signed strength per currency (%)
int      g_rank_strong = -1;      // ccy index of rank 1 (strongest)
int      g_rank_weak   = -1;      // ccy index of rank 8 (weakest)
double   g_spread_pct  = 0.0;     // |strength[strong]-strength[weak]| in %
bool     g_strength_ready = false;
bool     g_closed_bar_ready = false;

// Host decomposition (resolved in OnInit).
int      g_host_base  = -1;       // ccy index of host base, or -1 if host not in model
int      g_host_quote = -1;       // ccy index of host quote, or -1

int QM_CcyIndex(const string code)
  {
   for(int i = 0; i < QM_NCCY; ++i)
      if(g_ccy[i] == code)
         return i;
   return -1;
  }

// Build the static 8-currency / 28-pair model. Pair symbols use the ".DWX"
// suffix and exactly match framework/registry/dwx_symbol_matrix.csv.
void QM_BuildStrengthModel()
  {
   g_ccy[0] = "USD"; g_ccy[1] = "EUR"; g_ccy[2] = "GBP"; g_ccy[3] = "JPY";
   g_ccy[4] = "AUD"; g_ccy[5] = "CHF"; g_ccy[6] = "NZD"; g_ccy[7] = "CAD";

   // The 28 majors/minors present in the DWX matrix (verified against
   // dwx_symbol_matrix.csv). Base = first 3 letters, quote = next 3.
   string p[QM_NPAIR] =
     {
      "EURUSD.DWX","GBPUSD.DWX","AUDUSD.DWX","NZDUSD.DWX",
      "USDJPY.DWX","USDCHF.DWX","USDCAD.DWX",
      "EURGBP.DWX","EURJPY.DWX","EURCHF.DWX","EURAUD.DWX","EURCAD.DWX","EURNZD.DWX",
      "GBPJPY.DWX","GBPCHF.DWX","GBPAUD.DWX","GBPCAD.DWX","GBPNZD.DWX",
      "AUDJPY.DWX","AUDCHF.DWX","AUDCAD.DWX","AUDNZD.DWX",
      "NZDJPY.DWX","NZDCHF.DWX","NZDCAD.DWX",
      "CADJPY.DWX","CADCHF.DWX","CHFJPY.DWX"
     };
   for(int i = 0; i < QM_NPAIR; ++i)
     {
      g_pair[i] = p[i];
      const string base  = StringSubstr(p[i], 0, 3);
      const string quote = StringSubstr(p[i], 3, 3);
      g_pair_base[i]  = QM_CcyIndex(base);
      g_pair_quote[i] = QM_CcyIndex(quote);
     }
  }

// Fill `universe` with the host + the 28 model pairs (deduplicated).
void QM_BuildUniverse(string &universe[])
  {
   ArrayResize(universe, QM_NPAIR + 1);
   universe[0] = _Symbol;
   int n = 1;
   for(int i = 0; i < QM_NPAIR; ++i)
     {
      bool dup = false;
      for(int j = 0; j < n; ++j)
         if(universe[j] == g_pair[i]) { dup = true; break; }
      if(!dup)
        {
         universe[n] = g_pair[i];
         ++n;
        }
     }
   ArrayResize(universe, n);
  }

// -----------------------------------------------------------------------------
// Strength computation — advanced ONCE per closed H1 bar (cheap: 28 D1 reads).
// Uses the last closed D1 bar (shift 1) vs `lookback` bars earlier (shift 1+L).
// -----------------------------------------------------------------------------
void QM_AdvanceStrength()
  {
   double sum[QM_NCCY];
   int    cnt[QM_NCCY];
   for(int c = 0; c < QM_NCCY; ++c) { sum[c] = 0.0; cnt[c] = 0; }

   const int L = strategy_strength_lookback;

   for(int i = 0; i < QM_NPAIR; ++i)
     {
      const int bi = g_pair_base[i];
      const int qi = g_pair_quote[i];
      if(bi < 0 || qi < 0)
         continue;
      if(Bars(g_pair[i], PERIOD_D1) < strategy_min_d1_bars)
         continue;
      // perf-allowed: two closed-bar foreign-symbol close reads per pair (basket leg).
      const double c_now  = iClose(g_pair[i], PERIOD_D1, 1);
      const double c_past = iClose(g_pair[i], PERIOD_D1, 1 + L);
      if(c_now <= 0.0 || c_past <= 0.0)
         continue;                       // missing pair data -> skip this pair (card rule)
      const double ret = (c_now - c_past) / c_past * 100.0;  // % return over L D1 bars
      // Base currency strengthens with a positive pair return; quote weakens.
      sum[bi] += ret;  cnt[bi] += 1;
      sum[qi] -= ret;  cnt[qi] += 1;
     }

   bool all_ok = true;
   for(int c = 0; c < QM_NCCY; ++c)
     {
      if(cnt[c] <= 0) { all_ok = false; g_strength[c] = 0.0; }
      else            g_strength[c] = sum[c] / (double)cnt[c];
     }

   if(!all_ok)
     {
      g_strength_ready = false;
      g_rank_strong = -1;
      g_rank_weak   = -1;
      g_spread_pct  = 0.0;
      return;
     }

   // Rank: find strongest (max) and weakest (min).
   int strong = 0, weak = 0;
   for(int c = 1; c < QM_NCCY; ++c)
     {
      if(g_strength[c] > g_strength[strong]) strong = c;
      if(g_strength[c] < g_strength[weak])   weak   = c;
     }
   g_rank_strong = strong;
   g_rank_weak   = weak;
   g_spread_pct  = MathAbs(g_strength[strong] - g_strength[weak]);
   g_strength_ready = (strong != weak);
  }

// Direction the host should be traded given current strength ranking, or 0 if
// the host is not the rank1-vs-rank8 pair. +1 long, -1 short, 0 none.
int QM_HostStrengthDirection()
  {
   if(!g_strength_ready)
      return 0;
   if(g_host_base < 0 || g_host_quote < 0)
      return 0;
   if(g_spread_pct < strategy_min_spread_pct)
      return 0;

   // Host must be exactly the strong-vs-weak pair (either orientation).
   const bool base_strong  = (g_host_base  == g_rank_strong && g_host_quote == g_rank_weak);
   const bool quote_strong = (g_host_quote == g_rank_strong && g_host_base  == g_rank_weak);
   if(base_strong)  return +1;   // strong is host base  -> long
   if(quote_strong) return -1;   // strong is host quote -> short
   return 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick filter: liquid-session window (broker time) + spread guard.
// Fail-open on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   // Liquid London/NY hours in broker time (wrap-safe, but window is non-wrapping).
   const datetime broker_now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(broker_now, dt);
   const int h = dt.hour;
   if(strategy_session_start_brk <= strategy_session_end_brk)
     {
      if(h < strategy_session_start_brk || h >= strategy_session_end_brk)
         return true;
     }
   else
     {
      if(h < strategy_session_start_brk && h >= strategy_session_end_brk)
         return true;
     }

   // Spread guard: block only a genuinely wide spread relative to ATR.
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;                     // no valid quote — defer, don't block
   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;
   const double spread = ask - bid;
   if(spread > 0.0 && spread > (strategy_spread_pct_of_atr / 100.0) * atr)
      return true;                      // wide spread — block
   return false;                        // zero/normal modeled spread — pass
  }

// H1 entry. Caller guarantees QM_IsNewBar()==true (one call per closed H1 bar).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   if(Bars(_Symbol, PERIOD_H1) < strategy_min_d1_bars)
      return false;

   // Strength is advanced once per closed H1 bar in OnTick (before this call).
   const int dir = QM_HostStrengthDirection();
   if(dir == 0)
      return false;

   // --- H1 confirmation on the host symbol (closed-bar reads at shift 1/2) ---
   const double ema_now  = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_period, 1);
   const double ema_prev = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_period, 2);
   if(ema_now <= 0.0 || ema_prev <= 0.0)
      return false;
   // perf-allowed: two closed-bar close reads for price/return confirmation.
   const double close1 = iClose(_Symbol, PERIOD_H1, 1);
   const double close2 = iClose(_Symbol, PERIOD_H1, 2);
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;
   const double h1_return = close1 - close2;
   const double ema_slope = ema_now - ema_prev;

   if(dir > 0)
     {
      if(!(close1 > ema_now && ema_slope > 0.0 && h1_return > 0.0))
         return false;
     }
   else
     {
      if(!(close1 < ema_now && ema_slope < 0.0 && h1_return < 0.0))
         return false;
     }

   // --- Build the order. Framework sizes lots from the SL distance. ---
   const QM_OrderType ot = (dir > 0) ? QM_BUY : QM_SELL;
   const double entry = (dir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                  : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, ot, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;
   const double tp = QM_TakeRR(_Symbol, ot, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type   = ot;
   req.price  = 0.0;        // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (dir > 0) ? "strength_pair_long" : "strength_pair_short";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// No active trade management beyond the static ATR stop and 1.8R target.
void Strategy_ManageOpenPosition()
  {
  }

// Rule-based exits: momentum (H1 close vs EMA50), signal (host no longer the
// rank1-vs-rank8 pair), and a 48-bar H1 time stop.
bool Strategy_ExitSignal()
  {
   if(!g_closed_bar_ready)
      return false;

   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Determine the open position's direction (one position per magic).
   int pos_dir = 0;
   datetime open_time = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      pos_dir   = (ptype == POSITION_TYPE_BUY) ? +1 : -1;
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      break;
     }
   if(pos_dir == 0)
      return false;

   // Momentum exit: H1 close crosses to the wrong side of EMA50.
   const double ema_now = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_period, 1);
   // perf-allowed: single closed-bar close read for the momentum exit.
   const double close1  = iClose(_Symbol, PERIOD_H1, 1);
   if(ema_now > 0.0 && close1 > 0.0)
     {
      if(pos_dir > 0 && close1 < ema_now) return true;
      if(pos_dir < 0 && close1 > ema_now) return true;
     }

   // Signal exit: host is no longer the rank1-vs-rank8 pair in the SAME
   // direction. Uses the strength cached by the entry path on this H1 bar.
   const int dir_now = QM_HostStrengthDirection();
   if(dir_now != pos_dir)
      return true;

   // Time stop: close after N H1 bars held.
   if(open_time > 0)
     {
      // perf-allowed: single bar-open time read for the time-stop bar count.
      const datetime cur_bar = iTime(_Symbol, PERIOD_H1, 0);
      const int held = Bars(_Symbol, PERIOD_H1, open_time, cur_bar) - 1;
      if(held >= strategy_time_stop_bars)
         return true;
     }

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

   // Build the static currency-strength model and decompose the host symbol.
   QM_BuildStrengthModel();
   const string host_base  = StringSubstr(_Symbol, 0, 3);
   const string host_quote = StringSubstr(_Symbol, 3, 3);
   g_host_base  = QM_CcyIndex(host_base);
   g_host_quote = QM_CcyIndex(host_quote);

   // BASKET wiring: register the host + 28 model pairs and warm their D1 history
   // so foreign-symbol reads return real data in the tester.
   string universe[];
   QM_BuildUniverse(universe);
   QM_SymbolGuardInit(universe);
   QM_BasketWarmupHistory(universe, PERIOD_D1, 300);

   QM_LogEvent(QM_INFO, "INIT_OK",
               StringFormat("{\"host_base\":\"%s\",\"host_quote\":\"%s\",\"pairs\":%d}",
                            host_base, host_quote, QM_NPAIR));
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

   // Latch the closed-bar event ONCE (single-consume) and reuse it. On a fresh
   // H1 bar, refresh D1 currency strength BEFORE evaluating the rule-based exit
   // so the signal-exit sees the current ranking.
   const bool nb = QM_IsNewBar();
   g_closed_bar_ready = nb;
   if(nb)
      QM_AdvanceStrength();

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

   if(!nb)
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
