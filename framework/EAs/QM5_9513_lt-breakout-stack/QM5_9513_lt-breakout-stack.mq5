#property strict
#property version   "5.0"
#property description "QM5_9513 Leveraged Trading Multi-Horizon Breakout Stack"
// Strategy Card: QM5_9513 (lt-breakout-stack), G0 APPROVED 2026-05-19.
// Source: Robert Carver, Leveraged Trading, Harriman House 2019, ISBN 9780857197214.
// Chapter 8 / Appendix C: multi-horizon rolling breakout forecast.

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9513;
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
// Card: lookback horizons N = {10, 20, 40, 80, 160, 320} days
// Source scalars from official Leveraged Trading spreadsheet (Appendix C)
input double strategy_scalar_10         = 28.6;   // Scalar for N=10 horizon
input double strategy_scalar_20         = 31.6;   // Scalar for N=20 horizon
input double strategy_scalar_40         = 32.7;   // Scalar for N=40 horizon
input double strategy_scalar_80         = 33.5;   // Scalar for N=80 horizon
input double strategy_scalar_160        = 33.5;   // Scalar for N=160 horizon
input double strategy_scalar_320        = 33.5;   // Scalar for N=320 horizon
// Entry/exit thresholds (Card §Entry / §Exit)
input double strategy_entry_threshold   = 2.0;    // Long if forecast>+entry_threshold; Short if <-entry_threshold
input double strategy_exit_threshold    = 0.0;    // Close long when forecast<=0; close short when forecast>=0
// ATR stop (Card §Stop Loss: 2.5 * ATR(20, D1))
input int    strategy_atr_period        = 20;     // ATR period for hard stop
input double strategy_atr_stop_mult     = 2.5;    // ATR multiplier for emergency stop
// Spread filter (Card §Filters: skip if spread > 2 * MedianSpread(20D))
input int    strategy_spread_lookback   = 20;     // Days for median spread calculation
input double strategy_spread_cap_mult   = 2.0;    // Max spread = mult * median spread
// Minimum valid horizons required before trading
input int    strategy_min_valid_horizons = 3;     // Card: require at least 3 valid horizons

// =============================================================================
// Internal state
// =============================================================================
static double g_spread_history[20];   // Ring buffer for spread in points
static int    g_spread_idx = 0;
static int    g_spread_count = 0;

// =============================================================================
// Helpers
// =============================================================================

// Compute the combined breakout forecast from 6 horizons.
// Returns DBL_MAX if fewer than min_valid_horizons are valid.
double ComputeBreakoutForecast()
  {
   const int lookbacks[6] = {10, 20, 40, 80, 160, 320};
   const double scalars[6] = {strategy_scalar_10, strategy_scalar_20, strategy_scalar_40,
                              strategy_scalar_80, strategy_scalar_160, strategy_scalar_320};

   // Need at least 320 bars of D1 history
   const int total_bars = Bars(_Symbol, PERIOD_D1); // perf-allowed — no QM_* for bar count; runs once per new D1 bar
   if(total_bars < 321)
      return DBL_MAX;

   // Get the most recent close (bar index 1 = the last CLOSED D1 bar)
   const double close_now = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed — rolling N-bar history requires direct iClose; gated by QM_IsNewBar
   if(close_now <= 0.0)
      return DBL_MAX;

   double forecast_sum = 0.0;
   int    valid_count  = 0;

   for(int k = 0; k < 6; ++k)
     {
      const int N = lookbacks[k];
      if(total_bars < N + 1)
         continue; // Not enough bars for this horizon

      // Compute rolling high/low over last N closed bars (bars 1..N)
      double roll_max = -DBL_MAX;
      double roll_min =  DBL_MAX;
      for(int i = 1; i <= N; ++i)
        {
         const double c = iClose(_Symbol, PERIOD_D1, i); // perf-allowed — rolling N-bar history requires direct iClose; gated by QM_IsNewBar
         if(c <= 0.0)
            continue;
         if(c > roll_max)
            roll_max = c;
         if(c < roll_min)
            roll_min = c;
        }

      // Skip degenerate horizon (Card §Filters: skip if roll_max == roll_min)
      if(roll_max <= roll_min || roll_max <= 0.0)
         continue;

      const double roll_avg     = (roll_max + roll_min) / 2.0;
      const double roll_range   = roll_max - roll_min;
      const double scaled_price = (close_now - roll_avg) / roll_range;
      double forecast_N         = scaled_price * scalars[k];

      // Clamp to [-20, +20] per card formula
      if(forecast_N >  20.0) forecast_N =  20.0;
      if(forecast_N < -20.0) forecast_N = -20.0;

      forecast_sum += forecast_N;
      valid_count++;
     }

   // Card §Filters: require at least strategy_min_valid_horizons
   if(valid_count < strategy_min_valid_horizons)
      return DBL_MAX;

   return forecast_sum / (double)valid_count;
  }

// Update rolling spread tracker on each new D1 bar
void UpdateSpreadHistory()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return;
   const double spread_pts = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   g_spread_history[g_spread_idx] = spread_pts;
   g_spread_idx = (g_spread_idx + 1) % strategy_spread_lookback;
   if(g_spread_count < strategy_spread_lookback)
      g_spread_count++;
  }

// Compute median spread from ring buffer (simple sort-and-pick)
double MedianSpread()
  {
   if(g_spread_count < 1)
      return 0.0;
   double tmp[20];
   int n = g_spread_count;
   for(int i = 0; i < n; ++i)
      tmp[i] = g_spread_history[i];
   // Bubble sort (small array, O(n^2) fine)
   for(int i = 0; i < n - 1; ++i)
      for(int j = i + 1; j < n; ++j)
         if(tmp[j] < tmp[i]) { double t = tmp[i]; tmp[i] = tmp[j]; tmp[j] = t; }
   return (n % 2 == 0) ? (tmp[n/2 - 1] + tmp[n/2]) / 2.0 : tmp[n/2];
  }

// =============================================================================
// Strategy hooks
// =============================================================================

// Strategy_NoTradeFilter — cheap O(1) checks per tick
bool Strategy_NoTradeFilter()
  {
   // Spread cap filter (Card §Filters)
   if(g_spread_count >= 5)
     {
      const double cur_spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      const double med        = MedianSpread();
      if(med > 0.0 && cur_spread > strategy_spread_cap_mult * med)
         return true; // block trading — spread too wide
     }
   return false;
  }

// Strategy_EntrySignal — called on each new D1 closed bar
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type           = QM_BUY;
   req.price          = 0.0;
   req.sl             = 0.0;
   req.tp             = 0.0;
   req.reason         = "";
   req.symbol_slot    = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // Update spread tracking once per new bar
   UpdateSpreadHistory();

   // Check if we already have an open position for this magic — if so, skip entry
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) == magic &&
         PositionGetString(POSITION_SYMBOL) == _Symbol)
         return false; // one position per magic
     }

   const double forecast = ComputeBreakoutForecast();
   if(forecast == DBL_MAX)
      return false; // Insufficient data or valid horizons

   const double atr_val = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_val <= 0.0)
      return false;

   const double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   // Card §Entry: LONG if combined_forecast > +entry_threshold
   if(forecast > strategy_entry_threshold)
     {
      req.type   = QM_BUY;
      req.price  = ask;
      req.sl     = ask - strategy_atr_stop_mult * atr_val;
      req.tp     = 0.0; // No fixed TP — exits via forecast signal
      req.reason = "LT_BREAKOUT_LONG";
      return true;
     }

   // Card §Entry: SHORT if combined_forecast < -entry_threshold
   if(forecast < -strategy_entry_threshold)
     {
      req.type   = QM_SELL;
      req.price  = bid;
      req.sl     = bid + strategy_atr_stop_mult * atr_val;
      req.tp     = 0.0; // No fixed TP — exits via forecast signal
      req.reason = "LT_BREAKOUT_SHORT";
      return true;
     }

   return false;
  }

// Strategy_ManageOpenPosition — adjust emergency hard stop only (no trail, no BE)
void Strategy_ManageOpenPosition()
  {
   // Card §Stop Loss: 2.5 * ATR(20, D1) hard stop — maintained dynamically
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      // Use framework ATR trail at the hard-stop multiplier (no profit lock)
      QM_TM_TrailATR(ticket, strategy_atr_period, strategy_atr_stop_mult);
     }
  }

// Strategy_ExitSignal — close on forecast reversal (Card §Exit)
bool Strategy_ExitSignal()
  {
   // Only evaluate on new bar (called within the new-bar gate in OnTick)
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double forecast = ComputeBreakoutForecast();
      if(forecast == DBL_MAX)
         return false; // No data — keep position

      // Card §Exit: Close LONG when combined_forecast <= 0
      if(ptype == POSITION_TYPE_BUY && forecast <= strategy_exit_threshold)
         return true;
      // Card §Exit: Close SHORT when combined_forecast >= 0
      if(ptype == POSITION_TYPE_SELL && forecast >= -strategy_exit_threshold)
         return true;
     }
   return false;
  }

// Strategy_NewsFilterHook — defer to framework
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// =============================================================================
// Framework wiring
// =============================================================================

int OnInit()
  {
   // Zero-init spread ring buffer
   ArrayInitialize(g_spread_history, 0.0);
   g_spread_idx   = 0;
   g_spread_count = 0;

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_9513\",\"ea\":\"lt-breakout-stack\"}");
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

   // Per-tick: manage open positions (dynamic hard stop)
   Strategy_ManageOpenPosition();

   // Gate remaining logic to new closed D1 bar
   if(!QM_IsNewBar(_Symbol, PERIOD_D1))
      return;

   QM_EquityStreamOnNewBar();

   // Per-closed-bar: check exit signal
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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
      return; // Don't re-enter same bar after exit
     }

   // Per-closed-bar: entry
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
