#property strict
#property version   "5.0"
#property description "QM5_10290 Cinar TRIX zero-line stop-and-reverse"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 10290;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_trix_period         = 15;
input int    strategy_trix_warmup_bars    = 160;
input int    strategy_atr_period          = 14;
input double strategy_atr_sl_mult         = 2.0;

double RateClose(const MqlRates &rates[], const int copied, const int shift)
  {
   if(shift < 1 || shift > copied)
      return 0.0;
   return rates[shift - 1].close;
  }

bool Strategy_CalculateTrix(double &trix)
  {
   trix = 0.0;
   if(strategy_trix_period <= 1)
      return false;

   const int min_bars = strategy_trix_period * 3 + 2;
   const int default_warmup = strategy_trix_period * 10 + 2;
   const int requested = (strategy_trix_warmup_bars > default_warmup) ? strategy_trix_warmup_bars : default_warmup;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, _Period, 1, requested, rates); // perf-allowed: exact TRIX triple-EMA close window, called only from the skeleton's closed-bar entry path.
   if(copied < min_bars)
      return false;

   const double alpha = 2.0 / ((double)strategy_trix_period + 1.0);
   const double one_minus_alpha = 1.0 - alpha;
   const int oldest = copied;
   const double seed_close = RateClose(rates, copied, oldest);
   if(seed_close <= 0.0)
      return false;

   double ema1 = seed_close;
   double ema2 = seed_close;
   double ema3 = seed_close;
   double previous_ema3 = 0.0;

   for(int shift = oldest - 1; shift >= 1; --shift)
     {
      const double close = RateClose(rates, copied, shift);
      if(close <= 0.0)
         return false;

      ema1 = alpha * close + one_minus_alpha * ema1;
      ema2 = alpha * ema1 + one_minus_alpha * ema2;
      ema3 = alpha * ema2 + one_minus_alpha * ema3;

      if(shift == 1)
        {
         if(previous_ema3 <= 0.0)
            return false;
         trix = (ema3 - previous_ema3) / previous_ema3;
         return true;
        }

      previous_ema3 = ema3;
     }

   return false;
  }

bool Strategy_GetOurPosition(int &position_direction, ulong &ticket)
  {
   position_direction = 0;
   ticket = 0;
   const int magic = QM_FrameworkMagic();
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

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      position_direction = (position_type == POSITION_TYPE_BUY) ? 1 : -1;
      ticket = pos_ticket;
      return true;
     }

   return false;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
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

   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return false;

   double trix = 0.0;
   if(!Strategy_CalculateTrix(trix))
      return false;

   int signal_direction = 0;
   if(trix > 0.0)
      signal_direction = 1;
   else if(trix < 0.0)
      signal_direction = -1;
   else
      return false;

   int current_direction = 0;
   ulong ticket = 0;
   if(Strategy_GetOurPosition(current_direction, ticket))
     {
      if(current_direction == signal_direction)
         return false;
      if(!QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL))
         return false;
     }

   const bool go_long = (signal_direction > 0);
   req.type = go_long ? QM_BUY : QM_SELL;
   req.reason = go_long ? "CINAR_TRIX_LONG" : "CINAR_TRIX_SHORT";

   const double entry_price = go_long ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                      : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   return (req.sl > 0.0);
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Source strategy specifies stop-and-reverse only; no trailing, partial close, or break-even rule.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   return false;
  }

// News Filter Hook (callable for P8 News Impact phase)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10290_cinar-trix\"}");
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
