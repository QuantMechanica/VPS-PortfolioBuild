#property strict
#property version   "5.1"
#property description "QM5_11593 robo-midnight-hammer-adx-d1 - D1 rejection candle with ADX/DI"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA - QM5_11593 robo-midnight-hammer-adx-d1
// -----------------------------------------------------------------------------
// Approved card: docs/strategy_card.md
// Source: RoboForex Educational Team, Forex Strategy Collection (~2015),
//         "Midnight", pages 109-110.
//
// On each completed D1 bar, a long setup requires a lower tail at least three
// times the real body, an upper tail no greater than half the lower tail,
// ADX(14) > 20, +DI > -DI, +DI > 20, and -DI < 20. The short setup mirrors
// those rules. Entry is at the next D1 open. The signal-bar extreme is the
// structural stop, 2R is the factory target, and any position still open is
// closed at the end of its entry D1 bar. No EMA condition is added because the
// source card names EMA(24) as context only and defines no mechanical EMA rule.
// One position per magic; no grid, martingale, adaptive parameter, or ML.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 11593;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_adx_period              = 14;
input double strategy_adx_threshold           = 20.0;
input double strategy_tail_body_ratio         = 3.0;
input double strategy_opposite_tail_max_ratio = 0.5;
input double strategy_rr_target               = 2.0;
input int    strategy_max_hold_bars            = 1;

// State is refreshed only after the framework consumes a new D1 bar.
int    g_signal_direction = 0; // +1 long, -1 short, 0 none
double g_signal_low       = 0.0;
double g_signal_high      = 0.0;
bool   g_exit_requested   = false;

int Strategy_ExpectedSlot()
  {
   if(_Symbol == "EURUSD.DWX") return 0;
   if(_Symbol == "GBPUSD.DWX") return 1;
   if(_Symbol == "AUDUSD.DWX") return 2;
   if(_Symbol == "USDJPY.DWX") return 3;
   if(_Symbol == "NZDUSD.DWX") return 4;
   if(_Symbol == "USDCAD.DWX") return 5;
   return -1;
  }

bool Strategy_ConfigurationAuthorized()
  {
   const int expected_slot = Strategy_ExpectedSlot();
   return (qm_ea_id == 11593 &&
           expected_slot >= 0 &&
           qm_magic_slot_offset == expected_slot &&
           (ENUM_TIMEFRAMES)_Period == PERIOD_D1 &&
           strategy_adx_period >= 2 && strategy_adx_period <= 100 &&
           strategy_adx_threshold > 0.0 && strategy_adx_threshold < 100.0 &&
           strategy_tail_body_ratio > 0.0 && strategy_tail_body_ratio <= 20.0 &&
           strategy_opposite_tail_max_ratio >= 0.0 &&
           strategy_opposite_tail_max_ratio <= 1.0 &&
           strategy_rr_target > 0.0 && strategy_rr_target <= 10.0 &&
           strategy_max_hold_bars >= 1 && strategy_max_hold_bars <= 10);
  }

// Compute the completed-bar signal and end-of-entry-day exit once per D1 bar.
void AdvanceState_OnNewBar()
  {
   g_signal_direction = 0;
   g_signal_low = 0.0;
   g_signal_high = 0.0;
   g_exit_requested = false;

   if(!Strategy_ConfigurationAuthorized())
      return;

   const double open1  = iOpen(_Symbol, PERIOD_D1, 1);  // perf-allowed: fixed structural OHLC read behind QM_IsNewBar().
   const double high1  = iHigh(_Symbol, PERIOD_D1, 1);  // perf-allowed: fixed structural OHLC read behind QM_IsNewBar().
   const double low1   = iLow(_Symbol, PERIOD_D1, 1);   // perf-allowed: fixed structural OHLC read behind QM_IsNewBar().
   const double close1 = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: fixed structural OHLC read behind QM_IsNewBar().
   if(open1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0 || high1 <= low1)
      return;

   const double body = MathAbs(close1 - open1);
   const double lower_tail = MathMin(open1, close1) - low1;
   const double upper_tail = high1 - MathMax(open1, close1);
   if(lower_tail < 0.0 || upper_tail < 0.0)
      return;

   const double adx = QM_ADX(_Symbol, PERIOD_D1, strategy_adx_period, 1);
   const double plus_di = QM_ADX_PlusDI(_Symbol, PERIOD_D1, strategy_adx_period, 1);
   const double minus_di = QM_ADX_MinusDI(_Symbol, PERIOD_D1, strategy_adx_period, 1);

   const bool long_shape = (lower_tail > 0.0 &&
                            lower_tail >= strategy_tail_body_ratio * body &&
                            upper_tail <= strategy_opposite_tail_max_ratio * lower_tail);
   const bool short_shape = (upper_tail > 0.0 &&
                             upper_tail >= strategy_tail_body_ratio * body &&
                             lower_tail <= strategy_opposite_tail_max_ratio * upper_tail);
   const bool long_confirmation = (adx > strategy_adx_threshold &&
                                   plus_di > minus_di &&
                                   plus_di > strategy_adx_threshold &&
                                   minus_di < strategy_adx_threshold);
   const bool short_confirmation = (adx > strategy_adx_threshold &&
                                    minus_di > plus_di &&
                                    minus_di > strategy_adx_threshold &&
                                    plus_di < strategy_adx_threshold);

   if(long_shape && long_confirmation)
      g_signal_direction = +1;
   else if(short_shape && short_confirmation)
      g_signal_direction = -1;

   g_signal_low = low1;
   g_signal_high = high1;

   const int magic = QM_FrameworkMagic();
   int matching_positions = 0;
   datetime entry_time = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      ++matching_positions;
      entry_time = (datetime)PositionGetInteger(POSITION_TIME);
     }

   if(matching_positions <= 0)
      return;
   if(matching_positions != 1 || entry_time <= 0)
     {
      g_exit_requested = true;
      return;
     }

   // Entry occurs at a D1 open. At the next D1 open, entry_shift is 1 and the
   // source's same-day close becomes executable without an exact-minute gate.
   const int entry_shift = iBarShift(_Symbol, PERIOD_D1, entry_time, false); // perf-allowed: one position-time lookup behind QM_IsNewBar().
   if(entry_shift >= strategy_max_hold_bars)
      g_exit_requested = true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return !Strategy_ConfigurationAuthorized();
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;
   if(g_signal_direction == 0 || g_signal_low <= 0.0 || g_signal_high <= 0.0)
      return false;

   const QM_OrderType side = (g_signal_direction > 0 ? QM_BUY : QM_SELL);
   const double entry = (g_signal_direction > 0
                         ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                         : SymbolInfoDouble(_Symbol, SYMBOL_BID));
   if(entry <= 0.0)
      return false;

   const double raw_sl = (g_signal_direction > 0 ? g_signal_low : g_signal_high);
   const double sl = QM_StopRulesNormalizePrice(_Symbol, raw_sl);
   if(sl <= 0.0)
      return false;
   if((g_signal_direction > 0 && sl >= entry) ||
      (g_signal_direction < 0 && sl <= entry))
      return false;

   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_rr_target);
   if(tp <= 0.0)
      return false;
   if((g_signal_direction > 0 && tp <= entry) ||
      (g_signal_direction < 0 && tp >= entry))
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = (g_signal_direction > 0
                 ? "midnight_hammer_adx_long"
                 : "midnight_shooting_star_adx_short");
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // No trailing, break-even, partial close, or stop mutation is authorized.
  }

bool Strategy_ExitSignal()
  {
   return (g_exit_requested &&
           QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0);
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
   // Q08 evidence must sample floating P&L before any per-tick guard returns.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Consume the closed-bar gate exactly once. State advances before exit
   // evaluation so the entry-day close is acted on at the next D1 open.
   const bool is_new_bar = QM_IsNewBar();
   if(is_new_bar)
      AdvanceState_OnNewBar();

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      bool close_succeeded = false;
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if(QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP))
            close_succeeded = true;
        }
      if(close_succeeded)
         g_exit_requested = false;
     }

   // Custom and central news checks gate entries only; management and exits
   // above remain active throughout news windows.
   if(Strategy_NewsFilterHook(broker_now))
      return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol,
                                        broker_now,
                                        qm_news_temporal,
                                        qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!is_new_bar)
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
