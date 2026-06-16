#property strict
#property version   "5.0"
#property description "QM5_11048 CS2011 Fixed MACD Signal"
// rework v2 2026-06-16 — spread filter fail-OPEN on degenerate/zero DWX tester spread (was fail-closed → gated 100% of entries → 0 trades / Q02 MIN_TRADES fail)

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11048;
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
input ENUM_TIMEFRAMES strategy_timeframe             = PERIOD_H1;
input int             strategy_macd_fast             = 12;
input int             strategy_macd_slow             = 26;
input int             strategy_macd_signal           = 9;
input bool            strategy_zero_confirm          = false;
input int             strategy_atr_period            = 14;
input double          strategy_sl_atr_mult           = 1.5;
input double          strategy_tp_sl_ratio           = 1.0;
input int             strategy_max_bars_in_trade     = 24;
input bool            strategy_enable_breakeven      = true;
input double          strategy_breakeven_trigger_r   = 0.75;
input int             strategy_atr_percentile_bars   = 100;
input double          strategy_min_atr_percentile    = 20.0;
input int             strategy_spread_lookback_bars  = 480;
input double          strategy_spread_median_mult    = 2.0;
input bool            strategy_session_filter        = false;
input int             strategy_session_start_hour    = 7;
input int             strategy_session_end_hour      = 21;

bool Strategy_SelectOurPosition(ulong &ticket,
                                ENUM_POSITION_TYPE &ptype,
                                double &open_price,
                                datetime &open_time)
  {
   ticket = 0;
   ptype = POSITION_TYPE_BUY;
   open_price = 0.0;
   open_time = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = t;
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

bool Strategy_BullCross()
  {
   const double main_1 = QM_MACD_Main(_Symbol, strategy_timeframe, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double sig_1 = QM_MACD_Signal(_Symbol, strategy_timeframe, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double main_2 = QM_MACD_Main(_Symbol, strategy_timeframe, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 2);
   const double sig_2 = QM_MACD_Signal(_Symbol, strategy_timeframe, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 2);
   return (main_2 <= sig_2 && main_1 > sig_1);
  }

bool Strategy_BearCross()
  {
   const double main_1 = QM_MACD_Main(_Symbol, strategy_timeframe, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double sig_1 = QM_MACD_Signal(_Symbol, strategy_timeframe, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double main_2 = QM_MACD_Main(_Symbol, strategy_timeframe, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 2);
   const double sig_2 = QM_MACD_Signal(_Symbol, strategy_timeframe, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 2);
   return (main_2 >= sig_2 && main_1 < sig_1);
  }

bool Strategy_AtrPercentileOk()
  {
   const double current_atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   if(current_atr <= 0.0)
      return false;

   const int lookback = MathMax(20, strategy_atr_percentile_bars);
   double values[];
   ArrayResize(values, lookback);
   int count = 0;
   for(int shift = 1; shift <= lookback; ++shift)
     {
      const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, shift);
      if(atr > 0.0)
        {
         values[count] = atr;
         count++;
        }
     }

   if(count < 20)
      return false;

   ArrayResize(values, count);
   ArraySort(values);
   int threshold_index = (int)MathFloor((strategy_min_atr_percentile / 100.0) * (count - 1));
   threshold_index = MathMax(0, MathMin(count - 1, threshold_index));
   return (current_atr >= values[threshold_index]);
  }

double Strategy_MedianSpread()
  {
   const int lookback = MathMax(20, strategy_spread_lookback_bars);
   double values[];
   ArrayResize(values, lookback);
   int count = 0;
   for(int shift = 1; shift <= lookback; ++shift)
     {
      const long spread = iSpread(_Symbol, strategy_timeframe, shift);
      if(spread > 0)
        {
         values[count] = (double)spread;
         count++;
        }
     }

   if(count < 20)
      return 0.0;

   ArrayResize(values, count);
   ArraySort(values);
   const int mid = count / 2;
   if((count % 2) == 1)
      return values[mid];
   return (values[mid - 1] + values[mid]) * 0.5;
  }

bool Strategy_SpreadOk()
  {
   // Fail-OPEN when spread data is degenerate. On DWX custom symbols in the MT5
   // tester both iSpread(history) and SYMBOL_SPREAD frequently report 0, which
   // previously made this filter unsatisfiable and gated 100% of entries (0
   // trades). The filter's intent is to reject ABNORMALLY wide spreads only;
   // absence of spread data must not block trading.
   const double median_spread = Strategy_MedianSpread();
   if(median_spread <= 0.0)
      return true;

   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0)
      return true;

   return ((double)current_spread <= median_spread * strategy_spread_median_mult);
  }

bool Strategy_SessionOk()
  {
   if(!strategy_session_filter)
      return true;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const int start_h = MathMax(0, MathMin(23, strategy_session_start_hour));
   const int end_h = MathMax(0, MathMin(23, strategy_session_end_hour));
   if(start_h == end_h)
      return true;
   if(start_h < end_h)
      return (dt.hour >= start_h && dt.hour < end_h);
   return (dt.hour >= start_h || dt.hour < end_h);
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(_Period != strategy_timeframe)
      return true;
   if(!Strategy_SessionOk())
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
   req.reason = "CS2011_MACD";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_macd_fast <= 0 || strategy_macd_slow <= strategy_macd_fast || strategy_macd_signal <= 0)
      return false;
   if(strategy_atr_period <= 0 || strategy_sl_atr_mult <= 0.0 || strategy_tp_sl_ratio <= 0.0)
      return false;

   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   double open_price;
   datetime open_time;
   if(Strategy_SelectOurPosition(ticket, ptype, open_price, open_time))
      return false;

   if(!Strategy_AtrPercentileOk() || !Strategy_SpreadOk())
      return false;

   const double macd_main_1 = QM_MACD_Main(_Symbol, strategy_timeframe, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   if(Strategy_BullCross() && (!strategy_zero_confirm || macd_main_1 > 0.0))
     {
      req.type = QM_BUY;
      req.price = ask;
      req.sl = QM_StopATR(_Symbol, QM_BUY, ask, strategy_atr_period, strategy_sl_atr_mult);
      req.tp = QM_TakeRR(_Symbol, QM_BUY, ask, req.sl, strategy_tp_sl_ratio);
      req.reason = "CS2011_MACD_LONG";
      return (req.sl > 0.0 && req.sl < ask - point && req.tp > ask + point);
     }

   if(Strategy_BearCross() && (!strategy_zero_confirm || macd_main_1 < 0.0))
     {
      req.type = QM_SELL;
      req.price = bid;
      req.sl = QM_StopATR(_Symbol, QM_SELL, bid, strategy_atr_period, strategy_sl_atr_mult);
      req.tp = QM_TakeRR(_Symbol, QM_SELL, bid, req.sl, strategy_tp_sl_ratio);
      req.reason = "CS2011_MACD_SHORT";
      return (req.sl > bid + point && req.tp > 0.0 && req.tp < bid - point);
     }

   return false;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   if(!strategy_enable_breakeven || strategy_breakeven_trigger_r <= 0.0)
      return;

   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   double open_price;
   datetime open_time;
   if(!Strategy_SelectOurPosition(ticket, ptype, open_price, open_time))
      return;

   const bool is_buy = (ptype == POSITION_TYPE_BUY);
   const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double sl = PositionGetDouble(POSITION_SL);
   if(market <= 0.0 || open_price <= 0.0 || sl <= 0.0)
      return;

   const double initial_risk = MathAbs(open_price - sl);
   const double moved = is_buy ? (market - open_price) : (open_price - market);
   if(initial_risk > 0.0 && moved >= initial_risk * strategy_breakeven_trigger_r)
      QM_TM_MoveSL(ticket, open_price, "cs2011_breakeven_075r");
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   double open_price;
   datetime open_time;
   if(!Strategy_SelectOurPosition(ticket, ptype, open_price, open_time))
      return false;

   if(strategy_max_bars_in_trade > 0)
     {
      const int bar_seconds = PeriodSeconds(strategy_timeframe);
      if(bar_seconds > 0 && TimeCurrent() - open_time >= strategy_max_bars_in_trade * bar_seconds)
         return true;
     }

   if(ptype == POSITION_TYPE_BUY && Strategy_BearCross())
      return true;
   if(ptype == POSITION_TYPE_SELL && Strategy_BullCross())
      return true;

   return false;
  }

// News Filter Hook
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
