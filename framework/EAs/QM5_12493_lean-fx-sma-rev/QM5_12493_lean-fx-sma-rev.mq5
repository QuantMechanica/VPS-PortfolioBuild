#property strict
#property version   "5.0"
#property description "QM5_12493 lean-fx-sma-rev - Lean FX SMA intraday reversal"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA - QM5_12493 lean-fx-sma-rev
// -----------------------------------------------------------------------------
// Card: D:\QM\strategy_farm\artifacts\cards_approved\QM5_12493_lean-fx-sma-rev.md
// Source: QuantConnect Lean IntradayReversalCurrencyMarketsAlpha.py.
//
// Mechanics:
//   - EURUSD.DWX H1.
//   - Entry window is New York time 10:00 through before 15:00.
//   - Price crossing below SMA(5) enters long.
//   - Price crossing above SMA(5) enters short.
//   - The same signal direction is not re-entered until the opposite signal
//     appears.
//   - Exit at 15:01 New York time, or on the opposite SMA signal.
//   - Initial stop is ATR(14) * 2.0. No fixed take-profit.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12493;
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
input int    strategy_sma_period        = 5;
input int    strategy_session_start_ny_hour = 10;
input int    strategy_session_start_ny_min  = 0;
input int    strategy_session_end_ny_hour   = 15;
input int    strategy_session_end_ny_min    = 1;
input int    strategy_atr_period        = 14;
input double strategy_atr_stop_mult     = 2.0;
input double strategy_spread_pct_of_stop = 15.0;

int g_last_signal_direction = 0; // +1 long, -1 short, 0 none yet.

datetime QM12493_BrokerToNewYork(const datetime broker_time)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   const int ny_offset_hours = QM_IsUSDSTUTC(utc) ? -4 : -5;
   return utc + ny_offset_hours * 3600;
  }

int QM12493_MinutesOfDay(const datetime t)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

bool QM12493_IsInsideEntrySession(const datetime broker_time)
  {
   const int now_min = QM12493_MinutesOfDay(QM12493_BrokerToNewYork(broker_time));
   const int start_min = strategy_session_start_ny_hour * 60 + strategy_session_start_ny_min;
   const int end_min = strategy_session_end_ny_hour * 60;

   if(start_min == end_min)
      return false;
   if(start_min < end_min)
      return (now_min >= start_min && now_min < end_min);
   return (now_min >= start_min || now_min < end_min);
  }

bool QM12493_IsTimeExit(const datetime broker_time)
  {
   const int now_min = QM12493_MinutesOfDay(QM12493_BrokerToNewYork(broker_time));
   const int exit_min = strategy_session_end_ny_hour * 60 + strategy_session_end_ny_min;
   return (now_min >= exit_min);
  }

int QM12493_SmaCrossSignal()
  {
   const int period = MathMax(2, strategy_sma_period);
   const double close_1 = QM_SMA(_Symbol, _Period, 1, 1, PRICE_CLOSE);
   const double close_2 = QM_SMA(_Symbol, _Period, 1, 2, PRICE_CLOSE);
   const double sma_1 = QM_SMA(_Symbol, _Period, period, 1, PRICE_CLOSE);
   const double sma_2 = QM_SMA(_Symbol, _Period, period, 2, PRICE_CLOSE);

   if(close_1 <= 0.0 || close_2 <= 0.0 || sma_1 <= 0.0 || sma_2 <= 0.0)
      return 0;

   if(close_2 >= sma_2 && close_1 < sma_1)
      return +1;
   if(close_2 <= sma_2 && close_1 > sma_1)
      return -1;
   return 0;
  }

bool QM12493_SpreadTooWide()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   const double stop_distance = atr * strategy_atr_stop_mult;
   if(stop_distance <= 0.0)
      return false;

   return (spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance);
  }

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;
   if(!QM12493_IsInsideEntrySession(TimeCurrent()))
      return false;
   if(QM12493_SpreadTooWide())
      return false;

   const int signal = QM12493_SmaCrossSignal();
   if(signal == 0)
      return false;
   if(signal == g_last_signal_direction)
      return false;

   const QM_OrderType side = (signal > 0) ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_stop_mult);
   if(sl <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = (side == QM_BUY) ? "lean_fx_sma_rev_long" : "lean_fx_sma_rev_short";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   g_last_signal_direction = signal;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   if(QM12493_IsTimeExit(TimeCurrent()))
      return true;

   const int signal = QM12493_SmaCrossSignal();
   if(signal == 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const long position_type = PositionGetInteger(POSITION_TYPE);
      if(position_type == POSITION_TYPE_BUY && signal < 0)
         return true;
      if(position_type == POSITION_TYPE_SELL && signal > 0)
         return true;
     }

   return false;
  }

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
