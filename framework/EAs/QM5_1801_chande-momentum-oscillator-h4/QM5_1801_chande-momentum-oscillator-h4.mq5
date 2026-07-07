#property strict
#property version   "5.0"
#property description "QM5_1801 Chande Momentum Oscillator H4"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1801 chande-momentum-oscillator-h4
// -----------------------------------------------------------------------------
// Card: D:\QM\strategy_farm\artifacts\cards_approved\
//       QM5_1801_chande-momentum-oscillator-h4.md (g0_status APPROVED).
//
// Mechanics (H4, closed-bar signals):
//   CMO(P) = 100 * (SU - SD) / (SU + SD), where SU/SD are the sums of positive
//   and negative close-to-close moves over P bars. Long entries fire when CMO
//   exits oversold (-50) while H4 close is above the D1 EMA(200). Short entries
//   fire when CMO exits overbought (+50) while H4 close is below the D1 EMA(200).
//   Exits are CMO zero-line neutralisation, opposite-threshold touch, emergency
//   ATR stop, or 25-H4-bar time stop. No trailing stop.
//
// Framework helpers are used for ATR, EMA, stop construction, order open/close,
// risk sizing, magic resolution, Friday close and news gating. The only custom
// math is the bounded CMO close-to-close sum because the framework has no CMO
// reader. Raw close reads are marked perf-allowed and bounded to period+1 bars.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1801;
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
input int    strategy_cmo_period        = 20;
input double strategy_oversold_level    = -50.0;
input double strategy_overbought_level  = 50.0;
input int    strategy_d1_ema_period     = 200;
input int    strategy_atr_period        = 20;
input double strategy_atr_sl_mult       = 2.5;
input double strategy_spread_atr_mult   = 0.35;
input int    strategy_max_hold_h4_bars  = 25;

// Re-arm state from the card: after one threshold-cross entry, do not take the
// same side again until CMO reaches the opposite threshold.
int g_last_entry_side = 0; // +1 long, -1 short, 0 fully re-armed

double StrategyClose(const ENUM_TIMEFRAMES tf, const int shift)
  {
   return iClose(_Symbol, tf, shift); // perf-allowed: fixed closed-bar close read; no framework close reader exists.
  }

bool StrategyCMO(const int shift, double &out_cmo)
  {
   out_cmo = 0.0;
   if(strategy_cmo_period <= 0 || shift < 1)
      return false;

   double sum_up = 0.0;
   double sum_down = 0.0;
   for(int i = shift; i < shift + strategy_cmo_period; ++i)
     {
      const double c0 = iClose(_Symbol, PERIOD_H4, i);     // perf-allowed: bounded CMO close-to-close sum, period+1 bars.
      const double c1 = iClose(_Symbol, PERIOD_H4, i + 1); // perf-allowed: bounded CMO close-to-close sum, period+1 bars.
      if(c0 <= 0.0 || c1 <= 0.0)
         return false;

      const double diff = c0 - c1;
      if(diff > 0.0)
         sum_up += diff;
      else
         sum_down -= diff;
     }

   const double denom = sum_up + sum_down;
   if(denom <= 0.0)
      return false;

   out_cmo = 100.0 * (sum_up - sum_down) / denom;
   return true;
  }

void StrategyUpdateRearm(const double cmo_latest)
  {
   if(g_last_entry_side > 0 && cmo_latest >= strategy_overbought_level)
      g_last_entry_side = 0;
   else if(g_last_entry_side < 0 && cmo_latest <= strategy_oversold_level)
      g_last_entry_side = 0;
  }

bool StrategyFindPosition(ulong &ticket,
                          ENUM_POSITION_TYPE &position_type,
                          datetime &open_time)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   open_time = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = t;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

// Return TRUE to BLOCK trading this tick. Spread guard fails open on the .DWX
// zero modeled spread and blocks only a genuinely wide spread.
bool Strategy_NoTradeFilter()
  {
   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr <= 0.0 || strategy_spread_atr_mult <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > 0.0 && spread > strategy_spread_atr_mult * atr)
      return true;

   return false;
  }

// Caller guarantees QM_IsNewBar() == true. The card's CMO[0] maps to shift 1
// (latest closed H4 bar) because the trade is sent at the next H4 bar open.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   double cmo_0 = 0.0;
   double cmo_1 = 0.0;
   double cmo_2 = 0.0;
   if(!StrategyCMO(1, cmo_0) || !StrategyCMO(2, cmo_1) || !StrategyCMO(3, cmo_2))
      return false;

   StrategyUpdateRearm(cmo_0);

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double close_0 = StrategyClose(PERIOD_H4, 1);
   const double d1_ema = QM_EMA(_Symbol, PERIOD_D1, strategy_d1_ema_period, 1);
   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(close_0 <= 0.0 || d1_ema <= 0.0 || atr <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const bool long_signal =
      (g_last_entry_side <= 0 &&
       cmo_2 <= strategy_oversold_level &&
       cmo_1 <  strategy_oversold_level &&
       cmo_0 >  cmo_1 &&
       cmo_0 >  strategy_oversold_level &&
       close_0 > d1_ema);

   if(long_signal)
     {
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, ask, atr, strategy_atr_sl_mult);
      if(sl <= 0.0 || sl >= ask)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl;
      req.tp = 0.0;
      req.reason = "cmo_oversold_recovery_long";
      g_last_entry_side = 1;
      return true;
     }

   const bool short_signal =
      (g_last_entry_side >= 0 &&
       cmo_2 >= strategy_overbought_level &&
       cmo_1 >  strategy_overbought_level &&
       cmo_0 <  cmo_1 &&
       cmo_0 <  strategy_overbought_level &&
       close_0 < d1_ema);

   if(short_signal)
     {
      const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, bid, atr, strategy_atr_sl_mult);
      if(sl <= bid)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl;
      req.tp = 0.0;
      req.reason = "cmo_overbought_recovery_short";
      g_last_entry_side = -1;
      return true;
     }

   return false;
  }

// No trailing, break-even, scale-in, or partial close: the card uses fixed
// initial ATR stop plus signal/time exits only.
void Strategy_ManageOpenPosition()
  {
  }

// Signal exits are checked only when this EA has an open position. Time-stop is
// O(1); CMO exit math is bounded to the same 20-bar oscillator window.
bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   datetime open_time;
   if(!StrategyFindPosition(ticket, position_type, open_time))
      return false;

   const int h4_seconds = PeriodSeconds(PERIOD_H4);
   if(h4_seconds > 0 && open_time > 0 &&
      TimeCurrent() - open_time >= strategy_max_hold_h4_bars * h4_seconds)
      return true;

   double cmo_0 = 0.0;
   double cmo_1 = 0.0;
   if(!StrategyCMO(1, cmo_0) || !StrategyCMO(2, cmo_1))
      return false;

   StrategyUpdateRearm(cmo_0);

   if(position_type == POSITION_TYPE_BUY)
     {
      if(cmo_1 <= 0.0 && cmo_0 > 0.0)
         return true;
      if(cmo_0 >= strategy_overbought_level)
         return true;
     }

   if(position_type == POSITION_TYPE_SELL)
     {
      if(cmo_1 >= 0.0 && cmo_0 < 0.0)
         return true;
      if(cmo_0 <= strategy_oversold_level)
         return true;
     }

   return false;
  }

// Defer to the central news filter.
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
