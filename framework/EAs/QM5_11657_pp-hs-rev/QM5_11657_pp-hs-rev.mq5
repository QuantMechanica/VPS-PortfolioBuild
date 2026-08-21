#property strict
#property version   "5.1"
#property description "QM5_11657 pp-hs-rev - PatternPy rolling H&S labels, H4"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA - QM5_11657 pp-hs-rev
// -----------------------------------------------------------------------------
// Approved card: docs/strategy_card.md
// Source: Keith Orange / keithorange, PatternPy,
//   tradingpatterns/tradingpatterns.py::detect_head_shoulder
//
// PatternPy labels dataframe row i from a three-row rolling high/low window
// and compares row i with both i-1 and i+1. The i+1 dependency is the source's
// shift(-1). To eliminate lookahead, this EA waits until i+1 has closed:
//
//   next_bar  = shift 1 = source row i+1 (confirmation)
//   label_bar = shift 2 = source row i
//   prior_bar = shift 3 = source row i-1
//   roll_start= shift 4 = source row i-2
//
// The rolling window is therefore shifts 4, 3, and 2. A source label confirmed
// by shift 1 enters at the current H4 bar open. The inverse assignment has
// precedence if both masks are true, matching the source's second dataframe
// assignment. Positions close on the opposite label or after 12 completed
// bars. ATR(14) at 2.0x is the card-authorized emergency stop. There is no
// take-profit, neckline reconstruction, swing scan, spread filter, trailing
// stop, grid, martingale, or ML.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 11657;
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
input int    strategy_window             = 3;    // PatternPy baseline; fixed
input int    strategy_atr_period         = 14;   // card emergency-stop period
input double strategy_sl_atr_mult        = 2.0;  // card seed; P3: 1.0..3.0
input int    strategy_max_hold_bars      = 12;   // card lifecycle; fixed

// Cached only after QM_IsNewBar() consumes a newly completed bar.
int    g_pattern_dir    = 0;     // +1 inverse H&S, -1 H&S, 0 no label
double g_signal_atr     = 0.0;
bool   g_exit_requested = false;

int Strategy_ExpectedSlot()
  {
   if(_Symbol == "EURUSD.DWX") return 0;
   if(_Symbol == "GBPUSD.DWX") return 1;
   if(_Symbol == "XAUUSD.DWX") return 2;
   if(_Symbol == "GDAXI.DWX")  return 3; // registry mapping for card GER40
   if(_Symbol == "NDX.DWX")    return 4;
   return -1;
  }

bool Strategy_ConfigurationAuthorized()
  {
   const int expected_slot = Strategy_ExpectedSlot();
   const bool authorized_period = ((ENUM_TIMEFRAMES)_Period == PERIOD_H1 ||
                                   (ENUM_TIMEFRAMES)_Period == PERIOD_H4 ||
                                   (ENUM_TIMEFRAMES)_Period == PERIOD_D1);
   return (qm_ea_id == 11657 &&
           expected_slot >= 0 &&
           qm_magic_slot_offset == expected_slot &&
           authorized_period &&
           strategy_window == 3 &&
           strategy_atr_period == 14 &&
           strategy_sl_atr_mult >= 1.0 &&
           strategy_sl_atr_mult <= 3.0 &&
           strategy_max_hold_bars == 12);
  }

// Translate PatternPy's detector literally on completed bars. The source first
// assigns H&S and then assigns inverse H&S, so inverse wins if both masks hold.
bool PatternPyDirection(int &direction)
  {
   direction = 0;
   if(strategy_window != 3)
      return false;

   MqlRates next_bar;
   MqlRates label_bar;
   MqlRates prior_bar;
   MqlRates roll_start;
   if(!QM_ReadBar(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, next_bar) ||
      !QM_ReadBar(_Symbol, (ENUM_TIMEFRAMES)_Period, 2, label_bar) ||
      !QM_ReadBar(_Symbol, (ENUM_TIMEFRAMES)_Period, 3, prior_bar) ||
      !QM_ReadBar(_Symbol, (ENUM_TIMEFRAMES)_Period, 4, roll_start))
      return false;

   if(next_bar.high <= 0.0 || next_bar.low <= 0.0 ||
      label_bar.high <= 0.0 || label_bar.low <= 0.0 ||
      prior_bar.high <= 0.0 || prior_bar.low <= 0.0 ||
      roll_start.high <= 0.0 || roll_start.low <= 0.0)
      return false;

   const double high_roll_max =
      MathMax(roll_start.high, MathMax(prior_bar.high, label_bar.high));
   const double low_roll_min =
      MathMin(roll_start.low, MathMin(prior_bar.low, label_bar.low));

   const bool head_shoulder =
      (high_roll_max > prior_bar.high) &&
      (high_roll_max > next_bar.high) &&
      (label_bar.high < prior_bar.high) &&
      (label_bar.high < next_bar.high);

   const bool inverse_head_shoulder =
      (low_roll_min < prior_bar.low) &&
      (low_roll_min < next_bar.low) &&
      (label_bar.low > prior_bar.low) &&
      (label_bar.low > next_bar.low);

   if(inverse_head_shoulder)
      direction = +1;
   else if(head_shoulder)
      direction = -1;

   return (direction != 0);
  }

// Compute the source label and all closed-bar exit state once per new bar.
void AdvanceState_OnNewBar()
  {
   g_pattern_dir = 0;
   g_signal_atr = 0.0;
   g_exit_requested = false;

   if(!Strategy_ConfigurationAuthorized())
      return;

   if(PatternPyDirection(g_pattern_dir))
      g_signal_atr = QM_ATR(_Symbol,
                            (ENUM_TIMEFRAMES)_Period,
                            strategy_atr_period,
                            1);

   const int magic = QM_FrameworkMagic();
   int matching_positions = 0;
   bool position_is_long = false;
   datetime opened_at = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ++matching_positions;
      position_is_long = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      opened_at = (datetime)PositionGetInteger(POSITION_TIME);
     }

   if(matching_positions <= 0)
      return;
   if(matching_positions != 1 || opened_at <= 0)
     {
      g_exit_requested = true;
      return;
     }

   if((position_is_long && g_pattern_dir < 0) ||
      (!position_is_long && g_pattern_dir > 0))
      g_exit_requested = true;

   // perf-allowed: one position-time lookup behind QM_IsNewBar(); no raw
   // warmup scan. At shift 12, twelve holding-period bars have completed.
   const int entry_shift = iBarShift(_Symbol,
                                     (ENUM_TIMEFRAMES)_Period,
                                     opened_at,
                                     false);
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
   if(g_pattern_dir == 0 || g_signal_atr <= 0.0)
      return false;

   const QM_OrderType side = (g_pattern_dir > 0 ? QM_BUY : QM_SELL);
   const double entry = (side == QM_BUY
                         ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                         : SymbolInfoDouble(_Symbol, SYMBOL_BID));
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol,
                                         side,
                                         entry,
                                         g_signal_atr,
                                         strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;
   if(side == QM_BUY && sl >= entry)
      return false;
   if(side == QM_SELL && sl <= entry)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0; // card authorizes no profit target
   req.reason = (side == QM_BUY ? "patternpy_inverse_hs"
                                : "patternpy_head_shoulders");
   req.symbol_slot = 0; // relative host slot resolved by QM_FrameworkInit
   req.expiration_seconds = 0;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // No break-even, trailing, partial close, add-on, or stop mutation.
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
   // Q08 evidence lifecycle: sample floating P&L before any guard can return.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(QM_FrameworkHandleFridayClose())
      return;
   if(Strategy_NoTradeFilter())
      return;

   // Consume the closed-bar gate once. The state update precedes exits so an
   // opposite label and the 12-bar lifecycle close are acted on immediately.
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
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         if(QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY))
            close_succeeded = true;
        }
      if(close_succeeded)
         g_exit_requested = false;
     }

   // News gates suppress new entries only; lifecycle exits above remain live.
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
      news_allows = QM_NewsAllowsTrade(_Symbol,
                                       broker_now,
                                       qm_news_mode_legacy);
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
