#property strict
#property version   "5.0"
#property description "QM5_12601 EIA XNG Hurricane Supply-Risk Breakout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12601 - EIA XNG Hurricane-Season Supply-Risk Breakout
// -----------------------------------------------------------------------------
// D1 structural natural-gas sleeve:
//   - trades only during the Atlantic hurricane peak window, Aug 15 to Oct 15
//   - follows upside XNGUSD.DWX D1 channel breakouts with SMA/range confirmation
//   - exits on season end, failed breakout, SMA failure, max hold, or ATR stop
// Runtime uses MT5 OHLC and broker calendar only; no weather, EIA, LNG, or API.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12601;
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
input int    strategy_entry_channel       = 20;
input int    strategy_exit_channel        = 10;
input int    strategy_trend_period        = 63;
input int    strategy_atr_period          = 20;
input double strategy_min_range_atr       = 0.75;
input double strategy_min_close_location  = 0.65;
input double strategy_atr_sl_mult         = 3.5;
input int    strategy_max_hold_days       = 12;
input int    strategy_max_spread_points   = 2500;

int g_last_signal_day_key = 0;

bool Strategy_IsXngD1()
  {
   return (_Symbol == "XNGUSD.DWX" && _Period == PERIOD_D1);
  }

int Strategy_DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

bool Strategy_InPeakHurricaneWindow(const datetime t)
  {
   if(t <= 0)
      return false;

   MqlDateTime dt;
   TimeToStruct(t, dt);
   if(dt.mon == 8 && dt.day >= 15)
      return true;
   if(dt.mon == 9)
      return true;
   if(dt.mon == 10 && dt.day <= 15)
      return true;
   return false;
  }

bool Strategy_HasOpenPosition()
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

bool Strategy_LoadClosedState(double &close_last,
                              double &entry_high,
                              double &entry_low,
                              double &exit_low,
                              double &atr_last,
                              double &sma_last,
                              double &range_last,
                              double &close_location,
                              datetime &signal_time,
                              int &signal_day_key)
  {
   const int max_channel = MathMax(strategy_entry_channel, strategy_exit_channel);
   const int bars_needed = max_channel + 2;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_D1, 1, bars_needed, rates) < bars_needed) // perf-allowed: D1 hurricane-window channel/range state.
      return false;

   signal_time = rates[0].time;
   signal_day_key = Strategy_DayKey(signal_time);
   close_last = rates[0].close;
   const double high_last = rates[0].high;
   const double low_last = rates[0].low;

   entry_high = rates[1].high;
   entry_low = rates[1].low;
   for(int i = 2; i <= strategy_entry_channel; ++i)
     {
      if(rates[i].high > entry_high)
         entry_high = rates[i].high;
      if(rates[i].low < entry_low)
         entry_low = rates[i].low;
     }

   exit_low = rates[1].low;
   for(int j = 2; j <= strategy_exit_channel; ++j)
     {
      if(rates[j].low < exit_low)
         exit_low = rates[j].low;
     }

   atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   sma_last = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_period, 1, PRICE_CLOSE);
   range_last = high_last - low_last;

   if(signal_time <= 0 || close_last <= 0.0 || entry_high <= 0.0 ||
      entry_low <= 0.0 || exit_low <= 0.0)
      return false;
   if(atr_last <= 0.0 || sma_last <= 0.0 || range_last <= 0.0)
      return false;

   close_location = (close_last - low_last) / range_last;
   return MathIsValidNumber(close_location);
  }

void Strategy_CloseOpenPositionsIfNeeded()
  {
   double close_last = 0.0;
   double entry_high = 0.0;
   double entry_low = 0.0;
   double exit_low = 0.0;
   double atr_last = 0.0;
   double sma_last = 0.0;
   double range_last = 0.0;
   double close_location = 0.0;
   datetime signal_time = 0;
   int signal_day_key = 0;
   const bool have_state = Strategy_LoadClosedState(close_last, entry_high, entry_low,
                                                    exit_low, atr_last, sma_last,
                                                    range_last, close_location,
                                                    signal_time, signal_day_key);

   const bool in_window = Strategy_InPeakHurricaneWindow(TimeCurrent());
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   const int hold_seconds = MathMax(1, strategy_max_hold_days) * 86400;

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
      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      bool should_close = (!in_window);
      if(opened > 0 && now - opened >= hold_seconds)
         should_close = true;
      if(have_state && pos_type == POSITION_TYPE_BUY)
        {
         if(close_last < exit_low || close_last < sma_last)
            should_close = true;
        }
      else if(pos_type != POSITION_TYPE_BUY)
        {
         should_close = true;
        }

      if(should_close)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsXngD1())
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_entry_channel < 2 || strategy_exit_channel < 2 || strategy_exit_channel > strategy_entry_channel)
      return true;
   if(strategy_trend_period <= 1 || strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_min_range_atr <= 0.0 || strategy_min_close_location <= 0.5 || strategy_min_close_location > 1.0)
      return true;
   if(strategy_max_hold_days <= 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_12601_EIA_XNG_HURR_BRK";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   Strategy_CloseOpenPositionsIfNeeded();

   if(Strategy_HasOpenPosition())
      return false;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return false;
     }

   double close_last = 0.0;
   double entry_high = 0.0;
   double entry_low = 0.0;
   double exit_low = 0.0;
   double atr_last = 0.0;
   double sma_last = 0.0;
   double range_last = 0.0;
   double close_location = 0.0;
   datetime signal_time = 0;
   int signal_day_key = 0;
   if(!Strategy_LoadClosedState(close_last, entry_high, entry_low, exit_low,
                                atr_last, sma_last, range_last, close_location,
                                signal_time, signal_day_key))
      return false;

   if(signal_day_key <= 0 || signal_day_key == g_last_signal_day_key)
      return false;
   if(!Strategy_InPeakHurricaneWindow(signal_time))
      return false;
   if(range_last < strategy_min_range_atr * atr_last)
      return false;
   if(close_last <= entry_high || close_last <= sma_last)
      return false;
   if(close_location < strategy_min_close_location)
      return false;

   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.reason = "XNG_HURRICANE_SUPPLY_BREAKOUT_LONG";
   g_last_signal_day_key = signal_day_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   Strategy_CloseOpenPositionsIfNeeded();
  }

bool Strategy_ExitSignal()
  {
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12601\",\"ea\":\"eia-xng-hurr-brk\"}");
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

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();
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
