#property strict
#property version   "5.0"
#property description "ICT Silver Bullet Prior-Hour Sweep Reentry (QM5_9418)"

#include <QM/QM_Common.mqh>

// =============================================================================
// ICT Silver Bullet — Prior-Hour Sweep & Reentry
//
// Session windows (broker time = DXZ NY-Close, UTC+2 winter / UTC+3 summer):
//   Window A: 10:00 broker  =  03:00 ET (London pre-open)
//   Window B: 17:00 broker  =  10:00 ET (New York cash open)
//
// Per window:
//   1. Lock prior H1 high/low at window open.
//   2. On each new M5 bar, detect downside sweep: bar low < prev_h1_low - sweep_threshold.
//      Or upside sweep: bar high > prev_h1_high + sweep_threshold.
//   3. After sweep, detect reentry close back through swept level.
//   4. Optional FVG confluence: 3-candle gap on M5.
//   5. Enter market order. SL below/above sweep extreme. TP = opposite H1 range or 2R.
//   6. Time stop: close at window_start + strategy_time_stop_min (default 90 min).
//   7. One trade per window per symbol.
// =============================================================================

// ---- File-scope cached session state ----------------------------------------

static datetime g_window_start     = 0;
static double   g_prev_h1_high     = 0.0;
static double   g_prev_h1_low      = 0.0;
static bool     g_sweep_low_done   = false;
static bool     g_sweep_high_done  = false;
static double   g_sweep_low_ext    = 0.0;
static double   g_sweep_high_ext   = 0.0;
static bool     g_trade_taken      = false;

// -----------------------------------------------------------------------------

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9418;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
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
input double strategy_sweep_atr_mult    = 0.05;  // sweep threshold = mult * ATR(14,M5)
input double strategy_stop_atr_mult     = 0.10;  // SL buffer beyond sweep extreme
input double strategy_spread_atr_limit  = 0.20;  // skip entry if spread > mult * ATR(14,M5)
input int    strategy_atr_period        = 14;     // ATR period on M5
input bool   strategy_fvg_required      = true;   // require 3-candle FVG confluence
input bool   strategy_use_london_window = true;   // 10:00 broker (03:00 ET)
input bool   strategy_use_ny_window     = true;   // 17:00 broker (10:00 ET)
input int    strategy_entry_cutoff_min  = 45;     // disable new entries after N minutes
input int    strategy_time_stop_min     = 90;     // close position after N minutes

// ---- Advance cached session state on each new M5 bar -----------------------

void AdvanceState_OnNewBar()
  {
   datetime new_bar = iTime(_Symbol, PERIOD_M5, 0); // perf-allowed: window gate
   MqlDateTime dt;
   TimeToStruct(new_bar, dt);
   int h = dt.hour;
   int m = dt.min;

   bool is_window_a = strategy_use_london_window && (h == 10 && m == 0);
   bool is_window_b = strategy_use_ny_window     && (h == 17 && m == 0);

   if(is_window_a || is_window_b)
     {
      g_window_start    = new_bar;
      g_prev_h1_high    = iHigh(_Symbol, PERIOD_H1, 1); // perf-allowed: structural H1 reference
      g_prev_h1_low     = iLow (_Symbol, PERIOD_H1, 1); // perf-allowed: structural H1 reference
      g_sweep_low_done  = false;
      g_sweep_high_done = false;
      g_sweep_low_ext   = 0.0;
      g_sweep_high_ext  = 0.0;
      g_trade_taken     = false;
      return;
     }

   if(g_window_start == 0)                                              return;
   if(new_bar >= g_window_start + strategy_entry_cutoff_min * 60)      return;
   if(g_trade_taken)                                                    return;
   if(g_prev_h1_high <= g_prev_h1_low)                                 return;

   double atr = QM_ATR(_Symbol, PERIOD_M5, strategy_atr_period, 1);
   if(atr <= 0.0) return;

   double sweep_thresh = strategy_sweep_atr_mult * atr;
   double bar_low  = iLow (_Symbol, PERIOD_M5, 1); // perf-allowed: structural sweep detection
   double bar_high = iHigh(_Symbol, PERIOD_M5, 1); // perf-allowed: structural sweep detection

   if(!g_sweep_low_done  && bar_low  < g_prev_h1_low  - sweep_thresh)
     {
      g_sweep_low_done = true;
      g_sweep_low_ext  = bar_low;
     }
   if(!g_sweep_high_done && bar_high > g_prev_h1_high + sweep_thresh)
     {
      g_sweep_high_done = true;
      g_sweep_high_ext  = bar_high;
     }
  }

// ---- Strategy hooks --------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   AdvanceState_OnNewBar();

   if(g_window_start == 0)                                             return false;
   datetime now = TimeCurrent();
   if(now < g_window_start)                                            return false;
   if(now >= g_window_start + strategy_entry_cutoff_min * 60)         return false;
   if(g_trade_taken)                                                   return false;
   if(g_prev_h1_high <= g_prev_h1_low)                                return false;

   double atr = QM_ATR(_Symbol, PERIOD_M5, strategy_atr_period, 1);
   if(atr <= 0.0) return false;

   double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   if(spread > strategy_spread_atr_limit * atr) return false;
   double bar_close = iClose(_Symbol, PERIOD_M5, 1); // perf-allowed: structural reentry check
   if(bar_close <= 0.0) return false;

   bool long_entry  = g_sweep_low_done  && bar_close > g_prev_h1_low;
   bool short_entry = g_sweep_high_done && bar_close < g_prev_h1_high;
   if(!long_entry && !short_entry) return false;

   if(strategy_fvg_required)
     {
      double fvg_l1 = iLow (_Symbol, PERIOD_M5, 1); // perf-allowed: FVG check
      double fvg_h3 = iHigh(_Symbol, PERIOD_M5, 3); // perf-allowed: FVG check
      double fvg_h1 = iHigh(_Symbol, PERIOD_M5, 1); // perf-allowed: FVG check
      double fvg_l3 = iLow (_Symbol, PERIOD_M5, 3); // perf-allowed: FVG check

      bool bull_fvg = long_entry  && fvg_l1 > fvg_h3;
      bool bear_fvg = short_entry && fvg_h1 < fvg_l3;

      if(long_entry && !bull_fvg)
        {
         double fvg_l2 = iLow (_Symbol, PERIOD_M5, 2); // perf-allowed: FVG extended check
         double fvg_h4 = iHigh(_Symbol, PERIOD_M5, 4); // perf-allowed: FVG extended check
         bull_fvg = fvg_l2 > fvg_h4;
        }
      if(short_entry && !bear_fvg)
        {
         double fvg_h2 = iHigh(_Symbol, PERIOD_M5, 2); // perf-allowed: FVG extended check
         double fvg_l4 = iLow (_Symbol, PERIOD_M5, 4); // perf-allowed: FVG extended check
         bear_fvg = fvg_h2 < fvg_l4;
        }

      if(long_entry  && !bull_fvg) return false;
      if(short_entry && !bear_fvg) return false;
     }

   double stop_buf = strategy_stop_atr_mult * atr;
   double min_stop = MathMax(5.0 * _Point,
                             (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point);

   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(long_entry)
     {
      double ask      = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl_price = g_sweep_low_ext - stop_buf;
      if(ask - sl_price < min_stop) sl_price = ask - min_stop;

      double r        = ask - sl_price;
      double tp_range = g_prev_h1_high;
      double tp_2r    = ask + 2.0 * r;
      double tp_price = (tp_range > ask) ? MathMin(tp_range, tp_2r) : tp_2r;

      req.type   = QM_BUY;
      req.price  = ask;
      req.sl     = sl_price;
      req.tp     = tp_price;
      req.reason = "SILVER_BULLET_LONG";
     }
   else
     {
      double bid      = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl_price = g_sweep_high_ext + stop_buf;
      if(sl_price - bid < min_stop) sl_price = bid + min_stop;

      double r        = sl_price - bid;
      double tp_range = g_prev_h1_low;
      double tp_2r    = bid - 2.0 * r;
      double tp_price = (tp_range < bid) ? MathMax(tp_range, tp_2r) : tp_2r;

      req.type   = QM_SELL;
      req.price  = bid;
      req.sl     = sl_price;
      req.tp     = tp_price;
      req.reason = "SILVER_BULLET_SHORT";
     }

   g_trade_taken = true;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // No trailing stop per card — position managed by fixed SL/TP and time stop.
  }

bool Strategy_ExitSignal()
  {
   if(g_window_start == 0) return false;
   if(TimeCurrent() < g_window_start + (datetime)(strategy_time_stop_min * 60)) return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) == (long)magic) return true;
     }
   return false;
  }

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
