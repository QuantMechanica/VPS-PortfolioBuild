#property strict
#property version   "5.0"
#property description "QM5_1175 Quantpedia Alt ETF Extrema Reversal Port"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1175;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal        = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance      = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_extrema_lookback_d1 = 10;
input int    strategy_min_valid_d1_bars   = 15;
input int    strategy_atr_period_d1       = 14;
input double strategy_atr_sl_mult         = 1.5;
input int    strategy_hold_bars_d1        = 1;
input int    strategy_max_spread_points   = 0;

#define QM5_1175_SYMBOL_COUNT 6

string g_symbols[QM5_1175_SYMBOL_COUNT] = {
   "NDX.DWX",
   "WS30.DWX",
   "GDAXI.DWX",
   "UK100.DWX",
   "XAUUSD.DWX",
   "XTIUSD.DWX"
};

int g_slots[QM5_1175_SYMBOL_COUNT] = {0, 1, 2, 3, 4, 5};

datetime g_last_entry_bar = 0;
datetime g_last_exit_bar = 0;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < QM5_1175_SYMBOL_COUNT; ++i)
      if(g_symbols[i] == _Symbol)
         return i;
   return -1;
  }

int Strategy_SlotForCurrentSymbol()
  {
   const int index = Strategy_CurrentSymbolIndex();
   if(index < 0)
      return qm_magic_slot_offset;
   return g_slots[index];
  }

datetime Strategy_LastClosedD1Time()
  {
   return iTime(_Symbol, PERIOD_D1, 1);
  }

bool Strategy_TradingStatusValid(const string symbol)
  {
   if(!SymbolSelect(symbol, true))
      return false;
   return (SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE) != SYMBOL_TRADE_MODE_DISABLED);
  }

bool Strategy_HasOpenPosition(ulong &ticket, datetime &opened_at, QM_OrderType &side)
  {
   ticket = 0;
   opened_at = 0;
   side = QM_BUY;

   const int magic = QM_Magic(qm_ea_id, Strategy_SlotForCurrentSymbol());
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
      opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      side = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) ? QM_SELL : QM_BUY;
      return true;
     }

   return false;
  }

bool Strategy_ReadRollingExtrema(const int lookback, double &out_highest, double &out_lowest)
  {
   out_highest = 0.0;
   out_lowest = 0.0;
   if(lookback <= 0)
      return false;
   if(Bars(_Symbol, PERIOD_D1) < MathMax(strategy_min_valid_d1_bars, lookback + 5))
      return false;

   for(int shift = 1; shift <= lookback; ++shift)
     {
      const double close = iClose(_Symbol, PERIOD_D1, shift);
      if(close <= 0.0)
         return false;
      if(shift == 1 || close > out_highest)
         out_highest = close;
      if(shift == 1 || close < out_lowest)
         out_lowest = close;
     }

   return (out_highest > 0.0 && out_lowest > 0.0);
  }

bool Strategy_ExtremaSignal(QM_OrderType &out_side)
  {
   out_side = QM_BUY;
   const int lookback = MathMax(1, strategy_extrema_lookback_d1);
   if(Bars(_Symbol, PERIOD_D1) < MathMax(strategy_min_valid_d1_bars, lookback + 5))
      return false;

   double highest = 0.0;
   double lowest = 0.0;
   if(!Strategy_ReadRollingExtrema(lookback, highest, lowest))
      return false;

   const double close = iClose(_Symbol, PERIOD_D1, 1);
   if(close <= 0.0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tolerance = (point > 0.0) ? (point * 0.5) : 0.0;
   const bool at_high = (MathAbs(close - highest) <= tolerance);
   const bool at_low = (MathAbs(close - lowest) <= tolerance);

   if(at_high && at_low)
      return false;
   if(at_high)
     {
      out_side = QM_SELL;
      return true;
     }
   if(at_low)
     {
      out_side = QM_BUY;
      return true;
     }

   return false;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   if(Strategy_CurrentSymbolIndex() < 0)
      return true;
   if(!Strategy_TradingStatusValid(_Symbol))
      return true;
   if(strategy_max_spread_points > 0 && SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > strategy_max_spread_points)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const datetime signal_bar = Strategy_LastClosedD1Time();
   if(signal_bar <= 0 || g_last_entry_bar == signal_bar)
      return false;

   ulong ticket = 0;
   datetime opened_at = 0;
   QM_OrderType open_side = QM_BUY;
   if(Strategy_HasOpenPosition(ticket, opened_at, open_side))
      return false;

   QM_OrderType side = QM_BUY;
   if(!Strategy_ExtremaSignal(side))
      return false;

   const double entry = QM_OrderTypeIsBuy(side) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                                : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;
   if(QM_OrderTypeIsBuy(side) && sl >= entry)
      return false;
   if(!QM_OrderTypeIsBuy(side) && sl <= entry)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = QM_OrderTypeIsBuy(side) ? "QM5_1175_EXTREMA_REV_LONG"
                                        : "QM5_1175_EXTREMA_REV_SHORT";
   req.symbol_slot = Strategy_SlotForCurrentSymbol();
   req.expiration_seconds = 0;

   g_last_entry_bar = signal_bar;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed one-day holding with the initial ATR stop only.
  }

bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   datetime opened_at = 0;
   QM_OrderType open_side = QM_BUY;
   if(!Strategy_HasOpenPosition(ticket, opened_at, open_side))
      return false;
   if(!Strategy_TradingStatusValid(_Symbol))
      return true;

   const datetime closed_bar = Strategy_LastClosedD1Time();
   if(closed_bar <= 0 || g_last_exit_bar == closed_bar)
      return false;
   if(opened_at >= closed_bar)
      return false;

   const int hold_bars = MathMax(1, strategy_hold_bars_d1);
   int opened_shift = iBarShift(_Symbol, PERIOD_D1, opened_at, false);
   if(opened_shift < 0)
      return false;
   if(opened_shift >= hold_bars)
     {
      g_last_exit_bar = closed_bar;
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

   QM_SymbolGuardInit(g_symbols);
   QM_BasketWarmupHistory(g_symbols, PERIOD_D1, MathMax(strategy_min_valid_d1_bars, strategy_extrema_lookback_d1 + 5));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1175_qp-alt-etf-extrema-rev\"}");
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
      const int magic = QM_Magic(qm_ea_id, Strategy_SlotForCurrentSymbol());
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
