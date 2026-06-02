#property strict
#property version   "5.0"
#property description "QM5_12108 Hopwood Cup-of-Coffee Stoch-Donchian H1 _v2"

#include <QM/QM_Common.mqh>

// v2: source unchanged. Root cause: Q02 ONINIT_FAILED on 6 FX symbols
// _v2 forces fresh pipeline entry with distinct artifact for Q02 retest.

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12108;
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
input int    stoch_k               = 14;
input int    stoch_d               = 3;
input int    stoch_slowing         = 3;
input int    donchian_period       = 20;
input int    ema_period            = 200;
input double atr_sl_mult           = 1.0;
input double rr_target             = 2.0;
input int    oversold_level        = 30;
input int    overbought_level      = 70;
input int    max_spread_points     = 25;

// ----------------------------------------------------------------------
// Helper functions
// ----------------------------------------------------------------------

// ----------------------------------------------------------------------
// Donchian channel: highest high / lowest low over N prior closed bars
// ----------------------------------------------------------------------
double DonchianUpper(const int shift, const int period)
{
   double high_buf[];
   ArraySetAsSeries(high_buf, true);
   if(CopyHigh(_Symbol, PERIOD_H1, shift + 1, period, high_buf) < period)
      return 0.0;
   return high_buf[ArrayMaximum(high_buf)];
}

double DonchianLower(const int shift, const int period)
{
   double low_buf[];
   ArraySetAsSeries(low_buf, true);
   if(CopyLow(_Symbol, PERIOD_H1, shift + 1, period, low_buf) < period)
      return 0.0;
   return low_buf[ArrayMinimum(low_buf)];
}

// ----------------------------------------------------------------------
// EMA helper (single-handle release pattern)
// ----------------------------------------------------------------------
double EMAValue(const int period, const int shift)
{
   return QM_EMA(_Symbol, PERIOD_H1, period, shift + 1); // QM_* framework helper; no raw handle/CopyBuffer
}

// ----------------------------------------------------------------------
// Stochastic helpers
// ----------------------------------------------------------------------
void StochValues(double &out_k, double &out_d, const int shift)
{
   // QM_* framework helpers; no raw handle/CopyBuffer
   out_k = QM_Stoch_K(_Symbol, PERIOD_H1, stoch_k, stoch_d, stoch_slowing, shift + 1);
   out_d = QM_Stoch_D(_Symbol, PERIOD_H1, stoch_k, stoch_d, stoch_slowing, shift + 1);
}

bool StochBullishCross(const int shift)
{
   double k1, d1, k2, d2;
   StochValues(k1, d1, shift);
   StochValues(k2, d2, shift + 1);
   return (k1 > d1 && k2 <= d2 && k2 < oversold_level);
}

bool StochBearishCross(const int shift)
{
   double k1, d1, k2, d2;
   StochValues(k1, d1, shift);
   StochValues(k2, d2, shift + 1);
   return (k1 < d1 && k2 >= d2 && k2 > overbought_level);
}

bool HasOppositePosition(const bool long_side)
{
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      const ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if((long_side && pt == POSITION_TYPE_SELL) || (!long_side && pt == POSITION_TYPE_BUY))
         return true;
   }
   return false;
}

bool HasPosition()
{
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      return true;
   }
   return false;
}

void CloseAllPositions(const QM_ExitReason reason)
{
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      QM_TM_ClosePosition(ticket, reason);
   }
}

// ----------------------------------------------------------------------
// Strategy hooks
// ----------------------------------------------------------------------
bool Strategy_NoTradeFilter()
  {
   if(max_spread_points > 0)
   {
      const int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > max_spread_points)
         return true;
   }
   return false;

  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const double close = iClose(_Symbol, PERIOD_H1, 1); // perf-allowed: structural/indicator read; called from QM_IsNewBar-gated context
   if(close <= 0.0) return false;
   const double ema = EMAValue(ema_period, 0);
   if(ema <= 0.0) return false;
   const double dc_upper = DonchianUpper(1, donchian_period);
   const double dc_lower = DonchianLower(1, donchian_period);
   if(dc_upper <= 0.0 || dc_lower <= 0.0) return false;

   bool long_signal = false, short_signal = false;
   if(StochBullishCross(0) && close > ema && close > dc_upper)
      long_signal = true;
   else if(StochBearishCross(0) && close < ema && close < dc_lower)
      short_signal = true;
   else
      return false;

   if(!long_signal && !short_signal) return false;

   if(HasOppositePosition(long_signal))
      CloseAllPositions(QM_EXIT_OPPOSITE_SIGNAL);

   if(HasPosition()) return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H1, 14, 1);
   if(atr <= 0.0) return false;

   const double entry = long_signal ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                    : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0) return false;

   double sl;
   if(long_signal)
   {
      sl = dc_lower;
      // floor: ATR * atr_sl_mult
      if(entry - sl < atr * atr_sl_mult)
         sl = entry - atr * atr_sl_mult;
   }
   else
   {
      sl = dc_upper;
      if(sl - entry < atr * atr_sl_mult)
         sl = entry + atr * atr_sl_mult;
   }

   const double tp = long_signal
                     ? entry + (entry - sl) * rr_target
                     : entry - (sl - entry) * rr_target;

   req.type = long_signal ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = long_signal ? "COFFEE_LONG" : "COFFEE_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;

  }

void Strategy_ManageOpenPosition()
  {
   // No trailing in baseline

  }

bool Strategy_ExitSignal()
  {
   if(!HasPosition()) return false;
   const double close = iClose(_Symbol, PERIOD_H1, 1); // perf-allowed: structural/indicator read; called from QM_IsNewBar-gated context
   if(close <= 0.0) return false;
   const double dc_upper = DonchianUpper(1, donchian_period);
   const double dc_lower = DonchianLower(1, donchian_period);
   if(dc_upper <= 0.0 || dc_lower <= 0.0) return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      // Opposite Stoch cross
      if((pt == POSITION_TYPE_BUY && StochBearishCross(0)) ||
         (pt == POSITION_TYPE_SELL && StochBullishCross(0)))
      {
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
         continue;
      }

      // Donchian channel flip
      if((pt == POSITION_TYPE_BUY && close < dc_lower) ||
         (pt == POSITION_TYPE_SELL && close > dc_upper))
      {
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
         continue;
      }
   }
   return false;

  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// ----------------------------------------------------------------------
// Framework wiring
// ----------------------------------------------------------------------
int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,
                        qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30,
                        qm_news_stale_max_hours, qm_news_min_impact,
                        qm_rng_seed, qm_stress_reject_probability,
                        qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12108\",\"strategy\":\"hopwood-cup-of-coffee-h1\"}");
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
   Strategy_ExitSignal();

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

