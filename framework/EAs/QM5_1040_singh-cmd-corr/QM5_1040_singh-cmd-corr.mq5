#property strict
#property version   "5.0"
#property description "QM5_1040 Singh Oil CADJPY Correlation"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_1040 - Singh Commodity Correlation, Part 1
// -----------------------------------------------------------------------------
// D1 structural intermarket sleeve:
//   - host/traded symbol: CADJPY.DWX
//   - leading symbol: XTIUSD.DWX, read-only oil chart
//   - oil D1 support/resistance breakout triggers next-bar CADJPY entry
//   - CADJPY risk uses ATR stop and fixed 3R target
// Runtime uses broker OHLC, ATR helpers, framework news/friday/risk gates only.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1040;
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
input string strategy_oil_symbol                 = "XTIUSD.DWX";
input int    strategy_sr_lookback_bars           = 30;
input int    strategy_min_touches                = 2;
input int    strategy_min_level_age_bars         = 10;
input double strategy_touch_tolerance_atr        = 0.25;
input int    strategy_atr_period                 = 14;
input double strategy_sl_atr_mult                = 2.0;
input double strategy_tp_rr                      = 3.0;
input int    strategy_atr_floor_period           = 30;
input double strategy_atr_floor_ratio            = 0.70;
input double strategy_leading_max_daily_range_pct = 5.0;
input int    strategy_max_hold_days              = 30;
input int    strategy_max_spread_points          = 120;

datetime g_last_oil_signal_time = 0;

bool Strategy_IsCadjpyD1()
  {
   return (_Symbol == "CADJPY.DWX" && _Period == PERIOD_D1);
  }

int Strategy_DaysBetween(const datetime later_time, const datetime earlier_time)
  {
   if(later_time <= 0 || earlier_time <= 0 || later_time < earlier_time)
      return 0;
   return (int)((later_time - earlier_time) / 86400);
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

bool Strategy_SpreadAllowsEntry()
  {
   if(strategy_max_spread_points <= 0)
      return true;
   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread_points <= strategy_max_spread_points);
  }

double Strategy_HighestHigh(const MqlRates &rates[], const int start_index, const int end_index)
  {
   double value = -DBL_MAX;
   for(int i = start_index; i <= end_index; ++i)
     {
      if(rates[i].high > value)
         value = rates[i].high;
     }
   return value;
  }

double Strategy_LowestLow(const MqlRates &rates[], const int start_index, const int end_index)
  {
   double value = DBL_MAX;
   for(int i = start_index; i <= end_index; ++i)
     {
      if(rates[i].low < value)
         value = rates[i].low;
     }
   return value;
  }

int Strategy_CountTouches(const MqlRates &rates[],
                          const int start_index,
                          const int end_index,
                          const double level,
                          const double tolerance,
                          const bool use_high,
                          int &youngest_touch_shift)
  {
   int touches = 0;
   youngest_touch_shift = 1000000;

   for(int i = start_index; i <= end_index; ++i)
     {
      const double price = use_high ? rates[i].high : rates[i].low;
      if(MathAbs(price - level) <= tolerance)
        {
         ++touches;
         if(i < youngest_touch_shift)
            youngest_touch_shift = i;
        }
     }
   return touches;
  }

bool Strategy_LoadOilBreakout(int &direction, datetime &signal_time)
  {
   direction = 0;
   signal_time = 0;

   if(!QM_SymbolAssertOrLog(strategy_oil_symbol))
      return false;

   const int lookback = MathMax(10, strategy_sr_lookback_bars);
   const int bars_needed = lookback + 1;
   MqlRates oil_rates[];
   ArraySetAsSeries(oil_rates, true);
   const int copied = CopyRates(strategy_oil_symbol, PERIOD_D1, 1, bars_needed, oil_rates); // perf-allowed: bounded D1 leading-instrument breakout state, called only after QM_IsNewBar().
   if(copied < bars_needed)
      return false;

   const double close_last = oil_rates[0].close;
   signal_time = oil_rates[0].time;
   if(close_last <= 0.0 || signal_time <= 0)
      return false;

   if(strategy_leading_max_daily_range_pct > 0.0)
     {
      const double range_pct = 100.0 * (oil_rates[0].high - oil_rates[0].low) / close_last;
      if(range_pct > strategy_leading_max_daily_range_pct)
         return false;
     }

   const double oil_atr = QM_ATR(strategy_oil_symbol, PERIOD_D1, strategy_atr_period, 1);
   if(oil_atr <= 0.0)
      return false;
   const double touch_tolerance = oil_atr * MathMax(0.0, strategy_touch_tolerance_atr);

   const double resistance = Strategy_HighestHigh(oil_rates, 1, lookback);
   const double support = Strategy_LowestLow(oil_rates, 1, lookback);
   if(resistance <= 0.0 || support <= 0.0 || resistance <= support)
      return false;

   int youngest_resistance_touch = 0;
   int youngest_support_touch = 0;
   const int resistance_touches = Strategy_CountTouches(oil_rates,
                                                        1,
                                                        lookback,
                                                        resistance,
                                                        touch_tolerance,
                                                        true,
                                                        youngest_resistance_touch);
   const int support_touches = Strategy_CountTouches(oil_rates,
                                                     1,
                                                     lookback,
                                                     support,
                                                     touch_tolerance,
                                                     false,
                                                     youngest_support_touch);
   const int min_touches = MathMax(1, strategy_min_touches);
   const int min_age = MathMax(0, strategy_min_level_age_bars);

   if(close_last > resistance &&
      resistance_touches >= min_touches &&
      youngest_resistance_touch >= min_age)
     {
      direction = 1;
      return true;
     }

   if(close_last < support &&
      support_touches >= min_touches &&
      youngest_support_touch >= min_age)
     {
      direction = -1;
      return true;
     }

   return true;
  }

bool Strategy_TradeInstrumentVolatilityAllows()
  {
   const double atr_current = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_current <= 0.0)
      return false;
   if(strategy_atr_floor_ratio <= 0.0 || strategy_atr_floor_period <= strategy_atr_period)
      return true;

   const double atr_floor = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_floor_period, 1);
   if(atr_floor <= 0.0)
      return false;
   return (atr_current >= atr_floor * strategy_atr_floor_ratio);
  }

bool Strategy_BuildEntryRequest(const int direction, QM_EntryRequest &req)
  {
   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = (direction > 0) ? "SINGH_OIL_CADJPY_LONG" : "SINGH_OIL_CADJPY_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const double atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_last <= 0.0)
      return false;

   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry_price, atr_last, strategy_sl_atr_mult);
   if(req.sl <= 0.0)
      return false;
   if(req.type == QM_BUY && req.sl >= entry_price)
      return false;
   if(req.type == QM_SELL && req.sl <= entry_price)
      return false;

   const double risk_distance = MathAbs(entry_price - req.sl);
   if(risk_distance <= 0.0)
      return false;

   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double raw_tp = (req.type == QM_BUY)
                         ? entry_price + strategy_tp_rr * risk_distance
                         : entry_price - strategy_tp_rr * risk_distance;
   req.tp = NormalizeDouble(raw_tp, digits);
   return (req.tp > 0.0);
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsCadjpyD1())
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_oil_symbol != "XTIUSD.DWX")
      return true;
   if(strategy_sr_lookback_bars < 10 || strategy_min_touches < 1)
      return true;
   if(strategy_atr_period <= 0 || strategy_sl_atr_mult <= 0.0 || strategy_tp_rr <= 0.0)
      return true;
   if(strategy_atr_floor_period > 0 && strategy_atr_floor_period <= strategy_atr_period)
      return true;
   if(strategy_leading_max_daily_range_pct < 0.0 || strategy_max_hold_days <= 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_1040_SINGH_CMD_CORR";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;
   if(!Strategy_TradeInstrumentVolatilityAllows())
      return false;

   int direction = 0;
   datetime signal_time = 0;
   if(!Strategy_LoadOilBreakout(direction, signal_time))
      return false;
   if(direction == 0)
      return false;
   if(signal_time <= 0 || signal_time == g_last_oil_signal_time)
      return false;

   if(!Strategy_BuildEntryRequest(direction, req))
      return false;

   g_last_oil_signal_time = signal_time;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

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
      if(opened > 0 && now - opened >= hold_seconds)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
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
   if(!SymbolSelect(strategy_oil_symbol, true))
     {
      PrintFormat("QM5_1040 failed to select leading symbol %s", strategy_oil_symbol);
      return INIT_FAILED;
     }

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

   string allowed_symbols[2];
   allowed_symbols[0] = _Symbol;
   allowed_symbols[1] = strategy_oil_symbol;
   QM_SymbolGuardInit(allowed_symbols);

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1040\",\"ea\":\"singh-cmd-corr\",\"variant\":\"oil-cadjpy\"}");
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

