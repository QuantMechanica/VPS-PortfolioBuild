#property strict
#property version   "5.0"
#property description "QM5_12534 NNFX Canonical D1 Full-Stack"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Strategy implementation for approved card QM5_12534:
// Kijun baseline + SSL Channel + Aroon + Waddah Attar Explosion on closed D1 bars.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12534;
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
input int    strategy_kijun_period       = 26;
input int    strategy_ssl_period         = 10;
input int    strategy_aroon_period       = 25;
input int    strategy_atr_period         = 14;
input double strategy_atr_proximity_mult = 1.0;
input double strategy_sl_atr_mult        = 1.5;
input double strategy_tp_half_atr_mult   = 1.0;
input int    strategy_wae_fast           = 20;
input int    strategy_wae_slow           = 40;
input int    strategy_wae_signal         = 9;
input double strategy_wae_sensitivity    = 150.0;
input int    strategy_wae_bb_period      = 20;
input double strategy_wae_bb_deviation   = 2.0;
input int    strategy_wae_deadzone_pts   = 150;

bool Strategy_LoadClosedBars(MqlRates &rates[], const int count)
  {
   if(count <= 0)
      return false;
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, count, rates); // perf-allowed: bounded D1 closed-bar stack read; EntrySignal is called only after framework QM_IsNewBar().
   return (copied == count);
  }

bool Strategy_BaselineRecentCross(const int direction)
  {
   MqlRates rates[];
   if(!Strategy_LoadClosedBars(rates, 4))
      return false;

   for(int shift = 1; shift <= 3; ++shift)
     {
      const double close_now = rates[shift - 1].close;
      const double close_prev = rates[shift].close;
      const double kijun_now = QM_Ichimoku_KijunSen(_Symbol, PERIOD_D1, 9, strategy_kijun_period, 52, shift);
      const double kijun_prev = QM_Ichimoku_KijunSen(_Symbol, PERIOD_D1, 9, strategy_kijun_period, 52, shift + 1);
      if(close_now <= 0.0 || close_prev <= 0.0 || kijun_now <= 0.0 || kijun_prev <= 0.0)
         continue;
      if(direction > 0 && close_now > kijun_now && close_prev <= kijun_prev)
         return true;
      if(direction < 0 && close_now < kijun_now && close_prev >= kijun_prev)
         return true;
     }

   return false;
  }

int Strategy_SSLSignal(const int shift)
  {
   MqlRates rates[];
   if(!Strategy_LoadClosedBars(rates, shift))
      return 0;

   const double close_price = rates[shift - 1].close;
   const double high_ma = QM_SMA(_Symbol, PERIOD_D1, strategy_ssl_period, shift, PRICE_HIGH);
   const double low_ma = QM_SMA(_Symbol, PERIOD_D1, strategy_ssl_period, shift, PRICE_LOW);
   if(close_price <= 0.0 || high_ma <= 0.0 || low_ma <= 0.0)
      return 0;
   if(close_price > high_ma)
      return 1;
   if(close_price < low_ma)
      return -1;
   return 0;
  }

int Strategy_AroonSignal()
  {
   MqlRates rates[];
   const int period = MathMax(2, strategy_aroon_period);
   if(!Strategy_LoadClosedBars(rates, period))
      return 0;

   int highest_idx = 0;
   int lowest_idx = 0;
   double highest = rates[0].high;
   double lowest = rates[0].low;
   for(int i = 1; i < period; ++i)
     {
      if(rates[i].high > highest)
        {
         highest = rates[i].high;
         highest_idx = i;
        }
      if(rates[i].low < lowest)
        {
         lowest = rates[i].low;
         lowest_idx = i;
        }
     }

   const double aroon_up = 100.0 * (period - highest_idx) / period;
   const double aroon_down = 100.0 * (period - lowest_idx) / period;
   if(aroon_up > aroon_down)
      return 1;
   if(aroon_down > aroon_up)
      return -1;
   return 0;
  }

int Strategy_WAESignal()
  {
   const double macd_now = QM_MACD_Main(_Symbol, PERIOD_D1, strategy_wae_fast, strategy_wae_slow, strategy_wae_signal, 1, PRICE_CLOSE);
   const double macd_prev = QM_MACD_Main(_Symbol, PERIOD_D1, strategy_wae_fast, strategy_wae_slow, strategy_wae_signal, 2, PRICE_CLOSE);
   const double bb_upper = QM_BB_Upper(_Symbol, PERIOD_D1, strategy_wae_bb_period, strategy_wae_bb_deviation, 1, PRICE_CLOSE);
   const double bb_lower = QM_BB_Lower(_Symbol, PERIOD_D1, strategy_wae_bb_period, strategy_wae_bb_deviation, 1, PRICE_CLOSE);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(bb_upper <= 0.0 || bb_lower <= 0.0 || point <= 0.0)
      return 0;

   const double momentum = (macd_now - macd_prev) * strategy_wae_sensitivity;
   const double explosion = MathAbs(bb_upper - bb_lower);
   const double deadzone = strategy_wae_deadzone_pts * point;
   const double threshold = MathMax(explosion, deadzone);

   if(momentum > threshold)
      return 1;
   if(-momentum > threshold)
      return -1;
   return 0;
  }

bool Strategy_ProximityPass(const int direction)
  {
   MqlRates rates[];
   if(!Strategy_LoadClosedBars(rates, 1))
      return false;
   const double close_price = rates[0].close;
   const double kijun = QM_Ichimoku_KijunSen(_Symbol, PERIOD_D1, 9, strategy_kijun_period, 52, 1);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(close_price <= 0.0 || kijun <= 0.0 || atr <= 0.0)
      return false;
   if(direction > 0 && close_price <= kijun)
      return false;
   if(direction < 0 && close_price >= kijun)
      return false;
   return (MathAbs(close_price - kijun) < atr * strategy_atr_proximity_mult);
  }

bool Strategy_HasOpenPosition()
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
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool Strategy_NoTradeFilter()
  {
   return (_Period != PERIOD_D1);
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

   if(Strategy_HasOpenPosition())
      return false;
   if(strategy_kijun_period < 2 || strategy_ssl_period < 2 || strategy_atr_period < 1)
      return false;

   const int ssl = Strategy_SSLSignal(1);
   const int aroon = Strategy_AroonSignal();
   const int wae = Strategy_WAESignal();
   int direction = 0;
   if(Strategy_BaselineRecentCross(1) && Strategy_ProximityPass(1) && ssl > 0 && aroon > 0 && wae > 0)
      direction = 1;
   else if(Strategy_BaselineRecentCross(-1) && Strategy_ProximityPass(-1) && ssl < 0 && aroon < 0 && wae < 0)
      direction = -1;
   else
      return false;

   const double entry = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(entry <= 0.0 || atr <= 0.0)
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry, atr, strategy_sl_atr_mult);
   req.tp = 0.0;
   req.reason = (direction > 0) ? "NNFX_CANONICAL_LONG" : "NNFX_CANONICAL_SHORT";
   return (req.sl > 0.0);
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (ptype == POSITION_TYPE_BUY);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                  : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(open_price <= 0.0 || price <= 0.0 || volume <= 0.0)
         continue;

      const double trigger = is_buy ? (open_price + atr * strategy_tp_half_atr_mult)
                                    : (open_price - atr * strategy_tp_half_atr_mult);
      const bool hit_trigger = is_buy ? (price >= trigger) : (price <= trigger);
      const bool sl_not_breakeven = (current_sl <= 0.0) ||
                                    (is_buy ? (current_sl < open_price) : (current_sl > open_price));
      if(!hit_trigger || !sl_not_breakeven)
         continue;

      const double half_lots = QM_TM_NormalizeVolume(_Symbol, volume * 0.5);
      if(half_lots > 0.0 && half_lots < volume && QM_TM_PartialClose(ticket, half_lots, QM_EXIT_PARTIAL))
        {
         const double be = QM_TM_NormalizePrice(_Symbol, open_price);
         QM_TM_MoveSL(ticket, be, "nnfx_tp_half_move_runner_be");
        }
     }
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   MqlRates rates[];
   if(!Strategy_LoadClosedBars(rates, 2))
      return false;

   const double close_now = rates[0].close;
   const double close_prev = rates[1].close;
   const double kijun_now = QM_Ichimoku_KijunSen(_Symbol, PERIOD_D1, 9, strategy_kijun_period, 52, 1);
   const double kijun_prev = QM_Ichimoku_KijunSen(_Symbol, PERIOD_D1, 9, strategy_kijun_period, 52, 2);
   const int ssl = Strategy_SSLSignal(1);
   if(close_now <= 0.0 || close_prev <= 0.0 || kijun_now <= 0.0 || kijun_prev <= 0.0)
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

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
        {
         if((close_now < kijun_now && close_prev >= kijun_prev) || ssl < 0)
            return true;
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         if((close_now > kijun_now && close_prev <= kijun_prev) || ssl > 0)
            return true;
        }
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12534\",\"ea\":\"QM5_12534_nnfx_canonical_d1_fullstack\"}");
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
