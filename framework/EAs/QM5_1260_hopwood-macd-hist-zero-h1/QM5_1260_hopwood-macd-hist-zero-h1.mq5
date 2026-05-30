#property strict
#property version   "5.0"
#property description "QM5_1260 Hopwood MACD-Histogram Zero-Cross H1 Trend-Follower"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1260;
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
input int    strategy_macd_fast          = 12;
input int    strategy_macd_slow          = 26;
input int    strategy_macd_signal        = 9;
input int    strategy_ema_period         = 200;
input double strategy_atr_sl_mult        = 2.0;
input double strategy_rr_target          = 2.0;
input double strategy_hist_collapse_frac = 0.25;
input int    strategy_hist_lookback      = 20;
input int    strategy_collapse_bars      = 3;
input int    strategy_max_spread_points  = 25;

double Histogram(const int shift)
{
   const int handle = iMACD(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, PRICE_CLOSE);
   if (handle == INVALID_HANDLE) return 0.0;
   double macd[1], signal[1];
   const int c1 = CopyBuffer(handle, 0, shift + 1, 1, macd);
   const int c2 = CopyBuffer(handle, 1, shift + 1, 1, signal);
   IndicatorRelease(handle);
   if (c1 != 1 || c2 != 1) return 0.0;
   return macd[0] - signal[0];
}

double EMA200(const int shift)
{
   const int handle = iMA(_Symbol, PERIOD_H1, strategy_ema_period, 0, MODE_EMA, PRICE_CLOSE);
   if (handle == INVALID_HANDLE) return 0.0;
   double val[1];
   const int copied = CopyBuffer(handle, 0, shift + 1, 1, val);
   IndicatorRelease(handle);
   if (copied != 1) return 0.0;
   return val[0];
}

double MaxAbsHist(const int lookback)
{
   double max_val = 0.0;
   for (int i = 0; i < lookback; ++i)
   {
      const double h = Histogram(i);
      const double abs_h = MathAbs(h);
      if (abs_h > max_val) max_val = abs_h;
   }
   return max_val;
}

bool CrossedAboveZero(const int shift)
{
   const double h1 = Histogram(shift);
   const double h2 = Histogram(shift + 1);
   return (h1 > 0.0 && h2 <= 0.0);
}

bool CrossedBelowZero(const int shift)
{
   const double h1 = Histogram(shift);
   const double h2 = Histogram(shift + 1);
   return (h1 < 0.0 && h2 >= 0.0);
}

bool HistogramCollapsed(const int shift)
{
   const double max_abs = MaxAbsHist(strategy_hist_lookback);
   if (max_abs <= 0.0) return false;
   const double threshold = max_abs * strategy_hist_collapse_frac;
   int collapsed = 0;
   for (int i = 0; i < strategy_collapse_bars + 2; ++i)
   {
      if (MathAbs(Histogram(shift + i)) < threshold)
         collapsed++;
      else
         break;
   }
   return (collapsed >= strategy_collapse_bars);
}

bool HasOppositePosition(const QM_OrderType side)
{
   const int magic = QM_FrameworkMagic();
   for (int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if (ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if ((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if ((side == QM_BUY && pos_type == POSITION_TYPE_SELL) ||
          (side == QM_SELL && pos_type == POSITION_TYPE_BUY))
         return true;
   }
   return false;
}

bool HasPosition()
{
   const int magic = QM_FrameworkMagic();
   for (int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if (ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if ((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      return true;
   }
   return false;
}

void ClosePosition(const QM_ExitReason reason)
{
   const int magic = QM_FrameworkMagic();
   for (int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if (ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if ((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      QM_TM_ClosePosition(ticket, reason);
   }
}

bool Strategy_NoTradeFilter()
{
   if (strategy_max_spread_points > 0)
   {
      const int spread_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if (spread_points > strategy_max_spread_points) return true;
   }
   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "MACD_HIST_ZERO";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const double close = iClose(_Symbol, PERIOD_H1, 1);
   const double ema = EMA200(0);
   if (close <= 0.0 || ema <= 0.0) return false;

   QM_OrderType side = QM_BUY;
   string reason = "";

   if (CrossedAboveZero(0) && close > ema)
   {
      side = QM_BUY;
      reason = "MACDHIST_LONG_ZERO_CROSS";
   }
   else if (CrossedBelowZero(0) && close < ema)
   {
      side = QM_SELL;
      reason = "MACDHIST_SHORT_ZERO_CROSS";
   }
   else
      return false;

   if (HasOppositePosition(side))
      ClosePosition(QM_EXIT_OPPOSITE_SIGNAL);
   if (HasPosition())
      return false;

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if (entry <= 0.0) return false;

   const double sl = QM_StopATR(_Symbol, side, entry, 14, strategy_atr_sl_mult);
   if (sl <= 0.0) return false;

   double tp = 0.0;
   if (strategy_rr_target > 0.0)
   {
      tp = (side == QM_BUY) ? entry + (entry - sl) * strategy_rr_target
                            : entry - (sl - entry) * strategy_rr_target;
   }

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
}

void Strategy_ManageOpenPosition()
{
}

bool Strategy_ExitSignal()
{
   if (!HasPosition()) return false;

   const int magic = QM_FrameworkMagic();
   for (int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if (ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if ((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      if ((pos_type == POSITION_TYPE_BUY && CrossedBelowZero(0)) ||
          (pos_type == POSITION_TYPE_SELL && CrossedAboveZero(0)))
      {
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
         continue;
      }

      if (HistogramCollapsed(0))
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

int OnInit()
{
   if (!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                         qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                         30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                         qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1260\",\"strategy\":\"hopwood-macd-hist-zero-h1\"}");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
}

void OnTick()
{
   if (!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   if (Strategy_NewsFilterHook(broker_now)) return;
   bool news_allows = true;
   if (qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if (!news_allows) return;
   if (QM_FrameworkHandleFridayClose()) return;
   if (Strategy_NoTradeFilter()) return;
   Strategy_ManageOpenPosition();
   Strategy_ExitSignal();
   if (!QM_IsNewBar()) return;
   QM_EquityStreamOnNewBar();
   QM_EntryRequest req;
   if (Strategy_EntrySignal(req))
   {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
   }
}

void OnTimer() { QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result) { QM_FrameworkOnTradeTransaction(trans, request, result); }
double OnTester() { QM_ChartUI_Refresh(); return QM_DefaultObjective(); }
