#property strict
#property version   "5.0"
#property description "QM5_1206 Lento SP500 Combined Signal MA"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 1206;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_fast_a_period       = 1;
input int    strategy_slow_a_period       = 200;
input int    strategy_fast_b_period       = 5;
input int    strategy_slow_b_period       = 150;
input int    strategy_min_history_d1_bars = 220;
input int    strategy_atr_period_d1       = 20;
input double strategy_stop_atr_mult       = 3.0;
input int    strategy_disagree_hold_bars  = 1;
input int    strategy_max_spread_points   = 0;

const string STRATEGY_SYMBOL = "SP500.DWX";

datetime g_last_entry_bar = 0;
datetime g_last_exit_bar = 0;
datetime g_disagree_since = 0;

datetime Strategy_LastClosedD1Time()
  {
   return iTime(_Symbol, PERIOD_D1, 1);
  }

bool Strategy_IsAllowedSymbol()
  {
   return (_Symbol == STRATEGY_SYMBOL && _Period == PERIOD_D1 && qm_magic_slot_offset == 0);
  }

bool Strategy_HasOpenPosition(ulong &ticket, double &current_sl, datetime &opened_at)
  {
   ticket = 0;
   current_sl = 0.0;
   opened_at = 0;

   const int magic = QM_Magic(qm_ea_id, qm_magic_slot_offset);
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
      if(PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
         continue;

      ticket = pos_ticket;
      current_sl = PositionGetDouble(POSITION_SL);
      opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

int Strategy_ConsensusState()
  {
   const int max_period = MathMax(MathMax(strategy_fast_a_period, strategy_slow_a_period),
                                  MathMax(strategy_fast_b_period, strategy_slow_b_period));
   if(Bars(_Symbol, PERIOD_D1) < MathMax(strategy_min_history_d1_bars, max_period + strategy_atr_period_d1 + 5))
      return 0;

   const double a_fast = QM_SMA(_Symbol, PERIOD_D1, MathMax(1, strategy_fast_a_period), 1, PRICE_CLOSE);
   const double a_slow = QM_SMA(_Symbol, PERIOD_D1, MathMax(2, strategy_slow_a_period), 1, PRICE_CLOSE);
   const double b_fast = QM_SMA(_Symbol, PERIOD_D1, MathMax(1, strategy_fast_b_period), 1, PRICE_CLOSE);
   const double b_slow = QM_SMA(_Symbol, PERIOD_D1, MathMax(2, strategy_slow_b_period), 1, PRICE_CLOSE);
   if(a_fast <= 0.0 || a_slow <= 0.0 || b_fast <= 0.0 || b_slow <= 0.0)
      return 0;

   const bool signal_a_bull = (a_fast > a_slow);
   const bool signal_b_bull = (b_fast > b_slow);
   if(signal_a_bull && signal_b_bull)
      return 1;
   if(!signal_a_bull && !signal_b_bull)
      return -1;
   return 0;
  }

bool Strategy_StopDistanceAllowed(const double entry, const double sl)
  {
   if(entry <= 0.0 || sl <= 0.0 || sl >= entry)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double stop_points = MathAbs(entry - sl) / point;
   return (stops_level <= 0 || stop_points > (double)stops_level);
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsAllowedSymbol())
      return true;
   if(!SymbolSelect(_Symbol, true))
      return true;
   if(SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE) == SYMBOL_TRADE_MODE_DISABLED)
      return true;
   if(strategy_fast_a_period <= 0 || strategy_slow_a_period <= 0 || strategy_fast_b_period <= 0 || strategy_slow_b_period <= 0)
      return true;
   if(strategy_atr_period_d1 <= 0 || strategy_stop_atr_mult <= 0.0 || strategy_disagree_hold_bars < 0)
      return true;
   if(strategy_max_spread_points > 0 && SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > strategy_max_spread_points)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "LENTO_SP500_CSA_MA_LONG";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const datetime signal_bar = Strategy_LastClosedD1Time();
   if(signal_bar <= 0 || g_last_entry_bar == signal_bar)
      return false;

   ulong ticket = 0;
   double current_sl = 0.0;
   datetime opened_at = 0;
   if(Strategy_HasOpenPosition(ticket, current_sl, opened_at))
      return false;

   if(Strategy_ConsensusState() != 1)
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(entry <= 0.0 || atr <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr, strategy_stop_atr_mult);
   if(!Strategy_StopDistanceAllowed(entry, sl))
      return false;

   req.price = entry;
   req.sl = sl;
   g_last_entry_bar = signal_bar;
   g_disagree_since = 0;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   ulong ticket = 0;
   double current_sl = 0.0;
   datetime opened_at = 0;
   if(!Strategy_HasOpenPosition(ticket, current_sl, opened_at))
      return;

   const double close = iClose(_Symbol, PERIOD_D1, 1);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(close <= 0.0 || atr <= 0.0)
      return;

   const double trail = QM_TM_NormalizePrice(_Symbol, close - atr * strategy_stop_atr_mult);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(trail <= 0.0 || point <= 0.0)
      return;
   if(current_sl <= 0.0 || trail > current_sl + point * 0.5)
      QM_TM_MoveSL(ticket, trail, "LENTO_SP500_ATR_TRAIL");
  }

bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   double current_sl = 0.0;
   datetime opened_at = 0;
   if(!Strategy_HasOpenPosition(ticket, current_sl, opened_at))
      return false;

   const datetime signal_bar = Strategy_LastClosedD1Time();
   if(signal_bar <= 0 || g_last_exit_bar == signal_bar)
      return false;

   const int state = Strategy_ConsensusState();
   if(state == -1)
     {
      g_disagree_since = 0;
      g_last_exit_bar = signal_bar;
      return true;
     }
   if(state == 1)
     {
      g_disagree_since = 0;
      return false;
     }

   if(g_disagree_since <= 0)
     {
      g_disagree_since = signal_bar;
      return false;
     }

   const int first_shift = iBarShift(_Symbol, PERIOD_D1, g_disagree_since, false);
   const int current_shift = iBarShift(_Symbol, PERIOD_D1, signal_bar, false);
   if(first_shift >= 0 && current_shift >= 0 && first_shift - current_shift >= MathMax(1, strategy_disagree_hold_bars))
     {
      g_disagree_since = 0;
      g_last_exit_bar = signal_bar;
      return true;
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

   string symbols[1] = {STRATEGY_SYMBOL};
   QM_SymbolGuardInit(symbols);
   QM_BasketWarmupHistory(symbols, PERIOD_D1, strategy_min_history_d1_bars);

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1206_lento-sp500-csa-ma\"}");
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
      const int magic = QM_Magic(qm_ea_id, qm_magic_slot_offset);
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
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
