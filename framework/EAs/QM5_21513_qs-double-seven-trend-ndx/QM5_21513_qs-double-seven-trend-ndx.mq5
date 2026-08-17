#property strict
#property version   "5.0"
#property description "QM5_21513 NDX Double 7s Trend-Aligned Pullback Strategy"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_21513 - NDX Double 7s Trend-Aligned Pullback
// -----------------------------------------------------------------------------
// Source: Larry Connors / Cesar Alvarez "Double 7s" (QuantifiedStrategies coverage)
// Implementation:
//   - Native NDX.DWX D1 bars only; no external feed, no ML.
//   - Primary trend filter: SMA(strategy_trend_sma_period, D1) on completed closes.
//   - Rolling 7-day close extremes: Lowest7 = Min(Close[1..7]), Highest7 = Max(Close[1..7]).
//   - Long entry: Close[1] > SMA200[1] and Close[1] <= Lowest7 (lowest close of 7 days).
//   - Short entry: Close[1] < SMA200[1] and Close[1] >= Highest7 (highest close of 7 days).
//   - Signal-target exit: Close[1] >= Highest7 (for Long), Close[1] <= Lowest7 (for Short).
//   - Fixed hard SL: strategy_atr_sl_mult * ATR(strategy_atr_period, D1).
//   - Max-hold exit: strategy_max_hold_bars (default 30 D1 bars).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 21513;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_trend_sma_period   = 200;
input int    strategy_extreme_window     = 7;
input int    strategy_atr_period         = 14;
input double strategy_atr_sl_mult        = 2.5;
input int    strategy_max_hold_bars      = 30;
input int    strategy_warmup_buffer      = 20;
input int    strategy_max_spread_points  = 500;

// Cached strategy state (updated once per closed D1 bar)
bool   g_state_valid   = false;
double g_close_1       = 0.0;
double g_sma_trend     = 0.0;
double g_lowest_7      = 0.0;
double g_highest_7     = 0.0;
double g_cached_atr    = 0.0;

// -----------------------------------------------------------------------------
// State update on new closed bar
// -----------------------------------------------------------------------------

void AdvanceState_OnNewBar()
  {
   g_state_valid = false;
   g_close_1     = 0.0;
   g_sma_trend   = 0.0;
   g_lowest_7    = 0.0;
   g_highest_7   = 0.0;
   g_cached_atr  = 0.0;

   const int window = MathMax(2, strategy_extreme_window);
   const int bars_needed = MathMax(strategy_trend_sma_period + strategy_warmup_buffer, window + 2);

   double closes[];
   ArrayResize(closes, bars_needed);
   ArraySetAsSeries(closes, true);

   const int copied = CopyClose(_Symbol, PERIOD_D1, 1, bars_needed, closes); // perf-allowed: bounded D1 vector behind QM_IsNewBar
   if(copied < bars_needed)
      return;

   g_close_1 = closes[0];
   if(g_close_1 <= 0.0)
      return;

   g_sma_trend = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_sma_period, 1);
   if(g_sma_trend <= 0.0 || !MathIsValidNumber(g_sma_trend))
      return;

   double min_c = closes[0];
   double max_c = closes[0];
   for(int i = 1; i < window; ++i)
     {
      if(closes[i] < min_c) min_c = closes[i];
      if(closes[i] > max_c) max_c = closes[i];
     }
   g_lowest_7  = min_c;
   g_highest_7 = max_c;

   g_cached_atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(g_cached_atr <= 0.0 || !MathIsValidNumber(g_cached_atr))
      return;

   g_state_valid = true;
  }

bool Strategy_HasOwnedPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   if(_Symbol != "NDX.DWX" || _Period != PERIOD_D1)
      return true;
   if(qm_ea_id != 21513 || qm_magic_slot_offset != 0)
      return true;
   if(strategy_trend_sma_period < 10 || strategy_extreme_window < 2)
      return true;
   if(strategy_atr_period <= 1 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_max_hold_bars <= 0 || strategy_max_spread_points <= 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_21513_DBL7";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_state_valid)
      return false;
   if(g_cached_atr <= 0.0 || !MathIsValidNumber(g_cached_atr))
      return false;

   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread_points < 0 || spread_points > strategy_max_spread_points)
      return false;

   // Entry logic:
   // LONG: Close[1] > SMA200[1] && Close[1] <= Lowest7 (lowest close of 7 days)
   // SHORT: Close[1] < SMA200[1] && Close[1] >= Highest7 (highest close of 7 days)
   int direction = 0;
   if(g_close_1 > g_sma_trend && g_close_1 <= g_lowest_7)
      direction = 1;
   else if(g_close_1 < g_sma_trend && g_close_1 >= g_highest_7)
      direction = -1;
   else
      return false;

   // Fresh-state management must close an opposite position before entry;
   // same-direction means hold. Any owned position that remains blocks entry.
   if(Strategy_HasOwnedPosition())
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0 || !MathIsValidNumber(entry_price))
      return false;

   req.sl = QM_StopATRFromValue(_Symbol,
                                req.type,
                                entry_price,
                                g_cached_atr,
                                strategy_atr_sl_mult);
   req.sl = QM_StopRulesNormalizePrice(_Symbol, req.sl);
   if(req.sl <= 0.0 || !MathIsValidNumber(req.sl))
      return false;
   if(req.type == QM_BUY && req.sl >= entry_price)
      return false;
   if(req.type == QM_SELL && req.sl <= entry_price)
      return false;

   req.tp = 0.0;
   req.reason = (direction > 0) ? "DBL7_LONG" : "DBL7_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const string position_symbol = PositionGetString(POSITION_SYMBOL);
      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      const int completed_bars = (opened > 0) ? iBarShift(_Symbol, PERIOD_D1, opened, false) : -1;

      bool should_close = false;
      if(position_symbol != "NDX.DWX")
         should_close = true;
      if(position_type != POSITION_TYPE_BUY && position_type != POSITION_TYPE_SELL)
         should_close = true;
      if(opened <= 0 || completed_bars < 0)
         should_close = true;

      // Max-hold exit
      if(completed_bars >= strategy_max_hold_bars)
         should_close = true;

      // Signal-target exit: close LONG when Close[1] >= Highest7; close SHORT when Close[1] <= Lowest7
      if(g_state_valid)
        {
         if(position_type == POSITION_TYPE_BUY && g_close_1 >= g_highest_7)
            should_close = true;
         else if(position_type == POSITION_TYPE_SELL && g_close_1 <= g_lowest_7)
            should_close = true;
        }

      if(should_close)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_ExitSignal()
  {
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring
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

   g_state_valid = false;
   g_close_1     = 0.0;
   g_sma_trend   = 0.0;
   g_lowest_7    = 0.0;
   g_highest_7   = 0.0;
   g_cached_atr  = 0.0;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_21513\",\"ea\":\"qs-double-seven-trend-ndx\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
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
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();
   AdvanceState_OnNewBar();

   // Re-run management against the freshly prepared D1 state. A failed or
   // unsettled opposite close remains fail-closed at Strategy_EntrySignal.
   Strategy_ManageOpenPosition();

   if(Strategy_NewsFilterHook(broker_now))
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

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
