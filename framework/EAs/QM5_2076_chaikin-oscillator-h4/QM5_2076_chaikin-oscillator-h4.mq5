#property strict
#property version   "5.0"
#property description "QM5_2076 Chaikin Oscillator Signal-Line Cross"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_2076
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 2076;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.5;
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
input int    strategy_chaikin_fast      = 3;
input int    strategy_chaikin_slow      = 10;
input int    strategy_atr_period        = 20;
input double strategy_atr_sl_mult       = 2.5;
input int    strategy_stddev_period     = 50;
input int    strategy_volume_mean_bars  = 50;
input int    strategy_time_stop_bars    = 50;

// -----------------------------------------------------------------------------
// Strategy Structs
// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// Strategy helpers
// -----------------------------------------------------------------------------

bool Strategy_HasOurPosition(ENUM_POSITION_TYPE &position_type, datetime &opened_at)
{
   position_type = POSITION_TYPE_BUY;
   opened_at = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
   }

   return false;
}

bool ReadChaikinData(double &co[], double &volume_mean, double &stddev_co)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, PERIOD_CURRENT, 1, 250, rates);
   if(copied < 250)
      return false;
      
   double adl[];
   ArrayResize(adl, 250);
   double current_adl = 0.0;
   
   // Calculate ADL from oldest to newest (index 249 to 0 in rates array since ArraySetAsSeries is true)
   for(int i = 249; i >= 0; --i)
   {
      double range = rates[i].high - rates[i].low;
      double mfm = 0.0;
      if(range > 0.0)
         mfm = ((rates[i].close - rates[i].low) - (rates[i].high - rates[i].close)) / range;
      current_adl += mfm * (double)rates[i].tick_volume;
      adl[249 - i] = current_adl; // adl[0] is oldest, adl[249] is newest
   }
   
   double ema3[];
   double ema10[];
   ArrayResize(ema3, 250);
   ArrayResize(ema10, 250);
   double alpha3 = 2.0 / ((double)strategy_chaikin_fast + 1.0);
   double alpha10 = 2.0 / ((double)strategy_chaikin_slow + 1.0);
   ema3[0] = adl[0];
   ema10[0] = adl[0];
   for(int i = 1; i < 250; ++i)
   {
      ema3[i] = ema3[i-1] + alpha3 * (adl[i] - ema3[i-1]);
      ema10[i] = ema10[i-1] + alpha10 * (adl[i] - ema10[i-1]);
   }
   
   ArrayResize(co, 250);
   for(int i = 0; i < 250; ++i)
      co[i] = ema3[i] - ema10[i]; // co[249] is newest (index 1 of closed bar), co[248] is index 2, etc.
      
   // Volume mean of last 50 closed bars (rates[0] to rates[49], corresponding to co[249] down to co[200])
   double vol_sum = 0.0;
   for(int i = 0; i < 50; ++i)
      vol_sum += (double)rates[i].tick_volume;
   volume_mean = vol_sum / 50.0;
   
   // StdDev of CO over last 50 closed bars
   double sum = 0.0;
   for(int i = 200; i <= 249; ++i)
      sum += co[i];
   double mean_co = sum / 50.0;
   
   double sum_sq = 0.0;
   for(int i = 200; i <= 249; ++i)
      sum_sq += (co[i] - mean_co) * (co[i] - mean_co);
   stddev_co = MathSqrt(sum_sq / 50.0);
   
   return true;
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   double atr_val = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_val <= 0.0)
      return true; // block if ATR not ready
      
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;
      
   double spread = ask - bid;
   if(spread > 0.30 * atr_val)
      return true; // skip if spread > 0.30 * ATR(20, H4)
      
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

   ENUM_POSITION_TYPE position_type;
   datetime opened_at;
   if(Strategy_HasOurPosition(position_type, opened_at))
      return false;

   double co_vals[];
   double vol_mean = 0.0;
   double stddev_co = 0.0;
   if(!ReadChaikinData(co_vals, vol_mean, stddev_co))
      return false;

   double co_current = co_vals[249]; // CO[0] in card notation
   double co_prev = co_vals[248];    // CO[-1] in card notation

   double atr_val = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_val <= 0.0)
      return false;

   // Cross-quality gate: skip if |CO[0] - CO[-1]| < 0.05 * StdDev(CO, 50)
   if(MathAbs(co_current - co_prev) < 0.05 * stddev_co)
      return false;

   // D1 regime aligned
   double ema50_d1 = QM_EMA(_Symbol, PERIOD_D1, 50, 1);
   if(ema50_d1 <= 0.0)
      return false;
   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);

   // Slope check values
   double required_slope = 0.5 * atr_val * vol_mean;

   // Check crossover and slope
   if(co_prev <= 0.0 && co_current > 0.0 && (co_current - co_prev) > required_slope)
   {
      if(close1 > ema50_d1)
      {
         req.type = QM_BUY;
         req.sl = iLow(_Symbol, PERIOD_CURRENT, 1) - strategy_atr_sl_mult * atr_val;
         req.tp = 0.0; // no fixed TP
         req.reason = "CHAIKIN_CO_LONG";
         return true;
      }
   }
   else if(co_prev >= 0.0 && co_current < 0.0 && (co_prev - co_current) > required_slope)
   {
      if(close1 < ema50_d1)
      {
         req.type = QM_SELL;
         req.sl = iHigh(_Symbol, PERIOD_CURRENT, 1) + strategy_atr_sl_mult * atr_val;
         req.tp = 0.0; // no fixed TP
         req.reason = "CHAIKIN_CO_SHORT";
         return true;
      }
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
   const int magic = QM_FrameworkMagic();
   double atr_val = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, 1);
   if(atr_val <= 0.0) return;
   
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      
      double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      
      bool activate_trail = false;
      if(pos_type == POSITION_TYPE_BUY)
      {
         double current_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(current_bid - open_price >= 2.0 * atr_val)
            activate_trail = true;
      }
      else if(pos_type == POSITION_TYPE_SELL)
      {
         double current_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(open_price - current_ask >= 2.0 * atr_val)
            activate_trail = true;
      }
      
      if(activate_trail)
      {
         QM_TM_TrailATR(ticket, strategy_atr_period, strategy_atr_sl_mult);
      }
   }
}

bool Strategy_ExitSignal()
{
   static datetime last_check_bar = 0;
   datetime current_bar_time = iTime(_Symbol, _Period, 0);
   if(current_bar_time == last_check_bar)
      return false; // only check exit signals once per closed bar
   
   ENUM_POSITION_TYPE position_type;
   datetime opened_at = 0;
   if(!Strategy_HasOurPosition(position_type, opened_at))
      return false;
      
   last_check_bar = current_bar_time;
   
   // 1. Time-stop check: count bars since entry
   if(opened_at > 0)
   {
      int bars_since_entry = iBarShift(_Symbol, _Period, opened_at, false);
      if(bars_since_entry >= strategy_time_stop_bars)
         return true; // time-stop exit
   }
   
   // Read Chaikin and Volume data
   double co_vals[];
   double vol_mean = 0.0;
   double stddev_co = 0.0;
   if(!ReadChaikinData(co_vals, vol_mean, stddev_co))
      return false;
      
   double atr_val = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_val <= 0.0)
      return false;
      
   // co_vals[249] is CO[0] (just-closed bar)
   // co_vals[248] is CO[-1] (previous bar)
   double co_current = co_vals[249];
   double co_prev = co_vals[248];
   
   // Check Opposite zero-line cross
   if(position_type == POSITION_TYPE_BUY)
   {
      if(co_prev >= 0.0 && co_current < 0.0 && (co_prev - co_current) > 0.5 * atr_val * vol_mean)
         return true;
   }
   else if(position_type == POSITION_TYPE_SELL)
   {
      if(co_prev <= 0.0 && co_current > 0.0 && (co_current - co_prev) > 0.5 * atr_val * vol_mean)
         return true;
   }
   
   // Check Pressure-acceleration divergence
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, _Period, 1, 250, rates) < 250)
      return false;
      
   if(position_type == POSITION_TYPE_BUY)
   {
      double max_high = -DBL_MAX;
      double max_co_prev = -DBL_MAX;
      for(int i = 1; i <= 13; ++i) // previous 13 bars (rates[1] to rates[13] in series array)
      {
         if(rates[i].high > max_high) max_high = rates[i].high;
         // co_vals[249] is rates[0], co_vals[248] is rates[1], ..., co_vals[249 - i] is rates[i]
         if(co_vals[249 - i] > max_co_prev) max_co_prev = co_vals[249 - i];
      }
      if(rates[0].high > max_high && co_current < max_co_prev)
         return true;
   }
   else if(position_type == POSITION_TYPE_SELL)
   {
      double min_low = DBL_MAX;
      double min_co_prev = DBL_MAX;
      for(int i = 1; i <= 13; ++i) // previous 13 bars
      {
         if(rates[i].low < min_low) min_low = rates[i].low;
         if(co_vals[249 - i] < min_co_prev) min_co_prev = co_vals[249 - i];
      }
      if(rates[0].low < min_low && co_current > min_co_prev)
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
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { QM_FrameworkShutdown(); }

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
