#property strict
#property version   "5.0"
#property description "QM5_9354 DeMark TD-D-Wave Wave-4 Pullback Continuation (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_9354
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9354;
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

// -----------------------------------------------------------------------------
// Global variables for persistence
// -----------------------------------------------------------------------------
static datetime last_traded_w3_time = 0;
static double   last_w4_extreme     = 0.0;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Helper to find highest high in H4 index range [start, end]
double HighestHigh(int start, int end, int &max_idx)
{
   max_idx = start;
   double max_val = iHigh(_Symbol, PERIOD_H4, start);
   for(int i = start + 1; i <= end; i++)
   {
      double val = iHigh(_Symbol, PERIOD_H4, i);
      if(val > max_val)
      {
         max_val = val;
         max_idx = i;
      }
   }
   return max_val;
}

// Helper to find lowest low in H4 index range [start, end]
double LowestLow(int start, int end, int &min_idx)
{
   min_idx = start;
   double min_val = iLow(_Symbol, PERIOD_H4, start);
   for(int i = start + 1; i <= end; i++)
   {
      double val = iLow(_Symbol, PERIOD_H4, i);
      if(val < min_val)
      {
         min_val = val;
         min_idx = i;
      }
   }
   return min_val;
}

bool IsWave1High(int w1)
{
   double h_w1 = iHigh(_Symbol, PERIOD_H4, w1);
   // 1. high[w1] is highest high over the prior 21 closed H4 bars
   for(int i = 1; i <= 21; i++)
   {
      if(iHigh(_Symbol, PERIOD_H4, w1 + i) > h_w1) return false;
   }
   // 2. The 13 closed bars before w1 (newer bars) all have high[i] < high[w1]
   for(int i = 1; i <= 13; i++)
   {
      if(iHigh(_Symbol, PERIOD_H4, w1 - i) >= h_w1) return false;
   }
   return true;
}

bool IsWave1Low(int w1)
{
   double l_w1 = iLow(_Symbol, PERIOD_H4, w1);
   // 1. low[w1] is lowest low over the prior 21 closed H4 bars
   for(int i = 1; i <= 21; i++)
   {
      if(iLow(_Symbol, PERIOD_H4, w1 + i) < l_w1) return false;
   }
   // 2. The 13 closed bars before w1 all have low[i] > low[w1]
   for(int i = 1; i <= 13; i++)
   {
      if(iLow(_Symbol, PERIOD_H4, w1 - i) <= l_w1) return false;
   }
   return true;
}

bool IsWave2Low(int w2, int w1)
{
   double l_w2 = iLow(_Symbol, PERIOD_H4, w2);
   int dummy;
   if(LowestLow(w2, w1, dummy) != l_w2) return false;
   for(int i = 1; i <= 8; i++)
   {
      if(iLow(_Symbol, PERIOD_H4, w2 - i) <= l_w2) return false;
   }
   return true;
}

bool IsWave2High(int w2, int w1)
{
   double h_w2 = iHigh(_Symbol, PERIOD_H4, w2);
   int dummy;
   if(HighestHigh(w2, w1, dummy) != h_w2) return false;
   for(int i = 1; i <= 8; i++)
   {
      if(iHigh(_Symbol, PERIOD_H4, w2 - i) >= h_w2) return false;
   }
   return true;
}

bool IsWave3High(int w3, int w2, int w1)
{
   double h_w3 = iHigh(_Symbol, PERIOD_H4, w3);
   if(h_w3 <= iHigh(_Symbol, PERIOD_H4, w1)) return false;
   int dummy;
   if(HighestHigh(w3, w2, dummy) != h_w3) return false;
   return true;
}

bool IsWave3Low(int w3, int w2, int w1)
{
   double l_w3 = iLow(_Symbol, PERIOD_H4, w3);
   if(l_w3 >= iLow(_Symbol, PERIOD_H4, w1)) return false;
   int dummy;
   if(LowestLow(w3, w2, dummy) != l_w3) return false;
   return true;
}

bool FindUpSkeleton(int &w1, int &w2, int &w3)
{
   int total_bars = iBars(_Symbol, PERIOD_H4);
   int max_lookback = MathMin(300, total_bars - 22);
   
   for(int i_w1 = max_lookback; i_w1 >= 39; i_w1--)
   {
      if(!IsWave1High(i_w1)) continue;
      
      for(int i_w2 = i_w1 - 5; i_w2 >= 14; i_w2--)
      {
         if(!IsWave2Low(i_w2, i_w1)) continue;
         
         for(int i_w3 = i_w2 - 8; i_w3 >= 6; i_w3--)
         {
            if(!IsWave3High(i_w3, i_w2, i_w1)) continue;
            
            w1 = i_w1;
            w2 = i_w2;
            w3 = i_w3;
            return true;
         }
      }
   }
   return false;
}

bool FindDownSkeleton(int &w1, int &w2, int &w3)
{
   int total_bars = iBars(_Symbol, PERIOD_H4);
   int max_lookback = MathMin(300, total_bars - 22);
   
   for(int i_w1 = max_lookback; i_w1 >= 39; i_w1--)
   {
      if(!IsWave1Low(i_w1)) continue;
      
      for(int i_w2 = i_w1 - 5; i_w2 >= 14; i_w2--)
      {
         if(!IsWave2High(i_w2, i_w1)) continue;
         
         for(int i_w3 = i_w2 - 8; i_w3 >= 6; i_w3--)
         {
            if(!IsWave3Low(i_w3, i_w2, i_w1)) continue;
            
            w1 = i_w1;
            w2 = i_w2;
            w3 = i_w3;
            return true;
         }
      }
   }
   return false;
}

bool Strategy_NoTradeFilter()
{
   double atr = QM_ATR(_Symbol, PERIOD_H4, 14, 1);
   if(atr <= 0.0) return true;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0) return true;
   double current_spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   double spread_cap = 0.15 * atr / point;
   if(current_spread_points > spread_cap) return true;
   
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
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic) return false;
   }

   // Search for active UP skeleton
   int w1_up = 0, w2_up = 0, w3_up = 0;
   bool has_up = FindUpSkeleton(w1_up, w2_up, w3_up);
   if(has_up)
   {
      double h_w1 = iHigh(_Symbol, PERIOD_H4, w1_up);
      double l_w2 = iLow(_Symbol, PERIOD_H4, w2_up);
      double h_w3 = iHigh(_Symbol, PERIOD_H4, w3_up);
      
      int t_low = 0;
      double W4L_cand = LowestLow(1, w3_up - 1, t_low);
      
      bool overlap = (W4L_cand <= h_w1);
      bool time_gate = (w3_up - t_low >= 5);
      bool retrace_gate = (W4L_cand <= h_w3 - 0.382 * (h_w3 - l_w2)) &&
                          (W4L_cand >= h_w3 - 0.618 * (h_w3 - l_w2));
                          
      if(!overlap && time_gate && retrace_gate)
      {
         bool pullback_bottomed = (1 < t_low);
         bool close_above_high = (iClose(_Symbol, PERIOD_H4, 1) > iHigh(_Symbol, PERIOD_H4, t_low));
         bool bar_is_up = (iClose(_Symbol, PERIOD_H4, 1) > iClose(_Symbol, PERIOD_H4, 2));
         
         datetime w3_time = iTime(_Symbol, PERIOD_H4, w3_up);
         
         if(pullback_bottomed && close_above_high && bar_is_up && w3_time > last_traded_w3_time)
         {
            double atr = QM_ATR(_Symbol, PERIOD_H4, 14, 1);
            if(atr > 0.0)
            {
               double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
               double stop = W4L_cand - 0.30 * atr;
               double take = h_w3 + 0.618 * (h_w3 - l_w2);
               
               int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
               stop = NormalizeDouble(stop, digits);
               take = NormalizeDouble(take, digits);
               
               if(stop < entry && take > entry)
               {
                  req.type = QM_BUY;
                  req.sl = stop;
                  req.tp = take;
                  req.reason = "TD_DWAVE_W4_BUY";
                  last_traded_w3_time = w3_time;
                  last_w4_extreme = W4L_cand;
                  return true;
               }
            }
         }
      }
   }

   // Search for active DOWN skeleton
   int w1_dn = 0, w2_dn = 0, w3_dn = 0;
   bool has_dn = FindDownSkeleton(w1_dn, w2_dn, w3_dn);
   if(has_dn)
   {
      double l_w1 = iLow(_Symbol, PERIOD_H4, w1_dn);
      double h_w2 = iHigh(_Symbol, PERIOD_H4, w2_dn);
      double l_w3 = iLow(_Symbol, PERIOD_H4, w3_dn);
      
      int t_high = 0;
      double W4H_cand = HighestHigh(1, w3_dn - 1, t_high);
      
      bool overlap = (W4H_cand >= l_w1);
      bool time_gate = (w3_dn - t_high >= 5);
      bool retrace_gate = (W4H_cand >= l_w3 + 0.382 * (h_w2 - l_w3)) &&
                          (W4H_cand <= l_w3 + 0.618 * (h_w2 - l_w3));
                          
      if(!overlap && time_gate && retrace_gate)
      {
         bool pullback_topped = (1 < t_high);
         bool close_below_low = (iClose(_Symbol, PERIOD_H4, 1) < iLow(_Symbol, PERIOD_H4, t_high));
         bool bar_is_dn = (iClose(_Symbol, PERIOD_H4, 1) < iClose(_Symbol, PERIOD_H4, 2));
         
         datetime w3_time = iTime(_Symbol, PERIOD_H4, w3_dn);
         
         if(pullback_topped && close_below_low && bar_is_dn && w3_time > last_traded_w3_time)
         {
            double atr = QM_ATR(_Symbol, PERIOD_H4, 14, 1);
            if(atr > 0.0)
            {
               double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
               double stop = W4H_cand + 0.30 * atr;
               double take = l_w3 - 0.618 * (h_w2 - l_w3);
               
               int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
               stop = NormalizeDouble(stop, digits);
               take = NormalizeDouble(take, digits);
               
               if(stop > entry && take < entry)
               {
                  req.type = QM_SELL;
                  req.sl = stop;
                  req.tp = take;
                  req.reason = "TD_DWAVE_W4_SELL";
                  last_traded_w3_time = w3_time;
                  last_w4_extreme = W4H_cand;
                  return true;
               }
            }
         }
      }
   }

   return false;
}

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      datetime entry_time = (datetime)PositionGetInteger(POSITION_TIME);
      int bars_passed = iBarShift(_Symbol, PERIOD_H4, entry_time);
      
      // Time stop
      if(bars_passed >= 35) return true;

      // Failure exit
      double close_1 = iClose(_Symbol, PERIOD_H4, 1);
      double w4_extreme = last_w4_extreme;
      if(w4_extreme == 0.0)
      {
         int w1 = 0, w2 = 0, w3 = 0;
         if(type == POSITION_TYPE_BUY && FindUpSkeleton(w1, w2, w3))
         {
            int t_low = 0;
            w4_extreme = LowestLow(1, w3 - 1, t_low);
         }
         else if(type == POSITION_TYPE_SELL && FindDownSkeleton(w1, w2, w3))
         {
            int t_high = 0;
            w4_extreme = HighestHigh(1, w3 - 1, t_high);
         }
      }
      if(w4_extreme > 0.0)
      {
         if(type == POSITION_TYPE_BUY && close_1 < w4_extreme) return true;
         if(type == POSITION_TYPE_SELL && close_1 > w4_extreme) return true;
      }
   }
   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
{
   if(qm_news_stale_max_hours > 336)
   {
      Print("Build guardrail violation: qm_news_stale_max_hours cannot be above 336");
      return INIT_FAILED;
   }

   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                        qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;
      
   if(!QM_FrameworkDeclareExecutionContract(PERIOD_H4, QM_FRIDAY_CLOSE_CARD_RULE, "QM5_9354 TD D-Wave Pullback"))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_9354\",\"ea\":\"demark-td-dwave-wave4-h4\"}");
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
   if(Strategy_NoTradeFilter()) return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
   {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
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
