#property strict
#property version   "5.0"
#property description "QM5_1227 Neely-Weller-Ulrich FX channel breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1227;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 0.75;

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
input int    strategy_channel_lookback    = 60;
input int    strategy_exit_sma_period     = 60;
input int    strategy_atr_period_d1       = 20;
input double strategy_atr_sl_mult         = 2.50;
input int    strategy_max_hold_bars       = 90;
input int    strategy_min_bars            = 120;
input int    strategy_max_active_symbols  = 3;
input int    strategy_max_spread_points   = 30;

#define STRATEGY_SYMBOL_COUNT 4

const string STRATEGY_SYMBOLS[4] =
  {
   "EURUSD.DWX",
   "GBPUSD.DWX",
   "USDJPY.DWX",
   "USDCHF.DWX"
  };

datetime g_last_entry_bar = 0;
datetime g_last_exit_bar = 0;

int Strategy_MaxLookback()
  {
   return MathMax(strategy_min_bars,
                  MathMax(strategy_channel_lookback,
                          MathMax(strategy_exit_sma_period, strategy_atr_period_d1)) + 3);
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

bool Strategy_HasOpenPosition(ulong &ticket, ENUM_POSITION_TYPE &type, datetime &opened_at)
  {
   ticket = 0;
   type = POSITION_TYPE_BUY;
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

      ticket = pos_ticket;
      type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

int Strategy_BasketPositionCount()
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong pos_ticket = PositionGetTicket(i);
      if(pos_ticket == 0 || !PositionSelectByTicket(pos_ticket))
         continue;

      const int pos_magic = (int)PositionGetInteger(POSITION_MAGIC);
      for(int slot = 0; slot < STRATEGY_SYMBOL_COUNT; ++slot)
        {
         if(pos_magic == QM_Magic(qm_ea_id, slot))
           {
            ++count;
            break;
           }
        }
     }

   return count;
  }

bool Strategy_PriorChannel(const int shift, double &upper, double &lower)
  {
   upper = -DBL_MAX;
   lower = DBL_MAX;

   const int lookback = MathMax(1, strategy_channel_lookback);
   for(int i = shift + 1; i <= shift + lookback; ++i)
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
   if(Bars(_Symbol, strategy_signal_tf) < Strategy_MaxLookback())
      return true;
   if(strategy_channel_lookback <= 1 || strategy_exit_sma_period <= 1)
      return true;
   if(strategy_atr_period_d1 <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_max_active_symbols <= 0 || strategy_max_active_symbols > STRATEGY_SYMBOL_COUNT)
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

   const datetime bar_time = iTime(_Symbol, strategy_signal_tf, 1);
   if(bar_time <= 0 || bar_time == g_last_entry_bar)
      return false;

   ulong ticket = 0;
   ENUM_POSITION_TYPE pos_type = POSITION_TYPE_BUY;
   datetime opened_at = 0;
   if(Strategy_HasOpenPosition(ticket, pos_type, opened_at))
      return false;
   if(Strategy_BasketPositionCount() >= strategy_max_active_symbols)
      return false;
   if(!Strategy_SpreadOk())
      return false;

   double upper = 0.0;
   double lower = 0.0;
   if(!Strategy_PriorChannel(1, upper, lower))
      return false;

   const double close_1 = iClose(_Symbol, strategy_signal_tf, 1);
   if(close_1 <= 0.0)
      return false;

   QM_OrderType side = QM_BUY;
   if(close_1 > upper)
      side = QM_BUY;
   else if(close_1 < lower)
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
   req.reason = "neely_fx_channel";
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
   datetime opened_at = 0;
   if(!Strategy_HasOpenPosition(ticket, type, opened_at))
      return false;

   const double close_1 = iClose(_Symbol, strategy_signal_tf, 1);
   const double mid = QM_SMA(_Symbol, strategy_signal_tf, MathMax(1, strategy_exit_sma_period), 1);
   if(close_1 <= 0.0 || mid <= 0.0)
      return false;

   if((type == POSITION_TYPE_BUY && close_1 < mid) ||
      (type == POSITION_TYPE_SELL && close_1 > mid))
     {
      g_last_exit_bar = bar_time;
      return true;
     }

   if(strategy_max_hold_bars > 0 && opened_at > 0)
     {
      const int open_shift = iBarShift(_Symbol, strategy_signal_tf, opened_at, false);
      if(open_shift >= strategy_max_hold_bars)
        {
         g_last_exit_bar = bar_time;
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

   string symbols[4];
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
      symbols[i] = STRATEGY_SYMBOLS[i];
   QM_SymbolGuardInit(symbols);
   QM_BasketWarmupHistory(symbols, PERIOD_D1, Strategy_MaxLookback() + 10);

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1227_neely-fx-channel\"}");
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
