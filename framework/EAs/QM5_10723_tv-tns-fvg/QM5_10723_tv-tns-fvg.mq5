#property strict
#property version   "5.0"
#property description "QM5_10723 TradingView Tap'n'Slap FVG"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10723;
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
input int    strategy_fvg_max_age            = 30;
input int    strategy_min_tap_age            = 3;
input int    strategy_pivot_length           = 8;
input int    strategy_atr_period             = 14;
input double strategy_stop_atr_mult          = 0.75;
input double strategy_stop_atr_cap_mult      = 2.5;
input double strategy_min_rr                 = 1.5;
input double strategy_be_trigger_r           = 0.8;
input int    strategy_be_lock_points         = 5;
input bool   strategy_filter_weak_sl         = true;
input int    strategy_edge_offset_points     = 0;
input int    strategy_max_trades_per_day     = 3;
input int    strategy_session_start_hhmm     = 1530;
input int    strategy_entry_cutoff_hhmm      = 2130;
input int    strategy_session_end_hhmm       = 2200;
input int    strategy_max_spread_points      = 0;

int g_trade_day_key = 0;
int g_trades_today = 0;

int Strategy_DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int Strategy_Hhmm(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

void Strategy_ResetDailyCounterIfNeeded(const datetime broker_time)
  {
   const int day_key = Strategy_DayKey(broker_time);
   if(day_key != g_trade_day_key)
     {
      g_trade_day_key = day_key;
      g_trades_today = 0;
     }
  }

double Strategy_Point()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   return (point > 0.0) ? point : 0.0;
  }

double Strategy_CurrentSpreadPoints()
  {
   const double point = Strategy_Point();
   if(point <= 0.0)
      return 0.0;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid)
      return 0.0;
   return (ask - bid) / point;
  }

bool Strategy_IsPivotHigh(const MqlRates &rates[], const int copied, const int shift, const int length)
  {
   if(length < 1 || shift - length < 1 || shift + length >= copied)
      return false;

   const double h = rates[shift].high;
   for(int i = shift - length; i <= shift + length; ++i)
     {
      if(i == shift)
         continue;
      if(rates[i].high >= h)
         return false;
     }
   return true;
  }

bool Strategy_IsPivotLow(const MqlRates &rates[], const int copied, const int shift, const int length)
  {
   if(length < 1 || shift - length < 1 || shift + length >= copied)
      return false;

   const double l = rates[shift].low;
   for(int i = shift - length; i <= shift + length; ++i)
     {
      if(i == shift)
         continue;
      if(rates[i].low <= l)
         return false;
     }
   return true;
  }

double Strategy_NearestPivotTarget(const MqlRates &rates[],
                                   const int copied,
                                   const QM_OrderType side,
                                   const double entry)
  {
   double target = 0.0;
   const int length = MathMax(1, strategy_pivot_length);
   for(int shift = length + 1; shift < copied - length; ++shift)
     {
      if(QM_OrderTypeIsBuy(side))
        {
         if(!Strategy_IsPivotHigh(rates, copied, shift, length))
            continue;
         const double h = rates[shift].high;
         if(h <= entry)
            continue;
         if(target <= 0.0 || h < target)
            target = h;
        }
      else
        {
         if(!Strategy_IsPivotLow(rates, copied, shift, length))
            continue;
         const double l = rates[shift].low;
         if(l >= entry)
            continue;
         if(target <= 0.0 || l > target)
            target = l;
        }
     }
   return target;
  }

bool Strategy_StopInsideZone(const double sl, const double zone_low, const double zone_high)
  {
   return (sl >= zone_low && sl <= zone_high);
  }

double Strategy_StopDistance()
  {
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   const double point = Strategy_Point();
   if(atr <= 0.0 || point <= 0.0)
      return 0.0;

   const double min_stop = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
   const double base = atr * strategy_stop_atr_mult;
   const double cap = atr * strategy_stop_atr_cap_mult;
   double dist = MathMax(base, min_stop);
   if(cap > 0.0 && min_stop <= cap)
      dist = MathMin(dist, cap);
   return dist;
  }

bool Strategy_BuildRequest(const QM_OrderType side,
                           const double zone_low,
                           const double zone_high,
                           const MqlRates &rates[],
                           const int copied,
                           QM_EntryRequest &req)
  {
   const double entry = QM_OrderTypeIsBuy(side) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                                : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double stop_dist = Strategy_StopDistance();
   if(stop_dist <= 0.0)
      return false;

   const double sl = QM_OrderTypeIsBuy(side) ? entry - stop_dist : entry + stop_dist;
   if(strategy_filter_weak_sl && Strategy_StopInsideZone(sl, zone_low, zone_high))
      return false;

   const double tp = Strategy_NearestPivotTarget(rates, copied, side, entry);
   if(tp <= 0.0)
      return false;

   const double risk = MathAbs(entry - sl);
   const double reward = MathAbs(tp - entry);
   if(risk <= 0.0 || reward / risk < strategy_min_rr)
      return false;

   req.type = side;
   req.price = entry;
   req.sl = NormalizeDouble(sl, _Digits);
   req.tp = NormalizeDouble(tp, _Digits);
   req.reason = QM_OrderTypeIsBuy(side) ? "TNS_FVG_LONG_TAP" : "TNS_FVG_SHORT_TAP";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

bool Strategy_NoTradeFilter()
  {
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

   const datetime broker_now = TimeCurrent();
   Strategy_ResetDailyCounterIfNeeded(broker_now);
   if(g_trades_today >= strategy_max_trades_per_day)
      return false;

   const int hhmm = Strategy_Hhmm(broker_now);
   if(hhmm < strategy_session_start_hhmm || hhmm >= strategy_entry_cutoff_hhmm)
      return false;

   if(strategy_max_spread_points > 0 && Strategy_CurrentSpreadPoints() > strategy_max_spread_points)
      return false;

   const int fvg_age = MathMax(3, strategy_fvg_max_age);
   const int pivot_window = MathMax(1, strategy_pivot_length);
   const int bars_needed = MathMax(fvg_age + 4, pivot_window * 2 + fvg_age + 8);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, _Period, 0, bars_needed, rates); // perf-allowed: bounded FVG/pivot scan on closed-bar entry gate.
   if(copied < bars_needed)
      return false;

   const double point = Strategy_Point();
   const double edge = MathMax(0, strategy_edge_offset_points) * point;
   const MqlRates tap = rates[1];
   const int min_shift = MathMax(1, strategy_min_tap_age) + 1;
   const int max_shift = MathMin(strategy_fvg_max_age, copied - 3);

   for(int shift = min_shift; shift <= max_shift; ++shift)
     {
      if(rates[shift].low > rates[shift + 2].high)
        {
         const double zone_low = rates[shift + 2].high;
         const double zone_high = rates[shift].low;
         const bool bearish_tap = (tap.close < tap.open);
         const bool high_inside = (tap.high >= zone_low + edge && tap.high <= zone_high - edge);
         const bool tapped_zone = (tap.low <= zone_high);
         if(bearish_tap && high_inside && tapped_zone &&
            Strategy_BuildRequest(QM_BUY, zone_low, zone_high, rates, copied, req))
           {
            g_trades_today++;
            return true;
           }
        }

      if(rates[shift].high < rates[shift + 2].low)
        {
         const double zone_low = rates[shift].high;
         const double zone_high = rates[shift + 2].low;
         const bool bullish_tap = (tap.close > tap.open);
         const bool low_inside = (tap.low >= zone_low + edge && tap.low <= zone_high - edge);
         const bool tapped_zone = (tap.high >= zone_low);
         if(bullish_tap && low_inside && tapped_zone &&
            Strategy_BuildRequest(QM_SELL, zone_low, zone_high, rates, copied, req))
           {
            g_trades_today++;
            return true;
           }
        }
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   const double point = Strategy_Point();
   if(magic <= 0 || point <= 0.0 || strategy_be_trigger_r <= 0.0)
      return;

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
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || current_sl <= 0.0)
         continue;

      const bool is_buy = (ptype == POSITION_TYPE_BUY);
      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double initial_r = MathAbs(open_price - current_sl);
      if(market <= 0.0 || initial_r <= 0.0)
         continue;

      const double moved = is_buy ? (market - open_price) : (open_price - market);
      if(moved < initial_r * strategy_be_trigger_r)
         continue;

      const double lock = MathMax(0, strategy_be_lock_points) * point;
      const double target_sl = is_buy ? open_price + lock : open_price - lock;
      const bool improves = is_buy ? (target_sl > current_sl + point * 0.5)
                                   : (target_sl < current_sl - point * 0.5);
      if(improves)
         QM_TM_MoveSL(ticket, NormalizeDouble(target_sl, _Digits), "tns_fvg_be_lock");
     }
  }

bool Strategy_ExitSignal()
  {
   return (Strategy_Hhmm(TimeCurrent()) >= strategy_session_end_hhmm);
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10723_tv-tns-fvg\"}");
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
