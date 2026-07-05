#property strict
#property version   "5.0"
#property description "QM5_9507 Carver D1 Donchian breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 9507;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
// Card mechanic holds through weekends by design (Donchian(40) trail exit /
// 4xATR stop span multi-week trends). A default weekly force-flat truncates
// every trade to <=1 week and starves entry re-triggers (see
// docs/ops/evidence/05a836a7_qm5_12847_turn_of_month_fidelity_2026-07-02.md
// for the identical defect class fixed on QM5_12847).
input bool   qm_friday_close_enabled     = false;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_breakout_lookback_d1 = 80;
input int    strategy_exit_lookback_d1     = 40;
input int    strategy_atr_period           = 25;
input double strategy_atr_sl_mult          = 4.0;
input int    strategy_atr_median_bars      = 252;
input double strategy_min_atr_median_mult  = 0.40;
input int    strategy_spread_days          = 60;
input double strategy_spread_mult          = 2.0;
input double strategy_trail_after_r        = 1.5;

int g_last_entry_bar_key = 0;

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

int Strategy_OpenPositionDirection()
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
      const long pos_type = PositionGetInteger(POSITION_TYPE);
      return (pos_type == POSITION_TYPE_BUY) ? 1 : -1;
     }
   return 0;
  }

bool Strategy_HistoryReady()
  {
   const int need_bars = MathMax(strategy_breakout_lookback_d1 + strategy_atr_period + 5,
                                 strategy_atr_median_bars + strategy_atr_period + 5);
   return Bars(_Symbol, PERIOD_D1) >= need_bars; // perf-allowed: one D1 history-depth check on the entry path
  }

double Strategy_ChannelHigh(const int lookback, const int start_shift)
  {
   if(lookback <= 0 || start_shift < 1)
      return 0.0;
   // perf-allowed: Donchian channel needs a bounded high lookup over D1 closed
   // bars. This runs through MT5's native iHighest, not a per-tick CopyRates loop.
   const int idx = iHighest(_Symbol, PERIOD_D1, MODE_HIGH, lookback, start_shift);
   if(idx < 0)
      return 0.0;
   return iHigh(_Symbol, PERIOD_D1, idx); // perf-allowed: bounded Donchian high selected by iHighest
  }

double Strategy_ChannelLow(const int lookback, const int start_shift)
  {
   if(lookback <= 0 || start_shift < 1)
      return 0.0;
   // perf-allowed: Donchian channel needs a bounded low lookup over D1 closed
   // bars. This runs through MT5's native iLowest, not a per-tick CopyRates loop.
   const int idx = iLowest(_Symbol, PERIOD_D1, MODE_LOW, lookback, start_shift);
   if(idx < 0)
      return 0.0;
   return iLow(_Symbol, PERIOD_D1, idx); // perf-allowed: bounded Donchian low selected by iLowest
  }

double Strategy_MedianATR()
  {
   if(strategy_atr_median_bars <= 0 || strategy_atr_median_bars > 512)
      return 0.0;

   double values[512];
   int count = 0;
   for(int shift = 1; shift <= strategy_atr_median_bars; ++shift)
     {
      const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, shift);
      if(atr <= 0.0)
         continue;
      values[count] = atr;
      ++count;
     }

   if(count <= 0)
      return 0.0;

   for(int i = 0; i < count - 1; ++i)
      for(int j = i + 1; j < count; ++j)
         if(values[j] < values[i])
           {
            const double tmp = values[i];
            values[i] = values[j];
            values[j] = tmp;
           }

   if((count % 2) == 1)
      return values[count / 2];
   return 0.5 * (values[(count / 2) - 1] + values[count / 2]);
  }

bool Strategy_VolatilityAllowsEntry()
  {
   if(strategy_min_atr_median_mult <= 0.0)
      return true;
   const double current_atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double median_atr = Strategy_MedianATR();
   if(current_atr <= 0.0 || median_atr <= 0.0)
      return false;
   return current_atr >= (median_atr * strategy_min_atr_median_mult);
  }

double Strategy_MedianDailySpreadPoints()
  {
   if(strategy_spread_days <= 0 || strategy_spread_days > 128)
      return 0.0;

   double values[128];
   int count = 0;
   for(int shift = 1; shift <= strategy_spread_days; ++shift)
     {
      const long spread = iSpread(_Symbol, PERIOD_D1, shift);
      if(spread > 0)
        {
         values[count] = (double)spread;
         ++count;
        }
     }

   if(count <= 0)
      return 0.0;

   for(int i = 0; i < count - 1; ++i)
      for(int j = i + 1; j < count; ++j)
         if(values[j] < values[i])
           {
            const double tmp = values[i];
            values[i] = values[j];
            values[j] = tmp;
           }

   if((count % 2) == 1)
      return values[count / 2];
   return 0.5 * (values[(count / 2) - 1] + values[count / 2]);
  }

bool Strategy_SpreadAllowsEntry()
  {
   if(strategy_spread_mult <= 0.0)
      return true;
   const double median_spread = Strategy_MedianDailySpreadPoints();
   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(!(median_spread > 0.0) || !(current_spread > 0))
      return true;
   return ((double)current_spread <= median_spread * strategy_spread_mult);
  }

int Strategy_BreakoutDirection()
  {
   const double close_1 = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: one closed D1 close read for Donchian breakout
   const double prior_high = Strategy_ChannelHigh(strategy_breakout_lookback_d1, 2);
   const double prior_low = Strategy_ChannelLow(strategy_breakout_lookback_d1, 2);
   if(close_1 <= 0.0 || prior_high <= 0.0 || prior_low <= 0.0)
      return 0;
   if(close_1 > prior_high)
      return 1;
   if(close_1 < prior_low)
      return -1;
   return 0;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   if(qm_magic_slot_offset < 0 || qm_magic_slot_offset > 32)
      return true;
   if(strategy_breakout_lookback_d1 <= 1 || strategy_exit_lookback_d1 <= 1)
      return true;
   if(strategy_atr_period <= 1 || strategy_atr_sl_mult <= 0.0)
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

   const int signal_bar_key = QM_CalendarPeriodKey(PERIOD_D1, _Symbol, 1);
   if(signal_bar_key <= 0 || signal_bar_key == g_last_entry_bar_key)
      return false;
   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_HistoryReady())
      return false;
   if(!Strategy_VolatilityAllowsEntry())
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   const int direction = Strategy_BreakoutDirection();
   if(direction == 0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   req.price = (direction > 0) ? ask : bid;
   req.sl = QM_StopATR(_Symbol, req.type, req.price, strategy_atr_period, strategy_atr_sl_mult);
   req.tp = 0.0;
   req.reason = (direction > 0) ? "CARVER_DONCHIAN80_LONG" : "CARVER_DONCHIAN80_SHORT";
   if(req.sl <= 0.0)
      return false;
   if(req.type == QM_BUY && req.sl >= req.price)
      return false;
   if(req.type == QM_SELL && req.sl <= req.price)
      return false;

   g_last_entry_bar_key = signal_bar_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   if(strategy_trail_after_r <= 0.0)
      return;

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

      const long pos_type = PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || current_sl <= 0.0)
         continue;

      if(pos_type == POSITION_TYPE_BUY)
        {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         const double risk = open_price - current_sl;
         if(bid <= 0.0 || risk <= 0.0 || (bid - open_price) < risk * strategy_trail_after_r)
            continue;
         const double trail_sl = QM_StopRulesNormalizePrice(_Symbol, Strategy_ChannelLow(strategy_exit_lookback_d1, 1));
         if(trail_sl > current_sl && trail_sl < bid)
            QM_TM_MoveSL(ticket, trail_sl, "CARVER_DONCHIAN40_TRAIL");
        }
      else
        {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         const double risk = current_sl - open_price;
         if(ask <= 0.0 || risk <= 0.0 || (open_price - ask) < risk * strategy_trail_after_r)
            continue;
         const double trail_sl = QM_StopRulesNormalizePrice(_Symbol, Strategy_ChannelHigh(strategy_exit_lookback_d1, 1));
         if(trail_sl > ask && (current_sl <= 0.0 || trail_sl < current_sl))
            QM_TM_MoveSL(ticket, trail_sl, "CARVER_DONCHIAN40_TRAIL");
        }
     }
  }

bool Strategy_ExitSignal()
  {
   const int current_direction = Strategy_OpenPositionDirection();
   if(current_direction == 0)
      return false;

   const double close_1 = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: one closed D1 close read for Donchian exit
   if(close_1 <= 0.0)
      return false;

   if(current_direction > 0)
     {
      const double exit_low = Strategy_ChannelLow(strategy_exit_lookback_d1, 2);
      return (exit_low > 0.0 && close_1 < exit_low);
     }

   const double exit_high = Strategy_ChannelHigh(strategy_exit_lookback_d1, 2);
   return (exit_high > 0.0 && close_1 > exit_high);
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_9507\",\"ea\":\"carver-breakout\"}");
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

   if(Strategy_NewsFilterHook(broker_now))
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

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
