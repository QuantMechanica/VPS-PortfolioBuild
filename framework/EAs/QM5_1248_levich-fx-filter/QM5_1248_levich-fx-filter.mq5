#property strict
#property version   "5.0"
#property description "QM5_1248 Levich-Thomas FX percent-filter rule"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1248;
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
input ENUM_TIMEFRAMES strategy_timeframe       = PERIOD_H1;
input double          strategy_filter_pct      = 0.005;
input int             strategy_reference_bars  = 240;
input int             strategy_atr_period      = 48;
input double          strategy_stop_atr_mult   = 2.0;
input int             strategy_spread_days     = 20;
input double          strategy_spread_mult     = 2.5;
input bool            strategy_allow_reversal  = false;
input int             strategy_min_history_bars = 260;
input int             strategy_trade_start_hour_sun = 23;
input int             strategy_trade_end_hour_fri   = 18;

#define QM5_1248_SYMBOL_COUNT 4

const string STRATEGY_SYMBOLS[QM5_1248_SYMBOL_COUNT] =
  {
   "EURUSD.DWX",
   "GBPUSD.DWX",
   "USDJPY.DWX",
   "USDCHF.DWX"
  };

datetime g_last_entry_bar = 0;
datetime g_last_exit_bar  = 0;
datetime g_reference_bar   = 0;
double   g_reference_low   = 0.0;
double   g_reference_high  = 0.0;
bool     g_reference_ready = false;

int Strategy_CurrentSymbolSlot()
  {
   for(int i = 0; i < QM5_1248_SYMBOL_COUNT; ++i)
      if(_Symbol == STRATEGY_SYMBOLS[i])
         return i;
   return -1;
  }

bool Strategy_SelectOurPosition(ulong &ticket, ENUM_POSITION_TYPE &ptype, datetime &open_time)
  {
   ticket = 0;
   ptype = POSITION_TYPE_BUY;
   open_time = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

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
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

bool Strategy_TradingWindowOpen()
  {
   const datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);

   if(dt.day_of_week == 0)
      return (dt.hour >= strategy_trade_start_hour_sun);
   if(dt.day_of_week >= 1 && dt.day_of_week <= 4)
      return true;
   if(dt.day_of_week == 5)
      return (dt.hour < strategy_trade_end_hour_fri);
   return false;
  }

double Strategy_MedianSpreadForEntryHour()
  {
   if(strategy_spread_days <= 0)
      return 0.0;

   const datetime signal_time = iTime(_Symbol, strategy_timeframe, 1);
   if(signal_time <= 0)
      return 0.0;

   MqlDateTime signal_dt;
   TimeToStruct(signal_time, signal_dt);

   const int max_shift = MathMax(1, strategy_spread_days * 24);
   double values[];
   ArrayResize(values, max_shift);
   int count = 0;

   for(int shift = 1; shift <= max_shift; ++shift)
     {
      const datetime t = iTime(_Symbol, strategy_timeframe, shift);
      if(t <= 0)
         continue;

      MqlDateTime dt;
      TimeToStruct(t, dt);
      if(dt.hour != signal_dt.hour)
         continue;

      const double spread = (double)iSpread(_Symbol, strategy_timeframe, shift);
      if(spread > 0.0)
        {
         values[count] = spread;
         ++count;
        }
     }

   if(count <= 0)
      return 0.0;

   ArrayResize(values, count);
   ArraySort(values);
   const int mid = count / 2;
   if((count % 2) == 1)
      return values[mid];
   return (values[mid - 1] + values[mid]) * 0.5;
  }

bool Strategy_SpreadOk()
  {
   if(strategy_spread_mult <= 0.0)
      return true;

   const double median_spread = Strategy_MedianSpreadForEntryHour();
   if(median_spread <= 0.0)
      return true;

   const double current_spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0.0)
      return false;

   return (current_spread <= median_spread * strategy_spread_mult);
  }

bool Strategy_SeedReference()
  {
   const int lookback = MathMax(2, strategy_reference_bars);
   if(Bars(_Symbol, strategy_timeframe) < MathMax(strategy_min_history_bars, lookback + strategy_atr_period + 5))
      return false;

   g_reference_low = DBL_MAX;
   g_reference_high = -DBL_MAX;
   for(int shift = 1; shift <= lookback; ++shift)
     {
      const double close_i = iClose(_Symbol, strategy_timeframe, shift);
      if(close_i <= 0.0)
         return false;
      if(close_i < g_reference_low)
         g_reference_low = close_i;
      if(close_i > g_reference_high)
         g_reference_high = close_i;
     }

   g_reference_bar = iTime(_Symbol, strategy_timeframe, 1);
   g_reference_ready = (g_reference_low > 0.0 && g_reference_high >= g_reference_low);
   return g_reference_ready;
  }

bool Strategy_UpdateReference()
  {
   if(!g_reference_ready && !Strategy_SeedReference())
      return false;

   const datetime bar_time = iTime(_Symbol, strategy_timeframe, 1);
   const double close_1 = iClose(_Symbol, strategy_timeframe, 1);
   if(bar_time <= 0 || close_1 <= 0.0)
      return false;

   if(bar_time != g_reference_bar)
     {
      if(close_1 < g_reference_low)
         g_reference_low = close_1;
      if(close_1 > g_reference_high)
         g_reference_high = close_1;
      g_reference_bar = bar_time;
     }

   return (g_reference_low > 0.0 && g_reference_high >= g_reference_low);
  }

void Strategy_ResetReference(const double close_value)
  {
   if(close_value <= 0.0)
      return;
   g_reference_low = close_value;
   g_reference_high = close_value;
   g_reference_bar = iTime(_Symbol, strategy_timeframe, 1);
   g_reference_ready = true;
  }

double Strategy_StopForSide(const QM_OrderType side, const double entry)
  {
   const double atr = QM_ATR(_Symbol, strategy_timeframe, MathMax(1, strategy_atr_period), 1);
   if(entry <= 0.0 || atr <= 0.0 || strategy_stop_atr_mult <= 0.0)
      return 0.0;

   return QM_StopATRFromValue(_Symbol, side, entry, atr, strategy_stop_atr_mult);
  }

bool Strategy_StopOk(const QM_OrderType side, const double entry, const double sl)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || entry <= 0.0 || sl <= 0.0)
      return false;
   if(side == QM_BUY && sl >= entry)
      return false;
   if(side == QM_SELL && sl <= entry)
      return false;

   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double stop_points = MathAbs(entry - sl) / point;
   return (stops_level <= 0 || stop_points > (double)stops_level);
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != strategy_timeframe)
      return true;
   if(Strategy_CurrentSymbolSlot() < 0)
      return true;
   if(qm_magic_slot_offset != Strategy_CurrentSymbolSlot())
      return true;
   if(strategy_timeframe != PERIOD_H1 && strategy_timeframe != PERIOD_H4 && strategy_timeframe != PERIOD_D1)
      return true;
   if(strategy_filter_pct <= 0.0 || strategy_filter_pct >= 0.25)
      return true;
   if(strategy_atr_period <= 0 || strategy_stop_atr_mult <= 0.0)
      return true;
   if(!Strategy_TradingWindowOpen())
      return true;

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "LEVICH_FX_FILTER";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const datetime bar_time = iTime(_Symbol, strategy_timeframe, 1);
   if(bar_time <= 0 || bar_time == g_last_entry_bar)
      return false;

   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   datetime open_time;
   if(Strategy_SelectOurPosition(ticket, ptype, open_time))
      return false;
   if(!Strategy_SpreadOk())
      return false;

   if(!Strategy_UpdateReference())
      return false;

   const double close_1 = iClose(_Symbol, strategy_timeframe, 1);
   if(close_1 <= 0.0)
      return false;

   QM_OrderType side = QM_BUY;
   if(close_1 >= g_reference_low * (1.0 + strategy_filter_pct))
      side = QM_BUY;
   else if(close_1 <= g_reference_high * (1.0 - strategy_filter_pct))
      side = QM_SELL;
   else
      return false;

   const double entry = QM_EntryMarketPrice(side);
   const double sl = Strategy_StopForSide(side, entry);
   if(!Strategy_StopOk(side, entry, sl))
      return false;

   req.type = side;
   req.price = entry;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = (side == QM_BUY ? "LEVICH_FILTER_LONG" : "LEVICH_FILTER_SHORT");
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   g_last_entry_bar = bar_time;
   Strategy_ResetReference(close_1);
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   const datetime bar_time = iTime(_Symbol, strategy_timeframe, 1);
   if(bar_time <= 0 || bar_time == g_last_exit_bar)
      return false;

   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   datetime open_time;
   if(!Strategy_SelectOurPosition(ticket, ptype, open_time))
      return false;

   if(!Strategy_UpdateReference())
      return false;

   const double close_1 = iClose(_Symbol, strategy_timeframe, 1);
   if(close_1 <= 0.0)
      return false;

   const bool reverse_short = (ptype == POSITION_TYPE_BUY && close_1 <= g_reference_high * (1.0 - strategy_filter_pct));
   const bool reverse_long = (ptype == POSITION_TYPE_SELL && close_1 >= g_reference_low * (1.0 + strategy_filter_pct));
   if(reverse_short || reverse_long)
     {
      g_last_exit_bar = bar_time;
      Strategy_ResetReference(close_1);
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

   string symbols[QM5_1248_SYMBOL_COUNT];
   for(int i = 0; i < QM5_1248_SYMBOL_COUNT; ++i)
      symbols[i] = STRATEGY_SYMBOLS[i];
   QM_SymbolGuardInit(symbols);
   QM_BasketWarmupHistory(symbols, strategy_timeframe, strategy_min_history_bars + 10);

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1248_levich-fx-filter\"}");
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

   if(!QM_IsNewBar(_Symbol, strategy_timeframe))
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
