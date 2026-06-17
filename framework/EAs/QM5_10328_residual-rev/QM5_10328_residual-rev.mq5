#property strict
#property version   "5.0"
#property description "QM5_10328 Residual Reversal"

#include <QM/QM_Common.mqh>

#define STRATEGY_BASKET_SIZE 4

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10328;
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
input ENUM_TIMEFRAMES strategy_signal_tf          = PERIOD_M30;
input int    strategy_session_start_hhmm          = 1530;
input int    strategy_session_end_hhmm            = 2200;
input int    strategy_slot_minutes                = 30;
input int    strategy_same_slot_bars_per_day      = 48;
input int    strategy_beta_days                   = 20;
input int    strategy_min_beta_observations       = 12;
input int    strategy_min_basket_symbols          = 3;
input int    strategy_atr_period                  = 14;
input double strategy_residual_atr_mult           = 0.35;
input double strategy_stop_atr_mult               = 0.75;
input int    strategy_spread_lookback_days        = 20;
input double strategy_spread_percentile           = 80.0;
input int    strategy_basket_warmup_bars          = 1800;

string g_strategy_basket[STRATEGY_BASKET_SIZE];

void Strategy_InitBasket()
  {
   g_strategy_basket[0] = "SP500.DWX";
   g_strategy_basket[1] = "NDX.DWX";
   g_strategy_basket[2] = "WS30.DWX";
   g_strategy_basket[3] = "GDAXI.DWX";
  }

bool Strategy_IsBasketSymbol(const string symbol)
  {
   for(int i = 0; i < STRATEGY_BASKET_SIZE; ++i)
      if(g_strategy_basket[i] == symbol)
         return true;
   return false;
  }

int Strategy_HhmmToMinutes(const int hhmm)
  {
   const int hour = hhmm / 100;
   const int minute = hhmm % 100;
   if(hour < 0 || hour > 23 || minute < 0 || minute > 59)
      return -1;
   return hour * 60 + minute;
  }

int Strategy_MinutesOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

int Strategy_SessionSlot(const datetime t)
  {
   const int start = Strategy_HhmmToMinutes(strategy_session_start_hhmm);
   const int end = Strategy_HhmmToMinutes(strategy_session_end_hhmm);
   if(start < 0 || end < 0 || strategy_slot_minutes <= 0)
      return -1;

   int duration = end - start;
   if(duration <= 0)
      duration += 24 * 60;
   if(duration <= 0 || (duration % strategy_slot_minutes) != 0)
      return -1;

   int offset = Strategy_MinutesOfDay(t) - start;
   if(offset < 0)
      offset += 24 * 60;
   if(offset < 0 || offset >= duration)
      return -1;

   return offset / strategy_slot_minutes;
  }

bool Strategy_SessionEntrySlotAllows(const datetime signal_bar_time)
  {
   const int start = Strategy_HhmmToMinutes(strategy_session_start_hhmm);
   const int end = Strategy_HhmmToMinutes(strategy_session_end_hhmm);
   if(start < 0 || end < 0 || strategy_slot_minutes <= 0)
      return false;

   int duration = end - start;
   if(duration <= 0)
      duration += 24 * 60;
   if(duration <= 0 || (duration % strategy_slot_minutes) != 0)
      return false;

   const int slot = Strategy_SessionSlot(signal_bar_time);
   const int slot_count = duration / strategy_slot_minutes;
   return (slot > 0 && slot < slot_count - 1);
  }

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

bool Strategy_ReadReturn(const string symbol, const int shift, double &ret, double &close_price)
  {
   ret = 0.0;
   close_price = 0.0;
   if(shift < 1 || !QM_SymbolAssertOrLog(symbol))
      return false;

   const double open_price = iOpen(symbol, strategy_signal_tf, shift);   // perf-allowed: fixed same-slot OHLC read, called only from the framework QM_IsNewBar-gated entry path.
   const double close_px = iClose(symbol, strategy_signal_tf, shift);    // perf-allowed: fixed same-slot OHLC read, called only from the framework QM_IsNewBar-gated entry path.
   if(open_price <= 0.0 || close_px <= 0.0)
      return false;

   ret = (close_px - open_price) / open_price;
   close_price = close_px;
   return true;
  }

double Strategy_Percentile(double &values[], const int count, const double percentile)
  {
   if(count <= 0)
      return 0.0;

   ArrayResize(values, count);
   ArraySort(values);

   double p = percentile;
   if(p < 0.0)
      p = 0.0;
   if(p > 100.0)
      p = 100.0;

   int idx = (int)MathCeil((p / 100.0) * (double)count) - 1;
   if(idx < 0)
      idx = 0;
   if(idx >= count)
      idx = count - 1;
   return values[idx];
  }

bool Strategy_BasketMedianReturn(const int shift, double &median_ret, int &valid_count)
  {
   median_ret = 0.0;
   valid_count = 0;

   double values[];
   ArrayResize(values, STRATEGY_BASKET_SIZE);
   for(int i = 0; i < STRATEGY_BASKET_SIZE; ++i)
     {
      double r = 0.0;
      double c = 0.0;
      if(!Strategy_ReadReturn(g_strategy_basket[i], shift, r, c))
         continue;
      values[valid_count] = r;
      valid_count++;
     }

   if(valid_count < strategy_min_basket_symbols)
      return false;

   median_ret = Strategy_Percentile(values, valid_count, 50.0);
   return true;
  }

bool Strategy_BetaForSymbol(const string symbol, double &beta, int &observations)
  {
   beta = 0.0;
   observations = 0;

   if(strategy_beta_days < 1 || strategy_same_slot_bars_per_day < 1)
      return false;

   double sx = 0.0;
   double sy = 0.0;
   double sxx = 0.0;
   double sxy = 0.0;

   for(int day = 1; day <= strategy_beta_days; ++day)
     {
      const int shift = 1 + day * strategy_same_slot_bars_per_day;

      double basket_ret = 0.0;
      int valid_basket = 0;
      if(!Strategy_BasketMedianReturn(shift, basket_ret, valid_basket))
         continue;

      double symbol_ret = 0.0;
      double close_price = 0.0;
      if(!Strategy_ReadReturn(symbol, shift, symbol_ret, close_price))
         continue;

      sx += basket_ret;
      sy += symbol_ret;
      sxx += basket_ret * basket_ret;
      sxy += basket_ret * symbol_ret;
      observations++;
     }

   if(observations < strategy_min_beta_observations)
      return false;

   const double n = (double)observations;
   const double var_x = sxx - (sx * sx / n);
   if(MathAbs(var_x) <= 1e-12)
      return false;

   beta = (sxy - (sx * sy / n)) / var_x;
   return true;
  }

bool Strategy_CurrentSpreadAllows()
  {
   if(strategy_spread_lookback_days < 1 || strategy_same_slot_bars_per_day < 1)
      return true;

   // .DWX BACKTEST INVARIANT #1: the Darwinex tester quotes ask == bid, so
   // SYMBOL_SPREAD and iSpread() both read 0. A spread filter that fail-closes
   // on a zero current spread (or that can never build a non-zero rolling
   // percentile) would block every trade. Treat a non-positive current spread
   // as "no measurable spread" and ALLOW; only an explicitly-too-wide live
   // spread relative to the rolling 80th percentile is rejected.
   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0)
      return true;

   double spreads[];
   ArrayResize(spreads, strategy_spread_lookback_days);
   int count = 0;
   for(int day = 1; day <= strategy_spread_lookback_days; ++day)
     {
      const int shift = 1 + day * strategy_same_slot_bars_per_day;
      const long spread_value = iSpread(_Symbol, strategy_signal_tf, shift); // perf-allowed: bounded same-slot spread sample, called only from framework QM_IsNewBar-gated EntrySignal.
      if(spread_value <= 0)
         continue;
      spreads[count] = (double)spread_value;
      count++;
     }

   // Not enough historical spread observations (e.g. all-zero .DWX history) →
   // the percentile is undefined, so do not block.
   if(count < strategy_min_beta_observations)
      return true;

   const double threshold = Strategy_Percentile(spreads, count, strategy_spread_percentile);
   if(threshold <= 0.0)
      return true;
   return ((double)current_spread <= threshold);
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != strategy_signal_tf)
      return true;
   if(!Strategy_IsBasketSymbol(_Symbol))
      return true;
   if(Strategy_HasOpenPosition())
      return false;

   const datetime broker_now = TimeCurrent();
   if(!Strategy_SessionEntrySlotAllows(broker_now))
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

   if(!Strategy_IsBasketSymbol(_Symbol))
      return false;

   const datetime signal_bar_time = TimeCurrent() - strategy_slot_minutes * 60;
   if(!Strategy_SessionEntrySlotAllows(signal_bar_time))
      return false;

   double current_basket_ret = 0.0;
   int current_valid = 0;
   if(!Strategy_BasketMedianReturn(1, current_basket_ret, current_valid))
      return false;

   string strongest_symbol = "";
   int strongest_direction = 0;
   double strongest_abs_residual = 0.0;

   for(int i = 0; i < STRATEGY_BASKET_SIZE; ++i)
     {
      const string symbol = g_strategy_basket[i];

      double symbol_ret = 0.0;
      double symbol_close = 0.0;
      if(!Strategy_ReadReturn(symbol, 1, symbol_ret, symbol_close))
         continue;

      double beta = 0.0;
      int obs = 0;
      if(!Strategy_BetaForSymbol(symbol, beta, obs))
         continue;

      const double atr = QM_ATR(symbol, strategy_signal_tf, strategy_atr_period, 1);
      if(atr <= 0.0 || symbol_close <= 0.0)
         continue;

      const double residual = symbol_ret - beta * current_basket_ret;
      const double threshold = strategy_residual_atr_mult * (atr / symbol_close);
      int direction = 0;
      if(residual < -threshold)
         direction = 1;
      else if(residual > threshold)
         direction = -1;
      else
         continue;

      const double abs_residual = MathAbs(residual);
      if(abs_residual > strongest_abs_residual)
        {
         strongest_abs_residual = abs_residual;
         strongest_symbol = symbol;
         strongest_direction = direction;
        }
     }

   if(strongest_direction == 0 || strongest_symbol != _Symbol)
      return false;
   if(!Strategy_CurrentSpreadAllows())
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   const QM_OrderType side = (strongest_direction > 0) ? QM_BUY : QM_SELL;
   const double entry = (strongest_direction > 0) ? ask : bid;
   const double atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double stop_distance = atr * strategy_stop_atr_mult;
   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread_points > 0 && stop_distance < 3.0 * (double)spread_points * point)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr, strategy_stop_atr_mult);
   if(sl <= 0.0)
      return false;

   req.type = side;
   req.price = NormalizeDouble(entry, _Digits);
   req.sl = sl;
   req.tp = 0.0;
   req.reason = (strongest_direction > 0) ? "RESIDUAL_REV_LONG" : "RESIDUAL_REV_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, or pyramiding.
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || strategy_slot_minutes <= 0)
      return false;

   const datetime broker_now = TimeCurrent();
   const int hold_seconds = strategy_slot_minutes * 60;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(open_time > 0 && broker_now >= open_time + hold_seconds)
         return true;
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // Defer to the central two-axis news filter (QM_NewsAllowsTrade2). No custom
   // high-impact handling required for this strategy. MQL5 does not warn on
   // unused parameters, so broker_time is simply left untouched (a C-style
   // `(void)broker_time;` cast is illegal in MQL5 — error 143).
   return false;
  }

int OnInit()
  {
   Strategy_InitBasket();
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

   QM_SymbolGuardInit(g_strategy_basket);
   QM_BasketWarmupHistory(g_strategy_basket, strategy_signal_tf, strategy_basket_warmup_bars);
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10328\",\"strategy\":\"residual-rev\"}");
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
