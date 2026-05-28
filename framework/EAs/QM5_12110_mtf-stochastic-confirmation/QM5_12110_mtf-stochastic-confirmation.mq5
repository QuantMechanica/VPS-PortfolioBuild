#property strict
#property version   "5.0"
#property description "QM5_12110 mtf-stochastic-confirmation"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12110;
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
input int    ema_period            = 200;
input double atr_sl_mult           = 2.0;
input double rr_target             = 1.5;
input int    max_spread_points     = 25;

// ----------------------------------------------------------------------
// Helper functions
// ----------------------------------------------------------------------

// ----------------------------------------------------------------------
// MTF Stochastic helpers
// ----------------------------------------------------------------------
void StochOnTF(const ENUM_TIMEFRAMES tf, double &out_k, double &out_d, const int shift)
{
   const int handle = iStochastic(_Symbol, tf, stoch_k, stoch_d, stoch_slowing, MODE_SMA, STO_CLOSECLOSE);
   if(handle == INVALID_HANDLE) { out_k = 50.0; out_d = 50.0; return; }
   double k_buf[], d_buf[];
   ArraySetAsSeries(k_buf, true);
   ArraySetAsSeries(d_buf, true);
   CopyBuffer(handle, 0, shift + 1, 2, k_buf);
   CopyBuffer(handle, 1, shift + 1, 2, d_buf);
   IndicatorRelease(handle);
   out_k = k_buf[0];
   out_d = d_buf[0];
}

bool StochH1BullishCross(const int shift)
{
   double k1, d1, k2, d2;
   StochOnTF(PERIOD_H1, k1, d1, shift);
   StochOnTF(PERIOD_H1, k2, d2, shift + 1);
   return (k1 > d1 && k2 <= d2);
}

bool StochH1BearishCross(const int shift)
{
   double k1, d1, k2, d2;
   StochOnTF(PERIOD_H1, k1, d1, shift);
   StochOnTF(PERIOD_H1, k2, d2, shift + 1);
   return (k1 < d1 && k2 >= d2);
}

double EMAValue(const int period, const int shift)
{
   const int handle = iMA(_Symbol, PERIOD_H1, period, 0, MODE_EMA, PRICE_CLOSE);
   if(handle == INVALID_HANDLE) return 0.0;
   double val[1];
   CopyBuffer(handle, 0, shift + 1, 1, val);
   IndicatorRelease(handle);
   return val[0];
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

void CloseAll(const QM_ExitReason reason)
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
      if(spread > max_spread_points) return true;
   }
   return false;

  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // H1 cross
   if(!StochH1BullishCross(0) && !StochH1BearishCross(0))
      return false;

   // H4 reading
   double h4_k, h4_d;
   StochOnTF(PERIOD_H4, h4_k, h4_d, 1);

   // D1 reading
   double d1_k, d1_d;
   StochOnTF(PERIOD_D1, d1_k, d1_d, 1);

   const double close = iClose(_Symbol, PERIOD_H1, 1);
   if(close <= 0) return false;

   const double ema = EMAValue(ema_period, 0);
   if(ema <= 0) return false;

   bool long_signal = false, short_signal = false;
   if(StochH1BullishCross(0) && h4_k > 50 && h4_k > h4_d && d1_k > 50 && close > ema)
      long_signal = true;
   else if(StochH1BearishCross(0) && h4_k < 50 && h4_k < h4_d && d1_k < 50 && close < ema)
      short_signal = true;
   else
      return false;

   if(HasPosition())
   {
      // Check for flip
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
         const ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         if((pt == POSITION_TYPE_BUY && short_signal) || (pt == POSITION_TYPE_SELL && long_signal))
            QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
         else
            return false; // D1 macro still aligned
      }
   }

   const double entry = long_signal ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                    : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, PERIOD_H1, 14, 1);
   if(atr <= 0) return false;
   const double sl = long_signal ? entry - atr * atr_sl_mult : entry + atr * atr_sl_mult;
   const double tp = long_signal ? entry + (entry - sl) * rr_target : entry - (sl - entry) * rr_target;

   req.type = long_signal ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = long_signal ? "MTF_STOCH_LONG" : "MTF_STOCH_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;

  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   if(!HasPosition()) return false;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      // H1 opposite cross
      if((pt == POSITION_TYPE_BUY && StochH1BearishCross(0)) ||
         (pt == POSITION_TYPE_SELL && StochH1BullishCross(0)))
      {
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
         continue;
      }

      // D1 macro flip
      double d1_k, d1_d;
      StochOnTF(PERIOD_D1, d1_k, d1_d, 1);
      if((pt == POSITION_TYPE_BUY && d1_k < 50) || (pt == POSITION_TYPE_SELL && d1_k > 50))
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
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12110\",\"strategy\":\"mtf-stochastic-confirmation\"}");
   return INIT_SUCCEEDED;
  }


void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {{
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
   {{
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
   }}
  }}


void OnTimer() {{ QM_FrameworkOnTimer(); }}
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
  {{ QM_FrameworkOnTradeTransaction(trans, request, result); }}
double OnTester() {{ QM_ChartUI_Refresh(); return QM_DefaultObjective(); }}

