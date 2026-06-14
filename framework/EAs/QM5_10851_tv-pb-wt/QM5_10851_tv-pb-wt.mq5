#property strict
#property version   "5.0"
#property description "QM5_10851 TradingView EMA Pullback WaveTrend"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10851;
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
input int    strategy_trend_ema_period      = 200;
input int    strategy_pullback_ema_period   = 50;
input int    strategy_wt_channel_period     = 10;
input int    strategy_wt_average_period     = 21;
input int    strategy_wt_signal_period      = 4;
input int    strategy_atr_period            = 14;
input int    strategy_swing_lookback_bars   = 10;
input double strategy_min_stop_atr_mult     = 1.0;
input double strategy_stop_cap_atr_mult     = 2.0;
input double strategy_target_rr             = 2.0;
input int    strategy_time_exit_bars        = 48;
input int    strategy_wt_warmup_bars        = 260;
input double strategy_max_spread_stop_frac  = 0.15;

bool   g_strategy_state_ready = false;
double g_close_1 = 0.0;
double g_wt1_1 = 0.0;
double g_wt1_2 = 0.0;
double g_wt2_1 = 0.0;
double g_wt2_2 = 0.0;
double g_swing_low = 0.0;
double g_swing_high = 0.0;

int Strategy_MaxInt(const int a, const int b)
  {
   return (a > b) ? a : b;
  }

double Strategy_NormalizePrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   return NormalizeDouble(price, _Digits);
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

bool Strategy_AdvanceStateOnClosedBar()
  {
   g_strategy_state_ready = false;

   if(strategy_trend_ema_period <= 0 ||
      strategy_pullback_ema_period <= 0 ||
      strategy_wt_channel_period <= 0 ||
      strategy_wt_average_period <= 0 ||
      strategy_wt_signal_period <= 0 ||
      strategy_atr_period <= 0 ||
      strategy_swing_lookback_bars <= 0 ||
      strategy_min_stop_atr_mult <= 0.0 ||
      strategy_stop_cap_atr_mult < strategy_min_stop_atr_mult ||
      strategy_target_rr <= 0.0 ||
      strategy_time_exit_bars <= 0 ||
      strategy_max_spread_stop_frac <= 0.0)
      return false;

   int bars_needed = Strategy_MaxInt(strategy_wt_warmup_bars, strategy_trend_ema_period + 20);
   bars_needed = Strategy_MaxInt(bars_needed,
                                 strategy_wt_channel_period + strategy_wt_average_period +
                                 strategy_wt_signal_period + strategy_swing_lookback_bars + 20);

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, _Period, 1, bars_needed, rates); // perf-allowed: closed-bar WaveTrend cache, called only after QM_IsNewBar()
   if(copied < Strategy_MaxInt(strategy_swing_lookback_bars + strategy_wt_signal_period + 2, 40))
      return false;
   ArraySetAsSeries(rates, true);

   double ap[];
   double esa[];
   double dev[];
   double ci[];
   double wt1[];
   ArrayResize(ap, copied);
   ArrayResize(esa, copied);
   ArrayResize(dev, copied);
   ArrayResize(ci, copied);
   ArrayResize(wt1, copied);

   const double alpha_esa = 2.0 / ((double)strategy_wt_channel_period + 1.0);
   const double alpha_tci = 2.0 / ((double)strategy_wt_average_period + 1.0);

   double esa_prev = 0.0;
   for(int i = copied - 1; i >= 0; --i)
     {
      ap[i] = (rates[i].high + rates[i].low + rates[i].close) / 3.0;
      if(i == copied - 1)
         esa[i] = ap[i];
      else
         esa[i] = alpha_esa * ap[i] + (1.0 - alpha_esa) * esa_prev;
      esa_prev = esa[i];
     }

   double dev_prev = 0.0;
   for(int i = copied - 1; i >= 0; --i)
     {
      const double abs_dev = MathAbs(ap[i] - esa[i]);
      if(i == copied - 1)
         dev[i] = abs_dev;
      else
         dev[i] = alpha_esa * abs_dev + (1.0 - alpha_esa) * dev_prev;
      dev_prev = dev[i];
      ci[i] = (dev[i] > 0.0) ? ((ap[i] - esa[i]) / (0.015 * dev[i])) : 0.0;
     }

   double tci_prev = 0.0;
   for(int i = copied - 1; i >= 0; --i)
     {
      if(i == copied - 1)
         wt1[i] = ci[i];
      else
         wt1[i] = alpha_tci * ci[i] + (1.0 - alpha_tci) * tci_prev;
      tci_prev = wt1[i];
     }

   if(copied <= strategy_wt_signal_period + 2)
      return false;

   double wt2_1_sum = 0.0;
   double wt2_2_sum = 0.0;
   for(int i = 0; i < strategy_wt_signal_period; ++i)
     {
      wt2_1_sum += wt1[i];
      wt2_2_sum += wt1[i + 1];
     }

   g_close_1 = rates[0].close;
   g_wt1_1 = wt1[0];
   g_wt1_2 = wt1[1];
   g_wt2_1 = wt2_1_sum / (double)strategy_wt_signal_period;
   g_wt2_2 = wt2_2_sum / (double)strategy_wt_signal_period;

   g_swing_low = DBL_MAX;
   g_swing_high = -DBL_MAX;
   const int swing_bars = MathMin(strategy_swing_lookback_bars, copied);
   for(int i = 0; i < swing_bars; ++i)
     {
      if(rates[i].low < g_swing_low)
         g_swing_low = rates[i].low;
      if(rates[i].high > g_swing_high)
         g_swing_high = rates[i].high;
     }

   if(g_close_1 <= 0.0 || g_swing_low <= 0.0 || g_swing_high <= 0.0)
      return false;

   g_strategy_state_ready = true;
   return true;
  }

bool Strategy_WTCrossUp()
  {
   return g_strategy_state_ready && g_wt1_2 <= g_wt2_2 && g_wt1_1 > g_wt2_1;
  }

bool Strategy_WTCrossDown()
  {
   return g_strategy_state_ready && g_wt1_2 >= g_wt2_2 && g_wt1_1 < g_wt2_1;
  }

bool Strategy_NoTradeFilter()
  {
   // No Trade Filter: no card-level time filter. Framework handles news and
   // Friday close; the card's spread guard is enforced after stop distance is known.
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

   if(!g_strategy_state_ready || Strategy_HasOpenPosition())
      return false;

   const double trend_ema = QM_EMA(_Symbol, _Period, strategy_trend_ema_period, 1, PRICE_CLOSE);
   const double pullback_ema = QM_EMA(_Symbol, _Period, strategy_pullback_ema_period, 1, PRICE_CLOSE);
   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(trend_ema <= 0.0 || pullback_ema <= 0.0 || atr <= 0.0)
      return false;

   QM_OrderType side = QM_BUY;
   bool signal = false;
   if(g_close_1 > trend_ema && g_close_1 < pullback_ema && Strategy_WTCrossUp())
     {
      side = QM_BUY;
      signal = true;
     }
   else if(g_close_1 < trend_ema && g_close_1 > pullback_ema && Strategy_WTCrossDown())
     {
      side = QM_SELL;
      signal = true;
     }

   if(!signal)
      return false;

   const double entry = QM_EntryMarketPrice(side);
   if(entry <= 0.0)
      return false;

   double stop_distance = 0.0;
   if(side == QM_BUY)
     {
      if(g_swing_low <= 0.0 || g_swing_low >= entry)
         stop_distance = strategy_min_stop_atr_mult * atr;
      else
         stop_distance = entry - g_swing_low;
     }
   else
     {
      if(g_swing_high <= 0.0 || g_swing_high <= entry)
         stop_distance = strategy_min_stop_atr_mult * atr;
      else
         stop_distance = g_swing_high - entry;
     }

   const double min_distance = strategy_min_stop_atr_mult * atr;
   const double cap_distance = strategy_stop_cap_atr_mult * atr;
   if(stop_distance < min_distance)
      stop_distance = min_distance;
   if(stop_distance > cap_distance)
      stop_distance = cap_distance;

   const double spread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(spread <= 0.0 || spread > strategy_max_spread_stop_frac * stop_distance)
      return false;

   const double sl = Strategy_NormalizePrice((side == QM_BUY) ? (entry - stop_distance) : (entry + stop_distance));
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_target_rr);
   if(sl <= 0.0 || tp <= 0.0)
      return false;
   if(side == QM_BUY && !(sl < entry && tp > entry))
      return false;
   if(side == QM_SELL && !(sl > entry && tp < entry))
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = (side == QM_BUY) ? "EMA200_PULLBACK_WT_LONG" : "EMA200_PULLBACK_WT_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Trade Management: card baseline has no trailing stop, break-even move,
   // partial close, or pyramiding. Framework SL/TP and Friday close remain active.
  }

bool Strategy_ExitSignal()
  {
   if(!g_strategy_state_ready)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const double trend_ema = QM_EMA(_Symbol, _Period, strategy_trend_ema_period, 1, PRICE_CLOSE);
   if(trend_ema <= 0.0)
      return false;

   const int seconds_per_bar = PeriodSeconds(_Period);
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
      if(ptype == POSITION_TYPE_BUY)
        {
         if(Strategy_WTCrossDown() || g_close_1 < trend_ema)
            return true;
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         if(Strategy_WTCrossUp() || g_close_1 > trend_ema)
            return true;
        }

      if(seconds_per_bar > 0 && strategy_time_exit_bars > 0)
        {
         const datetime opened_at = (datetime)PositionGetInteger(POSITION_TIME);
         if(opened_at > 0 && (TimeCurrent() - opened_at) >= (strategy_time_exit_bars * seconds_per_bar))
            return true;
        }
     }

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // News Filter Hook: no card-specific override; defer to the V5 two-axis news filter.
   if(broker_time <= 0)
      return false;
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

   const bool new_bar = QM_IsNewBar();
   if(new_bar)
      Strategy_AdvanceStateOnClosedBar();

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!new_bar)
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
