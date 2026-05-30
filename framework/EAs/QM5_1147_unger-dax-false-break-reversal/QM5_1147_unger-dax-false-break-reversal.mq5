#property strict
#property version   "5.0"
#property description "QM5_1147 Unger DAX false-break reversal"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1147;
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
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_atr_period_m15       = 14;
input int    strategy_atr_period_d1        = 14;
input double strategy_sl_atr_mult          = 1.5;
input double strategy_tp_atr_mult          = 1.0;
input double strategy_open_gap_atr_mult    = 1.5;
input int    strategy_session_start_hhmm   = 900;
input int    strategy_session_end_hhmm     = 1725;
input int    strategy_max_spread_points    = 200;

bool HasOurOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

int CurrentDayKey()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int CurrentHHMM()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return dt.hour * 100 + dt.min;
  }

bool HasEnteredToday()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const datetime day_start = StructToTime(dt) - (dt.hour * 3600 + dt.min * 60 + dt.sec);
   if(!HistorySelect(day_start, TimeCurrent()))
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = HistoryDealsTotal() - 1; i >= 0; --i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      if((int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic)
         continue;
      if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY) == DEAL_ENTRY_IN)
         return true;
     }
   return false;
  }

bool OpeningGapTooLarge()
  {
   if(strategy_open_gap_atr_mult <= 0.0)
      return false;

   const double today_open = iOpen(_Symbol, PERIOD_D1, 0);
   const double prev_close = iClose(_Symbol, PERIOD_D1, 1);
   const double atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(today_open <= 0.0 || prev_close <= 0.0 || atr_d1 <= 0.0)
      return true;

   return MathAbs(today_open - prev_close) > atr_d1 * strategy_open_gap_atr_mult;
  }

bool Strategy_NoTradeFilter()
  {
   if(HasOurOpenPosition())
      return false;

   const int hhmm = CurrentHHMM();
   if(hhmm < strategy_session_start_hhmm || hhmm >= strategy_session_end_hhmm)
      return true;

   const int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(strategy_max_spread_points > 0 && spread > strategy_max_spread_points)
      return true;

   if(OpeningGapTooLarge())
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

   if(_Period != PERIOD_M15)
      return false;

   static int  tracked_day_key = 0;
   static bool low_broken = false;
   static bool high_broken = false;
   static bool traded_today = false;

   const int day_key = CurrentDayKey();
   if(day_key != tracked_day_key)
     {
      tracked_day_key = day_key;
      low_broken = false;
      high_broken = false;
      traded_today = false;
     }

   if(traded_today || HasOurOpenPosition() || HasEnteredToday())
      return false;

   const int hhmm = CurrentHHMM();
   if(hhmm < strategy_session_start_hhmm || hhmm >= strategy_session_end_hhmm)
      return false;

   const double pdh = iHigh(_Symbol, PERIOD_D1, 1);
   const double pdl = iLow(_Symbol, PERIOD_D1, 1);
   const double close_last = iClose(_Symbol, PERIOD_M15, 1);
   const double atr_m15 = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period_m15, 1);
   if(pdh <= 0.0 || pdl <= 0.0 || pdh <= pdl || close_last <= 0.0 || atr_m15 <= 0.0)
      return false;

   if(close_last < pdl)
     {
      low_broken = true;
      return false;
     }
   if(close_last > pdh)
     {
      high_broken = true;
      return false;
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   double entry = 0.0;
   if(low_broken && close_last > pdl)
     {
      req.type = QM_BUY;
      entry = ask;
      req.reason = "PDL_FALSE_BREAK_REVERSAL_LONG";
     }
   else if(high_broken && close_last < pdh)
     {
      req.type = QM_SELL;
      entry = bid;
      req.reason = "PDH_FALSE_BREAK_REVERSAL_SHORT";
     }
   else
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry, atr_m15, strategy_sl_atr_mult);
   if(req.sl <= 0.0)
      return false;

   const double tp_distance = atr_m15 * strategy_tp_atr_mult;
   if(tp_distance > 0.0)
     {
      if(req.type == QM_BUY)
         req.tp = NormalizeDouble(entry + tp_distance, _Digits);
      else
         req.tp = NormalizeDouble(entry - tp_distance, _Digits);
     }

   traded_today = true;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed SL/TP and session flatten only.
  }

bool Strategy_ExitSignal()
  {
   return CurrentHHMM() >= strategy_session_end_hhmm;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1147\",\"ea\":\"unger-dax-false-break-reversal\"}");
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
