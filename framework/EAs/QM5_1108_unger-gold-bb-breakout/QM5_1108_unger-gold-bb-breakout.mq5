#property strict
#property version   "5.0"
#property description "QM5_1108 Unger Gold Bollinger Band Breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1108;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal    = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance  = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_bb_period             = 40;
input double strategy_bb_deviation          = 2.0;
input int    strategy_atr_period            = 14;
input double strategy_atr_sl_mult           = 2.0;
input bool   strategy_use_rr_take_profit    = true;
input double strategy_take_profit_rr        = 3.0;
input int    strategy_max_hold_sessions     = 7;
input int    strategy_session_median_days   = 40;
input bool   strategy_use_compression_filter = true;

const string STRATEGY_SYMBOL = "XAUUSD.DWX";

datetime g_last_entry_bar = 0;

bool Strategy_HasOpenPosition()
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

double Strategy_Median(double &values[], const int count)
  {
   if(count <= 0)
      return 0.0;

   for(int i = 0; i < count - 1; ++i)
      for(int j = i + 1; j < count; ++j)
         if(values[j] < values[i])
           {
            const double tmp = values[i];
            values[i] = values[j];
            values[j] = tmp;
           }

   if((count % 2) == 1)
      return values[count / 2];
   return 0.5 * (values[(count / 2) - 1] + values[count / 2]);
  }

bool Strategy_PreviousSessionCompressed()
  {
   if(!strategy_use_compression_filter)
      return true;
   if(strategy_session_median_days <= 0)
      return false;

   const double prev_high = iHigh(_Symbol, PERIOD_D1, 1);
   const double prev_low = iLow(_Symbol, PERIOD_D1, 1);
   const double prev_range = prev_high - prev_low;
   if(prev_high <= 0.0 || prev_low <= 0.0 || prev_range <= 0.0)
      return false;

   double ranges[];
   ArrayResize(ranges, strategy_session_median_days);
   int count = 0;
   for(int shift = 2; shift <= strategy_session_median_days + 1; ++shift)
     {
      const double high_i = iHigh(_Symbol, PERIOD_D1, shift);
      const double low_i = iLow(_Symbol, PERIOD_D1, shift);
      const double range_i = high_i - low_i;
      if(high_i <= 0.0 || low_i <= 0.0 || range_i <= 0.0)
         continue;
      ranges[count] = range_i;
      ++count;
     }

   if(count < MathMin(strategy_session_median_days, 20))
      return false;

   const double median_range = Strategy_Median(ranges, count);
   return (median_range > 0.0 && prev_range < median_range);
  }

bool Strategy_StopDistanceAllowed(const double entry, const double sl)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || entry <= 0.0 || sl <= 0.0 || sl >= entry)
      return false;

   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double stop_points = MathAbs(entry - sl) / point;
   return (stops_level <= 0 || stop_points > (double)stops_level);
  }

bool Strategy_NoTradeFilter()
  {
   if(_Symbol != STRATEGY_SYMBOL)
      return true;
   if(_Period != PERIOD_H1)
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_bb_period <= 1 || strategy_bb_deviation <= 0.0)
      return true;
   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_use_rr_take_profit && strategy_take_profit_rr <= 0.0)
      return true;
   if(strategy_max_hold_sessions <= 0 || strategy_session_median_days <= 0)
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

   const datetime signal_bar = iTime(_Symbol, PERIOD_H1, 1);
   if(signal_bar <= 0 || signal_bar == g_last_entry_bar)
      return false;
   g_last_entry_bar = signal_bar;

   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_PreviousSessionCompressed())
      return false;

   const double close1 = iClose(_Symbol, PERIOD_H1, 1);
   const double upper1 = QM_BB_Upper(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_deviation, 1);
   if(close1 <= 0.0 || upper1 <= 0.0 || close1 <= upper1)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   const double entry = QM_EntryMarketPrice(QM_BUY);
   if(atr <= 0.0 || entry <= 0.0)
      return false;

   req.price = entry;
   req.sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr, strategy_atr_sl_mult);
   if(!Strategy_StopDistanceAllowed(entry, req.sl))
      return false;

   if(strategy_use_rr_take_profit)
      req.tp = QM_TakeRR(_Symbol, QM_BUY, entry, req.sl, strategy_take_profit_rr);

   req.reason = "UNGER_GOLD_BB_BREAKOUT_LONG";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed ATR stop, optional fixed-R TP, no trailing or partial close.
  }

bool Strategy_ExitSignal()
  {
   if(_Period != PERIOD_H1)
      return false;

   const datetime signal_bar = iTime(_Symbol, PERIOD_H1, 1);
   if(signal_bar <= 0)
      return false;

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

      const datetime opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened_at <= 0)
         continue;

      const int open_shift = iBarShift(_Symbol, PERIOD_H1, opened_at, false);
      if(open_shift >= 2)
        {
         const double close1 = iClose(_Symbol, PERIOD_H1, 1);
         const double middle1 = QM_BB_Middle(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_deviation, 1);
         if(close1 > 0.0 && middle1 > 0.0 && close1 <= middle1)
            return true;
        }

      if(strategy_max_hold_sessions > 0)
        {
         const int max_seconds = strategy_max_hold_sessions * 24 * 3600;
         if((signal_bar - opened_at) >= max_seconds)
            return true;
        }
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1108\",\"ea\":\"unger-gold-bb-breakout\"}");
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
