#property strict
#property version   "5.0"
#property description "QM5_9290 MQL5 DeMarker Envelope Fakeout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9290 — DeMarker Envelope Fakeout
// Card: D:\QM\strategy_farm\artifacts\cards_approved\QM5_9290_mql5-dem-env-fakeout.md
// Source: Stephen Njuki, MQL5 Wizard Techniques (Part 63), 2025-05-07
// Pattern: 3-bar fakeout through Envelope band, confirmed by DeMarker extreme.
// Long: close[1]>lower, close[2]<=lower, close[3]>=lower, DeM[1]<=0.30
// Short: close[1]<upper, close[2]>=upper, close[3]<=upper, DeM[1]>=0.70
// Exit: opposite fakeout signal OR 12-bar time exit. SL = band ± 0.5*ATR(14).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 9290;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int            strategy_dem_period      = 13;    // DeMarker period
input int            strategy_env_period      = 14;    // Envelopes MA period
input double         strategy_env_deviation   = 0.1;   // Envelopes deviation %
input ENUM_MA_METHOD strategy_env_method      = MODE_SMA; // Envelopes MA method
input int            strategy_atr_period      = 14;    // ATR period for stop
input double         strategy_atr_sl_mult     = 0.5;   // ATR multiplier for stop
input double         strategy_dem_long_thresh = 0.30;  // DeMarker long threshold (<=)
input double         strategy_dem_short_thresh= 0.70;  // DeMarker short threshold (>=)
input int            strategy_max_hold_bars   = 12;    // Max bars before time-exit
input double         strategy_env_expand_max  = 0.25;  // Max width expansion ratio

// ---- State: entry bar tracking for time exit and opposite-signal detection ----
datetime g_entry_bar_time = 0;  // open time of signal bar; 0 = no tracked position
int      g_open_dir       = 0;  // 1=long, -1=short

// ---- Signal helpers ----

// Returns true if envelope width at shift=1 is >strategy_env_expand_max wider than shift=4.
bool EnvIsExpanding()
  {
   const double w1 = QM_Envelope_Upper(_Symbol, _Period, strategy_env_period, strategy_env_deviation, strategy_env_method, 1)
                   - QM_Envelope_Lower(_Symbol, _Period, strategy_env_period, strategy_env_deviation, strategy_env_method, 1);
   const double w4 = QM_Envelope_Upper(_Symbol, _Period, strategy_env_period, strategy_env_deviation, strategy_env_method, 4)
                   - QM_Envelope_Lower(_Symbol, _Period, strategy_env_period, strategy_env_deviation, strategy_env_method, 4);
   if(w4 <= 0.0)
      return false;
   return ((w1 / w4) - 1.0) > strategy_env_expand_max;
  }

// 3-bar fakeout below the lower Envelope, confirmed by DeMarker oversold.
bool IsFakeoutLong()
  {
   const double lo1 = QM_Envelope_Lower(_Symbol, _Period, strategy_env_period, strategy_env_deviation, strategy_env_method, 1);
   const double lo2 = QM_Envelope_Lower(_Symbol, _Period, strategy_env_period, strategy_env_deviation, strategy_env_method, 2);
   const double lo3 = QM_Envelope_Lower(_Symbol, _Period, strategy_env_period, strategy_env_deviation, strategy_env_method, 3);
   if(lo1 <= 0.0 || lo2 <= 0.0 || lo3 <= 0.0)
      return false;
   const double dem = QM_DeMarker(_Symbol, _Period, strategy_dem_period, 1);
   const double c1  = iClose(_Symbol, _Period, 1); // perf-allowed: bespoke structural
   const double c2  = iClose(_Symbol, _Period, 2); // perf-allowed: bespoke structural
   const double c3  = iClose(_Symbol, _Period, 3); // perf-allowed: bespoke structural
   if(c1 <= 0.0 || c2 <= 0.0 || c3 <= 0.0)
      return false;
   return c1 > lo1 && c2 <= lo2 && c3 >= lo3 && dem <= strategy_dem_long_thresh;
  }

// 3-bar fakeout above the upper Envelope, confirmed by DeMarker overbought.
bool IsFakeoutShort()
  {
   const double up1 = QM_Envelope_Upper(_Symbol, _Period, strategy_env_period, strategy_env_deviation, strategy_env_method, 1);
   const double up2 = QM_Envelope_Upper(_Symbol, _Period, strategy_env_period, strategy_env_deviation, strategy_env_method, 2);
   const double up3 = QM_Envelope_Upper(_Symbol, _Period, strategy_env_period, strategy_env_deviation, strategy_env_method, 3);
   if(up1 <= 0.0 || up2 <= 0.0 || up3 <= 0.0)
      return false;
   const double dem = QM_DeMarker(_Symbol, _Period, strategy_dem_period, 1);
   const double c1  = iClose(_Symbol, _Period, 1); // perf-allowed: bespoke structural
   const double c2  = iClose(_Symbol, _Period, 2); // perf-allowed: bespoke structural
   const double c3  = iClose(_Symbol, _Period, 3); // perf-allowed: bespoke structural
   if(c1 <= 0.0 || c2 <= 0.0 || c3 <= 0.0)
      return false;
   return c1 < up1 && c2 >= up2 && c3 <= up3 && dem >= strategy_dem_short_thresh;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No Trade Filter: spread/session/regime conditions.
// Returns true to BLOCK trading this tick.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Trade Entry: populate req and return true on new closed-bar fakeout signal.
// Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type            = QM_BUY;
   req.price           = 0.0;
   req.sl              = 0.0;
   req.tp              = 0.0;
   req.reason          = "";
   req.symbol_slot     = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(EnvIsExpanding())
      return false;

   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   if(IsFakeoutLong())
     {
      const double lo = QM_Envelope_Lower(_Symbol, _Period, strategy_env_period, strategy_env_deviation, strategy_env_method, 1);
      req.type   = QM_BUY;
      req.sl     = lo - strategy_atr_sl_mult * atr;
      req.tp     = 0.0;
      req.reason = "DEM_ENV_FK_LONG";
      g_entry_bar_time = iTime(_Symbol, _Period, 1); // perf-allowed: record entry bar for time-exit
      g_open_dir       = 1;
      return true;
     }

   if(IsFakeoutShort())
     {
      const double up = QM_Envelope_Upper(_Symbol, _Period, strategy_env_period, strategy_env_deviation, strategy_env_method, 1);
      req.type   = QM_SELL;
      req.sl     = up + strategy_atr_sl_mult * atr;
      req.tp     = 0.0;
      req.reason = "DEM_ENV_FK_SHORT";
      g_entry_bar_time = iTime(_Symbol, _Period, 1); // perf-allowed: record entry bar for time-exit
      g_open_dir       = -1;
      return true;
     }

   return false;
  }

// Trade Management: reset state when SL/TP closes position externally.
void Strategy_ManageOpenPosition()
  {
   if(g_entry_bar_time == 0)
      return;
   if(!QM_EntryHasOpenPosition((long)QM_FrameworkMagic(), _Symbol))
     {
      g_entry_bar_time = 0;
      g_open_dir       = 0;
     }
  }

// Trade Close: time exit (12 bars) or opposite fakeout signal.
bool Strategy_ExitSignal()
  {
   if(g_entry_bar_time == 0 || g_open_dir == 0)
      return false;

   // Time exit: entry bar shifts past strategy_max_hold_bars
   // perf-allowed: bespoke structural — bar-elapsed count via iBarShift
   const int elapsed = iBarShift(_Symbol, _Period, g_entry_bar_time);
   if(elapsed < 0 || elapsed > strategy_max_hold_bars)
      return true;

   // Opposite fakeout exit (shift=1 values; O(1) per tick with pooled handles)
   if(g_open_dir > 0 && IsFakeoutShort())
      return true;
   if(g_open_dir < 0 && IsFakeoutLong())
      return true;

   return false;
  }

// News Filter Hook: defer to framework 2-axis filter.
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
