#property strict
#property version   "5.0"
#property description "QM5_12403 stock-bab — Stock Betting-Against-Beta, cross-sectional long/short on the DWX equity-index proxy basket (D1, basket)"

#include <QM/QM_Common.mqh>
#include <QM/QM_Indicators.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_12403 stock-bab
// -----------------------------------------------------------------------------
// Source: Papers With Backtest / Quantpedia "Betting Against Beta Factor in
// Stocks", source_id b7832a20. Card:
// artifacts/cards_approved/QM5_12403_stock-bab.md (g0_status APPROVED).
//
// BASKET EA — cross-sectional Betting-Against-Beta (BAB). Same BAB mechanic as
// the sibling country-bab (QM5_1104), but the source universe is INDIVIDUAL US
// STOCKS. Individual stocks are NOT available on Darwinex .DWX, so the stock
// universe is PROXIED by the limited DWX equity-index set:
//
//   SP500.DWX (S&P 500, backtest-only), NDX.DWX (Nasdaq 100), WS30.DWX (Dow 30),
//   GDAXI.DWX (DAX 40), UK100.DWX (FTSE 100).
//
// ==> PROXY FLAG: the original per-stock breadth (hundreds of names) collapses
//     to five liquid index CFDs. This is a reduced-breadth port; cross-sectional
//     dispersion is far smaller than the source. Documented in basket_manifest
//     and SPEC. The card's GER40.DWX / JP225.DWX are NOT in dwx_symbol_matrix.csv
//     — GER40 is represented by GDAXI.DWX (DAX) and JP225 is dropped (no matrix
//     entry; never register a phantom symbol).
//
// Mechanic (closed-form OLS beta, NO ML):
//   Benchmark : the cross-sectional EQUAL-WEIGHT UNIVERSE-AVERAGE daily return
//               (the "market" leg), recomputed per closed D1 bar from the basket.
//   Beta      : per instrument, the OLS slope of its daily returns vs the
//               universe-average daily returns over `strategy_beta_lookback_d1`
//               closed D1 bars: beta = Cov(r_i, r_mkt) / Var(r_mkt). Closed-form,
//               deterministic, no fitting/online adaptation.
//   Rank      : sort the valid members by beta ascending.
//   Long      : the lowest-beta bucket (bottom `strategy_bucket_size`).
//   Short     : the highest-beta bucket (top `strategy_bucket_size`).
//   Host      : the EA runs one instance per host symbol; the host trades only
//               when it is itself inside a bucket (long if low-beta, short if
//               high-beta). One position per magic per host.
//   Rebalance : monthly, on the last D1 trading bar of the month (broker time).
//               Open the host leg at month-end if selected; close any host leg
//               opened in a prior month (it is re-evaluated fresh each month).
//   Stop      : protective emergency stop = `strategy_atr_sl_mult` * ATR(20,D1)
//               from entry (card: 3.0*ATR; bounds MT5 worst-case — the monthly
//               reselection is the primary close).
//   Filters   : require at least 2*bucket_size valid members for a usable rank;
//               require >= warmup D1 bars; skip a genuinely wide host spread.
//
// Selection is advanced ONCE per closed D1 bar (cheap O(N*lookback), N=5).
// Foreign-symbol reads are made valid via QM_SymbolGuardInit +
// QM_BasketWarmupHistory in OnInit. Only the five Strategy_* hooks + the OnInit
// basket wiring are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12403;
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
input int    strategy_beta_lookback_d1   = 252;   // OLS beta window in closed D1 bars (P3 {126,252,378})
input int    strategy_min_warmup_bars    = 270;   // min D1 bars per member before it is eligible (card: 270)
input int    strategy_bucket_size        = 2;     // long bottom-K / short top-K by beta (P3 {1,2,3})
input int    strategy_atr_period_d1      = 20;    // emergency-stop ATR period (D1)
input double strategy_atr_sl_mult        = 3.0;   // emergency stop = mult * ATR (card: 3.0)
input double strategy_beta_abs_max       = 5.0;   // reject pathological beta reads as invalid
input double strategy_spread_pct_of_stop = 20.0;  // skip entry if host spread > this % of stop distance

// -----------------------------------------------------------------------------
// Fixed proxy universe (matrix-verified). The stock universe of the source is
// proxied by these five liquid DWX equity-index CFDs. SP500.DWX participates in
// the cross-sectional ranking (backtest-only read member).
// -----------------------------------------------------------------------------
#define QM_MAX_UNIV 8

string g_univ[QM_MAX_UNIV];
int    g_nuniv    = 0;
int    g_host_idx = -1;            // index of _Symbol within g_univ, or -1

// Cached per-rebalance selection state.
double g_beta[QM_MAX_UNIV];        // OLS beta vs universe-average returns
bool   g_valid[QM_MAX_UNIV];       // per-member valid-data flag
int    g_side[QM_MAX_UNIV];        // +1 long (low beta) / -1 short (high beta) / 0 none
int    g_active_count = 0;         // members with valid beta this eval
bool   g_ready    = false;         // true when this eval produced a usable ranking

datetime g_last_entry_rebalance_day = 0;

void QM_BuildUniverse()
  {
   string u[] =
     {
      "SP500.DWX","NDX.DWX","WS30.DWX","GDAXI.DWX","UK100.DWX"
     };
   g_nuniv = ArraySize(u);
   if(g_nuniv > QM_MAX_UNIV) g_nuniv = QM_MAX_UNIV;
   for(int i = 0; i < g_nuniv; ++i)
      g_univ[i] = u[i];
  }

// Warmup list = universe plus the host (host is normally already a member).
void QM_BuildWarmupList(string &out[])
  {
   ArrayResize(out, g_nuniv + 1);
   int n = 0;
   out[n++] = _Symbol;
   for(int i = 0; i < g_nuniv; ++i)
     {
      bool dup = false;
      for(int j = 0; j < n; ++j)
         if(out[j] == g_univ[i]) { dup = true; break; }
      if(!dup) out[n++] = g_univ[i];
     }
   ArrayResize(out, n);
  }

bool QM_HasSufficientBars(const string sym)
  {
   return (Bars(sym, PERIOD_D1) >= strategy_min_warmup_bars);
  }

// -----------------------------------------------------------------------------
// Advance the cross-sectional BAB selection ONCE per closed D1 bar.
//
// Step 1: per member, read the daily-return series over the lookback (closed
//         bars, shift 1..lookback). Cache into a returns matrix.
// Step 2: build the equal-weight universe-average return per bar = the "market".
// Step 3: per member, OLS beta = Cov(r_i, r_mkt) / Var(r_mkt) (closed-form).
// Step 4: rank by beta ascending; long bottom-K, short top-K.
// -----------------------------------------------------------------------------
void QM_AdvanceSelection()
  {
   g_ready = false;
   g_active_count = 0;
   for(int i = 0; i < g_nuniv; ++i)
     {
      g_beta[i]  = 0.0;
      g_valid[i] = false;
      g_side[i]  = 0;
     }

   const int L = strategy_beta_lookback_d1;
   if(L < 2)
      return;

   // Returns matrix: ret[member][bar], bar = 0..L-1 corresponding to D1 shifts
   // (shift, shift+1). member_ok marks members with a fully valid series.
   double ret[QM_MAX_UNIV][512];
   bool   member_ok[QM_MAX_UNIV];
   const int cap = 512;
   const int len = (L < cap) ? L : cap;   // bounded loop (lookback <= 512)

   for(int m = 0; m < g_nuniv; ++m)
     {
      member_ok[m] = false;
      const string sym = g_univ[m];
      if(!QM_HasSufficientBars(sym))
         continue;

      bool ok = true;
      for(int k = 0; k < len; ++k)
        {
         const int shift = k + 1;
         const double c0 = iClose(sym, PERIOD_D1, shift);
         const double c1 = iClose(sym, PERIOD_D1, shift + 1);
         if(c0 <= 0.0 || c1 <= 0.0)
           { ok = false; break; }
         ret[m][k] = (c0 / c1) - 1.0;
        }
      member_ok[m] = ok;
     }

   // Equal-weight universe-average return per bar (the market leg). A bar
   // contributes only members that are valid across the whole window.
   double mkt[512];
   int    nmembers = 0;
   for(int m = 0; m < g_nuniv; ++m)
      if(member_ok[m]) nmembers++;
   if(nmembers < 2)
      return;                               // need >= 2 members for a market

   for(int k = 0; k < len; ++k)
     {
      double s = 0.0;
      for(int m = 0; m < g_nuniv; ++m)
         if(member_ok[m]) s += ret[m][k];
      mkt[k] = s / (double)nmembers;
     }

   // Market variance (one pass).
   double sum_mkt = 0.0;
   for(int k = 0; k < len; ++k) sum_mkt += mkt[k];
   const double mean_mkt = sum_mkt / (double)len;
   double var_mkt = 0.0;
   for(int k = 0; k < len; ++k)
     {
      const double d = mkt[k] - mean_mkt;
      var_mkt += d * d;
     }
   if(var_mkt <= 0.0)
      return;

   // Per-member OLS beta vs the market.
   for(int m = 0; m < g_nuniv; ++m)
     {
      if(!member_ok[m])
         continue;
      double sum_i = 0.0;
      for(int k = 0; k < len; ++k) sum_i += ret[m][k];
      const double mean_i = sum_i / (double)len;

      double cov = 0.0;
      for(int k = 0; k < len; ++k)
         cov += (ret[m][k] - mean_i) * (mkt[k] - mean_mkt);

      const double beta = cov / var_mkt;
      if(MathAbs(beta) > strategy_beta_abs_max)
         continue;                          // pathological — treat as invalid

      g_beta[m]  = beta;
      g_valid[m] = true;
      ++g_active_count;
     }

   // Need at least one full long bucket + one full short bucket.
   if(g_active_count < strategy_bucket_size * 2)
      return;

   // Rank valid members by beta ascending (selection sort on a compact list).
   int    idx[QM_MAX_UNIV];
   double bv[QM_MAX_UNIV];
   int    count = 0;
   for(int m = 0; m < g_nuniv; ++m)
      if(g_valid[m]) { idx[count] = m; bv[count] = g_beta[m]; count++; }

   for(int i = 0; i < count - 1; ++i)
     {
      int best = i;
      for(int j = i + 1; j < count; ++j)
         if(bv[j] < bv[best]) best = j;
      if(best != i)
        {
         const double tb = bv[i]; bv[i] = bv[best]; bv[best] = tb;
         const int ti = idx[i]; idx[i] = idx[best]; idx[best] = ti;
        }
     }

   // Bottom-K = long (low beta); top-K = short (high beta).
   for(int i = 0; i < strategy_bucket_size; ++i)
     {
      g_side[idx[i]]               = +1;    // lowest beta → long
      g_side[idx[count - 1 - i]]   = -1;    // highest beta → short
     }

   g_ready = true;
  }

datetime QM_LastClosedD1Time()
  {
   return iTime(_Symbol, PERIOD_D1, 1);
  }

// True if `day` (a D1 bar open) is the last trading day of its month: the next
// calendar day falls in a different month.
bool QM_IsMonthEndD1(const datetime day)
  {
   if(day <= 0)
      return false;
   MqlDateTime dt;
   TimeToStruct(day, dt);
   const int month = dt.mon;
   dt.day += 1;
   const datetime next_day = StructToTime(dt);
   if(next_day <= 0)
      return false;
   MqlDateTime ndt;
   TimeToStruct(next_day, ndt);
   return (ndt.mon != month);
  }

bool QM_HasOurPosition(ulong &ticket, datetime &opened_at)
  {
   ticket = 0;
   opened_at = 0;
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
      opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick spread guard. Fail-open on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;                         // no valid quote — defer, don't block

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(atr <= 0.0)
      return false;
   const double stop_distance = strategy_atr_sl_mult * atr;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;                          // genuinely wide spread — block
   return false;                            // zero/normal modeled spread — pass
  }

// Monthly BAB entry. Caller guarantees QM_IsNewBar()==true. Selection is
// advanced in OnTick before this call (g_ready / g_side).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const datetime rebalance_day = QM_LastClosedD1Time();
   if(!QM_IsMonthEndD1(rebalance_day) || g_last_entry_rebalance_day == rebalance_day)
      return false;

   ulong ticket = 0;
   datetime opened_at = 0;
   if(QM_HasOurPosition(ticket, opened_at))
      return false;

   if(!g_ready || g_host_idx < 0)
      return false;

   const int side = g_side[g_host_idx];
   if(side == 0)
      return false;                         // host not in a bucket this month

   const QM_OrderType order_type = (side > 0) ? QM_BUY : QM_SELL;
   const double entry = (side > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   const double sl = QM_StopATRFromValue(_Symbol, order_type, entry, atr, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;

   req.type   = order_type;
   req.price  = 0.0;                        // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;                        // no TP — monthly reselection is the primary exit
   req.reason = (side > 0) ? "QM5_12403_BAB_LOW_BETA_LONG" : "QM5_12403_BAB_HIGH_BETA_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   g_last_entry_rebalance_day = rebalance_day;
   return true;
  }

// No active management beyond the static protective ATR emergency stop.
void Strategy_ManageOpenPosition()
  {
  }

// Monthly rebalance exit: close a host leg held from a prior month. Each month
// re-evaluates the ranking fresh, so any position opened before this month's
// rebalance bar is closed (and possibly re-opened on the new side via entry).
bool Strategy_ExitSignal()
  {
   const datetime rebalance_day = QM_LastClosedD1Time();
   if(!QM_IsMonthEndD1(rebalance_day))
      return false;

   ulong ticket = 0;
   datetime opened_at = 0;
   if(!QM_HasOurPosition(ticket, opened_at))
      return false;

   return (opened_at < rebalance_day);
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

   // Build the fixed proxy universe and locate the host within it.
   QM_BuildUniverse();
   g_host_idx = -1;
   for(int i = 0; i < g_nuniv; ++i)
      if(g_univ[i] == _Symbol) { g_host_idx = i; break; }

   // BASKET wiring: register the host + every universe member and warm their D1
   // history so foreign-symbol iClose reads return real tester data.
   string warmlist[];
   QM_BuildWarmupList(warmlist);
   QM_SymbolGuardInit(warmlist);
   const int warm = strategy_beta_lookback_d1 + strategy_min_warmup_bars + 16;
   QM_BasketWarmupHistory(warmlist, PERIOD_D1, warm);

   QM_LogEvent(QM_INFO, "INIT_OK",
               StringFormat("{\"universe\":%d,\"host\":\"%s\",\"host_idx\":%d}",
                            g_nuniv, _Symbol, g_host_idx));
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

   // Latch the closed-bar event ONCE (single-consume). On a fresh D1 bar,
   // refresh the cross-sectional BAB ranking BEFORE the rule-based exit so the
   // signal-exit and entry both see the current selection.
   const bool nb = QM_IsNewBar();
   if(nb)
      QM_AdvanceSelection();

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
