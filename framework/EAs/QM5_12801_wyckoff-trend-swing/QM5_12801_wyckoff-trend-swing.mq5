#property strict
#property version   "5.0"
#property description "QM5_12801 Wyckoff Trend Swing H4"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12801;
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
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_tf              = PERIOD_H4;
input int    strategy_sr_lookback_bars         = 36;
input int    strategy_volume_lookback_bars     = 24;
input double strategy_volume_spike_mult        = 1.25;
input int    strategy_atr_period               = 14;
input int    strategy_fast_ema_period          = 50;
input int    strategy_slow_ema_period          = 200;
input int    strategy_adx_period               = 14;
input double strategy_adx_min                  = 17.0;
input double strategy_sr_touch_atr_mult        = 0.45;
input double strategy_reclaim_atr_mult         = 0.12;
input double strategy_sl_atr_mult              = 2.2;
input double strategy_sl_buffer_atr_mult       = 0.35;
input double strategy_max_sl_atr_mult          = 3.2;
input double strategy_partial_rr               = 1.5;
input double strategy_partial_fraction         = 0.50;
input double strategy_trail_atr_mult           = 1.2;
input int    strategy_reentry_guard_bars       = 8;
input int    strategy_time_stop_bars           = 45;
input double strategy_spread_atr_mult          = 0.20;
input double strategy_min_atr_close_pct        = 0.0015;
input double strategy_max_atr_close_pct        = 0.0600;

ulong    g_managed_ticket = 0;
bool     g_partial_done = false;
double   g_initial_risk = 0.0;
datetime g_entry_bar_time = 0;
datetime g_last_signal_time = 0;

string Strategy_SymbolForSlot(const int slot)
  {
   switch(slot)
     {
      case 0: return "NDX.DWX";
      case 1: return "GDAXI.DWX";
      case 2: return "SP500.DWX";
      case 3: return "XAUUSD.DWX";
     }
   return "";
  }

bool Strategy_SlotMatchesSymbol()
  {
   return (Strategy_SymbolForSlot(qm_magic_slot_offset) == _Symbol);
  }

bool Strategy_SelectOurPosition(ulong &ticket)
  {
   ticket = 0;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      ticket = t;
      return true;
     }
   return false;
  }

bool Strategy_BasicMarketOk(const double atr)
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || atr <= 0.0)
      return false;
   if((ask - bid) > strategy_spread_atr_mult * atr)
      return false;
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != strategy_tf)
      return true;
   if(qm_magic_slot_offset < 0 || qm_magic_slot_offset > 3)
      return true;
   if(!Strategy_SlotMatchesSymbol())
      return true;

   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   if(!Strategy_BasicMarketOk(atr))
      return true;
   return false;
  }

double Strategy_AverageVolume(const MqlRates &rates[], const int first_shift, const int bars, const int copied)
  {
   if(bars <= 0 || first_shift + bars > copied)
      return 0.0;

   double total = 0.0;
   for(int i = first_shift; i < first_shift + bars; ++i)
      total += (double)rates[i].tick_volume;
   return total / (double)bars;
  }

bool Strategy_FindSupportResistance(const MqlRates &rates[],
                                    const int copied,
                                    double &support,
                                    double &resistance)
  {
   support = DBL_MAX;
   resistance = -DBL_MAX;
   const int last_shift = strategy_sr_lookback_bars + 1;
   if(last_shift >= copied)
      return false;

   for(int i = 2; i <= last_shift; ++i)
     {
      support = MathMin(support, rates[i].low);
      resistance = MathMax(resistance, rates[i].high);
     }

   return (support > 0.0 && resistance > support);
  }

bool Strategy_VolatilityAllows(const double atr, const double close_price)
  {
   if(atr <= 0.0 || close_price <= 0.0)
      return false;
   const double ratio = atr / close_price;
   if(ratio < strategy_min_atr_close_pct)
      return false;
   if(ratio > strategy_max_atr_close_pct)
      return false;
   return true;
  }

bool Strategy_TrendUp(const double close1)
  {
   const double ema_fast_1 = QM_EMA(_Symbol, strategy_tf, strategy_fast_ema_period, 1);
   const double ema_fast_3 = QM_EMA(_Symbol, strategy_tf, strategy_fast_ema_period, 3);
   const double ema_slow_1 = QM_EMA(_Symbol, strategy_tf, strategy_slow_ema_period, 1);
   const double adx = QM_ADX(_Symbol, strategy_tf, strategy_adx_period, 1);
   if(ema_fast_1 <= 0.0 || ema_fast_3 <= 0.0 || ema_slow_1 <= 0.0 || adx < strategy_adx_min)
      return false;
   return (ema_fast_1 > ema_slow_1 && ema_fast_1 >= ema_fast_3 && close1 > ema_fast_1);
  }

bool Strategy_TrendDown(const double close1)
  {
   const double ema_fast_1 = QM_EMA(_Symbol, strategy_tf, strategy_fast_ema_period, 1);
   const double ema_fast_3 = QM_EMA(_Symbol, strategy_tf, strategy_fast_ema_period, 3);
   const double ema_slow_1 = QM_EMA(_Symbol, strategy_tf, strategy_slow_ema_period, 1);
   const double adx = QM_ADX(_Symbol, strategy_tf, strategy_adx_period, 1);
   if(ema_fast_1 <= 0.0 || ema_fast_3 <= 0.0 || ema_slow_1 <= 0.0 || adx < strategy_adx_min)
      return false;
   return (ema_fast_1 < ema_slow_1 && ema_fast_1 <= ema_fast_3 && close1 < ema_fast_1);
  }

bool Strategy_ReentryGuardAllows(const datetime signal_time)
  {
   if(g_last_signal_time <= 0)
      return true;
   const int bars_since = iBarShift(_Symbol, strategy_tf, g_last_signal_time, false);
   if(bars_since >= 0 && bars_since < strategy_reentry_guard_bars)
      return false;
   return (signal_time != g_last_signal_time);
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

   ulong existing_ticket = 0;
   if(Strategy_SelectOurPosition(existing_ticket))
      return false;
   if(strategy_sr_lookback_bars < 12 || strategy_volume_lookback_bars < 6)
      return false;

   const int needed = MathMax(strategy_slow_ema_period + 5,
                              strategy_sr_lookback_bars + strategy_volume_lookback_bars + 8);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, strategy_tf, 0, needed, rates); // perf-allowed: caller gates this hook with QM_IsNewBar().
   if(copied < needed)
      return false;

   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   if(!Strategy_BasicMarketOk(atr))
      return false;

   const double close1 = rates[1].close;
   if(!Strategy_VolatilityAllows(atr, close1))
      return false;

   double support = 0.0;
   double resistance = 0.0;
   if(!Strategy_FindSupportResistance(rates, copied, support, resistance))
      return false;

   const double avg_volume = Strategy_AverageVolume(rates, 2, strategy_volume_lookback_bars, copied);
   const double signal_volume = (double)rates[1].tick_volume;
   if(avg_volume <= 0.0 || signal_volume < avg_volume * strategy_volume_spike_mult)
      return false;

   const double touch_band = strategy_sr_touch_atr_mult * atr;
   const double reclaim = strategy_reclaim_atr_mult * atr;
   const datetime signal_time = rates[1].time;
   if(!Strategy_ReentryGuardAllows(signal_time))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(Strategy_TrendUp(close1) &&
      rates[1].low <= support + touch_band &&
      close1 > support + reclaim &&
      close1 > rates[1].open)
     {
      const double structural_sl = support - strategy_sl_buffer_atr_mult * atr;
      const double atr_sl = ask - strategy_sl_atr_mult * atr;
      const double sl = MathMax(structural_sl, atr_sl);
      const double risk = ask - sl;
      if(sl <= 0.0 || risk <= 0.0 || risk > strategy_max_sl_atr_mult * atr)
         return false;

      req.type = QM_BUY;
      req.price = ask;
      req.sl = NormalizeDouble(sl, _Digits);
      req.tp = 0.0;
      req.reason = "QM5_12801_WYCKOFF_ACCUM_SUPPORT";

      g_entry_bar_time = signal_time;
      g_last_signal_time = signal_time;
      g_managed_ticket = 0;
      g_partial_done = false;
      g_initial_risk = risk;
      return true;
     }

   if(Strategy_TrendDown(close1) &&
      rates[1].high >= resistance - touch_band &&
      close1 < resistance - reclaim &&
      close1 < rates[1].open)
     {
      const double structural_sl = resistance + strategy_sl_buffer_atr_mult * atr;
      const double atr_sl = bid + strategy_sl_atr_mult * atr;
      const double sl = MathMin(structural_sl, atr_sl);
      const double risk = sl - bid;
      if(sl <= 0.0 || risk <= 0.0 || risk > strategy_max_sl_atr_mult * atr)
         return false;

      req.type = QM_SELL;
      req.price = bid;
      req.sl = NormalizeDouble(sl, _Digits);
      req.tp = 0.0;
      req.reason = "QM5_12801_WYCKOFF_DISTR_RESIST";

      g_entry_bar_time = signal_time;
      g_last_signal_time = signal_time;
      g_managed_ticket = 0;
      g_partial_done = false;
      g_initial_risk = risk;
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   ulong ticket = 0;
   if(!Strategy_SelectOurPosition(ticket))
      return;

   if(g_managed_ticket != ticket)
     {
      g_managed_ticket = ticket;
      g_partial_done = false;
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double sl = PositionGetDouble(POSITION_SL);
      g_initial_risk = MathAbs(open_price - sl);
     }

   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   if(atr <= 0.0 || g_initial_risk <= 0.0)
      return;

   const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double current_sl = PositionGetDouble(POSITION_SL);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return;

   if(type == POSITION_TYPE_BUY)
     {
      const double open_profit = bid - open_price;
      if(!g_partial_done && open_profit >= strategy_partial_rr * g_initial_risk)
        {
         const double volume = PositionGetDouble(POSITION_VOLUME);
         if(QM_TM_PartialClose(ticket, volume * strategy_partial_fraction, QM_EXIT_PARTIAL))
           {
            g_partial_done = true;
            QM_TM_MoveSL(ticket, open_price, "QM5_12801_TP1_BE_LONG");
           }
        }

      if(open_profit > g_initial_risk)
        {
         const double trail = bid - strategy_trail_atr_mult * atr;
         if(trail > 0.0 && (current_sl <= 0.0 || trail > current_sl))
            QM_TM_MoveSL(ticket, trail, "QM5_12801_ATR_TRAIL_LONG");
        }
     }
   else if(type == POSITION_TYPE_SELL)
     {
      const double open_profit = open_price - ask;
      if(!g_partial_done && open_profit >= strategy_partial_rr * g_initial_risk)
        {
         const double volume = PositionGetDouble(POSITION_VOLUME);
         if(QM_TM_PartialClose(ticket, volume * strategy_partial_fraction, QM_EXIT_PARTIAL))
           {
            g_partial_done = true;
            QM_TM_MoveSL(ticket, open_price, "QM5_12801_TP1_BE_SHORT");
           }
        }

      if(open_profit > g_initial_risk)
        {
         const double trail = ask + strategy_trail_atr_mult * atr;
         if(trail > 0.0 && (current_sl <= 0.0 || trail < current_sl))
            QM_TM_MoveSL(ticket, trail, "QM5_12801_ATR_TRAIL_SHORT");
        }
     }
  }

bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   if(!Strategy_SelectOurPosition(ticket))
      return false;

   const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
   if(open_time > 0 && strategy_time_stop_bars > 0)
     {
      const int bars_since_entry = iBarShift(_Symbol, strategy_tf, open_time, false);
      if(bars_since_entry >= strategy_time_stop_bars)
         return true;
     }

   const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const double close1 = iClose(_Symbol, strategy_tf, 1); // perf-allowed: single closed-bar trend-failure read.
   const double ema_fast = QM_EMA(_Symbol, strategy_tf, strategy_fast_ema_period, 1);
   if(close1 <= 0.0 || ema_fast <= 0.0)
      return false;
   if(type == POSITION_TYPE_BUY && close1 < ema_fast)
      return true;
   if(type == POSITION_TYPE_SELL && close1 > ema_fast)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_12801\",\"card\":\"wyckoff-trend-swing\"}");
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

   if(!QM_IsNewBar(_Symbol, strategy_tf))
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
