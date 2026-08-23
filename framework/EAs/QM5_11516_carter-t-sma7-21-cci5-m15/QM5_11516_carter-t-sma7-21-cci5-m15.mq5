#property strict
#property version   "5.0"
#property description "QM5_11516 Carter-T SMA(7/21) CCI(5) M15"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_11516
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11516;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.5;
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
input int    strategy_sma_fast_period      = 7;
input int    strategy_sma_slow_period      = 21;
input int    strategy_cci_period           = 5;
input int    strategy_cross_lookback       = 2;
input int    strategy_sync_bars            = 1;
input int    strategy_sl_pips              = 15;
input int    strategy_tp1_pips             = 25;
input double strategy_partial_close_ratio  = 0.50;
input int    strategy_be_buffer_pips       = 0;
input int    strategy_spread_cap_pips      = 12;
input bool   strategy_no_friday_entry      = true;

// -----------------------------------------------------------------------------
// Helper functions
// -----------------------------------------------------------------------------

double PipDistance(const int pips)
  {
   return QM_StopRulesPipsToPriceDistance(_Symbol, pips);
  }

bool IsFridayBrokerTime()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return (dt.day_of_week == 5);
  }

bool SpreadWithinCap()
  {
   const double max_spread = PipDistance(strategy_spread_cap_pips);
   if(max_spread <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return false;

   return ((ask - bid) <= max_spread);
  }

int FindSmaCrossShift(const bool bullish, const int max_lookback = 3)
  {
   for(int s = 1; s <= max_lookback; ++s)
     {
      const double sma_fast_now = QM_SMA(_Symbol, PERIOD_M15, strategy_sma_fast_period, s);
      const double sma_slow_now = QM_SMA(_Symbol, PERIOD_M15, strategy_sma_slow_period, s);
      const double sma_fast_prev = QM_SMA(_Symbol, PERIOD_M15, strategy_sma_fast_period, s + 1);
      const double sma_slow_prev = QM_SMA(_Symbol, PERIOD_M15, strategy_sma_slow_period, s + 1);
      if(sma_fast_now <= 0.0 || sma_slow_now <= 0.0 || sma_fast_prev <= 0.0 || sma_slow_prev <= 0.0)
         return -1;

      if(bullish && sma_fast_now > sma_slow_now && sma_fast_prev <= sma_slow_prev)
         return s;
      if(!bullish && sma_fast_now < sma_slow_now && sma_fast_prev >= sma_slow_prev)
         return s;
     }
   return -1;
  }

int FindCciZeroCrossShift(const bool bullish, const int max_lookback = 4)
  {
   for(int s = 1; s <= max_lookback; ++s)
     {
      const double cci_now = QM_CCI(_Symbol, PERIOD_M15, strategy_cci_period, s, PRICE_TYPICAL);
      const double cci_prev = QM_CCI(_Symbol, PERIOD_M15, strategy_cci_period, s + 1, PRICE_TYPICAL);
      if(bullish && cci_now > 0.0 && cci_prev <= 0.0)
         return s;
      if(!bullish && cci_now < 0.0 && cci_prev >= 0.0)
         return s;
     }
   return -1;
  }

bool SelectOurPosition(ulong &ticket, ENUM_POSITION_TYPE &type, double &open_price,
                       double &sl, double &tp, double &volume)
  {
   ticket = 0;
   type = POSITION_TYPE_BUY;
   open_price = 0.0;
   sl = 0.0;
   tp = 0.0;
   volume = 0.0;

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

      ticket = pos_ticket;
      type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      sl = PositionGetDouble(POSITION_SL);
      tp = PositionGetDouble(POSITION_TP);
      volume = PositionGetDouble(POSITION_VOLUME);
      return true;
     }

   return false;
  }

bool PartialAlreadyDone(const ENUM_POSITION_TYPE type, const double open_price, const double sl)
  {
   if(open_price <= 0.0 || sl <= 0.0)
      return false;

   const double be_buffer = PipDistance(strategy_be_buffer_pips);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   if(type == POSITION_TYPE_BUY)
      return (sl >= open_price + be_buffer - point);
   return (sl <= open_price - be_buffer + point);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return !SpreadWithinCap();
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

   if(strategy_no_friday_entry && IsFridayBrokerTime())
      return false;
   if(!SpreadWithinCap())
      return false;

   if(strategy_sma_fast_period <= 0 || strategy_sma_slow_period <= 0 ||
      strategy_cci_period <= 0 || strategy_sl_pips <= 0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   // LONG setup
   const int sma_shift_long = FindSmaCrossShift(true, strategy_cross_lookback);
   if(sma_shift_long >= 1)
     {
      const double cci1 = QM_CCI(_Symbol, PERIOD_M15, strategy_cci_period, 1, PRICE_TYPICAL);
      if(cci1 > 0.0)
        {
         const int cci_shift_long = FindCciZeroCrossShift(true, 4);
         if(cci_shift_long >= 1 && MathAbs(cci_shift_long - sma_shift_long) <= strategy_sync_bars)
           {
            const double sl = QM_StopFixedPips(_Symbol, QM_BUY, ask, strategy_sl_pips);
            if(sl > 0.0 && sl < ask)
              {
               req.type = QM_BUY;
               req.sl = sl;
               req.tp = 0.0;
               req.reason = "CARTER_SMA7_21_CCI5_LONG";
               return true;
              }
           }
        }
     }

   // SHORT setup
   const int sma_shift_short = FindSmaCrossShift(false, strategy_cross_lookback);
   if(sma_shift_short >= 1)
     {
      const double cci1 = QM_CCI(_Symbol, PERIOD_M15, strategy_cci_period, 1, PRICE_TYPICAL);
      if(cci1 < 0.0)
        {
         const int cci_shift_short = FindCciZeroCrossShift(false, 4);
         if(cci_shift_short >= 1 && MathAbs(cci_shift_short - sma_shift_short) <= strategy_sync_bars)
           {
            const double sl = QM_StopFixedPips(_Symbol, QM_SELL, bid, strategy_sl_pips);
            if(sl > 0.0 && sl > bid)
              {
               req.type = QM_SELL;
               req.sl = sl;
               req.tp = 0.0;
               req.reason = "CARTER_SMA7_21_CCI5_SHORT";
               return true;
              }
           }
        }
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   ulong ticket;
   ENUM_POSITION_TYPE type;
   double open_price;
   double sl;
   double tp;
   double volume;
   if(!SelectOurPosition(ticket, type, open_price, sl, tp, volume))
      return;
   if(PartialAlreadyDone(type, open_price, sl))
      return;
   if(open_price <= 0.0 || sl <= 0.0 || volume <= 0.0)
      return;

   const bool is_buy = (type == POSITION_TYPE_BUY);
   const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(market <= 0.0)
      return;

   const double tp1_dist = PipDistance(strategy_tp1_pips);
   if(tp1_dist <= 0.0)
      return;

   const double trigger = is_buy ? (open_price + tp1_dist) : (open_price - tp1_dist);
   if((is_buy && market < trigger) || (!is_buy && market > trigger))
      return;

   double lots_to_close = QM_TM_NormalizeVolume(_Symbol, volume * strategy_partial_close_ratio);
   if(lots_to_close <= 0.0 || lots_to_close >= volume)
      return;

   if(QM_TM_PartialClose(ticket, lots_to_close, QM_EXIT_PARTIAL))
     {
      QM_TM_MoveSL(ticket,
                   is_buy ? open_price + PipDistance(strategy_be_buffer_pips)
                          : open_price - PipDistance(strategy_be_buffer_pips),
                   "tp1_partial_move_to_breakeven");
     }
  }

bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE type;
   double open_price;
   double sl;
   double tp;
   double volume;
   if(!SelectOurPosition(ticket, type, open_price, sl, tp, volume))
      return false;

   if(!PartialAlreadyDone(type, open_price, sl))
      return false;

   const double sma_fast = QM_SMA(_Symbol, PERIOD_M15, strategy_sma_fast_period, 1);
   const double close1 = iClose(_Symbol, PERIOD_M15, 1); // perf-allowed: single closed-bar close; no QM close reader exists.
   if(sma_fast <= 0.0 || close1 <= 0.0)
      return false;

   if(type == POSITION_TYPE_BUY)
      return (close1 < sma_fast);
   return (close1 > sma_fast);
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_11516\",\"ea\":\"carter_t_sma7_21_cci5_m15\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   QM_FrameworkTrackOpenPositionMae();
   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar(_Symbol, PERIOD_M15))
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
