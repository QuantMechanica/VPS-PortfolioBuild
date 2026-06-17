#property strict
#property version   "5.0"
#property description "QM5_10972 FTMO Trap Reversal"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10972;
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
input int    strategy_level_lookback       = 40;
input int    strategy_test_lookback        = 80;
input int    strategy_min_level_tests      = 2;
input int    strategy_reclaim_bars         = 3;
input int    strategy_atr_period           = 14;
input double strategy_pierce_atr_mult      = 0.25;
input double strategy_sl_atr_buffer        = 0.30;
input double strategy_take_rr              = 2.0;
input double strategy_breakeven_rr         = 1.0;
input int    strategy_time_exit_bars       = 24;
input double strategy_max_trap_range_atr   = 2.5;
input double strategy_min_range_height_atr = 1.5;
input int    strategy_rsi_period           = 14;
input double strategy_rsi_short_min        = 55.0;
input double strategy_rsi_short_fall_from  = 70.0;
input double strategy_rsi_long_max         = 45.0;
input double strategy_rsi_long_rise_from   = 30.0;

double g_pending_trap_extreme = 0.0;
int    g_pending_entry_side = 0;
ulong  g_active_ticket = 0;
double g_active_trap_extreme = 0.0;
double g_active_initial_risk = 0.0;

double BarHigh(const int shift)
  {
   return iHigh(_Symbol, PERIOD_CURRENT, shift); // perf-allowed structural 40/80-bar swing scan; EntrySignal is framework new-bar gated.
  }

double BarLow(const int shift)
  {
   return iLow(_Symbol, PERIOD_CURRENT, shift); // perf-allowed structural 40/80-bar swing scan; EntrySignal is framework new-bar gated.
  }

double BarClose(const int shift)
  {
   return iClose(_Symbol, PERIOD_CURRENT, shift); // perf-allowed structural closed-bar reclaim/exit check.
  }

double RangeHigh(const int start_shift, const int bars)
  {
   double high = 0.0;
   for(int i = 0; i < bars; ++i)
     {
      const double value = BarHigh(start_shift + i);
      if(value <= 0.0)
         return 0.0;
      if(i == 0 || value > high)
         high = value;
     }
   return high;
  }

double RangeLow(const int start_shift, const int bars)
  {
   double low = 0.0;
   for(int i = 0; i < bars; ++i)
     {
      const double value = BarLow(start_shift + i);
      if(value <= 0.0)
         return 0.0;
      if(i == 0 || value < low)
         low = value;
     }
   return low;
  }

int CountResistanceTests(const double resistance, const double tolerance,
                         const int start_shift, const int bars)
  {
   int tests = 0;
   for(int i = 0; i < bars; ++i)
     {
      const double high = BarHigh(start_shift + i);
      if(high <= 0.0)
         return 0;
      if(high >= resistance - tolerance)
         tests++;
     }
   return tests;
  }

int CountSupportTests(const double support, const double tolerance,
                      const int start_shift, const int bars)
  {
   int tests = 0;
   for(int i = 0; i < bars; ++i)
     {
      const double low = BarLow(start_shift + i);
      if(low <= 0.0)
         return 0;
      if(low <= support + tolerance)
         tests++;
     }
   return tests;
  }

bool FindOurPosition(ulong &ticket, ENUM_POSITION_TYPE &ptype, double &open_price,
                     double &sl, datetime &open_time)
  {
   ticket = 0;
   ptype = POSITION_TYPE_BUY;
   open_price = 0.0;
   sl = 0.0;
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
      sl = PositionGetDouble(POSITION_SL);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

double CloserTakeProfit(const QM_OrderType side, const double entry,
                        const double sl, const double opposite_range_side)
  {
   const double rr_tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_take_rr);
   if(rr_tp <= 0.0 || opposite_range_side <= 0.0)
      return rr_tp;

   if(side == QM_BUY)
     {
      if(opposite_range_side <= entry)
         return rr_tp;
      return QM_StopRulesNormalizePrice(_Symbol, MathMin(rr_tp, opposite_range_side));
     }

   if(opposite_range_side >= entry)
      return rr_tp;
   return QM_StopRulesNormalizePrice(_Symbol, MathMax(rr_tp, opposite_range_side));
  }

void ResetPositionState()
  {
   g_active_ticket = 0;
   g_active_trap_extreme = 0.0;
   g_active_initial_risk = 0.0;
  }

bool Strategy_NoTradeFilter()
  {
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

   if(strategy_level_lookback < 5 || strategy_test_lookback < strategy_level_lookback ||
      strategy_reclaim_bars < 1 || strategy_atr_period < 2)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic > 0 && QM_TM_OpenPositionCount(magic) > 0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double close_reclaim = BarClose(1);
   const double high_reclaim = BarHigh(1);
   const double low_reclaim = BarLow(1);
   if(close_reclaim <= 0.0 || high_reclaim <= low_reclaim)
      return false;

   const double reclaim_pos = (close_reclaim - low_reclaim) / (high_reclaim - low_reclaim);
   const double rsi_now = QM_RSI(_Symbol, PERIOD_CURRENT, strategy_rsi_period, 1, PRICE_CLOSE);
   const double rsi_prev = QM_RSI(_Symbol, PERIOD_CURRENT, strategy_rsi_period, 2, PRICE_CLOSE);
   if(rsi_now <= 0.0 || rsi_prev <= 0.0)
      return false;

   for(int trap_shift = 2; trap_shift <= strategy_reclaim_bars + 1; ++trap_shift)
     {
      const double resistance = RangeHigh(trap_shift + 1, strategy_level_lookback);
      const double support = RangeLow(trap_shift + 1, strategy_level_lookback);
      if(resistance <= support || (resistance - support) < strategy_min_range_height_atr * atr)
         continue;

      const double trap_high = BarHigh(trap_shift);
      const double trap_low = BarLow(trap_shift);
      if(trap_high <= trap_low || (trap_high - trap_low) > strategy_max_trap_range_atr * atr)
         continue;

      const double tolerance = strategy_pierce_atr_mult * atr;
      const int test_start = trap_shift + 1;

      if(trap_high >= resistance + tolerance &&
         close_reclaim < resistance &&
         reclaim_pos <= 0.40 &&
         CountResistanceTests(resistance, tolerance, test_start, strategy_test_lookback) >= strategy_min_level_tests &&
         (rsi_now > strategy_rsi_short_min || (rsi_prev > strategy_rsi_short_fall_from && rsi_now < rsi_prev)))
        {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid <= 0.0)
            return false;
         req.type = QM_SELL;
         req.sl = QM_StopRulesNormalizePrice(_Symbol, trap_high + strategy_sl_atr_buffer * atr);
         req.tp = CloserTakeProfit(req.type, bid, req.sl, support);
         if(req.sl <= bid || req.tp >= bid || req.tp <= 0.0)
            return false;
         req.reason = "FTMO_TRAP_REV_SHORT";
         g_pending_trap_extreme = trap_high;
         g_pending_entry_side = -1;
         return true;
        }

      if(trap_low <= support - tolerance &&
         close_reclaim > support &&
         reclaim_pos >= 0.60 &&
         CountSupportTests(support, tolerance, test_start, strategy_test_lookback) >= strategy_min_level_tests &&
         (rsi_now < strategy_rsi_long_max || (rsi_prev < strategy_rsi_long_rise_from && rsi_now > rsi_prev)))
        {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask <= 0.0)
            return false;
         req.type = QM_BUY;
         req.sl = QM_StopRulesNormalizePrice(_Symbol, trap_low - strategy_sl_atr_buffer * atr);
         req.tp = CloserTakeProfit(req.type, ask, req.sl, resistance);
         if(req.sl >= ask || req.tp <= ask || req.tp <= 0.0)
            return false;
         req.reason = "FTMO_TRAP_REV_LONG";
         g_pending_trap_extreme = trap_low;
         g_pending_entry_side = 1;
         return true;
        }
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   double open_price = 0.0;
   double sl = 0.0;
   datetime open_time = 0;
   if(!FindOurPosition(ticket, ptype, open_price, sl, open_time))
     {
      ResetPositionState();
      return;
     }

   if(g_active_ticket != ticket)
     {
      g_active_ticket = ticket;
      g_active_initial_risk = MathAbs(open_price - sl);
      g_active_trap_extreme = 0.0;
      if((ptype == POSITION_TYPE_BUY && g_pending_entry_side == 1) ||
         (ptype == POSITION_TYPE_SELL && g_pending_entry_side == -1))
         g_active_trap_extreme = g_pending_trap_extreme;
     }

   if(g_active_initial_risk <= 0.0)
      return;

   const bool is_buy = (ptype == POSITION_TYPE_BUY);
   const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(market <= 0.0)
      return;

   const double moved = is_buy ? (market - open_price) : (open_price - market);
   if(moved >= g_active_initial_risk * strategy_breakeven_rr)
      QM_TM_MoveSL(ticket, QM_StopRulesNormalizePrice(_Symbol, open_price), "ftmo_trap_rev_breakeven_1r");
  }

bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   double open_price = 0.0;
   double sl = 0.0;
   datetime open_time = 0;
   if(!FindOurPosition(ticket, ptype, open_price, sl, open_time))
      return false;

   const int period_seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(period_seconds > 0 && strategy_time_exit_bars > 0 &&
      TimeCurrent() - open_time >= (long)strategy_time_exit_bars * period_seconds)
      return true;

   if(g_active_trap_extreme <= 0.0)
      return false;

   if(!QM_IsNewBar(_Symbol, PERIOD_CURRENT))
      return false;

   const double close_last = BarClose(1);
   if(close_last <= 0.0)
      return false;

   if(ptype == POSITION_TYPE_BUY && close_last < g_active_trap_extreme)
      return true;
   if(ptype == POSITION_TYPE_SELL && close_last > g_active_trap_extreme)
      return true;

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10972_ftmo-trap-rev\"}");
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
