#property strict
#property version   "5.0"
#property description "QM5_1358 AllocateSmartly Generalized Protective Momentum + correlation hedge (monthly D1 rotation)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_1358 — AllocateSmartly Generalized Protective Momentum (GPM), corr-hedged.
// -----------------------------------------------------------------------------
// Keuning & Keller "Generalized Protective Momentum". Cross-sectional, monthly
// rotation with a correlation hedge and a breadth-driven crash-protection switch.
//
// Once per calendar-month roll (last closed D1 bar of the month), over the full
// DWX basket the EA computes, on CLOSED D1 bars:
//   * ri = average of the 1,3,6,12-MONTH price returns (month = 21 D1 bars).
//   * ci = 12-month (252 D1 bar) Pearson correlation of the asset's monthly-step
//          returns vs the equal-weight basket monthly-step returns.
//   * zi = ri * (1 - ci)        (correlation-hedged momentum score).
//   * n  = count of RISK assets with zi > 0 (breadth).
// Allocation:
//   * If n <= breadth_floor  -> 100% crash-protection asset (defensive proxy).
//   * If n >  breadth_floor  -> crash-protection weight ((R - n)/half) and the
//     remainder split equally across the top-3 risk assets by zi. R = risk count,
//     half = R/2 (source: 6 of 12). Crash protection = higher-zi of the CP set.
//
// Per-instance realization: this EA runs ONE instance per registered host symbol
// (host_symbol="_per_instance"). Each instance trades only its OWN chart symbol:
// it goes / stays LONG when its host symbol is in the selected sleeve set
// (top-3 risk OR the chosen crash-protection asset), and flat otherwise. Equal
// weighting is expressed through per-symbol RISK_FIXED sizing; one position per
// magic per leg. This is the single-position-per-magic framework's mechanical
// equivalent of the source's equal-weight multi-sleeve book.
//
// .DWX REALIZATION FLAGS (see SPEC.md / open_questions):
//  * No bond/credit/REIT/Europe-ETF CFDs exist on DWX. The 12-asset source
//    universe ports to 8 routable RISK proxies (5 equity indices + 3 commodities)
//    and XAUUSD.DWX as the DEFENSIVE / crash-protection proxy (gold safe-haven
//    stands in for IEF/TLT; treasuries are not routable). This realizes the
//    "rotate to a defensive proxy" leg as a PRICE-momentum proxy — there is no
//    bond carry/yield feed and .DWX applies $0 swap in the tester, so any
//    yield/carry edge is realized purely through price momentum and FLAGGED.
//  * MULTI-symbol basket EA: foreign-symbol D1 reads need QM_SymbolGuardInit +
//    QM_BasketWarmupHistory in OnInit or iClose returns 0 in the tester -> 0 trades.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1358;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = false;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_month_bars        = 21;    // D1 bars per month proxy (252/12)
input int    strategy_corr_months       = 12;    // correlation lookback in months (12 -> 252 D1 bars)
input int    strategy_top_n             = 3;     // number of risk sleeves to hold when offensive
input double strategy_atr_sl_mult       = 4.0;   // protective initial stop = mult * D1 ATR(period)
input int    strategy_atr_period        = 14;    // D1 ATR period for the protective stop
input double strategy_spread_atr_cap    = 0.50;  // skip entry if quoted spread / D1 ATR exceeds this

// -----------------------------------------------------------------------------
// Basket universe. RISK assets first, then the crash-protection (defensive) leg.
// All registered in magic_numbers.csv with matching slots. All present in
// dwx_symbol_matrix.csv (verified at build time).
// -----------------------------------------------------------------------------
const int STRATEGY_UNIVERSE_SIZE = 9;   // 8 risk + 1 crash-protection
const int STRATEGY_RISK_COUNT    = 8;   // first 8 entries are the risk universe
const int STRATEGY_CP_INDEX      = 8;   // last entry is the defensive / crash-protection proxy

string g_universe_symbols[9] =
  {
   // --- RISK universe (8) ---
   "SP500.DWX",   // S&P 500  (SPY proxy; backtest-only)
   "NDX.DWX",     // Nasdaq 100 (QQQ proxy)
   "WS30.DWX",    // Dow 30   (large-cap / IWM-Russell fallback proxy)
   "GDAXI.DWX",   // DAX 40   (VGK / Europe-equity proxy)
   "UK100.DWX",   // FTSE 100 (international-equity proxy)
   "XTIUSD.DWX",  // WTI crude (DBC commodity proxy)
   "XNGUSD.DWX",  // Nat gas  (DBC commodity proxy)
   "XAGUSD.DWX",  // Silver   (commodity / precious-metal proxy)
   // --- CRASH-PROTECTION / defensive proxy (1) ---
   "XAUUSD.DWX"   // Gold     (IEF/TLT safe-haven proxy; treasuries not routable)
  };
int g_universe_slots[9] = {0, 1, 2, 3, 4, 5, 6, 7, 8};

// Per-closed-bar cache of "is THIS host symbol selected this month". Recomputed
// once per new D1 bar (cheap-guard) so the per-tick exit path never re-runs the
// full-basket allocation. Advanced by AdvanceAllocation_OnNewBar().
datetime g_alloc_bar_time   = 0;
bool     g_alloc_self_sel   = false;
bool     g_alloc_valid      = false;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
      if(g_universe_symbols[i] == _Symbol)
         return i;
   return -1;
  }

int Strategy_CurrentSymbolSlot()
  {
   const int idx = Strategy_CurrentSymbolIndex();
   if(idx < 0)
      return qm_magic_slot_offset;
   return g_universe_slots[idx];
  }

// -----------------------------------------------------------------------------
// Calendar-month roll detection (broker time, derived purely from closed D1 bar
// open-times — NOT a per-EA timestamp gate; it identifies the once-per-month
// rebalance event the source specifies). Returns true when the most recently
// closed D1 bar (shift 1) is in a different calendar month than the bar before
// it (shift 2) — i.e. shift 1 is the first closed bar of a new month, so the
// prior month just finished.
// -----------------------------------------------------------------------------
bool Strategy_IsMonthRoll()
  {
   const datetime t1 = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: monthly calendar-roll detection, only after framework new-bar gate.
   const datetime t2 = iTime(_Symbol, PERIOD_D1, 2); // perf-allowed: monthly calendar-roll detection, only after framework new-bar gate.
   if(t1 <= 0 || t2 <= 0)
      return false;
   MqlDateTime d1, d2;
   TimeToStruct(t1, d1);
   TimeToStruct(t2, d2);
   return (d1.mon != d2.mon || d1.year != d2.year);
  }

// Closed-bar D1 close at shift (>=1). Returns <=0 if missing.
double Strategy_Close(const string symbol, const int shift)
  {
   return iClose(symbol, PERIOD_D1, shift); // perf-allowed: explicit basket monthly return, only after framework new-bar gate.
  }

// Average of the 1/3/6/12-month price returns for one symbol on closed D1 bars.
// month = strategy_month_bars D1 bars. Returns false if any required close
// is missing (foreign history not loaded yet).
bool Strategy_SymbolMomentum(const string symbol, double &out_ri)
  {
   out_ri = 0.0;
   if(!QM_SymbolAssertOrLog(symbol))
      return false;

   const int mb = strategy_month_bars;
   const int horizons[4] = {1, 3, 6, 12};
   const double now_close = Strategy_Close(symbol, 1);
   if(now_close <= 0.0)
      return false;

   double sum = 0.0;
   for(int h = 0; h < 4; ++h)
     {
      const int shift = 1 + horizons[h] * mb;
      const double past = Strategy_Close(symbol, shift);
      if(past <= 0.0)
         return false;
      sum += (now_close / past) - 1.0;
     }
   out_ri = sum / 4.0;
   return true;
  }

// Monthly-step return series for a symbol over the correlation window. Fills
// out_series[0..count-1] with the most-recent-first monthly returns. Returns
// the number of valid points (0 on missing history).
int Strategy_MonthlyReturnSeries(const string symbol, double &out_series[], const int max_points)
  {
   const int mb = strategy_month_bars;
   int n = 0;
   for(int k = 0; k < max_points; ++k)
     {
      const int shift_recent = 1 + k * mb;
      const int shift_prev   = 1 + (k + 1) * mb;
      const double c_recent = Strategy_Close(symbol, shift_recent);
      const double c_prev   = Strategy_Close(symbol, shift_prev);
      if(c_recent <= 0.0 || c_prev <= 0.0)
         break;
      out_series[k] = (c_recent / c_prev) - 1.0;
      ++n;
     }
   return n;
  }

// Pearson correlation of two equal-length series. Returns 0.0 on degenerate
// (zero-variance) input (correlation undefined -> treat as 0 hedge benefit).
double Strategy_Pearson(const double &a[], const double &b[], const int n)
  {
   if(n < 2)
      return 0.0;
   double sa = 0.0, sb = 0.0;
   for(int i = 0; i < n; ++i) { sa += a[i]; sb += b[i]; }
   const double ma = sa / n;
   const double mb = sb / n;
   double cov = 0.0, va = 0.0, vb = 0.0;
   for(int i = 0; i < n; ++i)
     {
      const double da = a[i] - ma;
      const double db = b[i] - mb;
      cov += da * db;
      va  += da * da;
      vb  += db * db;
     }
   if(va <= 0.0 || vb <= 0.0)
      return 0.0;
   return cov / MathSqrt(va * vb);
  }

// -----------------------------------------------------------------------------
// Full-basket GPM allocation evaluated once per month roll. Writes the set of
// SELECTED universe indices into out_selected[] (size STRATEGY_UNIVERSE_SIZE,
// 1 = hold that symbol this month) and returns true if a valid allocation was
// produced (enough history across the basket).
// -----------------------------------------------------------------------------
bool Strategy_EvaluateAllocation(int &out_selected[])
  {
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
      out_selected[i] = 0;

   const int max_pts = strategy_corr_months;     // 12 monthly points
   const int needed_close_bars = 1 + (12 * strategy_month_bars) + 2; // 12m momentum depth

   // 1) Build the equal-weight basket monthly-return series across RISK assets.
   double basket_series[64];
   for(int k = 0; k < max_pts; ++k)
      basket_series[k] = 0.0;
   int basket_pts = max_pts;
   int contrib = 0;
   for(int s = 0; s < STRATEGY_RISK_COUNT; ++s)
     {
      double ser[64];
      const int np = Strategy_MonthlyReturnSeries(g_universe_symbols[s], ser, max_pts);
      if(np < max_pts)
         continue;                 // require full window for the EW reference
      for(int k = 0; k < max_pts; ++k)
         basket_series[k] += ser[k];
      ++contrib;
     }
   if(contrib < (STRATEGY_RISK_COUNT / 2))
      return false;                // not enough of the basket has history yet
   for(int k = 0; k < max_pts; ++k)
      basket_series[k] /= (double)contrib;

   // 2) Per-symbol zi = ri * (1 - ci) across the whole universe.
   double zi[9];
   bool   valid[9];
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i) { zi[i] = 0.0; valid[i] = false; }

   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
     {
      double ri = 0.0;
      if(!Strategy_SymbolMomentum(g_universe_symbols[i], ri))
         continue;
      double ser[64];
      const int np = Strategy_MonthlyReturnSeries(g_universe_symbols[i], ser, max_pts);
      if(np < max_pts)
         continue;
      const double ci = Strategy_Pearson(ser, basket_series, max_pts);
      zi[i]    = ri * (1.0 - ci);
      valid[i] = true;
     }

   // 3) Breadth: count RISK assets with zi > 0.
   int n = 0;
   int valid_risk = 0;
   for(int i = 0; i < STRATEGY_RISK_COUNT; ++i)
     {
      if(!valid[i])
         continue;
      ++valid_risk;
      if(zi[i] > 0.0)
         ++n;
     }
   if(valid_risk < (STRATEGY_RISK_COUNT / 2))
      return false;

   const int breadth_half  = STRATEGY_RISK_COUNT / 2;   // source: 6 of 12
   const int breadth_floor = breadth_half;              // n <= half -> fully defensive

   // 4) Crash-protection leg is always eligible. Here the CP set is a single
   //    defensive proxy (XAUUSD.DWX); if absent/invalid we cannot rotate to it.
   const bool cp_valid = valid[STRATEGY_CP_INDEX];

   if(n <= breadth_floor)
     {
      // Fully defensive: 100% crash protection.
      if(cp_valid)
         out_selected[STRATEGY_CP_INDEX] = 1;
      return true;
     }

   // 5) Offensive: hold top-N risk sleeves by zi; also hold CP for the residual
   //    crash-protection weight ((R - n)/half) when that weight is > 0.
   //    Per-instance binary realization: select top-N risk symbols (equal sized
   //    via RISK_FIXED) and the CP proxy when defensive weight is positive.
   int order[9];
   int oc = 0;
   for(int i = 0; i < STRATEGY_RISK_COUNT; ++i)
      if(valid[i])
         order[oc++] = i;
   // Descending sort risk indices by zi.
   for(int a = 0; a < oc - 1; ++a)
      for(int b = a + 1; b < oc; ++b)
         if(zi[order[b]] > zi[order[a]])
           {
            const int tmp = order[a];
            order[a] = order[b];
            order[b] = tmp;
           }

   int take = strategy_top_n;
   if(take > oc)
      take = oc;
   for(int t = 0; t < take; ++t)
      if(zi[order[t]] > 0.0)             // only hold a risk sleeve with positive zi
         out_selected[order[t]] = 1;

   // Residual crash-protection weight ((R - n)/half). Positive whenever n < R.
   const double cp_weight = (double)(STRATEGY_RISK_COUNT - n) / (double)breadth_half;
   if(cp_weight > 0.0 && cp_valid)
      out_selected[STRATEGY_CP_INDEX] = 1;

   return true;
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

double Strategy_D1ATR()
  {
   return QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
  }

bool Strategy_SpreadAllowsEntry()
  {
   if(strategy_spread_atr_cap <= 0.0)
      return true;

   // .DWX invariant #1: tester quotes ask==bid (0 modeled spread). Never
   // fail-closed on zero spread — only block a genuinely wide quoted spread.
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return true; // zero/invalid modeled spread -> allow (fail-OPEN)

   const double atr = Strategy_D1ATR();
   if(atr <= 0.0)
      return true;
   return ((ask - bid) <= atr * strategy_spread_atr_cap);
  }

// Recompute the cached "self selected" flag once per closed D1 bar. Called from
// OnTick AFTER the QM_IsNewBar() gate, so the full-basket allocation runs at most
// once per bar — never on the per-tick exit path.
void AdvanceAllocation_OnNewBar()
  {
   g_alloc_bar_time = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: cache key, only after framework new-bar gate.
   const int idx = Strategy_CurrentSymbolIndex();
   if(idx < 0)
     {
      g_alloc_valid    = false;
      g_alloc_self_sel = false;
      return;
     }
   int selected[9];
   if(!Strategy_EvaluateAllocation(selected))
     {
      g_alloc_valid    = false;
      g_alloc_self_sel = false;
      return;
     }
   g_alloc_valid    = true;
   g_alloc_self_sel = (selected[idx] == 1);
  }

// Cached read of "is THIS chart symbol selected by the current monthly
// allocation". Falls back to a one-shot compute if the cache was never primed
// (e.g. first roll before any new-bar advance this run).
bool Strategy_SelfSelected()
  {
   if(g_alloc_valid)
      return g_alloc_self_sel;
   const int idx = Strategy_CurrentSymbolIndex();
   if(idx < 0)
      return false;
   int selected[9];
   if(!Strategy_EvaluateAllocation(selected))
      return false;
   return (selected[idx] == 1);
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   if(Strategy_CurrentSymbolIndex() < 0)
      return true;
   // Only act on the monthly rebalance roll.
   if(!Strategy_IsMonthRoll())
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_1358_GPM";
   req.symbol_slot = Strategy_CurrentSymbolSlot();
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_SelfSelected())
      return false;                 // host symbol not in this month's sleeve set
   if(!Strategy_SpreadAllowsEntry())
      return false;

   // GPM holds LONG-only sleeves (rotation into strength / into the defensive
   // proxy). No short leg in source.
   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;
   const double atr = Strategy_D1ATR();
   if(atr <= 0.0)
      return false;

   req.type = QM_BUY;
   req.sl = QM_StopRulesStopFromDistance(_Symbol, req.type, entry, atr * strategy_atr_sl_mult);
   if(req.sl <= 0.0 || req.sl >= entry)
      return false;

   const bool is_cp = (Strategy_CurrentSymbolIndex() == STRATEGY_CP_INDEX);
   req.reason = is_cp ? "QM5_1358_GPM_DEFENSIVE" : "QM5_1358_GPM_RISK_SLEEVE";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Monthly rotation: protective ATR stop is set at entry; no intramonth trail
   // in source. Exit is rebalance-driven (Strategy_ExitSignal). Nothing per-tick.
  }

bool Strategy_ExitSignal()
  {
   if(_Period != PERIOD_D1)
      return false;
   if(!Strategy_HasOpenPosition())
      return false;
   // Only re-decide on the monthly roll; otherwise hold to month end.
   if(!Strategy_IsMonthRoll())
      return false;
   // Exit if the host symbol is no longer in the selected sleeve set.
   return (!Strategy_SelfSelected());
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
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

   // Basket EA: register the universe and pre-load D1 history deep enough for the
   // 12-month momentum + correlation window so foreign-symbol iClose returns real
   // data in the tester (FW7/FW9).
   QM_SymbolGuardInit(g_universe_symbols);
   const int warmup_bars = 1 + (12 * strategy_month_bars) + (strategy_corr_months * strategy_month_bars) + 10;
   QM_BasketWarmupHistory(g_universe_symbols, PERIOD_D1, warmup_bars);

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1358\",\"ea\":\"as-gpm-corrhedge\"}");
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

   // Refresh the cached monthly allocation once per closed D1 bar (the per-tick
   // exit path above reads only the cache).
   AdvanceAllocation_OnNewBar();

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
