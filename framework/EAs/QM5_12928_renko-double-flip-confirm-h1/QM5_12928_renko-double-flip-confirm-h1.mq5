#property strict
#property version   "5.0"
#property description "QM5_12928 Renko Double-Flip Confirmation (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_12928
// Strategy: Renko Double-Flip Confirmation (H1)
// Source: Steve Nison 1994 / ForexFactory Renko cluster
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12928;
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
input int    strategy_atr_period        = 14;
input double strategy_brick_atr_mult    = 0.5;
input int    strategy_reversal_rule     = 2;
input double strategy_tp_brick_mult     = 3.0;
input double strategy_sl_brick_mult     = 2.0;
input int    strategy_trail_brick_threshold = 2;
input int    strategy_time_stop_bars    = 48;
input double strategy_max_spread_mult   = 1.5;

// -----------------------------------------------------------------------------
// State tracking
// -----------------------------------------------------------------------------
double   g_brick_size                   = 0.0;
double   g_last_brick_close             = 0.0;
int      g_last_block_color             = 0;  // +1 = bullish, -1 = bearish, 0 = uninitialized
int      g_second_last_block_color      = 0;
int      g_third_last_block_color       = 0;
int      g_last_week_key                = -1;

bool     g_signal_buy                   = false;
bool     g_signal_sell                  = false;
bool     g_rearm_buy                    = true;
bool     g_rearm_sell                   = true;

int      g_favorable_bricks_since_entry = 0;
int      g_bars_held                    = 0;
datetime g_entry_bar_time               = 0;
int      g_pos_direction                = 0;  // +1 long, -1 short, 0 none

// Spread tracking for median spread
#define SPREAD_HISTORY_SIZE 20
int      g_spread_history[SPREAD_HISTORY_SIZE];
int      g_spread_count                 = 0;

void UpdateSpreadHistory()
{
   const int current_spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread < 0) return;
   
   if(g_spread_count < SPREAD_HISTORY_SIZE)
   {
      g_spread_history[g_spread_count] = current_spread;
      g_spread_count++;
   }
   else
   {
      for(int i = 0; i < SPREAD_HISTORY_SIZE - 1; ++i)
         g_spread_history[i] = g_spread_history[i + 1];
      g_spread_history[SPREAD_HISTORY_SIZE - 1] = current_spread;
   }
}

double GetMedianSpread()
{
   if(g_spread_count == 0) return 0.0;
   int temp[SPREAD_HISTORY_SIZE];
   ArrayCopy(temp, g_spread_history, 0, 0, g_spread_count);
   ArraySort(temp);
   return (double)temp[g_spread_count / 2];
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   UpdateSpreadHistory();
   if(g_spread_count >= 10 && strategy_max_spread_mult > 0.0)
   {
      const double median_sp = GetMedianSpread();
      const double current_sp = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(median_sp > 0.0 && current_sp > 0.0 && current_sp > strategy_max_spread_mult * median_sp)
         return true; // spread filter blocks genuinely wide spread
   }
   return false;
}

void UpdateRenkoState(const double close_price)
{
   const double pip_val = (_Digits == 3 || _Digits == 5) ? 10.0 * _Point : _Point;
   
   // Check weekly brick refresh
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const int week_key = dt.year * 100 + (dt.day_of_year / 7);
   if(week_key != g_last_week_key || g_brick_size <= 0.0)
   {
      const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
      if(atr > 0.0)
      {
         int brick_pips = (int)MathRound((atr * strategy_brick_atr_mult) / pip_val);
         if(brick_pips < 1) brick_pips = 1;
         g_brick_size = brick_pips * pip_val;
         g_last_week_key = week_key;
      }
      else if(g_brick_size <= 0.0)
      {
         g_brick_size = 10.0 * pip_val;
      }
   }
   
   if(g_brick_size <= 0.0) return;
   
   if(g_last_brick_close == 0.0)
   {
      g_last_brick_close = close_price;
      return;
   }
   
   g_signal_buy = false;
   g_signal_sell = false;
   
   if(g_last_block_color == 0)
   {
      if(close_price >= g_last_brick_close + g_brick_size)
      {
         g_last_block_color = 1;
         g_last_brick_close += g_brick_size;
      }
      else if(close_price <= g_last_brick_close - g_brick_size)
      {
         g_last_block_color = -1;
         g_last_brick_close -= g_brick_size;
      }
      return;
   }
   
   if(g_last_block_color == 1)
   {
      // Bullish continuation
      if(close_price >= g_last_brick_close + g_brick_size)
      {
         int num_bricks = (int)MathFloor((close_price - g_last_brick_close) / g_brick_size);
         for(int b = 0; b < num_bricks; ++b)
         {
            g_third_last_block_color = g_second_last_block_color;
            g_second_last_block_color = g_last_block_color;
            g_last_block_color = 1;
            g_last_brick_close += g_brick_size;
            
            if(g_pos_direction == 1)
               g_favorable_bricks_since_entry++;
            
            g_rearm_sell = true; // opposite brick printed for short re-arm
            
            if(g_last_block_color == 1 && g_second_last_block_color == 1 && g_third_last_block_color == -1 && g_rearm_buy)
            {
               g_signal_buy = true;
            }
         }
      }
      // Bearish reversal (requires 2 * brick_size)
      else if(close_price <= g_last_brick_close - (double)strategy_reversal_rule * g_brick_size)
      {
         g_third_last_block_color = g_second_last_block_color;
         g_second_last_block_color = g_last_block_color;
         g_last_block_color = -1;
         g_last_brick_close -= (double)strategy_reversal_rule * g_brick_size;
         
         if(g_pos_direction == -1)
            g_favorable_bricks_since_entry++;
         
         g_rearm_buy = true; // opposite brick printed for long re-arm
         
         int extra = (int)MathFloor((g_last_brick_close - close_price) / g_brick_size);
         for(int b = 0; b < extra; ++b)
         {
            g_third_last_block_color = g_second_last_block_color;
            g_second_last_block_color = g_last_block_color;
            g_last_block_color = -1;
            g_last_brick_close -= g_brick_size;
            if(g_pos_direction == -1)
               g_favorable_bricks_since_entry++;
         }
      }
   }
   else if(g_last_block_color == -1)
   {
      // Bearish continuation
      if(close_price <= g_last_brick_close - g_brick_size)
      {
         int num_bricks = (int)MathFloor((g_last_brick_close - close_price) / g_brick_size);
         for(int b = 0; b < num_bricks; ++b)
         {
            g_third_last_block_color = g_second_last_block_color;
            g_second_last_block_color = g_last_block_color;
            g_last_block_color = -1;
            g_last_brick_close -= g_brick_size;
            
            if(g_pos_direction == -1)
               g_favorable_bricks_since_entry++;
            
            g_rearm_buy = true; // opposite brick printed for long re-arm
            
            if(g_last_block_color == -1 && g_second_last_block_color == -1 && g_third_last_block_color == 1 && g_rearm_sell)
            {
               g_signal_sell = true;
            }
         }
      }
      // Bullish reversal (requires 2 * brick_size)
      else if(close_price >= g_last_brick_close + (double)strategy_reversal_rule * g_brick_size)
      {
         g_third_last_block_color = g_second_last_block_color;
         g_second_last_block_color = g_last_block_color;
         g_last_block_color = 1;
         g_last_brick_close += (double)strategy_reversal_rule * g_brick_size;
         
         if(g_pos_direction == 1)
            g_favorable_bricks_since_entry++;
         
         g_rearm_sell = true; // opposite brick printed for short re-arm
         
         int extra = (int)MathFloor((close_price - g_last_brick_close) / g_brick_size);
         for(int b = 0; b < extra; ++b)
         {
            g_third_last_block_color = g_second_last_block_color;
            g_second_last_block_color = g_last_block_color;
            g_last_block_color = 1;
            g_last_brick_close += g_brick_size;
            if(g_pos_direction == 1)
               g_favorable_bricks_since_entry++;
         }
      }
   }
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

   const double c = iClose(_Symbol, PERIOD_H1, 1); // perf-allowed: single closed H1 bar entry reference.
   if(c <= 0.0) return false;

   UpdateRenkoState(c);

   // Check if already open position
   const int magic = QM_FrameworkMagic();
   int open_pos_count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) == magic && PositionGetString(POSITION_SYMBOL) == _Symbol)
      {
         open_pos_count++;
      }
   }
   
   if(open_pos_count > 0)
   {
      g_bars_held++;
      return false;
   }
   else
   {
      g_pos_direction = 0;
      g_bars_held = 0;
      g_favorable_bricks_since_entry = 0;
   }

   if(g_brick_size <= 0.0) return false;

   if(g_signal_buy)
   {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = c - strategy_sl_brick_mult * g_brick_size;
      req.tp = c + strategy_tp_brick_mult * g_brick_size;
      req.reason = "RENKO_DOUBLE_BULL_FLIP";
      req.symbol_slot = qm_magic_slot_offset;
      g_pos_direction = 1;
      g_bars_held = 0;
      g_favorable_bricks_since_entry = 0;
      g_rearm_buy = false;
      return true;
   }
   
   if(g_signal_sell)
   {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = c + strategy_sl_brick_mult * g_brick_size;
      req.tp = c - strategy_tp_brick_mult * g_brick_size;
      req.reason = "RENKO_DOUBLE_BEAR_FLIP";
      req.symbol_slot = qm_magic_slot_offset;
      g_pos_direction = -1;
      g_bars_held = 0;
      g_favorable_bricks_since_entry = 0;
      g_rearm_sell = false;
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic || PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      
      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double current_sl = PositionGetDouble(POSITION_SL);
      
      if(g_favorable_bricks_since_entry >= strategy_trail_brick_threshold && g_brick_size > 0.0)
      {
         if(pos_type == POSITION_TYPE_BUY)
         {
            const double new_sl = g_last_brick_close - g_brick_size;
            if(new_sl > current_sl + _Point)
            {
               QM_TM_MoveSL(ticket, new_sl, "RENKO_TRAIL_BRICK");
            }
         }
         else if(pos_type == POSITION_TYPE_SELL)
         {
            const double new_sl = g_last_brick_close + g_brick_size;
            if(current_sl <= 0.0 || new_sl < current_sl - _Point)
            {
               QM_TM_MoveSL(ticket, new_sl, "RENKO_TRAIL_BRICK");
            }
         }
      }
   }
}

bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic || PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      
      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      
      // Time stop
      if(g_bars_held >= strategy_time_stop_bars)
         return true;
      
      // Reverse-flip exit: single opposite block printed
      if(pos_type == POSITION_TYPE_BUY && g_last_block_color == -1)
         return true;
      if(pos_type == POSITION_TYPE_SELL && g_last_block_color == 1)
         return true;
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

   if(!QM_FrameworkDeclareExecutionContract(PERIOD_H1,
                                            QM_FRIDAY_CLOSE_CARD_RULE,
                                            "QM5_12928 renko double flip confirm H1"))
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
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;
   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
   {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
   }

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;

   if(!QM_IsNewBar(_Symbol, PERIOD_H1)) return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
   if(Strategy_EntrySignal(req))
   {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
   }
}

void OnTimer() { QM_FrameworkOnTimer(); }

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
