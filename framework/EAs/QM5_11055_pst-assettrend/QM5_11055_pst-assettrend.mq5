#property strict
#property version   "5.0"
#property description "QM5_11055 pst-assettrend — pysystemtrade asset-class EWMAC trend (D1, basket)"

#include <QM/QM_Common.mqh>
#include <QM/QM_Indicators.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11055 pst-assettrend
// -----------------------------------------------------------------------------
// Source: Rob Carver / pysystemtrade rob_system asset-class trend rules
// (config.yaml assettrend2..64 + rawdata.normalised_price_for_asset_class),
// source_id 352af9de. Card: artifacts/cards_approved/QM5_11055_pst-assettrend.md
// (g0_status APPROVED).
//
// BASKET EA. Instead of trending the traded symbol directly, each host symbol
// trends the median volatility-normalised cumulative return series of the
// symbol's ASSET CLASS (forex / index / metal). The same combined forecast is
// applied to every member of that class; the EA runs per host symbol and trades
// the host long/short from the class forecast.
//
// Mechanics (all on CLOSED D1 bars, advanced once per new D1 bar):
//   Class norm price : for each class member, daily_return / robust_daily_vol.
//                      Cross-sectional MEDIAN across members each day. Cumulate
//                      the median into asset_class_norm_price (a synthetic series).
//   EWMAC components : for Lfast in {2,4,8,16,32,64}, Lslow = 4*Lfast,
//                      raw = (EMA(price,Lfast)-EMA(price,Lslow))
//                            / robust_vol(diff(price),35);
//                      forecast = raw * scalar[Lfast]; cap to [-20,+20].
//   Combined         : equal-weight mean of the six capped components.
//   Entry            : long  when combined >= +entry_threshold (default +5).
//                      short when combined <= -entry_threshold.
//   Exit             : close long  when combined <= +exit_buffer (default +1).
//                      close short when combined >= -exit_buffer.
//   Emergency stop   : stop_atr_mult * ATR(20, D1) from entry (bounds MT5
//                      worst-case; primary close is the signal reversal).
//   Filters          : require >= min_class_members active members; >= 320 D1
//                      warmup bars; skip new entries on a genuinely wide spread.
//
// Only the 5 Strategy_* hooks + the OnInit basket wiring are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11055;
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
input double strategy_entry_threshold   = 5.0;    // |combined| to ENTER (P3 sweep {3,5,8})
input double strategy_exit_buffer       = 1.0;    // |combined| to EXIT  (P3 sweep {0,1,2})
input int    strategy_min_class_members = 3;      // min active class members (P3 sweep {3,5})
input int    strategy_vol_lookback      = 35;     // robust-vol lookback (days)
input int    strategy_atr_period        = 20;     // emergency-stop ATR period (D1)
input double strategy_stop_atr_mult     = 3.0;    // emergency stop = mult * ATR (P3 {2.5,3.0,3.5})
input int    strategy_min_d1_bars       = 320;    // min D1 warmup bars per member
input int    strategy_series_window     = 400;    // synthetic-series reconstruction window (days)
input double strategy_spread_pct_of_stop = 20.0;  // skip if host spread > this % of stop distance

// -----------------------------------------------------------------------------
// Asset-class membership model. Members are the DWX-matrix symbols sharing the
// host's asset class. Class series uses the MEDIAN vol-normalised return across
// these members each day (Carver normalised_price_for_asset_class).
// -----------------------------------------------------------------------------
#define QM_MAX_MEMBERS 32
#define QM_HBUF        700   // max closes per member (series_window + vol_lookback + slack)

string g_member[QM_MAX_MEMBERS];   // class-member ".DWX" symbols
int    g_nmember = 0;              // number of class members

// Cached forecast state, advanced once per closed D1 bar.
double g_combined   = 0.0;         // current combined forecast (mean of 6 capped EWMAC)
bool   g_ready      = false;       // true when the forecast is valid this bar

// The six EWMAC horizons and their source forecast scalars (config.yaml).
const int    QM_NH = 6;
int    g_lfast[6]  = { 2,        4,        8,        16,       32,       64       };
double g_scalar[6] = { 10.846520, 7.572335, 5.190471, 3.549453, 2.344923, 1.546514 };

// Forex majors/minors present in dwx_symbol_matrix.csv (28 pairs).
void QM_BuildForexClass()
  {
   string fx[] =
     {
      "EURUSD.DWX","GBPUSD.DWX","AUDUSD.DWX","NZDUSD.DWX",
      "USDJPY.DWX","USDCHF.DWX","USDCAD.DWX",
      "EURGBP.DWX","EURJPY.DWX","EURCHF.DWX","EURAUD.DWX","EURCAD.DWX","EURNZD.DWX",
      "GBPJPY.DWX","GBPCHF.DWX","GBPAUD.DWX","GBPCAD.DWX","GBPNZD.DWX",
      "AUDJPY.DWX","AUDCHF.DWX","AUDCAD.DWX","AUDNZD.DWX",
      "NZDJPY.DWX","NZDCHF.DWX","NZDCAD.DWX",
      "CADJPY.DWX","CADCHF.DWX","CHFJPY.DWX"
     };
   g_nmember = ArraySize(fx);
   if(g_nmember > QM_MAX_MEMBERS) g_nmember = QM_MAX_MEMBERS;
   for(int i = 0; i < g_nmember; ++i) g_member[i] = fx[i];
  }

// Equity-index class (matrix-verified; SP500 backtest-only but valid here).
void QM_BuildIndexClass()
  {
   string ix[] = { "NDX.DWX","WS30.DWX","GDAXI.DWX","UK100.DWX","SP500.DWX" };
   g_nmember = ArraySize(ix);
   for(int i = 0; i < g_nmember; ++i) g_member[i] = ix[i];
  }

// Metals/commodities class (matrix-verified).
void QM_BuildCommodityClass()
  {
   string cm[] = { "XAUUSD.DWX","XAGUSD.DWX","XTIUSD.DWX","XNGUSD.DWX" };
   g_nmember = ArraySize(cm);
   for(int i = 0; i < g_nmember; ++i) g_member[i] = cm[i];
  }

// Resolve the host symbol's asset class and populate the member list.
void QM_BuildClassForHost()
  {
   g_nmember = 0;
   const string s = _Symbol;
   // Index hosts.
   if(s == "NDX.DWX" || s == "WS30.DWX" || s == "GDAXI.DWX" ||
      s == "UK100.DWX" || s == "SP500.DWX")
     { QM_BuildIndexClass(); return; }
   // Commodity / metal hosts.
   if(s == "XAUUSD.DWX" || s == "XAGUSD.DWX" || s == "XTIUSD.DWX" || s == "XNGUSD.DWX")
     { QM_BuildCommodityClass(); return; }
   // Default: forex class (host is a 6-char FX pair).
   QM_BuildForexClass();
  }

void QM_BuildUniverse(string &universe[])
  {
   ArrayResize(universe, g_nmember + 1);
   universe[0] = _Symbol;
   int n = 1;
   for(int i = 0; i < g_nmember; ++i)
     {
      bool dup = false;
      for(int j = 0; j < n; ++j)
         if(universe[j] == g_member[i]) { dup = true; break; }
      if(!dup) { universe[n] = g_member[i]; ++n; }
     }
   ArrayResize(universe, n);
  }

// Robust (exponentially-weighted-free) volatility: simple std-dev of the last
// `len` values of `src` ending at index `end` (inclusive), Carver robust_vol
// floor applied. Returns a strictly positive value or 0.0 if not computable.
double QM_RobustStd(const double &src[], const int end, const int len)
  {
   if(len <= 1 || end < len - 1) return 0.0;
   double sum = 0.0;
   int cnt = 0;
   for(int k = end - len + 1; k <= end; ++k)
     { sum += src[k]; ++cnt; }
   if(cnt <= 1) return 0.0;
   const double mean = sum / cnt;
   double var = 0.0;
   for(int k = end - len + 1; k <= end; ++k)
     { const double d = src[k] - mean; var += d * d; }
   var /= (cnt - 1);
   if(var <= 0.0) return 0.0;
   return MathSqrt(var);
  }

// Standard EMA of the last value of `src` over `period`, computed forward from
// the start of the array (full reconstruction). Returns EMA at index `end`.
double QM_EmaAt(const double &src[], const int end, const int period)
  {
   if(period <= 0 || end < 0) return 0.0;
   const double alpha = 2.0 / (period + 1.0);
   double ema = src[0];
   for(int i = 1; i <= end; ++i)
      ema = alpha * src[i] + (1.0 - alpha) * ema;
   return ema;
  }

// -----------------------------------------------------------------------------
// Forecast computation — advanced ONCE per closed D1 bar. Reconstructs the
// asset-class normalised price over the last `series_window` D1 bars, then the
// six EWMAC components on that synthetic series.
// -----------------------------------------------------------------------------
void QM_AdvanceForecast()
  {
   g_ready = false;
   g_combined = 0.0;

   int W = strategy_series_window;              // synthetic-series length (days)
   if(W < 80) return;
   // Bound the synthetic window so fixed history buffers never overflow.
   const int volL0 = strategy_vol_lookback;
   if(W + volL0 + 1 > QM_HBUF) W = QM_HBUF - volL0 - 1;

   // Per-member close history: W + vol_lookback + 1 closed daily closes so the
   // trailing vol window is available even for the earliest synthetic day.
   const int volL = strategy_vol_lookback;

   // 1) Read each member's daily close history ONCE, derive its daily-return
   //    series, then form the cross-sectional MEDIAN vol-normalised return per
   //    day and cumulate into the synthetic price. Reading each member's closes
   //    once (need closes) keeps this O((W+volL)*members) per new D1 bar.
   //
   //    Day index d runs 0..W-1; day d uses D1 shift (W-d) for "now". We read
   //    closes at shifts 1..(W+volL+1) so the trailing vol window is available
   //    for the earliest synthetic day too.
   const int H = W + volL + 1;                  // number of closes per member

   static double mret[QM_MAX_MEMBERS][QM_HBUF]; // [member][hist] daily return, idx 0..H-1
   bool   mactive[QM_MAX_MEMBERS];

   int active_members = 0;
   for(int m = 0; m < g_nmember; ++m)
     {
      mactive[m] = false;
      const string sym = g_member[m];
      if(Bars(sym, PERIOD_D1) < strategy_min_d1_bars) continue;

      double prev_close = 0.0;
      bool ok = true;
      // idx i corresponds to D1 shift (H - i): i=0 -> oldest (shift H), i=H-1 -> shift 1.
      for(int i = 0; i < H; ++i)
        {
         const int shift = H - i;
         // perf-allowed: closed-bar foreign-symbol daily close reads (basket leg);
         // gated to once-per-new-D1-bar via QM_IsNewBar in OnTick.
         const double c = iClose(sym, PERIOD_D1, shift);
         if(c <= 0.0) { ok = false; break; }
         if(i == 0) mret[m][i] = 0.0;
         else       mret[m][i] = (c - prev_close) / prev_close;
         prev_close = c;
        }
      if(!ok) continue;

      mactive[m] = true;
      ++active_members;
     }

   if(active_members < strategy_min_class_members)
      return;                                   // not enough active members

   double norm_price[];
   ArrayResize(norm_price, W);
   double cum = 0.0;
   int active_at_last = 0;

   for(int d = 0; d < W; ++d)
     {
      // mclose index of "now" for synthetic day d. Day d=W-1 maps to shift 1
      // (newest). idx_now = (H-1) - (W-1 - d) = H - W + d.
      const int idx_now = H - W + d;            // >= volL+1 by construction

      double vals[QM_MAX_MEMBERS];
      int nv = 0;

      for(int m = 0; m < g_nmember; ++m)
        {
         if(!mactive[m]) continue;
         const double ret = mret[m][idx_now];

         // Robust daily vol over the trailing volL returns BEFORE idx_now.
         double rsum = 0.0; int rcnt = 0;
         for(int k = 1; k <= volL; ++k)
           {
            const int j = idx_now - k;
            if(j < 1) break;
            const double r = mret[m][j];
            rsum += r * r; ++rcnt;
           }
         if(rcnt < 2) continue;
         const double vol = MathSqrt(rsum / rcnt);
         if(vol <= 0.0) continue;

         vals[nv] = ret / vol;                  // vol-normalised return
         ++nv;
        }

      if(d == W - 1) active_at_last = nv;

      double med = 0.0;
      if(nv > 0)
        {
         double tmp[QM_MAX_MEMBERS];
         for(int t = 0; t < nv; ++t) tmp[t] = vals[t];
         for(int a = 1; a < nv; ++a)         // insertion sort (nv <= 32)
           {
            const double key = tmp[a];
            int b = a - 1;
            while(b >= 0 && tmp[b] > key) { tmp[b + 1] = tmp[b]; --b; }
            tmp[b + 1] = key;
           }
         if((nv & 1) == 1) med = tmp[nv / 2];
         else              med = 0.5 * (tmp[nv / 2 - 1] + tmp[nv / 2]);
        }

      cum += med;
      norm_price[d] = cum;
     }

   if(active_at_last < strategy_min_class_members)
      return;                                   // not enough active members on the last day

   // 2) diff series of the synthetic price (length W-1) for robust_vol.
   double diff[];
   ArrayResize(diff, W - 1);
   for(int i = 1; i < W; ++i) diff[i - 1] = norm_price[i] - norm_price[i - 1];

   const int last  = W - 1;                     // last index in norm_price
   const int dlast = (W - 1) - 1;               // last index in diff

   const double dvol = QM_RobustStd(diff, dlast, volL);
   if(dvol <= 0.0) return;

   // 3) six EWMAC components -> capped -> mean.
   double sumf = 0.0;
   for(int h = 0; h < QM_NH; ++h)
     {
      const int lf = g_lfast[h];
      const int ls = 4 * lf;
      if(last < ls) return;                     // not enough series for slow EMA
      const double ef = QM_EmaAt(norm_price, last, lf);
      const double es = QM_EmaAt(norm_price, last, ls);
      double raw = (ef - es) / dvol;
      double fc  = raw * g_scalar[h];
      if(fc >  20.0) fc =  20.0;
      if(fc < -20.0) fc = -20.0;
      sumf += fc;
     }

   g_combined = sumf / QM_NH;
   g_ready = true;
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
      return false;                             // no valid quote — defer

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;
   const double stop_distance = strategy_stop_atr_mult * atr;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;                              // genuinely wide spread — block
   return false;                                // zero/normal modeled spread — pass
  }

// D1 entry. Caller guarantees QM_IsNewBar()==true (one call per closed D1 bar).
// Forecast is advanced in OnTick before this call (g_combined / g_ready).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   if(!g_ready)
      return false;

   int dir = 0;
   if(g_combined >=  strategy_entry_threshold) dir = +1;
   if(g_combined <= -strategy_entry_threshold) dir = -1;
   if(dir == 0)
      return false;

   const QM_OrderType ot = (dir > 0) ? QM_BUY : QM_SELL;
   const double entry = (dir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                  : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // Emergency stop only (signal-reversal exit is the primary close).
   const double sl = QM_StopATR(_Symbol, ot, entry, strategy_atr_period, strategy_stop_atr_mult);
   if(sl <= 0.0)
      return false;

   req.type   = ot;
   req.price  = 0.0;        // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;        // no TP — exit on signal reversal
   req.reason = (dir > 0) ? "assettrend_long" : "assettrend_short";
   return true;
  }

// No active trade management beyond the static emergency ATR stop.
void Strategy_ManageOpenPosition()
  {
  }

// Signal-reversal exit: close long when combined <= +exit_buffer; close short
// when combined >= -exit_buffer. Uses the forecast cached this D1 bar.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;
   if(!g_ready)
      return false;

   int pos_dir = 0;
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
      pos_dir = (ptype == POSITION_TYPE_BUY) ? +1 : -1;
      break;
     }
   if(pos_dir == 0)
      return false;

   if(pos_dir > 0 && g_combined <=  strategy_exit_buffer) return true;
   if(pos_dir < 0 && g_combined >= -strategy_exit_buffer) return true;
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

   // Resolve the host's asset class + members, then BASKET-warm the D1 history
   // of the host + every member so foreign-symbol reads return real tester data.
   QM_BuildClassForHost();
   string universe[];
   QM_BuildUniverse(universe);
   QM_SymbolGuardInit(universe);
   const int warm = strategy_series_window + strategy_vol_lookback + 8;
   QM_BasketWarmupHistory(universe, PERIOD_D1, warm);

   QM_LogEvent(QM_INFO, "INIT_OK",
               StringFormat("{\"class_members\":%d,\"host\":\"%s\"}",
                            g_nmember, _Symbol));
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
   // refresh the class forecast BEFORE the rule-based exit so signal-reversal
   // exit sees the current forecast.
   const bool nb = QM_IsNewBar();
   if(nb)
      QM_AdvanceForecast();

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
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
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
