#property strict
#property version   "5.0"
#property description "QM5_10321 Half-Hour Return Periodicity Continuation"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_10321 halfhour-cont
// Strategy card: D:\QM\strategy_farm\artifacts\cards_approved\QM5_10321_halfhour-cont.md
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10321;
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
input int    strategy_slot_minutes        = 30;
input int    strategy_session_start_hhmm  = 0;
input int    strategy_session_end_hhmm    = 2400;
input int    strategy_history_days        = 10;
input int    strategy_persistence_days    = 5;
input int    strategy_lookback_bars       = 800;
input int    strategy_atr_period          = 14;
input double strategy_atr_sl_mult         = 0.50;
input double strategy_spread_median_mult  = 1.50;

int HhmmToMinutes(const int hhmm)
  {
   const int hours = hhmm / 100;
   const int mins = hhmm % 100;
   if(hours < 0 || hours > 24 || mins < 0 || mins > 59)
      return -1;
   if(hours == 24 && mins != 0)
      return -1;
   return hours * 60 + mins;
  }

int MinuteOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

bool IsEligibleSlot(const datetime slot_time)
  {
   const int start_min = HhmmToMinutes(strategy_session_start_hhmm);
   const int end_min = HhmmToMinutes(strategy_session_end_hhmm);
   const int slot = MathMax(1, strategy_slot_minutes);
   if(start_min < 0 || end_min < 0 || end_min <= start_min)
      return false;

   const int minute = MinuteOfDay(slot_time);
   if(minute < start_min || minute >= end_min)
      return false;

   if(minute < start_min + slot)
      return false;
   if(minute >= end_min - slot)
      return false;

   return true;
  }

void SortIntValues(int &values[], const int count)
  {
   for(int i = 1; i < count; ++i)
     {
      const int key = values[i];
      int j = i - 1;
      while(j >= 0 && values[j] > key)
        {
         values[j + 1] = values[j];
         --j;
        }
      values[j + 1] = key;
     }
  }

double MedianSpread(const int &values[], const int count)
  {
   if(count <= 0)
      return 0.0;

   int sorted[];
   ArrayResize(sorted, count);
   for(int i = 0; i < count; ++i)
      sorted[i] = values[i];
   SortIntValues(sorted, count);

   if((count % 2) == 1)
      return (double)sorted[count / 2];
   return ((double)sorted[(count / 2) - 1] + (double)sorted[count / 2]) / 2.0;
  }

bool HasOurOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

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

bool ReadSameSlotState(double &lag1_return,
                       double &avg_return,
                       double &median_spread,
                       int &history_count)
  {
   lag1_return = 0.0;
   avg_return = 0.0;
   median_spread = 0.0;
   history_count = 0;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int max_bars = MathMax(strategy_lookback_bars, 400);
   const int copied = CopyRates(_Symbol, PERIOD_M30, 0, max_bars, rates); // perf-allowed: same-slot history scan runs only from Strategy_EntrySignal after the framework closed-bar gate.
   if(copied < 2)
      return false;

   const datetime current_slot_time = rates[0].time;
   if(!IsEligibleSlot(current_slot_time))
      return false;

   const int current_slot_minute = MinuteOfDay(current_slot_time);
   const int required_history = MathMax(1, strategy_history_days);
   const int persistence_days = MathMax(1, strategy_persistence_days);
   int spread_samples[];
   ArrayResize(spread_samples, 0);

   double sum = 0.0;
   int persistence_count = 0;

   for(int i = 1; i < copied; ++i)
     {
      if(MinuteOfDay(rates[i].time) != current_slot_minute)
         continue;
      if(rates[i].open <= 0.0 || rates[i].close <= 0.0)
         continue;

      const double slot_ret = (rates[i].close - rates[i].open) / rates[i].open;
      if(history_count == 0)
         lag1_return = slot_ret;
      if(persistence_count < persistence_days)
        {
         sum += slot_ret;
         ++persistence_count;
        }

      if(rates[i].spread > 0)
        {
         const int n = ArraySize(spread_samples);
         ArrayResize(spread_samples, n + 1);
         spread_samples[n] = rates[i].spread;
        }

      ++history_count;
      if(history_count >= required_history && persistence_count >= persistence_days)
         break;
     }

   if(history_count < required_history || persistence_count < persistence_days)
      return false;

   avg_return = sum / (double)persistence_count;
   median_spread = MedianSpread(spread_samples, ArraySize(spread_samples));
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_M30)
      return true;
   if(strategy_slot_minutes != 30)
      return true;
   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_history_days < 1 || strategy_persistence_days < 1)
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

   if(HasOurOpenPosition())
      return false;

   double lag1_return = 0.0;
   double avg_return = 0.0;
   double median_spread = 0.0;
   int history_count = 0;
   if(!ReadSameSlotState(lag1_return, avg_return, median_spread, history_count))
      return false;

   if(median_spread > 0.0)
     {
      const double current_spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(current_spread > median_spread * strategy_spread_median_mult)
         return false;
     }

   QM_OrderType side = QM_BUY;
   if(lag1_return > 0.0 && avg_return >= 0.0)
      side = QM_BUY;
   else if(lag1_return < 0.0 && avg_return <= 0.0)
      side = QM_SELL;
   else
      return false;

   const double entry_price = (side == QM_BUY)
                              ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                              : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_price <= 0.0)
      return false;

   req.type = side;
   req.sl = QM_StopATR(_Symbol, side, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   req.tp = 0.0;
   req.reason = (side == QM_BUY) ? "HALFHOUR_CONT_LONG" : "HALFHOUR_CONT_SHORT";

   if(req.sl <= 0.0)
      return false;
   if(side == QM_BUY && req.sl >= entry_price)
      return false;
   if(side == QM_SELL && req.sl <= entry_price)
      return false;

   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no break-even, trailing, partial close, or pyramiding.
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const datetime now = TimeCurrent();
   const int max_hold_seconds = MathMax(1, strategy_slot_minutes) * 60;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && now - opened >= max_hold_seconds)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10321_halfhour-cont\"}");
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
