#property strict
#property version   "5.0"
#property description "QM5_12436 EA31337 Williams %R reentry"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  — closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_Stoch_K / QM_Stoch_D / QM_CCI /
//     QM_WPR (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_LotsForRisk(symbol, sl_points)        — risk model lot sizing
//   - QM_StopFixedPips / QM_TakeFixedPips
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() — use QM_IsNewBar()
//   - Call iWPR / CopyBuffer directly — use the QM_* readers above.
//   - Hand-edit framework/include/QM/QM_MagicResolver.mqh. After adding rows
//     to magic_numbers.csv, run:
//         python framework/scripts/update_magic_resolver.py
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12436;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_wpr_period        = 18;
input double strategy_signal_open_level = 40.0;
input int    strategy_signal_open_method = 0;
input int    strategy_stop_pips         = 80;
input int    strategy_take_pips         = 80;
input int    strategy_max_hold_bars     = 30;
input double strategy_max_spread_pips   = 4.0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// Card: D:/QM/strategy_farm/artifacts/cards_approved/QM5_12436_ea31337-wpr.md
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   if(strategy_wpr_period < 1 || strategy_signal_open_level <= 0.0 ||
      strategy_stop_pips <= 0 || strategy_take_pips <= 0 ||
      strategy_max_hold_bars <= 0 || strategy_max_spread_pips < 0.0)
      return true;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double max_spread = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_max_spread_pips);
   if(ask > 0.0 && bid > 0.0 && ask > bid && max_spread > 0.0 && (ask - bid) > max_spread)
      return true;

   return false;
  }

// Card: WPR(18) reentry from a four-bar extreme. Long when current WPR has
// reentered above -50-level (default -90) after dipping below -90 within
// the last four bars, and is rising; short mirrors above -50+level
// (default -10). "Over three bars" percent-change ported the same way as
// the sibling Stochastic card (QM5_12430): shift1-vs-shift3.
bool Strategy_LongSignal()
  {
   if(strategy_signal_open_method != 0)
      return false;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double w1 = QM_WPR(_Symbol, tf, strategy_wpr_period, 1);
   const double w2 = QM_WPR(_Symbol, tf, strategy_wpr_period, 2);
   const double w3 = QM_WPR(_Symbol, tf, strategy_wpr_period, 3);
   const double w4 = QM_WPR(_Symbol, tf, strategy_wpr_period, 4);
   if(w1 == 0.0 || w2 == 0.0 || w3 == 0.0 || w4 == 0.0)
      return false;

   const double reentry_level = -50.0 - strategy_signal_open_level;
   const double extreme_level = reentry_level;
   const double min_change_pct = strategy_signal_open_level / 10.0;
   const double min_w = MathMin(MathMin(w1, w2), MathMin(w3, w4));
   const double change_pct = ((w1 - w3) / w3) * 100.0;

   return (w1 > reentry_level &&
           min_w < extreme_level &&
           w1 > w2 &&
           change_pct >= min_change_pct);
  }

bool Strategy_ShortSignal()
  {
   if(strategy_signal_open_method != 0)
      return false;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double w1 = QM_WPR(_Symbol, tf, strategy_wpr_period, 1);
   const double w2 = QM_WPR(_Symbol, tf, strategy_wpr_period, 2);
   const double w3 = QM_WPR(_Symbol, tf, strategy_wpr_period, 3);
   const double w4 = QM_WPR(_Symbol, tf, strategy_wpr_period, 4);
   if(w1 == 0.0 || w2 == 0.0 || w3 == 0.0 || w4 == 0.0)
      return false;

   const double reentry_level = -50.0 + strategy_signal_open_level;
   const double extreme_level = reentry_level;
   const double min_change_pct = strategy_signal_open_level / 10.0;
   const double max_w = MathMax(MathMax(w1, w2), MathMax(w3, w4));
   const double change_pct = ((w3 - w1) / w3) * 100.0;

   return (w1 < reentry_level &&
           max_w > extreme_level &&
           w1 < w2 &&
           change_pct >= min_change_pct);
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

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   QM_OrderType side = QM_BUY;
   string reason = "";
   if(Strategy_LongSignal())
     {
      side = QM_BUY;
      reason = "EA31337_WPR_LONG";
     }
   else if(Strategy_ShortSignal())
     {
      side = QM_SELL;
      reason = "EA31337_WPR_SHORT";
     }
   else
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return false;

   const double entry = (side == QM_BUY ? ask : bid);
   const double sl = QM_StopFixedPips(_Symbol, side, entry, strategy_stop_pips);
   const double tp = QM_TakeFixedPips(_Symbol, side, entry, strategy_take_pips);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = reason;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed SL/TP plus time/opposite exits; no trailing or partial management.
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const int period_seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   const datetime now = TimeCurrent();

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      const long max_hold_seconds = (long)strategy_max_hold_bars * (long)period_seconds;
      if(period_seconds > 0 && opened > 0 &&
         (long)(now - opened) >= max_hold_seconds)
         return true;

      if(pos_type == POSITION_TYPE_BUY && Strategy_ShortSignal())
         return true;
      if(pos_type == POSITION_TYPE_SELL && Strategy_LongSignal())
         return true;
     }

   return false;
  }

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
