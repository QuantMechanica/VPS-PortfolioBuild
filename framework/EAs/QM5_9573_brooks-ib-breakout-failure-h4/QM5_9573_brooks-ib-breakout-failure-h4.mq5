#property strict
#property version   "5.0"
#property description "QM5_9573 Brooks Inside-Bar Breakout Failure H4"

#include <QM/QM_Common.mqh>

// QM5_9573 — Brooks inside-bar breakout failure on H4.
// Card: D:/QM/strategy_farm/artifacts/cards_approved/QM5_9573_brooks-ib-breakout-failure-h4.md
// Mechanic:
//   - Mother bar is large but not a spike, followed by a strict inside bar.
//   - The breakout bar pushes beyond the mother by an ATR buffer.
//   - The same bar or the next closed bar fails back inside the mother and
//     closes in the failure half, then the EA fades the failed breakout.
//   - Static structure SL/TP, TP capped at 2.5R, time stop after 10 H4 bars.

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9573;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal      = QM_NEWS_TEMPORAL_PRE60_POST60;
input QM_NewsComplianceProfile qm_news_compliance    = QM_NEWS_COMPLIANCE_DXZ;
input int                      qm_news_stale_max_hours = 336;
input string                   qm_news_min_impact      = "high";
input QM_NewsMode              qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_atr_period         = 14;
input double strategy_mother_atr_min     = 0.80;
input double strategy_mother_atr_max     = 2.50;
input double strategy_inside_range_max   = 0.65;
input double strategy_break_atr_mult     = 0.10;
input double strategy_failure_atr_mult   = 0.05;
input double strategy_sl_atr_mult        = 0.30;
input double strategy_spread_atr_mult    = 0.20;
input double strategy_max_rr             = 2.50;
input int    strategy_time_stop_h4_bars  = 10;

int Strategy_SymbolSlot()
  {
   if(_Symbol == "EURUSD.DWX") return 0;
   if(_Symbol == "GBPUSD.DWX") return 1;
   if(_Symbol == "USDJPY.DWX") return 2;
   if(_Symbol == "AUDUSD.DWX") return 3;
   if(_Symbol == "USDCAD.DWX") return 4;
   if(_Symbol == "USDCHF.DWX") return 5;
   if(_Symbol == "NZDUSD.DWX") return 6;
   if(_Symbol == "XAUUSD.DWX") return 7;
   if(_Symbol == "XTIUSD.DWX") return 8;
   if(_Symbol == "GDAXI.DWX")  return 9;
   if(_Symbol == "NDX.DWX")    return 10;
   if(_Symbol == "WS30.DWX")   return 11;
   if(_Symbol == "UK100.DWX")  return 12;
   return -1;
  }

bool Strategy_ValidInputs()
  {
   return (strategy_atr_period > 0 &&
           strategy_mother_atr_min > 0.0 &&
           strategy_mother_atr_max >= strategy_mother_atr_min &&
           strategy_inside_range_max > 0.0 &&
           strategy_inside_range_max < 1.0 &&
           strategy_break_atr_mult > 0.0 &&
           strategy_failure_atr_mult > 0.0 &&
           strategy_sl_atr_mult > 0.0 &&
           strategy_spread_atr_mult > 0.0 &&
           strategy_max_rr > 0.0 &&
           strategy_time_stop_h4_bars > 0);
  }

bool Strategy_HaveOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

double Strategy_High(const int shift)
  {
   return iHigh(_Symbol, PERIOD_H4, shift); // perf-allowed: closed H4 OHLC structural pattern read.
  }

double Strategy_Low(const int shift)
  {
   return iLow(_Symbol, PERIOD_H4, shift); // perf-allowed: closed H4 OHLC structural pattern read.
  }

double Strategy_Close(const int shift)
  {
   return iClose(_Symbol, PERIOD_H4, shift); // perf-allowed: closed H4 OHLC structural pattern read.
  }

bool Strategy_SpreadAllowed(const double atr)
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid || atr <= 0.0)
      return false;
   return ((ask - bid) <= strategy_spread_atr_mult * atr);
  }

bool Strategy_ResolveFailurePattern(const int failure_shift,
                                    const int breakout_shift,
                                    const int inside_shift,
                                    const int mother_shift,
                                    int &direction,
                                    double &stop_loss,
                                    double &take_profit,
                                    string &reason)
  {
   direction = 0;
   stop_loss = 0.0;
   take_profit = 0.0;
   reason = "";

   const double mother_high = Strategy_High(mother_shift);
   const double mother_low  = Strategy_Low(mother_shift);
   const double inside_high = Strategy_High(inside_shift);
   const double inside_low  = Strategy_Low(inside_shift);
   const double break_high  = Strategy_High(breakout_shift);
   const double break_low   = Strategy_Low(breakout_shift);
   const double fail_high   = Strategy_High(failure_shift);
   const double fail_low    = Strategy_Low(failure_shift);
   const double fail_close  = Strategy_Close(failure_shift);
   if(mother_high <= 0.0 || mother_low <= 0.0 ||
      inside_high <= 0.0 || inside_low <= 0.0 ||
      break_high <= 0.0 || break_low <= 0.0 ||
      fail_high <= 0.0 || fail_low <= 0.0 || fail_close <= 0.0)
      return false;

   const double mother_range = mother_high - mother_low;
   const double inside_range = inside_high - inside_low;
   if(mother_range <= 0.0 || inside_range <= 0.0)
      return false;

   const double atr_mother_ref = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, mother_shift + 1);
   const double atr_break_ref  = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, breakout_shift + 1);
   const double atr_failure    = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, failure_shift);
   if(atr_mother_ref <= 0.0 || atr_break_ref <= 0.0 || atr_failure <= 0.0)
      return false;

   if(mother_range < strategy_mother_atr_min * atr_mother_ref)
      return false;
   if(mother_range > strategy_mother_atr_max * atr_mother_ref)
      return false;
   if(inside_high >= mother_high || inside_low <= mother_low)
      return false;
   if(inside_range > strategy_inside_range_max * mother_range)
      return false;

   const bool up_break = (break_high > mother_high + strategy_break_atr_mult * atr_break_ref);
   const bool down_break = (break_low < mother_low - strategy_break_atr_mult * atr_break_ref);
   if(up_break == down_break)
      return false;
   if(!Strategy_SpreadAllowed(atr_failure))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double failure_mid = 0.5 * (fail_high + fail_low);

   if(up_break)
     {
      if(fail_close >= mother_high - strategy_failure_atr_mult * atr_failure)
         return false;
      if(fail_close > failure_mid)
         return false;

      const double entry = bid;
      const double sl_raw = MathMax(break_high, fail_high) + strategy_sl_atr_mult * atr_failure;
      double target = mother_low;
      const double risk = sl_raw - entry;
      if(entry <= 0.0 || risk <= 0.0 || target >= entry)
         return false;

      const double rr_cap = entry - strategy_max_rr * risk;
      if(target < rr_cap)
         target = rr_cap;

      stop_loss = QM_StopRulesNormalizePrice(_Symbol, sl_raw);
      take_profit = QM_StopRulesNormalizePrice(_Symbol, target);
      if(stop_loss <= entry || take_profit >= entry)
         return false;

      direction = -1;
      reason = (failure_shift == breakout_shift) ? "QM5_9573_SHORT_SAMEBAR_FAIL" : "QM5_9573_SHORT_NEXTBAR_FAIL";
      return true;
     }

   if(fail_close <= mother_low + strategy_failure_atr_mult * atr_failure)
      return false;
   if(fail_close < failure_mid)
      return false;

   const double entry = ask;
   const double sl_raw = MathMin(break_low, fail_low) - strategy_sl_atr_mult * atr_failure;
   double target = mother_high;
   const double risk = entry - sl_raw;
   if(entry <= 0.0 || risk <= 0.0 || target <= entry)
      return false;

   const double rr_cap = entry + strategy_max_rr * risk;
   if(target > rr_cap)
      target = rr_cap;

   stop_loss = QM_StopRulesNormalizePrice(_Symbol, sl_raw);
   take_profit = QM_StopRulesNormalizePrice(_Symbol, target);
   if(stop_loss >= entry || take_profit <= entry)
      return false;

   direction = 1;
   reason = (failure_shift == breakout_shift) ? "QM5_9573_LONG_SAMEBAR_FAIL" : "QM5_9573_LONG_NEXTBAR_FAIL";
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   if((ENUM_TIMEFRAMES)_Period != PERIOD_H4)
      return true;

   const int slot = Strategy_SymbolSlot();
   if(slot < 0)
      return true;
   if(slot != qm_magic_slot_offset)
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

   if(!Strategy_ValidInputs())
      return false;
   if(Strategy_HaveOpenPosition())
      return false;

   int direction = 0;
   double sl = 0.0;
   double tp = 0.0;
   string reason = "";

   // Same-bar failure: mother shift 3, inside shift 2, breakout/failure shift 1.
   if(!Strategy_ResolveFailurePattern(1, 1, 2, 3, direction, sl, tp, reason))
     {
      // Next-bar failure: mother shift 4, inside shift 3, breakout shift 2, failure shift 1.
      if(!Strategy_ResolveFailurePattern(1, 2, 3, 4, direction, sl, tp, reason))
         return false;
     }

   if(direction > 0)
      req.type = QM_BUY;
   else if(direction < 0)
      req.type = QM_SELL;
   else
      return false;

   req.sl = sl;
   req.tp = tp;
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const int h4_seconds = PeriodSeconds(PERIOD_H4);
   if(h4_seconds <= 0 || strategy_time_stop_h4_bars <= 0)
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

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 &&
         (TimeCurrent() - opened) >= (long)strategy_time_stop_h4_bars * h4_seconds)
         return true;
     }

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
   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
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
