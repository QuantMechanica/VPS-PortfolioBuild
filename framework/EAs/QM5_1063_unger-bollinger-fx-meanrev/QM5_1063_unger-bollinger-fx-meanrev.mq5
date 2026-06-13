#property strict
#property version   "5.0"
#property description "QM5_1063 Unger Bollinger FX Mean Reversion"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1063;
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
input ENUM_TIMEFRAMES strategy_signal_tf          = PERIOD_H1;
input int             strategy_bb_period          = 20;
input double          strategy_bb_deviation       = 2.0;
input int             strategy_adx_period         = 14;
input int             strategy_adx_median_bars    = 100;
input double          strategy_adx_gate           = 20.0;
input int             strategy_atr_period         = 14;
input double          strategy_sl_atr_mult        = 1.5;
input int             strategy_max_hold_bars      = 12;
input int             strategy_spread_median_days = 20;
input double          strategy_spread_mult        = 2.0;

double g_cached_median_spread_points = 0.0;

bool HasOurOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = 0; i < PositionsTotal(); ++i)
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

bool IsWeekendEntryBlock(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);

   if(dt.day_of_week == 5 && dt.hour >= 21)
      return true;
   if(dt.day_of_week == 6)
      return true;
   if(dt.day_of_week == 0 && dt.hour < 22)
      return true;

   return false;
  }

double MedianFromArray(double &values[], const int count)
  {
   if(count <= 0)
      return 0.0;

   ArrayResize(values, count);
   ArraySort(values);
   const int mid = count / 2;
   if((count % 2) == 1)
      return values[mid];
   return 0.5 * (values[mid - 1] + values[mid]);
  }

double MedianADX(const int bars)
  {
   if(bars <= 0)
      return 0.0;

   double values[];
   ArrayResize(values, bars);
   int count = 0;
   for(int shift = 1; shift <= bars; ++shift)
     {
      const double adx = QM_ADX(_Symbol, strategy_signal_tf, strategy_adx_period, shift);
      if(adx <= 0.0)
         continue;
      values[count] = adx;
      count++;
     }

   return MedianFromArray(values, count);
  }

void RefreshMedianSpreadIfNeeded()
  {
   if(g_cached_median_spread_points > 0.0 && !QM_IsNewBar(_Symbol, PERIOD_D1))
      return;

   if(strategy_spread_median_days <= 0)
      return;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   // perf-allowed: D1 spread baseline is refreshed only on the framework D1 new-bar gate.
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, strategy_spread_median_days, rates);
   if(copied <= 0)
      return;

   double spreads[];
   ArrayResize(spreads, copied);
   int count = 0;
   for(int i = 0; i < copied; ++i)
     {
      if(rates[i].spread <= 0)
         continue;
      spreads[count] = (double)rates[i].spread;
      count++;
     }

   const double median_spread = MedianFromArray(spreads, count);
   if(median_spread > 0.0)
      g_cached_median_spread_points = median_spread;
  }

bool SpreadEntryBlock()
  {
   RefreshMedianSpreadIfNeeded();
   if(g_cached_median_spread_points <= 0.0 || strategy_spread_mult <= 0.0)
      return false;

   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0)
      return false;

   return ((double)current_spread > strategy_spread_mult * g_cached_median_spread_points);
  }

bool Strategy_NoTradeFilter()
  {
   if(HasOurOpenPosition())
      return false;

   if(IsWeekendEntryBlock(TimeCurrent()))
      return true;

   if(SpreadEntryBlock())
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

   if(strategy_bb_period <= 1 || strategy_bb_deviation <= 0.0 ||
      strategy_adx_period <= 1 || strategy_adx_median_bars <= 0 ||
      strategy_atr_period <= 0 || strategy_sl_atr_mult <= 0.0)
      return false;

   if(HasOurOpenPosition())
      return false;

   const double close_1 = iClose(_Symbol, strategy_signal_tf, 1); // perf-allowed: fixed closed-bar close; no QM close reader exists.
   const double upper = QM_BB_Upper(_Symbol, strategy_signal_tf, strategy_bb_period, strategy_bb_deviation, 1);
   const double lower = QM_BB_Lower(_Symbol, strategy_signal_tf, strategy_bb_period, strategy_bb_deviation, 1);
   const double adx = QM_ADX(_Symbol, strategy_signal_tf, strategy_adx_period, 1);
   const double median_adx = MedianADX(strategy_adx_median_bars);
   if(close_1 <= 0.0 || upper <= 0.0 || lower <= 0.0 || adx <= 0.0 || median_adx <= 0.0)
      return false;

   const double effective_adx_gate = MathMin(strategy_adx_gate, median_adx);
   if(adx >= effective_adx_gate)
      return false;

   QM_OrderType side = QM_BUY;
   double entry_price = 0.0;
   if(close_1 > upper)
     {
      side = QM_SELL;
      entry_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      req.reason = "BB_FADE_SHORT";
     }
   else if(close_1 < lower)
     {
      side = QM_BUY;
      entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.reason = "BB_FADE_LONG";
     }
   else
      return false;

   if(entry_price <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, side, entry_price, strategy_atr_period, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, or pyramiding.
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const double close_1 = iClose(_Symbol, strategy_signal_tf, 1); // perf-allowed: fixed closed-bar close for middle-band exit.
   const double close_2 = iClose(_Symbol, strategy_signal_tf, 2); // perf-allowed: fixed prior closed-bar close for middle-band cross.
   const double middle_1 = QM_BB_Middle(_Symbol, strategy_signal_tf, strategy_bb_period, strategy_bb_deviation, 1);
   const double middle_2 = QM_BB_Middle(_Symbol, strategy_signal_tf, strategy_bb_period, strategy_bb_deviation, 2);
   const int hold_seconds = strategy_max_hold_bars * PeriodSeconds(strategy_signal_tf);
   if(close_1 <= 0.0 || close_2 <= 0.0 || middle_1 <= 0.0 || middle_2 <= 0.0)
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

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && close_2 < middle_2 && close_1 >= middle_1)
         return true;
      if(ptype == POSITION_TYPE_SELL && close_2 > middle_2 && close_1 <= middle_1)
         return true;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(hold_seconds > 0 && open_time > 0 && TimeCurrent() >= open_time + hold_seconds)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1063_unger-bollinger-fx-meanrev\"}");
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
