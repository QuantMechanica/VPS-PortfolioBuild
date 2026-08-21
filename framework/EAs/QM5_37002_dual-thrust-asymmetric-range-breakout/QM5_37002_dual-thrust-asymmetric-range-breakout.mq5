#property strict
#property version   "5.0"
#property description "QM5_37002 Dual Thrust Asymmetric Range Breakout (Michael Chalek)"
// Strategy Card: QM5_37002 (dual-thrust-asymmetric-range-breakout), G0 APPROVED.
// Source: Chalek, M. & QuantConnect Research. Dual Thrust Algorithmic Performance Benchmarks.

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_37002 — Dual Thrust Asymmetric Range Breakout
// -----------------------------------------------------------------------------
// Asymmetric range breakout on D1 bars:
//   - Range = max(HH_N - LC_N, HC_N - LL_N) over N closed daily bars
//   - Buy_Trigger  = Open + k1 * Range
//   - Sell_Trigger = Open - k2 * Range
//
// Long Entry:  Close[1] > Buy_Trigger  -> market buy
// Short Entry: Close[1] < Sell_Trigger -> market sell
// Exit Signal: Long exits on Close[1] < Sell_Trigger or Max Hold Bars reached
//              Short exits on Close[1] > Buy_Trigger or Max Hold Bars reached
// Initial Stop: Fixed ATR(14) stop at 2.0 * ATR(14)
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 37002;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
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
input int    strategy_lookback_days       = 4;      // Dual Thrust lookback window (days)
input double strategy_k1                  = 0.50;   // Buy trigger range multiplier
input double strategy_k2                  = 0.50;   // Sell trigger range multiplier
input int    strategy_atr_period          = 14;     // ATR period for stop loss and spread filter
input double strategy_sl_atr_mult         = 2.00;   // Stop loss ATR multiplier
input int    strategy_max_hold_bars       = 5;      // Maximum hold time in D1 bars
input double strategy_spread_atr_mult     = 1.80;   // Spread filter ATR multiplier
input int    strategy_max_spread_points   = 300;    // Absolute spread cap in points

// -----------------------------------------------------------------------------
// Dual Thrust Calculation Helper
// -----------------------------------------------------------------------------

struct DualThrust_Levels
{
   bool   valid;
   double range;
   double buy_trigger;
   double sell_trigger;
};

DualThrust_Levels CalculateDualThrust(const string sym, const int lookback, const double k1, const double k2)
{
   DualThrust_Levels res;
   res.valid = false;
   res.range = 0.0;
   res.buy_trigger = 0.0;
   res.sell_trigger = 0.0;

   if(lookback < 1 || k1 <= 0.0 || k2 <= 0.0)
      return res;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(sym, PERIOD_D1, 1, lookback + 1, rates) < lookback + 1) // perf-allowed: closed-bar Dual Thrust rates vector
      return res;

   double hh = -1e9;
   double hc = -1e9;
   double ll = 1e9;
   double lc = 1e9;

   for(int i = 0; i < lookback; ++i)
   {
      if(rates[i].high > hh) hh = rates[i].high;
      if(rates[i].close > hc) hc = rates[i].close;
      if(rates[i].low < ll)  ll = rates[i].low;
      if(rates[i].close < lc) lc = rates[i].close;
   }

   if(hh <= ll || hc <= lc)
      return res;

   double range1 = hh - lc;
   double range2 = hc - ll;
   double range = MathMax(range1, range2);
   if(range <= 0.0)
      return res;

   double ref_open = rates[0].open;

   res.range = range;
   res.buy_trigger = ref_open + k1 * range;
   res.sell_trigger = ref_open - k2 * range;
   res.valid = true;
   return res;
}

bool IsRolloverBlackout()
{
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);
   int minute_of_day = dt.hour * 60 + dt.min;
   if(minute_of_day >= 1435 || minute_of_day <= 5)
      return true;
   return false;
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   if(IsRolloverBlackout())
      return true;

   const double atr_1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask > 0.0 && bid > 0.0 && ask > bid)
   {
      if(atr_1 > 0.0 && (ask - bid) > (strategy_spread_atr_mult * atr_1))
         return true;
      if(point > 0.0 && strategy_max_spread_points > 0 && (ask - bid) > (strategy_max_spread_points * point))
         return true;
   }
   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   req.type               = QM_BUY;
   req.price              = 0.0;
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   DualThrust_Levels dt = CalculateDualThrust(_Symbol, strategy_lookback_days, strategy_k1, strategy_k2);
   if(!dt.valid)
      return false;

   const double close1 = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: closed D1 bar close reference
   if(close1 <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(close1 > dt.buy_trigger)
   {
      req.type   = QM_BUY;
      req.reason = "QM5_37002_DUALTHRUST_BUY";
      req.sl     = QM_StopATR(_Symbol, QM_BUY, ask, strategy_atr_period, strategy_sl_atr_mult);
   }
   else if(close1 < dt.sell_trigger)
   {
      req.type   = QM_SELL;
      req.reason = "QM5_37002_DUALTHRUST_SELL";
      req.sl     = QM_StopATR(_Symbol, QM_SELL, bid, strategy_atr_period, strategy_sl_atr_mult);
   }
   else
   {
      return false;
   }

   if(req.sl <= 0.0)
      return false;

   return true;
}

void Strategy_ManageOpenPosition()
{
}

bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   int open_dir = 0;
   datetime open_time = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      open_dir = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      break;
   }

   if(open_dir == 0)
      return false;

   DualThrust_Levels dt = CalculateDualThrust(_Symbol, strategy_lookback_days, strategy_k1, strategy_k2);
   if(dt.valid)
   {
      const double close1 = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: closed D1 bar close reference
      if(close1 > 0.0)
      {
         if(open_dir > 0 && close1 < dt.sell_trigger)
            return true;
         if(open_dir < 0 && close1 > dt.buy_trigger)
            return true;
      }
   }

   if(open_time > 0 && strategy_max_hold_bars > 0)
   {
      int hold_seconds = (int)(TimeCurrent() - open_time);
      int max_hold_seconds = strategy_max_hold_bars * PeriodSeconds(PERIOD_D1);
      if(hold_seconds >= max_hold_seconds)
         return true;
   }

   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time)
{
   return false;
}

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_37002_dual_thrust_breakout\"}");
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
         ulong ticket = PositionGetTicket(i);
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
