#property strict
#property version   "5.0"
#property description "QM5_11379 144lwma-5smma-cross-m5"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11379 144lwma-5smma-cross-m5
// Card: D:/QM/strategy_farm/artifacts/cards_approved/QM5_11379_144lwma-5smma-cross-m5.md
// Mechanics: SMMA(5) crosses LWMA(144) on M5, close remains within 10 pips
// of LWMA, stop at the most recent opposite-side Williams fractal, TP at 2R.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11379;
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
input int    strategy_smma_period       = 5;
input int    strategy_lwma_period       = 144;
input int    strategy_proximity_pips    = 10;
input int    strategy_fractal_lookback  = 10;
input int    strategy_sl_cap_pips       = 20;
input int    strategy_fractal_max_pips  = 15;
input double strategy_tp_rr             = 2.0;
input int    strategy_spread_cap_pips   = 15;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick. Spread guard fails open on .DWX zero
// modeled spread and blocks only a genuinely wide positive spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   const double spread = ask - bid;
   if(cap > 0.0 && spread > 0.0 && spread > cap)
      return true;

   return false;
  }

// Caller guarantees QM_IsNewBar() == true. Entry uses the last closed bar:
// shift 1 is the cross candle, shift 2 is the prior closed bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_smma_period <= 0 ||
      strategy_lwma_period <= 0 ||
      strategy_proximity_pips <= 0 ||
      strategy_fractal_lookback < 2 ||
      strategy_sl_cap_pips <= 0 ||
      strategy_fractal_max_pips <= 0 ||
      strategy_tp_rr <= 0.0)
      return false;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double smma_1 = QM_SMMA(_Symbol, tf, strategy_smma_period, 1);
   const double smma_2 = QM_SMMA(_Symbol, tf, strategy_smma_period, 2);
   const double lwma_1 = QM_LWMA(_Symbol, tf, strategy_lwma_period, 1);
   const double lwma_2 = QM_LWMA(_Symbol, tf, strategy_lwma_period, 2);
   if(smma_1 <= 0.0 || smma_2 <= 0.0 || lwma_1 <= 0.0 || lwma_2 <= 0.0)
      return false;

   const bool long_cross = (smma_2 <= lwma_2 && smma_1 > lwma_1);
   const bool short_cross = (smma_2 >= lwma_2 && smma_1 < lwma_1);
   if(long_cross == short_cross)
      return false;

   const double close_1 = iClose(_Symbol, _Period, 1); // perf-allowed: one fixed closed-bar close; no QM_Close helper exists.
   if(close_1 <= 0.0)
      return false;

   const double proximity = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_proximity_pips);
   if(proximity <= 0.0 || MathAbs(close_1 - lwma_1) > proximity)
      return false;
   if(long_cross && close_1 < lwma_1)
      return false;
   if(short_cross && close_1 > lwma_1)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const QM_OrderType side = long_cross ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? ask : bid;
   const double max_stop = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_fractal_max_pips);
   const double cap_stop = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
   if(entry <= 0.0 || max_stop <= 0.0 || cap_stop <= 0.0)
      return false;

   double fractal_stop = 0.0;
   for(int shift = 2; shift <= strategy_fractal_lookback + 1; ++shift)
     {
      if(side == QM_BUY)
        {
         const double lower = QM_FractalLower(_Symbol, tf, shift);
         if(lower > 0.0 && lower != EMPTY_VALUE && lower < DBL_MAX / 2.0 && lower < entry)
           {
            fractal_stop = lower;
            break;
           }
        }
      else
        {
         const double upper = QM_FractalUpper(_Symbol, tf, shift);
         if(upper > 0.0 && upper != EMPTY_VALUE && upper < DBL_MAX / 2.0 && upper > entry)
           {
            fractal_stop = upper;
            break;
           }
        }
     }

   if(fractal_stop <= 0.0)
      return false;

   double stop_distance = MathAbs(entry - fractal_stop);
   if(stop_distance <= 0.0 || stop_distance > max_stop)
      return false;
   if(stop_distance > cap_stop)
      stop_distance = cap_stop;

   const double sl = (side == QM_BUY)
                     ? QM_StopRulesNormalizePrice(_Symbol, entry - stop_distance)
                     : QM_StopRulesNormalizePrice(_Symbol, entry + stop_distance);
   if(sl <= 0.0 || (side == QM_BUY && sl >= entry) || (side == QM_SELL && sl <= entry))
      return false;

   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = (side == QM_BUY) ? "smma5_cross_lwma144_long" : "smma5_cross_lwma144_short";
   return true;
  }

// Fixed SL and TP only; no card-authorized trailing, break-even, partial close,
// or scale-in management.
void Strategy_ManageOpenPosition()
  {
  }

// SL/TP and framework Friday close handle exits; the card has no discretionary
// strategy exit.
bool Strategy_ExitSignal()
  {
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
