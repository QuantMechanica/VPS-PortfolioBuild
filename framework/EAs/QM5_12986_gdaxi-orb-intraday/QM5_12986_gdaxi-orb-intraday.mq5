#property strict
#property version   "5.0"
#property description "QM5_12986 gdaxi-orb-intraday: GDAXI Opening Range Breakout, day-flat (M15, prop-track)"

#include <QM/QM_Common.mqh>

// ============================================================================
// QM5_12986 — GDAXI Opening Range Breakout, Day-Flat (prop-track)
// Source:  Crabel, T. (1990). Day Trading with Short Term Price Patterns and
//          Opening Range Breakout. Traders Press. + internal QM5_12700 OOS evidence.
// Card:    QM5_12986_gdaxi-orb-intraday
// Symbol:  GDAXI.DWX only (single_symbol_only: true)
// Period:  M15 closed-bar, intraday discipline applied
// ============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 12986;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
// Duration (minutes) of the Xetra cash opening range (must be a multiple of 15).
input int    orb_minutes                  = 60;
// Skip the day if ORB range < min_range_atr_frac * D1 ATR(14): degenerate range.
input double min_range_atr_frac           = 0.15;
// Skip the day if ORB range > max_range_atr_frac * D1 ATR(14): exhausted/gap range.
input double max_range_atr_frac           = 1.0;
// Risk-to-reward multiple for the TP (TP = entry + rr_multiple * initial_risk).
input double rr_multiple                  = 2.0;

// ============================================================================
// DST helpers for broker-time session computation (EU and US DST)
// ============================================================================

// Returns true if EU summer time (CEST) is active for the given UTC datetime.
// CEST: last Sunday in March 01:00 UTC → last Sunday in October 01:00 UTC.
// Input: utc_time = QM_BrokerToUTC(TimeCurrent()).
bool IsEUDSTActive(const datetime utc_time)
  {
   MqlDateTime dt;
   TimeToStruct(utc_time, dt);
   int mon = dt.mon;

   if(mon < 3 || mon > 10) return false;
   if(mon > 3 && mon < 10) return true;

   // In March or October: determine last Sunday of that month.
   // Add enough days to reach the 31st, then read its day-of-week.
   int days_to_31 = 31 - dt.day;
   datetime day31_utc = (datetime)(utc_time + (long)days_to_31 * 86400);
   MqlDateTime d31;
   TimeToStruct(day31_utc, d31);
   int last_sun_day = 31 - (int)d31.day_of_week;  // 0=Sunday → day 31; 6=Saturday → day 25

   if(mon == 3)
     {
      if(dt.day < last_sun_day) return false;
      if(dt.day > last_sun_day) return true;
      return (dt.hour >= 1);  // CEST starts at 01:00 UTC on last Sunday March
     }
   // mon == 10: CEST ends at 01:00 UTC on last Sunday October
   if(dt.day < last_sun_day) return true;
   if(dt.day > last_sun_day) return false;
   return (dt.hour < 1);
  }

// Returns the Xetra cash session open hour in DXZ broker time.
// Xetra opens 09:00 CET (UTC+1 winter) or 09:00 CEST (UTC+2 summer).
// DXZ broker = UTC+2 (outside US DST) or UTC+3 (during US DST).
int GetXetraOpenBrokerHour(const datetime broker_now)
  {
   const datetime utc_now    = QM_BrokerToUTC(broker_now);
   const bool     eu_dst     = IsEUDSTActive(utc_now);
   const bool     us_dst     = QM_IsUSDSTUTC(utc_now);
   const int      xetra_utc  = eu_dst ? 7 : 8;   // 07:00 UTC (CEST) or 08:00 UTC (CET)
   const int      broker_off = us_dst ? 3 : 2;
   return xetra_utc + broker_off;
  }

// Returns the broker hour for the hard flat exit (17:15 CET/CEST equivalent).
// 17:15 CET = 16:15 UTC; 17:15 CEST = 15:15 UTC.
int GetFlatBrokerHour(const datetime broker_now)
  {
   const datetime utc_now    = QM_BrokerToUTC(broker_now);
   const bool     eu_dst     = IsEUDSTActive(utc_now);
   const bool     us_dst     = QM_IsUSDSTUTC(utc_now);
   const int      flat_utc   = eu_dst ? 15 : 16;
   const int      broker_off = us_dst ? 3 : 2;
   return flat_utc + broker_off;
  }

// ============================================================================
// Per-day ORB state — advanced once per new M15 bar inside Strategy_EntrySignal
// ============================================================================
double g_orb_high        = 0.0;
double g_orb_low         = 0.0;
bool   g_orb_complete    = false;
bool   g_orb_valid       = false;
bool   g_trade_today     = false;
int    g_orb_bars_count  = 0;

// ============================================================================
// Strategy hooks
// ============================================================================

// No additional filter (session time and ORB logic handled in EntrySignal).
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Called once per new M15 bar (QM_IsNewBar guard in skeleton OnTick).
// Advances the per-day ORB state and fires entry when ORB is complete and valid.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // ---- Reset ORB state on new D1 bar (new Xetra trading day) ----
   // QM_IsNewBar(_Symbol, PERIOD_D1) has its own internal state separate from
   // the M15 QM_IsNewBar() consumed by the skeleton — safe to call here.
   if(QM_IsNewBar(_Symbol, PERIOD_D1))
     {
      g_orb_high       = 0.0;
      g_orb_low        = 0.0;
      g_orb_complete   = false;
      g_orb_valid      = false;
      g_trade_today    = false;
      g_orb_bars_count = 0;
     }

   // Block if already traded today (max 1 trade/day) or in a position.
   if(g_trade_today)
      return false;
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   // ---- Accumulate ORB bars ----
   // The last closed M15 bar (shift=1) is the one we just advanced past.
   // perf-allowed: bespoke ORB structural logic requires raw bar time/OHLC reads.
   const datetime bar1_time  = iTime(_Symbol, PERIOD_M15, 1);    // perf-allowed
   const int      orb_target = orb_minutes / 15;                  // number of M15 bars in ORB

   if(!g_orb_complete)
     {
      const int session_hour = GetXetraOpenBrokerHour(bar1_time);
      MqlDateTime bar1_dt;
      TimeToStruct(bar1_time, bar1_dt);

      if((int)bar1_dt.hour == session_hour)
        {
         // This M15 bar was within the ORB period.
         const double hi = iHigh(_Symbol, PERIOD_M15, 1);   // perf-allowed
         const double lo = iLow(_Symbol,  PERIOD_M15, 1);   // perf-allowed

         if(g_orb_bars_count == 0)
           {
            g_orb_high = hi;
            g_orb_low  = lo;
           }
         else
           {
            g_orb_high = MathMax(g_orb_high, hi);
            g_orb_low  = MathMin(g_orb_low, lo);
           }
         g_orb_bars_count++;

         if(g_orb_bars_count >= orb_target)
           {
            // ORB is complete — evaluate range quality filter.
            g_orb_complete = true;
            const double orb_range  = g_orb_high - g_orb_low;
            const double d1_atr     = QM_ATR(_Symbol, PERIOD_D1, 14, 1);
            const double min_range  = min_range_atr_frac * d1_atr;
            const double max_range  = max_range_atr_frac * d1_atr;
            g_orb_valid = (d1_atr > 0.0 &&
                           orb_range >= min_range &&
                           orb_range <= max_range);
           }
        }
      // ORB not yet complete or this bar is outside session hour.
      return false;
     }

   // ---- ORB is complete: look for first close beyond the range ----
   if(!g_orb_valid)
      return false;

   // Check whether the last closed M15 bar closed beyond the ORB boundaries.
   const double close1 = iClose(_Symbol, PERIOD_M15, 1);   // perf-allowed: ORB structural
   const double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid    = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(close1 > g_orb_high)
     {
      // Breakout above range: BUY
      req.type   = QM_BUY;
      req.price  = 0.0;
      req.reason = "ORB_BREAKOUT_LONG";
      req.sl     = g_orb_low;                                                     // opposite boundary
      req.tp     = QM_TakeRR(_Symbol, QM_BUY, ask, g_orb_low, rr_multiple);
      g_trade_today = true;
      return true;
     }

   if(close1 < g_orb_low)
     {
      // Breakout below range: SELL
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.reason = "ORB_BREAKOUT_SHORT";
      req.sl     = g_orb_high;                                                    // opposite boundary
      req.tp     = QM_TakeRR(_Symbol, QM_SELL, bid, g_orb_high, rr_multiple);
      g_trade_today = true;
      return true;
     }

   return false;
  }

// No active management: SL and TP are set at entry (opposite range boundary / 2R).
void Strategy_ManageOpenPosition()
  {
  }

// Hard flat: close any open position at or after 17:15 CET/CEST equivalent.
// Runs every tick (cheap O(1) time comparison).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) == 0)
      return false;

   const datetime broker_now  = TimeCurrent();
   const int      flat_hour   = GetFlatBrokerHour(broker_now);
   const int      flat_min    = 15;   // flat at HH:15 CET/CEST equivalent

   MqlDateTime dt;
   TimeToStruct(broker_now, dt);
   if((int)dt.hour > flat_hour ||
      ((int)dt.hour == flat_hour && (int)dt.min >= flat_min))
      return true;

   return false;
  }

// No custom news hook; defers to framework two-axis filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// ============================================================================
// Framework wiring — do NOT edit below this line unless you know why.
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
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
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
