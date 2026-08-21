#property strict
#property version   "5.0"
#property description "QM5_12920 Quantpedia Pre-Election Drift SP500"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_12920 - qp-pre-election-sp500
// -----------------------------------------------------------------------------
// Trades the pre-election drift on SP500.DWX around US federal elections.
// Federal elections occur on the Tuesday after the first Monday in November
// in even-numbered years.
// Entry: Open LONG on SP500.DWX at the close of D-5 trading days (Tuesday one
// week before Election Day).
// Exit: Close LONG at the close of Election Day (D0, Tuesday).
// Hard stop: 2.0x D1 ATR(20).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 12920;
input int    qm_magic_slot_offset        = 2; // SP500.DWX is slot 2 in magic_numbers.csv
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
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_atr_period         = 20;
input double strategy_atr_sl_mult        = 2.0;
input int    strategy_min_d1_bars        = 60;

int g_last_traded_election_year = 0;

// -----------------------------------------------------------------------------
// Calendar helpers
// -----------------------------------------------------------------------------

datetime Strategy_GetElectionDate(const int year)
{
   if((year % 2) != 0)
      return 0; // US Federal elections occur in even years only

   MqlDateTime dt;
   dt.year = year;
   dt.mon = 11;
   dt.day = 1;
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   const datetime nov1 = StructToTime(dt);
   if(nov1 <= 0)
      return 0;
   TimeToStruct(nov1, dt);

   // day_of_week: 0=Sun, 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat
   int first_monday_day = 1;
   if(dt.day_of_week == 1)
      first_monday_day = 1;
   else if(dt.day_of_week == 0)
      first_monday_day = 2;
   else
      first_monday_day = 1 + (8 - dt.day_of_week);

   const int election_day = first_monday_day + 1; // Tuesday after first Monday
   dt.day = election_day;
   return StructToTime(dt);
}

datetime Strategy_GetD5Date(const int year)
{
   const datetime election_date = Strategy_GetElectionDate(year);
   if(election_date <= 0)
      return 0;
   // Election day is Tuesday; 5 trading days prior is the prior Tuesday (7 calendar days)
   return election_date - (7 * 86400);
}

bool Strategy_IsSp500D1()
{
   return (_Symbol == "SP500.DWX" && _Period == PERIOD_D1 && qm_magic_slot_offset == 2);
}

bool Strategy_HasOpenPosition(ulong &ticket)
{
   ticket = 0;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      ticket = t;
      return true;
   }
   return false;
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   if(!Strategy_IsSp500D1())
      return true;
   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(Bars(_Symbol, PERIOD_D1) < strategy_min_d1_bars)
      return true;
   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const datetime current_bar_time = iTime(_Symbol, PERIOD_D1, 0);
   if(current_bar_time <= 0)
      return false;

   MqlDateTime dt;
   TimeToStruct(current_bar_time, dt);
   if((dt.year % 2) != 0)
      return false;

   const datetime election_date = Strategy_GetElectionDate(dt.year);
   const datetime d5_date = Strategy_GetD5Date(dt.year);
   if(election_date <= 0 || d5_date <= 0)
      return false;

   // Entry window: open on or after D-5 close through election day
   // When D-5 closes, current_bar_time is > d5_date up to election day
   if(current_bar_time <= d5_date || current_bar_time > election_date)
      return false;

   if(g_last_traded_election_year == dt.year)
      return false;

   ulong existing_ticket = 0;
   if(Strategy_HasOpenPosition(existing_ticket))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0.0)
      return false;

   req.type = QM_BUY;
   req.price = ask;
   req.sl = QM_StopATR(_Symbol, req.type, req.price, strategy_atr_period, strategy_atr_sl_mult);
   req.tp = 0.0;
   req.symbol_slot = qm_magic_slot_offset;
   req.reason = StringFormat("SP500_PRE_ELECTION_%d", dt.year);

   if(req.sl <= 0.0 || req.sl >= req.price)
      return false;

   g_last_traded_election_year = dt.year;
   return true;
}

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
{
   ulong ticket = 0;
   if(!Strategy_HasOpenPosition(ticket))
      return false;

   const datetime current_bar_time = iTime(_Symbol, PERIOD_D1, 0);
   if(current_bar_time <= 0)
      return false;

   MqlDateTime dt;
   TimeToStruct(current_bar_time, dt);
   const datetime election_date = Strategy_GetElectionDate(dt.year);
   if(election_date > 0 && current_bar_time > election_date)
   {
      // Election day has closed -> exit position
      return true;
   }

   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12920\",\"ea\":\"qp-pre-election-sp500\"}");
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
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
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
