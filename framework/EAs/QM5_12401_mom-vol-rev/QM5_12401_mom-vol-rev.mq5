#property strict
#property version   "5.0"
#property description "QM5_12401 High-Volatility Momentum/Reversal Basket (cross-sectional, D1, long/short)"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketEquityStop.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_12401 mom-vol-rev
// -----------------------------------------------------------------------------
// Monthly cross-sectional momentum/reversal over a global CFD basket. At the
// start of each calendar month, for every basket symbol with enough D1 history,
// skip the most-recent N D1 bars, then compute a 6-month (126-bar) return and an
// annualized realized volatility from daily log returns over that same window.
// The highest-volatility subset is selected; within it the strongest performers
// are bought and the weakest sold.
//
// ARCHITECTURE — one instance per symbol, one magic per symbol (framework
// standard). Every instance deterministically recomputes the SAME full-basket
// ranking (QM_BasketWarmupHistory loads OHLC for all basket symbols) and then
// acts only on ITS OWN chart symbol's resulting long / short / flat state. The
// computation is deterministic and every instance sees the same basket data, so
// the cross-sectional selection is reproduced without cross-instance coordination.
//
// REBALANCE — NON-OVERLAPPING monthly (sanctioned card fallback: one position
// per magic cannot represent 6 overlapping tranches safely). Each new calendar
// month: close this symbol's leg if the new rank no longer selects it in the
// same direction; hold if still selected same direction; open if newly selected.
// One entry per month (a mid-month emergency-stop does NOT re-enter until the
// next rebalance). See SPEC.md for the tranche-approximation note.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12401;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.25;   // card override: live 0.25% (not the 0.5% default)
input double RISK_FIXED                 = 1000.0; // backtest $1000 per selected leg
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
input int    strategy_lookback_d1            = 126;  // return/vol lookback (D1 bars, ~6 months)
input int    strategy_skip_d1                = 5;    // skip most-recent D1 bars before the lookback
input int    strategy_vol_subset_size        = 4;    // highest-volatility subset size (of the basket)
input int    strategy_breadth                = 1;    // #long + #short inside the high-vol subset
input int    strategy_min_valid_symbols      = 7;    // require full available basket valid before trading
input int    strategy_warmup_bars            = 140;  // minimum host D1 bars
input int    strategy_atr_period             = 20;   // ATR period for the per-leg emergency stop
input double strategy_atr_sl_mult            = 3.0;  // per-leg emergency stop = mult * ATR(period)
input int    strategy_median_spread_lookback = 60;   // rolling median-spread window (D1 bars)
input double strategy_spread_mult            = 2.0;  // skip entry if spread > mult * median spread
input double strategy_basket_stop_r_mult     = 6.0;  // basket aggregate stop = -mult * R (cross-magic)

// -----------------------------------------------------------------------------
// Strategy state
// -----------------------------------------------------------------------------
#define QM_MVR_DIR_LONG    1
#define QM_MVR_DIR_SHORT  -1
#define QM_MVR_DIR_FLAT    0
#define QM_MVR_DIR_HOLD   99   // not-ready sentinel: hold current leg, take no new decision

// Basket universe. Card lists 8 symbols; GER40.DWX -> GDAXI.DWX (the DAX 40
// Custom Symbol in the matrix); JP225.DWX has no DWX equivalent and is dropped
// (documented in SPEC / open_questions). Order == registered magic slots 0..6.
string g_mvr_basket[7] =
  {
   "SP500.DWX", "NDX.DWX", "WS30.DWX", "GDAXI.DWX", "UK100.DWX", "XAUUSD.DWX", "XTIUSD.DWX"
  };
int    g_mvr_basket_n           = 0;
int    g_mvr_last_rebalance_key = 0;    // month key of the last recomputed decision
int    g_mvr_desired_dir        = QM_MVR_DIR_HOLD;
int    g_mvr_acted_key          = 0;    // month key for which an entry was already placed

// -----------------------------------------------------------------------------
// Cross-sectional helpers
// -----------------------------------------------------------------------------

// Current position direction for this instance's own chart symbol + magic.
int QM_MVR_HostDir()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      return (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? QM_MVR_DIR_LONG : QM_MVR_DIR_SHORT;
     }
   return QM_MVR_DIR_FLAT;
  }

// 6-month (skip-adjusted) return + annualized realized volatility for one symbol.
// Returns false when there is not yet enough clean history.
bool QM_MVR_ComputeMetrics(const string sym, double &out_ret, double &out_vol)
  {
   out_ret = 0.0;
   out_vol = 0.0;
   const int lb   = strategy_lookback_d1;
   const int skip = strategy_skip_d1;
   if(lb < 20 || skip < 0)
      return false;
   const int need = lb + 1;                    // lb daily returns require lb+1 closes
   double closes[];
   ArraySetAsSeries(closes, true);             // [0] = most-recent close in the window
   // Cross-sectional basket close read, recomputed once per calendar month (QM_MVR_EnsureMonthlyDecision gate).
   const int got = CopyClose(sym, PERIOD_D1, skip + 1, need, closes); // perf-allowed
   if(got != need)
      return false;
   for(int i = 0; i < need; ++i)
      if(closes[i] <= 0.0)
         return false;

   out_ret = (closes[0] / closes[lb]) - 1.0;   // skip-adjusted lookback return

   double rets[];
   ArrayResize(rets, lb);
   double mean = 0.0;
   for(int i = 0; i < lb; ++i)
     {
      const double r = MathLog(closes[i] / closes[i + 1]);  // newer / older
      rets[i] = r;
      mean += r;
     }
   mean /= lb;
   double var = 0.0;
   for(int i = 0; i < lb; ++i)
     {
      const double d = rets[i] - mean;
      var += d * d;
     }
   var /= (lb - 1);                            // sample variance
   out_vol = MathSqrt(var) * MathSqrt(252.0);  // annualized realized vol
   return true;
  }

// Full deterministic cross-sectional ranking -> desired direction for _Symbol.
int QM_MVR_ComputeDesiredDir()
  {
   const int n = g_mvr_basket_n;
   double m_ret[];
   double m_vol[];
   bool   m_valid[];
   ArrayResize(m_ret, n);
   ArrayResize(m_vol, n);
   ArrayResize(m_valid, n);

   int valid_count = 0;
   int host_idx    = -1;
   for(int i = 0; i < n; ++i)
     {
      double rr = 0.0;
      double vv = 0.0;
      m_valid[i] = QM_MVR_ComputeMetrics(g_mvr_basket[i], rr, vv);
      m_ret[i]   = rr;
      m_vol[i]   = vv;
      if(m_valid[i])
         valid_count++;
      if(g_mvr_basket[i] == _Symbol)
         host_idx = i;
     }

   if(host_idx < 0)
      return QM_MVR_DIR_FLAT;                          // _Symbol not in basket -> never trade
   if(valid_count < strategy_min_valid_symbols)
      return QM_MVR_DIR_HOLD;                          // basket warmup not ready
   if(!m_valid[host_idx])
      return QM_MVR_DIR_HOLD;

   int subset_size = strategy_vol_subset_size;
   if(subset_size < 1)
      subset_size = 1;
   if(subset_size > valid_count)
      subset_size = valid_count;

   // Index list of valid symbols, sorted by volatility DESC (insertion sort;
   // deterministic tie order == basket order, identical across instances).
   int idx[];
   ArrayResize(idx, valid_count);
   int k = 0;
   for(int i = 0; i < n; ++i)
      if(m_valid[i])
        {
         idx[k] = i;
         k++;
        }
   for(int a = 1; a < valid_count; ++a)
     {
      const int    key = idx[a];
      const double kv  = m_vol[key];
      int b = a - 1;
      while(b >= 0 && m_vol[idx[b]] < kv)
        {
         idx[b + 1] = idx[b];
         b--;
        }
      idx[b + 1] = key;
     }

   bool host_in_subset = false;
   for(int a = 0; a < subset_size; ++a)
      if(idx[a] == host_idx)
        {
         host_in_subset = true;
         break;
        }
   if(!host_in_subset)
      return QM_MVR_DIR_FLAT;                          // not in the high-vol subset this month

   int br = strategy_breadth;
   if(br < 1)
      br = 1;
   const int max_side = subset_size / 2;               // long & short sides must not overlap
   if(br > max_side)
      br = max_side;
   if(br < 1)
      return QM_MVR_DIR_FLAT;                          // subset too small to form both sides

   // Subset ranked by return DESC: strongest `br` -> long, weakest `br` -> short.
   int sub[];
   ArrayResize(sub, subset_size);
   for(int a = 0; a < subset_size; ++a)
      sub[a] = idx[a];
   for(int a = 1; a < subset_size; ++a)
     {
      const int    key = sub[a];
      const double kr  = m_ret[key];
      int b = a - 1;
      while(b >= 0 && m_ret[sub[b]] < kr)
        {
         sub[b + 1] = sub[b];
         b--;
        }
      sub[b + 1] = key;
     }

   for(int a = 0; a < br; ++a)
      if(sub[a] == host_idx)
         return QM_MVR_DIR_LONG;
   for(int a = 0; a < br; ++a)
      if(sub[subset_size - 1 - a] == host_idx)
         return QM_MVR_DIR_SHORT;
   return QM_MVR_DIR_FLAT;
  }

// Recompute the monthly decision exactly once per calendar month (restart-safe).
void QM_MVR_EnsureMonthlyDecision()
  {
   const int mkey = QM_CalendarPeriodKey(PERIOD_MN1);
   if(mkey <= 0)
      return;
   if(mkey == g_mvr_last_rebalance_key)
      return;
   g_mvr_desired_dir        = QM_MVR_ComputeDesiredDir();
   g_mvr_last_rebalance_key = mkey;
  }

// Dollar risk per leg (R): RISK_FIXED in backtest, RISK_PERCENT of equity live.
double QM_MVR_RiskDollarsPerLeg()
  {
   if(RISK_FIXED > 0.0)
      return RISK_FIXED;
   const double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq <= 0.0 || RISK_PERCENT <= 0.0)
      return 0.0;
   return (RISK_PERCENT / 100.0) * eq;
  }

// Basket-level aggregate emergency stop: close ALL legs owned by this ea_id when
// combined floating PnL <= -mult*R. Uses the framework's cross-magic primitives
// (QM_FrameworkOwnsMagicSymbol), so in live (multiple instances, one account) it
// aggregates every leg; in a single-symbol backtest only one leg exists so it
// degenerates to a per-leg backstop that (given 1R==3*ATR-stop sizing) does not
// fire spuriously.
void QM_MVR_EnforceBasketStop()
  {
   if(strategy_basket_stop_r_mult <= 0.0)
      return;
   if(!QM_BasketEquityStop_HasOwnedPositions())
      return;
   const double R = QM_MVR_RiskDollarsPerLeg();
   if(R <= 0.0)
      return;
   const double pnl    = QM_BasketEquityStop_FloatingPnL();
   const double thresh = -strategy_basket_stop_r_mult * R;
   if(pnl <= thresh)
      QM_BasketEquityStop_CloseAllOwned(QM_EXIT_KILLSWITCH);
  }

// Median modeled spread (points) over the lookback window for the host symbol.
int QM_MVR_MedianSpreadPoints()
  {
   const int lb = strategy_median_spread_lookback;
   if(lb <= 0)
      return 0;
   MqlRates rates[];
   // Host median-spread sample, evaluated at most once per new D1 bar on the rebalance path.
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, lb, rates); // perf-allowed
   if(copied <= 0)
      return 0;
   int spreads[];
   ArrayResize(spreads, copied);
   int m = 0;
   for(int i = 0; i < copied; ++i)
     {
      if(rates[i].spread < 0)
         continue;
      spreads[m] = (int)rates[i].spread;
      m++;
     }
   if(m <= 0)
      return 0;
   for(int i = 1; i < m; ++i)
     {
      const int key = spreads[i];
      int j = i - 1;
      while(j >= 0 && spreads[j] > key)
        {
         spreads[j + 1] = spreads[j];
         j--;
        }
      spreads[j + 1] = key;
     }
   return spreads[m / 2];
  }

// .DWX-safe spread gate: fail-open on zero/inverted modeled spread; only block a
// genuinely wide spread (> mult * median).
bool QM_MVR_SpreadAllowsEntry()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;                       // no quote -> not tradeable
   if(!(ask > bid))
      return true;                        // zero / inverted spread -> .DWX invariant, fail-open
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;
   const int cur = (int)MathRound((ask - bid) / point);
   if(cur <= 0)
      return true;                        // fail-open
   const int med = QM_MVR_MedianSpreadPoints();
   if(med <= 0)
      return true;                        // insufficient history -> fail-open (.DWX invariant)
   const int cap = (int)MathMax(1.0, MathRound(strategy_spread_mult * med));
   return (cur <= cap);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No-Trade Filter (time / spread / news): param sanity + host warmup guard.
// Cheap O(1) checks; blocks the whole tick early only before enough history
// exists (when there is no open position to manage anyway).
bool Strategy_NoTradeFilter()
  {
   if(strategy_lookback_d1 < 20 || strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   const int need  = MathMax(strategy_warmup_bars, strategy_lookback_d1 + strategy_skip_d1 + 2);
   const int avail = iBars(_Symbol, PERIOD_D1);   // perf-allowed: warmup-availability check only
   if(avail < need)
      return true;
   return false;
  }

// Trade Entry: open this month's leg per the cross-sectional decision.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(g_mvr_desired_dir != QM_MVR_DIR_LONG && g_mvr_desired_dir != QM_MVR_DIR_SHORT)
      return false;
   if(g_mvr_acted_key == g_mvr_last_rebalance_key)
      return false;                               // one entry per monthly rebalance (no re-entry after a stop)
   if(QM_MVR_HostDir() != QM_MVR_DIR_FLAT)
      return false;                               // already holding this month's leg
   if(!QM_MVR_SpreadAllowsEntry())
      return false;

   const bool   go_long = (g_mvr_desired_dir == QM_MVR_DIR_LONG);
   const double entry   = go_long ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                  : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   req.type               = go_long ? QM_BUY : QM_SELL;
   req.price              = 0.0;
   req.sl                 = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_sl_mult);
   req.tp                 = 0.0;
   req.reason             = go_long ? "QM5_12401_MVR_LONG" : "QM5_12401_MVR_SHORT";
   req.symbol_slot        = 0;
   req.expiration_seconds = 0;
   if(req.sl <= 0.0)
      return false;

   g_mvr_acted_key = g_mvr_last_rebalance_key;    // latch: one entry per month
   return true;
  }

// Trade Management: advance the monthly decision, enforce the basket aggregate
// stop. The per-leg emergency stop is the server-side SL (3*ATR) set at entry.
void Strategy_ManageOpenPosition()
  {
   QM_MVR_EnsureMonthlyDecision();
   QM_MVR_EnforceBasketStop();
  }

// Trade Close: non-overlapping rebalance — close the leg if this month's rank no
// longer selects this symbol in its current direction (flip or exit-to-flat).
bool Strategy_ExitSignal()
  {
   if(g_mvr_desired_dir == QM_MVR_DIR_HOLD)
      return false;                               // decision not ready -> hold
   const int cur = QM_MVR_HostDir();
   if(cur == QM_MVR_DIR_FLAT)
      return false;                               // nothing to close
   if(cur != g_mvr_desired_dir)
      return true;                                // flip or drop-out -> close
   return false;
  }

// News Filter Hook (callable for the Q09 News Impact phase). Defers to the
// central two-axis QM news gate in OnTick.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
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

   // Basket EA: opt into the multi-symbol guard and force the tester to load
   // full D1 history for every basket symbol (FW9) so foreign CopyClose reads
   // return real data instead of 0.
   g_mvr_basket_n = ArraySize(g_mvr_basket);
   QM_SymbolGuardInit(g_mvr_basket);
   const int warmup = MathMax(strategy_warmup_bars,
                              strategy_lookback_d1 + strategy_skip_d1 + strategy_median_spread_lookback + 5);
   QM_BasketWarmupHistory(g_mvr_basket, PERIOD_D1, warmup);

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
   // Q08 evidence lifecycle: sample floating P&L before any per-tick guard can
   // return.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Management, stop enforcement and rule-based exits keep running through news
   // windows — the news gate below blocks NEW entries only.
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

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
     }
  }

void OnTimer() { QM_FrameworkOnTimer(); }

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
