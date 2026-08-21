#property strict
#property version   "5.0"
#property description "QM5_36005 NNFX Coral & Trend Lord Momentum Harvester"
// Strategy Card: QM5_36005 (nnfx-coral-trendlord-woodies-harvester), G0 APPROVED 2026-08-15.

#include <QM/QM_Common.mqh>
#include <Trade/Trade.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_36005
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 36005;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.5;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

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
input int    strategy_coral_period        = 20;     // Coral SMMA/T3 smoothing period
input double strategy_coral_coeff         = 0.40;   // Coral smoothing coefficient
input int    strategy_coral_warmup_bars   = 100;    // Coral closed-bar warmup lookback depth
input int    strategy_trendlord_period    = 50;     // Trend Lord lookback period
input int    strategy_woodies_cci_period  = 14;     // Woodies CCI period
input int    strategy_wae_fast            = 12;     // WAE MACD fast EMA period
input int    strategy_wae_slow            = 26;     // WAE MACD slow EMA period
input int    strategy_wae_signal          = 9;      // WAE MACD signal SMA period
input int    strategy_wae_bb_period       = 20;     // WAE Bollinger Bands period
input double strategy_wae_bb_deviation    = 2.0;    // WAE Bollinger Bands deviation
input int    strategy_wae_sensitivity     = 150;    // WAE sensitivity multiplier
input int    strategy_wae_deadzone_pts    = 150;    // WAE deadzone in points
input int    strategy_atr_period          = 14;     // ATR period for stop loss and spread filter
input double strategy_sl_atr_mult         = 1.00;   // Stop loss ATR multiplier
input double strategy_tp_atr_mult         = 1.00;   // Take profit ATR multiplier
input double strategy_spread_atr_mult     = 1.80;   // Spread filter ATR multiplier

// -----------------------------------------------------------------------------
// Helpers & Indicator Math
// -----------------------------------------------------------------------------

int GetBarHhmm(const datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.hour * 100 + dt.min);
}

bool Strategy_HasOpenPosition()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0) return false;
   return (QM_TM_OpenPositionCount(magic) > 0);
}

bool Strategy_Coral(const string sym, const int period, const double coeff, const int warmup_bars, const int shift, double &coral_val)
{
   coral_val = 0.0;
   if(period < 2 || shift < 1) return false;
   const int count = warmup_bars + shift + 1;

   double e1[], e2[], e3[], e4[], e5[], e6[];
   ArrayResize(e1, count);
   ArrayResize(e2, count);
   ArrayResize(e3, count);
   ArrayResize(e4, count);
   ArrayResize(e5, count);
   ArrayResize(e6, count);

   const double alpha = 2.0 / ((double)period + 1.0);
   const double b = MathMax(0.0, MathMin(1.0, coeff));
   const double b2 = b * b;
   const double b3 = b2 * b;
   const double c1 = -b3;
   const double c2 = 3.0 * b2 + 3.0 * b3;
   const double c3 = -6.0 * b2 - 3.0 * b - 3.0 * b3;
   const double c4 = 1.0 + 3.0 * b + 3.0 * b2 + b3;

   for(int s = count - 1; s >= shift; --s)
   {
      const double c = iClose(sym, PERIOD_D1, s); // perf-allowed: closed-bar Coral T3 calculation behind QM_IsNewBar()
      if(c <= 0.0) return false;

      if(s == count - 1)
      {
         e1[s] = c; e2[s] = c; e3[s] = c;
         e4[s] = c; e5[s] = c; e6[s] = c;
      }
      else
      {
         e1[s] = alpha * c + (1.0 - alpha) * e1[s + 1];
         e2[s] = alpha * e1[s] + (1.0 - alpha) * e2[s + 1];
         e3[s] = alpha * e2[s] + (1.0 - alpha) * e3[s + 1];
         e4[s] = alpha * e3[s] + (1.0 - alpha) * e4[s + 1];
         e5[s] = alpha * e4[s] + (1.0 - alpha) * e5[s + 1];
         e6[s] = alpha * e5[s] + (1.0 - alpha) * e6[s + 1];
      }

      if(s == shift)
      {
         coral_val = c1 * e6[s] + c2 * e5[s] + c3 * e4[s] + c4 * e3[s];
      }
   }
   return (coral_val > 0.0);
}

int Strategy_TrendLordSignal(const string sym, const int period, const int shift)
{
   if(period <= 0 || shift < 1) return 0;
   double sum_w1 = 0.0, sum_weight1 = 0.0;
   double sum_w2 = 0.0, sum_weight2 = 0.0;
   for(int k = 0; k < period; ++k)
   {
      const double weight = (double)(period - k);
      const double c1 = iClose(sym, PERIOD_D1, shift + k);     // perf-allowed: closed-bar TrendLord LWMA behind QM_IsNewBar()
      const double c2 = iClose(sym, PERIOD_D1, shift + 1 + k); // perf-allowed: closed-bar TrendLord LWMA behind QM_IsNewBar()
      if(c1 <= 0.0 || c2 <= 0.0) return 0;
      sum_w1 += c1 * weight;
      sum_weight1 += weight;
      sum_w2 += c2 * weight;
      sum_weight2 += weight;
   }
   if(sum_weight1 <= 0.0 || sum_weight2 <= 0.0) return 0;
   const double tl1 = sum_w1 / sum_weight1;
   const double tl2 = sum_w2 / sum_weight2;
   if(tl1 > tl2) return 1;  // GREEN
   if(tl1 < tl2) return -1; // RED
   return 0;
}

int Strategy_WAESignal()
{
   const double macd_now  = QM_MACD_Main(_Symbol, PERIOD_D1, strategy_wae_fast, strategy_wae_slow, strategy_wae_signal, 1, PRICE_CLOSE);
   const double macd_prev = QM_MACD_Main(_Symbol, PERIOD_D1, strategy_wae_fast, strategy_wae_slow, strategy_wae_signal, 2, PRICE_CLOSE);
   const double bb_upper  = QM_BB_Upper(_Symbol, PERIOD_D1, strategy_wae_bb_period, strategy_wae_bb_deviation, 1, PRICE_CLOSE);
   const double bb_lower  = QM_BB_Lower(_Symbol, PERIOD_D1, strategy_wae_bb_period, strategy_wae_bb_deviation, 1, PRICE_CLOSE);
   const double point     = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(bb_upper <= 0.0 || bb_lower <= 0.0 || point <= 0.0)
      return 0;

   const double momentum = (macd_now - macd_prev) * (double)strategy_wae_sensitivity;
   const double explosion = MathAbs(bb_upper - bb_lower);
   const double deadzone = (double)strategy_wae_deadzone_pts * point;
   const double threshold = MathMax(explosion, deadzone);

   if(momentum > threshold)
      return 1;
   if(-momentum > threshold)
      return -1;
   return 0;
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   const datetime now = TimeCurrent();
   const int hhmm = GetBarHhmm(now);
   if(hhmm >= 2355 || hhmm < 5)
      return true;

   const double atr_1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask > 0.0 && bid > 0.0 && ask > bid && point > 0.0 && atr_1 > 0.0)
   {
      const double spread_pts = (ask - bid) / point;
      const double atr_pts = atr_1 / point;
      if(spread_pts > strategy_spread_atr_mult * atr_pts)
         return true;
   }
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

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   if(Strategy_HasOpenPosition())
      return false;

   const double close_1 = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: closed-bar reference behind QM_IsNewBar()
   if(close_1 <= 0.0)
      return false;

   double coral_1 = 0.0;
   if(!Strategy_Coral(_Symbol, strategy_coral_period, strategy_coral_coeff, strategy_coral_warmup_bars, 1, coral_1))
      return false;

   const int tl_signal = Strategy_TrendLordSignal(_Symbol, strategy_trendlord_period, 1);
   if(tl_signal == 0)
      return false;

   const double woodies_cci = QM_CCI(_Symbol, PERIOD_D1, strategy_woodies_cci_period, 1);

   const int wae_signal = Strategy_WAESignal();
   if(wae_signal == 0)
      return false;

   const double atr_1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_1 <= 0.0)
      return false;

   const double pip_size = QM_StopRulesPipsToPriceDistance(_Symbol, 1.0);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(pip_size <= 0.0 || point <= 0.0)
      return false;

   const double sl_dist = MathMax(strategy_sl_atr_mult * atr_1, 10.0 * pip_size);
   const double tp_dist = MathMax(strategy_tp_atr_mult * atr_1, 10.0 * pip_size);

   // Long: Close > Coral AND TrendLord == GREEN (+1) AND Woodies_CCI > 0 AND WAE == UP (+1)
   if(close_1 > coral_1 && tl_signal > 0 && woodies_cci > 0.0 && wae_signal > 0)
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double exec_price = (ask > 0.0) ? ask : close_1;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_TM_NormalizePrice(_Symbol, exec_price - sl_dist);
      req.tp = QM_TM_NormalizePrice(_Symbol, exec_price + tp_dist);
      req.reason = "nnfx_coral_tl_long";
      return true;
   }

   // Short: Close < Coral AND TrendLord == RED (-1) AND Woodies_CCI < 0 AND WAE == DOWN (-1)
   if(close_1 < coral_1 && tl_signal < 0 && woodies_cci < 0.0 && wae_signal < 0)
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double exec_price = (bid > 0.0) ? bid : close_1;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_TM_NormalizePrice(_Symbol, exec_price + sl_dist);
      req.tp = QM_TM_NormalizePrice(_Symbol, exec_price - tp_dist);
      req.reason = "nnfx_coral_tl_short";
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0) return;
   const double pip_size = QM_StopRulesPipsToPriceDistance(_Symbol, 1.0);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(pip_size <= 0.0 || point <= 0.0) return;

   const double atr_1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double be_trigger = (atr_1 > 0.0) ? (strategy_tp_atr_mult * atr_1) : (20.0 * pip_size);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);

      if(pos_type == POSITION_TYPE_BUY)
      {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid <= 0.0 || open_price <= 0.0) continue;

         // Move to break-even once open profit >= 1.0 ATR
         if((bid - open_price) >= be_trigger)
         {
            const double target_sl = QM_TM_NormalizePrice(_Symbol, open_price + 1.0 * pip_size);
            if(target_sl > current_sl + point * 0.5)
               QM_TM_MoveSL(ticket, target_sl, "nnfx_be_plus_1");
         }
      }
      else if(pos_type == POSITION_TYPE_SELL)
      {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask <= 0.0 || open_price <= 0.0) continue;

         // Move to break-even once open profit >= 1.0 ATR
         if((open_price - ask) >= be_trigger)
         {
            const double target_sl = QM_TM_NormalizePrice(_Symbol, open_price - 1.0 * pip_size);
            if(current_sl <= 0.0 || target_sl < current_sl - point * 0.5)
               QM_TM_MoveSL(ticket, target_sl, "nnfx_be_plus_1");
         }
      }
   }
}

bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0) return false;

   const int tl_signal = Strategy_TrendLordSignal(_Symbol, strategy_trendlord_period, 1);
   const double woodies_cci = QM_CCI(_Symbol, PERIOD_D1, strategy_woodies_cci_period, 1);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      // Long exit: TrendLord flipped RED (< 0) or Woodies CCI crossed below 0
      if(pos_type == POSITION_TYPE_BUY)
      {
         if(tl_signal < 0 || woodies_cci < 0.0)
            return true;
      }
      // Short exit: TrendLord flipped GREEN (> 0) or Woodies CCI crossed above 0
      else if(pos_type == POSITION_TYPE_SELL)
      {
         if(tl_signal > 0 || woodies_cci > 0.0)
            return true;
      }
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
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                        qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   QM_FrameworkShutdown();
}

void OnTick()
{
   QM_FrameworkTrackOpenPositionMae();
   if(!QM_KillSwitchCheck()) return;
   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;

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

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;
   
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;

   if(!QM_IsNewBar()) return;
   QM_EquityStreamOnNewBar();

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

void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{
   QM_FrameworkOnTradeTransaction(t, r, res);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
