#property strict
#property version   "5.0"
#property description "QM5_13014 MQL5 DEMA Range Channel breakout v2 (exit surgery)"
// Strategy Card: QM5_13014 (mql5-dema-chan-v2), G0 APPROVED 2026-07-04.
// Source: Nikolay Kositsin, Exp_DEMA_Range_Channel_Tm_Plus, MQL5 CodeBase, 2018-08-23.
//
// EXIT SURGERY v2 — parent QM5_10494
// Surgical delta: add strategy_min_hold_h = 24.0; suppress channel-reversal signal
// exit for the first 24h of hold. The 32h time exit (strategy_hold_minutes=1920) is
// UNTOUCHED — only the opposite-channel signal-reversal exit path gains the guard.
// Evidence: EXIT_SURGERY_SCAN_2026-07-04.md §3.1; hold-gradient WR 0%->68%;
// 190 TIME_MGMT kills in 8-24h bucket (WR 14%); 343 winners in 1-3d bucket (WR 68%).
// All other logic and parameters are IDENTICAL to parent QM5_10494.

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 13014;
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
input ENUM_TIMEFRAMES strategy_signal_tf       = PERIOD_H8;
input int    strategy_dema_period              = 14;
input int    strategy_channel_shift_bars       = 3;
input double strategy_price_shift_points       = 0.0;
input int    strategy_atr_period               = 14;
input double strategy_atr_sl_mult              = 1.5;
input double strategy_target_rr                = 2.0;
input int    strategy_hold_minutes             = 1920;
// v2 surgical input: suppress channel-reversal signal exit before this many hours.
// Evidence: EXIT_SURGERY_SCAN_2026-07-04.md §3.1 — the 8-24h bucket (190 trades,
// WR 14%) is dominated by premature channel-reversal kills before positions mature.
// Setting this to 24h lets positions breathe through initial H8 signal noise while
// the 32h time exit (strategy_hold_minutes=1920) remains the outer hard stop.
input double strategy_min_hold_h               = 24.0;
input double strategy_min_atr_points           = 20.0;
input int    strategy_max_spread_points        = 35;

bool Strategy_FindOurPosition(ENUM_POSITION_TYPE &ptype, datetime &open_time)
  {
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

      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

double Strategy_SourcePrice(const int shift, const bool use_high)
  {
   return use_high ? iHigh(_Symbol, strategy_signal_tf, shift)
                   : iLow(_Symbol, strategy_signal_tf, shift);
  }

double Strategy_DEMA(const int shift, const bool use_high)
  {
   if(strategy_dema_period <= 1 || shift < 0)
      return 0.0;

   const int warmup = strategy_dema_period * 6 + 10;
   if(Bars(_Symbol, strategy_signal_tf) <= shift + warmup)
      return 0.0;

   const double alpha = 2.0 / ((double)strategy_dema_period + 1.0);
   double ema1 = Strategy_SourcePrice(shift + warmup - 1, use_high);
   if(ema1 <= 0.0)
      return 0.0;
   double ema2 = ema1;

   for(int s = shift + warmup - 2; s >= shift; --s)
     {
      const double price = Strategy_SourcePrice(s, use_high);
      if(price <= 0.0)
         return 0.0;
      ema1 = alpha * price + (1.0 - alpha) * ema1;
      ema2 = alpha * ema1 + (1.0 - alpha) * ema2;
     }

   return 2.0 * ema1 - ema2;
  }

double Strategy_ChannelUpper(const int signal_shift)
  {
   const int channel_shift = signal_shift + MathMax(0, strategy_channel_shift_bars);
   const double dema_high = Strategy_DEMA(channel_shift, true);
   if(dema_high <= 0.0)
      return 0.0;
   return dema_high + MathMax(0.0, strategy_price_shift_points) * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  }

double Strategy_ChannelLower(const int signal_shift)
  {
   const int channel_shift = signal_shift + MathMax(0, strategy_channel_shift_bars);
   const double dema_low = Strategy_DEMA(channel_shift, false);
   if(dema_low <= 0.0)
      return 0.0;
   return dema_low - MathMax(0.0, strategy_price_shift_points) * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  }

int Strategy_ChannelSignal()
  {
   if(strategy_dema_period <= 1 || strategy_atr_period <= 0)
      return 0;

   const double close_1 = iClose(_Symbol, strategy_signal_tf, 1);
   const double close_2 = iClose(_Symbol, strategy_signal_tf, 2);
   if(close_1 <= 0.0 || close_2 <= 0.0)
      return 0;

   const double upper_1 = Strategy_ChannelUpper(1);
   const double upper_2 = Strategy_ChannelUpper(2);
   const double lower_1 = Strategy_ChannelLower(1);
   const double lower_2 = Strategy_ChannelLower(2);
   if(upper_1 <= 0.0 || upper_2 <= 0.0 || lower_1 <= 0.0 || lower_2 <= 0.0)
      return 0;

   if(close_1 > upper_1 && close_2 <= upper_2)
      return 1;
   if(close_1 < lower_1 && close_2 >= lower_2)
      return -1;

   return 0;
  }

double Strategy_NormalizeStop(const QM_OrderType side, const double entry, const double stop)
  {
   if(entry <= 0.0 || stop <= 0.0)
      return 0.0;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(point <= 0.0)
      return 0.0;

   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double min_dist = MathMax(1, stops_level) * point;
   double normalized = stop;
   if(side == QM_BUY && entry - normalized < min_dist)
      normalized = entry - min_dist;
   if(side == QM_SELL && normalized - entry < min_dist)
      normalized = entry + min_dist;

   return NormalizeDouble(normalized, digits);
  }

bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return true;
     }

   const double atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(strategy_min_atr_points > 0.0 && point > 0.0 && atr > 0.0)
      if(atr < strategy_min_atr_points * point)
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

   ENUM_POSITION_TYPE existing_type = POSITION_TYPE_BUY;
   datetime open_time = 0;
   if(Strategy_FindOurPosition(existing_type, open_time))
      return false;

   const int signal = Strategy_ChannelSignal();
   if(signal == 0)
      return false;

   const QM_OrderType side = (signal > 0) ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0 || strategy_atr_sl_mult <= 0.0 || strategy_target_rr <= 0.0)
      return false;

   const double raw_sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_sl_mult);
   const double sl = Strategy_NormalizeStop(side, entry, raw_sl);
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_target_rr);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type = side;
   req.sl = sl;
   req.tp = tp;
   req.reason = (signal > 0) ? "DEMA_RANGE_LONG_V2" : "DEMA_RANGE_SHORT_V2";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed SL/TP, time exit, and opposite channel exit only.
  }

bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   datetime open_time = 0;
   if(!Strategy_FindOurPosition(ptype, open_time))
      return false;

   // Time exit: fires unconditionally at strategy_hold_minutes (32h). Unchanged from parent.
   if(strategy_hold_minutes > 0 && open_time > 0)
      if(TimeCurrent() - open_time >= strategy_hold_minutes * 60)
         return true;

   // v2 surgical guard: suppress the channel-reversal signal exit for the first
   // strategy_min_hold_h hours (default 24h). Trades in the 8-24h window that
   // receive an opposite-channel H8 signal are no longer forcibly closed early.
   // Evidence: EXIT_SURGERY_SCAN_2026-07-04.md §3.1 — 190 kills in 8-24h at WR 14%.
   if(strategy_min_hold_h > 0.0 && open_time > 0 &&
      (double)(TimeCurrent() - open_time) < strategy_min_hold_h * 3600.0)
      return false;

   if(!QM_IsNewBar(_Symbol, strategy_signal_tf))
      return false;

   const int signal = Strategy_ChannelSignal();
   if(ptype == POSITION_TYPE_BUY && signal < 0)
      return true;
   if(ptype == POSITION_TYPE_SELL && signal > 0)
      return true;

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
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13014_mql5_dema_chan_v2\",\"surgery\":\"min_hold_h_24_signal_reversal_guard\"}");
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
