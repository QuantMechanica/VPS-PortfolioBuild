#property strict
#property version   "5.0"
#property description "QM5_10195 TradingView Supertrend MACD EMA"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Strategy implementation is confined to the five Strategy_* hooks below.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10195;
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
input int    strategy_supertrend_period = 10;
input double strategy_supertrend_mult   = 3.0;
input int    strategy_macd_fast         = 12;
input int    strategy_macd_slow         = 26;
input int    strategy_macd_signal       = 9;
input int    strategy_ema_period        = 200;
input int    strategy_swing_lookback    = 10;
input int    strategy_atr_period        = 14;
input double strategy_atr_fallback_mult = 1.5;

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only - runs on every tick.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

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
   const double close_1 = iClose(_Symbol, tf, 1);
   const double ema_1 = QM_EMA(_Symbol, tf, strategy_ema_period, 1);
   const double macd_main_1 = QM_MACD_Main(_Symbol, tf, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double macd_signal_1 = QM_MACD_Signal(_Symbol, tf, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   if(close_1 <= 0.0 || ema_1 <= 0.0)
      return false;

   int st_dir = 0;
   double final_upper = 0.0;
   double final_lower = 0.0;
   const int st_period = MathMax(strategy_supertrend_period, 1);
   const int warmup = MathMax(st_period * 8, 80);
   for(int shift = 1 + warmup; shift >= 1; --shift)
     {
      const double high = iHigh(_Symbol, tf, shift);
      const double low = iLow(_Symbol, tf, shift);
      const double close = iClose(_Symbol, tf, shift);
      const double atr = QM_ATR(_Symbol, tf, st_period, shift);
      if(high <= 0.0 || low <= 0.0 || close <= 0.0 || atr <= 0.0)
         continue;

      const double hl2 = (high + low) * 0.5;
      const double basic_upper = hl2 + strategy_supertrend_mult * atr;
      const double basic_lower = hl2 - strategy_supertrend_mult * atr;

      if(st_dir == 0)
        {
         final_upper = basic_upper;
         final_lower = basic_lower;
         st_dir = (close >= hl2) ? 1 : -1;
         continue;
        }

      const double prev_close = iClose(_Symbol, tf, shift + 1);
      final_upper = (basic_upper < final_upper || prev_close > final_upper) ? basic_upper : final_upper;
      final_lower = (basic_lower > final_lower || prev_close < final_lower) ? basic_lower : final_lower;

      if(st_dir < 0)
         st_dir = (close > final_upper) ? 1 : -1;
      else
         st_dir = (close < final_lower) ? -1 : 1;
     }

   if(st_dir == 0)
      return false;

   QM_OrderType side = QM_BUY;
   string reason = "";
   if(st_dir > 0 && macd_main_1 > macd_signal_1 && close_1 > ema_1)
     {
      side = QM_BUY;
      reason = "ST_MACD_EMA_LONG";
     }
   else if(st_dir < 0 && macd_main_1 < macd_signal_1 && close_1 < ema_1)
     {
      side = QM_SELL;
      reason = "ST_MACD_EMA_SHORT";
     }
   else
      return false;

   const double entry = QM_EntryMarketPrice(side);
   double stop = QM_StopStructure(_Symbol, side, entry, strategy_swing_lookback);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(stop <= 0.0 || tick_size <= 0.0)
      return false;

   stop = QM_OrderTypeIsBuy(side) ? (stop - tick_size) : (stop + tick_size);

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double min_distance = (point > 0.0 && stops_level > 0) ? point * stops_level : 0.0;
   if(min_distance > 0.0 && MathAbs(entry - stop) < min_distance)
      stop = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_fallback_mult);

   if(stop <= 0.0)
      return false;

   req.type = side;
   req.sl = QM_StopRulesNormalizePrice(_Symbol, stop);
   req.reason = reason;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, partial close, or break-even management.
  }

// Return TRUE to close the open position now.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double macd_main_1 = QM_MACD_Main(_Symbol, tf, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double macd_signal_1 = QM_MACD_Signal(_Symbol, tf, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double macd_main_2 = QM_MACD_Main(_Symbol, tf, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 2);
   const double macd_signal_2 = QM_MACD_Signal(_Symbol, tf, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 2);

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
      if(ptype == POSITION_TYPE_BUY && macd_main_2 >= macd_signal_2 && macd_main_1 < macd_signal_1)
         return true;
      if(ptype == POSITION_TYPE_SELL && macd_main_2 <= macd_signal_2 && macd_main_1 > macd_signal_1)
         return true;
     }

   return false;
  }

// Optional news-filter override.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line.
// -----------------------------------------------------------------------------

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{}");
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
