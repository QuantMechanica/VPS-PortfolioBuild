#property strict
#property version   "5.0"
#property description "QM5_1505 Connors Cumulative RSI H4"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1505;
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
input int    strategy_rsi_period            = 2;
input int    strategy_cum_rsi_bars          = 3;
input double strategy_cum_rsi_long_max      = 30.0;
input double strategy_cum_rsi_short_min     = 270.0;
input int    strategy_trend_sma_period      = 200;
input int    strategy_exit_sma_period       = 5;
input int    strategy_d1_sma_period         = 50;
input int    strategy_d1_slope_bars         = 5;
input int    strategy_atr_period            = 14;
input int    strategy_atr_baseline_bars     = 200;
input double strategy_atr_floor_mult        = 0.60;
input double strategy_atr_sl_mult           = 2.0;
input double strategy_atr_tp_mult           = 1.5;
input double strategy_tp1_close_fraction    = 0.60;
input int    strategy_cooldown_bars         = 16;
input int    strategy_time_stop_bars        = 20;

datetime g_last_entry_time = 0;
ulong    g_tp1_ticket = 0;

bool ReadClosedBar(const string symbol, const ENUM_TIMEFRAMES tf, const int shift, MqlRates &bar)
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(symbol, tf, shift, 1, rates); // perf-allowed: one closed bar inside strategy hooks.
   if(copied != 1)
      return false;
   bar = rates[0];
   return true;
  }

double CumRSI(const string symbol, const ENUM_TIMEFRAMES tf, const int period, const int bars, const int start_shift)
  {
   if(period <= 0 || bars <= 0 || start_shift < 1)
      return -1.0;

   double total = 0.0;
   for(int i = 0; i < bars; ++i)
     {
      const double value = QM_RSI(symbol, tf, period, start_shift + i);
      if(value < 0.0)
         return -1.0;
      total += value;
     }
   return total;
  }

double AverageATR(const string symbol, const ENUM_TIMEFRAMES tf, const int period, const int bars, const int start_shift)
  {
   if(period <= 0 || bars <= 0 || start_shift < 1)
      return 0.0;

   double total = 0.0;
   int samples = 0;
   for(int shift = start_shift; shift < start_shift + bars; ++shift)
     {
      const double value = QM_ATR(symbol, tf, period, shift);
      if(value <= 0.0)
         continue;
      total += value;
      samples++;
     }

   if(samples < MathMin(20, bars))
      return 0.0;
   return total / samples;
  }

bool CooldownAllowsEntry()
  {
   if(strategy_cooldown_bars <= 0 || g_last_entry_time <= 0)
      return true;
   const int shift = iBarShift(_Symbol, PERIOD_H4, g_last_entry_time, false);
   if(shift < 0)
      return true;
   return (shift >= strategy_cooldown_bars);
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

   if((ENUM_TIMEFRAMES)_Period != PERIOD_H4)
      return false;
   if(strategy_rsi_period <= 0 ||
      strategy_cum_rsi_bars <= 0 ||
      strategy_trend_sma_period <= 0 ||
      strategy_exit_sma_period <= 0 ||
      strategy_d1_sma_period <= 0 ||
      strategy_atr_period <= 0 ||
      strategy_atr_baseline_bars <= 0 ||
      strategy_atr_floor_mult <= 0.0 ||
      strategy_atr_sl_mult <= 0.0 ||
      strategy_atr_tp_mult <= 0.0 ||
      strategy_tp1_close_fraction <= 0.0 ||
      strategy_tp1_close_fraction >= 1.0)
      return false;
   if(!CooldownAllowsEntry())
      return false;

   MqlRates h4_bar;
   if(!ReadClosedBar(_Symbol, PERIOD_H4, 1, h4_bar))
      return false;

   const double cum_rsi = CumRSI(_Symbol, PERIOD_H4, strategy_rsi_period, strategy_cum_rsi_bars, 1);
   const double h4_sma = QM_SMA(_Symbol, PERIOD_H4, strategy_trend_sma_period, 1);
   const double d1_sma_now = QM_SMA(_Symbol, PERIOD_D1, strategy_d1_sma_period, 1);
   const double d1_sma_prev = QM_SMA(_Symbol, PERIOD_D1, strategy_d1_sma_period, 1 + strategy_d1_slope_bars);
   MqlRates d1_bar;
   if(cum_rsi < 0.0 || h4_sma <= 0.0 || d1_sma_now <= 0.0 || d1_sma_prev <= 0.0)
      return false;
   if(!ReadClosedBar(_Symbol, PERIOD_D1, 1, d1_bar))
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double avg_atr = AverageATR(_Symbol, PERIOD_H4, strategy_atr_period, strategy_atr_baseline_bars, 1);
   if(atr <= 0.0 || avg_atr <= 0.0 || atr <= avg_atr * strategy_atr_floor_mult)
      return false;

   QM_OrderType side = QM_BUY;
   bool has_signal = false;
   if(cum_rsi < strategy_cum_rsi_long_max &&
      h4_bar.close > h4_sma &&
      d1_bar.close > d1_sma_now &&
      d1_sma_now > d1_sma_prev)
     {
      side = QM_BUY;
      has_signal = true;
     }
   else if(cum_rsi > strategy_cum_rsi_short_min &&
           h4_bar.close < h4_sma &&
           d1_bar.close < d1_sma_now &&
           d1_sma_now < d1_sma_prev)
     {
      side = QM_SELL;
      has_signal = true;
     }

   if(!has_signal)
      return false;

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = (side == QM_BUY) ? "CONNORS_CUM_RSI_PULLBACK_LONG"
                                 : "CONNORS_CUM_RSI_PULLBACK_SHORT";
   g_last_entry_time = h4_bar.time;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   bool active_tracked_ticket = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      if(ticket == g_tp1_ticket)
        {
         active_tracked_ticket = true;
         continue;
        }

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      const double sl = PositionGetDouble(POSITION_SL);
      const double lots = PositionGetDouble(POSITION_VOLUME);
      if(entry <= 0.0 || sl <= 0.0 || lots <= 0.0 || strategy_atr_sl_mult <= 0.0)
         continue;

      const double atr_from_sl = MathAbs(entry - sl) / strategy_atr_sl_mult;
      if(atr_from_sl <= 0.0)
         continue;

      const double target = (ptype == POSITION_TYPE_BUY)
                            ? entry + atr_from_sl * strategy_atr_tp_mult
                            : entry - atr_from_sl * strategy_atr_tp_mult;
      const double price = (ptype == POSITION_TYPE_BUY)
                           ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                           : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(price <= 0.0)
         continue;

      const bool hit = (ptype == POSITION_TYPE_BUY) ? (price >= target) : (price <= target);
      if(!hit)
         continue;

      if(QM_Exit(ticket, QM_EXIT_TP_HIT, lots * strategy_tp1_close_fraction))
        {
         g_tp1_ticket = ticket;
         active_tracked_ticket = true;
        }
     }

   if(!active_tracked_ticket)
      g_tp1_ticket = 0;
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   MqlRates h4_bar;
   if(!ReadClosedBar(_Symbol, PERIOD_H4, 1, h4_bar))
      return false;
   const double exit_sma = QM_SMA(_Symbol, PERIOD_H4, strategy_exit_sma_period, 1);
   if(exit_sma <= 0.0)
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

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && h4_bar.close > exit_sma)
         return true;
      if(ptype == POSITION_TYPE_SELL && h4_bar.close < exit_sma)
         return true;

      if(strategy_time_stop_bars > 0)
        {
         const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
         const int open_shift = iBarShift(_Symbol, PERIOD_H4, opened, false);
         if(open_shift >= strategy_time_stop_bars)
            return true;
        }
     }

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
