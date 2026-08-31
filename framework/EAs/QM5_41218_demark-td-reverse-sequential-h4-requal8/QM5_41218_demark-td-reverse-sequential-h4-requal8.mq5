#property strict
#property version   "5.0"
#property description "QM5_41218 DeMark TD-Reverse-Sequential H4 requalification"

#include <QM/QM_Common.mqh>

// Faithful new-identity port of QM5_1567_demark-td-reverse-sequential-h4 under
// OWNER-DEC-Q09HOLD-REQUAL-8-20260829. Strategy mechanics and defaults remain
// unchanged; only identity, exact manifest binding, safe series readers, and
// current V5 framework wiring differ.

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 41218;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode       qm_news_temporal        = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance      = QM_NEWS_COMPLIANCE_DXZ;
input int                       qm_news_stale_max_hours = 336;
input string                    qm_news_min_impact      = "high";
input QM_NewsMode               qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_setup_bars         = 9;
input int    strategy_countdown_bars     = 13;
input int    strategy_countdown_timeout  = 24;
input int    strategy_atr_period         = 14;
input double strategy_sl_atr_buffer      = 0.5;
input double strategy_sl_atr_cap         = 3.0;
input double strategy_tp_atr_mult        = 1.5;
input double strategy_spread_atr_mult    = 0.4;
input int    strategy_regime_sma_period  = 200;
input int    strategy_time_stop_h4_bars  = 12;

bool Strategy_ReadBar(const ENUM_TIMEFRAMES timeframe,
                      const int shift,
                      MqlRates &bar)
  {
   ZeroMemory(bar);
   if(shift < 0)
      return false;
   return QM_ReadBar(_Symbol, timeframe, shift, bar);
  }

bool Strategy_SetupChain(const bool is_buy, const int setup_end_shift)
  {
   for(int k = 0; k < strategy_setup_bars; ++k)
     {
      const int shift = setup_end_shift + k;
      MqlRates current_bar;
      MqlRates four_back_bar;
      if(!Strategy_ReadBar(PERIOD_H4, shift, current_bar) ||
         !Strategy_ReadBar(PERIOD_H4, shift + 4, four_back_bar))
         return false;
      if(current_bar.close <= 0.0 || four_back_bar.close <= 0.0)
         return false;

      if(is_buy)
        {
         if(current_bar.close <= four_back_bar.close)
            return false;
        }
      else
        {
         if(current_bar.close >= four_back_bar.close)
            return false;
        }
     }
   return true;
  }

bool Strategy_CountdownTrigger(const bool is_buy,
                               const int setup_end_shift,
                               double &bar13_extreme)
  {
   int count = 0;
   double close_bar8 = 0.0;
   bar13_extreme = 0.0;

   for(int shift = setup_end_shift - 1; shift >= 1; --shift)
     {
      MqlRates current_bar;
      MqlRates two_back_bar;
      if(!Strategy_ReadBar(PERIOD_H4, shift, current_bar) ||
         !Strategy_ReadBar(PERIOD_H4, shift + 2, two_back_bar))
         return false;

      bool qualifies = false;
      if(is_buy)
        {
         if(current_bar.low <= 0.0 || two_back_bar.low <= 0.0)
            return false;
         qualifies = (current_bar.low < two_back_bar.low);
        }
      else
        {
         if(current_bar.high <= 0.0 || two_back_bar.high <= 0.0)
            return false;
         qualifies = (current_bar.high > two_back_bar.high);
        }

      if(!qualifies)
         continue;

      count++;
      if(count == 8)
         close_bar8 = current_bar.close;

      if(count == strategy_countdown_bars)
        {
         if(shift != 1 || close_bar8 <= 0.0)
            return false;
         bar13_extreme = is_buy ? current_bar.low : current_bar.high;
         if(bar13_extreme <= 0.0)
            return false;
         return is_buy ? (bar13_extreme < close_bar8)
                       : (bar13_extreme > close_bar8);
        }
     }

   return false;
  }

bool Strategy_FindReverseSequentialSignal(bool &is_buy,
                                          double &bar13_extreme)
  {
   const int max_setup_end_shift = strategy_countdown_timeout + 1;
   for(int setup_end_shift = 2;
       setup_end_shift <= max_setup_end_shift;
       ++setup_end_shift)
     {
      if(Strategy_SetupChain(true, setup_end_shift) &&
         Strategy_CountdownTrigger(true, setup_end_shift, bar13_extreme))
        {
         is_buy = true;
         return true;
        }

      if(Strategy_SetupChain(false, setup_end_shift) &&
         Strategy_CountdownTrigger(false, setup_end_shift, bar13_extreme))
        {
         is_buy = false;
         return true;
        }
     }
   return false;
  }

bool Strategy_HasOpenPositionForMagic()
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
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// No Trade Filter
// -----------------------------------------------------------------------------
bool Strategy_NoTradeFilter()
  {
   // Never suspend management or the time exit for an already-open position.
   if(Strategy_HasOpenPositionForMagic())
      return false;

   if(_Symbol != "EURUSD.DWX" || _Period != PERIOD_H4)
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_setup_bars <= 0 || strategy_countdown_bars < 8 ||
      strategy_countdown_timeout <= 0 || strategy_atr_period <= 0 ||
      strategy_sl_atr_buffer < 0.0 || strategy_sl_atr_cap <= 0.0 ||
      strategy_tp_atr_mult <= 0.0 || strategy_spread_atr_mult <= 0.0 ||
      strategy_regime_sma_period <= 0 || strategy_time_stop_h4_bars <= 0)
      return true;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return true;

   // Zero spread is normal for .DWX tester symbols; block only a real wide spread.
   if(ask > bid && (ask - bid) > strategy_spread_atr_mult * atr)
      return true;
   return false;
  }

// -----------------------------------------------------------------------------
// Trade Entry
// -----------------------------------------------------------------------------
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "td_reverse_sequential";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPositionForMagic())
      return false;

   bool is_buy = true;
   double bar13_extreme = 0.0;
   if(!Strategy_FindReverseSequentialSignal(is_buy, bar13_extreme))
      return false;

   MqlRates d1_bar;
   if(!Strategy_ReadBar(PERIOD_D1, 1, d1_bar))
      return false;
   const double d1_sma = QM_SMA(_Symbol, PERIOD_D1,
                                strategy_regime_sma_period, 1, PRICE_CLOSE);
   if(d1_bar.close <= 0.0 || d1_sma <= 0.0)
      return false;
   if(is_buy && d1_bar.close <= d1_sma)
      return false;
   if(!is_buy && d1_bar.close >= d1_sma)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const QM_OrderType side = is_buy ? QM_BUY : QM_SELL;
   const double entry = QM_EntryMarketPrice(side);
   if(atr <= 0.0 || entry <= 0.0)
      return false;

   const double raw_sl = is_buy
                         ? (bar13_extreme - strategy_sl_atr_buffer * atr)
                         : (bar13_extreme + strategy_sl_atr_buffer * atr);
   const double sl_dist = MathAbs(entry - raw_sl);
   if(sl_dist <= 0.0 || sl_dist > strategy_sl_atr_cap * atr)
      return false;
   if((is_buy && raw_sl >= entry) || (!is_buy && raw_sl <= entry))
      return false;

   const double raw_tp = is_buy
                         ? (entry + strategy_tp_atr_mult * atr)
                         : (entry - strategy_tp_atr_mult * atr);
   const double sl = QM_StopRulesNormalizePrice(_Symbol, raw_sl);
   const double tp = QM_StopRulesNormalizePrice(_Symbol, raw_tp);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = is_buy ? "td_reverse_sequential_buy"
                       : "td_reverse_sequential_sell";
   return true;
  }

// -----------------------------------------------------------------------------
// Trade Management
// -----------------------------------------------------------------------------
void Strategy_ManageOpenPosition()
  {
   // Fixed SL/TP only; the approved parent mechanics specify no trailing.
  }

// -----------------------------------------------------------------------------
// Trade Close
// -----------------------------------------------------------------------------
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const int hold_seconds = strategy_time_stop_h4_bars * PeriodSeconds(PERIOD_H4);
   if(hold_seconds <= 0)
      return false;

   const datetime now = TimeCurrent();
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
      if(opened > 0 && now - opened >= hold_seconds)
         return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// News Filter Hook
// -----------------------------------------------------------------------------
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Current V5 framework wiring
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
   QM_LogEvent(QM_INFO, "DEINIT",
               StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   // Q08 evidence lifecycle: no guard may skip open-position MAE sampling.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
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

   // News rules gate new entries only; management and exits above stay active.
   if(Strategy_NewsFilterHook(broker_now))
      return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now,
                                        qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now,
                                       qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar(_Symbol, PERIOD_H4))
      return;

   QM_EquityStreamOnNewBar();

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
