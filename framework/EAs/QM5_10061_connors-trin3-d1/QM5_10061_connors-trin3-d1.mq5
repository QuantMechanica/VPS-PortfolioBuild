#property strict
#property version   "5.0"
#property description "QM5_10061 Connors TRIN Three-Day Market Timing (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA
// Card: QM5_10061_connors-trin3-d1, g0_status APPROVED.
// Mechanised literally from Connors/TradingMarkets TRIN3 D1 market timing:
// long-only, next-open execution after the third closed TRIN > 1.0 day.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 10061;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal        = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance      = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_signal_tf          = PERIOD_D1;
input string          strategy_trin_symbol        = "TRIN";
input int             strategy_regime_sma_period  = 200;
input int             strategy_exit_sma_period    = 5;
input double          strategy_trin_threshold     = 1.0;
input int             strategy_trin_days          = 3;
input int             strategy_atr_period         = 14;
input double          strategy_atr_sl_mult        = 3.0;
input double          strategy_spread_atr_fraction = 0.25;
input int             strategy_time_stop_bars     = 5;

// No Trade Filter: time, spread, news.
bool Strategy_NoTradeFilter()
  {
   // No card-specific session or clock filter; framework handles news and Friday close.
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   const double atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   if(point <= 0.0 || atr <= 0.0 || spread_points < 0)
      return true;

   return ((double)spread_points * point) > (strategy_spread_atr_fraction * atr);
  }

// Trade Entry.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_signal_tf != PERIOD_D1 ||
      strategy_regime_sma_period <= 0 ||
      strategy_exit_sma_period <= 0 ||
      strategy_trin_days != 3 ||
      strategy_atr_period <= 0 ||
      strategy_atr_sl_mult <= 0.0)
      return false;

   const double close_last = iClose(_Symbol, strategy_signal_tf, 1); // perf-allowed: single closed D1 close read; no framework OHLC reader exists.
   const double sma200 = QM_SMA(_Symbol, strategy_signal_tf, strategy_regime_sma_period, 1);
   if(close_last <= 0.0 || sma200 <= 0.0 || close_last <= sma200)
      return false;

   const double trin_1 = iClose(strategy_trin_symbol, strategy_signal_tf, 1); // perf-allowed: external custom TRIN daily close, fixed shift only.
   const double trin_2 = iClose(strategy_trin_symbol, strategy_signal_tf, 2); // perf-allowed: external custom TRIN daily close, fixed shift only.
   const double trin_3 = iClose(strategy_trin_symbol, strategy_signal_tf, 3); // perf-allowed: external custom TRIN daily close, fixed shift only.
   if(trin_1 <= strategy_trin_threshold ||
      trin_2 <= strategy_trin_threshold ||
      trin_3 <= strategy_trin_threshold)
      return false;

   const double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   if(entry_price <= 0.0 || atr <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry_price, atr, strategy_atr_sl_mult);
   if(req.sl <= 0.0 || req.sl >= entry_price)
      return false;

   req.reason = "CONNORS_TRIN3_LONG_NEXT_OPEN";
   return true;
  }

// Trade Management.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, pyramiding, or TP.
  }

// Trade Close.
bool Strategy_ExitSignal()
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

      const double close_last = iClose(_Symbol, strategy_signal_tf, 1); // perf-allowed: single closed D1 close read for SMA(5) exit.
      const double sma5 = QM_SMA(_Symbol, strategy_signal_tf, strategy_exit_sma_period, 1);
      if(close_last > 0.0 && sma5 > 0.0 && close_last > sma5)
         return true;

      const datetime opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      const int bars_since_entry = iBarShift(_Symbol, strategy_signal_tf, opened_at, false);
      if(strategy_time_stop_bars > 0 && bars_since_entry >= strategy_time_stop_bars)
         return true;
     }

   return false;
  }

// News Filter Hook.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10061_connors_trin3_d1\"}");
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
