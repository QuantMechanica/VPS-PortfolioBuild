#property strict
#property version   "5.0"
#property description "QM5_11298 cs-bb-close H1 Bollinger close-break"

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
//   - QM_FrameworkTrackOpenPositionMae / QM_FrameworkHandleFridayClose /
//     QM_KillSwitchCheck / QM_NewsAllowsTrade
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
input int    qm_ea_id                   = 11298;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_bb_period    = 21;
input double strategy_bb_deviation = 2.0;
input int    strategy_atr_period   = 14;
input double strategy_sl_atr_mult  = 2.5;

// Suppresses a same-closed-bar reversal after the framework processes a
// mid-band exit. It is fixed lifecycle state, not an adaptive parameter.
bool g_skip_entry_after_exit = false;

// -----------------------------------------------------------------------------
// Strategy hooks — implemented mechanically from the approved card.
// -----------------------------------------------------------------------------

// No Trade Filter (time, spread, news): the card adds only an H1 timeframe
// constraint. Framework wiring owns spread-safe execution and the news gate.
bool Strategy_NoTradeFilter()
  {
   return ((ENUM_TIMEFRAMES)_Period != PERIOD_H1);
  }

// Trade Entry: evaluate the two most recent completed H1 bars. A close crossing
// an outer Bollinger band is the single trigger; no second event is required.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type               = QM_BUY;
   req.price              = 0.0;
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(g_skip_entry_after_exit)
     {
      g_skip_entry_after_exit = false;
      return false;
     }

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;
   if(strategy_bb_period < 2 || strategy_bb_deviation <= 0.0 ||
      strategy_atr_period < 2 || strategy_sl_atr_mult <= 0.0)
      return false;

   MqlRates prior_bar;
   MqlRates signal_bar;
   if(!QM_ReadBar(_Symbol, PERIOD_H1, 2, prior_bar) ||
      !QM_ReadBar(_Symbol, PERIOD_H1, 1, signal_bar))
      return false;

   const double upper_prior = QM_BB_Upper(_Symbol, PERIOD_H1, strategy_bb_period,
                                          strategy_bb_deviation, 2);
   const double upper_signal = QM_BB_Upper(_Symbol, PERIOD_H1, strategy_bb_period,
                                           strategy_bb_deviation, 1);
   const double lower_prior = QM_BB_Lower(_Symbol, PERIOD_H1, strategy_bb_period,
                                          strategy_bb_deviation, 2);
   const double lower_signal = QM_BB_Lower(_Symbol, PERIOD_H1, strategy_bb_period,
                                           strategy_bb_deviation, 1);
   if(upper_prior <= 0.0 || upper_signal <= 0.0 ||
      lower_prior <= 0.0 || lower_signal <= 0.0)
      return false;

   QM_OrderType direction;
   string entry_reason;
   if(prior_bar.close <= upper_prior && signal_bar.close > upper_signal)
     {
      direction = QM_BUY;
      entry_reason = "bb_close_break_long";
     }
   else if(prior_bar.close >= lower_prior && signal_bar.close < lower_signal)
     {
      direction = QM_SELL;
      entry_reason = "bb_close_break_short";
     }
   else
      return false;

   const double entry_price = (direction == QM_BUY)
                              ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                              : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_price <= 0.0)
      return false;

   const double stop_price = QM_StopATR(_Symbol, direction, entry_price,
                                        strategy_atr_period, strategy_sl_atr_mult);
   if(stop_price <= 0.0)
      return false;

   req.type   = direction;
   req.sl     = stop_price;
   req.reason = entry_reason;
   return true;
  }

// Trade Management: the card defines no trailing, partial-close, break-even,
// or scale-in rule. The catastrophic stop is server-side from entry.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close: close on a completed-bar cross back through the middle band.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   bool is_long = false;
   bool have_pos = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
       if(!PositionSelectByTicket(ticket))
          continue;
       if((int)PositionGetInteger(POSITION_MAGIC) != magic)
          continue;
       if(PositionGetString(POSITION_SYMBOL) != _Symbol)
          continue;
       is_long  = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
       have_pos = true;
       break;
     }
   if(!have_pos)
      return false;

   MqlRates prior_bar;
   MqlRates signal_bar;
   if(!QM_ReadBar(_Symbol, PERIOD_H1, 2, prior_bar) ||
      !QM_ReadBar(_Symbol, PERIOD_H1, 1, signal_bar))
      return false;

   const double middle_prior = QM_BB_Middle(_Symbol, PERIOD_H1, strategy_bb_period,
                                             strategy_bb_deviation, 2);
   const double middle_signal = QM_BB_Middle(_Symbol, PERIOD_H1, strategy_bb_period,
                                              strategy_bb_deviation, 1);
   if(middle_prior <= 0.0 || middle_signal <= 0.0)
      return false;

   const bool exit_now = is_long
                         ? (prior_bar.close >= middle_prior && signal_bar.close < middle_signal)
                         : (prior_bar.close <= middle_prior && signal_bar.close > middle_signal);
   if(exit_now)
      g_skip_entry_after_exit = true;
   return exit_now;
  }

// News Filter Hook: no card-specific override; the central callable hook remains
// available for P8 and gates entries only in the framework wiring below.
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
                        qm_news_mode_legacy,           // legacy back-compat
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,                            // pause-before (legacy hint)
                        30,                            // pause-after (legacy hint)
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,              // FW1 Axis A
                        qm_news_compliance))           // FW1 Axis B
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
   // Q08 evidence lifecycle: sample floating P&L before any per-tick guard can
   // return. QM_KillSwitchCheck retains the same call as a compatibility
   // fallback for pre-template EAs; keep this explicit hook in all new builds.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
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

   // FW1 — the news blackout gates NEW entries only. Management, stops, and
   // exits above continue to run through news windows.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
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
