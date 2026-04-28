#property strict
#property version   "5.0"
#property description "QM5_1008 Lien DBB Trend Join (SRC04_S02b)"
// Strategy Card ID: SRC04_S02b (lien-dbb-trend-join)

#include <QM/QM_Common.mqh>
#include <QM/QM_StopRules.mqh>
#include <Trade/Trade.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1008;
input int    qm_magic_slot_offset        = 0;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsMode qm_news_mode           = QM_NEWS_PAUSE;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_bb_period          = 20;    // Card §4 (PDF pp.107-108): 20-period basis.
input double strategy_bb_inner_sigma     = 1.0;   // Card §4: first standard deviation band.
input double strategy_bb_outer_sigma     = 2.0;   // Card §6: sibling S02a co-regime suppression uses outer zone.
input int    strategy_lookback_bars      = 2;     // Card §4: "last two candles" opposite side precondition.
input int    strategy_init_stop_pips     = 65;    // Card §4 rule 4: initial 65-pip stop.
input int    strategy_tp1_pips           = 50;    // Card §5 rule 5: close half at +50 pips, move stop to BE.
input int    strategy_tp2_pips           = 195;   // Card §5 rule 6: close remainder at +195 pips.
input bool   strategy_enable_coregime_guard = true; // Card §6: skip S02b if S02a-style outer-band-zone overlap.

enum StrategySignal
  {
   STRAT_NONE = 0,
   STRAT_LONG = 1,
   STRAT_SHORT = 2
  };

CTrade   g_trade;
datetime g_last_bar_time = 0;
ulong    g_tp1_ticket = 0;

bool IsNewBar()
  {
   const datetime t0 = iTime(_Symbol, _Period, 0);
   if(t0 <= 0 || t0 == g_last_bar_time)
      return false;
   g_last_bar_time = t0;
   return true;
  }

bool ReadBandLevels(const int shift, double &mid, double &inner_upper, double &inner_lower, double &outer_upper, double &outer_lower)
  {
   if(strategy_bb_period <= 1)
      return false;

   double sum = 0.0;
   for(int i = shift; i < shift + strategy_bb_period; ++i)
     {
      const double c = iClose(_Symbol, _Period, i);
      if(c <= 0.0)
         return false;
      sum += c;
     }

   mid = sum / strategy_bb_period;

   double sq_sum = 0.0;
   for(int i = shift; i < shift + strategy_bb_period; ++i)
     {
      const double c = iClose(_Symbol, _Period, i);
      const double d = c - mid;
      sq_sum += d * d;
     }

   const double variance = sq_sum / strategy_bb_period;
   const double sd = MathSqrt(variance);
   if(mid <= 0.0 || sd <= 0.0)
      return false;

   inner_upper = mid + strategy_bb_inner_sigma * sd;
   inner_lower = mid - strategy_bb_inner_sigma * sd;
   outer_upper = mid + strategy_bb_outer_sigma * sd;
   outer_lower = mid - strategy_bb_outer_sigma * sd;
   return true;
  }

bool InOuterBandZone(const StrategySignal side, const int shift)
  {
   double mid = 0.0, inner_upper = 0.0, inner_lower = 0.0, outer_upper = 0.0, outer_lower = 0.0;
   if(!ReadBandLevels(shift, mid, inner_upper, inner_lower, outer_upper, outer_lower))
      return false;

   const double close_p = iClose(_Symbol, _Period, shift);
   if(close_p <= 0.0)
      return false;

   if(side == STRAT_LONG)
      return (close_p >= outer_lower && close_p <= inner_lower);
   if(side == STRAT_SHORT)
      return (close_p <= outer_upper && close_p >= inner_upper);
   return false;
  }

bool GetOurPosition(ENUM_POSITION_TYPE &ptype, ulong &ticket, double &open_price, double &volume, double &sl)
  {
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
      ticket = t;
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      volume = PositionGetDouble(POSITION_VOLUME);
      sl = PositionGetDouble(POSITION_SL);
      return true;
     }
   return false;
  }

double PriceDistanceFromPips(const int pips)
  {
   return QM_StopRulesPipsToPriceDistance(_Symbol, pips);
  }

// Card §4 (PDF pp.107-108): close back across inner band after 2-bar opposite-side dwell.
StrategySignal Strategy_EntrySignal()
  {
   if(strategy_bb_period < 2 || strategy_lookback_bars < 1)
      return STRAT_NONE;
   if(Bars(_Symbol, _Period) < strategy_bb_period + strategy_lookback_bars + 5)
      return STRAT_NONE;

   double mid = 0.0, inner_upper = 0.0, inner_lower = 0.0, outer_upper = 0.0, outer_lower = 0.0;
   if(!ReadBandLevels(1, mid, inner_upper, inner_lower, outer_upper, outer_lower))
      return STRAT_NONE;

   const double c1 = iClose(_Symbol, _Period, 1);
   if(c1 <= 0.0)
      return STRAT_NONE;

   bool long_precondition = true;
   bool short_precondition = true;
   for(int k = 2; k <= 1 + strategy_lookback_bars; ++k)
     {
      double kmid = 0.0, k_inner_upper = 0.0, k_inner_lower = 0.0, k_outer_upper = 0.0, k_outer_lower = 0.0;
      if(!ReadBandLevels(k, kmid, k_inner_upper, k_inner_lower, k_outer_upper, k_outer_lower))
         return STRAT_NONE;

      const double ck = iClose(_Symbol, _Period, k);
      if(ck <= 0.0)
         return STRAT_NONE;

      if(!(ck < k_inner_lower))
         long_precondition = false;
      if(!(ck > k_inner_upper))
         short_precondition = false;
     }

   if(long_precondition && c1 > inner_lower)
     {
      if(strategy_enable_coregime_guard && InOuterBandZone(STRAT_LONG, 2))
         return STRAT_NONE; // Card §6: S02a-precondition overlap guard.
      return STRAT_LONG;
     }

   if(short_precondition && c1 < inner_upper)
     {
      if(strategy_enable_coregime_guard && InOuterBandZone(STRAT_SHORT, 2))
         return STRAT_NONE; // Card §6: S02a-precondition overlap guard.
      return STRAT_SHORT;
     }

   return STRAT_NONE;
  }

// Card §5: TP1 partial (+50 pips) then stop-to-breakeven on remainder.
void Strategy_ManageOpenPosition()
  {
   ENUM_POSITION_TYPE ptype;
   ulong ticket;
   double open_price = 0.0, volume = 0.0, sl = 0.0;
   if(!GetOurPosition(ptype, ticket, open_price, volume, sl))
      return;

   if(ticket == 0 || volume <= 0.0 || open_price <= 0.0)
      return;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return;

   const double distance_tp1 = PriceDistanceFromPips(strategy_tp1_pips);
   if(distance_tp1 <= 0.0)
      return;

   const double current_price = (ptype == POSITION_TYPE_BUY) ? bid : ask;
   const double favorable = (ptype == POSITION_TYPE_BUY) ? (current_price - open_price) : (open_price - current_price);

   if(favorable < distance_tp1 || g_tp1_ticket == ticket)
      return;

   const double vol_min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   const double vol_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(vol_min <= 0.0 || vol_step <= 0.0)
      return;

   double close_vol = volume * 0.5;
   close_vol = MathFloor(close_vol / vol_step) * vol_step;
   close_vol = NormalizeDouble(close_vol, 8);
   if(close_vol < vol_min || (volume - close_vol) < vol_min)
      return;

   if(!g_trade.PositionClosePartial(ticket, close_vol))
      return;

   const double be_sl = NormalizeDouble(open_price, _Digits);
   if(ptype == POSITION_TYPE_BUY && (sl <= 0.0 || sl < be_sl))
      g_trade.PositionModify(_Symbol, be_sl, 0.0);
   else if(ptype == POSITION_TYPE_SELL && (sl <= 0.0 || sl > be_sl))
      g_trade.PositionModify(_Symbol, be_sl, 0.0);

   g_tp1_ticket = ticket;
  }

// Card §5 + §7: no discretionary exit signal; SL/TP + framework Friday close handle exits.
bool Strategy_ExitSignal()
  {
   return false;
  }

void PlaceEntry(const StrategySignal signal)
  {
   if(signal == STRAT_NONE)
      return;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return;

   const QM_OrderType side = (signal == STRAT_LONG) ? QM_BUY : QM_SELL;
   const double entry = (signal == STRAT_LONG) ? ask : bid;
   const double stop = QM_StopFixedPips(_Symbol, side, entry, strategy_init_stop_pips);
   const double take = QM_TakeFixedPips(_Symbol, side, entry, strategy_tp2_pips);
   if(stop <= 0.0 || take <= 0.0)
      return;

   QM_EntryRequest req;
   ZeroMemory(req);
   req.type = side;
   req.price = entry;
   req.sl = stop;
   req.tp = take;
   req.reason = (signal == STRAT_LONG) ? "SRC04_S02b_LONG_DBB_RECLAIM" : "SRC04_S02b_SHORT_DBB_RECLAIM";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   ulong out_ticket = 0;
   if(QM_Entry(req, out_ticket) == QM_ENTRY_OK)
      g_tp1_ticket = 0;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"SRC04_S02b\",\"ea\":\"QM5_1008_lien_dbb_trend_join\"}");
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
   if(!QM_NewsAllowsTrade(_Symbol, TimeCurrent(), qm_news_mode))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
      return;

   ENUM_POSITION_TYPE ptype;
   ulong ticket;
   double open_price = 0.0, volume = 0.0, sl = 0.0;
   if(GetOurPosition(ptype, ticket, open_price, volume, sl))
      return;

   if(!IsNewBar())
      return;

   const StrategySignal signal = Strategy_EntrySignal();
   PlaceEntry(signal);
  }

void OnTimer()
  {
   QM_FrameworkOnTimer();
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
