#property strict
#property version   "5.0"
#property description "QM5_34007 Alexey Sergeev Tick Momentum Interceptor"
// Strategy Card: QM5_34007 (sergeev-hft-tick-momentum-interceptor), G0 APPROVED 2026-08-15.

#include <QM/QM_Common.mqh>
#include <Trade/Trade.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_34007
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 34007;
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
input double strategy_max_spread_pips     = 0.8;    // Max allowable spread in pips (0.8 pips = 8 points on 5-digit)
input double strategy_tick_burst_factor   = 3.0;    // Tick volume density surge multiplier (Volume[1] / AvgVolume)
input int    strategy_vol_period          = 20;     // Volume baseline SMA lookback
input int    strategy_min_body_points     = 40;     // Minimum 1-bar impulse displacement in points (4.0 pips)
input int    strategy_tp_points           = 60;     // Take profit in points (6.0 pips)
input int    strategy_sl_points           = 50;     // Hard stop loss in points (5.0 pips)
input int    strategy_be_trigger_points   = 35;     // Break-even trigger profit in points (3.5 pips)
input int    strategy_be_lock_points      = 10;     // Break-even locked profit in points (1.0 pip)
input int    strategy_atr_period          = 14;     // Spread filter ATR period
input double strategy_spread_atr_mult     = 1.8;    // Dynamic spread filter ATR multiplier

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

int GetBarHhmm(const datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.hour * 100 + dt.min);
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

   const double atr_1 = QM_ATR(_Symbol, PERIOD_M1, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask > 0.0 && bid > 0.0 && ask > bid && point > 0.0)
   {
      const double spread_pts = (ask - bid) / point;
      if(atr_1 > 0.0)
      {
         const double atr_pts = atr_1 / point;
         if(spread_pts > strategy_spread_atr_mult * atr_pts)
            return true;
      }
      const double max_spread_pts = QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(strategy_max_spread_pips * 10.0)) / point;
      if(max_spread_pts > 0.0 && spread_pts > max_spread_pts)
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

   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   const long vol_1 = iVolume(_Symbol, PERIOD_M1, 1); // perf-allowed: closed-bar volume behind QM_IsNewBar()
   if(vol_1 <= 0)
      return false;

   const int vol_lb = MathMax(5, strategy_vol_period);
   double sum_vol = 0.0;
   int count_vol = 0;
   for(int i = 2; i <= vol_lb + 1; ++i)
   {
      const long v = iVolume(_Symbol, PERIOD_M1, i); // perf-allowed: closed-bar volume behind QM_IsNewBar()
      if(v > 0)
      {
         sum_vol += (double)v;
         count_vol++;
      }
   }
   if(count_vol < 3)
      return false;

   const double avg_vol = sum_vol / (double)count_vol;
   if(avg_vol <= 0.0)
      return false;

   const double tick_burst = (double)vol_1 / avg_vol;
   if(tick_burst < strategy_tick_burst_factor)
      return false;

   const double close_1 = iClose(_Symbol, PERIOD_M1, 1); // perf-allowed: closed-bar close behind QM_IsNewBar()
   const double open_1 = iOpen(_Symbol, PERIOD_M1, 1);   // perf-allowed: closed-bar open behind QM_IsNewBar()
   if(close_1 <= 0.0 || open_1 <= 0.0)
      return false;

   const double body_pts = (close_1 - open_1) / point;
   const double sl_dist = (double)strategy_sl_points * point;
   const double tp_dist = (double)strategy_tp_points * point;

   if(body_pts >= (double)strategy_min_body_points)
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double exec_price = (ask > 0.0) ? ask : close_1;
      req.type = QM_BUY;
      req.price = exec_price;
      req.sl = exec_price - sl_dist;
      req.tp = exec_price + tp_dist;
      req.reason = "Sergeev Tick Momentum Long";
      return true;
   }

   if(body_pts <= -(double)strategy_min_body_points)
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double exec_price = (bid > 0.0) ? bid : close_1;
      req.type = QM_SELL;
      req.price = exec_price;
      req.sl = exec_price + sl_dist;
      req.tp = exec_price - tp_dist;
      req.reason = "Sergeev Tick Momentum Short";
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return;

   const double be_trigger_dist = (double)strategy_be_trigger_points * point;
   const double be_lock_dist = (double)strategy_be_lock_points * point;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);

      if(pos_type == POSITION_TYPE_BUY)
      {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid <= 0.0 || open_price <= 0.0)
            continue;
         const double profit_dist = bid - open_price;
         if(profit_dist >= be_trigger_dist)
         {
            const double new_sl = open_price + be_lock_dist;
            if(current_sl < new_sl || current_sl == 0.0)
            {
               QM_TM_MoveSL(ticket, new_sl, "Micro-BE Lock");
            }
         }
      }
      else if(pos_type == POSITION_TYPE_SELL)
      {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask <= 0.0 || open_price <= 0.0)
            continue;
         const double profit_dist = open_price - ask;
         if(profit_dist >= be_trigger_dist)
         {
            const double new_sl = open_price - be_lock_dist;
            if(current_sl > new_sl || current_sl == 0.0)
            {
               QM_TM_MoveSL(ticket, new_sl, "Micro-BE Lock");
            }
         }
      }
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
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
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
