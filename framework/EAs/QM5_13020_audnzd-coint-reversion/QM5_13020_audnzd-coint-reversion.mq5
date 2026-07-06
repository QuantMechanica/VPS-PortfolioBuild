#property strict
#property version   "5.0"
#property description "QM5_13020 AUDNZD D1 Cointegration Reversion"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_13020 - AUDNZD D1 Cointegration Reversion
// -----------------------------------------------------------------------------
// Card: QM-EDGELAB-FXCOINT-2026-06-09_AUDNZD (single-symbol AUDNZD.DWX cross,
// D1). z = (log_close - SMA(sma_lookback) of log_close) /
// stdev(stdev_lookback) of log_close. Entry at +/-entry_z, exit at zero-cross
// (deadband exit_z), ATR hard stop at entry, max-hold-days time stop.
// Log-price mean/stdev are bespoke (QM_SMA/QM_StdDev only read raw price), so
// this file reads iClose directly under a `// perf-allowed` note; the loop is
// bounded (<=140 iterations) and only runs once per closed D1 bar, gated by
// the framework's QM_IsNewBar() check before Strategy_EntrySignal fires.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 13020;
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
input int    strategy_sma_lookback_d1     = 100;  // Card Entry: SMA lookback of log close (slow mean).
input int    strategy_stdev_lookback_d1   = 20;   // Card Entry: stdev lookback of log close (fast dispersion).
input double strategy_entry_z             = 2.0;  // Card Entry: +/- z-band that triggers a new position.
input double strategy_exit_z              = 0.0;  // Card Exit: zero-cross deadband (long>=+val, short<=-val).
input int    strategy_atr_period          = 14;   // Card Exit: ATR period for the hard stop.
input double strategy_atr_sl_mult         = 2.5;  // Card Exit: ATR multiple for the hard stop distance.
input int    strategy_max_hold_days       = 30;   // Card Exit: time stop, D1 bars since entry.
input int    strategy_max_spread_points   = 80;   // Card Filters: skip entries above this spread.

double   g_z_cache       = 0.0;
bool     g_z_cache_valid = false;

// Cointegration z-score needs LOG price; QM_SMA/QM_StdDev only operate on
// raw price. Bounded single-bar read, called only from the once-per-closed-
// bar cache refresh below.
double Strategy_LogClose(const int shift)
  {
   const double c = iClose(_Symbol, PERIOD_D1, shift); // perf-allowed: bespoke log-price read for the cointegration z-score, gated to once/closed-bar via Strategy_RefreshZCache.
   if(c <= 0.0)
      return 0.0;
   return MathLog(c);
  }

bool Strategy_RollingLogMean(const int period, double &mean_out)
  {
   mean_out = 0.0;
   if(period < 2)
      return false;

   double sum = 0.0;
   for(int i = 1; i <= period; ++i)
     {
      const double lc = Strategy_LogClose(i);
      if(lc == 0.0)
         return false;
      sum += lc;
     }
   mean_out = sum / (double)period;
   return true;
  }

bool Strategy_RollingLogStdDev(const int period, double &stdev_out)
  {
   stdev_out = 0.0;
   double mean = 0.0;
   if(!Strategy_RollingLogMean(period, mean))
      return false;

   double sumsq = 0.0;
   for(int i = 1; i <= period; ++i)
     {
      const double lc = Strategy_LogClose(i);
      if(lc == 0.0)
         return false;
      const double d = lc - mean;
      sumsq += d * d;
     }
   stdev_out = MathSqrt(sumsq / (double)period);
   return MathIsValidNumber(stdev_out);
  }

bool Strategy_ComputeZ(double &z_out)
  {
   z_out = 0.0;
   if(strategy_sma_lookback_d1 < 2 || strategy_stdev_lookback_d1 < 2)
      return false;

   const double lc0 = Strategy_LogClose(1);
   if(lc0 == 0.0)
      return false;

   double sma_log = 0.0;
   if(!Strategy_RollingLogMean(strategy_sma_lookback_d1, sma_log))
      return false;

   double stdev_log = 0.0;
   if(!Strategy_RollingLogStdDev(strategy_stdev_lookback_d1, stdev_log))
      return false;
   if(stdev_log <= 0.0)
      return false;

   z_out = (lc0 - sma_log) / stdev_log;
   return MathIsValidNumber(z_out);
  }

// Refreshed once per closed D1 bar (called from Strategy_EntrySignal, which
// the framework only invokes after QM_IsNewBar() == true). Strategy_ExitSignal
// reads this cache every tick instead of recomputing the rolling stats.
void Strategy_RefreshZCache()
  {
   double z = 0.0;
   g_z_cache_valid = Strategy_ComputeZ(z);
   g_z_cache = g_z_cache_valid ? z : 0.0;
  }

bool Strategy_GetOpenPosition(ulong &ticket_out, ENUM_POSITION_TYPE &type_out, datetime &open_time_out)
  {
   ticket_out = 0;
   type_out = POSITION_TYPE_BUY;
   open_time_out = 0;

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

      ticket_out = ticket;
      type_out = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time_out = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

// No Trade Filter (time, spread, news).
bool Strategy_NoTradeFilter()
  {
   if(_Symbol != "AUDNZD.DWX" || _Period != PERIOD_D1)
      return true;
   if(strategy_sma_lookback_d1 < 2 || strategy_stdev_lookback_d1 < 2)
      return true;
   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   return false;
  }

// Trade Entry.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // Refresh the shared z cache first so Strategy_ExitSignal (called every
   // tick) always has today's value, even when a position is already open
   // and no new entry can fire below.
   Strategy_RefreshZCache();
   if(!g_z_cache_valid)
      return false;

   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   if(strategy_max_spread_points > 0)
     {
      // Card Risk & Filters: skip entries when spread exceeds the cap. .DWX
      // symbols quote 0 spread in the tester — only the upper bound is
      // checked, never a "spread <= 0 reject" (fail-closed-on-zero class).
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return false;
     }

   int direction = 0;
   if(g_z_cache <= -strategy_entry_z)
      direction = 1;
   else if(g_z_cache >= strategy_entry_z)
      direction = -1;
   else
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.reason = (direction > 0) ? "QM5_13020_LONG_ZSCORE_REVERSION" : "QM5_13020_SHORT_ZSCORE_REVERSION";
   return true;
  }

// Trade Management.
void Strategy_ManageOpenPosition()
  {
   // Card Trade Management Rules: symmetric long/short, no pyramiding,
   // gridding, martingale, partial close, or trailing stop. Exit is handled
   // entirely by the ATR hard stop (broker-side SL) and Strategy_ExitSignal.
  }

// Trade Close.
bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   datetime open_time = 0;
   if(!Strategy_GetOpenPosition(ticket, ptype, open_time))
      return false;

   if(strategy_max_hold_days > 0 && open_time > 0)
     {
      // perf-allowed: time-stop bar count from the position's own open time
      // (not a per-EA new-bar gate); bounded single lookup.
      const int bars_held = iBarShift(_Symbol, PERIOD_D1, open_time, false);
      if(bars_held >= strategy_max_hold_days)
         return true;
     }

   if(!g_z_cache_valid)
      return false;

   // Card Exit & Stops: mean exit when z crosses 0 (deadband = strategy_exit_z).
   if(ptype == POSITION_TYPE_BUY && g_z_cache >= strategy_exit_z)
      return true;
   if(ptype == POSITION_TYPE_SELL && g_z_cache <= -strategy_exit_z)
      return true;

   return false;
  }

// News Filter Hook (callable for P8 News Impact phase).
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade2 / QM_NewsAllowsTrade
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13020\",\"ea\":\"audnzd-coint-reversion\"}");
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
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: trade management can adjust SL/TP on open positions.
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. time stop). Separate from SL/TP.
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

   // News blackout gates NEW entries only (below); management/exits above keep
   // running through news windows (2026-07-02 audit finding, dc418a720).
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
