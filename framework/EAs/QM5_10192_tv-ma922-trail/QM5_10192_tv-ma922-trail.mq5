#property strict
#property version   "5.0"
#property description "QM5_10192 TradingView MA 9/22 breakout trail"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10192;
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
input int    strategy_fast_ma_period       = 9;
input int    strategy_slow_ma_period       = 22;
input int    strategy_atr_period           = 14;
input int    strategy_rsi_period           = 14;
input int    strategy_volume_sma_period    = 20;
input int    strategy_swing_lookback_bars  = 20;
input double strategy_breakout_atr_mult    = 0.5;
input double strategy_min_body_pct         = 0.5;
input double strategy_initial_stop_pct     = 1.5;
input double strategy_initial_atr_mult     = 1.0;
input double strategy_trailing_stop_pct    = 1.5;
input double strategy_max_spread_stop_frac = 0.15;

bool IsStrategyTimeframe()
  {
   return (_Period == PERIOD_M5 || _Period == PERIOD_M15);
  }

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

double RecentHigh(const int lookback)
  {
   if(lookback <= 0)
      return 0.0;
   double high = -DBL_MAX;
   for(int shift = 2; shift < 2 + lookback; ++shift)
     {
      const double value = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, shift);
      if(value <= 0.0)
         return 0.0;
      high = MathMax(high, value);
     }
   return high;
  }

double RecentLow(const int lookback)
  {
   if(lookback <= 0)
      return 0.0;
   double low = DBL_MAX;
   for(int shift = 2; shift < 2 + lookback; ++shift)
     {
      const double value = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, shift);
      if(value <= 0.0)
         return 0.0;
      low = MathMin(low, value);
     }
   return low;
  }

bool BodyFilterPasses()
  {
   const double open_1 = iOpen(_Symbol, (ENUM_TIMEFRAMES)_Period, 1);
   const double close_1 = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, 1);
   const double high_1 = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, 1);
   const double low_1 = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, 1);
   const double range = high_1 - low_1;
   if(open_1 <= 0.0 || close_1 <= 0.0 || range <= 0.0)
      return false;
   return (MathAbs(close_1 - open_1) / range >= strategy_min_body_pct);
  }

bool VolumeFilterPasses()
  {
   if(strategy_volume_sma_period <= 0)
      return false;

   const long current_volume = iVolume(_Symbol, (ENUM_TIMEFRAMES)_Period, 1);
   if(current_volume <= 0)
      return false;

   double volume_sum = 0.0;
   for(int shift = 2; shift < 2 + strategy_volume_sma_period; ++shift)
     {
      const long sample = iVolume(_Symbol, (ENUM_TIMEFRAMES)_Period, shift);
      if(sample <= 0)
         return false;
      volume_sum += (double)sample;
     }

   return ((double)current_volume > volume_sum / (double)strategy_volume_sma_period);
  }

int MaCrossSignal()
  {
   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double fast_1 = QM_SMA(_Symbol, tf, strategy_fast_ma_period, 1, PRICE_CLOSE);
   const double slow_1 = QM_SMA(_Symbol, tf, strategy_slow_ma_period, 1, PRICE_CLOSE);
   const double fast_2 = QM_SMA(_Symbol, tf, strategy_fast_ma_period, 2, PRICE_CLOSE);
   const double slow_2 = QM_SMA(_Symbol, tf, strategy_slow_ma_period, 2, PRICE_CLOSE);
   if(fast_1 <= 0.0 || slow_1 <= 0.0 || fast_2 <= 0.0 || slow_2 <= 0.0)
      return 0;
   if(fast_2 <= slow_2 && fast_1 > slow_1)
      return 1;
   if(fast_2 >= slow_2 && fast_1 < slow_1)
      return -1;
   return 0;
  }

double InitialStopDistance(const double entry_price, const double atr)
  {
   if(entry_price <= 0.0 || atr <= 0.0)
      return 0.0;
   const double pct_distance = entry_price * strategy_initial_stop_pct / 100.0;
   const double atr_distance = atr * strategy_initial_atr_mult;
   return MathMax(pct_distance, atr_distance);
  }

bool SpreadFilterPasses(const double stop_distance)
  {
   if(strategy_max_spread_stop_frac <= 0.0)
      return true;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || stop_distance <= 0.0)
      return false;
   return ((ask - bid) <= stop_distance * strategy_max_spread_stop_frac);
  }

bool PositionOpposedByCross(const int signal)
  {
   if(signal == 0)
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

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY && signal < 0)
         return true;
      if(type == POSITION_TYPE_SELL && signal > 0)
         return true;
     }
   return false;
  }

// No Trade Filter: framework handles kill-switch, news, and Friday close; this
// hook enforces the card's M5/M15 execution scope.
bool Strategy_NoTradeFilter()
  {
   return !IsStrategyTimeframe();
  }

// Trade Entry: closed-bar 9/22 MA cross with ATR breakout confirmation, candle
// body, tick-volume SMA, RSI, and spread-vs-stop filters.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!IsStrategyTimeframe())
      return false;
   if(strategy_fast_ma_period <= 0 || strategy_slow_ma_period <= strategy_fast_ma_period)
      return false;
   if(strategy_atr_period <= 0 || strategy_rsi_period <= 0 || strategy_swing_lookback_bars <= 0)
      return false;
   if(strategy_breakout_atr_mult <= 0.0 || strategy_min_body_pct <= 0.0)
      return false;
   if(strategy_initial_stop_pct <= 0.0 || strategy_initial_atr_mult <= 0.0)
      return false;
   if(HasOurOpenPosition())
      return false;

   const int signal = MaCrossSignal();
   if(signal == 0)
      return false;
   if(!BodyFilterPasses() || !VolumeFilterPasses())
      return false;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double close_1 = iClose(_Symbol, tf, 1);
   const double atr = QM_ATR(_Symbol, tf, strategy_atr_period, 1);
   const double rsi = QM_RSI(_Symbol, tf, strategy_rsi_period, 1, PRICE_CLOSE);
   if(close_1 <= 0.0 || atr <= 0.0 || rsi <= 0.0)
      return false;

   if(signal > 0)
     {
      const double recent_high = RecentHigh(strategy_swing_lookback_bars);
      if(recent_high <= 0.0 || close_1 <= recent_high + strategy_breakout_atr_mult * atr)
         return false;
      if(rsi <= 50.0)
         return false;
      req.type = QM_BUY;
      req.reason = "TV_MA922_LONG";
     }
   else
     {
      const double recent_low = RecentLow(strategy_swing_lookback_bars);
      if(recent_low <= 0.0 || close_1 >= recent_low - strategy_breakout_atr_mult * atr)
         return false;
      if(rsi >= 50.0)
         return false;
      req.type = QM_SELL;
      req.reason = "TV_MA922_SHORT";
     }

   const double entry = QM_EntryMarketPrice(req.type);
   const double stop_distance = InitialStopDistance(entry, atr);
   if(entry <= 0.0 || stop_distance <= 0.0 || !SpreadFilterPasses(stop_distance))
      return false;

   req.sl = QM_StopRulesStopFromDistance(_Symbol, req.type, entry, stop_distance);
   req.tp = 0.0;
   return (req.sl > 0.0);
  }

// Trade Management: source exit trails by 1.5% of average entry price, updating
// only in the profitable direction.
void Strategy_ManageOpenPosition()
  {
   if(strategy_trailing_stop_pct <= 0.0)
      return;

   const int magic = QM_FrameworkMagic();
   const double trail_frac = strategy_trailing_stop_pct / 100.0;
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
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

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0)
         continue;

      if(type == POSITION_TYPE_BUY)
        {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid <= open_price)
            continue;
         const double new_sl = NormalizeDouble(bid * (1.0 - trail_frac), _Digits);
         if(new_sl > open_price && (current_sl <= 0.0 || new_sl > current_sl + point * 0.5))
            QM_TM_MoveSL(ticket, new_sl, "tv_ma922_pct_trail");
        }
      else if(type == POSITION_TYPE_SELL)
        {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask >= open_price)
            continue;
         const double new_sl = NormalizeDouble(ask * (1.0 + trail_frac), _Digits);
         if(new_sl < open_price && (current_sl <= 0.0 || new_sl < current_sl - point * 0.5))
            QM_TM_MoveSL(ticket, new_sl, "tv_ma922_pct_trail");
        }
     }
  }

// Trade Close: close on the opposite 9/22 MA cross before the trailing stop.
bool Strategy_ExitSignal()
  {
   if(!IsStrategyTimeframe() || !HasOurOpenPosition())
      return false;
   return PositionOpposedByCross(MaCrossSignal());
  }

// News Filter Hook: no card-specific override; P8 can call the central news
// filter through framework wiring.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10192\",\"ea\":\"tv-ma922-trail\"}");
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
