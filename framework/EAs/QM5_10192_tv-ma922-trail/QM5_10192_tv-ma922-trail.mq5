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

// No Trade Filter (time, spread, news): central news and Friday-close gates run
// before this hook; the card's spread rule is evaluated against the candidate
// initial stop inside Trade Entry.
bool Strategy_NoTradeFilter()
  {
   return (_Period != PERIOD_M5 && _Period != PERIOD_M15);
  }

// Trade Entry: 9/22 MA cross, ATR breakout, body, volume, RSI, initial stop,
// risk sizing through the framework, and one-position-per-magic enforcement.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(_Period != PERIOD_M5 && _Period != PERIOD_M15)
      return false;
   if(strategy_fast_ma_period <= 0 || strategy_slow_ma_period <= strategy_fast_ma_period)
      return false;
   if(strategy_atr_period <= 0 || strategy_rsi_period <= 0)
      return false;
   if(strategy_volume_sma_period <= 0 || strategy_swing_lookback_bars <= 0)
      return false;
   if(strategy_breakout_atr_mult <= 0.0 || strategy_min_body_pct <= 0.0)
      return false;
   if(strategy_initial_stop_pct <= 0.0 || strategy_initial_atr_mult <= 0.0)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double fast_1 = QM_SMA(_Symbol, tf, strategy_fast_ma_period, 1, PRICE_CLOSE);
   const double slow_1 = QM_SMA(_Symbol, tf, strategy_slow_ma_period, 1, PRICE_CLOSE);
   const double fast_2 = QM_SMA(_Symbol, tf, strategy_fast_ma_period, 2, PRICE_CLOSE);
   const double slow_2 = QM_SMA(_Symbol, tf, strategy_slow_ma_period, 2, PRICE_CLOSE);
   if(fast_1 <= 0.0 || slow_1 <= 0.0 || fast_2 <= 0.0 || slow_2 <= 0.0)
      return false;

   int signal = 0;
   if(fast_2 <= slow_2 && fast_1 > slow_1)
      signal = 1;
   else if(fast_2 >= slow_2 && fast_1 < slow_1)
      signal = -1;
   if(signal == 0)
      return false;

   const int bars_needed = MathMax(strategy_slow_ma_period + 3,
                         MathMax(strategy_volume_sma_period + 2,
                                 strategy_swing_lookback_bars + 2));
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, tf, 1, bars_needed, rates); // perf-allowed: bounded closed-bar OHLC/tick-volume read inside framework QM_IsNewBar-gated EntrySignal.
   if(copied < bars_needed)
      return false;

   const double bar_range = rates[0].high - rates[0].low;
   if(rates[0].open <= 0.0 || rates[0].close <= 0.0 || bar_range <= 0.0)
      return false;
   if(MathAbs(rates[0].close - rates[0].open) / bar_range < strategy_min_body_pct)
      return false;

   if(rates[0].tick_volume <= 0)
      return false;
   double volume_sum = 0.0;
   for(int shift = 1; shift <= strategy_volume_sma_period; ++shift)
     {
      if(rates[shift].tick_volume <= 0)
         return false;
      volume_sum += (double)rates[shift].tick_volume;
     }
   if((double)rates[0].tick_volume <= volume_sum / (double)strategy_volume_sma_period)
      return false;

   double recent_high = -DBL_MAX;
   double recent_low = DBL_MAX;
   for(int shift = 1; shift <= strategy_swing_lookback_bars; ++shift)
     {
      if(rates[shift].high <= 0.0 || rates[shift].low <= 0.0)
         return false;
      recent_high = MathMax(recent_high, rates[shift].high);
      recent_low = MathMin(recent_low, rates[shift].low);
     }

   const double atr = QM_ATR(_Symbol, tf, strategy_atr_period, 1);
   const double rsi = QM_RSI(_Symbol, tf, strategy_rsi_period, 1, PRICE_CLOSE);
   if(atr <= 0.0 || rsi <= 0.0)
      return false;

   if(signal > 0)
     {
      if(rates[0].close <= recent_high + strategy_breakout_atr_mult * atr)
         return false;
      if(rsi <= 50.0)
         return false;
      req.type = QM_BUY;
      req.reason = "TV_MA922_LONG";
     }
   else
     {
      if(rates[0].close >= recent_low - strategy_breakout_atr_mult * atr)
         return false;
      if(rsi >= 50.0)
         return false;
      req.type = QM_SELL;
      req.reason = "TV_MA922_SHORT";
     }

   const double entry = QM_EntryMarketPrice(req.type);
   if(entry <= 0.0)
      return false;

   const double stop_distance = MathMax(entry * strategy_initial_stop_pct / 100.0,
                                        atr * strategy_initial_atr_mult);
   if(stop_distance <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;
   if(strategy_max_spread_stop_frac > 0.0 &&
      (ask - bid) > strategy_max_spread_stop_frac * stop_distance)
      return false;

   req.sl = QM_StopRulesStopFromDistance(_Symbol, req.type, entry, stop_distance);
   req.tp = 0.0;
   return (req.sl > 0.0);
  }

// Trade Management: percentage trailing stop based on average entry price,
// moved only in the profitable direction.
void Strategy_ManageOpenPosition()
  {
   if(strategy_trailing_stop_pct <= 0.0)
      return;

   const int magic = QM_FrameworkMagic();
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

      const double trail_distance = open_price * strategy_trailing_stop_pct / 100.0;
      if(type == POSITION_TYPE_BUY)
        {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid <= open_price)
            continue;
         const double new_sl = NormalizeDouble(bid - trail_distance, _Digits);
         if(new_sl > open_price && (current_sl <= 0.0 || new_sl > current_sl + point * 0.5))
            QM_TM_MoveSL(ticket, new_sl, "tv_ma922_pct_entry_trail");
        }
      else if(type == POSITION_TYPE_SELL)
        {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask >= open_price)
            continue;
         const double new_sl = NormalizeDouble(ask + trail_distance, _Digits);
         if(new_sl < open_price && (current_sl <= 0.0 || new_sl < current_sl - point * 0.5))
            QM_TM_MoveSL(ticket, new_sl, "tv_ma922_pct_entry_trail");
        }
     }
  }

// Trade Close: opposite 9/22 MA cross before the trailing stop is hit.
bool Strategy_ExitSignal()
  {
   if(_Period != PERIOD_M5 && _Period != PERIOD_M15)
      return false;

   const int magic = QM_FrameworkMagic();
   ENUM_POSITION_TYPE open_type = POSITION_TYPE_BUY;
   bool has_position = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      open_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      has_position = true;
      break;
     }
   if(!has_position)
      return false;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double fast_1 = QM_SMA(_Symbol, tf, strategy_fast_ma_period, 1, PRICE_CLOSE);
   const double slow_1 = QM_SMA(_Symbol, tf, strategy_slow_ma_period, 1, PRICE_CLOSE);
   const double fast_2 = QM_SMA(_Symbol, tf, strategy_fast_ma_period, 2, PRICE_CLOSE);
   const double slow_2 = QM_SMA(_Symbol, tf, strategy_slow_ma_period, 2, PRICE_CLOSE);
   if(fast_1 <= 0.0 || slow_1 <= 0.0 || fast_2 <= 0.0 || slow_2 <= 0.0)
      return false;

   if(open_type == POSITION_TYPE_BUY)
      return (fast_2 >= slow_2 && fast_1 < slow_1);
   if(open_type == POSITION_TYPE_SELL)
      return (fast_2 <= slow_2 && fast_1 > slow_1);
   return false;
  }

// News Filter Hook: no card-specific override; central news filtering remains
// callable for P8 News Impact phase.
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
