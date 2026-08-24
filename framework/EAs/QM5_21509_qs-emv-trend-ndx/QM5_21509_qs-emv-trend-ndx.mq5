#property strict
#property version   "5.0"
#property description "QM5_21509 NDX Ease of Movement Trend Confirmation"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_21509 - NDX Ease of Movement Trend Confirmation
// -----------------------------------------------------------------------------
// Mechanical card translation:
//   - Native NDX.DWX D1 OHLC and tick volume only; no external feed or ML.
//   - EMV is midpoint movement divided by the volume/range box ratio.
//   - Long: smoothed EMV crosses above zero while Close[1] > SMA trend.
//   - Short: smoothed EMV crosses below zero while Close[1] < SMA trend.
//   - Fixed ATR hard stop, trend-failure exit, and completed-D1-bar time stop.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 21509;
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
input int    strategy_emv_smooth_period   = 14;
input double strategy_volume_divisor      = 10000.0;
input int    strategy_trend_period        = 50;
input int    strategy_atr_period          = 14;
input double strategy_atr_sl_mult         = 2.5;
input int    strategy_max_hold_bars       = 50;
input int    strategy_max_spread_points   = 500;

// Cached once-per-completed-D1-bar state. Per-tick hooks read only these values.
bool   g_state_valid       = false;
double g_emv_1             = 0.0;
double g_emv_2             = 0.0;
double g_close_1           = 0.0;
double g_trend_sma_1       = 0.0;
double g_atr_1             = 0.0;
ulong  g_exit_ticket       = 0;

bool Strategy_FindOwnedPosition(ulong &ticket,
                                ENUM_POSITION_TYPE &position_type,
                                datetime &opened_at)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   opened_at = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      ticket = candidate;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

// Read one raw EMV observation from a bounded closed-bar array. A zero-range or
// zero-volume bar is a valid "no update" observation, as required by the card.
bool Strategy_RawEmvAt(const MqlRates &rates[],
                       const int index,
                       double &raw_emv,
                       bool &has_update)
  {
   raw_emv = 0.0;
   has_update = false;

   const int count = ArraySize(rates);
   if(index < 0 || index >= count || index + 1 >= count)
      return false;

   const double high_now = rates[index].high;
   const double low_now = rates[index].low;
   const double high_prior = rates[index + 1].high;
   const double low_prior = rates[index + 1].low;
   const long tick_volume = rates[index].tick_volume;

   const double range = high_now - low_now;
   if(range <= 0.0 || tick_volume <= 0)
      return true;

   const double midpoint_now = 0.5 * (high_now + low_now);
   const double midpoint_prior = 0.5 * (high_prior + low_prior);
   const double box_ratio = ((double)tick_volume / strategy_volume_divisor) / range;
   if(box_ratio == 0.0 || !MathIsValidNumber(box_ratio))
      return false;

   raw_emv = (midpoint_now - midpoint_prior) / box_ratio;
   if(!MathIsValidNumber(raw_emv))
      return false;

   has_update = true;
   return true;
  }

// SMA of the most recent N valid raw observations. Invalid volume/range bars do
// not advance the window, which mechanically carries the prior smoothed value.
bool Strategy_SmoothedEmvAt(const MqlRates &rates[],
                            const int target_index,
                            const int period,
                            double &smoothed_emv)
  {
   smoothed_emv = 0.0;
   const int count = ArraySize(rates);
   if(period < 1 || target_index < 0 || target_index >= count)
      return false;

   double total = 0.0;
   int samples = 0;
   for(int index = target_index;
       index >= 0 && index + 1 < count && samples < period;
       ++index)
     {
      double raw_emv = 0.0;
      bool has_update = false;
      if(!Strategy_RawEmvAt(rates, index, raw_emv, has_update))
         return false;
      if(!has_update)
         continue;

      total += raw_emv;
      samples++;
     }

   if(samples != period)
      return false;

   smoothed_emv = total / (double)period;
   return MathIsValidNumber(smoothed_emv);
  }

void AdvanceState_OnNewBar()
  {
   g_state_valid = false;
   g_emv_1 = 0.0;
   g_emv_2 = 0.0;
   g_close_1 = 0.0;
   g_trend_sma_1 = 0.0;
   g_atr_1 = 0.0;
   g_exit_ticket = 0;

   ulong owned_ticket = 0;
   ENUM_POSITION_TYPE owned_type = POSITION_TYPE_BUY;
   datetime opened_at = 0;
   const bool have_position = Strategy_FindOwnedPosition(owned_ticket, owned_type, opened_at);

   // perf-allowed: one restart-safe completed-D1-bar age lookup, reached only
   // from the framework QM_IsNewBar gate; there is no QM bar-age helper.
   if(have_position && opened_at > 0 && strategy_max_hold_bars > 0)
     {
      const int completed_bars = iBarShift(_Symbol, PERIOD_D1, opened_at, false); // perf-allowed: once per new D1 bar for restart-safe holding age
      if(completed_bars >= strategy_max_hold_bars)
         g_exit_ticket = owned_ticket;
     }

   if(strategy_emv_smooth_period < 2 || strategy_emv_smooth_period > 500 ||
      strategy_trend_period < 2 || strategy_trend_period > 1000 ||
      strategy_atr_period < 2 || strategy_volume_divisor <= 0.0)
      return;

   const int history_required = strategy_trend_period + strategy_emv_smooth_period + 5;
   if(history_required < 9 || history_required > 1505)
      return;

   MqlRates rates[];
   ArrayResize(rates, history_required);
   ArraySetAsSeries(rates, true);
   // perf-allowed: bounded D1 OHLC/tick-volume vector required for bespoke EMV,
   // called exactly once from the framework new-bar path.
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, history_required, rates); // perf-allowed: bounded cache refresh once per new D1 bar
   if(copied < history_required || ArraySize(rates) < history_required)
      return;
   if(ArraySize(rates) <= 0)
      return;

   g_close_1 = rates[0].close;
   if(g_close_1 <= 0.0 || !MathIsValidNumber(g_close_1))
      return;

   if(!Strategy_SmoothedEmvAt(rates, 0, strategy_emv_smooth_period, g_emv_1))
      return;
   if(!Strategy_SmoothedEmvAt(rates, 1, strategy_emv_smooth_period, g_emv_2))
      return;

   g_trend_sma_1 = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_period, 1, PRICE_CLOSE);
   g_atr_1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(g_trend_sma_1 <= 0.0 || !MathIsValidNumber(g_trend_sma_1) ||
      g_atr_1 <= 0.0 || !MathIsValidNumber(g_atr_1))
      return;

   g_state_valid = true;

   if(have_position && g_exit_ticket == 0)
     {
      if(owned_type == POSITION_TYPE_BUY && g_close_1 < g_trend_sma_1)
         g_exit_ticket = owned_ticket;
      else if(owned_type == POSITION_TYPE_SELL && g_close_1 > g_trend_sma_1)
         g_exit_ticket = owned_ticket;
      else if(owned_type != POSITION_TYPE_BUY && owned_type != POSITION_TYPE_SELL)
         g_exit_ticket = owned_ticket;
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   if(_Symbol != "NDX.DWX" || _Period != PERIOD_D1)
      return true;
   if(qm_ea_id != 21509 || qm_magic_slot_offset != 0)
      return true;
   if(strategy_emv_smooth_period < 2 || strategy_emv_smooth_period > 500)
      return true;
   if(strategy_volume_divisor <= 0.0)
      return true;
   if(strategy_trend_period < 2 || strategy_trend_period > 1000)
      return true;
   if(strategy_atr_period < 2 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_max_hold_bars < 1 || strategy_max_spread_points < 1)
      return true;
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

   if(!g_state_valid)
      return false;

   const bool long_signal = (g_emv_2 <= 0.0 && g_emv_1 > 0.0 &&
                             g_close_1 > g_trend_sma_1);
   const bool short_signal = (g_emv_2 >= 0.0 && g_emv_1 < 0.0 &&
                              g_close_1 < g_trend_sma_1);
   if(!long_signal && !short_signal)
      return false;

   ulong owned_ticket = 0;
   ENUM_POSITION_TYPE owned_type = POSITION_TYPE_BUY;
   datetime opened_at = 0;
   if(Strategy_FindOwnedPosition(owned_ticket, owned_type, opened_at))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;
   // .DWX Model-4 runs can legitimately model zero spread. Only reject a
   // genuinely positive spread above the card's cap.
   if(ask > bid && (ask - bid) / point > (double)strategy_max_spread_points)
      return false;

   req.type = long_signal ? QM_BUY : QM_SELL;
   const double entry_price = long_signal ? ask : bid;
   req.sl = QM_StopATRFromValue(_Symbol,
                                req.type,
                                entry_price,
                                g_atr_1,
                                strategy_atr_sl_mult);
   req.sl = QM_StopRulesNormalizePrice(_Symbol, req.sl);
   if(req.sl <= 0.0 || !MathIsValidNumber(req.sl))
      return false;
   if(req.type == QM_BUY && req.sl >= entry_price)
      return false;
   if(req.type == QM_SELL && req.sl <= entry_price)
      return false;

   req.tp = 0.0;
   req.reason = long_signal ? "EMV_ZERO_CROSS_LONG" : "EMV_ZERO_CROSS_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card v1 has no trailing stop, break-even, take-profit, or partial close.
  }

bool Strategy_ExitSignal()
  {
   if(g_exit_ticket == 0)
      return false;

   ulong owned_ticket = 0;
   ENUM_POSITION_TYPE owned_type = POSITION_TYPE_BUY;
   datetime opened_at = 0;
   if(!Strategy_FindOwnedPosition(owned_ticket, owned_type, opened_at))
      return false;

   // Bind the signal to the position observed during the new-bar refresh. If
   // that position was closed and replaced, the replacement must not inherit it.
   return (owned_ticket == g_exit_ticket);
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
   g_exit_ticket = 0;
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_21509\",\"ea\":\"qs-emv-trend-ndx\"}");
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

   // Management and an already-latched exit remain active on every tick and
   // are deliberately above the entry-only news gate.
   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(ticket != g_exit_ticket || PositionGetString(POSITION_SYMBOL) != _Symbol)
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

   // Apply trend/time exits from the freshly completed D1 bar before a new
   // signal can enter. Entry stays fail-closed while the old ticket remains.
   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(ticket != g_exit_ticket || PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

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
