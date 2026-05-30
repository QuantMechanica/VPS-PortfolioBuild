#property strict
#property version   "5.0"
#property description "QM5_12111 bressert-double-stochastic-h1"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12111;
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
input int    raw_stoch_k           = 13;
input int    raw_stoch_d           = 5;
input int    raw_stoch_slowing     = 3;
input int    dss_period            = 8;
input int    dss_slowing           = 3;
input int    ema_period            = 200;
input double atr_sl_mult           = 2.0;
input double rr_target             = 2.0;
input int    oversold_level        = 20;
input int    overbought_level      = 80;
input int    max_spread_points     = 25;

// ----------------------------------------------------------------------
// Helper functions
// ----------------------------------------------------------------------

// ----------------------------------------------------------------------
// Double-Stochastic (DSS) — inline computation
// ----------------------------------------------------------------------
void ComputeDSS(double &dss_k, double &dss_d, const int shift)
{
   // Stage 1: raw Stoch %K
   const int handle1 = iStochastic(_Symbol, PERIOD_H1, raw_stoch_k, raw_stoch_d, raw_stoch_slowing, MODE_SMA, STO_CLOSECLOSE);
   if(handle1 == INVALID_HANDLE) { dss_k = 50; dss_d = 50; return; }
   double raw_k_buf[];
   ArraySetAsSeries(raw_k_buf, true);
   const int raw_count = dss_period * 2 + dss_slowing + 2;
   const int ck = CopyBuffer(handle1, 0, shift + 1, raw_count, raw_k_buf);
   IndicatorRelease(handle1);
   if(ck < raw_count) { dss_k = 50; dss_d = 50; return; }

   // Stage 2: manual 'Stochastic' on raw_k_buf (highest/lowest of last N)
   double dss_raw_buf[];
   ArrayResize(dss_raw_buf, ck);
   for(int i = 0; i < ck - dss_period + 1; i++)
   {
      double highest = raw_k_buf[i], lowest = raw_k_buf[i];
      for(int j = 0; j < dss_period; j++)
      {
         if(raw_k_buf[i + j] > highest) highest = raw_k_buf[i + j];
         if(raw_k_buf[i + j] < lowest)  lowest  = raw_k_buf[i + j];
      }
      const double range = highest - lowest;
      dss_raw_buf[i] = (range > 0) ? (raw_k_buf[i] - lowest) / range * 100.0 : 50.0;
   }

   // Apply 3-period smoothing (slowing)
   const int dss_len = ck - dss_period + 1;
   if(dss_len < dss_slowing + 1) { dss_k = 50; dss_d = 50; return; }
   double smoothed[];
   ArrayResize(smoothed, dss_len);
   for(int i = 0; i < dss_len; i++)
   {
      double sum = 0;
      int cnt = 0;
      for(int j = 0; j < dss_slowing && i + j < dss_len; j++)
      { sum += dss_raw_buf[i + j]; cnt++; }
      smoothed[i] = (cnt > 0) ? sum / cnt : 50.0;
   }

   dss_k = smoothed[0];                    // %K
   dss_d = (dss_len >= 2) ? smoothed[1] : smoothed[0];  // %D (shifted)
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
   double dss_k1, dss_d1, dss_k2, dss_d2;
   ComputeDSS(dss_k1, dss_d1, 0);
   ComputeDSS(dss_k2, dss_d2, 1);

   const double close = iClose(_Symbol, PERIOD_H1, 1);
   if(close <= 0) return false;

   const double ema = EMAValue(ema_period, 0);
   if(ema <= 0) return false;

   // Cross detection
   const bool bull_cross = (dss_k1 > dss_d1 && dss_k2 <= dss_d2 && dss_k2 < oversold_level);
   const bool bear_cross = (dss_k1 < dss_d1 && dss_k2 >= dss_d2 && dss_k2 > overbought_level);

   bool long_signal = false, short_signal = false;
   if(bull_cross && close > ema)
      long_signal = true;
   else if(bear_cross && close < ema)
      short_signal = true;
   else
      return false;

   if(HasPosition())
   {
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
            return false;
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
   req.reason = long_signal ? "DSS_LONG" : "DSS_SHORT";
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
   double dss_k, dss_d;
   ComputeDSS(dss_k, dss_d, 0);
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      const ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      // Opposite cross
      if((pt == POSITION_TYPE_BUY && dss_k < dss_d) ||
         (pt == POSITION_TYPE_SELL && dss_k > dss_d))
      {
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
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
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12111\",\"strategy\":\"bressert-double-stochastic-h1\"}");
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

