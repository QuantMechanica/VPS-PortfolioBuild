#property strict
#property version   "5.0"
#property description "QM5_12720 ICT Silver Bullet + bounded FVG-retracement scale-in grid (M5, NY killzone)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12720: Silver Bullet (sweep -> MSS -> FVG) with a BOUNDED scale-in grid
// across the FVG retracement zone. Forks QM5_1233's NY-killzone SB state machine;
// replaces the single pending entry with a bounded ladder of LIMIT-style adds
// inside the FVG (improving the average entry), shared stop beyond the FVG, and a
// shared RR target from the basket VWAP. Full-ladder worst-case loss is capped at
// risk_budget_pct (no martingale: equal lots, bounded by backward-solved sizing).
//
// Framework note: single-position-per-magic auto-entry can't place a multi-fill
// basket, so ALL fills go through Strategy_SendBounded() in the manage hook
// (12552 precedent). Strategy_EntrySignal stays inert.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12720;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;   // backtest 1%/ladder basis
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Silver Bullet (NY killzone)"
input bool   cutoff_anchor_ny            = true;
input int    broker_ny_offset_min        = 420;       // broker = NY + 7h
input string cutoff_time                 = "10:00";   // freeze range at this NY time
input string window_end_time             = "11:00";   // arm window ends (NY)
input string closing_time                = "11:55";   // EOD flat (NY) — SB scalp, not all-day
input int    liquidity_sweep_max_candles = 10;
input int    fractal_strength            = 2;
input int    fractal_lookback            = 30;
input double fvg_min_size                = 0.5;        // min FVG width as ATR mult
input double fvg_max_size                = 0.0;        // 0 = no cap
input int    atr_fvg_period              = 100;
input int    strategy_max_spread_points  = 300;

input group "Bounded scale-in grid"
input int    grid_levels                 = 4;         // ladder levels across the FVG
input double risk_budget_pct             = 1.0;       // full-ladder worst-case % equity
input double stop_buffer_atr             = 0.25;      // shared stop beyond FVG far edge (x ATR)
input double target_rr                   = 2.0;       // shared TP = avg_entry +/- RR * stop_dist

#define QM_MAX_GRID 16

// ---- SB day-state (from 1233) ----
int    g_day_phase=0; long g_day_key=-1;
double g_day_high=0,g_day_low=0; bool g_range_frozen=false;
bool   g_sweep_is_buy=false; double g_mss_level=0; int g_bars_since_sweep=0;
bool   g_fvg_active=false,g_fvg_is_buy=false;
double g_fvg_near=0,g_fvg_far=0,g_fvg_mid=0,g_fvg_width=0;

// ---- basket/ladder state ----
bool   g_armed=false;          // ladder planned + waiting for fills
int    g_dir=0;                // +1 buy / -1 sell
int    g_levels=0;             // planned levels
double g_plan_price[QM_MAX_GRID];
double g_lot_each=0;           // bounded equal lot per level
double g_shared_stop=0;
int    g_fills=0;              // levels filled so far
long   g_basket_day=-1;        // day the basket belongs to

int  QM_ParseHHMM(const string raw){int c=StringFind(raw,":"); if(c<=0||c>=StringLen(raw)-1)return -1; string hh=StringSubstr(raw,0,c),mm=StringSubstr(raw,c+1); int h=(int)StringToInteger(hh),m=(int)StringToInteger(mm); if(h<0||h>23||m<0||m>59)return -1; return h*60+m;}
int  QM_BrokerMin(const datetime t){MqlDateTime d; TimeToStruct(t,d); return d.hour*60+d.min;}
long QM_DayKey(const datetime t){MqlDateTime d; TimeToStruct(t,d); return (long)d.year*10000+(long)d.mon*100+d.day;}
int  QM_NYcutoff(const string s){int m=QM_ParseHHMM(s); if(m<0)return -1; if(cutoff_anchor_ny)m=((m+broker_ny_offset_min)%1440+1440)%1440; return m;}

void QM_ResetDay(const long k){g_day_key=k; g_day_phase=0; g_day_high=0; g_day_low=DBL_MAX; g_range_frozen=false; g_sweep_is_buy=false; g_mss_level=0; g_bars_since_sweep=0; g_fvg_active=false;}

int QM_BasketCount()
  {
   int n=0; const int magic=QM_FrameworkMagic();
   for(int i=PositionsTotal()-1;i>=0;--i){ulong t=PositionGetTicket(i); if(t==0||!PositionSelectByTicket(t))continue; if(PositionGetString(POSITION_SYMBOL)!=_Symbol)continue; if((int)PositionGetInteger(POSITION_MAGIC)==magic)n++;}
   return n;
  }

double QM_BasketVWAP()
  {
   double vol=0,pv=0; const int magic=QM_FrameworkMagic();
   for(int i=PositionsTotal()-1;i>=0;--i){ulong t=PositionGetTicket(i); if(t==0||!PositionSelectByTicket(t))continue; if(PositionGetString(POSITION_SYMBOL)!=_Symbol)continue; if((int)PositionGetInteger(POSITION_MAGIC)!=magic)continue; double v=PositionGetDouble(POSITION_VOLUME); pv+=PositionGetDouble(POSITION_PRICE_OPEN)*v; vol+=v;}
   return (vol>0)?pv/vol:0.0;
  }

void QM_CloseBasket(const string reason)
  {
   const int magic=QM_FrameworkMagic();
   for(int i=PositionsTotal()-1;i>=0;--i){ulong t=PositionGetTicket(i); if(t==0||!PositionSelectByTicket(t))continue; if(PositionGetString(POSITION_SYMBOL)!=_Symbol)continue; if((int)PositionGetInteger(POSITION_MAGIC)!=magic)continue; QM_TM_ClosePosition(t,QM_EXIT_STRATEGY);}
  }

// bounded equal-lot send at explicit volume (custom multi-position send)
bool QM_SendBounded(const int dir,const double lots,const double sl,const double tp,const string reason)
  {
   const double nl=QM_TM_NormalizeVolume(_Symbol,lots); if(nl<=0.0)return false;
   const bool buy=(dir>0); const double px=buy?SymbolInfoDouble(_Symbol,SYMBOL_ASK):SymbolInfoDouble(_Symbol,SYMBOL_BID); if(px<=0.0)return false;
   MqlTradeRequest rq; ZeroMemory(rq); rq.action=TRADE_ACTION_DEAL; rq.symbol=_Symbol; rq.magic=QM_FrameworkMagic();
   rq.volume=nl; rq.type=buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL; rq.price=QM_TM_NormalizePrice(_Symbol,px);
   rq.sl=(sl>0)?QM_TM_NormalizePrice(_Symbol,sl):0.0; rq.tp=(tp>0)?QM_TM_NormalizePrice(_Symbol,tp):0.0;
   rq.deviation=QM_TM_DEFAULT_DEVIATION_POINTS; rq.comment=reason;
   MqlTradeResult rs; string ec=""; const bool ok=QM_TradeContextSend(rq,rs,ec);
   QM_LogEvent(ok?QM_INFO:QM_WARN,"GRID_FILL",StringFormat("{\"dir\":%d,\"lots\":%.4f,\"ok\":%s}",dir,nl,ok?"true":"false"));
   return ok;
  }

void QM_RefreshBasketStopTP()
  {
   const double vwap=QM_BasketVWAP(); if(vwap<=0||g_shared_stop<=0)return;
   const double dist=MathAbs(vwap-g_shared_stop);
   const double tp=(g_dir>0)?vwap+target_rr*dist:vwap-target_rr*dist;
   const int magic=QM_FrameworkMagic();
   for(int i=PositionsTotal()-1;i>=0;--i){ulong t=PositionGetTicket(i); if(t==0||!PositionSelectByTicket(t))continue; if(PositionGetString(POSITION_SYMBOL)!=_Symbol)continue; if((int)PositionGetInteger(POSITION_MAGIC)!=magic)continue;
      const double cs=PositionGetDouble(POSITION_SL),ct=PositionGetDouble(POSITION_TP); const double pt=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
      if(MathAbs(cs-QM_TM_NormalizePrice(_Symbol,g_shared_stop))>pt*0.5) QM_TM_MoveSL(t,g_shared_stop,"grid_stop");
      if(MathAbs(ct-QM_TM_NormalizePrice(_Symbol,tp))>pt*0.5) QM_TM_MoveTP(t,tp,"grid_tp");}
  }

// ---- FVG locate (from 1233, bullish/bearish 3-bar gap) ----
bool QM_FindFVG(const bool buy)
  {
   const ENUM_TIMEFRAMES tf=(ENUM_TIMEFRAMES)_Period; const double atr=QM_ATR(_Symbol,tf,atr_fvg_period,1); if(atr<=0)return false;
   const double minw=atr*fvg_min_size, maxw=(fvg_max_size>0)?atr*fvg_max_size:0.0;
   for(int i=1;i<=fractal_lookback+5;++i){
      const double l1=iLow(_Symbol,tf,i),h1=iHigh(_Symbol,tf,i),l3=iLow(_Symbol,tf,i+2),h3=iHigh(_Symbol,tf,i+2);
      if(l1<=0||h1<=0||l3<=0||h3<=0)continue;
      double glo=0,ghi=0,near=0,far=0; bool f=false;
      if(buy){ if(l1>h3){glo=h3;ghi=l1;near=l1;far=h3;f=true;} }
      else   { if(h1<l3){glo=h1;ghi=l3;near=h1;far=l3;f=true;} }
      if(!f)continue; const double w=ghi-glo; if(w<=0||w<minw)continue; if(maxw>0&&w>maxw)continue;
      if(ghi<g_day_low||glo>g_day_high)continue;
      g_fvg_active=true; g_fvg_is_buy=buy; g_fvg_near=near; g_fvg_far=far; g_fvg_mid=(glo+ghi)*0.5; g_fvg_width=w; return true;}
   return false;
  }

bool QM_FindFractal(const bool buy,double &lvl)
  {
   const ENUM_TIMEFRAMES tf=(ENUM_TIMEFRAMES)_Period; const int k=MathMax(1,fractal_strength);
   for(int c=2;c<=1+fractal_lookback;++c){ bool fr=true;
      if(buy){ double cl=iLow(_Symbol,tf,c); if(cl<=0)return false; for(int s=1;s<=k&&fr;++s){double a=iLow(_Symbol,tf,c+s),b=iLow(_Symbol,tf,c-s); if(a<=0||b<=0||a<=cl||b<=cl)fr=false;} if(fr){lvl=cl;return true;} }
      else   { double ch=iHigh(_Symbol,tf,c); if(ch<=0)return false; for(int s=1;s<=k&&fr;++s){double a=iHigh(_Symbol,tf,c+s),b=iHigh(_Symbol,tf,c-s); if(a<=0||b<=0||a>=ch||b>=ch)fr=false;} if(fr){lvl=ch;return true;} }}
   return false;
  }

// Plan the bounded ladder across the FVG retracement zone. Levels from near edge
// toward far edge; shared stop beyond far edge; equal lot solved so full-ladder
// worst-case loss to the stop == risk_budget_pct of equity.
bool QM_PlanLadder()
  {
   const ENUM_TIMEFRAMES tf=(ENUM_TIMEFRAMES)_Period; const double atr=QM_ATR(_Symbol,tf,atr_fvg_period,1); if(atr<=0)return false;
   int N=grid_levels; if(N<1)N=1; if(N>QM_MAX_GRID)N=QM_MAX_GRID;
   const double buf=stop_buffer_atr*atr;
   g_dir=g_fvg_is_buy?1:-1;
   g_shared_stop=g_fvg_is_buy?(g_fvg_far-buf):(g_fvg_far+buf);
   for(int k=0;k<N;++k){ double frac=(N>1)?(double)k/(double)(N-1):0.0; g_plan_price[k]=g_fvg_near+(g_fvg_far-g_fvg_near)*frac; }
   // backward-solve equal lot: sum_k lots*dist(p_k,stop)*pointvalue = budget
   const double tickval=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE), ticksize=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(tickval<=0||ticksize<=0)return false; const double per_price=tickval/ticksize; // money per 1.0 price move per 1 lot
   double sumdist=0; for(int k=0;k<N;++k)sumdist+=MathAbs(g_plan_price[k]-g_shared_stop);
   if(sumdist<=0)return false;
   const double budget=AccountInfoDouble(ACCOUNT_EQUITY)*(risk_budget_pct/100.0);
   g_lot_each=budget/(per_price*sumdist);
   g_lot_each=QM_TM_NormalizeVolume(_Symbol,g_lot_each);
   if(g_lot_each<=0)return false;
   g_levels=N; g_fills=0; g_armed=true; return true;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period!=PERIOD_M5)return true;
   if(strategy_max_spread_points>0 && SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)>strategy_max_spread_points)return true;
   return false;
  }

// SB state machine runs here (per new bar) + ladder fills (per tick).
void Strategy_ManageOpenPosition()
  {
   if(_Period!=PERIOD_M5)return;
   const datetime now=TimeCurrent(); const long today=QM_DayKey(now); const int nowmin=QM_BrokerMin(now);
   const int cutoff=QM_NYcutoff(cutoff_time), wend=QM_NYcutoff(window_end_time), close=QM_NYcutoff(closing_time);

   // EOD flat + reset
   if(close>=0 && nowmin>=close){ if(QM_BasketCount()>0)QM_CloseBasket("sb_eod"); g_armed=false; }

   // ladder fills: if armed + within window, fill next level when price reaches it
   if(g_armed && QM_BasketCount()<g_levels && nowmin<close){
      const double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID),ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      // for buy: fill level k when bid <= plan_price[k] (price retraced into the gap)
      for(int k=g_fills;k<g_levels;++k){
         const bool hit=(g_dir>0)?(bid<=g_plan_price[k]):(ask>=g_plan_price[k]);
         if(!hit)break; // levels are ordered; stop at first unreached
         if(QM_SendBounded(g_dir,g_lot_each,g_shared_stop,0,StringFormat("SBG_L%d",k+1))){ g_fills=k+1; QM_RefreshBasketStopTP(); }
         else break;
      }
   }
   if(QM_BasketCount()>0)QM_RefreshBasketStopTP();

   // FVG invalidation: close beyond far edge kills the basket + disarm
   if((g_armed||QM_BasketCount()>0) && g_fvg_active){
      const double c1=iClose(_Symbol,(ENUM_TIMEFRAMES)_Period,1);
      const bool inval=g_fvg_is_buy?(c1<g_fvg_far):(c1>g_fvg_far);
      if(c1>0 && inval){ if(QM_BasketCount()>0)QM_CloseBasket("fvg_invalid"); g_armed=false; g_fvg_active=false; }
   }

   if(!QM_IsNewBar())return;
   QM_EquityStreamOnNewBar();

   // --- SB state machine on the just-closed bar (shift 1) ---
   const ENUM_TIMEFRAMES tf=(ENUM_TIMEFRAMES)_Period;
   const datetime bt=iTime(_Symbol,tf,1); if(bt<=0)return;
   const long bday=QM_DayKey(bt); const int bmin=QM_BrokerMin(bt);
   if(bday!=g_day_key)QM_ResetDay(bday);
   if(g_day_phase==4)return;
   const double bh=iHigh(_Symbol,tf,1),bl=iLow(_Symbol,tf,1),bc=iClose(_Symbol,tf,1); if(bh<=0||bl<=0||bc<=0)return;

   if(!g_range_frozen){ if(g_day_high<=0||bh>g_day_high)g_day_high=bh; if(g_day_low>=DBL_MAX||bl<g_day_low)g_day_low=bl;
      if(cutoff>=0 && bmin>=cutoff && g_day_high>g_day_low){ g_range_frozen=true; g_day_phase=1; } return; }

   // only arm setups within the killzone window [cutoff, window_end)
   if(wend>=0 && bmin>=wend && g_day_phase<3){ g_day_phase=4; return; }

   if(g_day_phase==1){
      const bool bhi=(bh>g_day_high),blo=(bl<g_day_low),inside=(bc<=g_day_high&&bc>=g_day_low);
      bool reg=false,rbuy=false;
      if(bhi&&inside){reg=true;rbuy=false;} else if(blo&&inside){reg=true;rbuy=true;}
      if(reg){ g_sweep_is_buy=rbuy; g_bars_since_sweep=0; double lvl=0; if(QM_FindFractal(rbuy,lvl)&&lvl>0){g_mss_level=lvl;g_day_phase=2;} else g_day_phase=4; }
      return; }

   if(g_day_phase==2){ g_bars_since_sweep++;
      const bool conf=g_sweep_is_buy?(bc>g_mss_level):(bc<g_mss_level);
      if(conf){ if(QM_FindFVG(g_sweep_is_buy)){ if(QM_PlanLadder())g_day_phase=3; else g_day_phase=4; } else g_day_phase=4; }
      return; }

   // phase 3: ladder armed; fills handled per-tick above; consumed for the day
   if(g_day_phase==3){ g_day_phase=4; }
  }

bool Strategy_EntrySignal(QM_EntryRequest &req){ return false; } // all entries via manage hook
bool Strategy_ExitSignal(){ return false; }                     // EOD handled in manage hook

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,qm_magic_slot_offset,RISK_PERCENT,RISK_FIXED,PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,qm_friday_close_enabled,qm_friday_close_hour_broker,30,30,
                        qm_news_stale_max_hours,qm_news_min_impact,qm_rng_seed,qm_stress_reject_probability,
                        qm_news_temporal,qm_news_compliance)) return INIT_FAILED;
   g_day_low=DBL_MAX;
   return INIT_SUCCEEDED;
  }
void OnDeinit(const int reason){ QM_FrameworkShutdown(); }
void OnTick()
  {
   if(!QM_KillSwitchCheck())return;
   if(QM_FrameworkHandleFridayClose())return;
   if(Strategy_NoTradeFilter())return;
   Strategy_ManageOpenPosition();
  }
void OnTimer(){ QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &t,const MqlTradeRequest &r,const MqlTradeResult &s){ QM_FrameworkOnTradeTransaction(t,r,s); }
double OnTester(){ QM_ChartUI_Refresh(); return QM_DefaultObjective(); }
