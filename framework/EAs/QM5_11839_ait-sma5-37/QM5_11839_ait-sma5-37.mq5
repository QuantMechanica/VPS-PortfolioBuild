#property strict
#property version   "5.0"
#property description "QuantMechanica V5 — AI Trader SMA5/37 Crossover (QM5_11839)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_11839 — AI Trader SMA5/37 Crossover (ait-sma5-37)
// Source: whchien/ai-trader CrossSMAStrategy
// D1 long-only trend following: enter on SMA(5) golden cross above SMA(37),
// exit on SMA(5) death cross below SMA(37), hard stop 2×ATR(14).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11839;
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
input int    strategy_fast_period       = 5;   // SMA fast period (default 5)
input int    strategy_slow_period       = 37;  // SMA slow period (default 37)
input int    strategy_atr_period        = 14;  // ATR period for hard stop
input double strategy_atr_sl_mult       = 2.0; // ATR multiplier for hard stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Golden cross: SMA(fast) crosses above SMA(slow) on the last closed D1 bar.
   double fast_curr = QM_SMA(_Symbol, PERIOD_CURRENT, strategy_fast_period, 1);
   double slow_curr = QM_SMA(_Symbol, PERIOD_CURRENT, strategy_slow_period, 1);
   double fast_prev = QM_SMA(_Symbol, PERIOD_CURRENT, strategy_fast_period, 2);
   double slow_prev = QM_SMA(_Symbol, PERIOD_CURRENT, strategy_slow_period, 2);

   if(fast_curr <= slow_curr)
      return false; // not above slow SMA now
   if(fast_prev > slow_prev)
      return false; // already crossed; not a fresh crossover

   // Hard stop: ATR(14) × mult below entry price
   double atr = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, 1);
   double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl_price    = entry_price - atr * strategy_atr_sl_mult;

   req.type         = QM_BUY;
   req.price        = entry_price;
   req.sl           = sl_price;
   req.tp           = 0.0;
   req.reason       = "ait-sma5-37 golden cross";
   req.symbol_slot  = qm_magic_slot_offset;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Static SL set at entry; no dynamic trail per card spec.
  }

bool Strategy_ExitSignal()
  {
   // Death cross: SMA(fast) crosses below SMA(slow) on the last closed D1 bar.
   double fast_curr = QM_SMA(_Symbol, PERIOD_CURRENT, strategy_fast_period, 1);
   double slow_curr = QM_SMA(_Symbol, PERIOD_CURRENT, strategy_slow_period, 1);
   double fast_prev = QM_SMA(_Symbol, PERIOD_CURRENT, strategy_fast_period, 2);
   double slow_prev = QM_SMA(_Symbol, PERIOD_CURRENT, strategy_slow_period, 2);

   return (fast_prev >= slow_prev && fast_curr < slow_curr);
  }

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
