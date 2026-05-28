#property strict
#property version   "5.0"
#property description "QM5_1217 Zarattini Donchian ensemble trend"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1217;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 0.66;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_signal_tf  = PERIOD_D1;
input int    strategy_lookback_fast       = 20;
input int    strategy_lookback_mid        = 55;
input int    strategy_lookback_slow       = 100;
input double strategy_entry_threshold     = 0.34;
input int    strategy_atr_period_d1       = 20;
input double strategy_atr_sl_mult         = 2.50;
input int    strategy_min_bars            = 120;
input int    strategy_reentry_wait_bars   = 5;
input int    strategy_max_spread_points   = 300;

#define STRATEGY_SYMBOL_COUNT 6

const string STRATEGY_SYMBOLS[6] =
  {
   "EURUSD.DWX",
   "GBPUSD.DWX",
   "USDJPY.DWX",
   "XAUUSD.DWX",
   "GER40.DWX",
   "NDX.DWX"
  };

datetime g_last_entry_bar = 0;
datetime g_last_exit_bar = 0;
datetime g_last_flat_seen_bar = 0;
int      g_reentry_block_remaining = 0;
bool     g_had_position = false;

int Strategy_MaxLookback()
  {
   return MathMax(strategy_lookback_fast,
                  MathMax(strategy_lookback_mid, strategy_lookback_slow));
  }

int Strategy_SymbolSlot()
  {
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
     {
      if(_Symbol == STRATEGY_SYMBOLS[i])
         return i;
     }
   return -1;
  }

bool Strategy_SpreadOk()
  {
   if(strategy_max_spread_points <= 0)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   return ((ask - bid) / point <= (double)strategy_max_spread_points);
  }

bool Strategy_HasOpenPosition(ulong &ticket, ENUM_POSITION_TYPE &type)
  {
   ticket = 0;
   type = POSITION_TYPE_BUY;

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

      ticket = pos_ticket;
      type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }

   return false;
  }

bool Strategy_PriorChannel(const int shift, const int lookback, double &upper, double &lower)
  {
   upper = -DBL_MAX;
   lower = DBL_MAX;

   const int period = MathMax(1, lookback);
   for(int i = shift + 1; i <= shift + period; ++i)
     {
      const double high_i = iHigh(_Symbol, strategy_signal_tf, i);
      const double low_i = iLow(_Symbol, strategy_signal_tf, i);
      if(high_i <= 0.0 || low_i <= 0.0 || high_i < low_i)
         return false;
      if(high_i > upper)
         upper = high_i;
      if(low_i < lower)
         lower = low_i;
     }

   return (upper > 0.0 && lower > 0.0 && upper > lower);
  }

bool Strategy_ApplyVoteAtShift(const int shift, const int lookback, int &score)
  {
   double upper = 0.0;
   double lower = 0.0;
   if(!Strategy_PriorChannel(shift, lookback, upper, lower))
      return false;

   const double close_i = iClose(_Symbol, strategy_signal_tf, shift);
   if(close_i <= 0.0)
      return false;

   if(close_i > upper)
      score = 1;
   else if(close_i < lower)
      score = -1;

   return true;
  }

bool Strategy_AggregateScore(double &aggregate)
  {
   aggregate = 0.0;

   const int available = Bars(_Symbol, strategy_signal_tf);
   const int max_lookback = Strategy_MaxLookback();
   if(available < MathMax(strategy_min_bars, max_lookback + 3))
      return false;

   int fast = 0;
   int mid = 0;
   int slow = 0;
   const int oldest_shift = MathMin(available - max_lookback - 2,
                                    MathMax(strategy_min_bars, max_lookback + 40));
   if(oldest_shift < 1)
      return false;

   for(int shift = oldest_shift; shift >= 1; --shift)
     {
      if(!Strategy_ApplyVoteAtShift(shift, strategy_lookback_fast, fast))
         return false;
      if(!Strategy_ApplyVoteAtShift(shift, strategy_lookback_mid, mid))
         return false;
      if(!Strategy_ApplyVoteAtShift(shift, strategy_lookback_slow, slow))
         return false;
     }

   aggregate = ((double)fast + (double)mid + (double)slow) / 3.0;
   return true;
  }

void Strategy_UpdateReentryBlock()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE type = POSITION_TYPE_BUY;
   const bool has_position = Strategy_HasOpenPosition(ticket, type);
   if(has_position)
     {
      g_had_position = true;
      return;
     }

   const datetime bar_time = iTime(_Symbol, strategy_signal_tf, 1);
   if(bar_time <= 0 || bar_time == g_last_flat_seen_bar)
      return;

   g_last_flat_seen_bar = bar_time;
   if(g_had_position)
     {
      g_had_position = false;
      g_reentry_block_remaining = MathMax(0, strategy_reentry_wait_bars);
      return;
     }

   if(g_reentry_block_remaining > 0)
      --g_reentry_block_remaining;
  }

double Strategy_AtrStop(const QM_OrderType side, const double entry)
  {
   const double atr = QM_ATR(_Symbol, strategy_signal_tf, MathMax(1, strategy_atr_period_d1), 1);
   if(entry <= 0.0 || atr <= 0.0 || strategy_atr_sl_mult <= 0.0)
      return 0.0;

   const double distance = atr * strategy_atr_sl_mult;
   const double stop = QM_OrderTypeIsBuy(side) ? (entry - distance) : (entry + distance);
   return NormalizeDouble(stop, _Digits);
  }

bool Strategy_StopOk(const QM_OrderType side, const double entry, const double sl)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || entry <= 0.0 || sl <= 0.0)
      return false;
   if(side == QM_BUY && sl >= entry)
      return false;
   if(side == QM_SELL && sl <= entry)
      return false;

   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double stop_points = MathAbs(entry - sl) / point;
   return (stops_level <= 0 || stop_points > (double)stops_level);
  }

bool Strategy_NoTradeFilter()
  {
   const int slot = Strategy_SymbolSlot();
   if(slot < 0)
      return true;
   if(qm_magic_slot_offset != slot)
      return true;
   if(_Period != strategy_signal_tf)
      return true;
   if(strategy_lookback_fast <= 1 || strategy_lookback_mid <= 1 || strategy_lookback_slow <= 1)
      return true;
   if(strategy_entry_threshold <= 0.0 || strategy_entry_threshold > 1.0)
      return true;
   if(strategy_atr_period_d1 <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;

   Strategy_UpdateReentryBlock();
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

   const datetime bar_time = iTime(_Symbol, strategy_signal_tf, 1);
   if(bar_time <= 0 || bar_time == g_last_entry_bar)
      return false;

   ulong ticket = 0;
   ENUM_POSITION_TYPE pos_type = POSITION_TYPE_BUY;
   if(Strategy_HasOpenPosition(ticket, pos_type))
      return false;
   if(g_reentry_block_remaining > 0 || !Strategy_SpreadOk())
      return false;

   double aggregate = 0.0;
   if(!Strategy_AggregateScore(aggregate))
      return false;

   QM_OrderType side = QM_BUY;
   if(aggregate >= strategy_entry_threshold)
      side = QM_BUY;
   else if(aggregate <= -strategy_entry_threshold)
      side = QM_SELL;
   else
      return false;

   const double entry = QM_EntryMarketPrice(side);
   const double sl = Strategy_AtrStop(side, entry);
   if(!Strategy_StopOk(side, entry, sl))
      return false;

   req.type = side;
   req.price = entry;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = "zarattini_donchian_ensemble";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   g_last_entry_bar = bar_time;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   const datetime bar_time = iTime(_Symbol, strategy_signal_tf, 1);
   if(bar_time <= 0 || bar_time == g_last_exit_bar)
      return false;

   ulong ticket = 0;
   ENUM_POSITION_TYPE type = POSITION_TYPE_BUY;
   if(!Strategy_HasOpenPosition(ticket, type))
      return false;

   double aggregate = 0.0;
   if(!Strategy_AggregateScore(aggregate))
      return false;

   if((type == POSITION_TYPE_BUY && aggregate <= 0.0) ||
      (type == POSITION_TYPE_SELL && aggregate >= 0.0))
     {
      g_last_exit_bar = bar_time;
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

   string symbols[6];
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
      symbols[i] = STRATEGY_SYMBOLS[i];
   QM_SymbolGuardInit(symbols);
   QM_BasketWarmupHistory(symbols, PERIOD_D1, MathMax(strategy_min_bars, Strategy_MaxLookback() + 80));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1217_zarattini-donchian-ensemble\"}");
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
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!QM_IsNewBar(_Symbol, strategy_signal_tf))
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
