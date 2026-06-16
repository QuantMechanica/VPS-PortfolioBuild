#property strict
#property version   "5.0"
#property description "QM5_1259 Hopwood Wilders Volatility-Stop H1 Trend-Follower"
// rework v2 2026-06-16 — fix QM_IsNewBar double-consume: 2nd call in OnTick always
// returned false so `if(!QM_IsNewBar()) return;` aborted before entry → 0 trades.
// Latch new-bar state once per tick into is_new_bar and reuse it.

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1259;
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
input int    strategy_atr_period         = 7;
input int    strategy_ema_period         = 200;
input double strategy_vs_mult            = 3.0;
input double strategy_rr_target          = 0.0;
input int    strategy_max_spread_points  = 25;

double g_vs_line = 0.0;
bool   g_vs_long = false;
int    g_vs_init_bars = 0;

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

double ATR7(const int shift)
{
   return QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, shift + 1);
}

void UpdateVSLine()
{
   const double close = iClose(_Symbol, PERIOD_H1, 1);
   const double atr = ATR7(0);
   if (close <= 0.0 || atr <= 0.0) return;

   if (g_vs_init_bars == 0)
   {
      const double ema = EMA200(0);
      if (ema <= 0.0) return;
      g_vs_long = (close > ema);
      g_vs_line = g_vs_long ? (close - strategy_vs_mult * atr)
                            : (close + strategy_vs_mult * atr);
      g_vs_init_bars = 1;
      return;
   }

   if (g_vs_long)
   {
      const double new_vs = close - strategy_vs_mult * atr;
      if (new_vs > g_vs_line) g_vs_line = new_vs;
      if (close < g_vs_line)
      {
         g_vs_long = false;
         g_vs_line = close + strategy_vs_mult * atr;
      }
   }
   else
   {
      const double new_vs = close + strategy_vs_mult * atr;
      if (new_vs < g_vs_line) g_vs_line = new_vs;
      if (close > g_vs_line)
      {
         g_vs_long = true;
         g_vs_line = close - strategy_vs_mult * atr;
      }
   }
}

bool VSFlippedLong()
{
   return g_vs_long;
}

bool VSFlippedShort()
{
   return !g_vs_long;
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

bool PositionSideIsLong()
{
   const int magic = QM_FrameworkMagic();
   for (int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if (ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if ((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      return ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
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

void CheckVSFlipExit()
{
   if (!HasPosition()) return;

   if (g_vs_init_bars == 0) return;

   const bool is_long = PositionSideIsLong();
   if (!is_long && VSFlippedLong())
      ClosePosition(QM_EXIT_OPPOSITE_SIGNAL);
   else if (is_long && VSFlippedShort())
      ClosePosition(QM_EXIT_OPPOSITE_SIGNAL);
}

void UpdateVSLineOnBar()
{
   if (!QM_IsNewBar()) return;
   UpdateVSLine();
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "WILDER_VS";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if (strategy_atr_period <= 0 || strategy_vs_mult <= 0.0)
      return false;

   if (g_vs_init_bars == 0)
      return false;

   const double ema = EMA200(0);
   const double close = iClose(_Symbol, PERIOD_H1, 1);
   if (ema <= 0.0 || close <= 0.0)
      return false;

   QM_OrderType side = QM_BUY;
   string reason = "";

   if (VSFlippedLong() && close > ema)
   {
      if (HasPosition() && !PositionSideIsLong())
      {
         ClosePosition(QM_EXIT_OPPOSITE_SIGNAL);
      }
      if (HasPosition()) return false;
      side = QM_BUY;
      reason = "WILDER_LONG_VS_FLIP";
   }
   else if (VSFlippedShort() && close < ema)
   {
      if (HasPosition() && PositionSideIsLong())
      {
         ClosePosition(QM_EXIT_OPPOSITE_SIGNAL);
      }
      if (HasPosition()) return false;
      side = QM_SELL;
      reason = "WILDER_SHORT_VS_FLIP";
   }
   else
      return false;

   const double entry = (side == QM_BUY)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if (entry <= 0.0) return false;

   const double atr = ATR7(0);
   if (atr <= 0.0) return false;

   double sl = (side == QM_BUY)
               ? entry - strategy_vs_mult * atr
               : entry + strategy_vs_mult * atr;
   if (sl <= 0.0 || sl >= entry) return false;

   double tp = 0.0;
   if (strategy_rr_target > 0.0)
   {
      tp = (side == QM_BUY)
           ? entry + (entry - sl) * strategy_rr_target
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
   if (!HasPosition()) return;
   if (g_vs_line <= 0.0) return;

   const int magic = QM_FrameworkMagic();
   for (int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if (ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if ((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const bool is_long = ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      const double new_sl = is_long
                           ? (g_vs_line < PositionGetDouble(POSITION_SL) ? PositionGetDouble(POSITION_SL) : g_vs_line)
                           : (g_vs_line > PositionGetDouble(POSITION_SL) ? PositionGetDouble(POSITION_SL) : g_vs_line);

      if (new_sl > 0.0 && ((is_long && new_sl > PositionGetDouble(POSITION_SL)) ||
                           (!is_long && (new_sl < PositionGetDouble(POSITION_SL) || PositionGetDouble(POSITION_SL) <= 0.0))))
      {
         MqlTradeRequest treq;
         MqlTradeResult tres;
         ZeroMemory(treq);
         ZeroMemory(tres);
         treq.action = TRADE_ACTION_SLTP;
         treq.symbol = _Symbol;
         treq.sl = NormalizeDouble(new_sl, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
         treq.tp = PositionGetDouble(POSITION_TP);
         treq.magic = magic;
         treq.position = ticket;
         const bool sent = OrderSend(treq, tres);
         if (!sent)
            QM_LogEvent(QM_WARN, "VS_SL_UPDATE_FAIL",
                        StringFormat("{\"pos\":%llu,\"retcode\":%u}", ticket, tres.retcode));
      }
   }
}

bool Strategy_ExitSignal()
{
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

   g_vs_init_bars = 0;
   g_vs_line = 0.0;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1259\",\"strategy\":\"hopwood-wilders-vol-stop-h1\"}");
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

   const bool is_new_bar = QM_IsNewBar();
   if (is_new_bar)
   {
      UpdateVSLine();
      g_vs_init_bars++;
   }

   Strategy_ManageOpenPosition();
   Strategy_ExitSignal();

   if (!is_new_bar)
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
