#property strict
#property version   "5.0"
#property description "QM5_10974 ftmo-obv-brk"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10974;
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
input int    strategy_range_lookback     = 40;
input int    strategy_atr_period         = 14;
input int    strategy_trend_ema_period   = 100;
input int    strategy_trail_ema_period   = 20;
input double strategy_breakout_atr_mult  = 0.20;
input double strategy_stop_atr_buffer    = 0.25;
input double strategy_take_rr            = 2.0;
input double strategy_trail_trigger_r    = 1.5;
input double strategy_range_min_atr      = 1.2;
input double strategy_range_max_atr      = 5.0;
input double strategy_candle_max_atr     = 2.2;
input int    strategy_obv_confirm_bars   = 2;
input int    strategy_obv_exit_bars      = 2;
input int    strategy_max_hold_bars      = 30;
input double strategy_max_spread_atr     = 0.15;

double g_sig_close1             = 0.0;
double g_sig_high1              = 0.0;
double g_sig_low1               = 0.0;
double g_sig_atr                = 0.0;
double g_sig_range_high         = 0.0;
double g_sig_range_low          = 0.0;
double g_sig_range_mid          = 0.0;
bool   g_sig_obv_long_confirm   = false;
bool   g_sig_obv_short_confirm  = false;
double g_sig_obv_range_high     = 0.0;
double g_sig_obv_range_low      = 0.0;

bool   g_latched_position       = false;
double g_latched_entry          = 0.0;
double g_latched_risk           = 0.0;
double g_latched_obv_high       = 0.0;
double g_latched_obv_low        = 0.0;
bool   g_latched_trail_armed    = false;
bool   g_cached_obv_exit        = false;

bool RefreshClosedBarState()
  {
   g_sig_close1            = 0.0;
   g_sig_high1             = 0.0;
   g_sig_low1              = 0.0;
   g_sig_atr               = 0.0;
   g_sig_range_high        = 0.0;
   g_sig_range_low         = 0.0;
   g_sig_range_mid         = 0.0;
   g_sig_obv_long_confirm  = false;
   g_sig_obv_short_confirm = false;
   g_sig_obv_range_high    = 0.0;
   g_sig_obv_range_low     = 0.0;
   g_cached_obv_exit       = false;

   const int lb = strategy_range_lookback;
   const int confirm_bars = MathMax(1, strategy_obv_confirm_bars);
   const int need_bars = lb + confirm_bars + strategy_obv_exit_bars + 4;
   if(lb < 2 || need_bars < 10)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, _Period, 0, need_bars, rates); // perf-allowed: closed-bar OBV/range rebuild, called only from the new-bar entry hook
   if(copied < need_bars)
      return false;

   double obv[];
   ArrayResize(obv, need_bars);
   ArrayInitialize(obv, 0.0);
   for(int s = need_bars - 2; s >= 1; --s)
     {
      obv[s] = obv[s + 1];
      const double vol = (double)rates[s].tick_volume;
      if(rates[s].close > rates[s + 1].close)
         obv[s] += vol;
      else if(rates[s].close < rates[s + 1].close)
         obv[s] -= vol;
     }

   g_sig_close1 = rates[1].close;
   g_sig_high1  = rates[1].high;
   g_sig_low1   = rates[1].low;
   if(g_sig_close1 <= 0.0 || g_sig_high1 <= 0.0 || g_sig_low1 <= 0.0)
      return false;

   g_sig_range_high = -DBL_MAX;
   g_sig_range_low  = DBL_MAX;
   for(int s = 2; s <= lb + 1; ++s)
     {
      if(rates[s].high > g_sig_range_high)
         g_sig_range_high = rates[s].high;
      if(rates[s].low < g_sig_range_low)
         g_sig_range_low = rates[s].low;
     }
   if(g_sig_range_high <= 0.0 || g_sig_range_low <= 0.0 || g_sig_range_high <= g_sig_range_low)
      return false;

   g_sig_range_mid = 0.5 * (g_sig_range_high + g_sig_range_low);
   g_sig_atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(g_sig_atr <= 0.0)
      return false;

   g_sig_obv_range_high = -DBL_MAX;
   g_sig_obv_range_low  = DBL_MAX;
   for(int s = 2; s <= lb + 1; ++s)
     {
      if(obv[s] > g_sig_obv_range_high)
         g_sig_obv_range_high = obv[s];
      if(obv[s] < g_sig_obv_range_low)
         g_sig_obv_range_low = obv[s];
     }

   for(int k = 1; k <= confirm_bars; ++k)
     {
      double hi = -DBL_MAX;
      double lo = DBL_MAX;
      for(int s = k + 1; s <= k + lb; ++s)
        {
         if(obv[s] > hi)
            hi = obv[s];
         if(obv[s] < lo)
            lo = obv[s];
        }
      if(obv[k] > hi)
         g_sig_obv_long_confirm = true;
      if(obv[k] < lo)
         g_sig_obv_short_confirm = true;
     }

   if(g_latched_position && strategy_obv_exit_bars > 0)
     {
      int inside_count = 0;
      for(int k = 1; k <= strategy_obv_exit_bars; ++k)
        {
         if(obv[k] >= g_latched_obv_low && obv[k] <= g_latched_obv_high)
            inside_count++;
         else
            break;
        }
      g_cached_obv_exit = (inside_count >= strategy_obv_exit_bars);
     }

   return true;
  }

void LatchEntryState(const double entry_price, const double sl_price)
  {
   g_latched_position    = true;
   g_latched_entry       = entry_price;
   g_latched_risk        = MathAbs(entry_price - sl_price);
   g_latched_obv_high    = g_sig_obv_range_high;
   g_latched_obv_low     = g_sig_obv_range_low;
   g_latched_trail_armed = false;
   g_cached_obv_exit     = false;
  }

bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(ask > bid)
     {
      const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
      if(atr_value > 0.0 && (ask - bid) > strategy_max_spread_atr * atr_value)
         return true;
     }

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

   if(!RefreshClosedBarState())
      return false;

   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   const double range_height = g_sig_range_high - g_sig_range_low;
   if(range_height < strategy_range_min_atr * g_sig_atr)
      return false;
   if(range_height > strategy_range_max_atr * g_sig_atr)
      return false;
   if((g_sig_high1 - g_sig_low1) > strategy_candle_max_atr * g_sig_atr)
      return false;

   const double trend_ema = QM_EMA(_Symbol, _Period, strategy_trend_ema_period, 1);
   if(trend_ema <= 0.0)
      return false;

   const double breakout_buffer = strategy_breakout_atr_mult * g_sig_atr;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(g_sig_close1 > g_sig_range_high + breakout_buffer &&
      g_sig_obv_long_confirm &&
      g_sig_close1 > trend_ema)
     {
      const double entry_price = (ask > 0.0) ? ask : g_sig_close1;
      const double candle_stop = g_sig_low1 - strategy_stop_atr_buffer * g_sig_atr;
      const double sl_price = QM_StopRulesNormalizePrice(_Symbol, MathMin(g_sig_range_mid, candle_stop));
      if(sl_price <= 0.0 || sl_price >= entry_price)
         return false;
      const double tp_price = QM_TakeRR(_Symbol, QM_BUY, entry_price, sl_price, strategy_take_rr);
      if(tp_price <= 0.0)
         return false;

      req.type = QM_BUY;
      req.sl = sl_price;
      req.tp = tp_price;
      req.reason = "obv_breakout_long";
      LatchEntryState(entry_price, sl_price);
      return true;
     }

   if(g_sig_close1 < g_sig_range_low - breakout_buffer &&
      g_sig_obv_short_confirm &&
      g_sig_close1 < trend_ema)
     {
      const double entry_price = (bid > 0.0) ? bid : g_sig_close1;
      const double candle_stop = g_sig_high1 + strategy_stop_atr_buffer * g_sig_atr;
      const double sl_price = QM_StopRulesNormalizePrice(_Symbol, MathMax(g_sig_range_mid, candle_stop));
      if(sl_price <= 0.0 || sl_price <= entry_price)
         return false;
      const double tp_price = QM_TakeRR(_Symbol, QM_SELL, entry_price, sl_price, strategy_take_rr);
      if(tp_price <= 0.0)
         return false;

      req.type = QM_SELL;
      req.sl = sl_price;
      req.tp = tp_price;
      req.reason = "obv_breakout_short";
      LatchEntryState(entry_price, sl_price);
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   bool found = false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      found = true;
      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double current_tp = PositionGetDouble(POSITION_TP);
      const bool is_long = (pos_type == POSITION_TYPE_BUY);

      if(!g_latched_position)
        {
         g_latched_position = true;
         g_latched_entry = open_price;
         if(current_sl > 0.0)
            g_latched_risk = MathAbs(open_price - current_sl);
         else if(current_tp > 0.0 && strategy_take_rr > 0.0)
            g_latched_risk = MathAbs(current_tp - open_price) / strategy_take_rr;
         g_latched_trail_armed = false;
        }

      if(g_latched_risk <= 0.0)
         break;

      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(bid <= 0.0 || ask <= 0.0)
         break;

      if(!g_latched_trail_armed)
        {
         if(is_long && bid >= open_price + strategy_trail_trigger_r * g_latched_risk)
            g_latched_trail_armed = true;
         if(!is_long && ask <= open_price - strategy_trail_trigger_r * g_latched_risk)
            g_latched_trail_armed = true;
        }

      if(!g_latched_trail_armed)
         break;

      const double trail_ema = QM_EMA(_Symbol, _Period, strategy_trail_ema_period, 1);
      if(trail_ema <= 0.0)
         break;

      const double new_sl = QM_StopRulesNormalizePrice(_Symbol, trail_ema);
      if(is_long)
        {
         if(new_sl > current_sl && new_sl < bid)
            QM_TM_MoveSL(ticket, new_sl, "ema20_trail_after_1_5r");
        }
      else
        {
         if((current_sl <= 0.0 || new_sl < current_sl) && new_sl > ask)
            QM_TM_MoveSL(ticket, new_sl, "ema20_trail_after_1_5r");
        }
      break;
     }

   if(!found)
     {
      g_latched_position = false;
      g_latched_entry = 0.0;
      g_latched_risk = 0.0;
      g_latched_trail_armed = false;
      g_cached_obv_exit = false;
     }
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      if(g_cached_obv_exit)
         return true;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int period_seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
      if(open_time > 0 && period_seconds > 0 && strategy_max_hold_bars > 0)
        {
         if((TimeCurrent() - open_time) >= strategy_max_hold_bars * period_seconds)
            return true;
        }

      return false;
     }

   g_latched_position = false;
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
