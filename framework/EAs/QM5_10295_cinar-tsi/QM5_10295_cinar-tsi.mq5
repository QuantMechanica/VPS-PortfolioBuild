#property strict
#property version   "5.0"
#property description "QM5_10295 Cinar TSI signal-line stop-and-reverse"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 10295;
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
input int    strategy_tsi_first_period    = 25;
input int    strategy_tsi_second_period   = 13;
input int    strategy_signal_period       = 12;
input int    strategy_tsi_warmup_bars     = 260;
input int    strategy_atr_period          = 14;
input double strategy_atr_sl_mult         = 2.0;

double Strategy_RateClose(const MqlRates &rates[], const int copied, const int shift)
  {
   if(shift < 1 || shift > copied)
      return 0.0;
   return rates[shift - 1].close;
  }

bool Strategy_CalculateTsi(double &tsi, double &signal)
  {
   tsi = 0.0;
   signal = 0.0;

   if(strategy_tsi_first_period <= 1 ||
      strategy_tsi_second_period <= 1 ||
      strategy_signal_period <= 1)
      return false;

   const int min_bars = strategy_tsi_first_period + strategy_tsi_second_period + strategy_signal_period + 3;
   const int default_warmup = (strategy_tsi_first_period + strategy_tsi_second_period + strategy_signal_period) * 5;
   const int requested = (strategy_tsi_warmup_bars > default_warmup) ? strategy_tsi_warmup_bars : default_warmup;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, requested + 1, rates); // perf-allowed: exact TSI close-difference EMA window, called only from the skeleton's closed-bar entry path.
   if(copied < min_bars)
      return false;

   const double alpha_first = 2.0 / ((double)strategy_tsi_first_period + 1.0);
   const double alpha_second = 2.0 / ((double)strategy_tsi_second_period + 1.0);
   const double alpha_signal = 2.0 / ((double)strategy_signal_period + 1.0);

   const int oldest_shift = copied - 1;
   const double seed_close = Strategy_RateClose(rates, copied, oldest_shift);
   const double seed_prev = Strategy_RateClose(rates, copied, oldest_shift + 1);
   if(seed_close <= 0.0 || seed_prev <= 0.0)
      return false;

   const double seed_pc = seed_close - seed_prev;
   double pc_ema_first = seed_pc;
   double pc_ema_second = seed_pc;
   double apc_ema_first = MathAbs(seed_pc);
   double apc_ema_second = MathAbs(seed_pc);

   if(apc_ema_second <= 0.0)
      return false;

   double tsi_value = (pc_ema_second / apc_ema_second) * 100.0;
   double signal_ema = tsi_value;

   for(int shift = oldest_shift - 1; shift >= 1; --shift)
     {
      const double close_now = Strategy_RateClose(rates, copied, shift);
      const double close_prev = Strategy_RateClose(rates, copied, shift + 1);
      if(close_now <= 0.0 || close_prev <= 0.0)
         return false;

      const double pc = close_now - close_prev;
      const double apc = MathAbs(pc);

      pc_ema_first = alpha_first * pc + (1.0 - alpha_first) * pc_ema_first;
      pc_ema_second = alpha_second * pc_ema_first + (1.0 - alpha_second) * pc_ema_second;
      apc_ema_first = alpha_first * apc + (1.0 - alpha_first) * apc_ema_first;
      apc_ema_second = alpha_second * apc_ema_first + (1.0 - alpha_second) * apc_ema_second;

      if(apc_ema_second <= 0.0)
         return false;

      tsi_value = (pc_ema_second / apc_ema_second) * 100.0;
      signal_ema = alpha_signal * tsi_value + (1.0 - alpha_signal) * signal_ema;
     }

   tsi = tsi_value;
   signal = signal_ema;
   return true;
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
   // Card adds no strategy-specific session, spread, or regime filter; framework handles global gates.
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

   double tsi = 0.0;
   double signal = 0.0;
   if(!Strategy_CalculateTsi(tsi, signal))
      return false;

   int signal_direction = 0;
   if(tsi > 0.0 && tsi > signal)
      signal_direction = 1;
   else if(tsi < 0.0 && tsi < signal)
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
   req.reason = go_long ? "CINAR_TSI_LONG" : "CINAR_TSI_SHORT";

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
   // Opposite TSI condition closes and reverses inside the closed-bar entry hook.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10295_cinar-tsi\"}");
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
