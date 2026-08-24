#property strict
#property version   "5.0"
#property description "QM5_20077 ATR-Channel Auto-Trailing Breakout (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_20077
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 20077;
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
input int    strategy_base_ma_period              = 21;
input int    strategy_atr_period                  = 14;
input double strategy_band_mult                   = 2.5;
input int    strategy_macro_ema_period            = 200;
input int    strategy_d1_atr_period               = 14;
input double strategy_min_channel_width_d1_atr_mult = 0.5;
input double strategy_max_sl_atr_mult             = 4.0;
input int    strategy_session_start_hour          = 6;
input int    strategy_session_end_hour            = 21;
input double strategy_spread_mult                 = 1.5;
input int    strategy_spread_median_bars          = 20;

// -----------------------------------------------------------------------------
// Strategy Global State & Indicator Handles
// -----------------------------------------------------------------------------
int      g_handle_base_ma     = INVALID_HANDLE;
int      g_handle_atr         = INVALID_HANDLE;
int      g_handle_macro_ema   = INVALID_HANDLE;
int      g_handle_d1_atr      = INVALID_HANDLE;

int      g_direction          = 0;   // 0 = none, +1 = bullish channel, -1 = bearish channel
double   g_stop_level         = 0.0; // trailing stop level for current channel state
datetime g_last_bar_time      = 0;
bool     g_pending_exit       = false;

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------
bool Strategy_GetOurPosition(ENUM_POSITION_TYPE &ptype, ulong &ticket, double &pos_sl, double &pos_open_price)
{
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      pos_sl = PositionGetDouble(POSITION_SL);
      pos_open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      return true;
   }
   return false;
}

double Strategy_MedianSpread(const int count)
{
   if(count <= 0) return 0.0;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_H1, 1, count, rates);
   if(copied < count) return 0.0;
   
   double spreads[];
   ArrayResize(spreads, count);
   for(int i = 0; i < count; ++i)
      spreads[i] = (double)rates[i].spread * _Point;
   
   ArraySort(spreads);
   if(count % 2 == 1)
      return spreads[count / 2];
   return 0.5 * (spreads[count / 2 - 1] + spreads[count / 2]);
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0) return true;
   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   ENUM_POSITION_TYPE ptype;
   ulong ticket = 0;
   double pos_sl = 0.0, pos_open_price = 0.0;
   if(Strategy_GetOurPosition(ptype, ticket, pos_sl, pos_open_price))
      return false;

   if(g_direction == 0 || g_stop_level <= 0.0)
      return false;

   const datetime broker_now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(broker_now, dt);
   if(dt.hour < strategy_session_start_hour || dt.hour >= strategy_session_end_hour)
      return false;

   double base_ma_buf[1], atr_buf[1], macro_ema_buf[1], d1_atr_buf[1];
   if(CopyBuffer(g_handle_base_ma, 0, 1, 1, base_ma_buf) <= 0) return false;
   if(CopyBuffer(g_handle_atr, 0, 1, 1, atr_buf) <= 0) return false;
   if(CopyBuffer(g_handle_macro_ema, 0, 1, 1, macro_ema_buf) <= 0) return false;
   if(CopyBuffer(g_handle_d1_atr, 0, 1, 1, d1_atr_buf) <= 0) return false;

   MqlRates rates[2];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_H1, 0, 2, rates) < 2) return false;

   const double base_ma   = base_ma_buf[0];
   const double atr_h1    = atr_buf[0];
   const double macro_ema = macro_ema_buf[0];
   const double d1_atr    = d1_atr_buf[0];
   const double close1    = rates[1].close;

   const double upper_band = base_ma + strategy_band_mult * atr_h1;
   const double lower_band = base_ma - strategy_band_mult * atr_h1;
   const double channel_width = upper_band - lower_band;
   const double min_width = strategy_min_channel_width_d1_atr_mult * d1_atr;

   if(channel_width <= min_width)
      return false;

   // Spread guard
   const double cur_spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   const double med_spread = Strategy_MedianSpread(strategy_spread_median_bars);
   if(med_spread > 0.0 && cur_spread > strategy_spread_mult * med_spread)
      return false;

   const double max_sl_dist = strategy_max_sl_atr_mult * atr_h1;

   if(g_direction == 1 && close1 > macro_ema)
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl = g_stop_level;
      if(ask - sl > max_sl_dist)
         sl = ask - max_sl_dist;

      req.cmd = QM_BUY;
      req.price = ask;
      req.sl = QM_NormalizePrice(_Symbol, sl);
      req.tp = 0.0;
      req.reason = "ATR_CHANNEL_BREAKOUT_LONG";
      return (req.sl > 0.0 && req.sl < ask);
   }
   else if(g_direction == -1 && close1 < macro_ema)
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl = g_stop_level;
      if(sl - bid > max_sl_dist)
         sl = bid + max_sl_dist;

      req.cmd = QM_SELL;
      req.price = bid;
      req.sl = QM_NormalizePrice(_Symbol, sl);
      req.tp = 0.0;
      req.reason = "ATR_CHANNEL_BREAKOUT_SHORT";
      return (req.sl > bid);
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
   ENUM_POSITION_TYPE ptype;
   ulong ticket = 0;
   double pos_sl = 0.0, pos_open_price = 0.0;
   if(!Strategy_GetOurPosition(ptype, ticket, pos_sl, pos_open_price))
      return;

   if(g_stop_level <= 0.0) return;

   const double norm_sl = QM_NormalizePrice(_Symbol, g_stop_level);
   if(ptype == POSITION_TYPE_BUY)
   {
      if(norm_sl > pos_sl)
      {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(norm_sl < bid)
            QM_TM_ModifyPosition(ticket, norm_sl, 0.0);
      }
   }
   else if(ptype == POSITION_TYPE_SELL)
   {
      if(pos_sl <= 0.0 || norm_sl < pos_sl)
      {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(norm_sl > ask)
            QM_TM_ModifyPosition(ticket, norm_sl, 0.0);
      }
   }
}

bool Strategy_ExitSignal()
{
   if(g_pending_exit)
   {
      g_pending_exit = false;
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

   g_handle_base_ma = iMA(_Symbol, PERIOD_H1, strategy_base_ma_period, 0, MODE_EMA, PRICE_CLOSE);
   g_handle_atr = iATR(_Symbol, PERIOD_H1, strategy_atr_period);
   g_handle_macro_ema = iMA(_Symbol, PERIOD_H1, strategy_macro_ema_period, 0, MODE_EMA, PRICE_CLOSE);
   g_handle_d1_atr = iATR(_Symbol, PERIOD_D1, strategy_d1_atr_period);

   if(g_handle_base_ma == INVALID_HANDLE || g_handle_atr == INVALID_HANDLE ||
      g_handle_macro_ema == INVALID_HANDLE || g_handle_d1_atr == INVALID_HANDLE)
   {
      Print("Error initializing indicator handles");
      return INIT_FAILED;
   }

   g_direction = 0;
   g_stop_level = 0.0;
   g_last_bar_time = 0;
   g_pending_exit = false;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_20077_atr-channel-trail-breakout-h1\"}");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_handle_base_ma != INVALID_HANDLE) IndicatorRelease(g_handle_base_ma);
   if(g_handle_atr != INVALID_HANDLE) IndicatorRelease(g_handle_atr);
   if(g_handle_macro_ema != INVALID_HANDLE) IndicatorRelease(g_handle_macro_ema);
   if(g_handle_d1_atr != INVALID_HANDLE) IndicatorRelease(g_handle_d1_atr);

   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
}

void OnTick()
{
   QM_FrameworkTrackOpenPositionMae();

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

   // Update channel flip latch and exit flags on new closed bar
   datetime cur_bar_time = 0;
   datetime bar_time_buf[1];
   if(CopyTime(_Symbol, PERIOD_H1, 0, 1, bar_time_buf) > 0)
      cur_bar_time = bar_time_buf[0];

   if(cur_bar_time > 0 && cur_bar_time != g_last_bar_time)
   {
      g_last_bar_time = cur_bar_time;

      double base_ma_buf[1], atr_buf[1], macro_ema_buf[1];
      MqlRates rates[2];
      ArraySetAsSeries(rates, true);

      if(CopyBuffer(g_handle_base_ma, 0, 1, 1, base_ma_buf) > 0 &&
         CopyBuffer(g_handle_atr, 0, 1, 1, atr_buf) > 0 &&
         CopyBuffer(g_handle_macro_ema, 0, 1, 1, macro_ema_buf) > 0 &&
         CopyRates(_Symbol, PERIOD_H1, 0, 2, rates) >= 2)
      {
         const double base_ma = base_ma_buf[0];
         const double atr_val = atr_buf[0];
         const double macro_ema = macro_ema_buf[0];
         const double close1 = rates[1].close;

         const double upper_band = base_ma + strategy_band_mult * atr_val;
         const double lower_band = base_ma - strategy_band_mult * atr_val;

         // Latch state machine
         if(g_direction == 0)
         {
            if(close1 > upper_band)
            {
               g_direction = 1;
               g_stop_level = lower_band;
            }
            else if(close1 < lower_band)
            {
               g_direction = -1;
               g_stop_level = upper_band;
            }
         }
         else if(g_direction == 1)
         {
            g_stop_level = MathMax(g_stop_level, lower_band);
            if(close1 < g_stop_level)
            {
               g_direction = -1;
               g_stop_level = upper_band;
            }
         }
         else if(g_direction == -1)
         {
            g_stop_level = MathMin(g_stop_level, upper_band);
            if(close1 > g_stop_level)
            {
               g_direction = 1;
               g_stop_level = lower_band;
            }
         }

         // Check exit condition on closed bar
         ENUM_POSITION_TYPE ptype;
         ulong ticket = 0;
         double pos_sl = 0.0, pos_open_price = 0.0;
         if(Strategy_GetOurPosition(ptype, ticket, pos_sl, pos_open_price))
         {
            if(ptype == POSITION_TYPE_BUY)
            {
               if(close1 < g_stop_level || close1 < macro_ema)
                  g_pending_exit = true;
            }
            else if(ptype == POSITION_TYPE_SELL)
            {
               if(close1 > g_stop_level || close1 > macro_ema)
                  g_pending_exit = true;
            }
         }
      }
   }

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
