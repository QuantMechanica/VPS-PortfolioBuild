#property strict
#property version   "5.0"
#property description "QM5_1574 Alpha Architect first-half-hour last-half-hour intraday momentum"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_1574 — Alpha Architect First-Half-Hour Last-Half-Hour Intraday Momentum
// Source:    ede348b4-0fa7-5be1-baa8-09e9089b67b7
// Card:      QM5_1574_aa-intraday-fh-lh
//
// Signal: Go long during last 30 min of session if first-30-min return > 0;
//         go short if first-30-min return < 0. Exit at session close.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1574;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
// Session times in broker-time HHMM (NY-close convention; SP500 regular session)
input int    strategy_session_open_hhmm  = 1630;  // first M30 bar open time (16:30 broker)
input int    strategy_entry_hhmm         = 2230;  // last-half-hour entry bar (22:30 broker)
input int    strategy_session_close_hhmm = 2300;  // hard exit time (23:00 broker)
input int    strategy_atr_period         = 14;
input double strategy_atr_sl_mult        = 1.5;
input int    strategy_max_spread_points  = 250;

// One-trade-per-session deduplication key (resets each OnInit)
int g_last_trade_day_key = 0;

// -----------------------------------------------------------------------------
// Helpers — cheap per-tick reads only (HHMM, day key, position check)
// -----------------------------------------------------------------------------

int Hhmm(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

int DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

bool HasOurOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

// Compute the first-half-hour return for today's session.
// Finds the M30 bar that opened at strategy_session_open_hhmm and computes
// (close/open - 1).  Uses iBarShift for structural bar lookup and iOpen/iClose
// with perf-allowed exception (bespoke session-bar structural read — no
// QM_* indicator equivalent for arbitrary M30 bar OHLC at a named time).
// Called only inside QM_IsNewBar gate — runs once per M30 bar at entry time.
bool FirstHalfHourReturn(double &first_return)
  {
   first_return = 0.0;

   MqlDateTime ref_dt;
   TimeToStruct(TimeCurrent(), ref_dt);
   ref_dt.hour = strategy_session_open_hhmm / 100;
   ref_dt.min  = strategy_session_open_hhmm % 100;
   ref_dt.sec  = 0;

   const datetime session_open_time = StructToTime(ref_dt);
   const int first_shift = iBarShift(_Symbol, PERIOD_M30, session_open_time, true);
   if(first_shift < 1)
      return false;

   const double bar_open  = iOpen(_Symbol,  PERIOD_M30, first_shift);  // perf-allowed: bespoke session-bar structural read
   const double bar_close = iClose(_Symbol, PERIOD_M30, first_shift);  // perf-allowed: bespoke session-bar structural read
   if(bar_open <= 0.0 || bar_close <= 0.0)
      return false;

   first_return = (bar_close / bar_open) - 1.0;
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   // Pass through when a position is open so ExitSignal can fire at session close.
   if(HasOurOpenPosition())
      return false;

   // Block entry outside session window.
   const int hhmm = Hhmm(TimeCurrent());
   if(hhmm < strategy_session_open_hhmm || hhmm >= strategy_session_close_hhmm)
      return true;

   // Block on excessive spread.
   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(strategy_max_spread_points > 0 && spread_points > strategy_max_spread_points)
      return true;

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type               = QM_BUY;
   req.price              = 0.0;
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const datetime now       = TimeCurrent();
   const int      now_hhmm  = Hhmm(now);
   const int      today_key = DayKey(now);

   // Entry only at the last-half-hour bar.
   if(now_hhmm != strategy_entry_hhmm)
      return false;

   // One trade per session.
   if(g_last_trade_day_key == today_key)
      return false;

   // Skip if already in a position (belt+suspenders beyond the registry guard).
   if(HasOurOpenPosition())
      return false;

   // Compute first-half-hour return (called once per new M30 bar at entry time).
   double first_return = 0.0;
   if(!FirstHalfHourReturn(first_return) || first_return == 0.0)
      return false;

   // ATR stop distance (pooled handle via QM_Indicators).
   const double atr = QM_ATR(_Symbol, PERIOD_M30, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   if(first_return > 0.0)
     {
      req.type   = QM_BUY;
      req.price  = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.sl     = QM_StopATRFromValue(_Symbol, req.type, req.price, atr, strategy_atr_sl_mult);
      req.reason = "FH_POSITIVE_LONG_LH";
     }
   else
     {
      req.type   = QM_SELL;
      req.price  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      req.sl     = QM_StopATRFromValue(_Symbol, req.type, req.price, atr, strategy_atr_sl_mult);
      req.reason = "FH_NEGATIVE_SHORT_LH";
     }

   if(req.price <= 0.0 || req.sl <= 0.0)
      return false;

   g_last_trade_day_key = today_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing stop, break-even, or partial-close management.
  }

bool Strategy_ExitSignal()
  {
   // Hard exit at session close (23:00 broker time).
   if(Hhmm(TimeCurrent()) < strategy_session_close_hhmm)
      return false;
   return HasOurOpenPosition();
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade2 via framework
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1574\",\"strategy\":\"aa_intraday_fh_lh\"}");
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
