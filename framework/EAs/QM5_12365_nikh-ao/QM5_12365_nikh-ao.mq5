#property strict
#property version   "5.0"
#property description "QM5_12365 Nikhil Awesome Oscillator Zero Cross (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12365 nikh-ao
// Source: Nikhil-Adithyan/Algorithmic-Trading-with-Python, Momentum/Awesome_Oscillator.py
// Card:   D:\QM\strategy_farm\artifacts\cards_approved\QM5_12365_nikh-ao.md
// G0 APPROVED 2026-05-26
//
// Strategy: Awesome Oscillator(5,34) D1 zero-cross momentum, long only.
//   AO = SMA(5, median) - SMA(34, median) on D1.
//   Enter long on AO cross from below to above zero.
//   Exit long on AO cross from above to below zero.
//   Hard stop: 2.0 * ATR(14) below entry.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12365;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal      = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance    = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours                 = 336;
input string qm_news_min_impact                      = "high";
input QM_NewsMode qm_news_mode_legacy                = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_ao_fast       = 5;     // AO fast SMA period (source default)
input int    strategy_ao_slow       = 34;    // AO slow SMA period (source default)
input int    strategy_atr_period    = 14;    // ATR period for hard stop
input double strategy_atr_sl_mult  = 2.0;   // ATR multiplier for hard stop (P2 baseline)
input int    strategy_warmup_bars   = 120;   // Min D1 bars before trading

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Block trading until we have sufficient D1 history (warmup gate).
// Uses QM_SMA at shift=strategy_warmup_bars: returns 0.0 when history is
// insufficient (CopyBuffer fails on out-of-range shift).
bool Strategy_NoTradeFilter()
  {
   if(QM_SMA(_Symbol, PERIOD_D1, strategy_ao_slow, strategy_warmup_bars, PRICE_MEDIAN) <= 0.0)
      return true;
   return false;
  }

// Enter long when AO crosses from below zero to above zero on a closed D1 bar.
// AO(1) = last closed bar, AO(2) = bar before that.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const double ao_curr = QM_SMA(_Symbol, PERIOD_D1, strategy_ao_fast, 1, PRICE_MEDIAN)
                        - QM_SMA(_Symbol, PERIOD_D1, strategy_ao_slow, 1, PRICE_MEDIAN);
   const double ao_prev = QM_SMA(_Symbol, PERIOD_D1, strategy_ao_fast, 2, PRICE_MEDIAN)
                        - QM_SMA(_Symbol, PERIOD_D1, strategy_ao_slow, 2, PRICE_MEDIAN);

   // Long only: zero cross from below
   if(ao_curr <= 0.0 || ao_prev >= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, QM_BUY, ask, strategy_atr_period, strategy_atr_sl_mult);
   if(sl <= 0.0 || sl >= ask)
      return false;

   req.type               = QM_BUY;
   req.price              = 0.0;  // market order
   req.sl                 = sl;
   req.tp                 = 0.0;  // no fixed TP; exit via AO zero-cross below
   req.reason             = "NIKH_AO_ZERO_CROSS_LONG";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// No trailing or break-even logic specified by card; SL is set at entry.
void Strategy_ManageOpenPosition()
  {
  }

// Exit long when AO crosses from above zero to below zero.
// Checked every tick; fires on the first tick after the new D1 bar closes
// with AO below zero following a positive AO bar.
bool Strategy_ExitSignal()
  {
   const double ao_curr = QM_SMA(_Symbol, PERIOD_D1, strategy_ao_fast, 1, PRICE_MEDIAN)
                        - QM_SMA(_Symbol, PERIOD_D1, strategy_ao_slow, 1, PRICE_MEDIAN);
   const double ao_prev = QM_SMA(_Symbol, PERIOD_D1, strategy_ao_fast, 2, PRICE_MEDIAN)
                        - QM_SMA(_Symbol, PERIOD_D1, strategy_ao_slow, 2, PRICE_MEDIAN);

   return (ao_curr < 0.0 && ao_prev >= 0.0);
  }

// Defer news filtering to the framework two-axis check.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12365\",\"slug\":\"nikh-ao\"}");
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
