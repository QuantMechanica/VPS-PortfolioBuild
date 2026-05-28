#property strict
#property version   "5.0"
#property description "QM5_1176 Quantpedia Stock ATH ATR Trend Port"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 1176;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_min_history_d1_bars = 500;
input int    strategy_atr_period_d1       = 10;
input double strategy_initial_sl_atr_mult = 2.0;
input double strategy_trail_atr_mult      = 2.0;
input bool   strategy_close_only_exit     = true;
input int    strategy_max_spread_points   = 0;

#define QM5_1176_SYMBOL_COUNT 3

string g_symbols[QM5_1176_SYMBOL_COUNT] = {
   "SP500.DWX",
   "NDX.DWX",
   "WS30.DWX"
};

int g_slots[QM5_1176_SYMBOL_COUNT] = {0, 1, 2};

datetime g_last_entry_bar = 0;
datetime g_last_manage_bar = 0;
datetime g_last_exit_bar = 0;
double   g_last_trail_stop = 0.0;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < QM5_1176_SYMBOL_COUNT; ++i)
      if(g_symbols[i] == _Symbol)
         return i;
   return -1;
  }

int Strategy_SlotForCurrentSymbol()
  {
   const int index = Strategy_CurrentSymbolIndex();
   if(index < 0)
      return qm_magic_slot_offset;
   return g_slots[index];
  }

datetime Strategy_LastClosedD1Time()
  {
   return iTime(_Symbol, PERIOD_D1, 1);
  }

bool Strategy_TradingStatusValid(const string symbol)
  {
   if(!SymbolSelect(symbol, true))
      return false;
   return (SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE) != SYMBOL_TRADE_MODE_DISABLED);
  }

bool Strategy_GetOurPosition(ulong &ticket, double &sl, datetime &opened_at)
  {
   ticket = 0;
   sl = 0.0;
   opened_at = 0;

   const int magic = QM_Magic(qm_ea_id, Strategy_SlotForCurrentSymbol());
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong pos_ticket = PositionGetTicket(i);
      if(pos_ticket == 0 || !PositionSelectByTicket(pos_ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
         continue;

      ticket = pos_ticket;
      sl = PositionGetDouble(POSITION_SL);
      opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

bool Strategy_HasEnoughHistory()
  {
   const int required = MathMax(strategy_min_history_d1_bars, strategy_atr_period_d1 + 5);
   int valid = 0;
   const int bars = Bars(_Symbol, PERIOD_D1);
   if(bars < required + 2)
      return false;

   for(int shift = 1; shift <= bars - 1; ++shift)
     {
      if(iClose(_Symbol, PERIOD_D1, shift) > 0.0)
         ++valid;
      if(valid >= required)
         return true;
     }
   return false;
  }

bool Strategy_ReadHistoricalHighBeforeSignal(double &out_high)
  {
   out_high = 0.0;
   if(!Strategy_HasEnoughHistory())
      return false;

   const int bars = Bars(_Symbol, PERIOD_D1);
   for(int shift = 2; shift <= bars - 1; ++shift)
     {
      const double close = iClose(_Symbol, PERIOD_D1, shift);
      if(close <= 0.0)
         continue;
      if(out_high <= 0.0 || close > out_high)
         out_high = close;
     }

   return (out_high > 0.0);
  }

bool Strategy_IsAllTimeHighSignal()
  {
   double prior_high = 0.0;
   if(!Strategy_ReadHistoricalHighBeforeSignal(prior_high))
      return false;

   const double close1 = iClose(_Symbol, PERIOD_D1, 1);
   if(close1 <= 0.0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tolerance = (point > 0.0) ? (point * 0.5) : 0.0;
   return (close1 + tolerance >= prior_high);
  }

bool Strategy_StopDistanceAllowed(const double entry, const double sl)
  {
   if(entry <= 0.0 || sl <= 0.0 || sl >= entry)
      return false;
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;
   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double stop_points = MathAbs(entry - sl) / point;
   return (stops_level <= 0 || stop_points > (double)stops_level);
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   if(Strategy_CurrentSymbolIndex() < 0)
      return true;
   if(!Strategy_TradingStatusValid(_Symbol))
      return true;
   if(strategy_atr_period_d1 <= 0 || strategy_initial_sl_atr_mult <= 0.0 || strategy_trail_atr_mult <= 0.0)
      return true;
   if(strategy_min_history_d1_bars < 2)
      return true;
   if(strategy_max_spread_points > 0 && SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > strategy_max_spread_points)
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
   req.symbol_slot = Strategy_SlotForCurrentSymbol();
   req.expiration_seconds = 0;

   const datetime signal_bar = Strategy_LastClosedD1Time();
   if(signal_bar <= 0 || g_last_entry_bar == signal_bar)
      return false;

   ulong ticket = 0;
   double current_sl = 0.0;
   datetime opened_at = 0;
   if(Strategy_GetOurPosition(ticket, current_sl, opened_at))
      return false;

   if(!Strategy_IsAllTimeHighSignal())
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(entry <= 0.0 || atr <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr, strategy_initial_sl_atr_mult);
   if(!Strategy_StopDistanceAllowed(entry, sl))
      return false;

   req.price = entry;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = "QM5_1176_STOCK_ATH_ATR_LONG";

   g_last_entry_bar = signal_bar;
   g_last_trail_stop = sl;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   ulong ticket = 0;
   double current_sl = 0.0;
   datetime opened_at = 0;
   if(!Strategy_GetOurPosition(ticket, current_sl, opened_at))
      return;

   const datetime closed_bar = Strategy_LastClosedD1Time();
   if(closed_bar <= 0 || g_last_manage_bar == closed_bar)
      return;

   const double close1 = iClose(_Symbol, PERIOD_D1, 1);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(close1 <= 0.0 || atr <= 0.0)
      return;

   const double raw_trail = close1 - atr * strategy_trail_atr_mult;
   const double trail = QM_TM_NormalizePrice(_Symbol, raw_trail);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(trail <= 0.0 || point <= 0.0)
      return;

   const bool improves = (current_sl <= 0.0 || trail > current_sl + point * 0.5);
   if(improves)
     {
      if(QM_TM_MoveSL(ticket, trail, "QM5_1176_D1_ATR_TRAIL"))
        {
         g_last_trail_stop = trail;
         g_last_manage_bar = closed_bar;
        }
      return;
     }

   if(current_sl > 0.0)
      g_last_trail_stop = current_sl;
   g_last_manage_bar = closed_bar;
  }

bool Strategy_ExitSignal()
  {
   if(!strategy_close_only_exit)
      return false;

   ulong ticket = 0;
   double current_sl = 0.0;
   datetime opened_at = 0;
   if(!Strategy_GetOurPosition(ticket, current_sl, opened_at))
      return false;

   const datetime closed_bar = Strategy_LastClosedD1Time();
   if(closed_bar <= 0 || g_last_exit_bar == closed_bar)
      return false;

   const double close1 = iClose(_Symbol, PERIOD_D1, 1);
   const double trail = (g_last_trail_stop > 0.0) ? g_last_trail_stop : current_sl;
   if(close1 <= 0.0 || trail <= 0.0)
      return false;

   if(close1 < trail)
     {
      g_last_exit_bar = closed_bar;
      return true;
     }

   return false;
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

   QM_SymbolGuardInit(g_symbols);
   QM_BasketWarmupHistory(g_symbols, PERIOD_D1, MathMax(strategy_min_history_d1_bars, strategy_atr_period_d1 + 5));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1176_qp-stock-ath-atr-trend\"}");
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
      const int magic = QM_Magic(qm_ea_id, Strategy_SlotForCurrentSymbol());
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
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
