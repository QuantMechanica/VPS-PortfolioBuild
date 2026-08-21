#property strict
#property version   "5.0"
#property description "QM5_20179 Pesavento AB=CD Harmonic Pattern"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_20179
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 20179;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.5;
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
input int    strategy_zigzag_depth      = 20;
input int    strategy_zigzag_deviation  = 5;
input int    strategy_zigzag_backstep   = 3;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 1.0;
input int    strategy_time_stop_bars    = 30;

// -----------------------------------------------------------------------------
// Strategy Structs
// -----------------------------------------------------------------------------

struct StrategyPivot
{
   int type;      // 1 = High, -1 = Low
   double price;
   int shift;
};

// -----------------------------------------------------------------------------
// Global variables
// -----------------------------------------------------------------------------

int g_zigzag_handle = INVALID_HANDLE;

// -----------------------------------------------------------------------------
// Strategy helpers
// -----------------------------------------------------------------------------

bool Strategy_HasOurPosition(ENUM_POSITION_TYPE &position_type, datetime &opened_at)
{
   position_type = POSITION_TYPE_BUY;
   opened_at = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
   }

   return false;
}

bool ReadZigZagPivots(StrategyPivot &pivots[], int limit_bars)
{
   ArrayResize(pivots, 0);
   if(g_zigzag_handle == INVALID_HANDLE)
      return false;
   if(!QM_IndicatorWarmupReady(g_zigzag_handle,
                               0,
                               1,
                               limit_bars + 2,
                               "QM5_20179_zigzag"))
      return false;
      
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int collected = 0;
   
   for(int shift = 1; shift <= limit_bars && collected < 10; ++shift)
   {
      double price = QM_IndicatorReadBuffer(g_zigzag_handle, 0, shift);
      if(price == EMPTY_VALUE || price <= 0.0)
         continue;
         
      double high = iHigh(_Symbol, _Period, shift);
      double low = iLow(_Symbol, _Period, shift);
      if(high <= 0.0 || low <= 0.0)
         continue;
         
      StrategyPivot pivot;
      pivot.shift = shift;
      pivot.price = price;
      
      if(MathAbs(price - high) <= MathAbs(price - low) + point)
         pivot.type = 1; // High
      else
         pivot.type = -1; // Low
         
      // Avoid duplicate consecutive pivot types
      if(collected > 0 && pivots[collected - 1].type == pivot.type)
      {
         // Keep the more extreme one if they are of the same type
         if((pivot.type == 1 && pivot.price > pivots[collected - 1].price) ||
            (pivot.type == -1 && pivot.price < pivots[collected - 1].price))
         {
            pivots[collected - 1] = pivot;
         }
         continue;
      }
      
      ArrayResize(pivots, collected + 1);
      pivots[collected] = pivot;
      collected++;
   }
   
   return (collected >= 3);
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;
      
   double spread = ask - bid;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double pip = (digits == 3 || digits == 5) ? 10.0 * point : point;
   
   if(spread > 3.0 * pip)
      return true; // skip if spread > 3 pips
      
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

   // Check if we already have a position
   ENUM_POSITION_TYPE position_type;
   datetime opened_at;
   if(Strategy_HasOurPosition(position_type, opened_at))
      return false;

   // Initialize ZigZag handle if not done yet
   if(g_zigzag_handle == INVALID_HANDLE)
   {
      g_zigzag_handle = iCustom(_Symbol, _Period, "Examples\\ZigZag", strategy_zigzag_depth, strategy_zigzag_deviation, strategy_zigzag_backstep);
      if(g_zigzag_handle == INVALID_HANDLE)
         return false;
   }

   // Read pivots (limit search to last 200 bars)
   StrategyPivot pivots[];
   if(!ReadZigZagPivots(pivots, 200))
      return false;

   // We need at least A, B, C pivots
   // pivots[0] = C, pivots[1] = B, pivots[2] = A
   double A = pivots[2].price;
   double B = pivots[1].price;
   double C = pivots[0].price;

   // Reject pattern if total duration (A->D in bars) < 12 or > 200 H4 bars
   int duration = pivots[2].shift;
   if(duration < 12 || duration > 200)
      return false;

   double ab_len = MathAbs(A - B);
   double bc_len = MathAbs(C - B);
   if(ab_len <= 0.0)
      return false;

   // Fibonacci Retracement Ratio: C in 0.618 - 0.786 of A-B
   double retrace = bc_len / ab_len;
   if(retrace < 0.618 || retrace > 0.786)
      return false;

   // Determine if structure is Bullish or Bearish
   // Bullish: A High (1), B Low (-1), C High (1)
   bool is_bullish_pivots = (pivots[2].type == 1 && pivots[1].type == -1 && pivots[0].type == 1);
   // Bearish: A Low (-1), B High (1), C Low (-1)
   bool is_bearish_pivots = (pivots[2].type == -1 && pivots[1].type == 1 && pivots[0].type == -1);

   if(!is_bullish_pivots && !is_bearish_pivots)
      return false;

   double atr_val = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_val <= 0.0)
      return false;

   double close1 = iClose(_Symbol, _Period, 1);
   double open1 = iOpen(_Symbol, _Period, 1);
   double high1 = iHigh(_Symbol, _Period, 1);
   double low1 = iLow(_Symbol, _Period, 1);

   if(is_bullish_pivots)
   {
      // Bullish AB=CD (Long Setup)
      // D target range: C - ab_len * 1.272 to C - ab_len * 1.0
      double d_target_min = C - ab_len * 1.272;
      double d_target_max = C - ab_len * 1.0;
      
      // Price has reached the D zone
      bool reached_d = (low1 <= d_target_max + 0.5 * atr_val && close1 >= d_target_min - 0.5 * atr_val);
      
      // Bullish reversal candle
      bool bullish_reversal = (close1 > open1 && (close1 - low1) >= 0.5 * (high1 - low1));
      
      if(reached_d && bullish_reversal)
      {
         req.type = QM_BUY;
         req.price = 0.0; // market entry
         req.sl = (C - ab_len) - strategy_atr_sl_mult * atr_val;
         req.tp = C; // TP at C level
         req.reason = "PESAVENTO_ABCD_LONG";
         return true;
      }
   }
   else if(is_bearish_pivots)
   {
      // Bearish AB=CD (Short Setup)
      // D target range: C + ab_len * 1.0 to C + ab_len * 1.272
      double d_target_min = C + ab_len * 1.0;
      double d_target_max = C + ab_len * 1.272;
      
      // Price has reached the D zone
      bool reached_d = (high1 >= d_target_min - 0.5 * atr_val && close1 <= d_target_max + 0.5 * atr_val);
      
      // Bearish reversal candle
      bool bearish_reversal = (close1 < open1 && (high1 - close1) >= 0.5 * (high1 - low1));
      
      if(reached_d && bearish_reversal)
      {
         req.type = QM_SELL;
         req.price = 0.0; // market entry
         req.sl = (C + ab_len) + strategy_atr_sl_mult * atr_val;
         req.tp = C; // TP at C level
         req.reason = "PESAVENTO_ABCD_SHORT";
         return true;
      }
   }

   return false;
}

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
{
   ENUM_POSITION_TYPE position_type;
   datetime opened_at;
   if(!Strategy_HasOurPosition(position_type, opened_at))
      return false;
      
   if(opened_at > 0)
   {
      int bars_since_entry = iBarShift(_Symbol, _Period, opened_at, false);
      if(bars_since_entry >= strategy_time_stop_bars)
         return true; // time-stop exit
   }
   
   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
{
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                        qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_zigzag_handle != INVALID_HANDLE)
      IndicatorRelease(g_zigzag_handle);
   QM_FrameworkShutdown();
}

void OnTick()
{
   if(!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;
   
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;
   
   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
   {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
   }

   if(!QM_IsNewBar()) return;
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
   {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
   }
}

void OnTimer() { QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{
   QM_FrameworkOnTradeTransaction(t, r, res);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
