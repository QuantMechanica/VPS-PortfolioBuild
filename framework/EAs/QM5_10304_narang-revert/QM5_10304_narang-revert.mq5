#property strict
#property version   "5.0"
#property description "QM5_10304 Narang Price Reversion Band Fade"

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
input int    qm_ea_id                   = 10304;
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
input ENUM_TIMEFRAMES strategy_signal_tf       = PERIOD_H4;
input int             strategy_bb_period       = 20;
input double          strategy_bb_deviation    = 2.0;
input int             strategy_rsi_period      = 14;
input double          strategy_rsi_long_level  = 30.0;
input double          strategy_rsi_short_level = 70.0;
input int             strategy_atr_period      = 14;
input double          strategy_atr_stop_mult   = 1.8;
input int             strategy_ema_period      = 200;
input double          strategy_ema_atr_band    = 1.5;
input int             strategy_adx_period      = 14;
input double          strategy_adx_max         = 28.0;
input int             strategy_max_hold_bars   = 12;
input int             strategy_warmup_bars     = 230;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

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

   if(strategy_bb_period <= 1 ||
      strategy_bb_deviation <= 0.0 ||
      strategy_rsi_period <= 1 ||
      strategy_atr_period <= 0 ||
      strategy_atr_stop_mult <= 0.0 ||
      strategy_ema_period <= 1 ||
      strategy_ema_atr_band <= 0.0 ||
      strategy_adx_period <= 0 ||
      strategy_max_hold_bars <= 0 ||
      strategy_warmup_bars <= strategy_ema_period)
      return false;

   if(Bars(_Symbol, strategy_signal_tf) < strategy_warmup_bars)
      return false;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double close_1 = QM_SMA(_Symbol, strategy_signal_tf, 1, 1, PRICE_CLOSE);
   const double lower_1 = QM_BB_Lower(_Symbol, strategy_signal_tf, strategy_bb_period, strategy_bb_deviation, 1);
   const double upper_1 = QM_BB_Upper(_Symbol, strategy_signal_tf, strategy_bb_period, strategy_bb_deviation, 1);
   const double rsi_1 = QM_RSI(_Symbol, strategy_signal_tf, strategy_rsi_period, 1);
   const double atr_1 = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   const double ema_1 = QM_EMA(_Symbol, strategy_signal_tf, strategy_ema_period, 1);
   const double adx_1 = QM_ADX(_Symbol, strategy_signal_tf, strategy_adx_period, 1);
   if(close_1 <= 0.0 || lower_1 <= 0.0 || upper_1 <= 0.0 ||
      rsi_1 <= 0.0 || atr_1 <= 0.0 || ema_1 <= 0.0 || adx_1 <= 0.0)
      return false;

   if(adx_1 > strategy_adx_max)
      return false;

   if(MathAbs(close_1 - ema_1) > strategy_ema_atr_band * atr_1)
      return false;

   int direction = 0;
   if(close_1 < lower_1 && rsi_1 <= strategy_rsi_long_level)
      direction = 1;
   if(close_1 > upper_1 && rsi_1 >= strategy_rsi_short_level)
      direction = -1;
   if(direction == 0)
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   req.price = QM_EntryMarketPrice(req.type);
   req.sl = QM_StopATRFromValue(_Symbol, req.type, req.price, atr_1, strategy_atr_stop_mult);
   req.reason = (direction > 0) ? "NARANG_REVERT_LONG" : "NARANG_REVERT_SHORT";
   if(req.price <= 0.0 || req.sl <= 0.0)
      return false;

   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no break-even, trailing, partial close, averaging, or grid.
  }

bool Strategy_ExitSignal()
  {
   if(strategy_bb_period <= 1 ||
      strategy_bb_deviation <= 0.0 ||
      strategy_max_hold_bars <= 0)
      return false;

   const double middle_1 = QM_BB_Middle(_Symbol, strategy_signal_tf, strategy_bb_period, strategy_bb_deviation, 1);
   if(middle_1 <= 0.0)
      return false;

   const int magic = QM_FrameworkMagic();

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const datetime opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      const int open_shift = iBarShift(_Symbol, strategy_signal_tf, opened_at, false);
      if(open_shift >= strategy_max_hold_bars)
         return true;

      const double close_1 = QM_SMA(_Symbol, strategy_signal_tf, 1, 1, PRICE_CLOSE);
      if(close_1 <= 0.0)
         continue;

      if(position_type == POSITION_TYPE_BUY && close_1 >= middle_1)
         return true;
      if(position_type == POSITION_TYPE_SELL && close_1 <= middle_1)
         return true;
     }

   return false;
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
