#property strict
#property version   "5.0"
#property description "QM5_1190 Quantpedia Index Double-Bottom Breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 1190;
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
input int    strategy_min_history_d1_bars = 220;
input int    strategy_local_low_window    = 5;
input int    strategy_min_low_gap_days    = 5;
input int    strategy_max_low_gap_days    = 60;
input int    strategy_atr_period_d1       = 20;
input double strategy_low_atr_tolerance   = 1.0;
input double strategy_stop_atr_mult       = 0.5;
input double strategy_min_neck_atr_mult   = 0.5;
input int    strategy_sma_exit_period     = 50;
input int    strategy_max_hold_bars       = 20;
input int    strategy_max_spread_points   = 0;

#define QM5_1190_SYMBOL_COUNT 3

string g_symbols[QM5_1190_SYMBOL_COUNT] = {
   "SP500.DWX",
   "NDX.DWX",
   "WS30.DWX"
};

int g_slots[QM5_1190_SYMBOL_COUNT] = {0, 1, 2};

datetime g_last_entry_bar = 0;
datetime g_last_exit_bar = 0;
datetime g_last_pattern_first = 0;
datetime g_last_pattern_second = 0;
double   g_last_pattern_neckline = 0.0;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < QM5_1190_SYMBOL_COUNT; ++i)
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

bool Strategy_GetOurPosition(ulong &ticket, datetime &opened_at)
  {
   ticket = 0;
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
      opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

bool Strategy_IsLocalLow(const int shift, const int half_window)
  {
   const double candidate = iLow(_Symbol, PERIOD_D1, shift);
   if(candidate <= 0.0)
      return false;

   for(int offset = -half_window; offset <= half_window; ++offset)
     {
      if(offset == 0)
         continue;
      const double other = iLow(_Symbol, PERIOD_D1, shift + offset);
      if(other <= 0.0)
         return false;
      if(other < candidate)
         return false;
     }

   return true;
  }

double Strategy_HighestHighBetween(const int newer_shift, const int older_shift)
  {
   double highest = 0.0;
   for(int shift = newer_shift + 1; shift <= older_shift - 1; ++shift)
     {
      const double high = iHigh(_Symbol, PERIOD_D1, shift);
      if(high <= 0.0)
         return 0.0;
      if(highest <= 0.0 || high > highest)
         highest = high;
     }
   return highest;
  }

bool Strategy_FindDoubleBottom(double &neckline, double &second_low, double &stop_price,
                               datetime &first_low_time, datetime &second_low_time)
  {
   neckline = 0.0;
   second_low = 0.0;
   stop_price = 0.0;
   first_low_time = 0;
   second_low_time = 0;

   const int half_window = MathMax(1, strategy_local_low_window / 2);
   const int min_gap = MathMax(1, strategy_min_low_gap_days);
   const int max_gap = MathMax(min_gap, strategy_max_low_gap_days);
   const int bars = Bars(_Symbol, PERIOD_D1);
   const int required = MathMax(strategy_min_history_d1_bars, max_gap + strategy_atr_period_d1 + half_window + 10);
   if(bars < required)
      return false;

   for(int second_shift = half_window + 1; second_shift <= max_gap + half_window + 2; ++second_shift)
     {
      if(!Strategy_IsLocalLow(second_shift, half_window))
         continue;

      const double low2 = iLow(_Symbol, PERIOD_D1, second_shift);
      const double atr2 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, second_shift);
      if(low2 <= 0.0 || atr2 <= 0.0)
         continue;

      for(int first_shift = second_shift + min_gap; first_shift <= second_shift + max_gap; ++first_shift)
        {
         if(first_shift + half_window >= bars)
            break;
         if(!Strategy_IsLocalLow(first_shift, half_window))
            continue;

         const double low1 = iLow(_Symbol, PERIOD_D1, first_shift);
         if(low1 <= 0.0)
            continue;
         if(MathAbs(low2 - low1) > atr2 * strategy_low_atr_tolerance)
            continue;

         const double candidate_neck = Strategy_HighestHighBetween(second_shift, first_shift);
         if(candidate_neck <= 0.0)
            continue;
         if(candidate_neck - low2 < atr2 * strategy_min_neck_atr_mult)
            continue;

         const double close1 = iClose(_Symbol, PERIOD_D1, 1);
         const double close2 = iClose(_Symbol, PERIOD_D1, 2);
         if(close1 <= candidate_neck || close2 > candidate_neck)
            continue;

         neckline = candidate_neck;
         second_low = low2;
         stop_price = QM_TM_NormalizePrice(_Symbol, low2 - atr2 * strategy_stop_atr_mult);
         first_low_time = iTime(_Symbol, PERIOD_D1, first_shift);
         second_low_time = iTime(_Symbol, PERIOD_D1, second_shift);
         return (stop_price > 0.0 && stop_price < close1);
        }
     }

   return false;
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

int Strategy_PositionAgeBars(const datetime opened_at)
  {
   if(opened_at <= 0)
      return 0;
   const int shift = iBarShift(_Symbol, PERIOD_D1, opened_at, false);
   if(shift < 0)
      return 0;
   return shift;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   if(Strategy_CurrentSymbolIndex() < 0)
      return true;
   if(!Strategy_TradingStatusValid(_Symbol))
      return true;
   if(strategy_local_low_window < 3 || (strategy_local_low_window % 2) == 0)
      return true;
   if(strategy_min_low_gap_days < 1 || strategy_max_low_gap_days < strategy_min_low_gap_days)
      return true;
   if(strategy_atr_period_d1 <= 0 || strategy_low_atr_tolerance <= 0.0 || strategy_stop_atr_mult <= 0.0)
      return true;
   if(strategy_min_neck_atr_mult <= 0.0 || strategy_sma_exit_period <= 0 || strategy_max_hold_bars <= 0)
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
   datetime opened_at = 0;
   if(Strategy_GetOurPosition(ticket, opened_at))
      return false;

   double neckline = 0.0;
   double second_low = 0.0;
   double stop_price = 0.0;
   datetime first_low_time = 0;
   datetime second_low_time = 0;
   if(!Strategy_FindDoubleBottom(neckline, second_low, stop_price, first_low_time, second_low_time))
      return false;

   if(g_last_pattern_first == first_low_time &&
      g_last_pattern_second == second_low_time &&
      MathAbs(g_last_pattern_neckline - neckline) <= SymbolInfoDouble(_Symbol, SYMBOL_POINT))
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(!Strategy_StopDistanceAllowed(entry, stop_price))
      return false;

   req.price = entry;
   req.sl = stop_price;
   req.tp = 0.0;
   req.reason = "QM5_1190_INDEX_DOUBLE_BOTTOM_LONG";

   g_last_entry_bar = signal_bar;
   g_last_pattern_first = first_low_time;
   g_last_pattern_second = second_low_time;
   g_last_pattern_neckline = neckline;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   datetime opened_at = 0;
   if(!Strategy_GetOurPosition(ticket, opened_at))
      return false;

   const datetime closed_bar = Strategy_LastClosedD1Time();
   if(closed_bar <= 0 || g_last_exit_bar == closed_bar)
      return false;

   const double close1 = iClose(_Symbol, PERIOD_D1, 1);
   const double sma = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_exit_period, 1);
   if(close1 <= 0.0 || sma <= 0.0)
      return false;

   if(Strategy_PositionAgeBars(opened_at) >= strategy_max_hold_bars || close1 < sma)
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
   QM_BasketWarmupHistory(g_symbols, PERIOD_D1, MathMax(strategy_min_history_d1_bars, strategy_max_low_gap_days + strategy_sma_exit_period + strategy_atr_period_d1));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1190_qp-index-double-bottom\"}");
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
         const ulong pos_ticket = PositionGetTicket(i);
         if(pos_ticket == 0 || !PositionSelectByTicket(pos_ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(pos_ticket, QM_EXIT_STRATEGY);
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
