#property strict
#property version   "5.0"
#property description "QM5_10000 ForexFactory TASAYC CCI Breakout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  — closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        — risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() — use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly —
//     use the QM_* readers above. The framework pools handles and releases them
//     on shutdown.
//   - CopyRates over warmup windows on every tick. If you genuinely need raw
//     bar arrays, gate by QM_IsNewBar so the work runs once per closed bar.
//   - Hand-edit framework/include/QM/QM_MagicResolver.mqh. After adding rows
//     to magic_numbers.csv, run:
//         python framework/scripts/update_magic_resolver.py
//     This is idempotent and preserves all rows.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10000;
input int    qm_magic_slot_offset       = 0;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsMode qm_news_mode          = QM_NEWS_PAUSE;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_cci_period        = 20;
input double strategy_cci_threshold     = 100.0;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_buffer     = 0.10;
input double strategy_max_range_atr     = 2.50;
input double strategy_tp_r_multiple     = 2.0;
input int    strategy_time_stop_bars    = 36;

bool   g_long_excursion_active          = false;
bool   g_short_excursion_active         = false;
double g_current_long_peak              = 0.0;
double g_current_short_trough           = 0.0;
double g_prior_long_peak                = 0.0;
double g_prior_short_trough             = 0.0;
bool   g_has_prior_long_peak            = false;
bool   g_has_prior_short_trough         = false;

void TrackCciExcursions(const double cci)
  {
   if(cci > strategy_cci_threshold)
     {
      if(!g_long_excursion_active)
        {
         g_long_excursion_active = true;
         g_current_long_peak = cci;
        }
      else
         g_current_long_peak = MathMax(g_current_long_peak, cci);
     }
   else if(g_long_excursion_active)
     {
      g_prior_long_peak = g_current_long_peak;
      g_has_prior_long_peak = true;
      g_long_excursion_active = false;
      g_current_long_peak = 0.0;
     }

   if(cci < -strategy_cci_threshold)
     {
      if(!g_short_excursion_active)
        {
         g_short_excursion_active = true;
         g_current_short_trough = cci;
        }
      else
         g_current_short_trough = MathMin(g_current_short_trough, cci);
     }
   else if(g_short_excursion_active)
     {
      g_prior_short_trough = g_current_short_trough;
      g_has_prior_short_trough = true;
      g_short_excursion_active = false;
      g_current_short_trough = 0.0;
     }
  }

bool SelectOurPosition(ulong &ticket,
                       ENUM_POSITION_TYPE &type,
                       double &open_price,
                       double &sl,
                       datetime &open_time)
  {
   const int magic = QM_FrameworkMagic();
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
      type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      sl = PositionGetDouble(POSITION_SL);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
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

   if(strategy_cci_period <= 0 || strategy_atr_period <= 0 || strategy_cci_threshold <= 0.0)
      return false;

   const double cci = QM_CCI(_Symbol, PERIOD_H1, strategy_cci_period, 1);
   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   const double high = iHigh(_Symbol, PERIOD_H1, 1);
   const double low = iLow(_Symbol, PERIOD_H1, 1);
   const double close = iClose(_Symbol, PERIOD_H1, 1);
   const double range = high - low;
   if(atr <= 0.0 || high <= 0.0 || low <= 0.0 || close <= 0.0 || range <= 0.0)
     {
      TrackCciExcursions(cci);
      return false;
     }

   if(range > strategy_max_range_atr * atr)
     {
      TrackCciExcursions(cci);
      return false;
     }

   bool signal_long = false;
   bool signal_short = false;
   if(g_has_prior_long_peak && cci > strategy_cci_threshold && cci > g_prior_long_peak)
      signal_long = true;
   if(g_has_prior_short_trough && cci < -strategy_cci_threshold && cci < g_prior_short_trough)
      signal_short = true;

   if(signal_long)
     {
      const double sl = low - strategy_atr_sl_buffer * atr;
      const double risk = close - sl;
      if(risk > 0.0)
        {
         req.type = QM_BUY;
         req.price = 0.0;
         req.sl = sl;
         req.tp = close + strategy_tp_r_multiple * risk;
         req.reason = "TASAYC_CCI_LONG";
         TrackCciExcursions(cci);
         return true;
        }
     }

   if(signal_short)
     {
      const double sl = high + strategy_atr_sl_buffer * atr;
      const double risk = sl - close;
      if(risk > 0.0)
        {
         req.type = QM_SELL;
         req.price = 0.0;
         req.sl = sl;
         req.tp = close - strategy_tp_r_multiple * risk;
         req.reason = "TASAYC_CCI_SHORT";
         TrackCciExcursions(cci);
         return true;
        }
     }

   TrackCciExcursions(cci);
   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE type = POSITION_TYPE_BUY;
   double open_price = 0.0;
   double sl = 0.0;
   datetime open_time = 0;
   if(!SelectOurPosition(ticket, type, open_price, sl, open_time))
      return;

   const bool is_buy = (type == POSITION_TYPE_BUY);
   const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(market <= 0.0 || open_price <= 0.0 || sl <= 0.0 || point <= 0.0)
      return;

   const double initial_risk = is_buy ? (open_price - sl) : (sl - open_price);
   const double moved = is_buy ? (market - open_price) : (open_price - market);
   if(initial_risk <= 0.0 || moved < initial_risk)
      return;

   const bool already_be = is_buy ? (sl >= open_price - point * 0.5)
                                  : (sl <= open_price + point * 0.5);
   if(!already_be)
      QM_TM_MoveSL(ticket, open_price, "TASAYC_BE_AT_1R");
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE type = POSITION_TYPE_BUY;
   double open_price = 0.0;
   double sl = 0.0;
   datetime open_time = 0;
   if(!SelectOurPosition(ticket, type, open_price, sl, open_time))
      return false;

   if(strategy_time_stop_bars > 0 && open_time > 0)
     {
      const int seconds = PeriodSeconds(PERIOD_H1);
      if(seconds > 0 && TimeCurrent() - open_time >= strategy_time_stop_bars * seconds)
         return true;
     }

   const bool is_buy = (type == POSITION_TYPE_BUY);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const bool before_one_r = is_buy ? (sl < open_price - point * 0.5)
                                    : (sl > open_price + point * 0.5);
   if(before_one_r)
     {
      const double cci = QM_CCI(_Symbol, PERIOD_H1, strategy_cci_period, 1);
      if(is_buy && cci <= 0.0)
         return true;
      if(!is_buy && cci >= 0.0)
         return true;
     }

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
// Framework wiring — do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
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
   if(!QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: trade management can adjust SL/TP on open positions.
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. time stop). Separate from SL/TP.
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

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   if(!QM_IsNewBar())
      return;

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

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
