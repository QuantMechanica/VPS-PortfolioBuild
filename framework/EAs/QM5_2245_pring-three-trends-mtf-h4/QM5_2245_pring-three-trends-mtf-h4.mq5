#property strict
#property version   "5.0"
#property description "QM5_2245 Pring Three-Trends MTF Alignment (H4 / D1 / W1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_2245
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 2245;
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
input int    strategy_sma_w1_period     = 40;
input int    strategy_sma_d1_period     = 50;
input int    strategy_ema_h4_fast       = 21;
input int    strategy_ema_h4_slow       = 55;
input int    strategy_atr_period        = 14;
input double strategy_sl_atr_mult       = 2.5;
input double strategy_trail_atr_mult   = 2.0;

// -----------------------------------------------------------------------------
// Global variables for spread buffer
// -----------------------------------------------------------------------------
static int spread_buffer[500];
static int spread_index = 0;
static bool spread_buffer_full = false;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

double GetHighestHighSinceEntry(datetime entry_time)
{
   int start_bar = iBarShift(_Symbol, PERIOD_H4, entry_time);
   if(start_bar < 0) return 0.0;
   double highs[];
   ArraySetAsSeries(highs, true);
   if(CopyHigh(_Symbol, PERIOD_H4, 0, start_bar + 1, highs) <= 0)
      return 0.0;
   double max_high = highs[0];
   for(int i = 1; i < ArraySize(highs); i++)
   {
      if(highs[i] > max_high) max_high = highs[i];
   }
   return max_high;
}

double GetLowestLowSinceEntry(datetime entry_time)
{
   int start_bar = iBarShift(_Symbol, PERIOD_H4, entry_time);
   if(start_bar < 0) return 0.0;
   double lows[];
   ArraySetAsSeries(lows, true);
   if(CopyLow(_Symbol, PERIOD_H4, 0, start_bar + 1, lows) <= 0)
      return 0.0;
   double min_low = lows[0];
   for(int i = 1; i < ArraySize(lows); i++)
   {
      if(lows[i] < min_low) min_low = lows[i];
   }
   return min_low;
}

bool Strategy_NoTradeFilter()
{
   // 1. Time filter: trade-only window 08:00-18:00 broker time
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.hour < 8 || dt.hour >= 18) return true;

   // 2. Spread filter: skip if current_spread > 1.5 * median_spread(500)
   int current_spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   spread_buffer[spread_index] = current_spread;
   spread_index = (spread_index + 1) % 500;
   if(spread_index == 0) spread_buffer_full = true;
   
   int limit = spread_buffer_full ? 500 : (spread_index > 0 ? spread_index : 1);
   int sorted_spreads[500];
   ArrayCopy(sorted_spreads, spread_buffer, 0, 0, limit);
   ArraySort(sorted_spreads);
   double median_spread = sorted_spreads[limit / 2];
   if(current_spread > 1.5 * median_spread) return true;

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

   // ATR Noise Floor
   double atr_sum = 0;
   for(int i = 1; i <= 50; i++)
   {
      atr_sum += QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, i);
   }
   double atr_sma = atr_sum / 50.0;
   double current_atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(current_atr <= 0.0 || current_atr < 0.5 * atr_sma) return false;

   // Trend directions
   double w1_close = iClose(_Symbol, PERIOD_W1, 0);
   double w1_sma = QM_SMA(_Symbol, PERIOD_W1, strategy_sma_w1_period, 0);
   if(w1_sma <= 0.0) return false;
   int primary = (w1_close > w1_sma) ? 1 : -1;

   double d1_close = iClose(_Symbol, PERIOD_D1, 0);
   double d1_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_d1_period, 0);
   if(d1_sma <= 0.0) return false;
   int secondary = (d1_close > d1_sma) ? 1 : -1;

   double h4_ema_fast = QM_EMA(_Symbol, PERIOD_H4, strategy_ema_h4_fast, 1);
   double h4_ema_slow = QM_EMA(_Symbol, PERIOD_H4, strategy_ema_h4_slow, 1);
   if(h4_ema_fast <= 0.0 || h4_ema_slow <= 0.0) return false;
   int minor = (h4_ema_fast > h4_ema_slow) ? 1 : -1;

   double close_1 = iClose(_Symbol, PERIOD_H4, 1);
   double close_2 = iClose(_Symbol, PERIOD_H4, 2);

   // Buy Setup
   if(primary > 0 && secondary > 0 && minor > 0 && close_1 > h4_ema_fast && close_1 > close_2)
   {
      // Freshness check (EMA cross within last 5 bars)
      bool fresh_cross = false;
      for(int i = 2; i <= 6; i++)
      {
         double fast = QM_EMA(_Symbol, PERIOD_H4, strategy_ema_h4_fast, i);
         double slow = QM_EMA(_Symbol, PERIOD_H4, strategy_ema_h4_slow, i);
         if(fast < slow)
         {
            fresh_cross = true;
            break;
         }
      }
      if(fresh_cross)
      {
         double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double stop = entry - strategy_sl_atr_mult * current_atr;
         int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
         stop = NormalizeDouble(stop, digits);
         
         if(stop < entry)
         {
            req.type = QM_BUY;
            req.sl = stop;
            req.tp = 0.0; // hard target: none
            req.reason = "PRING_3T_ALIGN_LONG";
            return true;
         }
      }
   }
   // Sell Setup
   else if(primary < 0 && secondary < 0 && minor < 0 && close_1 < h4_ema_fast && close_1 < close_2)
   {
      bool fresh_cross = false;
      for(int i = 2; i <= 6; i++)
      {
         double fast = QM_EMA(_Symbol, PERIOD_H4, strategy_ema_h4_fast, i);
         double slow = QM_EMA(_Symbol, PERIOD_H4, strategy_ema_h4_slow, i);
         if(fast > slow)
         {
            fresh_cross = true;
            break;
         }
      }
      if(fresh_cross)
      {
         double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double stop = entry + strategy_sl_atr_mult * current_atr;
         int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
         stop = NormalizeDouble(stop, digits);
         
         if(stop > entry)
         {
            req.type = QM_SELL;
            req.sl = stop;
            req.tp = 0.0;
            req.reason = "PRING_3T_ALIGN_SHORT";
            return true;
         }
      }
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double current_sl = PositionGetDouble(POSITION_SL);
      datetime entry_time = (datetime)PositionGetInteger(POSITION_TIME);

      int entry_bar = iBarShift(_Symbol, PERIOD_H4, entry_time);
      if(entry_bar < 0) continue;
      double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, entry_bar);
      if(atr <= 0.0) continue;

      int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

      if(type == POSITION_TYPE_BUY)
      {
         double highest_high = GetHighestHighSinceEntry(entry_time);
         if(highest_high <= 0.0) continue;

         double be_trigger = entry + 2.0 * atr;
         if(highest_high >= be_trigger)
         {
            double target_sl = entry;
            double trail_sl = highest_high - strategy_trail_atr_mult * atr;
            if(trail_sl > target_sl) target_sl = trail_sl;

            target_sl = NormalizeDouble(target_sl, digits);
            if(current_sl < target_sl || current_sl == 0.0)
            {
               MqlTradeRequest req = {};
               MqlTradeResult res = {};
               req.action = TRADE_ACTION_SLTP;
               req.position = ticket;
               req.sl = target_sl;
               req.tp = PositionGetDouble(POSITION_TP);
               OrderSend(req, res);
            }
         }
      }
      else if(type == POSITION_TYPE_SELL)
      {
         double lowest_low = GetLowestLowSinceEntry(entry_time);
         if(lowest_low <= 0.0) continue;

         double be_trigger = entry - 2.0 * atr;
         if(lowest_low <= be_trigger)
         {
            double target_sl = entry;
            double trail_sl = lowest_low + strategy_trail_atr_mult * atr;
            if(trail_sl < target_sl) target_sl = trail_sl;

            target_sl = NormalizeDouble(target_sl, digits);
            if(current_sl > target_sl || current_sl == 0.0)
            {
               MqlTradeRequest req = {};
               MqlTradeResult res = {};
               req.action = TRADE_ACTION_SLTP;
               req.position = ticket;
               req.sl = target_sl;
               req.tp = PositionGetDouble(POSITION_TP);
               OrderSend(req, res);
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
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      datetime entry_time = (datetime)PositionGetInteger(POSITION_TIME);
      
      // 1. Time stop: 60 H4 bars
      int bars_passed = iBarShift(_Symbol, PERIOD_H4, entry_time);
      if(bars_passed >= 60) return true;

      // 2. Secondary-trend break: Close[D1, 0] vs. SMA(50)[D1, 0]
      double d1_close = iClose(_Symbol, PERIOD_D1, 0);
      double d1_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_d1_period, 0);
      
      if(type == POSITION_TYPE_BUY)
      {
         if(d1_sma > 0.0 && d1_close < d1_sma) return true;
      }
      else if(type == POSITION_TYPE_SELL)
      {
         if(d1_sma > 0.0 && d1_close > d1_sma) return true;
      }

      // 3. Minor-trend break (faster exit): EMA(21)[H4, 1] vs. EMA(55)[H4, 1] AND Close[H4, 1] vs. EMA(21)[H4, 1]
      double h4_ema_fast = QM_EMA(_Symbol, PERIOD_H4, strategy_ema_h4_fast, 1);
      double h4_ema_slow = QM_EMA(_Symbol, PERIOD_H4, strategy_ema_h4_slow, 1);
      double close_1 = iClose(_Symbol, PERIOD_H4, 1);

      if(type == POSITION_TYPE_BUY)
      {
         if(h4_ema_fast > 0.0 && h4_ema_slow > 0.0 && h4_ema_fast < h4_ema_slow && close_1 < h4_ema_fast) return true;
      }
      else if(type == POSITION_TYPE_SELL)
      {
         if(h4_ema_fast > 0.0 && h4_ema_slow > 0.0 && h4_ema_fast > h4_ema_slow && close_1 > h4_ema_fast) return true;
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
      
   if(!QM_FrameworkDeclareExecutionContract(PERIOD_H4, QM_FRIDAY_CLOSE_CARD_RULE, "QM5_2245 Pring Three Trends"))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_2245\",\"ea\":\"pring-three-trends-mtf-h4\"}");
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
