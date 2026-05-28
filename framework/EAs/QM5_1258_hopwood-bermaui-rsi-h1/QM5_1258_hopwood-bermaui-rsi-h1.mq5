#property strict
#property version   "5.0"
#property description "QM5_1258 Hopwood Bermaui-RSI H1 Trend-Follower"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1258;
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
input int    strategy_rsi_period         = 14;
input int    strategy_ema_period         = 200;
input double strategy_atr_sl_mult        = 2.0;
input double strategy_rr_target          = 2.0;
input int    strategy_mid_zone_bars      = 4;
input double strategy_mid_zone_low       = 45.0;
input double strategy_mid_zone_high      = 55.0;
input int    strategy_max_spread_points  = 25;

double BermauiRSI(const int shift, const int buffer_size = 28)
{
   if (buffer_size < strategy_rsi_period * 2 + 1)
      return 50.0;

   double raw_rsi[];
   ArraySetAsSeries(raw_rsi, true);
   const int handle = iRSI(_Symbol, PERIOD_H1, strategy_rsi_period, PRICE_CLOSE);
   if (handle == INVALID_HANDLE) return 50.0;
   const int copied = CopyBuffer(handle, 0, shift, strategy_rsi_period + 1, raw_rsi);
   IndicatorRelease(handle);
   if (copied != strategy_rsi_period + 1) return 50.0;

   double gains = 0.0, losses = 0.0;
   for (int i = 1; i <= strategy_rsi_period; ++i)
   {
      const double diff = raw_rsi[i - 1] - raw_rsi[i];
      if (diff >= 0) gains += diff;
      else losses -= diff;
   }
   const double avg_gain = gains / (double)strategy_rsi_period;
   const double avg_loss = losses / (double)strategy_rsi_period;
   if (avg_loss == 0.0) return 100.0;
   const double rs = avg_gain / avg_loss;
   return 100.0 - 100.0 / (1.0 + rs);
}

double BermauiRSIClosedShift(const int shift)
{
   return BermauiRSI(shift + 1, strategy_rsi_period * 2 + 2);
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

bool CrossedAboveMidline(const int shift)
{
   const double rsi1 = BermauiRSIClosedShift(shift);
   const double rsi2 = BermauiRSIClosedShift(shift + 1);
   return (rsi1 > 50.0 && rsi2 <= 50.0);
}

bool CrossedBelowMidline(const int shift)
{
   const double rsi1 = BermauiRSIClosedShift(shift);
   const double rsi2 = BermauiRSIClosedShift(shift + 1);
   return (rsi1 < 50.0 && rsi2 >= 50.0);
}

bool InMidZone(const int shift)
{
   const double val = BermauiRSIClosedShift(shift);
   return (val >= strategy_mid_zone_low && val <= strategy_mid_zone_high);
}

int MidZoneCount(const int start_shift)
{
   int count = 0;
   for (int i = 0; i < 10; ++i)
   {
      if (InMidZone(start_shift + i))
         count++;
      else
         break;
   }
   return count;
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
      if (spread_points > strategy_max_spread_points)
         return true;
   }
   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "BERMAUI_RSI";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if (strategy_rsi_period <= 0 || strategy_ema_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return false;

   const double rsi_val = BermauiRSIClosedShift(0);
   if (rsi_val < 0.0 || rsi_val > 100.0)
      return false;

   const double ema = EMA200(0);
   if (ema <= 0.0)
      return false;

   const double close = iClose(_Symbol, PERIOD_H1, 1);
   if (close <= 0.0)
      return false;

   QM_OrderType side = QM_BUY;
   string reason = "";

   if (CrossedAboveMidline(0) && close > ema)
   {
      side = QM_BUY;
      reason = "BERMAUI_LONG_CROSS_UP";
   }
   else if (CrossedBelowMidline(0) && close < ema)
   {
      side = QM_SELL;
      reason = "BERMAUI_SHORT_CROSS_DN";
   }
   else
      return false;

   if (HasOppositePosition(side))
   {
      ClosePosition(QM_EXIT_OPPOSITE_SIGNAL);
   }

   if (HasPosition())
      return false;

   const double entry = (side == QM_BUY)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if (entry <= 0.0) return false;

   const double sl = QM_StopATR(_Symbol, side, entry, strategy_rsi_period, strategy_atr_sl_mult);
   if (sl <= 0.0) return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_rsi_period, 1);
   if (atr <= 0.0) return false;

   const double tp = (side == QM_BUY)
                     ? entry + (entry - sl) * strategy_rr_target
                     : entry - (sl - entry) * strategy_rr_target;

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
   if (!HasPosition())
      return false;

   const double rsi_val = BermauiRSIClosedShift(0);
   if (rsi_val < 0.0 || rsi_val > 100.0)
      return false;

   const int magic = QM_FrameworkMagic();
   for (int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if (ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if ((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      if ((pos_type == POSITION_TYPE_BUY && CrossedBelowMidline(0)) ||
          (pos_type == POSITION_TYPE_SELL && CrossedAboveMidline(0)))
      {
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
         continue;
      }

      if (MidZoneCount(0) >= strategy_mid_zone_bars)
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
   if (!QM_FrameworkInit(qm_ea_id,
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1258\",\"strategy\":\"hopwood-bermaui-rsi-h1\"}");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
}

void OnTick()
{
   if (!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if (Strategy_NewsFilterHook(broker_now))
      return;
   bool news_allows = true;
   if (qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if (!news_allows)
      return;
   if (QM_FrameworkHandleFridayClose())
      return;

   if (Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();
   Strategy_ExitSignal();

   if (!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   if (Strategy_EntrySignal(req))
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
