#property strict
#property version   "5.0"
#property description "QM5_12836 Turnaround Tuesday (WS30/Dow weekly calendar MR)"

#include <QM/QM_Common.mqh>
#include <QM/QM_Signals.mqh>

// =============================================================================
// Enums
// =============================================================================
enum WEAK_MONDAY_MODE { WMM_BELOW_FRIDAY = 0, WMM_BAR_BEARISH = 1 };
enum ENTRY_MODE_TT    { EM_IMMEDIATE = 0,      EM_BREAKOUT = 1 };
enum SL_MODE_TT       { SL_MONDAY_LOW = 0,     SL_FIXED_PCT = 1 };
enum TP_MODE_TT       { TP_FIXED_PCT = 0,       TP_MONDAY_HIGH = 1, TP_NONE = 2 };

// =============================================================================
// Framework inputs
// =============================================================================
input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 12836;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal    = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance  = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours               = 336;
input string qm_news_min_impact                    = "high";
input QM_NewsMode qm_news_mode_legacy              = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled               = true;
input int    qm_friday_close_hour_broker           = 21;

input group "Stress"
input double qm_stress_reject_probability          = 0.0;

input group "Strategy"
input int              regime_sma_period  = 200;           // D1 bull-regime SMA period; sweep 100/150/200
input WEAK_MONDAY_MODE weak_monday_mode   = WMM_BELOW_FRIDAY; // WMM_BELOW_FRIDAY=QS canonical; WMM_BAR_BEARISH=alt
input bool             use_volume_filter  = true;          // Monday D1 tick-vol > SMA(vol, N)
input int              volume_sma_period  = 25;            // Volume SMA lookback (D1 bars prior to Monday)
input ENTRY_MODE_TT    entry_mode         = EM_IMMEDIATE;  // EM_IMMEDIATE=first Tuesday bar; EM_BREAKOUT=above Mon-high
input SL_MODE_TT       sl_mode            = SL_MONDAY_LOW; // SL_MONDAY_LOW=at Monday's low; SL_FIXED_PCT=pct from entry
input double           sl_fixed_pct       = 1.0;           // SL distance from entry in % (when sl_mode=SL_FIXED_PCT)
input TP_MODE_TT       tp_mode            = TP_FIXED_PCT;  // TP_FIXED_PCT / TP_MONDAY_HIGH / TP_NONE
input double           tp_fixed_pct       = 1.75;          // TP distance from entry in % (when tp_mode=TP_FIXED_PCT)
input int              exit_dow           = 2;             // Day-of-week for hard time-exit (2=Tuesday)
input int              exit_hour          = 22;            // Broker hour for hard time-exit (WS30 US cash close ~22h broker)
input int              max_hold_days      = 2;             // Safety: force-close after N calendar days

// =============================================================================
// Weekly state cache — updated once per Tuesday from Monday's D1 bar.
// =============================================================================
double   g_monday_close    = 0.0;
double   g_monday_open     = 0.0;
double   g_monday_high     = 0.0;
double   g_monday_low      = 0.0;
double   g_friday_close    = 0.0;
double   g_monday_tick_vol = 0.0;
double   g_monday_vol_sma  = 0.0;
double   g_d1_regime_sma   = 0.0;
bool     g_week_setup_valid = false;
datetime g_last_setup_bar   = 0;   // iTime(PERIOD_D1,1) of the Monday we last cached
bool     g_entry_taken      = false;

// =============================================================================
// MaybeSetupWeekly
// Caches Monday D1 data the first time we encounter a new Tuesday H1 bar.
// All iX reads carry // perf-allowed: each executes at most once per calendar week.
// =============================================================================
void MaybeSetupWeekly(const datetime broker_now)
  {
   MqlDateTime t;
   TimeToStruct(broker_now, t);
   if(t.day_of_week != 2)
      return;

   const datetime d1_t1 = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: calendar gating, once/week
   if(d1_t1 <= 0 || d1_t1 == g_last_setup_bar)
      return;

   MqlDateTime d1t;
   TimeToStruct(d1_t1, d1t);
   if(d1t.day_of_week != 1)
      return; // D1[1] not Monday (holiday or startup artifact) — skip

   g_monday_close    = iClose(_Symbol, PERIOD_D1, 1);           // perf-allowed
   g_monday_open     = iOpen(_Symbol, PERIOD_D1, 1);            // perf-allowed
   g_monday_high     = iHigh(_Symbol, PERIOD_D1, 1);            // perf-allowed
   g_monday_low      = iLow(_Symbol, PERIOD_D1, 1);             // perf-allowed
   g_friday_close    = iClose(_Symbol, PERIOD_D1, 2);           // perf-allowed
   g_monday_tick_vol = (double)iVolume(_Symbol, PERIOD_D1, 1);  // perf-allowed

   // Volume SMA: average of N D1 bars immediately before Monday (shift 2..N+1)
   const int n_vol = MathMax(1, volume_sma_period);
   double vol_sum = 0.0;
   for(int i = 2; i <= n_vol + 1; i++) // perf-allowed: <=25 iters, once per week
      vol_sum += (double)iVolume(_Symbol, PERIOD_D1, i); // perf-allowed
   g_monday_vol_sma = vol_sum / n_vol;

   g_d1_regime_sma = QM_SMA(_Symbol, PERIOD_D1, regime_sma_period, 1);

   bool weak_mon;
   if(weak_monday_mode == WMM_BELOW_FRIDAY)
      weak_mon = (g_monday_close > 0.0 && g_friday_close > 0.0 &&
                  g_monday_close < g_friday_close);
   else
      weak_mon = (g_monday_close > 0.0 && g_monday_open > 0.0 &&
                  g_monday_close < g_monday_open);

   const bool vol_ok = (!use_volume_filter) ||
                       (g_monday_vol_sma > 0.0 && g_monday_tick_vol > g_monday_vol_sma);

   const bool regime_ok = (g_d1_regime_sma > 0.0 &&
                            g_monday_close > g_d1_regime_sma);

   g_week_setup_valid = (weak_mon && vol_ok && regime_ok &&
                         g_monday_high > 0.0 && g_monday_low > 0.0);

   g_last_setup_bar = d1_t1;
   g_entry_taken    = false;

   QM_LogEvent(QM_INFO, "WEEKLY_SETUP",
      StringFormat("{\"d1_bar\":\"%s\",\"monday_close\":%.4f,\"friday_close\":%.4f,"
                   "\"regime_sma\":%.4f,\"tick_vol\":%.0f,\"vol_sma\":%.2f,"
                   "\"setup_valid\":%s}",
                   TimeToString(d1_t1),
                   g_monday_close, g_friday_close, g_d1_regime_sma,
                   g_monday_tick_vol, g_monday_vol_sma,
                   g_week_setup_valid ? "true" : "false"));
  }

// =============================================================================
// Strategy hooks
// =============================================================================

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const datetime broker_now = TimeCurrent();
   MqlDateTime t;
   TimeToStruct(broker_now, t);

   MaybeSetupWeekly(broker_now);

   if(t.day_of_week != 2 || !g_week_setup_valid || g_entry_taken)
      return false;

   if(t.hour >= exit_hour)
      return false;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(entry_mode == EM_BREAKOUT)
     {
      // EM_BREAKOUT: enter when last closed H1 bar's HIGH has cleared Monday's high.
      const double last_h1_high = iHigh(_Symbol, _Period, 1); // perf-allowed: once/H1-bar, structural
      if(last_h1_high <= g_monday_high)
         return false;
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0.0)
      return false;

   double sl_price;
   if(sl_mode == SL_MONDAY_LOW)
     {
      if(g_monday_low <= 0.0)
         return false;
      sl_price = g_monday_low;
     }
   else
      sl_price = ask * (1.0 - sl_fixed_pct / 100.0);

   if(sl_price >= ask)
      return false;

   double tp_price;
   if(tp_mode == TP_FIXED_PCT)
      tp_price = ask * (1.0 + tp_fixed_pct / 100.0);
   else if(tp_mode == TP_MONDAY_HIGH)
     {
      tp_price = g_monday_high;
      if(tp_price <= ask) // if entry already above Monday high, fall back to fixed %
         tp_price = ask * (1.0 + tp_fixed_pct / 100.0);
     }
   else
      tp_price = 0.0;

   req.type             = QM_BUY;
   req.price            = 0.0;
   req.sl               = QM_StopRulesNormalizePrice(_Symbol, sl_price);
   req.tp               = (tp_price > 0.0)
                          ? QM_StopRulesNormalizePrice(_Symbol, tp_price)
                          : 0.0;
   req.reason           = StringFormat("TT12836_%s_%s",
                            (entry_mode == EM_IMMEDIATE) ? "IMM" : "BRK",
                            (weak_monday_mode == WMM_BELOW_FRIDAY) ? "BF" : "BB");
   req.symbol_slot      = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   g_entry_taken = true;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // No active management: exit via SL/TP or time-stop in Strategy_ExitSignal.
  }

bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) == 0)
      return false;

   const datetime broker_now = TimeCurrent();
   MqlDateTime t;
   TimeToStruct(broker_now, t);

   if(t.day_of_week == exit_dow && t.hour >= exit_hour)
      return true;

   // Safety: force-close if position held beyond max_hold_days calendar days.
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      const ulong tk = PositionGetTicket(i);
      if(tk == 0 || !PositionSelectByTicket(tk))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const datetime pos_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(broker_now - pos_time > (long)max_hold_days * 86400)
         return true;
     }

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// =============================================================================
// Framework wiring
// =============================================================================

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

   QM_LogEvent(QM_INFO, "INIT_OK",
      "{\"ea\":\"QM5_12836\",\"card\":\"balke-turnaround-tuesday-20260630\"}");
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
