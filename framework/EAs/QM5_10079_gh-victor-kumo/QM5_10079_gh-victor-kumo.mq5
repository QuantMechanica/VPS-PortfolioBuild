#property strict
#property version   "5.0"
#property description "QM5_10079 GitHub Victor Algo Ichimoku Kumo Breakout"

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
input int    qm_ea_id                   = 10079;
input int    qm_magic_slot_offset       = 0;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsMode qm_news_mode          = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_tenkan_period     = 9;
input int    strategy_kijun_period      = 26;
input int    strategy_senkou_b_period   = 52;
input double strategy_stop_percent      = 3.0;

datetime g_exit_kumo_bar_time = 0;
double   g_exit_kumo_span_a = 0.0;
double   g_exit_kumo_span_b = 0.0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
double RangeMidpoint(const int period, const int shift)
  {
   if(period <= 0 || shift < 0)
      return 0.0;

   double highest = -DBL_MAX;
   double lowest = DBL_MAX;
   for(int i = shift; i < shift + period; ++i)
     {
      const double hi = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, i);
      const double lo = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, i);
      if(hi <= 0.0 || lo <= 0.0)
         return 0.0;
      highest = MathMax(highest, hi);
      lowest = MathMin(lowest, lo);
     }

   if(highest <= 0.0 || lowest <= 0.0 || highest < lowest)
      return 0.0;
   return (highest + lowest) * 0.5;
  }

bool KumoSpansAt(const int shift, double &span_a, double &span_b)
  {
   span_a = 0.0;
   span_b = 0.0;
   if(strategy_tenkan_period <= 0 || strategy_kijun_period <= 0 ||
      strategy_senkou_b_period <= 0)
      return false;

   const int origin_shift = shift + strategy_kijun_period;
   const double tenkan = RangeMidpoint(strategy_tenkan_period, origin_shift);
   const double kijun = RangeMidpoint(strategy_kijun_period, origin_shift);
   const double senkou_b = RangeMidpoint(strategy_senkou_b_period, origin_shift);
   if(tenkan <= 0.0 || kijun <= 0.0 || senkou_b <= 0.0)
      return false;

   span_a = (tenkan + kijun) * 0.5;
   span_b = senkou_b;
   return true;
  }

bool CachedCurrentKumoSpans(double &span_a, double &span_b)
  {
   span_a = 0.0;
   span_b = 0.0;

   const datetime current_bar_open = iTime(_Symbol, (ENUM_TIMEFRAMES)_Period, 0);
   if(current_bar_open <= 0)
      return false;

   if(g_exit_kumo_bar_time != current_bar_open)
     {
      double fresh_a;
      double fresh_b;
      if(!KumoSpansAt(0, fresh_a, fresh_b))
         return false;
      g_exit_kumo_bar_time = current_bar_open;
      g_exit_kumo_span_a = fresh_a;
      g_exit_kumo_span_b = fresh_b;
     }

   span_a = g_exit_kumo_span_a;
   span_b = g_exit_kumo_span_b;
   return (span_a > 0.0 && span_b > 0.0);
  }

bool GetOurPosition(ENUM_POSITION_TYPE &position_type, ulong &ticket)
  {
   position_type = POSITION_TYPE_BUY;
   ticket = 0;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      ticket = t;
      return true;
     }

   return false;
  }

bool HasPriorBarTrade()
  {
   const datetime prior_bar_open = iTime(_Symbol, (ENUM_TIMEFRAMES)_Period, 1);
   const datetime current_bar_open = iTime(_Symbol, (ENUM_TIMEFRAMES)_Period, 0);
   if(prior_bar_open <= 0 || current_bar_open <= prior_bar_open)
      return false;

   if(!HistorySelect(prior_bar_open, current_bar_open - 1))
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const int deals = HistoryDealsTotal();
   for(int i = 0; i < deals; ++i)
     {
      const ulong deal_ticket = HistoryDealGetTicket(i);
      if(deal_ticket == 0)
         continue;
      if(HistoryDealGetString(deal_ticket, DEAL_SYMBOL) != _Symbol)
         continue;
      if((int)HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) != magic)
         continue;
      const ENUM_DEAL_ENTRY entry_type = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
      if(entry_type == DEAL_ENTRY_IN || entry_type == DEAL_ENTRY_INOUT)
         return true;
     }

   return false;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_stop_percent <= 0.0)
      return false;

   ENUM_POSITION_TYPE position_type;
   ulong ticket = 0;
   if(GetOurPosition(position_type, ticket))
      return false;
   if(HasPriorBarTrade())
      return false;

   double span_a_1;
   double span_b_1;
   double span_a_2;
   double span_b_2;
   if(!KumoSpansAt(1, span_a_1, span_b_1) ||
      !KumoSpansAt(2, span_a_2, span_b_2))
      return false;

   const double low1 = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, 1);
   const double low2 = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, 2);
   const double high1 = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, 1);
   const double high2 = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, 2);
   if(low1 <= 0.0 || low2 <= 0.0 || high1 <= 0.0 || high2 <= 0.0)
      return false;

   const bool bullish_kumo = (span_a_1 > span_b_1 && span_a_2 > span_b_2);
   const bool bearish_kumo = (span_a_1 < span_b_1 && span_a_2 < span_b_2);
   const double upper_1 = MathMax(span_a_1, span_b_1);
   const double upper_2 = MathMax(span_a_2, span_b_2);
   const double lower_1 = MathMin(span_a_1, span_b_1);
   const double lower_2 = MathMin(span_a_2, span_b_2);

   QM_OrderType side = QM_BUY;
   string reason = "";
   if(bullish_kumo && low2 <= upper_2 && low1 > upper_1)
     {
      side = QM_BUY;
      reason = "KUMO_BREAKOUT_LONG";
     }
   else if(bearish_kumo && high2 >= lower_2 && high1 < lower_1)
     {
      side = QM_SELL;
      reason = "KUMO_BREAKOUT_SHORT";
     }
   else
      return false;

   const double entry = QM_EntryMarketPrice(side);
   if(entry <= 0.0)
      return false;

   const double stop_distance = entry * strategy_stop_percent / 100.0;
   if(stop_distance <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = (side == QM_BUY) ? entry - stop_distance : entry + stop_distance;
   req.tp = 0.0;
   req.reason = reason;
   return (req.sl > 0.0);
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Source strategy has no trailing, break-even, or partial-close rule.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE position_type;
   ulong ticket = 0;
   if(!GetOurPosition(position_type, ticket))
      return false;

   double span_a_0;
   double span_b_0;
   if(!CachedCurrentKumoSpans(span_a_0, span_b_0))
      return false;

   const double opposite_for_long = MathMin(span_a_0, span_b_0);
   const double opposite_for_short = MathMax(span_a_0, span_b_0);
   const double current_low = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, 0);
   const double current_high = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, 0);
   if(current_low <= 0.0 || current_high <= 0.0)
      return false;

   if(position_type == POSITION_TYPE_BUY && current_low < opposite_for_long)
      return true;
   if(position_type == POSITION_TYPE_SELL && current_high > opposite_for_short)
      return true;

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
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
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
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
   if(!QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: trade management can adjust SL/TP on open positions.
   Strategy_ManageOpenPosition();

   // Per-closed-bar: exit-signal and entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — Strategy functions see one new closed bar per
   // call, not every incoming tick.
   if(!QM_IsNewBar())
     return;

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

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
