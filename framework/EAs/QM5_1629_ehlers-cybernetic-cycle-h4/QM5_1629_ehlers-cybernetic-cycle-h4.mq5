#property strict
#property version   "5.0"
#property description "QM5_1629 Ehlers Cybernetic Cycle H4"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_1629
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1629;
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
input double strategy_alpha                = 0.07;
input int    strategy_amplitude_window     = 20;
input double strategy_amplitude_threshold  = 0.005; // 0.5% of price
input int    strategy_d1_sma_period        = 200;
input int    strategy_atr_period           = 14;
input double strategy_sl_atr_mult          = 2.0;
input double strategy_tp_atr_mult          = 2.0;
input double strategy_be_trigger_atr_mult  = 1.0;
input int    strategy_time_stop_bars       = 20;
input double strategy_spread_atr_mult      = 0.3;
input int    strategy_cooldown_bars        = 4;

// -----------------------------------------------------------------------------
// State variables
// -----------------------------------------------------------------------------
bool          g_be_done               = false;
QM_ExitReason g_strategy_exit_reason  = QM_EXIT_STRATEGY;
datetime      g_last_trade_time       = 0;
int           g_last_trade_dir        = 0;

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------
bool LoadRates(const ENUM_TIMEFRAMES tf, const int bars_needed, MqlRates &rates[])
{
   if(bars_needed <= 0 || bars_needed > 200)
      return false;
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, tf, 0, bars_needed, rates); // perf-allowed: bounded bespoke cycle filter arithmetic
   ArraySetAsSeries(rates, true);
   return (copied >= bars_needed && ArraySize(rates) >= bars_needed);
}

bool ComputeCyberneticCycle(MqlRates &rates[], const int count, double &cycle_curr, double &cycle_prev, double &amp_out)
{
   if(count < 20 || count > 200 || ArraySize(rates) < count)
      return false;

   double smooth[256];
   double cycle[256];
   if(ArraySize(smooth) < count || ArraySize(cycle) < count)
      return false;
   ArrayInitialize(smooth, 0.0);
   ArrayInitialize(cycle, 0.0);

   for(int i = count - 4; i >= 0; --i)
   {
      const double p0 = rates[i].close;
      const double p1 = rates[i + 1].close;
      const double p2 = rates[i + 2].close;
      const double p3 = rates[i + 3].close;
      smooth[i] = (p0 + 2.0 * p1 + 2.0 * p2 + p3) / 6.0;
   }

   const double a = strategy_alpha;
   const double c1 = (1.0 - 0.5 * a) * (1.0 - 0.5 * a);
   const double c2 = 2.0 * (1.0 - a);
   const double c3 = (1.0 - a) * (1.0 - a);

   for(int i = count - 6; i >= 0; --i)
   {
      const double diff = smooth[i] - 2.0 * smooth[i + 1] + smooth[i + 2];
      if(i >= count - 8)
         cycle[i] = diff / 4.0;
      else
         cycle[i] = c1 * diff + c2 * cycle[i + 1] - c3 * cycle[i + 2];
   }

   cycle_curr = cycle[1];
   cycle_prev = cycle[2];

   double max_amp = 0.0;
   for(int k = 1; k <= strategy_amplitude_window && k < count; ++k)
   {
      const double amp = MathAbs(cycle[k]);
      if(amp > max_amp)
         max_amp = amp;
   }
   amp_out = max_amp;
   return true;
}

bool SpreadAllows(const double atr_value)
{
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return false;
   const double spread = ask - bid;
   if(spread < DBL_EPSILON)
      return true;
   if(atr_value <= 0.0)
      return true;
   return (spread <= strategy_spread_atr_mult * atr_value);
}

bool CooldownAllows(const int direction)
{
   if(strategy_cooldown_bars <= 0 || g_last_trade_dir != direction || g_last_trade_time <= 0)
      return true;

   const int bars_since_entry = iBarShift(_Symbol, PERIOD_H4, g_last_trade_time, false); // perf-allowed: one bounded H4 history lookup per closed-bar entry evaluation
   if(bars_since_entry < 0)
      return false;
   return (bars_since_entry >= strategy_cooldown_bars);
}

bool TimeStopReached(const datetime opened)
{
   if(opened <= 0 || strategy_time_stop_bars < 1)
      return false;

   const int opened_bar_shift = iBarShift(_Symbol, PERIOD_H4, opened, false); // perf-allowed: one bounded H4 history lookup while managing one open position
   if(opened_bar_shift < 0)
      return false;
   return (opened_bar_shift >= strategy_time_stop_bars);
}

bool BreakEvenPlusSpreadTarget(const ENUM_POSITION_TYPE position_type,
                               const double open_price,
                               const double current_sl,
                               double &target_sl)
{
   target_sl = 0.0;
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(open_price <= 0.0 || bid <= 0.0 || ask <= bid || point <= 0.0)
      return false;

   const bool is_buy = (position_type == POSITION_TYPE_BUY);
   const double spread = ask - bid;
   const double raw_target = is_buy ? (open_price + spread) : (open_price - spread);
   target_sl = QM_TM_NormalizePrice(_Symbol, raw_target);
   if(target_sl <= 0.0)
      return false;

   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const int freeze_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   const double broker_distance = MathMax(stops_level, freeze_level) * point;
   if(is_buy && target_sl > bid - broker_distance)
      return false;
   if(!is_buy && target_sl < ask + broker_distance)
      return false;

   if(current_sl > 0.0)
   {
      const bool improves = is_buy ? (target_sl > current_sl + point * 0.5)
                                   : (target_sl < current_sl - point * 0.5);
      if(!improves)
         return false;
   }
   return true;
}

bool SelectOurPosition(ulong &ticket, ENUM_POSITION_TYPE &position_type)
{
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong cand = PositionGetTicket(i);
      if(cand == 0 || !PositionSelectByTicket(cand))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      ticket = cand;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
   }
   return false;
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------
bool Strategy_NoTradeFilter()
{
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

   if(strategy_alpha <= 0.0 || strategy_amplitude_window < 2 || strategy_atr_period < 2)
      return false;

   const int bars_needed = strategy_amplitude_window + 120;
   MqlRates h4[];
   if(!LoadRates(PERIOD_H4, bars_needed, h4))
      return false;

   double cycle_curr = 0.0;
   double cycle_prev = 0.0;
   double amp = 0.0;
   if(!ComputeCyberneticCycle(h4, bars_needed, cycle_curr, cycle_prev, amp))
      return false;

   const bool cross_up = (cycle_prev < 0.0 && cycle_curr >= 0.0);
   const bool cross_dn = (cycle_prev > 0.0 && cycle_curr <= 0.0);
   if(!cross_up && !cross_dn)
      return false;

   if(amp <= strategy_amplitude_threshold * h4[1].close)
      return false;

   const double d1_close = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: one closed D1 regime read per H4 entry evaluation
   const double d1_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_d1_sma_period, 1, PRICE_CLOSE);
   if(d1_close <= 0.0 || d1_sma <= 0.0)
      return false;

   if(cross_up && d1_close <= d1_sma)
      return false;
   if(cross_dn && d1_close >= d1_sma)
      return false;

   const int dir = cross_up ? 1 : -1;
   if(!CooldownAllows(dir))
      return false;

   const double atr_value = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   if(!SpreadAllows(atr_value))
      return false;

   req.type = cross_up ? QM_BUY : QM_SELL;
   const double entry = cross_up ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry, atr_value, strategy_sl_atr_mult);
   req.tp = QM_TakeATRFromValue(_Symbol, req.type, entry, atr_value, strategy_tp_atr_mult);
   req.reason = cross_up ? "CYBERNETIC_CYCLE_BULL_CROSS" : "CYBERNETIC_CYCLE_BEAR_CROSS";

   if(req.sl <= 0.0)
      return false;

   return true;
}

void Strategy_ManageOpenPosition()
{
   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   if(!SelectOurPosition(ticket, position_type))
   {
      g_be_done = false;
      return;
   }

   if(g_be_done)
      return;

   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double sl_price = PositionGetDouble(POSITION_SL);
   if(open_price <= 0.0 || sl_price <= 0.0)
      return;

   const double atr_distance = MathAbs(open_price - sl_price) / strategy_sl_atr_mult;
   if(atr_distance <= 0.0)
      return;

   const bool is_buy = (position_type == POSITION_TYPE_BUY);
   const double trigger_price = is_buy ? (open_price + strategy_be_trigger_atr_mult * atr_distance)
                                       : (open_price - strategy_be_trigger_atr_mult * atr_distance);
   const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                      : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(market_price <= 0.0)
      return;

   const bool hit_trigger = is_buy ? (market_price >= trigger_price) : (market_price <= trigger_price);
   if(hit_trigger)
   {
      double target_sl = 0.0;
      if(BreakEvenPlusSpreadTarget(position_type, open_price, sl_price, target_sl) &&
         QM_TM_MoveSL(ticket, target_sl, "MOVE_TO_BE_PLUS_SPREAD"))
         g_be_done = true;
   }
}

bool Strategy_ExitSignal()
{
   g_strategy_exit_reason = QM_EXIT_STRATEGY;

   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   if(!SelectOurPosition(ticket, position_type))
      return false;

   const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
   if(TimeStopReached(opened))
   {
      g_strategy_exit_reason = QM_EXIT_TIME_STOP;
      return true;
   }

   const int bars_needed = strategy_amplitude_window + 120;
   MqlRates h4[];
   if(!LoadRates(PERIOD_H4, bars_needed, h4))
      return false;

   double cycle_curr = 0.0;
   double cycle_prev = 0.0;
   double amp = 0.0;
   if(!ComputeCyberneticCycle(h4, bars_needed, cycle_curr, cycle_prev, amp))
      return false;

   const bool cross_up = (cycle_prev < 0.0 && cycle_curr >= 0.0);
   const bool cross_dn = (cycle_prev > 0.0 && cycle_curr <= 0.0);
   const bool strong = (amp > strategy_amplitude_threshold * h4[1].close);

   const bool is_buy = (position_type == POSITION_TYPE_BUY);
   if(is_buy && cross_dn && strong)
   {
      g_strategy_exit_reason = QM_EXIT_OPPOSITE_SIGNAL;
      return true;
   }
   if(!is_buy && cross_up && strong)
   {
      g_strategy_exit_reason = QM_EXIT_OPPOSITE_SIGNAL;
      return true;
   }

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

   if(!QM_FrameworkDeclareExecutionContract(PERIOD_H4,
                                             QM_FRIDAY_CLOSE_FRAMEWORK_OVERRIDE,
                                             "FRAMEWORK_WEEKEND_RISK_OVERLAY"))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1629_ehlers-cybernetic-cycle-h4\"}");
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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, g_strategy_exit_reason);
      }
   }

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar(_Symbol, PERIOD_H4))
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
   if(Strategy_EntrySignal(req))
   {
      ulong out_ticket = 0;
      if(QM_TM_OpenPosition(req, out_ticket))
      {
         g_last_trade_time = iTime(_Symbol, PERIOD_H4, 0); // perf-allowed: confirmed-entry cooldown bookkeeping
         g_last_trade_dir = (req.type == QM_BUY) ? 1 : -1;
         g_be_done = false;
      }
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

