#property strict
#property version   "5.0"
#property description "QM5_10847 TradingView Inside Gem breakout score"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10847;
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
input int             strategy_min_score             = 5;
input int             strategy_min_inside_bars       = 2;
input bool            strategy_allow_one_inside_sweep = true;
input int             strategy_max_inside_bars       = 8;
input int             strategy_atr_period            = 14;
input double          strategy_atr_buffer_mult       = 0.25;
input double          strategy_rr_target             = 2.0;
input int             strategy_rsi_period            = 14;
input double          strategy_bo_quality_threshold  = 0.70;
input int             strategy_session_start_hour    = 9;
input int             strategy_session_end_hour      = 23;
input ENUM_TIMEFRAMES strategy_patron_tf             = PERIOD_H4;
input ENUM_TIMEFRAMES strategy_manager_tf            = PERIOD_H1;

int DirectionFromBar(const MqlRates &bar)
  {
   if(bar.close > bar.open)
      return 1;
   if(bar.close < bar.open)
      return -1;
   return 0;
  }

int ClosedBarDirection(const string symbol, const ENUM_TIMEFRAMES tf)
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(symbol, tf, 1, 1, rates); // perf-allowed: one closed HTF bar for MTF conflict check.
   if(copied != 1)
      return 0;
   return DirectionFromBar(rates[0]);
  }

bool Strategy_NoTradeFilter()
  {
   MqlDateTime now;
   TimeToStruct(TimeCurrent(), now);

   if(strategy_session_start_hour == strategy_session_end_hour)
      return false;

   if(strategy_session_start_hour < strategy_session_end_hour)
      return (now.hour < strategy_session_start_hour || now.hour >= strategy_session_end_hour);

   return (now.hour >= strategy_session_end_hour && now.hour < strategy_session_start_hour);
  }

bool BuildEntryFromPattern(const MqlRates &breakout_bar,
                           const MqlRates &mother_bar,
                           const MqlRates &inside_rates[],
                           const int inside_count,
                           QM_EntryRequest &req)
  {
   const double mother_range = mother_bar.high - mother_bar.low;
   if(mother_range <= 0.0)
      return false;

   int direction = 0;
   if(breakout_bar.close > mother_bar.high)
      direction = 1;
   else if(breakout_bar.close < mother_bar.low)
      direction = -1;
   else
      return false;

   const int patron_dir = ClosedBarDirection(_Symbol, strategy_patron_tf);
   const int manager_dir = ClosedBarDirection(_Symbol, strategy_manager_tf);
   if((patron_dir != 0 && patron_dir != direction) ||
      (manager_dir != 0 && manager_dir != direction))
      return false;

   const double midpoint = (mother_bar.high + mother_bar.low) * 0.5;
   int directional_closes = 0;
   bool midpoint_sweep = false;
   for(int i = 0; i < inside_count; ++i)
     {
      if(direction > 0 && inside_rates[i].close > inside_rates[i].open)
         directional_closes++;
      if(direction < 0 && inside_rates[i].close < inside_rates[i].open)
         directional_closes++;
      if(inside_rates[i].high >= midpoint && inside_rates[i].low <= midpoint)
         midpoint_sweep = true;
     }

   if(inside_count < strategy_min_inside_bars &&
      !(strategy_allow_one_inside_sweep && inside_count == 1 && midpoint_sweep))
      return false;

   int score = inside_count;
   if(directional_closes * 2 >= inside_count)
      score++;
   if(midpoint_sweep)
      score++;
   if(patron_dir == direction)
      score++;
   if(manager_dir == direction)
      score++;

   const double rsi_1 = QM_RSI(_Symbol, PERIOD_CURRENT, strategy_rsi_period, 1);
   const double rsi_2 = QM_RSI(_Symbol, PERIOD_CURRENT, strategy_rsi_period, 2);
   if(direction > 0 && rsi_1 >= 50.0)
      score++;
   if(direction < 0 && rsi_1 <= 50.0)
      score++;
   if(direction > 0 && rsi_2 > 0.0 && rsi_1 < rsi_2)
      score--;
   if(direction < 0 && rsi_2 > 0.0 && rsi_1 > rsi_2)
      score--;

   const double breakout_range = breakout_bar.high - breakout_bar.low;
   if(breakout_range > 0.0)
     {
      const double bo_q = (direction > 0)
                          ? ((breakout_bar.close - breakout_bar.low) / breakout_range)
                          : ((breakout_bar.high - breakout_bar.close) / breakout_range);
      if(bo_q >= strategy_bo_quality_threshold)
         score = (int)MathCeil((double)score * 1.20);
     }

   if(score < strategy_min_score)
      return false;

   const QM_OrderType side = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry = (direction > 0)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, 1);
   if(entry <= 0.0 || atr <= 0.0)
      return false;

   const double buffer = atr * strategy_atr_buffer_mult;
   double sl = (direction > 0) ? (mother_bar.low - buffer) : (mother_bar.high + buffer);
   sl = QM_StopRulesNormalizePrice(_Symbol, sl);
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_rr_target);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(point > 0.0 && stops_level > 0)
     {
      const double min_dist = stops_level * point;
      if(MathAbs(entry - sl) < min_dist || MathAbs(entry - tp) < min_dist)
         return false;
     }

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = (direction > 0) ? "inside_gem_long" : "inside_gem_short";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
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

   if(strategy_min_score <= 0 ||
      strategy_min_inside_bars <= 0 ||
      strategy_max_inside_bars <= 0 ||
      strategy_atr_period <= 0 ||
      strategy_atr_buffer_mult <= 0.0 ||
      strategy_rr_target <= 0.0 ||
      strategy_rsi_period <= 1)
      return false;

   const int max_inside = MathMin(strategy_max_inside_bars, 12);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_CURRENT, 1, max_inside + 2, rates); // perf-allowed: bounded closed-bar structural scan behind framework QM_IsNewBar gate.
   if(copied < 3)
      return false;

   const MqlRates breakout_bar = rates[0];
   for(int inside_count = MathMin(max_inside, copied - 2); inside_count >= 1; --inside_count)
     {
      const int mother_index = inside_count + 1;
      const MqlRates mother_bar = rates[mother_index];
      if(mother_bar.high <= mother_bar.low)
         continue;

      MqlRates inside_rates[];
      ArrayResize(inside_rates, inside_count);
      bool all_inside = true;
      for(int i = 0; i < inside_count; ++i)
        {
         inside_rates[i] = rates[i + 1];
         if(inside_rates[i].high > mother_bar.high || inside_rates[i].low < mother_bar.low)
           {
            all_inside = false;
            break;
           }
        }
      if(!all_inside)
         continue;

      if(BuildEntryFromPattern(breakout_bar, mother_bar, inside_rates, inside_count, req))
         return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card baseline has no trailing, partial close, or break-even management.
  }

bool Strategy_ExitSignal()
  {
   // Card baseline exits through fixed 2R take profit, structural SL, and framework Friday close.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10847_tv-inside-gem\"}");
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
