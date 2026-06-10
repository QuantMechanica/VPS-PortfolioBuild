#property strict
#property version   "5.0"
#property description "QM5_9292 MQL5 DeMarker Envelope Squeeze (mql5-dem-env-squeeze)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9292 — DeMarker Envelope Squeeze
// Source: Stephen Njuki, MQL5 Articles Part 63 (ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb)
// Pattern 4: Envelope Squeeze + DeMarker Building Pressure — H4, FX+Gold
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 9292;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours               = 336;
input string qm_news_min_impact                    = "high";
input QM_NewsMode qm_news_mode_legacy              = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_env_period          = 14;    // Envelope SMA period
input double strategy_env_deviation       = 0.10;  // Envelope deviation (%)
input int    strategy_dem_period          = 14;    // DeMarker period
input double strategy_dem_zone_lo         = 0.40;  // DeMarker neutral zone lower bound
input double strategy_dem_zone_hi         = 0.60;  // DeMarker neutral zone upper bound
input int    strategy_env_median_bars     = 20;    // Width median filter lookback (bars)
input int    strategy_breakout_bars       = 3;     // Max bars to wait for breakout after setup
input int    strategy_max_hold_bars       = 10;    // Time exit: close after this many H4 bars
input int    strategy_swing_lookback      = 5;     // Bars for swing high/low SL anchor

// -----------------------------------------------------------------------------
// File-scope setup state
// -----------------------------------------------------------------------------
int  g_setup_dir   = 0;   // 0=none, 1=long-armed, -1=short-armed
int  g_setup_bars  = 0;   // remaining bars to check for breakout

// -----------------------------------------------------------------------------
// Pooled handle helpers for DeMarker and Envelopes (not in QM_Indicators.mqh)
// Use QM pool infrastructure to avoid file-scope handle variables.
// -----------------------------------------------------------------------------

int IndDeM(const string sym, const ENUM_TIMEFRAMES tf, const int period)
  {
   const string key = StringFormat("DEM|%s|%d|%d", sym, (int)tf, period);
   int h = QM_IndicatorsLookup(key);
   if(h != INVALID_HANDLE)
      return h;
   h = iDeMarker(sym, tf, period);
   return QM_IndicatorsRegister(key, h);
  }

double DeM(const int shift)
  {
   return QM_IndicatorReadBuffer(IndDeM(_Symbol, _Period, strategy_dem_period), 0, shift);
  }

int IndEnv(const string sym, const ENUM_TIMEFRAMES tf, const int period, const double dev)
  {
   const string key = StringFormat("ENV|%s|%d|%d|%.4f", sym, (int)tf, period, dev);
   int h = QM_IndicatorsLookup(key);
   if(h != INVALID_HANDLE)
      return h;
   // iEnvelopes: buffer 0 = upper, buffer 1 = lower
   h = iEnvelopes(sym, tf, period, 0, MODE_SMA, PRICE_CLOSE, dev);
   return QM_IndicatorsRegister(key, h);
  }

double EnvUpper(const int shift)
  {
   return QM_IndicatorReadBuffer(
      IndEnv(_Symbol, _Period, strategy_env_period, strategy_env_deviation), 0, shift);
  }

double EnvLower(const int shift)
  {
   return QM_IndicatorReadBuffer(
      IndEnv(_Symbol, _Period, strategy_env_period, strategy_env_deviation), 1, shift);
  }

double EnvMid(const int shift)
  {
   return (EnvUpper(shift) + EnvLower(shift)) / 2.0;
  }

// Compute 20-bar median of Envelope widths by reading indicator buffer shifts 1..N
// Called only inside QM_IsNewBar gate — runs once per closed bar.
double EnvWidthMedian()
  {
   const int n = strategy_env_median_bars;
   if(n <= 0)
      return 0.0;
   double widths[];
   ArrayResize(widths, n);
   for(int i = 1; i <= n; i++)
      widths[i - 1] = EnvUpper(i) - EnvLower(i);
   ArraySort(widths);
   if(n % 2 == 1)
      return widths[n / 2];
   return (widths[n / 2 - 1] + widths[n / 2]) / 2.0;
  }

// Returns true if the EA already has an open position on this symbol
bool HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

// Build and return a market entry request. SL = max/min(envelope band, swing structure).
bool BuildEntryReq(const int dir, QM_EntryRequest &req)
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double upper1 = EnvUpper(1);
   const double lower1 = EnvLower(1);
   if(upper1 <= 0.0 || lower1 <= 0.0)
      return false;

   double sl = 0.0;

   if(dir == 1)  // long
     {
      req.type = QM_BUY;
      req.price = ask;
      // SL = higher of lower_envelope or swing low (tighter, closer to price)
      const double env_sl   = lower1;
      const double swing_sl = QM_StopStructure(_Symbol, QM_BUY, ask, strategy_swing_lookback);
      sl = (swing_sl > 0.0) ? MathMax(env_sl, swing_sl) : env_sl;
     }
   else  // short
     {
      req.type = QM_SELL;
      req.price = bid;
      // SL = lower of upper_envelope or swing high (tighter, closer to price)
      const double env_sl   = upper1;
      const double swing_sl = QM_StopStructure(_Symbol, QM_SELL, bid, strategy_swing_lookback);
      sl = (swing_sl > 0.0) ? MathMin(env_sl, swing_sl) : env_sl;
     }

   if(sl <= 0.0)
      return false;

   req.sl    = sl;
   req.tp    = 0.0;   // no fixed TP; exit via signal or time stop
   req.reason = (dir == 1) ? "DEM_ENV_SQUEEZE_LONG" : "DEM_ENV_SQUEEZE_SHORT";
   req.symbol_slot       = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const double point    = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;
   const double sl_points = MathAbs(req.price - req.sl) / point;
   if(sl_points < 1.0)
      return false;

   req.sl = sl;
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // No new entry if position already open (one position per magic)
   if(HasOpenPosition())
     {
      g_setup_dir  = 0;
      g_setup_bars = 0;
      return false;
     }

   const double env_upper1 = EnvUpper(1);
   const double env_lower1 = EnvLower(1);
   const double env_upper2 = EnvUpper(2);
   const double env_lower2 = EnvLower(2);

   if(env_upper1 <= 0.0 || env_lower1 <= 0.0 || env_upper2 <= 0.0 || env_lower2 <= 0.0)
      return false;

   const double width1 = env_upper1 - env_lower1;
   const double width2 = env_upper2 - env_lower2;
   const double dem1   = DeM(1);
   const double dem2   = DeM(2);

   if(dem1 <= 0.0 || dem2 <= 0.0 || width1 <= 0.0 || width2 <= 0.0)
      return false;

   // --- Check existing armed setup for breakout ---
   if(g_setup_dir != 0)
     {
      const double close1 = iClose(_Symbol, _Period, 1);  // perf-allowed: closed-bar breakout confirm
      if(close1 <= 0.0)
        {
         g_setup_bars--;
         if(g_setup_bars <= 0)
            g_setup_dir = 0;
         return false;
        }

      bool breakout = false;
      if(g_setup_dir == 1  && close1 > env_upper1)
         breakout = true;
      if(g_setup_dir == -1 && close1 < env_lower1)
         breakout = true;

      g_setup_bars--;
      if(g_setup_bars <= 0)
         g_setup_dir = 0;

      if(breakout)
        {
         const int fire_dir = (g_setup_dir == 0) ? (close1 > env_upper1 ? 1 : -1) : g_setup_dir;
         // g_setup_dir may have just been zeroed; use breakout flag directly
         const int dir = (close1 > env_upper1) ? 1 : -1;
         g_setup_dir = 0;
         return BuildEntryReq(dir, req);
        }

      return false;
     }

   // --- No armed setup: check for new setup ---
   const double median_w = EnvWidthMedian();
   if(median_w <= 0.0)
      return false;

   // Squeeze filter: current width must be below 20-bar median
   if(width1 >= median_w)
      return false;

   // Width must be narrowing (current < previous)
   if(width1 >= width2)
      return false;

   // Long setup: prev DeM >= zone_lo AND curr DeM <= zone_hi AND DeM rising
   const bool long_setup = (dem2 >= strategy_dem_zone_lo &&
                             dem1 <= strategy_dem_zone_hi &&
                             dem1 > dem2);

   // Short setup: prev DeM <= zone_hi AND curr DeM >= zone_lo AND DeM falling
   const bool short_setup = (dem2 <= strategy_dem_zone_hi &&
                              dem1 >= strategy_dem_zone_lo &&
                              dem1 < dem2);

   if(!long_setup && !short_setup)
      return false;

   const int dir = long_setup ? 1 : -1;

   // Arm setup; breakout check starts on NEXT bar
   g_setup_dir  = dir;
   g_setup_bars = strategy_breakout_bars;

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // No trailing or partial-close logic; exits managed via ExitSignal and SL
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      // Time exit: close after strategy_max_hold_bars H4 bars
      const datetime pos_open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int bars_held = iBarShift(_Symbol, _Period, pos_open_time, false);  // perf-allowed: time-based exit bar count
      if(bars_held >= strategy_max_hold_bars)
         return true;

      // Only evaluate indicator-based exits on new bars (cheap guard)
      if(!QM_IsNewBar())
         return false;
      const double close1 = iClose(_Symbol, _Period, 1);  // perf-allowed: closed-bar exit eval
      if(close1 <= 0.0)
         return false;

      const double mid  = EnvMid(1);
      const double dem1 = DeM(1);
      const double dem2 = DeM(2);

      if(ptype == POSITION_TYPE_BUY)
        {
         // Close long if price returns below midline
         if(close1 < mid)
            return true;
         // Close long if DeMarker crosses below 0.50
         if(dem2 >= 0.50 && dem1 < 0.50)
            return true;
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         // Close short if price returns above midline
         if(close1 > mid)
            return true;
         // Close short if DeMarker crosses above 0.50
         if(dem2 <= 0.50 && dem1 > 0.50)
            return true;
        }

      return false;
     }
   return false;
  }

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

   g_setup_dir  = 0;
   g_setup_bars = 0;
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_9292\",\"slug\":\"mql5-dem-env-squeeze\"}");
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
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest entry_req;
   if(Strategy_EntrySignal(entry_req))
     {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(entry_req, out_ticket);
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
