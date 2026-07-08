#property strict
#property version   "5.0"
#property description "QM5_9453 Chande CMO VR composite H4"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9453 - Chande VR-gated CMO trend breakout
// -----------------------------------------------------------------------------
// H4 price-only trend breakout:
//   1. Require VR = ATR(7) / ATR(28) above the trending threshold.
//   2. Trade CMO(14) crosses through +/-50 with same-bar direction confirm.
//   3. Reject single-bar blow-offs; exit on CMO zero-cross or time stop.
//
// Runtime uses MT5 OHLC only; no external feed, optimizer state, or ML.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 9453;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE60_POST60;
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
input int    strategy_cmo_period          = 14;
input int    strategy_vr_fast_atr         = 7;
input int    strategy_vr_slow_atr         = 28;
input double strategy_vr_min              = 1.30;
input double strategy_cmo_breakout_level  = 50.0;
input int    strategy_atr_period          = 14;
input double strategy_blowoff_atr_mult    = 2.0;
input double strategy_sl_atr_mult         = 1.0;
input int    strategy_time_stop_bars      = 16;
input double strategy_spread_atr_frac_max = 0.20;
input bool   strategy_shorts_enabled      = true;
input bool   strategy_whipsaw_guard       = true;

bool g_had_position = false;
int  g_last_position_direction = 0;
bool g_wait_zero_revisit = false;
int  g_wait_zero_direction = 0;

bool Strategy_CMO(const int shift, double &out_cmo)
  {
   out_cmo = 0.0;
   if(strategy_cmo_period <= 1 || shift < 1)
      return false;

   double sum_up = 0.0;
   double sum_down = 0.0;
   for(int i = shift; i < shift + strategy_cmo_period; ++i)
     {
      const double c0 = iClose(_Symbol, PERIOD_H4, i);     // perf-allowed: bounded Chande CMO close-to-close sum.
      const double c1 = iClose(_Symbol, PERIOD_H4, i + 1); // perf-allowed: bounded Chande CMO close-to-close sum.
      if(c0 <= 0.0 || c1 <= 0.0)
         return false;

      const double diff = c0 - c1;
      if(diff > 0.0)
         sum_up += diff;
      else
         sum_down -= diff;
     }

   const double denom = sum_up + sum_down;
   if(denom <= 0.0)
      return false;

   out_cmo = 100.0 * (sum_up - sum_down) / denom;
   return MathIsValidNumber(out_cmo);
  }

bool Strategy_HasOpenPosition()
  {
   return (QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0);
  }

int Strategy_PositionDirection(datetime &open_time)
  {
   open_time = 0;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return 0;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const long type = PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY)
         return 1;
      if(type == POSITION_TYPE_SELL)
         return -1;
     }

   return 0;
  }

bool Strategy_SpreadAllowed(const double atr)
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || atr <= 0.0)
      return false;

   if(ask > bid && strategy_spread_atr_frac_max > 0.0)
     {
      const double spread_price = ask - bid;
      if(spread_price > strategy_spread_atr_frac_max * atr)
         return false;
     }
   return true;
  }

void Strategy_UpdatePositionState()
  {
   datetime opened = 0;
   const int direction = Strategy_PositionDirection(opened);
   if(direction != 0)
     {
      g_had_position = true;
      g_last_position_direction = direction;
      return;
     }

   if(g_had_position)
     {
      g_had_position = false;
      if(strategy_whipsaw_guard && g_last_position_direction != 0)
        {
         g_wait_zero_revisit = true;
         g_wait_zero_direction = g_last_position_direction;
        }
      g_last_position_direction = 0;
     }
  }

bool Strategy_WhipsawGuardAllows(const double cmo_now)
  {
   if(!strategy_whipsaw_guard || !g_wait_zero_revisit)
      return true;

   if(g_wait_zero_direction > 0 && cmo_now <= 0.0)
     {
      g_wait_zero_revisit = false;
      g_wait_zero_direction = 0;
      return true;
     }
   if(g_wait_zero_direction < 0 && cmo_now >= 0.0)
     {
      g_wait_zero_revisit = false;
      g_wait_zero_direction = 0;
      return true;
     }

   return false;
  }

bool Strategy_BuildRequest(const QM_OrderType side,
                           const double atr,
                           QM_EntryRequest &req)
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double entry = QM_OrderTypeIsBuy(side) ? ask : bid;
   if(entry <= 0.0 || atr <= 0.0)
      return false;

   double sl = 0.0;
   if(QM_OrderTypeIsBuy(side))
      sl = entry - strategy_sl_atr_mult * atr;
   else
      sl = entry + strategy_sl_atr_mult * atr;

   sl = QM_StopRulesNormalizePrice(_Symbol, sl);
   if(QM_OrderTypeIsBuy(side) && (sl <= 0.0 || sl >= entry))
      return false;
   if(!QM_OrderTypeIsBuy(side) && sl <= entry)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = QM_OrderTypeIsBuy(side) ? "QM5_9453_CMO_VR_BREAKOUT_LONG"
                                        : "QM5_9453_CMO_VR_BREAKOUT_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_H4)
      return true;
   if(qm_magic_slot_offset < 0)
      return true;
   if(strategy_cmo_period <= 1)
      return true;
   if(strategy_vr_fast_atr <= 0 || strategy_vr_slow_atr <= strategy_vr_fast_atr)
      return true;
   if(strategy_vr_min <= 0.0)
      return true;
   if(strategy_cmo_breakout_level <= 0.0 || strategy_cmo_breakout_level >= 100.0)
      return true;
   if(strategy_atr_period <= 0 || strategy_blowoff_atr_mult <= 0.0)
      return true;
   if(strategy_sl_atr_mult <= 0.0 || strategy_time_stop_bars <= 0)
      return true;
   if(strategy_spread_atr_frac_max < 0.0)
      return true;

   const int warmup = MathMax(strategy_cmo_period + 3,
                              MathMax(strategy_vr_slow_atr, strategy_atr_period) + 3);
   if(Bars(_Symbol, PERIOD_H4) < warmup) // perf-allowed: O(1) H4 warm-up availability check.
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

   if(Strategy_HasOpenPosition())
      return false;

   const double atr_fast = QM_ATR(_Symbol, PERIOD_H4, strategy_vr_fast_atr, 1);
   const double atr_slow = QM_ATR(_Symbol, PERIOD_H4, strategy_vr_slow_atr, 1);
   const double atr_entry = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double atr_prior = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 2);
   if(atr_fast <= 0.0 || atr_slow <= 0.0 || atr_entry <= 0.0 || atr_prior <= 0.0)
      return false;

   const double vr = atr_fast / atr_slow;
   if(vr <= strategy_vr_min)
      return false;
   if(!Strategy_SpreadAllowed(atr_entry))
      return false;

   double cmo_now = 0.0;
   double cmo_prev = 0.0;
   if(!Strategy_CMO(1, cmo_now) || !Strategy_CMO(2, cmo_prev))
      return false;
   if(!Strategy_WhipsawGuardAllows(cmo_now))
      return false;

   const double open_now = iOpen(_Symbol, PERIOD_H4, 1);     // perf-allowed: fixed closed trigger bar.
   const double close_now = iClose(_Symbol, PERIOD_H4, 1);   // perf-allowed: fixed closed trigger bar.
   const double close_prev = iClose(_Symbol, PERIOD_H4, 2);  // perf-allowed: fixed prior closed bar.
   if(open_now <= 0.0 || close_now <= 0.0 || close_prev <= 0.0)
      return false;

   const double trigger_move = MathAbs(close_now - close_prev);
   if(trigger_move > strategy_blowoff_atr_mult * atr_prior)
      return false;

   const bool long_cross = (cmo_prev <= strategy_cmo_breakout_level &&
                            cmo_now > strategy_cmo_breakout_level &&
                            close_now > open_now);
   if(long_cross)
      return Strategy_BuildRequest(QM_BUY, atr_entry, req);

   const bool short_cross = (strategy_shorts_enabled &&
                             cmo_prev >= -strategy_cmo_breakout_level &&
                             cmo_now < -strategy_cmo_breakout_level &&
                             close_now < open_now);
   if(short_cross)
      return Strategy_BuildRequest(QM_SELL, atr_entry, req);

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   Strategy_UpdatePositionState();
  }

bool Strategy_ExitSignal()
  {
   datetime open_time = 0;
   const int direction = Strategy_PositionDirection(open_time);
   if(direction == 0)
      return false;

   const int h4_seconds = PeriodSeconds(PERIOD_H4);
   if(h4_seconds > 0 && open_time > 0 &&
      TimeCurrent() - open_time >= strategy_time_stop_bars * h4_seconds)
      return true;

   double cmo_now = 0.0;
   double cmo_prev = 0.0;
   if(!Strategy_CMO(1, cmo_now) || !Strategy_CMO(2, cmo_prev))
      return false;

   if(direction > 0 && cmo_prev > 0.0 && cmo_now <= 0.0)
      return true;
   if(direction < 0 && cmo_prev < 0.0 && cmo_now >= 0.0)
      return true;

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

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
                        60,
                        60,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_9453\",\"ea\":\"chande-cmo-vr-composite-h4\"}");
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

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
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
