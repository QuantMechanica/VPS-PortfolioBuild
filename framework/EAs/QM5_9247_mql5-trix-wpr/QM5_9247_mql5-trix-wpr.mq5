#property strict
#property version   "5.0"
#property description "QuantMechanica V5 — TRIX zero-cross with WPR midline confirmation"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9247 — TRIX WPR Zero Cross
// H4 trend-following: enter when TRIX crosses zero line while WPR confirms
// direction. Exit on opposite TRIX cross or WPR midline flip.
// Source: MQL5 Articles, Stephen Njuki, Part 67, Pattern 2.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9247;
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
input int    strategy_trix_period       = 3;    // TRIX triple-EMA period; article default
input int    strategy_wpr_period        = 14;   // Williams %R lookback period
input double strategy_atr_period        = 14;   // ATR period for stop/TP sizing
input double strategy_atr_sl_mult       = 1.9;  // SL = ATR * this multiplier
input double strategy_atr_tp_rr         = 2.2;  // TP = SL * this R:R ratio
input int    strategy_max_hold_bars     = 30;   // Failsafe exit after N H4 bars

// WPR not-extreme entry filter thresholds (card: long <-20, short >-80)
input double strategy_wpr_long_max      = -20.0;
input double strategy_wpr_short_min     = -80.0;

// -----------------------------------------------------------------------------
// Local TRIX pool helpers — follow QM_IndXXX / QM_XXX pattern from
// QM_Indicators.mqh. Uses framework pool API (QM_IndicatorsLookup /
// QM_IndicatorsRegister / QM_IndicatorReadBuffer) so handles are lifecycle-
// managed by the framework. MT5 provides iTriX natively.
// -----------------------------------------------------------------------------

int Local_IndTRIX(const string sym, const ENUM_TIMEFRAMES tf, const int period)
  {
   const string key = StringFormat("TRIX|%s|%d|%d", sym, (int)tf, period);
   int h = QM_IndicatorsLookup(key);
   if(h != INVALID_HANDLE)
      return h;
   h = iTriX(sym, tf, period, PRICE_CLOSE);
   return QM_IndicatorsRegister(key, h);
  }

double Local_TRIX(const string sym, const ENUM_TIMEFRAMES tf, const int period,
                  const int shift = 1)
  {
   return QM_IndicatorReadBuffer(Local_IndTRIX(sym, tf, period), 0, shift);
  }

// -----------------------------------------------------------------------------
// File-scope: track open-position entry bar index for time-based exit
// -----------------------------------------------------------------------------
long g_entry_bar_index = -1;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return false; // no additional session or regime filter
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Closed-bar TRIX values (shift=1 = last closed bar, shift=2 = bar before)
   const double trix0 = Local_TRIX(_Symbol, PERIOD_H4, strategy_trix_period, 1);
   const double trix1 = Local_TRIX(_Symbol, PERIOD_H4, strategy_trix_period, 2);

   // WPR at last closed bar
   const double wpr0 = QM_WPR(_Symbol, PERIOD_H4, strategy_wpr_period, 1);

   // ATR for stop distance
   const double atr = QM_ATR(_Symbol, PERIOD_H4, (int)strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double sl_pts  = atr * strategy_atr_sl_mult;
   const double tp_pts  = sl_pts * strategy_atr_tp_rr;
   const double ask     = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid     = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Long: TRIX crosses above zero AND WPR above midline AND not yet overbought
   if(trix0 > 0.0 && trix1 < 0.0 &&
      wpr0 > -50.0 && wpr0 < strategy_wpr_long_max)
     {
      req.type  = QM_BUY;
      req.price = ask;
      req.sl    = ask - sl_pts;
      req.tp    = ask + tp_pts;
      g_entry_bar_index = (long)Bars(_Symbol, PERIOD_H4);
      return true;
     }

   // Short: TRIX crosses below zero AND WPR below midline AND not yet oversold
   if(trix1 > 0.0 && trix0 < 0.0 &&
      wpr0 < -50.0 && wpr0 > strategy_wpr_short_min)
     {
      req.type  = QM_SELL;
      req.price = bid;
      req.sl    = bid + sl_pts;
      req.tp    = bid - tp_pts;
      g_entry_bar_index = (long)Bars(_Symbol, PERIOD_H4);
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // No trailing or break-even; TP/SL set at entry are the management
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double trix0 = Local_TRIX(_Symbol, PERIOD_H4, strategy_trix_period, 1);
      const double wpr0  = QM_WPR(_Symbol, PERIOD_H4, strategy_wpr_period, 1);

      // Long exit: TRIX crosses below zero OR WPR drops below midline
      if(ptype == POSITION_TYPE_BUY)
        {
         if(trix0 < 0.0 || wpr0 < -50.0)
            return true;
        }

      // Short exit: TRIX crosses above zero OR WPR rises above midline
      if(ptype == POSITION_TYPE_SELL)
        {
         if(trix0 > 0.0 || wpr0 > -50.0)
            return true;
        }

      // Failsafe time exit after strategy_max_hold_bars closed H4 bars
      if(g_entry_bar_index > 0)
        {
         long bars_now = (long)Bars(_Symbol, PERIOD_H4);
         if((bars_now - g_entry_bar_index) >= strategy_max_hold_bars)
            return true;
        }
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line
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
