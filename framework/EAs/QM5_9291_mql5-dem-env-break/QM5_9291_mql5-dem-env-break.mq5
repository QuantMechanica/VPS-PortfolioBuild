#property strict
#property version   "5.0"
#property description "QM5_9291 DeMarker Envelope Breakout (H4)"

#include <QM/QM_Common.mqh>

// ============================================================================
// QuantMechanica V5 — QM5_9291 mql5-dem-env-break
// Strategy Card: QM5_9291_mql5-dem-env-break, G0 APPROVED 2026-05-19.
// Edge: Two-bar envelope breakout with DeMarker extreme on H4.
//   Long when DeMarker >= 0.70 AND last two bars close above upper Envelope.
//   Short symmetric (DeMarker <= 0.30, closes below lower Envelope).
//   Envelope-width volatility filter (must exceed 20-bar median width).
//   Exit on midline return or DeMarker crossing 0.50.
// ============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                      = 9291;
input int    qm_magic_slot_offset          = 0;
input uint   qm_rng_seed                   = 42;

input group "Risk"
input double RISK_PERCENT                  = 0.0;
input double RISK_FIXED                    = 1000.0;
input double PORTFOLIO_WEIGHT              = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal      = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance    = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours                  = 336;
input string qm_news_min_impact                       = "high";
input QM_NewsMode qm_news_mode_legacy                 = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled       = true;
input int    qm_friday_close_hour_broker   = 21;

input group "Stress"
input double qm_stress_reject_probability  = 0.0;

input group "Strategy"
input int    strategy_dem_period           = 14;     // DeMarker averaging period
input double strategy_dem_ob_level         = 0.70;   // DeMarker overbought threshold (long entry)
input double strategy_dem_os_level         = 0.30;   // DeMarker oversold threshold (short entry)
input double strategy_dem_exit_level       = 0.50;   // DeMarker level triggering exit
input int    strategy_env_period           = 14;     // Envelopes MA period
input double strategy_env_deviation        = 0.100;  // Envelopes deviation (%)
input int    strategy_atr_period           = 14;     // ATR period for stop distance
input double strategy_atr_sl_mult          = 1.5;    // ATR multiplier for stop distance
input int    strategy_width_lookback       = 20;     // Bars for envelope-width median filter

// ============================================================================
// Cached per-bar state — advanced ONCE per new bar in AdvanceState_OnNewBar().
// All Strategy_ hooks read only from these cached values (O(1) per-tick path).
// ============================================================================

#define QM_DEM_ENV_WIDTH_HIST 20

double g_dem1        = 0.0;  // DeMarker value, last closed bar (shift=1)
double g_env_upper1  = 0.0;  // Envelope upper band, shift=1
double g_env_lower1  = 0.0;  // Envelope lower band, shift=1
double g_env_upper2  = 0.0;  // Envelope upper band, shift=2
double g_env_lower2  = 0.0;  // Envelope lower band, shift=2
double g_env_mid1    = 0.0;  // Envelope midline (upper+lower)/2, shift=1
double g_close1      = 0.0;  // Last closed bar close
double g_close2      = 0.0;  // Bar-before-last close
double g_width_hist[QM_DEM_ENV_WIDTH_HIST]; // ring buffer: envelope width per bar
int    g_width_idx   = 0;    // ring buffer write position
bool   g_state_ready = false;

// ============================================================================
// Indicator handle helpers — registers into QM pool so framework shutdown
// cleans up automatically. Never hold file-scope handles or call IndicatorRelease.
// ============================================================================

int GetDeMarkerHandle()
  {
   const string key = StringFormat("DEM|%s|%d|%d",
                                   _Symbol, (int)_Period, strategy_dem_period);
   int h = QM_IndicatorsLookup(key);
   if(h != INVALID_HANDLE) return h;
   h = iDeMarker(_Symbol, _Period, strategy_dem_period);
   return QM_IndicatorsRegister(key, h);
  }

int GetEnvelopesHandle()
  {
   const string key = StringFormat("ENV|%s|%d|%d|%.4f",
                                   _Symbol, (int)_Period,
                                   strategy_env_period, strategy_env_deviation);
   int h = QM_IndicatorsLookup(key);
   if(h != INVALID_HANDLE) return h;
   h = iEnvelopes(_Symbol, _Period, strategy_env_period, 0,
                  MODE_SMA, PRICE_CLOSE, strategy_env_deviation);
   return QM_IndicatorsRegister(key, h);
  }

double MedianEnvWidth()
  {
   double sorted[QM_DEM_ENV_WIDTH_HIST];
   ArrayCopy(sorted, g_width_hist);
   ArraySort(sorted);
   return (sorted[QM_DEM_ENV_WIDTH_HIST / 2 - 1] + sorted[QM_DEM_ENV_WIDTH_HIST / 2]) * 0.5;
  }

// Called ONCE per new closed bar — reads indicator buffers and updates cache.
void AdvanceState_OnNewBar()
  {
   const int h_dem = GetDeMarkerHandle();
   const int h_env = GetEnvelopesHandle();

   g_dem1       = QM_IndicatorReadBuffer(h_dem, 0, 1);
   g_env_upper1 = QM_IndicatorReadBuffer(h_env, 0, 1); // buffer 0 = upper
   g_env_lower1 = QM_IndicatorReadBuffer(h_env, 1, 1); // buffer 1 = lower
   g_env_upper2 = QM_IndicatorReadBuffer(h_env, 0, 2);
   g_env_lower2 = QM_IndicatorReadBuffer(h_env, 1, 2);

   if(g_env_upper1 > 0.0 && g_env_lower1 > 0.0)
      g_env_mid1 = (g_env_upper1 + g_env_lower1) * 0.5;
   g_close1 = iClose(_Symbol, _Period, 1); // perf-allowed: one read per new bar; no QM_Close reader
   g_close2 = iClose(_Symbol, _Period, 2); // perf-allowed: one read per new bar; no QM_Close reader

   const double width = (g_env_upper1 > g_env_lower1) ? (g_env_upper1 - g_env_lower1) : 0.0;
   g_width_hist[g_width_idx % QM_DEM_ENV_WIDTH_HIST] = width;
   ++g_width_idx;

   if(g_width_idx >= QM_DEM_ENV_WIDTH_HIST)
      g_state_ready = true;
  }

// ============================================================================
// Strategy hooks
// ============================================================================

// No Trade Filter — blocks entry during warmup and when envelope is narrow.
bool Strategy_NoTradeFilter()
  {
   if(!g_state_ready) return true; // block until 20 bars of width history available
   const double cur_width = g_env_upper1 - g_env_lower1;
   if(cur_width <= MedianEnvWidth()) return true; // low-volatility boundary filter
   return false;
  }

// Entry Signal — called once per new closed bar (gated by QM_IsNewBar in OnTick).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(!g_state_ready)                                          return false;
   if(g_env_upper1 <= 0.0 || g_env_lower1 <= 0.0)            return false;
   if(g_env_mid1 <= 0.0)                                       return false;

   const double atr_val = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_val <= 0.0) return false;

   // Long: DeMarker overbought AND both recent bars closed above upper envelope
   if(g_dem1 >= strategy_dem_ob_level &&
      g_close1 > g_env_upper1 &&
      g_close2 > g_env_upper2)
     {
      const double ask      = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double dist_mid = ask - g_env_mid1;            // distance to midline
      const double dist_atr = strategy_atr_sl_mult * atr_val; // ATR-based distance
      const double sl_dist  = MathMin(dist_mid, dist_atr); // tighter of the two
      if(sl_dist <= 0.0) return false;
      req.type               = QM_BUY;
      req.price              = 0.0;              // market order
      req.sl                 = ask - sl_dist;
      req.tp                 = 0.0;              // exit by signal
      req.reason             = "DEM_ENV_BREAK_LONG";
      req.symbol_slot        = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
     }

   // Short: DeMarker oversold AND both recent bars closed below lower envelope
   if(g_dem1 <= strategy_dem_os_level &&
      g_close1 < g_env_lower1 &&
      g_close2 < g_env_lower2)
     {
      const double bid      = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double dist_mid = g_env_mid1 - bid;            // distance to midline
      const double dist_atr = strategy_atr_sl_mult * atr_val;
      const double sl_dist  = MathMin(dist_mid, dist_atr);
      if(sl_dist <= 0.0) return false;
      req.type               = QM_SELL;
      req.price              = 0.0;
      req.sl                 = bid + sl_dist;
      req.tp                 = 0.0;
      req.reason             = "DEM_ENV_BREAK_SHORT";
      req.symbol_slot        = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
     }

   return false;
  }

// Trade Management — no intra-trade adjustments; position exits via ExitSignal or SL.
void Strategy_ManageOpenPosition()
  {
  }

// Exit Signal — evaluated every tick using cached per-bar values (O(1)).
bool Strategy_ExitSignal()
  {
   if(!g_state_ready) return false;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE ptype =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      if(ptype == POSITION_TYPE_BUY)
        {
         // Exit long: close returned below midline OR DeMarker fell below 0.50
         if(g_close1 < g_env_mid1 || g_dem1 < strategy_dem_exit_level)
            return true;
        }
      else
        {
         // Exit short: close returned above midline OR DeMarker rose above 0.50
         if(g_close1 > g_env_mid1 || g_dem1 > strategy_dem_exit_level)
            return true;
        }
     }
   return false;
  }

// News Filter Hook — defers to framework two-axis filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// ============================================================================
// Framework wiring — QM_IsNewBar() captured once per tick so AdvanceState
// fires before all Strategy_ hooks on new-bar ticks. Required because
// ExitSignal runs before the entry gate and needs current-bar cached state.
// ============================================================================

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

   // Capture new-bar flag once; advance cached state before all Strategy_ hooks
   // so ExitSignal sees current-bar data on the first tick of a new bar.
   const bool new_bar = QM_IsNewBar();
   if(new_bar)
     {
      AdvanceState_OnNewBar();
      QM_EquityStreamOnNewBar();
     }

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

   if(!new_bar)
      return;

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
