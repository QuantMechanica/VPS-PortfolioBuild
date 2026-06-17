#property strict
#property version   "5.0"
#property description "QM5_10909 Carter Bollinger-Middle EMA RSI MACD breakout (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_10909 carter-bb-ema-rsi
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)",
//   2014, Strategy #8, pp.18-19. Card:
//   artifacts/cards_approved/QM5_10909_carter-bb-ema-rsi.md
//
// Mechanics (H1, EURUSD/GBPUSD):
//   Long  entry: EMA(3) crosses ABOVE the Bollinger(20,3) middle line on the
//                last closed bar, WHILE MACD(6,17,1) main > 0 and RSI(14) > 50.
//   Short entry: EMA(3) crosses BELOW the BB middle line, WHILE MACD main < 0
//                and RSI < 50.
//   The EMA/BB-middle cross is the single TRIGGER event; MACD and RSI are
//   confirming STATES (.DWX invariant #4 — never require two cross events on
//   the same bar). The "3-bar signal window" of the card is approximated by
//   evaluating the fresh cross each closed bar (i.e. it re-arms once a fresh
//   cross + confirming states coincide).
//   TP: closer of {Bollinger band at entry, fixed 50 pips}.
//   SL: a few pips beyond the nearer of {recent swing extreme, BB band};
//       baseline 5 pips beyond that level.
//   Exit: close if EMA(3) crosses back through the BB middle line.
//   One position per magic.
// All framework wiring below the hook block is unchanged from the skeleton.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10909;
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
// Bollinger Bands
input int    InpBBPeriod      = 20;     // Bollinger Bands period
input double InpBBDeviation   = 3.0;    // Bollinger Bands deviation
// EMA (cross of BB middle)
input int    InpEMAPeriod     = 3;      // Fast EMA period (crosses BB middle)
// MACD confirmation (main line vs zero)
input int    InpMACDFast      = 6;      // MACD fast EMA
input int    InpMACDSlow      = 17;     // MACD slow EMA
input int    InpMACDSignal    = 1;      // MACD signal period
// RSI confirmation (vs 50)
input int    InpRSIPeriod     = 14;     // RSI period
input double InpRSIMidline    = 50.0;   // RSI midline threshold
// Exits / stops / targets
input int    InpTPFixedPips   = 50;     // Fixed take-profit (pips); band TP used if closer
input int    InpSLBufferPips  = 5;      // Stop buffer beyond the reference level (pips)
input int    InpStructLookback = 10;    // Swing-extreme lookback (bars) for SL reference

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   // One active position per magic — block new entries while exposed.
   return (QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0);
  }

// Build the entry request on a fresh EMA/BB-middle cross with MACD+RSI states.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const string sym = _Symbol;
   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;

   // Closed-bar reads: shift 1 = last closed bar, shift 2 = the bar before.
   const double ema_1 = QM_EMA(sym, tf, InpEMAPeriod, 1);
   const double ema_2 = QM_EMA(sym, tf, InpEMAPeriod, 2);
   const double mid_1 = QM_BB_Middle(sym, tf, InpBBPeriod, InpBBDeviation, 1);
   const double mid_2 = QM_BB_Middle(sym, tf, InpBBPeriod, InpBBDeviation, 2);
   if(ema_1 == 0.0 || ema_2 == 0.0 || mid_1 == 0.0 || mid_2 == 0.0)
      return false;

   // Single TRIGGER: fresh cross of EMA(3) through the BB middle line.
   const bool cross_up   = (ema_2 <= mid_2 && ema_1 > mid_1);
   const bool cross_down = (ema_2 >= mid_2 && ema_1 < mid_1);
   if(!cross_up && !cross_down)
      return false;

   // Confirming STATES on the same closed bar.
   const double macd_main = QM_MACD_Main(sym, tf, InpMACDFast, InpMACDSlow, InpMACDSignal, 1);
   const double rsi       = QM_RSI(sym, tf, InpRSIPeriod, 1);

   const double bb_upper = QM_BB_Upper(sym, tf, InpBBPeriod, InpBBDeviation, 1);
   const double bb_lower = QM_BB_Lower(sym, tf, InpBBPeriod, InpBBDeviation, 1);
   if(bb_upper == 0.0 || bb_lower == 0.0)
      return false;

   const double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(sym, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(cross_up && macd_main > 0.0 && rsi > InpRSIMidline)
     {
      const double entry = ask;
      req.type = QM_BUY;
      req.price = 0.0;  // framework fills at market

      // SL: nearer of {swing low, lower band}, then InpSLBufferPips below it.
      const double struct_sl = QM_StopStructure(sym, QM_BUY, entry, InpStructLookback); // swing-low based price
      double sl_ref = bb_lower;
      if(struct_sl > 0.0 && struct_sl > sl_ref) // nearer to entry = the higher of the two below price
         sl_ref = struct_sl;
      const double buf = QM_StopRulesPipsToPriceDistance(sym, InpSLBufferPips);
      req.sl = QM_TM_NormalizePrice(sym, sl_ref - buf);

      // TP: closer of {upper band, fixed 50 pips}.
      const double tp_fixed = QM_TakeFixedPips(sym, QM_BUY, entry, InpTPFixedPips);
      double tp = (bb_upper < tp_fixed) ? bb_upper : tp_fixed; // closer = lower price for a long
      req.tp = QM_TM_NormalizePrice(sym, tp);

      req.reason = "carter_bb_ema_long";
      return true;
     }

   if(cross_down && macd_main < 0.0 && rsi < InpRSIMidline)
     {
      const double entry = bid;
      req.type = QM_SELL;
      req.price = 0.0;

      // SL: nearer of {swing high, upper band}, then InpSLBufferPips above it.
      const double struct_sl = QM_StopStructure(sym, QM_SELL, entry, InpStructLookback); // swing-high based price
      double sl_ref = bb_upper;
      if(struct_sl > 0.0 && struct_sl < sl_ref) // nearer to entry = the lower of the two above price
         sl_ref = struct_sl;
      const double buf = QM_StopRulesPipsToPriceDistance(sym, InpSLBufferPips);
      req.sl = QM_TM_NormalizePrice(sym, sl_ref + buf);

      // TP: closer of {lower band, fixed 50 pips}.
      const double tp_fixed = QM_TakeFixedPips(sym, QM_SELL, entry, InpTPFixedPips);
      double tp = (bb_lower > tp_fixed) ? bb_lower : tp_fixed; // closer = higher price for a short
      req.tp = QM_TM_NormalizePrice(sym, tp);

      req.reason = "carter_bb_ema_short";
      return true;
     }

   return false;
  }

// No active trade-management adjustments — SL/TP are set at entry.
void Strategy_ManageOpenPosition()
  {
  }

// Discretionary exit: EMA(3) crosses back through the BB middle line against
// the open position's direction.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const string sym = _Symbol;
   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;

   const double ema_1 = QM_EMA(sym, tf, InpEMAPeriod, 1);
   const double ema_2 = QM_EMA(sym, tf, InpEMAPeriod, 2);
   const double mid_1 = QM_BB_Middle(sym, tf, InpBBPeriod, InpBBDeviation, 1);
   const double mid_2 = QM_BB_Middle(sym, tf, InpBBPeriod, InpBBDeviation, 2);
   if(ema_1 == 0.0 || ema_2 == 0.0 || mid_1 == 0.0 || mid_2 == 0.0)
      return false;

   const bool cross_up   = (ema_2 <= mid_2 && ema_1 > mid_1);
   const bool cross_down = (ema_2 >= mid_2 && ema_1 < mid_1);
   if(!cross_up && !cross_down)
      return false;

   // Determine current position direction (one position per magic).
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && cross_down)
         return true;   // long closes on a downward EMA/BB-middle cross
      if(ptype == POSITION_TYPE_SELL && cross_up)
         return true;   // short closes on an upward cross
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
