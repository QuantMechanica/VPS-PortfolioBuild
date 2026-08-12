#property strict
#property version   "5.0"
#property description "QM5_20010 XAU Friday Gold Rush (Friday D1 bar long)"
// Strategy Card: QM5_20010_xau-friday-rush.md, G0 APPROVED 2026-07-19.
// Source: Yu/Lee/Shih 2016 Banks and Bank Systems 11(2):33-44 (DOI
// 10.21511/BBS.11(2).2016.04) -- Friday gold returns positive+significant;
// Blose/Gondhalekar 2013 Accounting & Finance 53(3) (DOI
// 10.1111/j.1467-629X.2012.00497.x) -- weekend hold decays, exit before it.

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 20010;
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
input int    strategy_atr_period        = 14;  // Card §3/§Params: protective stop = ATR(D1,14), fixed (not swept).
input double strategy_stop_atr_mult     = 3.0; // Card §6 P3 sweep: [2.0, 3.0, 4.0], default 3.0.

// -----------------------------------------------------------------------------
// Strategy state
// -----------------------------------------------------------------------------
// Bars-held counter since entry, advanced via QM_CalendarPeriodKey(D1)
// comparisons against our own stored key (framework-sanctioned once-per-period
// pattern) -- NEVER via QM_IsNewBar(), which is already single-consumed by
// OnTick's own entry gate below (DWX invariant #3).
int g_days_elapsed      = 0;
int g_last_seen_day_key = 0;

bool Strategy_NoTradeFilter()
  {
   return false; // Card §5: the Friday-only calendar gate lives inside Strategy_EntrySignal below.
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false; // Card: single position per magic, long-only.

   // Card §3: "long-only; at the OPEN of the Friday D1 bar (first tick after
   // Thursday D1 close)". OnTick's QM_IsNewBar() gate (single-consumed, below)
   // guarantees this hook runs once per newly-opened closed D1 bar; checking
   // that just-opened bar's weekday against Friday implements the calendar
   // rule. This also satisfies the holiday-skip requirement by construction:
   // if Friday is a market holiday, no D1 bar with day_of_week==Friday ever
   // opens that week, so the check simply never fires -- no special case needed.
   const bool day_enabled[7] = {false, false, false, false, true, false, false}; // Mon..Sun, Fri=true
   if(QM_Sig_DayOfWeek(TimeCurrent(), day_enabled) <= 0)
      return false;

   const double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry_price <= 0.0)
      return false;

   req.type = QM_BUY; // Card §3: long-only.
   req.price = 0.0;   // framework fills market at current tick (Friday-bar-open fill).
   req.sl = QM_StopATR(_Symbol, QM_BUY, entry_price, strategy_atr_period, strategy_stop_atr_mult); // Card §3: catastrophe-stop backstop, non-alpha sizing.
   req.tp = 0.0; // Card §4: no TP -- the edge is the calendar bar, not a price level.
   req.reason = "xau_friday_gold_rush";

   g_days_elapsed = 0;
   g_last_seen_day_key = QM_CalendarPeriodKey(PERIOD_D1);
   return (req.sl > 0.0);
  }

void Strategy_ManageOpenPosition()
  {
   // Card §4: advance the bars-held counter once per new D1 period while a
   // position is open. QM_CalendarPeriodKey is a pure query (not a
   // single-consume latch), so it never competes with OnTick's own
   // QM_IsNewBar() consumption used by the entry gate.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return;

   const int today_key = QM_CalendarPeriodKey(PERIOD_D1);
   if(today_key == 0)
      return;

   if(g_last_seen_day_key == 0)
     {
      g_last_seen_day_key = today_key; // restart-safety: position existed before an EA reload.
      return;
     }

   if(today_key != g_last_seen_day_key)
     {
      ++g_days_elapsed;
      g_last_seen_day_key = today_key;
     }
  }

bool Strategy_ExitSignal()
  {
   // Card §4: "time exit at the CLOSE of the same Friday D1 bar (before
   // weekend)". Mechanically the Friday D1 bar is closed exactly when the
   // NEXT D1 period opens (whatever calendar day that bar turns out to be),
   // which is the QM_CalendarPeriodKey rollover Strategy_ManageOpenPosition
   // tracks above. Held-for-one-D1-period == flat before the weekend, by
   // construction; no trailing, no partials (Card §4).
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;
   return (g_days_elapsed >= 1);
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // Card §3: "news blackout per framework default" -- no override, defer to QM_NewsAllowsTrade2.
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

   g_days_elapsed = 0;
   g_last_seen_day_key = 0;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_20010\",\"ea\":\"xau-friday-rush\"}");
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
   ZeroMemory(req);
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
