#property strict
#property version   "5.0"
#property description "QM5_11317 Carter M5 System #9 EMA50/100 trend + MACD zero-cross"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11317;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_ema_fast_period     = 50;    // EMA(50) trend gate and exit anchor
input int    strategy_ema_slow_period     = 100;   // EMA(100) trend gate
input int    strategy_macd_fast           = 12;    // MACD fast EMA
input int    strategy_macd_slow           = 26;    // MACD slow EMA
input int    strategy_macd_signal         = 9;     // MACD signal SMA
input int    strategy_macd_cross_lookback = 5;     // zero-cross must be within this many closed bars
input int    strategy_distance_pips       = 10;    // minimum close distance beyond EMA(50)
input int    strategy_structure_bars      = 5;     // initial SL: 5-bar low/high
input double strategy_tp_r_multiple       = 2.0;   // V5 baseline full exit at 2R
input int    strategy_exit_break_pips     = 10;    // EMA(50) failure distance
input int    strategy_spread_cap_points   = 20;    // card M5 spread cap baseline

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || strategy_spread_cap_points <= 0)
      return false;
   const double cap = point * strategy_spread_cap_points;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > 0.0 && spread > cap)
      return true;

   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_ema_fast_period <= 0 || strategy_ema_slow_period <= 0 ||
      strategy_macd_fast <= 0 || strategy_macd_slow <= strategy_macd_fast ||
      strategy_macd_signal <= 0 || strategy_macd_cross_lookback <= 0 ||
      strategy_distance_pips <= 0 || strategy_structure_bars <= 0 ||
      strategy_tp_r_multiple <= 0.0)
      return false;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_distance_pips);
   if(distance <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, PERIOD_M5, 1); // perf-allowed: single closed-bar close; no QM close reader exists.
   const double ema_fast = QM_EMA(_Symbol, PERIOD_M5, strategy_ema_fast_period, 1);
   const double ema_slow = QM_EMA(_Symbol, PERIOD_M5, strategy_ema_slow_period, 1);
   if(close1 <= 0.0 || ema_fast <= 0.0 || ema_slow <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const bool long_state = (close1 > ema_fast &&
                            close1 > ema_slow &&
                            close1 >= ema_fast + distance &&
                            close1 > MathMax(ema_fast, ema_slow));
   const bool short_state = (close1 < ema_fast &&
                             close1 < ema_slow &&
                             close1 <= ema_fast - distance &&
                             close1 < MathMin(ema_fast, ema_slow));

   bool macd_cross_up = false;
   bool macd_cross_dn = false;
   const double macd_now = QM_MACD_Main(_Symbol, PERIOD_M5,
                                        strategy_macd_fast,
                                        strategy_macd_slow,
                                        strategy_macd_signal,
                                        1);
   if(long_state && macd_now > 0.0)
     {
      for(int shift = 1; shift <= strategy_macd_cross_lookback; ++shift)
        {
         const double newer = QM_MACD_Main(_Symbol, PERIOD_M5,
                                           strategy_macd_fast,
                                           strategy_macd_slow,
                                           strategy_macd_signal,
                                           shift);
         const double older = QM_MACD_Main(_Symbol, PERIOD_M5,
                                           strategy_macd_fast,
                                           strategy_macd_slow,
                                           strategy_macd_signal,
                                           shift + 1);
         if(newer > 0.0 && older <= 0.0)
           {
            macd_cross_up = true;
            break;
           }
        }
     }

   if(short_state && macd_now < 0.0)
     {
      for(int shift = 1; shift <= strategy_macd_cross_lookback; ++shift)
        {
         const double newer = QM_MACD_Main(_Symbol, PERIOD_M5,
                                           strategy_macd_fast,
                                           strategy_macd_slow,
                                           strategy_macd_signal,
                                           shift);
         const double older = QM_MACD_Main(_Symbol, PERIOD_M5,
                                           strategy_macd_fast,
                                           strategy_macd_slow,
                                           strategy_macd_signal,
                                           shift + 1);
         if(newer < 0.0 && older >= 0.0)
           {
            macd_cross_dn = true;
            break;
           }
        }
     }

   if(long_state && macd_cross_up)
     {
      const double sl = QM_StopStructure(_Symbol, QM_BUY, ask, strategy_structure_bars);
      const double tp = QM_TakeRR(_Symbol, QM_BUY, ask, sl, strategy_tp_r_multiple);
      if(sl <= 0.0 || sl >= ask || tp <= ask)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl;
      req.tp = tp;
      req.reason = "TC_M5_S9_EMA50_100_MACD_LONG";
      return true;
     }

   if(short_state && macd_cross_dn)
     {
      const double sl = QM_StopStructure(_Symbol, QM_SELL, bid, strategy_structure_bars);
      const double tp = QM_TakeRR(_Symbol, QM_SELL, bid, sl, strategy_tp_r_multiple);
      if(sl <= bid || tp <= 0.0 || tp >= bid)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl;
      req.tp = tp;
      req.reason = "TC_M5_S9_EMA50_100_MACD_SHORT";
      return true;
     }

   return false;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card permits the V5 baseline to model the partial-at-2R rule as a full 2R exit.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   const double close1 = iClose(_Symbol, PERIOD_M5, 1); // perf-allowed: single closed-bar close; no QM close reader exists.
   const double ema_fast = QM_EMA(_Symbol, PERIOD_M5, strategy_ema_fast_period, 1);
   const double break_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_exit_break_pips);
   if(close1 <= 0.0 || ema_fast <= 0.0 || break_dist <= 0.0)
      return false;

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

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY)
         return (close1 < ema_fast - break_dist);
      if(type == POSITION_TYPE_SELL)
         return (close1 > ema_fast + break_dist);
     }

   return false;
  }

// News Filter Hook
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------

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
