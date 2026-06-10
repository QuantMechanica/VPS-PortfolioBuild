#property strict
#property version   "5.0"
#property description "QM5_1088 Alpha Architect FAA RAVC Rotation"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_1088 — Alpha Architect FAA RAVC Rotation
//
// Monthly-cadence tactical-asset-allocation EA.
// One instance per universe symbol; each computes the full cross-asset rank
// on D1 bars and trades only its own _Symbol when it is in the top-N selection.
//
// Rebuild v2 (2026-06-10): changed timeframe from MN1 (untestable in MT5
// tester on DWX custom symbols) to D1 with 84-bar (~4-month) lookback.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 1088;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 0.33333333;

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
input int    strategy_lookback_bars       = 84;   // D1 bars for 4-month window (~4x21)
input int    strategy_top_n               = 3;    // max simultaneous holdings
input int    strategy_atr_period          = 14;   // ATR period for per-leg SL (D1 bars)
input double strategy_atr_sl_mult         = 4.0;  // ATR multiplier for per-leg SL
input int    strategy_rebalance_day_max   = 7;    // entry window: first N calendar days of new month

// ---------------------------------------------------------------------------
// Universe definition (7 DWX proxy assets per card R3)
// ---------------------------------------------------------------------------

const int STRATEGY_UNIVERSE_SIZE = 7;
string g_universe_symbols[7] =
  {
   "SP500.DWX", "NDX.DWX", "GDAXI.DWX", "XAUUSD.DWX",
   "XTIUSD.DWX", "EURUSD.DWX", "USDJPY.DWX"
  };
int g_universe_slots[7] = {0, 1, 2, 3, 4, 5, 6};

// ---------------------------------------------------------------------------
// Cached monthly selection state
// ---------------------------------------------------------------------------

bool g_selected[7]      = {false, false, false, false, false, false, false};
bool g_selection_ready  = false;
int  g_selection_key    = 0;  // year*100 + month when last computed

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
      if(g_universe_symbols[i] == _Symbol)
         return i;
   return -1;
  }

int Strategy_RebalanceKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 100 + dt.mon;
  }

// Entry allowed only in the first strategy_rebalance_day_max days of a month.
bool Strategy_RebalanceWindowOpen()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return (dt.day >= 1 && dt.day <= strategy_rebalance_day_max);
  }

// Single point for all cross-asset D1 price reads.
// The iClose call here is the ONLY raw series call in this EA — perf-allowed
// because: (1) it is bespoke cross-asset monthly-ranking math not covered by
// any QM_* helper, and (2) all callers are gated by the monthly-rebalance
// key so this path runs at most once per calendar month.
bool Strategy_CloseAt(const string symbol, const int shift, double &out_close)
  {
   out_close = iClose(symbol, PERIOD_D1, shift); // perf-allowed: bespoke cross-asset D1 rank, gated by monthly rebalance key
   return (out_close > 0.0);
  }

// 4-month relative momentum = close[1] / close[1 + lookback] - 1
bool Strategy_RelativeMomentum(const string symbol, double &out_momentum)
  {
   out_momentum = 0.0;
   if(strategy_lookback_bars < 1)
      return false;
   double c_now = 0.0, c_4m = 0.0;
   if(!Strategy_CloseAt(symbol, 1, c_now))
      return false;
   if(!Strategy_CloseAt(symbol, 1 + strategy_lookback_bars, c_4m))
      return false;
   if(c_4m <= 0.0)
      return false;
   out_momentum = (c_now / c_4m) - 1.0;
   return true;
  }

// Realized D1 volatility (std dev of log-returns) over strategy_lookback_bars
bool Strategy_RealizedVolatility(const string symbol, double &out_volatility)
  {
   out_volatility = 0.0;
   if(strategy_lookback_bars < 2)
      return false;
   double sum = 0.0, sum_sq = 0.0;
   int count = 0;
   for(int s = 1; s <= strategy_lookback_bars; ++s)
     {
      double c0 = 0.0, c1 = 0.0;
      if(!Strategy_CloseAt(symbol, s, c0) || !Strategy_CloseAt(symbol, s + 1, c1))
         return false;
      if(c1 <= 0.0)
         return false;
      const double r = MathLog(c0 / c1);
      sum += r;
      sum_sq += r * r;
      ++count;
     }
   if(count < 2)
      return false;
   const double mean = sum / count;
   out_volatility = MathSqrt(MathMax((sum_sq / count) - (mean * mean), 0.0));
   return true;
  }

// Pearson correlation between two symbols over strategy_lookback_bars D1 log-returns
bool Strategy_Correlation(const string sym_a, const string sym_b, double &out_corr)
  {
   out_corr = 0.0;
   if(strategy_lookback_bars < 2)
      return false;
   double sum_a = 0.0, sum_b = 0.0, sum_aa = 0.0, sum_bb = 0.0, sum_ab = 0.0;
   int count = 0;
   for(int s = 1; s <= strategy_lookback_bars; ++s)
     {
      double a0 = 0.0, a1 = 0.0, b0 = 0.0, b1 = 0.0;
      if(!Strategy_CloseAt(sym_a, s, a0) || !Strategy_CloseAt(sym_a, s + 1, a1))
         return false;
      if(!Strategy_CloseAt(sym_b, s, b0) || !Strategy_CloseAt(sym_b, s + 1, b1))
         return false;
      if(a1 <= 0.0 || b1 <= 0.0)
         return false;
      const double ra = MathLog(a0 / a1);
      const double rb = MathLog(b0 / b1);
      sum_a  += ra;  sum_b  += rb;
      sum_aa += ra * ra; sum_bb += rb * rb; sum_ab += ra * rb;
      ++count;
     }
   if(count < 2)
      return false;
   const double n    = (double)count;
   const double cov  = sum_ab - (sum_a * sum_b / n);
   const double va   = sum_aa - (sum_a * sum_a / n);
   const double vb   = sum_bb - (sum_b * sum_b / n);
   if(va <= 0.0 || vb <= 0.0)
      return false;
   out_corr = cov / MathSqrt(va * vb);
   return true;
  }

// Average pairwise correlation of universe[idx] with the remaining 6 members
bool Strategy_AverageCorrelation(const int idx, double &out_avg_corr)
  {
   out_avg_corr = 0.0;
   if(idx < 0 || idx >= STRATEGY_UNIVERSE_SIZE)
      return false;
   double sum = 0.0;
   int cnt = 0;
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
     {
      if(i == idx)
         continue;
      double corr = 0.0;
      if(!Strategy_Correlation(g_universe_symbols[idx], g_universe_symbols[i], corr))
         return false;
      sum += corr;
      ++cnt;
     }
   if(cnt <= 0)
      return false;
   out_avg_corr = sum / cnt;
   return true;
  }

// Rank where rank 1 = asset with the HIGHEST value (best momentum → highest)
int Strategy_RankHigherIsBetter(const double &values[], const int n, const int idx)
  {
   int rank = 1;
   for(int i = 0; i < n; ++i)
      if(values[i] > values[idx])
         ++rank;
   return rank;
  }

// Rank where rank 1 = asset with the LOWEST value (best vol/corr → lowest)
int Strategy_RankLowerIsBetter(const double &values[], const int n, const int idx)
  {
   int rank = 1;
   for(int i = 0; i < n; ++i)
      if(values[i] < values[idx])
         ++rank;
   return rank;
  }

void Strategy_ClearSelection()
  {
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
      g_selected[i] = false;
   g_selection_ready = false;
  }

// Compute and cache monthly selection.
// composite = rank_momentum(1.0) + rank_vol(0.5) + rank_corr(0.5); lower = better.
// Eligible = positive absolute momentum AND composite <= cutoff for top-N.
bool Strategy_RefreshSelection()
  {
   const int key = Strategy_RebalanceKey(TimeCurrent());
   if(g_selection_ready && g_selection_key == key)
      return true;

   Strategy_ClearSelection();

   double momentum[7], volatility[7], avg_corr[7], composite[7];

   // Phase 1: per-symbol momentum and volatility
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
     {
      if(!SymbolSelect(g_universe_symbols[i], true))
         return false;
      if(!Strategy_RelativeMomentum(g_universe_symbols[i], momentum[i]))
         return false;
      if(!Strategy_RealizedVolatility(g_universe_symbols[i], volatility[i]))
         return false;
     }

   // Phase 2: average pairwise correlation for each symbol
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
      if(!Strategy_AverageCorrelation(i, avg_corr[i]))
         return false;

   // Phase 3: composite rank score
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
     {
      const int mr = Strategy_RankHigherIsBetter(momentum,   STRATEGY_UNIVERSE_SIZE, i);
      const int vr = Strategy_RankLowerIsBetter(volatility,  STRATEGY_UNIVERSE_SIZE, i);
      const int cr = Strategy_RankLowerIsBetter(avg_corr,    STRATEGY_UNIVERSE_SIZE, i);
      composite[i] = (double)mr + 0.5 * (double)vr + 0.5 * (double)cr;
     }

   // Phase 4: find top-N cutoff score
   int top_n = strategy_top_n;
   if(top_n < 1)
      top_n = 1;
   if(top_n > STRATEGY_UNIVERSE_SIZE)
      top_n = STRATEGY_UNIVERSE_SIZE;

   double sorted[7];
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
      sorted[i] = composite[i];
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE - 1; ++i)
      for(int j = i + 1; j < STRATEGY_UNIVERSE_SIZE; ++j)
         if(sorted[j] < sorted[i])
           {
            const double tmp = sorted[i];
            sorted[i] = sorted[j];
            sorted[j] = tmp;
           }
   const double cutoff = sorted[top_n - 1];

   // Phase 5: mark selected (absolute momentum gate + composite cutoff)
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
      g_selected[i] = (momentum[i] > 0.0 && composite[i] <= cutoff);

   g_selection_key  = key;
   g_selection_ready = true;
   return true;
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;
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

// ---------------------------------------------------------------------------
// Framework hook implementations
// ---------------------------------------------------------------------------

// No Trade Filter (time, spread, news)
// Block if this instance's slot doesn't match its expected universe position.
bool Strategy_NoTradeFilter()
  {
   const int idx = Strategy_CurrentSymbolIndex();
   if(idx < 0)
      return true;
   if(qm_magic_slot_offset != g_universe_slots[idx])
      return true;
   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type               = QM_BUY;
   req.price              = 0.0;
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "QM5_1088_FAA_RAVC_TOP3_LONG";
   req.expiration_seconds = 0;

   const int idx = Strategy_CurrentSymbolIndex();
   if(idx < 0)
      return false;
   req.symbol_slot = g_universe_slots[idx];

   if(!Strategy_RebalanceWindowOpen())
      return false;
   if(!Strategy_RefreshSelection())
      return false;
   if(!g_selected[idx])
      return false;
   if(Strategy_HasOpenPosition())
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, QM_BUY, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0 || req.sl >= entry)
      return false;

   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Source exits through monthly rank rebalance (Strategy_ExitSignal).
   // Per-leg ATR stop placed at entry provides single-leg risk control.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   const int idx = Strategy_CurrentSymbolIndex();
   if(idx < 0)
      return false;
   if(!g_selection_ready)
      return false;
   if(!Strategy_HasOpenPosition())
      return false;
   return !g_selected[idx];
  }

// News Filter Hook (callable for P8 News Impact phase)
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// ---------------------------------------------------------------------------
// Framework wiring
// ---------------------------------------------------------------------------

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

   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
      SymbolSelect(g_universe_symbols[i], true);

   QM_LogEvent(QM_INFO, "INIT_OK", StringFormat(
      "{\"card\":\"QM5_1088\",\"ea\":\"aa-faa-ravc\",\"slot\":%d,\"symbol\":\"%s\",\"lookback_bars\":%d}",
      qm_magic_slot_offset,
      QM_LoggerEscapeJson(_Symbol),
      strategy_lookback_bars));
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
                        const MqlTradeRequest     &request,
                        const MqlTradeResult      &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
