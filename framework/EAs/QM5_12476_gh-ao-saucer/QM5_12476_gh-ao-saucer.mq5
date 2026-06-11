#property strict
#property version   "5.0"
#property description "QM5_12476 GitHub Awesome Oscillator Saucer"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA
// Strategy card: QM5_12476_gh-ao-saucer
// Source: af7930c8-6c65-52d1-9c01-040490b5ad39
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12476;
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
input int    strategy_ao_fast_period    = 5;
input int    strategy_ao_slow_period    = 34;
input int    strategy_signal_mode       = 2;    // 0=trend, 1=saucer, 2=combined
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 2.0;

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only - runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(strategy_ao_fast_period < 1 || strategy_ao_slow_period <= strategy_ao_fast_period)
      return true;
   if(strategy_signal_mode < 0 || strategy_signal_mode > 2)
      return true;
   if(strategy_atr_period < 1 || strategy_atr_sl_mult <= 0.0)
      return true;

   const double slow = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period,
                              strategy_ao_slow_period, 4, PRICE_MEDIAN);
   return (slow <= 0.0);
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const double fast1 = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period,
                               strategy_ao_fast_period, 1, PRICE_MEDIAN);
   const double slow1 = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period,
                               strategy_ao_slow_period, 1, PRICE_MEDIAN);
   const double fast2 = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period,
                               strategy_ao_fast_period, 2, PRICE_MEDIAN);
   const double slow2 = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period,
                               strategy_ao_slow_period, 2, PRICE_MEDIAN);
   const double fast3 = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period,
                               strategy_ao_fast_period, 3, PRICE_MEDIAN);
   const double slow3 = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period,
                               strategy_ao_slow_period, 3, PRICE_MEDIAN);
   const double fast4 = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period,
                               strategy_ao_fast_period, 4, PRICE_MEDIAN);
   const double slow4 = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period,
                               strategy_ao_slow_period, 4, PRICE_MEDIAN);

   if(fast1 <= 0.0 || slow1 <= 0.0 || fast2 <= 0.0 || slow2 <= 0.0 ||
      fast3 <= 0.0 || slow3 <= 0.0 || fast4 <= 0.0 || slow4 <= 0.0)
      return false;

   const double ao1 = fast1 - slow1;
   const double ao2 = fast2 - slow2;
   const double ao3 = fast3 - slow3;
   const double ao4 = fast4 - slow4;

   const bool bullish_saucer = (ao1 < ao2 && ao2 > ao3 && ao3 > ao4 &&
                                ao1 < 0.0 && ao2 < 0.0 && ao3 < 0.0);
   const bool bearish_saucer = (ao1 > ao2 && ao2 < ao3 && ao3 < ao4 &&
                                ao1 > 0.0 && ao2 > 0.0 && ao3 > 0.0);

   int signal = 0;
   if(strategy_signal_mode == 1 || strategy_signal_mode == 2)
     {
      if(bullish_saucer)
         signal = 1;
      else if(bearish_saucer)
         signal = -1;
     }

   if(signal == 0 && (strategy_signal_mode == 0 || strategy_signal_mode == 2))
     {
      if(fast1 > slow1)
         signal = 1;
      else if(fast1 < slow1)
         signal = -1;
     }

   if(signal == 0)
      return false;

   const QM_OrderType side = (signal > 0) ? QM_BUY : QM_SELL;
   const double entry_price = (signal > 0)
                              ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                              : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double stop = QM_StopATR(_Symbol, side, entry_price,
                                  strategy_atr_period, strategy_atr_sl_mult);
   if(entry_price <= 0.0 || stop <= 0.0)
      return false;

   req.type = side;
   req.sl = stop;
   req.reason = (signal > 0) ? "AO_LONG" : "AO_SHORT";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no break-even, trailing, partial close, or pyramiding.
  }

// Return TRUE to close the open position now.
bool Strategy_ExitSignal()
  {
   int position_dir = 0;
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

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      position_dir = (ptype == POSITION_TYPE_BUY) ? 1 : -1;
      break;
     }

   if(position_dir == 0)
      return false;

   const double fast1 = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period,
                               strategy_ao_fast_period, 1, PRICE_MEDIAN);
   const double slow1 = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period,
                               strategy_ao_slow_period, 1, PRICE_MEDIAN);
   const double fast2 = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period,
                               strategy_ao_fast_period, 2, PRICE_MEDIAN);
   const double slow2 = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period,
                               strategy_ao_slow_period, 2, PRICE_MEDIAN);
   const double fast3 = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period,
                               strategy_ao_fast_period, 3, PRICE_MEDIAN);
   const double slow3 = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period,
                               strategy_ao_slow_period, 3, PRICE_MEDIAN);
   const double fast4 = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period,
                               strategy_ao_fast_period, 4, PRICE_MEDIAN);
   const double slow4 = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period,
                               strategy_ao_slow_period, 4, PRICE_MEDIAN);

   if(fast1 <= 0.0 || slow1 <= 0.0 || fast2 <= 0.0 || slow2 <= 0.0 ||
      fast3 <= 0.0 || slow3 <= 0.0 || fast4 <= 0.0 || slow4 <= 0.0)
      return false;

   const double ao1 = fast1 - slow1;
   const double ao2 = fast2 - slow2;
   const double ao3 = fast3 - slow3;
   const double ao4 = fast4 - slow4;

   const bool bullish_saucer = (ao1 < ao2 && ao2 > ao3 && ao3 > ao4 &&
                                ao1 < 0.0 && ao2 < 0.0 && ao3 < 0.0);
   const bool bearish_saucer = (ao1 > ao2 && ao2 < ao3 && ao3 < ao4 &&
                                ao1 > 0.0 && ao2 > 0.0 && ao3 > 0.0);

   bool bullish_exit = false;
   bool bearish_exit = false;

   if(strategy_signal_mode == 1 || strategy_signal_mode == 2)
     {
      bullish_exit = bullish_saucer;
      bearish_exit = bearish_saucer;
     }

   if(strategy_signal_mode == 0 || strategy_signal_mode == 2)
     {
      bullish_exit = bullish_exit || (fast1 > slow1);
      bearish_exit = bearish_exit || (fast1 < slow1);
     }

   return ((position_dir > 0 && bearish_exit) ||
           (position_dir < 0 && bullish_exit));
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework").
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12476_gh-ao-saucer\"}");
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
