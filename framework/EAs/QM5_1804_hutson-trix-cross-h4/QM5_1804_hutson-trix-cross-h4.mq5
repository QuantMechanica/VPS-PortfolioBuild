#property strict
#property version   "5.0"
#property description "QM5_1804 Hutson TRIX Cross H4"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1804;
input int    qm_magic_slot_offset        = 0;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsMode qm_news_mode           = QM_NEWS_PAUSE;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_trix_period        = 14;
input int    strategy_signal_period      = 9;
input int    strategy_regime_ema_period  = 100;
input int    strategy_atr_period         = 20;
input double strategy_atr_mult           = 2.5;
input double strategy_trail_trigger_atr  = 1.5;
input double strategy_spread_atr_frac    = 0.35;
input int    strategy_time_stop_bars     = 35;

datetime g_trix_state_bar = 0;
bool     g_trix_state_ok = false;
double   g_trix_curr = 0.0;
double   g_trix_prev = 0.0;
double   g_signal_curr = 0.0;
double   g_signal_prev = 0.0;
double   g_h4_close_curr = 0.0;
double   g_d1_regime_ema = 0.0;
double   g_h4_atr = 0.0;

bool HasOurPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

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

bool ReadTrixValues(const int trix_period,
                    const int signal_period,
                    double &trix_curr,
                    double &trix_prev,
                    double &signal_curr,
                    double &signal_prev)
  {
   if(trix_period < 2 || signal_period < 2)
      return false;

   const int warmup = MathMax(3 * trix_period, 42);
   const int bars_needed = warmup + signal_period + 5;
   if(Bars(_Symbol, PERIOD_H4) < bars_needed + 2)
      return false;

   double ema1[];
   double ema2[];
   double ema3[];
   double trix[];
   ArrayResize(ema1, bars_needed);
   ArrayResize(ema2, bars_needed);
   ArrayResize(ema3, bars_needed);
   ArrayResize(trix, bars_needed);

   const double alpha = 2.0 / (trix_period + 1.0);
   for(int i = 0; i < bars_needed; ++i)
     {
      const int shift = bars_needed - i;
      const double close_i = iClose(_Symbol, PERIOD_H4, shift);
      if(close_i <= 0.0)
         return false;

      if(i == 0)
        {
         ema1[i] = close_i;
         ema2[i] = close_i;
         ema3[i] = close_i;
         trix[i] = 0.0;
         continue;
        }

      ema1[i] = ema1[i - 1] + alpha * (close_i - ema1[i - 1]);
      ema2[i] = ema2[i - 1] + alpha * (ema1[i] - ema2[i - 1]);
      ema3[i] = ema3[i - 1] + alpha * (ema2[i] - ema3[i - 1]);
      if(ema3[i - 1] == 0.0)
         return false;
      trix[i] = ((ema3[i] - ema3[i - 1]) / ema3[i - 1]) * 10000.0;
     }

   const int curr = bars_needed - 1;
   const int prev = bars_needed - 2;
   if(prev - signal_period + 1 < warmup)
      return false;

   double sum_curr = 0.0;
   double sum_prev = 0.0;
   for(int j = 0; j < signal_period; ++j)
     {
      sum_curr += trix[curr - j];
      sum_prev += trix[prev - j];
     }

   trix_curr = trix[curr];
   trix_prev = trix[prev];
   signal_curr = sum_curr / signal_period;
   signal_prev = sum_prev / signal_period;
   return true;
  }

bool RefreshTrixState()
  {
   const datetime h4_bar = iTime(_Symbol, PERIOD_H4, 0);
   if(h4_bar <= 0)
      return false;
   if(g_trix_state_ok && h4_bar == g_trix_state_bar)
      return true;

   g_trix_state_bar = h4_bar;
   g_trix_state_ok = false;
   g_h4_close_curr = iClose(_Symbol, PERIOD_H4, 1);
   g_d1_regime_ema = QM_EMA(_Symbol, PERIOD_D1, strategy_regime_ema_period, 1);
   g_h4_atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(g_h4_close_curr <= 0.0 || g_d1_regime_ema <= 0.0 || g_h4_atr <= 0.0)
      return false;

   if(!ReadTrixValues(strategy_trix_period,
                      strategy_signal_period,
                      g_trix_curr,
                      g_trix_prev,
                      g_signal_curr,
                      g_signal_prev))
      return false;

   g_trix_state_ok = true;
   return true;
  }

bool TrixCrossUp()
  {
   return (g_trix_prev < g_signal_prev && g_trix_curr > g_signal_curr);
  }

bool TrixCrossDown()
  {
   return (g_trix_prev > g_signal_prev && g_trix_curr < g_signal_curr);
  }

bool SpreadAllowsEntry()
  {
   if(!RefreshTrixState())
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid)
      return false;

   return ((ask - bid) <= strategy_spread_atr_frac * g_h4_atr);
  }

bool Strategy_NoTradeFilter()
  {
   // Time: no card-specific session exclusion. Spread is enforced at entry.
   // News: framework calls QM_NewsAllowsTrade before this hook.
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

   if(HasOurPosition())
      return false;
   if(!RefreshTrixState())
      return false;
   if(!SpreadAllowsEntry())
      return false;

   const bool long_signal = TrixCrossUp() &&
                            g_trix_curr > 0.0 &&
                            g_h4_close_curr > g_d1_regime_ema;
   const bool short_signal = TrixCrossDown() &&
                             g_trix_curr < 0.0 &&
                             g_h4_close_curr < g_d1_regime_ema;

   if(!long_signal && !short_signal)
      return false;

   req.type = long_signal ? QM_BUY : QM_SELL;
   req.price = 0.0;
   const double entry = long_signal ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                    : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_mult);
   if(req.sl <= 0.0)
      return false;

   req.tp = 0.0;
   req.reason = long_signal ? "HUTSON_TRIX_CROSS_UP_H4" : "HUTSON_TRIX_CROSS_DOWN_H4";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   if(!RefreshTrixState())
      return;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double market = (ptype == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                                         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(open_price <= 0.0 || market <= 0.0)
         continue;

      const double favorable = (ptype == POSITION_TYPE_BUY) ? (market - open_price)
                                                            : (open_price - market);
      if(favorable >= strategy_trail_trigger_atr * g_h4_atr)
         QM_TM_TrailATR(ticket, strategy_atr_period, strategy_atr_mult);
     }
  }

bool Strategy_ExitSignal()
  {
   if(!RefreshTrixState())
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const int hold_seconds = strategy_time_stop_bars * PeriodSeconds(PERIOD_H4);
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(hold_seconds > 0 && opened > 0 && TimeCurrent() - opened >= hold_seconds)
         return true;

      if(ptype == POSITION_TYPE_BUY)
        {
         if(TrixCrossDown() || (g_trix_prev >= 0.0 && g_trix_curr < 0.0))
            return true;
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         if(TrixCrossUp() || (g_trix_prev <= 0.0 && g_trix_curr > 0.0))
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
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1804\",\"ea\":\"hutson-trix-cross-h4\"}");
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
   if(!QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode))
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

   if(!QM_IsNewBar(_Symbol, PERIOD_H4))
      return;

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

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
