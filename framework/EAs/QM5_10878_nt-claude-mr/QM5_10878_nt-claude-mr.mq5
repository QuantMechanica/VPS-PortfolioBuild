#property strict
#property version   "5.0"
#property description "QM5_10878 NexusTrade Claude Mean-Reversion Rebalance (D1 long-only)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_10878 — NexusTrade Claude Mean-Reversion Rebalance
// -----------------------------------------------------------------------------
// Card: D:/QM/strategy_farm/artifacts/cards_approved/QM5_10878_nt-claude-mr.md
// D1 long-only mean reversion on index-CFD proxies (SP500/NDX/WS30 .DWX).
//
// Entry (each D1 close):
//   close   < SMA(50)
//   RSI(14) > rsi_lower (default 30)
//   RSI(14) < rsi_upper (default 50)
//   close   > BollLower(20, 2.0)
//   no open position under this magic
//   -> enter long at next bar open (framework single-entry path).
//
// Exit:
//   mean-reversion: close >= SMA(50) OR RSI(14) >= rsi_exit (default 55)
//   time stop:      held >= time_stop_days trading days (default 15)
//   catastrophic:   ATR stop at entry - atr_sl_mult * ATR(14) (in req.sl)
//
// Single-symbol per-magic; NOT a basket (reads only _Symbol).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10878;
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
input int    strategy_sma_period        = 50;    // trend SMA: close must be below this
input int    strategy_rsi_period        = 14;    // RSI lookback
input double strategy_rsi_lower         = 30.0;  // entry: RSI strictly above this
input double strategy_rsi_upper         = 50.0;  // entry: RSI strictly below this
input double strategy_rsi_exit          = 55.0;  // exit: RSI at/above this
input int    strategy_bb_period         = 20;    // Bollinger period
input double strategy_bb_dev            = 2.0;   // Bollinger std-dev multiplier
input int    strategy_atr_period        = 14;    // ATR period for the catastrophic stop
input double strategy_atr_sl_mult       = 2.5;   // catastrophic stop = entry - mult*ATR
input int    strategy_time_stop_days    = 15;    // close after this many trading days

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// O(1) per-tick filter. No session/spread gating needed for this D1 strategy.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// New long entry on the just-closed D1 bar (caller guarantees QM_IsNewBar()).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One position per magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const string sym       = _Symbol;
   const double close1    = iClose(sym, PERIOD_D1, 1);          // last closed D1 bar
   const double sma50     = QM_SMA(sym, PERIOD_D1, strategy_sma_period, 1);
   const double rsi14     = QM_RSI(sym, PERIOD_D1, strategy_rsi_period, 1);
   const double bb_lower  = QM_BB_Lower(sym, PERIOD_D1, strategy_bb_period, strategy_bb_dev, 1);

   if(close1 <= 0.0 || sma50 <= 0.0 || bb_lower <= 0.0)
      return false;

   // Entry filter (rebound confirmation: above the lower band, not below it).
   if(!(close1 < sma50))
      return false;
   if(!(rsi14 > strategy_rsi_lower))
      return false;
   if(!(rsi14 < strategy_rsi_upper))
      return false;
   if(!(close1 > bb_lower))
      return false;

   // Catastrophic ATR stop, fixed at entry. Framework fills market price.
   const double sl = QM_StopATR(sym, QM_BUY, close1, strategy_atr_period, strategy_atr_sl_mult);

   req.type           = QM_BUY;
   req.price          = 0.0;     // market fill at next bar open
   req.sl             = sl;      // 0.0 if ATR unavailable -> no hard stop, exits handle it
   req.tp             = 0.0;     // mean-reversion / time-stop exits, no fixed TP
   req.reason         = "nt-claude-mr long";
   req.symbol_slot    = 0;
   req.expiration_seconds = 0;
   return true;
  }

// No intrabar trade management for this strategy.
void Strategy_ManageOpenPosition()
  {
  }

// Mean-reversion exit OR time stop. Evaluated against the last closed D1 bar.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const string sym   = _Symbol;
   const double close1 = iClose(sym, PERIOD_D1, 1);
   const double sma50  = QM_SMA(sym, PERIOD_D1, strategy_sma_period, 1);
   const double rsi14  = QM_RSI(sym, PERIOD_D1, strategy_rsi_period, 1);

   // Mean-reversion exit.
   if(close1 >= sma50 && sma50 > 0.0)
      return true;
   if(rsi14 >= strategy_rsi_exit)
      return true;

   // Time stop: count closed D1 bars elapsed since the position opened.
   const datetime bar1_time = iTime(sym, PERIOD_D1, 1);
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != sym)
         continue;
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      // Bars strictly between the open bar and the last closed bar (inclusive).
      const int bars_held = Bars(sym, PERIOD_D1, open_time, bar1_time);
      if(bars_held >= strategy_time_stop_days)
         return true;
     }

   return false;
  }

// Defer to the central news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
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
