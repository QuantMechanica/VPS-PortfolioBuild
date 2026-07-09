#property strict
#property version   "5.0"
#property description "QM5_13096 XTI NR7 compression breakout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_13096 - XTI NR7 Compression Breakout
// -----------------------------------------------------------------------------
// D1 structural WTI sleeve:
//   - setup bar must be the narrowest range of the last N completed D1 bars
//   - confirmation bar must close beyond setup high/low with trend confirmation
//   - exits on SMA trend failure, max hold, ATR stop/target
// Runtime uses MT5 OHLC/broker calendar only; no futures curve/API/CSV/feed.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 13096;
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
input int    strategy_nr_lookback              = 7;
input int    strategy_confirmation_min_dow     = 2;
input int    strategy_confirmation_max_dow     = 4;
input int    strategy_atr_period               = 20;
input int    strategy_trend_period             = 60;
input int    strategy_slope_lag_days           = 5;
input double strategy_min_nr_range_atr         = 0.20;
input double strategy_max_nr_range_atr         = 1.20;
input double strategy_break_buffer_atr         = 0.10;
input double strategy_min_break_close_location = 0.62;
input double strategy_atr_sl_mult              = 2.40;
input double strategy_atr_tp_mult              = 3.00;
input int    strategy_max_hold_days            = 12;
input int    strategy_max_spread_points        = 1000;

int g_last_entry_week_key = 0;

bool Strategy_IsXtiD1()
  {
   return (_Symbol == "XTIUSD.DWX" && _Period == PERIOD_D1);
  }

datetime Strategy_DateMidnight(const datetime t)
  {
   if(t <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

datetime Strategy_WeekStart(const datetime t)
  {
   if(t <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(t, dt);
   const int dow = dt.day_of_week;
   const int offset_days = (dow == 0) ? 6 : (dow - 1);
   return Strategy_DateMidnight(t) - offset_days * 86400;
  }

int Strategy_WeekKey(const datetime t)
  {
   const datetime start = Strategy_WeekStart(t);
   if(start <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(start, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int Strategy_DayOfWeek(const datetime t)
  {
   if(t <= 0)
      return -1;
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.day_of_week;
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

bool Strategy_LoadNr7State(double &setup_high,
                           double &setup_low,
                           double &setup_range,
                           double &confirm_open,
                           double &confirm_high,
                           double &confirm_low,
                           double &confirm_close,
                           double &confirm_close_location,
                           double &atr_last,
                           double &sma_last,
                           double &sma_past,
                           int &confirm_dow,
                           int &confirm_week_key)
  {
   setup_high = 0.0;
   setup_low = 0.0;
   setup_range = 0.0;
   confirm_open = 0.0;
   confirm_high = 0.0;
   confirm_low = 0.0;
   confirm_close = 0.0;
   confirm_close_location = 0.0;
   atr_last = 0.0;
   sma_last = 0.0;
   sma_past = 0.0;
   confirm_dow = -1;
   confirm_week_key = 0;

   const int lookback = MathMax(2, strategy_nr_lookback);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, lookback + 3, rates); // perf-allowed: D1 NR7 state is evaluated only after QM_IsNewBar().
   if(copied < lookback + 2)
      return false;

   const MqlRates confirm = rates[0];
   const MqlRates setup = rates[1];
   if(confirm.high <= confirm.low || setup.high <= setup.low || confirm.close <= 0.0 || setup.close <= 0.0)
      return false;

   setup_high = setup.high;
   setup_low = setup.low;
   setup_range = setup.high - setup.low;
   for(int i = 2; i <= lookback; ++i)
     {
      const double prior_range = rates[i].high - rates[i].low;
      if(prior_range <= 0.0)
         return false;
      if(setup_range >= prior_range)
         return false;
     }

   confirm_open = confirm.open;
   confirm_high = confirm.high;
   confirm_low = confirm.low;
   confirm_close = confirm.close;
   const double confirm_range = confirm_high - confirm_low;
   if(confirm_range <= 0.0 || confirm_open <= 0.0)
      return false;

   confirm_close_location = (confirm_close - confirm_low) / confirm_range;
   atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   sma_last = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_period, 1, PRICE_CLOSE);
   sma_past = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_period, 1 + strategy_slope_lag_days, PRICE_CLOSE);
   confirm_dow = Strategy_DayOfWeek(confirm.time);
   confirm_week_key = Strategy_WeekKey(confirm.time);

   return (setup_range > 0.0 &&
           MathIsValidNumber(confirm_close_location) &&
           atr_last > 0.0 &&
           sma_last > 0.0 &&
           sma_past > 0.0 &&
           confirm_week_key > 0);
  }

void Strategy_CloseOpenPositionsIfNeeded()
  {
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   const int hold_seconds = MathMax(1, strategy_max_hold_days) * 86400;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, 1, rates); // perf-allowed: D1 close-only management state, called only from the QM_IsNewBar() path.
   if(copied < 1)
      return;
   const double close_last = rates[0].close;
   const double sma_last = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_period, 1, PRICE_CLOSE);
   if(close_last <= 0.0 || sma_last <= 0.0)
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

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      bool should_close = false;

      if(opened > 0 && now - opened >= hold_seconds)
         should_close = true;
      if(pos_type == POSITION_TYPE_BUY && close_last < sma_last)
         should_close = true;
      if(pos_type == POSITION_TYPE_SELL && close_last > sma_last)
         should_close = true;

      if(should_close)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsXtiD1())
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_nr_lookback < 3 || strategy_nr_lookback > 20)
      return true;
   if(strategy_confirmation_min_dow < 1 || strategy_confirmation_max_dow > 5 || strategy_confirmation_min_dow > strategy_confirmation_max_dow)
      return true;
   if(strategy_atr_period <= 1 || strategy_trend_period <= 1 || strategy_slope_lag_days <= 0)
      return true;
   if(strategy_min_nr_range_atr <= 0.0 || strategy_max_nr_range_atr <= strategy_min_nr_range_atr)
      return true;
   if(strategy_break_buffer_atr < 0.0)
      return true;
   if(strategy_min_break_close_location <= 0.5 || strategy_min_break_close_location >= 1.0)
      return true;
   if(strategy_atr_sl_mult <= 0.0 || strategy_atr_tp_mult <= 0.0)
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
   req.reason = "QM5_13096_XTI_NR7_BRK";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition())
      return false;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return false;
     }

   double setup_high = 0.0;
   double setup_low = 0.0;
   double setup_range = 0.0;
   double confirm_open = 0.0;
   double confirm_high = 0.0;
   double confirm_low = 0.0;
   double confirm_close = 0.0;
   double confirm_close_location = 0.0;
   double atr_last = 0.0;
   double sma_last = 0.0;
   double sma_past = 0.0;
   int confirm_dow = -1;
   int confirm_week_key = 0;
   if(!Strategy_LoadNr7State(setup_high,
                             setup_low,
                             setup_range,
                             confirm_open,
                             confirm_high,
                             confirm_low,
                             confirm_close,
                             confirm_close_location,
                             atr_last,
                             sma_last,
                             sma_past,
                             confirm_dow,
                             confirm_week_key))
      return false;

   if(confirm_week_key == g_last_entry_week_key)
      return false;
   if(confirm_dow < strategy_confirmation_min_dow || confirm_dow > strategy_confirmation_max_dow)
      return false;
   if(setup_range < strategy_min_nr_range_atr * atr_last)
      return false;
   if(setup_range > strategy_max_nr_range_atr * atr_last)
      return false;

   const double buffer = strategy_break_buffer_atr * atr_last;
   int direction = 0;
   if(confirm_close > setup_high + buffer &&
      confirm_close > confirm_open &&
      confirm_close_location >= strategy_min_break_close_location &&
      confirm_close > sma_last &&
      sma_last > sma_past)
      direction = 1;
   else if(confirm_close < setup_low - buffer &&
           confirm_close < confirm_open &&
           confirm_close_location <= (1.0 - strategy_min_break_close_location) &&
           confirm_close < sma_last &&
           sma_last < sma_past)
      direction = -1;
   else
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry_price, atr_last, strategy_atr_sl_mult);
   req.sl = QM_StopRulesNormalizePrice(_Symbol, req.sl);
   if(req.sl <= 0.0)
      return false;
   if(req.type == QM_BUY && req.sl >= entry_price)
      return false;
   if(req.type == QM_SELL && req.sl <= entry_price)
      return false;

   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   req.tp = (req.type == QM_BUY)
            ? NormalizeDouble(entry_price + strategy_atr_tp_mult * atr_last, digits)
            : NormalizeDouble(entry_price - strategy_atr_tp_mult * atr_last, digits);
   req.tp = QM_StopRulesNormalizePrice(_Symbol, req.tp);
   if(req.tp <= 0.0)
      return false;
   if(req.type == QM_BUY && req.tp <= entry_price)
      return false;
   if(req.type == QM_SELL && req.tp >= entry_price)
      return false;

   req.reason = (direction > 0) ? "XTI_NR7_BRK_LONG" : "XTI_NR7_BRK_SHORT";
   g_last_entry_week_key = confirm_week_key;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13096\",\"ea\":\"xti-nr7-brk\"}");
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

   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   const bool is_new_bar = QM_IsNewBar();

   if(is_new_bar)
      Strategy_ManageOpenPosition();

   if(is_new_bar && Strategy_ExitSignal())
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

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!is_new_bar)
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
