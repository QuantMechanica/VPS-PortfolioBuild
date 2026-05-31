#property strict
#property version   "5.0"
#property description "QM5_10753 TradingView Three Musketeers confirmation"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10753;
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
input ENUM_TIMEFRAMES strategy_signal_tf        = PERIOD_M15;
input int             strategy_fast_ema_period  = 50;
input int             strategy_slow_ema_period  = 200;
input int             strategy_rsi_period       = 14;
input double          strategy_rsi_lower        = 30.0;
input double          strategy_rsi_upper        = 70.0;
input int             strategy_bb_period        = 20;
input double          strategy_bb_deviation     = 2.0;
input int             strategy_atr_period       = 14;
input double          strategy_atr_sl_mult      = 1.5;
input double          strategy_take_profit_rr   = 2.0;
input int             strategy_max_hold_bars    = 48;

bool StrategyParamsValid()
  {
   if(strategy_signal_tf != PERIOD_M15)
      return false;
   if(strategy_fast_ema_period <= 0 || strategy_slow_ema_period <= strategy_fast_ema_period)
      return false;
   if(strategy_rsi_period <= 0 || strategy_bb_period <= 0 || strategy_atr_period <= 0)
      return false;
   if(strategy_rsi_lower <= 0.0 || strategy_rsi_upper <= strategy_rsi_lower)
      return false;
   if(strategy_bb_deviation <= 0.0 || strategy_atr_sl_mult <= 0.0)
      return false;
   if(strategy_take_profit_rr <= 0.0 || strategy_max_hold_bars <= 0)
      return false;
   return true;
  }

bool HasOurOpenPosition()
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

double StrategyClose(const int shift)
  {
   return iClose(_Symbol, strategy_signal_tf, shift); // perf-allowed: O(1) closed-bar close; no QM close reader exists.
  }

int StrategyTwoOfThreeSignal()
  {
   if(!StrategyParamsValid())
      return 0;

   const double ema_fast = QM_EMA(_Symbol, strategy_signal_tf, strategy_fast_ema_period, 1);
   const double ema_slow = QM_EMA(_Symbol, strategy_signal_tf, strategy_slow_ema_period, 1);
   const double rsi_1 = QM_RSI(_Symbol, strategy_signal_tf, strategy_rsi_period, 1);
   const double rsi_2 = QM_RSI(_Symbol, strategy_signal_tf, strategy_rsi_period, 2);
   const double close_1 = StrategyClose(1);
   const double close_2 = StrategyClose(2);
   const double bb_lower_1 = QM_BB_Lower(_Symbol, strategy_signal_tf, strategy_bb_period, strategy_bb_deviation, 1);
   const double bb_lower_2 = QM_BB_Lower(_Symbol, strategy_signal_tf, strategy_bb_period, strategy_bb_deviation, 2);
   const double bb_upper_1 = QM_BB_Upper(_Symbol, strategy_signal_tf, strategy_bb_period, strategy_bb_deviation, 1);
   const double bb_upper_2 = QM_BB_Upper(_Symbol, strategy_signal_tf, strategy_bb_period, strategy_bb_deviation, 2);

   if(ema_fast <= 0.0 || ema_slow <= 0.0 || rsi_1 <= 0.0 || rsi_2 <= 0.0 ||
      close_1 <= 0.0 || close_2 <= 0.0 || bb_lower_1 <= 0.0 || bb_lower_2 <= 0.0 ||
      bb_upper_1 <= 0.0 || bb_upper_2 <= 0.0)
      return 0;

   int bull_score = 0;
   int bear_score = 0;

   if(ema_fast > ema_slow)
      ++bull_score;
   if(ema_fast < ema_slow)
      ++bear_score;

   if(rsi_2 < strategy_rsi_lower && rsi_1 >= strategy_rsi_lower)
      ++bull_score;
   if(rsi_2 > strategy_rsi_upper && rsi_1 <= strategy_rsi_upper)
      ++bear_score;

   if(close_2 <= bb_lower_2 && close_1 > bb_lower_1)
      ++bull_score;
   if(close_2 >= bb_upper_2 && close_1 < bb_upper_1)
      ++bear_score;

   const bool long_signal = (bull_score >= 2);
   const bool short_signal = (bear_score >= 2);
   if(long_signal && !short_signal)
      return 1;
   if(short_signal && !long_signal)
      return -1;
   return 0;
  }

bool PositionExceededTimeStop()
  {
   const int seconds_per_bar = PeriodSeconds(strategy_signal_tf);
   if(seconds_per_bar <= 0)
      return false;

   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   const int max_seconds = strategy_max_hold_bars * seconds_per_bar;
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
      if(opened > 0 && (now - opened) >= max_seconds)
         return true;
     }
   return false;
  }

bool PositionOpposedBySignal(const int signal)
  {
   if(signal == 0)
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
      if(type == POSITION_TYPE_BUY && signal < 0)
         return true;
      if(type == POSITION_TYPE_SELL && signal > 0)
         return true;
     }
   return false;
  }

// No Trade Filter: framework handles news, Friday close, and kill-switch.
// This hook keeps execution on the card's M15 timeframe.
bool Strategy_NoTradeFilter()
  {
   return (_Period != PERIOD_M15 || strategy_signal_tf != PERIOD_M15);
  }

// Trade Entry: closed-bar two-of-three confirmation from EMA trend, RSI
// threshold cross, and Bollinger Band reaction.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_NoTradeFilter() || HasOurOpenPosition())
      return false;

   const int signal = StrategyTwoOfThreeSignal();
   if(signal == 0)
      return false;

   req.type = (signal > 0) ? QM_BUY : QM_SELL;
   req.reason = (signal > 0) ? "TV_THREE_MUSK_LONG" : "TV_THREE_MUSK_SHORT";

   const double entry = QM_EntryMarketPrice(req.type);
   if(entry <= 0.0)
      return false;

   req.price = entry;
   req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_sl_mult);
   req.tp = QM_TakeRR(_Symbol, req.type, entry, req.sl, strategy_take_profit_rr);
   return (req.sl > 0.0 && req.tp > 0.0);
  }

// Trade Management: the card specifies no break-even, trailing, pyramiding, or
// partial-close management beyond the hard SL/TP bracket.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close: close on opposite two-of-three signal or after the 48-bar M15
// time stop if neither SL nor 2R TP has fired.
bool Strategy_ExitSignal()
  {
   if(!HasOurOpenPosition())
      return false;
   if(PositionExceededTimeStop())
      return true;
   return PositionOpposedBySignal(StrategyTwoOfThreeSignal());
  }

// News Filter Hook: no card-specific override; P8 uses the central framework
// news filter through the normal framework wiring.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10753\",\"ea\":\"tv-three-musk\"}");
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
