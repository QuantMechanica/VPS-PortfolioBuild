#property strict
#property version   "5.0"
#property description "QM5_10705 TradingView PDH/PDL Liquidity Trap"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10705;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours    = 336;
input string qm_news_min_impact         = "high";
input QM_NewsMode qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_atr_period        = 14;
input double strategy_atr_buffer_mult   = 1.0;
input double strategy_min_atr_buffer_mult = 0.5;
input double strategy_rr_target         = 2.0;
input int    strategy_trade_start_hour  = 0;
input int    strategy_trade_end_hour    = 24;
input int    strategy_max_spread_points = 0;
input int    strategy_cash_open_skip_minutes = 0;

int  g_trade_day_key = 0;
bool g_trade_taken_today = false;

int DayKey(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return (dt.year * 10000) + (dt.mon * 100) + dt.day;
  }

void RefreshTradeDay(const datetime bar_time)
  {
   const int key = DayKey(bar_time);
   if(key <= 0)
      return;
   if(key != g_trade_day_key)
     {
      g_trade_day_key = key;
      g_trade_taken_today = false;
     }
  }

bool ReadOneBar(const ENUM_TIMEFRAMES timeframe, const int shift, MqlRates &bar)
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, timeframe, shift, 1, rates) != 1) // perf-allowed: PDH/PDL structural rule, closed-bar hook only.
      return false;
   bar = rates[0];
   return true;
  }

bool HourInsideWindow(const int hour, const int start_hour, const int end_hour)
  {
   int start = start_hour;
   int end = end_hour;
   if(start < 0)
      start = 0;
   if(start > 23)
      start = 23;
   if(end < 0)
      end = 0;
   if(end > 24)
      end = 24;

   if(start == end)
      return true;
   if(start < end)
      return (hour >= start && hour < end);
   return (hour >= start || hour < end);
  }

bool InsideCashOpenSkip(const MqlDateTime &dt, const int open_hour, const int open_minute)
  {
   if(strategy_cash_open_skip_minutes <= 0)
      return false;
   const int now_minutes = dt.hour * 60 + dt.min;
   const int open_minutes = open_hour * 60 + open_minute;
   return (now_minutes >= open_minutes && now_minutes < open_minutes + strategy_cash_open_skip_minutes);
  }

void InitEntryRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool BuildTrapRequest(const QM_OrderType side,
                      const double entry_price,
                      const double trap_extreme,
                      const double atr_value,
                      QM_EntryRequest &req)
  {
   const double buffer_mult = MathMax(strategy_atr_buffer_mult, strategy_min_atr_buffer_mult);
   if(entry_price <= 0.0 || trap_extreme <= 0.0 || atr_value <= 0.0 || buffer_mult <= 0.0 || strategy_rr_target <= 0.0)
      return false;

   const double buffer = atr_value * buffer_mult;
   double stop = 0.0;
   if(side == QM_BUY)
      stop = trap_extreme - buffer;
   else
      stop = trap_extreme + buffer;

   const double risk_distance = MathAbs(entry_price - stop);
   if(stop <= 0.0 || risk_distance <= 0.0)
      return false;

   const double take = (side == QM_BUY) ? (entry_price + risk_distance * strategy_rr_target)
                                        : (entry_price - risk_distance * strategy_rr_target);
   if(take <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = NormalizeDouble(stop, _Digits);
   req.tp = NormalizeDouble(take, _Digits);
   req.reason = (side == QM_BUY) ? "PDL_SELLER_TRAP_LONG" : "PDH_BUYER_TRAP_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// No Trade Filter: time, spread, news-adjacent cash-open blackout.
bool Strategy_NoTradeFilter()
  {
   const datetime broker_now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(broker_now, dt);

   if(!HourInsideWindow(dt.hour, strategy_trade_start_hour, strategy_trade_end_hour))
      return true;

   if(InsideCashOpenSkip(dt, 8, 0) || InsideCashOpenSkip(dt, 15, 30))
      return true;

   if(strategy_max_spread_points > 0)
     {
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(point <= 0.0 || ask <= 0.0 || bid <= 0.0)
         return true;
      const double spread_points = (ask - bid) / point;
      if(spread_points > strategy_max_spread_points)
         return true;
     }

   return false;
  }

// Trade Entry: failed break of previous-day high/low, confirmed on closed bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   InitEntryRequest(req);

   if(strategy_atr_period <= 0)
      return false;

   MqlRates trap_bar;
   if(!ReadOneBar((ENUM_TIMEFRAMES)_Period, 1, trap_bar))
      return false;

   RefreshTradeDay(trap_bar.time);
   if(g_trade_taken_today)
      return false;

   MqlRates prev_day;
   if(!ReadOneBar(PERIOD_D1, 1, prev_day))
      return false;
   if(prev_day.high <= 0.0 || prev_day.low <= 0.0 || prev_day.high <= prev_day.low)
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(trap_bar.high > prev_day.high && trap_bar.close < prev_day.high)
     {
      if(BuildTrapRequest(QM_SELL, bid, trap_bar.high, atr, req))
        {
         g_trade_taken_today = true;
         return true;
        }
     }

   if(trap_bar.low < prev_day.low && trap_bar.close > prev_day.low)
     {
      if(BuildTrapRequest(QM_BUY, ask, trap_bar.low, atr, req))
        {
         g_trade_taken_today = true;
         return true;
        }
     }

   return false;
  }

// Trade Management: card specifies no trailing, break-even, or partial exits.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close: exits are broker SL/TP at configured R multiple plus framework Friday close.
bool Strategy_ExitSignal()
  {
   return false;
  }

// News Filter Hook: central V5 news filter remains authoritative.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(broker_time <= 0)
      return false;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10705_tv-liq-trap\"}");
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
