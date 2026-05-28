#property strict
#property version   "5.0"
#property description "QM5_10485 MQL5 Executer AC Momentum Bend"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10485;
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
input ENUM_TIMEFRAMES strategy_work_tf     = PERIOD_H1;
input int    strategy_ao_fast_period       = 5;
input int    strategy_ao_slow_period       = 34;
input int    strategy_ac_smooth_period     = 5;
input int    strategy_atr_period           = 14;
input double strategy_atr_sl_mult          = 1.5;
input double strategy_target_rr            = 2.0;
input int    strategy_time_stop_bars       = 72;

double Strategy_AO(const int shift)
  {
   const double fast = QM_SMA(_Symbol, strategy_work_tf, strategy_ao_fast_period, shift, PRICE_MEDIAN);
   const double slow = QM_SMA(_Symbol, strategy_work_tf, strategy_ao_slow_period, shift, PRICE_MEDIAN);
   if(fast == EMPTY_VALUE || slow == EMPTY_VALUE || fast == 0.0 || slow == 0.0)
      return EMPTY_VALUE;
   return fast - slow;
  }

double Strategy_AC(const int shift)
  {
   if(strategy_ac_smooth_period <= 0)
      return EMPTY_VALUE;

   const double ao_now = Strategy_AO(shift);
   if(ao_now == EMPTY_VALUE)
      return EMPTY_VALUE;

   double ao_sum = 0.0;
   for(int i = 0; i < strategy_ac_smooth_period; ++i)
     {
      const double ao = Strategy_AO(shift + i);
      if(ao == EMPTY_VALUE)
         return EMPTY_VALUE;
      ao_sum += ao;
     }

   return ao_now - (ao_sum / strategy_ac_smooth_period);
  }

int Strategy_ACSignal()
  {
   if(strategy_ao_fast_period <= 0 ||
      strategy_ao_slow_period <= strategy_ao_fast_period ||
      strategy_ac_smooth_period <= 0)
      return 0;

   const double ac1 = Strategy_AC(1);
   const double ac2 = Strategy_AC(2);
   const double ac3 = Strategy_AC(3);
   const double ac4 = Strategy_AC(4);
   if(ac1 == EMPTY_VALUE || ac2 == EMPTY_VALUE || ac3 == EMPTY_VALUE || ac4 == EMPTY_VALUE)
      return 0;

   if(ac1 > 0.0 && ac2 > 0.0 && ac1 > ac2 && ac2 > ac3)
      return 1;
   if(ac1 < 0.0 && ac2 < 0.0 && ac1 > ac2 && ac2 > ac3 && ac3 > ac4)
      return 1;
   if(ac2 <= 0.0 && ac1 > 0.0)
      return 1;

   if(ac1 > 0.0 && ac2 > 0.0 && ac1 < ac2 && ac2 < ac3 && ac3 < ac4)
      return -1;
   if(ac1 < 0.0 && ac2 < 0.0 && ac1 < ac2 && ac2 < ac3)
      return -1;
   if(ac2 >= 0.0 && ac1 < 0.0)
      return -1;

   return 0;
  }

bool Strategy_FindOurPosition(ENUM_POSITION_TYPE &ptype, datetime &opened_at)
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

      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only - runs on every tick.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   ENUM_POSITION_TYPE existing_type = POSITION_TYPE_BUY;
   datetime existing_opened_at = 0;
   if(Strategy_FindOurPosition(existing_type, existing_opened_at))
      return false;

   const int signal = Strategy_ACSignal();
   if(signal == 0)
      return false;

   const QM_OrderType side = (signal > 0) ? QM_BUY : QM_SELL;
   const double entry = (signal > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                     : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0 || strategy_atr_sl_mult <= 0.0 || strategy_target_rr <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, strategy_work_tf, strategy_atr_period, 1);
   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr, strategy_atr_sl_mult);
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_target_rr);
   if(atr <= 0.0 || sl <= 0.0 || tp <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = (signal > 0) ? "EXEC_AC_LONG" : "EXEC_AC_SHORT";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, averaging, or grid.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   datetime opened_at = 0;
   if(!Strategy_FindOurPosition(ptype, opened_at))
      return false;

   if(strategy_time_stop_bars > 0 && opened_at > 0)
     {
      const int open_shift = iBarShift(_Symbol, strategy_work_tf, opened_at, false);
      if(open_shift >= strategy_time_stop_bars)
         return true;
     }

   const int signal = Strategy_ACSignal();
   if(ptype == POSITION_TYPE_BUY && signal < 0)
      return true;
   if(ptype == POSITION_TYPE_SELL && signal > 0)
      return true;

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
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
