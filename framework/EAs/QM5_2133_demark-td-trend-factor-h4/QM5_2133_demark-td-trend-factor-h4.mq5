#property strict
#property version   "5.0"
#property description "QM5_2133 DeMark TD Trend Factor H4"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 2133;
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
input double strategy_factor_1              = 1.0556;
input double strategy_factor_2              = 1.1118;
input double strategy_down_factor_1         = 0.9474;
input double strategy_down_factor_2         = 0.8993;
input int    strategy_pivot_wing_bars       = 2;
input int    strategy_max_active_per_side   = 4;
input int    strategy_projection_expiry_h4  = 200;
input int    strategy_zone_window_h4        = 8;
input int    strategy_trend_lookback_h4     = 20;
input int    strategy_atr_period            = 20;
input int    strategy_atr_slow_period       = 50;
input int    strategy_d1_ema_period         = 50;
input double strategy_spread_atr_mult       = 0.30;
input double strategy_min_projection_atr    = 1.50;
input double strategy_vol_ratio_max         = 2.00;
input double strategy_entry_stop_atr_mult   = 0.50;
input double strategy_hard_stop_atr_mult    = 0.30;
input double strategy_trail_atr_mult        = 2.00;
input int    strategy_time_stop_h4_bars     = 60;
input int    strategy_warmup_h4_bars        = 200;

#define QM2133_MAX_PROJECTIONS 4

struct TFProjection
  {
   bool     active;
   double   pivot;
   double   level1;
   double   level2;
   int      age;
   bool     touched;
   int      touch_age;
   datetime pivot_time;
  };

TFProjection g_up_projections[QM2133_MAX_PROJECTIONS];
TFProjection g_dn_projections[QM2133_MAX_PROJECTIONS];

bool   g_close_long_conflict       = false;
bool   g_close_short_conflict      = false;
double g_last_entry_pivot          = 0.0;
bool   g_last_entry_target_reached = false;

int ClampProjectionCount()
  {
   if(strategy_max_active_per_side < 1)
      return 1;
   if(strategy_max_active_per_side > QM2133_MAX_PROJECTIONS)
      return QM2133_MAX_PROJECTIONS;
   return strategy_max_active_per_side;
  }

double NormalizeStrategyPrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   return QM_StopRulesNormalizePrice(_Symbol, price);
  }

void ClearProjection(TFProjection &p)
  {
   p.active = false;
   p.pivot = 0.0;
   p.level1 = 0.0;
   p.level2 = 0.0;
   p.age = 0;
   p.touched = false;
   p.touch_age = 0;
   p.pivot_time = 0;
  }

void AgeProjections(TFProjection &items[])
  {
   const int count = ClampProjectionCount();
   for(int i = 0; i < count; ++i)
     {
      if(!items[i].active)
         continue;
      items[i].age++;
      if(items[i].touched)
         items[i].touch_age++;
      if(items[i].age > strategy_projection_expiry_h4)
         ClearProjection(items[i]);
     }
  }

bool ProjectionExists(TFProjection &items[], const datetime pivot_time)
  {
   const int count = ClampProjectionCount();
   for(int i = 0; i < count; ++i)
      if(items[i].active && items[i].pivot_time == pivot_time)
         return true;
   return false;
  }

void AddProjection(TFProjection &items[],
                   const datetime pivot_time,
                   const double pivot,
                   const double level1,
                   const double level2)
  {
   const int count = ClampProjectionCount();
   if(pivot_time <= 0 || pivot <= 0.0 || level1 <= 0.0 || level2 <= 0.0)
      return;
   if(ProjectionExists(items, pivot_time))
      return;

   for(int i = count - 1; i > 0; --i)
      items[i] = items[i - 1];

   items[0].active = true;
   items[0].pivot = pivot;
   items[0].level1 = level1;
   items[0].level2 = level2;
   items[0].age = 0;
   items[0].touched = false;
   items[0].touch_age = 0;
   items[0].pivot_time = pivot_time;
  }

bool FindOurPosition(ulong &ticket,
                     ENUM_POSITION_TYPE &position_type,
                     double &open_price,
                     datetime &open_time)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   open_price = 0.0;
   open_time = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = candidate;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

int H4BarsHeld(const datetime open_time)
  {
   if(open_time <= 0)
      return 0;

   const int h4_seconds = PeriodSeconds(PERIOD_H4);
   if(h4_seconds <= 0)
      return 0;

   const int held = (int)((TimeCurrent() - open_time) / h4_seconds);
   return (held > 0) ? held : 0;
  }

bool StrategyParamsValid()
  {
   return strategy_factor_1 > 1.0 &&
          strategy_factor_2 > strategy_factor_1 &&
          strategy_down_factor_1 > 0.0 &&
          strategy_down_factor_1 < 1.0 &&
          strategy_down_factor_2 > 0.0 &&
          strategy_down_factor_2 < strategy_down_factor_1 &&
          strategy_pivot_wing_bars == 2 &&
          strategy_projection_expiry_h4 > 0 &&
          strategy_zone_window_h4 >= 0 &&
          strategy_trend_lookback_h4 > 0 &&
          strategy_atr_period > 0 &&
          strategy_atr_slow_period > strategy_atr_period &&
          strategy_d1_ema_period > 0 &&
          strategy_spread_atr_mult >= 0.0 &&
          strategy_min_projection_atr >= 0.0 &&
          strategy_vol_ratio_max > 0.0 &&
          strategy_entry_stop_atr_mult > 0.0 &&
          strategy_hard_stop_atr_mult >= 0.0 &&
          strategy_trail_atr_mult > 0.0 &&
          strategy_time_stop_h4_bars > 0 &&
          strategy_warmup_h4_bars >= strategy_projection_expiry_h4;
  }

bool IsQualifiedSwingLow(const MqlRates &rates[], const int shift)
  {
   const double low = rates[shift].low;
   return low > 0.0 &&
          rates[shift + 2].low > low &&
          rates[shift + 1].low > low &&
          rates[shift - 1].low > low &&
          rates[shift - 2].low > low;
  }

bool IsQualifiedSwingHigh(const MqlRates &rates[], const int shift)
  {
   const double high = rates[shift].high;
   return high > 0.0 &&
          rates[shift + 2].high < high &&
          rates[shift + 1].high < high &&
          rates[shift - 1].high < high &&
          rates[shift - 2].high < high;
  }

void DetectNewPivots(const MqlRates &rates[], const double atr)
  {
   const int pivot_shift = strategy_pivot_wing_bars + 1;
   if(ArraySize(rates) <= pivot_shift + strategy_pivot_wing_bars)
      return;

   if(IsQualifiedSwingLow(rates, pivot_shift))
     {
      const double pivot = rates[pivot_shift].low;
      const double level1 = pivot * strategy_factor_1;
      const double level2 = pivot * strategy_factor_2;
      if(level1 - pivot >= strategy_min_projection_atr * atr)
         AddProjection(g_up_projections, rates[pivot_shift].time, pivot, level1, level2);
     }

   if(IsQualifiedSwingHigh(rates, pivot_shift))
     {
      const double pivot = rates[pivot_shift].high;
      const double level1 = pivot * strategy_down_factor_1;
      const double level2 = pivot * strategy_down_factor_2;
      if(pivot - level1 >= strategy_min_projection_atr * atr)
         AddProjection(g_dn_projections, rates[pivot_shift].time, pivot, level1, level2);
     }
  }

bool UpProjectionSignalsShort(TFProjection &p,
                              const MqlRates &bar,
                              const double d1_ema,
                              const double close_lookback)
  {
   if(!p.active)
      return false;

   if(!p.touched && bar.high >= p.level1 && bar.high <= p.level2)
     {
      p.touched = true;
      p.touch_age = 0;
     }

   const bool timing_ok = p.touched && p.touch_age <= strategy_zone_window_h4;
   const bool qualifier = bar.high >= p.level1 &&
                          bar.high <= p.level2 &&
                          bar.close > p.level1 &&
                          bar.close <= p.level2 &&
                          bar.close < bar.open;
   const bool trend_ok = close_lookback < d1_ema && bar.close > d1_ema;
   return timing_ok && qualifier && trend_ok;
  }

bool DownProjectionSignalsLong(TFProjection &p,
                               const MqlRates &bar,
                               const double d1_ema,
                               const double close_lookback)
  {
   if(!p.active)
      return false;

   if(!p.touched && bar.low <= p.level1 && bar.low >= p.level2)
     {
      p.touched = true;
      p.touch_age = 0;
     }

   const bool timing_ok = p.touched && p.touch_age <= strategy_zone_window_h4;
   const bool qualifier = bar.low <= p.level1 &&
                          bar.low >= p.level2 &&
                          bar.close < p.level1 &&
                          bar.close >= p.level2 &&
                          bar.close > bar.open;
   const bool trend_ok = close_lookback > d1_ema && bar.close < d1_ema;
   return timing_ok && qualifier && trend_ok;
  }

bool RefreshTrendFactorState(QM_EntryRequest &req)
  {
   g_close_long_conflict = false;
   g_close_short_conflict = false;

   if(!StrategyParamsValid())
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double atr_slow = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_slow_period, 1);
   const double d1_ema = QM_EMA(_Symbol, PERIOD_D1, strategy_d1_ema_period, 1, PRICE_CLOSE);
   if(atr <= 0.0 || atr_slow <= 0.0 || d1_ema <= 0.0)
      return false;

   if(atr / atr_slow > strategy_vol_ratio_max)
      return false;

   const int required = MathMax(strategy_warmup_h4_bars,
                                strategy_trend_lookback_h4 + strategy_pivot_wing_bars + 8);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_H4, 0, required + 5, rates); // perf-allowed: TD-Trend-Factor requires bespoke 5-bar swing-pivot structure and is evaluated only after the framework QM_IsNewBar gate.
   if(copied < required)
      return false;

   AgeProjections(g_up_projections);
   AgeProjections(g_dn_projections);
   DetectNewPivots(rates, atr);

   const MqlRates bar = rates[1];
   const double close_lookback = rates[1 + strategy_trend_lookback_h4].close;
   if(bar.open <= 0.0 || bar.high <= 0.0 || bar.low <= 0.0 || bar.close <= 0.0 || close_lookback <= 0.0)
      return false;

   bool short_signal = false;
   bool long_signal = false;
   int short_index = -1;
   int long_index = -1;

   const int count = ClampProjectionCount();
   for(int i = 0; i < count; ++i)
     {
      if(UpProjectionSignalsShort(g_up_projections[i], bar, d1_ema, close_lookback))
        {
         short_signal = true;
         short_index = i;
         break;
        }
     }

   for(int i = 0; i < count; ++i)
     {
      if(DownProjectionSignalsLong(g_dn_projections[i], bar, d1_ema, close_lookback))
        {
         long_signal = true;
         long_index = i;
         break;
        }
     }

   g_close_long_conflict = short_signal;
   g_close_short_conflict = long_signal;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(short_signal && short_index >= 0)
     {
      TFProjection p = g_up_projections[short_index];
      const double stop_from_entry = bar.high + strategy_entry_stop_atr_mult * atr;
      const double hard_stop = p.level2 + strategy_hard_stop_atr_mult * atr;
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = NormalizeStrategyPrice(MathMax(stop_from_entry, hard_stop));
      req.tp = NormalizeStrategyPrice(p.pivot);
      req.reason = "TD_TREND_FACTOR_SHORT";
      if(req.sl > bid && req.tp > 0.0 && req.tp < bid)
        {
         g_last_entry_pivot = p.pivot;
         g_last_entry_target_reached = false;
         ClearProjection(g_up_projections[short_index]);
         return true;
        }
     }

   if(long_signal && long_index >= 0)
     {
      TFProjection p = g_dn_projections[long_index];
      const double stop_from_entry = bar.low - strategy_entry_stop_atr_mult * atr;
      const double hard_stop = p.level2 - strategy_hard_stop_atr_mult * atr;
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = NormalizeStrategyPrice(MathMin(stop_from_entry, hard_stop));
      req.tp = NormalizeStrategyPrice(p.pivot);
      req.reason = "TD_TREND_FACTOR_LONG";
      if(req.sl > 0.0 && req.sl < ask && req.tp > ask)
        {
         g_last_entry_pivot = p.pivot;
         g_last_entry_target_reached = false;
         ClearProjection(g_dn_projections[long_index]);
         return true;
        }
     }

   return false;
  }

bool Strategy_NoTradeFilter()
  {
   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double atr_slow = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_slow_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || atr_slow <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return true;

   if(ask > bid && (ask - bid) > strategy_spread_atr_mult * atr)
      return true;

   if(atr / atr_slow > strategy_vol_ratio_max)
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

   if(_Period != PERIOD_H4)
      return false;

   return RefreshTrendFactorState(req);
  }

void Strategy_ManageOpenPosition()
  {
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price;
   datetime open_time;
   if(!FindOurPosition(ticket, position_type, open_price, open_time))
      return;

   if(!g_last_entry_target_reached && g_last_entry_pivot > 0.0)
     {
      const bool is_buy = (position_type == POSITION_TYPE_BUY);
      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(market > 0.0)
        {
         if((is_buy && market >= g_last_entry_pivot) ||
            (!is_buy && market <= g_last_entry_pivot))
            g_last_entry_target_reached = true;
        }
     }

   if(g_last_entry_target_reached)
      QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr_mult);
  }

bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price;
   datetime open_time;
   if(!FindOurPosition(ticket, position_type, open_price, open_time))
      return false;

   if(H4BarsHeld(open_time) >= strategy_time_stop_h4_bars)
      return true;

   if(position_type == POSITION_TYPE_BUY && g_close_long_conflict)
      return true;
   if(position_type == POSITION_TYPE_SELL && g_close_short_conflict)
      return true;

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_2133\",\"strategy\":\"demark_td_trend_factor_h4\"}");
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
