#property strict
#property version   "5.0"
#property description "QM5_13138 XAU M5 EMA20 Asymmetric Impulse"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 13138;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = false;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_fast_ema_m5         = 20;
input int    strategy_mid_ema_m5          = 50;
input int    strategy_ha_warmup_bars      = 200;
input double strategy_stop_pct            = 10.0;
input double strategy_target_pct          = 1.0;
input int    strategy_target_delay_bars   = 12;
input int    strategy_max_hold_bars       = 5760;

bool g_strategy_new_bar = false;

bool Strategy_IsHostChart()
  {
   return (_Symbol == "XAUUSD.DWX" &&
           _Period == PERIOD_M5 &&
           qm_magic_slot_offset == 0);
  }

bool Strategy_IsManagedPosition()
  {
   return (PositionGetString(POSITION_SYMBOL) == _Symbol &&
           (int)PositionGetInteger(POSITION_MAGIC) == QM_FrameworkMagic());
  }

int Strategy_ManagedPositionCount()
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsManagedPosition())
         ++count;
     }
   return count;
  }

ulong Strategy_ManagedPositionTicket()
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsManagedPosition())
         return ticket;
     }
   return 0;
  }

void Strategy_CloseManagedPositions(const QM_ExitReason reason)
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) || !Strategy_IsManagedPosition())
         continue;
      QM_TM_ClosePosition(ticket, reason);
     }
  }

bool Strategy_HeikinAshiClosed(double &ha_open, double &ha_close)
  {
   ha_open = 0.0;
   ha_close = 0.0;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_M5, 1, strategy_ha_warmup_bars, rates); // perf-allowed: fixed 200-bar reconstruction called only from the M5 new-bar entry gate.
   if(copied != strategy_ha_warmup_bars)
      return false;

   double previous_open = 0.0;
   double previous_close = 0.0;
   for(int bar = copied - 1; bar >= 0; --bar)
     {
      const double current_close = (rates[bar].open + rates[bar].high +
                                    rates[bar].low + rates[bar].close) / 4.0;
      const double current_open = (bar == copied - 1)
                                  ? (rates[bar].open + rates[bar].close) / 2.0
                                  : (previous_open + previous_close) / 2.0;
      if(!MathIsValidNumber(current_open) || !MathIsValidNumber(current_close))
         return false;
      previous_open = current_open;
      previous_close = current_close;
      if(bar == 0)
        {
         ha_open = current_open;
         ha_close = current_close;
        }
     }
   return (ha_open > 0.0 && ha_close > 0.0);
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsHostChart())
      return true;
   if(strategy_fast_ema_m5 != 20 || strategy_mid_ema_m5 != 50 ||
      strategy_ha_warmup_bars != 200)
      return true;
   if(strategy_stop_pct != 10.0 || strategy_target_pct != 1.0 ||
      strategy_target_delay_bars != 12 || strategy_max_hold_bars != 5760)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "XAU_M5_EMA20_ASYMMETRIC";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_ManagedPositionCount() > 0)
      return false;

   const double fast1 = QM_EMA(_Symbol, PERIOD_M5, strategy_fast_ema_m5, 1, PRICE_CLOSE);
   const double fast2 = QM_EMA(_Symbol, PERIOD_M5, strategy_fast_ema_m5, 2, PRICE_CLOSE);
   const double mid1 = QM_EMA(_Symbol, PERIOD_M5, strategy_mid_ema_m5, 1, PRICE_CLOSE);
   const double mid2 = QM_EMA(_Symbol, PERIOD_M5, strategy_mid_ema_m5, 2, PRICE_CLOSE);
   if(fast1 <= 0.0 || fast2 <= 0.0 || mid1 <= 0.0 || mid2 <= 0.0)
      return false;
   if(!(fast1 > mid1 && fast2 <= mid2))
      return false;

   double ha_open = 0.0;
   double ha_close = 0.0;
   if(!Strategy_HeikinAshiClosed(ha_open, ha_close) ||
      !(ha_close > ha_open && ha_close > fast1))
      return false;

   const double entry = QM_EntryMarketPrice(QM_BUY);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(entry <= 0.0 || digits < 0)
      return false;
   req.sl = NormalizeDouble(entry * (1.0 - strategy_stop_pct / 100.0), digits);
   return (req.sl > 0.0 && req.sl < entry && MathIsValidNumber(req.sl));
  }

void Strategy_ManageOpenPosition()
  {
   const int count = Strategy_ManagedPositionCount();
   if(count <= 0)
      return;
   if(count > 1)
     {
      Strategy_CloseManagedPositions(QM_EXIT_STRATEGY);
      return;
     }

   const ulong ticket = Strategy_ManagedPositionTicket();
   if(ticket == 0 || !PositionSelectByTicket(ticket))
      return;
   const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
   const double entry = PositionGetDouble(POSITION_PRICE_OPEN);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(opened <= 0 || entry <= 0.0 || bid <= 0.0)
      return;

   const int delay_seconds = strategy_target_delay_bars * PeriodSeconds(PERIOD_M5);
   if(TimeCurrent() - opened >= delay_seconds &&
      bid >= entry * (1.0 + strategy_target_pct / 100.0))
     {
      QM_TM_ClosePosition(ticket, QM_EXIT_TP_HIT);
      return;
     }

   if(!g_strategy_new_bar)
      return;
   const int held_bars = iBarShift(_Symbol, PERIOD_M5, opened, false); // perf-allowed: one lookup per new M5 bar for the frozen 5760-bar time exit.
   if(held_bars >= strategy_max_hold_bars)
      QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
  }

bool Strategy_ExitSignal()
  {
   return false;
  }

bool Strategy_NewsAllowsEntry(const datetime broker_time)
  {
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      return QM_NewsAllowsTrade2(_Symbol,
                                 broker_time,
                                 qm_news_temporal,
                                 qm_news_compliance);
   return QM_NewsAllowsTrade(_Symbol, broker_time, qm_news_mode_legacy);
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

   string warmup_symbols[1] = {_Symbol};
   QM_BasketWarmupHistory(warmup_symbols, PERIOD_M5, strategy_ha_warmup_bars + 60);
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13138\",\"ea\":\"xau-m5-ema20\"}");
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
   if(QM_FrameworkHandleFridayClose())
      return;
   if(Strategy_NoTradeFilter())
      return;

   g_strategy_new_bar = QM_IsNewBar();
   if(g_strategy_new_bar)
      QM_EquityStreamOnNewBar();

   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
     {
      Strategy_CloseManagedPositions(QM_EXIT_STRATEGY);
      return;
     }

   if(!g_strategy_new_bar || !Strategy_NewsAllowsEntry(TimeCurrent()))
      return;

   QM_EntryRequest req;
   ZeroMemory(req);
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
