#property strict
#property version   "5.0"
#property description "QM5_1627 Hopwood Bermaui-CCI H4 Trend-Follower"

#include <QM/QM_Common.mqh>
#include <QM/QM_Indicators.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_1627
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1627;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_cci_period         = 20;
input int    strategy_wilder_period      = 7;
input int    strategy_hma_period         = 7;
input double strategy_envelope_threshold = 100.0;
input int    strategy_envelope_window    = 5;
input int    strategy_ema_period         = 200;
input int    strategy_atr_period         = 14;
input double strategy_sl_atr_mult        = 3.0;
input double strategy_tp_atr_mult        = 2.5;
input double strategy_be_atr_mult        = 1.2;
input int    strategy_time_stop_bars     = 40;
input int    strategy_cooldown_bars      = 8;
input double strategy_max_spread_atr_mult = 0.3;
input bool   strategy_sl_swing_anchor    = false;

// Globals for state tracking
bool           g_position_open_prev = false;
double         g_entry_price        = 0.0;
double         g_atr_at_entry       = 0.0;
QM_OrderType   g_trade_dir          = QM_BUY;
bool           g_tp1_taken          = false;
int            g_bars_in_trade      = 0;
int            g_cooldown_counter   = 0;
QM_OrderType   g_last_trade_dir     = QM_BUY;

// -----------------------------------------------------------------------------
// Strategy logic helpers
// -----------------------------------------------------------------------------

double GetBermauiCCI(int shift)
{
   double cci_raw[60];
   for(int i = 0; i < 60; i++)
   {
      cci_raw[i] = QM_CCI(_Symbol, PERIOD_H4, strategy_cci_period, shift + i, PRICE_TYPICAL); // perf-allowed: range scan
   }
   
   double cci_smooth1[30];
   for(int j = 0; j < 30; j++)
   {
      double wma = cci_raw[j + 25];
      for(int k = j + 24; k >= j; k--)
      {
         wma = (wma * (strategy_wilder_period - 1.0) + cci_raw[k]) / (double)strategy_wilder_period;
      }
      cci_smooth1[j] = wma;
   }
   
   double temp[5];
   const int half_period = strategy_hma_period / 2;
   const int sqrt_period = (int)MathSqrt(strategy_hma_period);
   
   for(int n = 0; n < 5; n++)
   {
      // WMA (half_period)
      double wma_half = 0.0;
      double wma_half_sum = 0.0;
      for(int i = 0; i < half_period; i++)
      {
         wma_half += cci_smooth1[n + i] * (half_period - i);
         wma_half_sum += (half_period - i);
      }
      if(wma_half_sum > 0.0) wma_half /= wma_half_sum;
      
      // WMA (strategy_hma_period)
      double wma_full = 0.0;
      double wma_full_sum = 0.0;
      for(int i = 0; i < strategy_hma_period; i++)
      {
         wma_full += cci_smooth1[n + i] * (strategy_hma_period - i);
         wma_full_sum += (strategy_hma_period - i);
      }
      if(wma_full_sum > 0.0) wma_full /= wma_full_sum;
      
      temp[n] = 2.0 * wma_half - wma_full;
   }
   
   // HMA is WMA of temp with period sqrt_period
   double hma = 0.0;
   double hma_sum = 0.0;
   for(int i = 0; i < sqrt_period; i++)
   {
      hma += temp[i] * (sqrt_period - i);
      hma_sum += (sqrt_period - i);
   }
   if(hma_sum > 0.0) hma /= hma_sum;
   return hma;
}

bool WasZeroCrossUp(int shift)
{
   return (GetBermauiCCI(shift + 1) < 0.0 && GetBermauiCCI(shift) >= 0.0);
}

bool WasZeroCrossDown(int shift)
{
   return (GetBermauiCCI(shift + 1) > 0.0 && GetBermauiCCI(shift) <= 0.0);
}

bool IsEnvelopeLong()
{
   bool zero_cross = false;
   for(int i = 1; i <= strategy_envelope_window; i++)
   {
      if(WasZeroCrossUp(i)) { zero_cross = true; break; }
   }
   if(!zero_cross) return false;
   return (GetBermauiCCI(1) > strategy_envelope_threshold);
}

bool IsEnvelopeShort()
{
   bool zero_cross = false;
   for(int i = 1; i <= strategy_envelope_window; i++)
   {
      if(WasZeroCrossDown(i)) { zero_cross = true; break; }
   }
   if(!zero_cross) return false;
   return (GetBermauiCCI(1) < -strategy_envelope_threshold);
}

double GetSwingSL(QM_OrderType side, int lookback)
{
   if(side == QM_BUY)
   {
      double lowest = DBL_MAX;
      for(int i = 1; i <= lookback; i++)
      {
         double low = iLow(_Symbol, PERIOD_H4, i); // perf-allowed: range scan
         if(low < lowest) lowest = low;
      }
      return lowest;
   }
   else
   {
      double highest = -DBL_MAX;
      for(int i = 1; i <= lookback; i++)
      {
         double high = iHigh(_Symbol, PERIOD_H4, i); // perf-allowed: range scan
         if(high > highest) highest = high;
      }
      return highest;
   }
}

bool CooldownAllows(QM_OrderType side)
{
   if(g_cooldown_counter > 0 && g_last_trade_dir == side)
      return false;
   return true;
}

bool Strategy_SelectOurPosition(ENUM_POSITION_TYPE &position_type, ulong &ticket)
{
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      ticket = candidate;
      return true;
     }
   return false;
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   if(Bars(_Symbol, PERIOD_H4) < strategy_ema_period + 60) // perf-allowed: O(1) bar count for warmup
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double spread = ask - bid;
   const double atr1 = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(spread > strategy_max_spread_atr_mult * atr1)
      return true;

   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   req.type             = QM_BUY;
   req.price            = 0.0;
   req.sl               = 0.0;
   req.tp               = 0.0;
   req.reason           = "";
   req.symbol_slot      = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_cci_period < 2 || strategy_wilder_period < 2 || strategy_hma_period < 2)
      return false;

   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   QM_OrderType side = QM_BUY;
   string reason = "";
   
   const double close1_d1 = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: close check
   const double sma200_d1 = QM_SMA(_Symbol, PERIOD_D1, strategy_ema_period, 1);
   const double cci1 = GetBermauiCCI(1);
   const double cci2 = GetBermauiCCI(2);
   const double delta = cci1 - cci2;

   if(IsEnvelopeLong() && delta > 0.0 && close1_d1 > sma200_d1)
   {
      side = QM_BUY;
      reason = "BERMAUI_CCI_LONG";
   }
   else if(IsEnvelopeShort() && delta < 0.0 && close1_d1 < sma200_d1)
   {
      side = QM_SELL;
      reason = "BERMAUI_CCI_SHORT";
   }
   else
   {
      return false;
   }

   if(!CooldownAllows(side))
      return false;

   const double ask_now = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid_now = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double entry_price = (side == QM_BUY) ? ask_now : bid_now;
   if(entry_price <= 0.0)
      return false;

   double sl = 0.0;
   if(strategy_sl_swing_anchor)
   {
      sl = GetSwingSL(side, 18);
   }
   else
   {
      sl = QM_StopATR(_Symbol, side, entry_price, strategy_atr_period, strategy_sl_atr_mult);
   }

   if(sl <= 0.0 || (side == QM_BUY && sl >= entry_price) || (side == QM_SELL && sl <= entry_price))
      return false;

   req.type             = side;
   req.price            = 0.0;
   req.sl               = req.sl; // Wait, actually: req.sl = sl
   req.sl               = sl;
   req.tp               = 0.0; // Managed via partial close & trailing SL
   req.reason           = reason;
   req.symbol_slot      = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   return true;
}

void Strategy_ManageOpenPosition()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) == 0)
      return;

   double close1 = iClose(_Symbol, PERIOD_H4, 1); // perf-allowed: close check
   if(close1 <= 0.0 || g_atr_at_entry <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double vol = PositionGetDouble(POSITION_VOLUME);
      
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double spread = (ask > bid) ? (ask - bid) : 0.0;

      // 1. Move SL to break-even-plus-spread at +1.2 * ATR
      if(type == POSITION_TYPE_BUY)
      {
         const double target_be = open_price + strategy_be_atr_mult * g_atr_at_entry;
         if(close1 >= target_be)
         {
            const double new_sl = QM_TM_NormalizePrice(_Symbol, open_price + spread + 2.0 * SymbolInfoDouble(_Symbol, SYMBOL_POINT));
            if(current_sl < new_sl - 1e-5)
            {
               QM_TM_MoveSL(ticket, new_sl, "BREAKEVEN");
            }
         }
      }
      else if(type == POSITION_TYPE_SELL)
      {
         const double target_be = open_price - strategy_be_atr_mult * g_atr_at_entry;
         if(close1 <= target_be)
         {
            const double new_sl = QM_TM_NormalizePrice(_Symbol, open_price - spread - 2.0 * SymbolInfoDouble(_Symbol, SYMBOL_POINT));
            if(current_sl > new_sl + 1e-5 || current_sl == 0.0)
            {
               QM_TM_MoveSL(ticket, new_sl, "BREAKEVEN");
            }
         }
      }

      // 2. Close 50% at +2.5 * ATR (TP1)
      if(!g_tp1_taken)
      {
         bool hit_tp1 = false;
         if(type == POSITION_TYPE_BUY && close1 >= open_price + strategy_tp_atr_mult * g_atr_at_entry)
            hit_tp1 = true;
         else if(type == POSITION_TYPE_SELL && close1 <= open_price - strategy_tp_atr_mult * g_atr_at_entry)
            hit_tp1 = true;

         if(hit_tp1)
         {
            const double close_vol = QM_TM_NormalizeVolume(_Symbol, vol * 0.5);
            if(close_vol > 0.0)
            {
               QM_TM_PartialClose(ticket, close_vol, QM_EXIT_STRATEGY);
               g_tp1_taken = true;
            }
         }
      }
      break;
   }
}

bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) == 0)
      return false;

   if(g_bars_in_trade >= strategy_time_stop_bars)
      return true;

   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   ulong ticket = 0;
   if(Strategy_SelectOurPosition(position_type, ticket))
   {
      if(position_type == POSITION_TYPE_BUY && IsEnvelopeShort())
         return true;
      if(position_type == POSITION_TYPE_SELL && IsEnvelopeLong())
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
      
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1627\",\"strategy\":\"hopwood-bermaui-cci-h4\"}");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
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

   const bool is_new_bar = QM_IsNewBar();

   // State tracking logic
   const int magic = QM_FrameworkMagic();
   if(magic > 0)
   {
      const int pos_count = QM_TM_OpenPositionCount(magic);
      if(pos_count > 0)
      {
         if(!g_position_open_prev)
         {
            g_position_open_prev = true;
            g_tp1_taken = false;
            g_bars_in_trade = 0;
            
            for(int i = PositionsTotal() - 1; i >= 0; --i)
            {
               ulong ticket = PositionGetTicket(i);
               if(PositionSelectByTicket(ticket) && (int)PositionGetInteger(POSITION_MAGIC) == magic)
               {
                  g_entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
                  g_atr_at_entry = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
                  g_trade_dir = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? QM_BUY : QM_SELL;
                  break;
               }
            }
         }
         else
         {
            if(is_new_bar)
            {
               g_bars_in_trade++;
            }
         }
      }
      else
      {
         if(g_position_open_prev)
         {
            g_position_open_prev = false;
            g_cooldown_counter = strategy_cooldown_bars;
            g_last_trade_dir = g_trade_dir;
            g_tp1_taken = false;
            g_bars_in_trade = 0;
         }
         else
         {
            if(is_new_bar)
            {
               if(g_cooldown_counter > 0)
                  g_cooldown_counter--;
            }
         }
      }
   }

   if(Strategy_NoTradeFilter()) return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
   {
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
   }

   if(!is_new_bar) return;
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
