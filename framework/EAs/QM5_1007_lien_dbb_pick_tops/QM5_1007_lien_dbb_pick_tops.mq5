#property strict
#property version   "5.0"
#property description "QM5_1007 Lien DBB Pick Tops (SRC04_S02a)"
// Strategy Card: SRC04_S02a (lien-dbb-pick-tops), CTO unblock with ea_id=1007 on 2026-04-28.

#include <QM/QM_Common.mqh>
#include <Trade/Trade.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 1007;
input int    qm_magic_slot_offset         = 0;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsMode qm_news_mode            = QM_NEWS_PAUSE;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Strategy"
input int    strategy_bb_period           = 20;   // Card §4 + §8, PDF p.101-103: 20-period DBB.
input double strategy_bb_inner_sigma      = 1.0;  // Card §4 + §8, PDF p.102-103: 1st-σ band.
input double strategy_bb_outer_sigma      = 2.0;  // Card §4 + §8, PDF p.101-103: 2nd-σ band.
input int    strategy_dwell_bars          = 1;    // Card §4 + §8: DWELL_BARS default 1.
input int    strategy_long_stop_pips      = 50;   // Card §4 + §8, PDF p.103 long rule 4.
input int    strategy_short_stop_pips     = 30;   // Card §4 + §8, PDF p.104 short rule 4.
input bool   strategy_enable_tp2_fixed_2r = true; // Card §5 + §8: default fixed 2R remainder close.

CTrade   g_trade;
datetime g_last_bar_time = 0;
int      g_ma_handle = INVALID_HANDLE;
int      g_std_handle = INVALID_HANDLE;

bool IsNewBar()
  {
   const datetime t0 = iTime(_Symbol, _Period, 0);
   if(t0 <= 0)
      return false;
   if(t0 == g_last_bar_time)
      return false;
   g_last_bar_time = t0;
   return true;
  }

double PipSize()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(point <= 0.0)
      return 0.0;
   if(digits == 3 || digits == 5)
      return point * 10.0;
   return point;
  }

bool GetOurPosition(ENUM_POSITION_TYPE &ptype, double &price_open, double &sl, double &volume, ulong &ticket)
  {
   ptype = POSITION_TYPE_BUY;
   price_open = 0.0;
   sl = 0.0;
   volume = 0.0;
   ticket = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      price_open = PositionGetDouble(POSITION_PRICE_OPEN);
      sl = PositionGetDouble(POSITION_SL);
      volume = PositionGetDouble(POSITION_VOLUME);
      ticket = t;
      return true;
     }

   return false;
  }

bool ReadBandValues(const int shift,
                    double &mid,
                    double &inner_upper,
                    double &inner_lower,
                    double &outer_upper,
                    double &outer_lower)
  {
   mid = 0.0;
   inner_upper = 0.0;
   inner_lower = 0.0;
   outer_upper = 0.0;
   outer_lower = 0.0;

   if(g_ma_handle == INVALID_HANDLE || g_std_handle == INVALID_HANDLE)
      return false;

   double ma_buf[1];
   double std_buf[1];
   if(CopyBuffer(g_ma_handle, 0, shift, 1, ma_buf) < 1)
      return false;
   if(CopyBuffer(g_std_handle, 0, shift, 1, std_buf) < 1)
      return false;

   mid = ma_buf[0];
   const double stdev = std_buf[0];
   if(mid <= 0.0 || stdev <= 0.0)
      return false;

   inner_upper = mid + strategy_bb_inner_sigma * stdev;
   inner_lower = mid - strategy_bb_inner_sigma * stdev;
   outer_upper = mid + strategy_bb_outer_sigma * stdev;
   outer_lower = mid - strategy_bb_outer_sigma * stdev;
   return true;
  }

bool IsCloseInLowerOuterZone(const int shift)
  {
   double mid, iu, il, ou, ol;
   if(!ReadBandValues(shift, mid, iu, il, ou, ol))
      return false;

   const double close_value = iClose(_Symbol, _Period, shift);
   // Card §4, PDF p.103 rule 1: precondition in lower outer zone [2σ lower, 1σ lower].
   return (close_value >= ol && close_value <= il);
  }

bool IsCloseInUpperOuterZone(const int shift)
  {
   double mid, iu, il, ou, ol;
   if(!ReadBandValues(shift, mid, iu, il, ou, ol))
      return false;

   const double close_value = iClose(_Symbol, _Period, shift);
   // Card §4, PDF p.104 rule 1: precondition in upper outer zone [1σ upper, 2σ upper].
   return (close_value >= iu && close_value <= ou);
  }

bool HasLowerZoneDwell()
  {
   if(strategy_dwell_bars < 1)
      return false;

   for(int i = 2; i <= strategy_dwell_bars + 1; ++i)
     {
      if(!IsCloseInLowerOuterZone(i))
         return false;
     }
   return true;
  }

bool HasUpperZoneDwell()
  {
   if(strategy_dwell_bars < 1)
      return false;

   for(int i = 2; i <= strategy_dwell_bars + 1; ++i)
     {
      if(!IsCloseInUpperOuterZone(i))
         return false;
     }
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   ENUM_POSITION_TYPE ptype;
   double price_open, sl, volume;
   ulong ticket;

   // Card §6 + §7: single active position; no pyramiding or stacking.
   if(GetOurPosition(ptype, price_open, sl, volume, ticket))
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

   if(strategy_bb_period < 2 || strategy_dwell_bars < 1)
      return false;

   double mid1, iu1, il1, ou1, ol1;
   double mid2, iu2, il2, ou2, ol2;
   if(!ReadBandValues(1, mid1, iu1, il1, ou1, ol1))
      return false;
   if(!ReadBandValues(2, mid2, iu2, il2, ou2, ol2))
      return false;

   const double close1 = iClose(_Symbol, _Period, 1);
   const double close2 = iClose(_Symbol, _Period, 2);
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   const double pip_size = PipSize();
   if(pip_size <= 0.0)
      return false;

   // Card §4, PDF p.103 long rules 1-4: lower-zone dwell then close reclaim above 1σ lower.
   if(HasLowerZoneDwell() && close2 <= il2 && close1 > il1)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;

      const double stop = il1 - strategy_long_stop_pips * pip_size;
      const double risk = entry - stop;
      if(risk <= 0.0)
         return false;

      req.type = QM_BUY;
      req.sl = stop;
      req.tp = strategy_enable_tp2_fixed_2r ? (entry + 2.0 * risk) : 0.0;
      req.reason = "SRC04_S02A_LONG_RECLAIM";
      return true;
     }

   // Card §4, PDF p.104 short rules 1-4: upper-zone dwell then close reclaim below 1σ upper.
   if(HasUpperZoneDwell() && close2 >= iu2 && close1 < iu1)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;

      const double stop = iu1 + strategy_short_stop_pips * pip_size;
      const double risk = stop - entry;
      if(risk <= 0.0)
         return false;

      req.type = QM_SELL;
      req.sl = stop;
      req.tp = strategy_enable_tp2_fixed_2r ? (entry - 2.0 * risk) : 0.0;
      req.reason = "SRC04_S02A_SHORT_RECLAIM";
      return true;
     }

   return false;
  }

bool IsBreakevenStop(const double entry, const double sl)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;
   return (MathAbs(sl - entry) <= point * 2.0);
  }

bool TryPartialCloseAtTP1(const ENUM_POSITION_TYPE ptype, const double entry, const double sl, const double volume)
  {
   if(volume <= 0.0)
      return false;

   if(IsBreakevenStop(entry, sl))
      return false;

   const double risk = MathAbs(entry - sl);
   if(risk <= 0.0)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return false;

   const double tp1 = (ptype == POSITION_TYPE_BUY) ? (entry + risk) : (entry - risk);
   const bool reached = (ptype == POSITION_TYPE_BUY) ? (bid >= tp1) : (ask <= tp1);
   if(!reached)
      return false;

   const double vol_min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   const double vol_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(vol_min <= 0.0 || vol_step <= 0.0)
      return false;

   // Card §5, PDF p.103-104 rule 5: close half and move stop to BE.
   double close_volume = volume * 0.5;
   close_volume = MathFloor(close_volume / vol_step) * vol_step;
   if(close_volume < vol_min)
      close_volume = vol_min;
   if(close_volume >= volume)
      return false;

   g_trade.SetExpertMagicNumber(QM_FrameworkMagic());
   if(!g_trade.PositionClosePartial(_Symbol, close_volume))
      return false;

   return g_trade.PositionModify(_Symbol, entry, 0.0);
  }

void Strategy_ManageOpenPosition()
  {
   ENUM_POSITION_TYPE ptype;
   double entry, sl, volume;
   ulong ticket;
   if(!GetOurPosition(ptype, entry, sl, volume, ticket))
      return;

   TryPartialCloseAtTP1(ptype, entry, sl, volume);
  }

bool Strategy_ExitSignal()
  {
   // Card §5, PDF p.103-104 rule 6: remainder closes at 2R TP (set as initial TP) or optional trail variant.
   return false;
  }

bool ExecuteEntrySignal(const QM_EntryRequest &req)
  {
   const double entry = (req.type == QM_BUY)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0 || req.sl <= 0.0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   const double sl_points = MathAbs(entry - req.sl) / point;
   const double lots = QM_LotsForRisk(_Symbol, sl_points);
   if(lots <= 0.0)
      return false;

   g_trade.SetExpertMagicNumber(QM_FrameworkMagic());
   if(req.type == QM_BUY)
      return g_trade.Buy(lots, _Symbol, 0.0, req.sl, req.tp, req.reason);
   return g_trade.Sell(lots, _Symbol, 0.0, req.sl, req.tp, req.reason);
  }

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
      return INIT_FAILED;

   g_ma_handle = iMA(_Symbol, _Period, strategy_bb_period, 0, MODE_SMA, PRICE_CLOSE);
   g_std_handle = iStdDev(_Symbol, _Period, strategy_bb_period, 0, MODE_SMA, PRICE_CLOSE);
   if(g_ma_handle == INVALID_HANDLE || g_std_handle == INVALID_HANDLE)
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"SRC04_S02a\",\"ea\":\"QM5_1007_lien_dbb_pick_tops\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   if(g_ma_handle != INVALID_HANDLE)
      IndicatorRelease(g_ma_handle);
   if(g_std_handle != INVALID_HANDLE)
      IndicatorRelease(g_std_handle);

   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   if(!QM_KillSwitchCheck())
      return;
   if(!QM_NewsAllowsTrade(_Symbol, TimeCurrent(), qm_news_mode))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(!IsNewBar())
      return;

   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
      return;

   if(Strategy_NoTradeFilter())
      return;

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
      ExecuteEntrySignal(req);
  }

void OnTimer()
  {
   QM_FrameworkOnTimer();
  }

double OnTester()
  {
   return QM_DefaultObjective();
  }
