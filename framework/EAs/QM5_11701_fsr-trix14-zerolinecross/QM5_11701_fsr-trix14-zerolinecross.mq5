#property strict
#property version   "5.0"
#property description "QM5_11701 FSR TRIX(14) H1 Zero-Line Cross"

#include <QM/QM_Common.mqh>

// =============================================================================
// Strategy: TRIX(14) H1 Zero-Line Cross
// Card: QM5_11701_fsr-trix14-zerolinecross
// Source: 30796091-5c65-5467-9f28-77d938217c26
// Entry: TRIX14 crosses zero upward (long) or downward (short) on H1 close.
// Exit:  SL=2×ATR(14), TP=4×ATR(14). Optional reverse-cross exit.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11701;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours               = 336;
input string qm_news_min_impact                    = "high";
input QM_NewsMode qm_news_mode_legacy              = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled               = true;
input int    qm_friday_close_hour_broker           = 21;

input group "Stress"
input double qm_stress_reject_probability          = 0.0;

input group "Strategy"
input int    strategy_trix_period                  = 14;   // TRIX triple-EMA smoothing period
input int    strategy_atr_period                   = 14;   // ATR period for stop/TP sizing
input double strategy_atr_sl_mult                  = 2.0;  // Stop = N × ATR(14)
input double strategy_atr_tp_mult                  = 4.0;  // TP = M × ATR(14); default 4 = 2:1 R:R
input bool   strategy_exit_on_reverse              = false; // Close on TRIX reverse-zero-cross

// --- TRIX via framework indicator pool ---------------------------------------
// iTRIX is not a QM_Indicators built-in; we register it in the same pool so
// the framework releases the handle on shutdown (no per-EA IndicatorRelease).

int QM_IndTRIX(const string sym, const ENUM_TIMEFRAMES tf, const int period)
  {
   const string key = StringFormat("TRIX|%s|%d|%d", sym, (int)tf, period);
   int h = QM_IndicatorsLookup(key);
   if(h != INVALID_HANDLE)
      return h;
   h = iTRIX(sym, tf, period, PRICE_CLOSE);
   return QM_IndicatorsRegister(key, h);
  }

double QM_TRIX_Read(const string sym, const ENUM_TIMEFRAMES tf,
                    const int period, const int shift = 1)
  {
   return QM_IndicatorReadBuffer(QM_IndTRIX(sym, tf, period), 0, shift);
  }

// =============================================================================
// Strategy hooks
// =============================================================================

// No intraday session filter; trades at any H1 bar.
bool Strategy_NoTradeFilter()
  {
   // Block if a position for this magic is already open (one position at a time).
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) == magic &&
         PositionGetString(POSITION_SYMBOL) == _Symbol)
         return true; // block new entry
     }
   return false;
  }

// Entry: TRIX(14) zero-line cross on closed H1 bar.
// Called only after QM_IsNewBar() is true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const double trix0 = QM_TRIX_Read(_Symbol, PERIOD_H1, strategy_trix_period, 1); // last closed bar
   const double trix1 = QM_TRIX_Read(_Symbol, PERIOD_H1, strategy_trix_period, 2); // bar before that

   if(trix0 == 0.0 && trix1 == 0.0)
      return false; // indicator not ready

   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double sl_pts = atr * strategy_atr_sl_mult;
   const double tp_pts = atr * strategy_atr_tp_mult;

   // Long: TRIX crosses from <= 0 to > 0
   if(trix1 <= 0.0 && trix0 > 0.0)
     {
      req.type  = ORDER_TYPE_BUY;
      req.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.sl    = req.price - sl_pts;
      req.tp    = req.price + tp_pts;
      req.lots  = QM_LotsForRisk(_Symbol, sl_pts / SymbolInfoDouble(_Symbol, SYMBOL_POINT));
      return true;
     }

   // Short: TRIX crosses from >= 0 to < 0
   if(trix1 >= 0.0 && trix0 < 0.0)
     {
      req.type  = ORDER_TYPE_SELL;
      req.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      req.sl    = req.price + sl_pts;
      req.tp    = req.price - tp_pts;
      req.lots  = QM_LotsForRisk(_Symbol, sl_pts / SymbolInfoDouble(_Symbol, SYMBOL_POINT));
      return true;
     }

   return false;
  }

// No active position management; SL/TP handles exit.
void Strategy_ManageOpenPosition()
  {
  }

// Optional: exit on TRIX reverse-zero-cross when strategy_exit_on_reverse=true.
bool Strategy_ExitSignal()
  {
   if(!strategy_exit_on_reverse)
      return false;
   if(!QM_IsNewBar())
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double trix0 = QM_TRIX_Read(_Symbol, PERIOD_H1, strategy_trix_period, 1);
      const double trix1 = QM_TRIX_Read(_Symbol, PERIOD_H1, strategy_trix_period, 2);

      // Exit long on downward cross
      if(ptype == POSITION_TYPE_BUY && trix1 >= 0.0 && trix0 < 0.0)
         return true;
      // Exit short on upward cross
      if(ptype == POSITION_TYPE_SELL && trix1 <= 0.0 && trix0 > 0.0)
         return true;
     }
   return false;
  }

// Defer to central news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// =============================================================================
// Framework wiring — do NOT edit below this line.
// =============================================================================

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

   // Warm up TRIX handle early so the first bar read is reliable.
   QM_IndTRIX(_Symbol, PERIOD_H1, strategy_trix_period);

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
