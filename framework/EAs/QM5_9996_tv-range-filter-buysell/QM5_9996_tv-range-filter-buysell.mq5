#property strict
#property version   "5.0"
#property description "QM5_9996 TradingView Range Filter Buy/Sell"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 9996;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_range_period        = 100;
input double strategy_range_multiplier    = 3.0;
input double strategy_sl_smoothed_mult    = 1.0;
input bool   strategy_use_atr_sl          = false;
input int    strategy_atr_period          = 14;
input double strategy_sl_atr_mult         = 1.5;
input double strategy_tp_atr_mult         = 0.0;
input int    strategy_max_hold_bars       = 0;
input double strategy_spread_sl_fraction  = 0.25;
input bool   strategy_ma_gate_enabled     = false;
input int    strategy_ma_period           = 200;

bool GetOurPosition(ENUM_POSITION_TYPE &ptype, ulong &ticket)
  {
   ptype = POSITION_TYPE_BUY;
   ticket = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong pos_ticket = PositionGetTicket(i);
      if(pos_ticket == 0 || !PositionSelectByTicket(pos_ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      ticket = pos_ticket;
      return true;
     }

   return false;
  }

bool ComputeRangeFilterSignal(int &signal, double &smoothed_range)
  {
   signal = 0;
   smoothed_range = 0.0;

   if(strategy_range_period < 2 || strategy_range_multiplier <= 0.0)
      return false;

   const int second_period = strategy_range_period * 2 - 1;
   int lookback = second_period * 4 + 10;
   const int min_lookback = strategy_range_period * 6 + 10;
   if(lookback < min_lookback)
      lookback = min_lookback;
   if(lookback < 40)
      lookback = 40;

   // perf-allowed: bespoke recursive range-filter state; EntrySignal is called only after QM_IsNewBar().
   double closes[];
   const int copied = CopyClose(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, lookback, closes);
   if(copied < second_period + 5)
      return false;

   const double alpha_fast = 2.0 / (strategy_range_period + 1.0);
   const double alpha_slow = 2.0 / (second_period + 1.0);

   double avrng = 0.0;
   double smooth_base = 0.0;
   double filter = closes[0];
   int fdir = 0;

   double prev_close = closes[0];
   double prev_filter = filter;
   int prev_fdir = fdir;
   double close_last = closes[0];
   double filter_last = filter;

   for(int i = 1; i < copied; ++i)
     {
      const double change = MathAbs(closes[i] - closes[i - 1]);
      if(i == 1)
        {
         avrng = change;
         smooth_base = change;
        }
      else
        {
         avrng = alpha_fast * change + (1.0 - alpha_fast) * avrng;
         smooth_base = alpha_slow * avrng + (1.0 - alpha_slow) * smooth_base;
        }

      const double rng = smooth_base * strategy_range_multiplier;
      prev_close = closes[i - 1];
      prev_filter = filter;
      prev_fdir = fdir;

      if(closes[i] > prev_filter)
        {
         const double raised = closes[i] - rng;
         filter = (raised < prev_filter) ? prev_filter : raised;
        }
      else
        {
         const double lowered = closes[i] + rng;
         filter = (lowered > prev_filter) ? prev_filter : lowered;
        }

      if(filter > prev_filter)
         fdir = 1;
      else if(filter < prev_filter)
         fdir = -1;

      close_last = closes[i];
      filter_last = filter;
      smoothed_range = rng;
     }

   if(smoothed_range <= 0.0 || filter_last <= 0.0 || prev_filter <= 0.0)
      return false;

   if(close_last > filter_last && fdir == 1 && (prev_close <= prev_filter || prev_fdir <= 0))
      signal = 1;
   else if(close_last < filter_last && fdir == -1 && (prev_close >= prev_filter || prev_fdir >= 0))
      signal = -1;

   if(signal != 0 && strategy_ma_gate_enabled)
     {
      const double ema = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ma_period, 1, PRICE_CLOSE);
      if(ema <= 0.0)
         return false;
      if(signal > 0 && close_last <= ema)
         signal = 0;
      if(signal < 0 && close_last >= ema)
         signal = 0;
     }

   return true;
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

   int signal = 0;
   double smoothed_range = 0.0;
   if(!ComputeRangeFilterSignal(signal, smoothed_range) || signal == 0)
      return false;

   ENUM_POSITION_TYPE ptype;
   ulong ticket = 0;
   const bool has_position = GetOurPosition(ptype, ticket);
   if(has_position)
     {
      if((signal > 0 && ptype == POSITION_TYPE_BUY) || (signal < 0 && ptype == POSITION_TYPE_SELL))
         return false;
      if(!QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL))
         return false;
     }

   req.type = (signal > 0) ? QM_BUY : QM_SELL;
   const double entry = (signal > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                     : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   double stop_distance = smoothed_range * strategy_sl_smoothed_mult;
   double atr_value = 0.0;
   if(strategy_use_atr_sl || strategy_tp_atr_mult > 0.0)
     {
      atr_value = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
      if(atr_value <= 0.0)
         return false;
     }
   if(strategy_use_atr_sl)
      stop_distance = atr_value * strategy_sl_atr_mult;
   if(stop_distance <= 0.0)
      return false;

   req.sl = QM_StopRulesNormalizePrice(_Symbol, (signal > 0) ? entry - stop_distance : entry + stop_distance);
   if(req.sl <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double spread = ask - bid;
   if(ask > 0.0 && bid > 0.0 && ask > bid && spread > strategy_spread_sl_fraction * MathAbs(entry - req.sl))
      return false;

   if(strategy_tp_atr_mult > 0.0)
      req.tp = QM_TakeATRFromValue(_Symbol, req.type, entry, atr_value, strategy_tp_atr_mult);

   req.reason = (signal > 0) ? "RANGE_FILTER_LONG_FLIP" : "RANGE_FILTER_SHORT_FLIP";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   if(strategy_max_hold_bars <= 0)
      return;

   const int period_seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(period_seconds <= 0)
      return;

   const int max_hold_seconds = strategy_max_hold_bars * period_seconds;
   const datetime now = TimeCurrent();

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
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
      if(opened > 0 && now - opened >= max_hold_seconds)
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_9996_tv_range_filter_buysell\"}");
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
