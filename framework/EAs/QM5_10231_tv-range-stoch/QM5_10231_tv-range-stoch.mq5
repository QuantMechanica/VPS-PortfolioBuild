#property strict
#property version   "5.0"
#property description "QM5_10231 Range Oscillator Stoch Confirm"

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
input int    qm_ea_id                   = 10231;
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
input ENUM_TIMEFRAMES strategy_signal_tf      = PERIOD_H4;
input int    strategy_range_wma_period       = 20;
input int    strategy_atr_period             = 14;
input double strategy_range_entry_threshold  = 100.0;
input double strategy_range_exit_threshold   = 30.0;
input int    strategy_stoch_k                = 5;
input int    strategy_stoch_d                = 3;
input int    strategy_stoch_slowing          = 3;
input double strategy_stoch_cross_level      = 20.0;
input bool   strategy_ema_exit_enabled       = true;
input int    strategy_ema_exit_period        = 50;
input double strategy_atr_sl_mult            = 2.0;
input int    strategy_trade_start_hour       = 0;
input int    strategy_trade_end_hour         = 24;

double Strategy_NormalizePrice(const double price)
  {
   return QM_StopRulesNormalizePrice(_Symbol, price);
  }

double Strategy_RangeOscillator(const int shift)
  {
   const double close_value = iClose(_Symbol, strategy_signal_tf, shift); // perf-allowed: no QM_Close helper; reads fixed closed-bar shift
   const double mean_value = QM_WMA(_Symbol, strategy_signal_tf, strategy_range_wma_period, shift, PRICE_CLOSE);
   const double atr_value = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, shift);
   if(close_value <= 0.0 || mean_value <= 0.0 || atr_value <= 0.0)
      return 0.0;
   return 100.0 * (close_value - mean_value) / atr_value;
  }

bool Strategy_SelectOurLong(ulong &ticket)
  {
   ticket = 0;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
         continue;
      ticket = candidate;
      return true;
     }

   return false;
  }

bool Strategy_InsideTradeWindow()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   if(strategy_trade_start_hour == strategy_trade_end_hour)
      return true;
   if(strategy_trade_start_hour < strategy_trade_end_hour)
      return (dt.hour >= strategy_trade_start_hour && dt.hour < strategy_trade_end_hour);
   return (dt.hour >= strategy_trade_start_hour || dt.hour < strategy_trade_end_hour);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// No Trade Filter (time, spread, news): window only; spread/news are framework.
bool Strategy_NoTradeFilter()
  {
   if(!Strategy_InsideTradeWindow())
      return true;
   return false;
  }

// Trade Entry: long-only range oscillator plus stochastic confirmation.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(_Period != strategy_signal_tf)
      return false;

   ulong existing_ticket = 0;
   if(Strategy_SelectOurLong(existing_ticket))
      return false;

   const double range_osc = Strategy_RangeOscillator(1);
   if(range_osc <= strategy_range_entry_threshold)
      return false;

   const double k1 = QM_Stoch_K(_Symbol, strategy_signal_tf,
                                strategy_stoch_k, strategy_stoch_d,
                                strategy_stoch_slowing, 1);
   const double d1 = QM_Stoch_D(_Symbol, strategy_signal_tf,
                                strategy_stoch_k, strategy_stoch_d,
                                strategy_stoch_slowing, 1);
   const double k2 = QM_Stoch_K(_Symbol, strategy_signal_tf,
                                strategy_stoch_k, strategy_stoch_d,
                                strategy_stoch_slowing, 2);
   const double d2 = QM_Stoch_D(_Symbol, strategy_signal_tf,
                                strategy_stoch_k, strategy_stoch_d,
                                strategy_stoch_slowing, 2);
   if(k1 <= 0.0 || d1 <= 0.0 || k2 <= 0.0 || d2 <= 0.0)
      return false;
   if(!(k2 < strategy_stoch_cross_level && k2 <= d2 && k1 > d1))
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, QM_BUY, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(sl <= 0.0 || sl >= entry)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   const double sl_points = MathAbs(entry - sl) / point;
   if(QM_LotsForRisk(_Symbol, sl_points) <= 0.0)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = Strategy_NormalizePrice(sl);
   req.tp = 0.0;
   req.reason = "TV_RANGE_STOCH_LONG";
   return true;
  }

// Trade Management: no trailing, partial, or BE rule in the card.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close: range oscillator exit or optional EMA slope exit.
bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   if(!Strategy_SelectOurLong(ticket))
      return false;

   const double range_osc = Strategy_RangeOscillator(1);
   if(range_osc < strategy_range_exit_threshold)
      return true;

   if(strategy_ema_exit_enabled)
     {
      const double ema1 = QM_EMA(_Symbol, strategy_signal_tf, strategy_ema_exit_period, 1);
      const double ema2 = QM_EMA(_Symbol, strategy_signal_tf, strategy_ema_exit_period, 2);
      if(ema1 > 0.0 && ema2 > 0.0 && ema1 < ema2)
         return true;
     }

   return false;
  }

// News Filter Hook: no custom override; defer to framework P8-capable news gate.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10231_tv-range-stoch\"}");
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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
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
