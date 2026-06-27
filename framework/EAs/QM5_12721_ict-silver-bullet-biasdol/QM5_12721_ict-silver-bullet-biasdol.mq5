#property strict
#property version   "5.0"
#property description "QM5_12721 ICT Silver Bullet v2 — HTF bias + Draw-on-Liquidity target + raid-wick stop"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12721: Silver Bullet v2. Fork of the canonical 1233 SB (NY 10-11 killzone,
// sweep -> MSS -> FVG, EOD-flat) with the THREE differentiators that separate the
// profitable discretionary SB from a naive mechanization (research 2026-06-27):
//   1) HTF DIRECTIONAL BIAS  — only take longs in bullish daily bias, shorts in
//      bearish (align with the daily draw-on-liquidity). Naive impl traded both.
//   2) DRAW-ON-LIQUIDITY TARGET — TP = the opposing liquidity pool (recent swing
//      high/low), not a fixed 2:1 RR. Lets winners run to the real target.
//   3) RAID-WICK STOP — SL = the sweep bar extreme (raid wick) + buffer, tight.
// Single fill per session (no grid — research says the SB edge is bias+DOL, not a ladder).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12721;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
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
input int    broker_ny_offset_min        = 420;
input string cutoff_time                 = "10:00";
input string window_end_time             = "11:00";
input string closing_time                = "11:55";
input int    liquidity_sweep_max_candles = 10;
input int    fractal_strength            = 2;
input int    fractal_lookback            = 30;
input double fvg_min_size                = 0.5;
input double fvg_max_size                = 0.0;
input int    atr_fvg_period              = 100;
input int    strategy_max_spread_points  = 300;

input group "v2 differentiators"
input bool   use_htf_bias                = true;     // (1) only trade WITH daily bias
input int    htf_bias_ema                = 50;       // D1 EMA for bias
input bool   target_draw_on_liquidity    = true;     // (2) TP = opposing liquidity pool
input int    dol_lookback_bars           = 60;       // M5 bars to scan for opposing liquidity
input double min_rr                       = 1.5;      // floor RR (skip if DOL closer than this)
input double max_rr                       = 6.0;      // cap RR (DOL target clamped)
input double stop_buffer_atr             = 0.20;     // (3) raid-wick stop buffer (x ATR M5)

// ---- day state ----
int    g_phase=0; long g_daykey=-1;
double g_dhigh=0,g_dlow=0; bool g_frozen=false;
bool   g_buy=false; double g_mss=0; int g_since=0;
double g_raid_extreme=0;     // (3) the sweep bar's wick extreme (raid wick)
bool   g_fvg=false,g_fvg_buy=false; double g_fvg_near=0,g_fvg_far=0,g_fvg_mid=0,g_fvg_w=0;
bool   g_done_today=false;

int  PHM(const string s){int c=StringFind(s,":"); if(c<=0)return -1; int h=(int)StringToInteger(StringSubstr(s,0,c)),m=(int)StringToInteger(StringSubstr(s,c+1)); if(h<0||h>23||m<0||m>59)return -1; return h*60+m;}
int  BMIN(const datetime t){MqlDateTime d; TimeToStruct(t,d); return d.hour*60+d.min;}
long DKEY(const datetime t){MqlDateTime d; TimeToStruct(t,d); return (long)d.year*10000+(long)d.mon*100+d.day;}
int  NYC(const string s){int m=PHM(s); if(m<0)return -1; if(cutoff_anchor_ny)m=((m+broker_ny_offset_min)%1440+1440)%1440; return m;}

void RESET(const long k){g_daykey=k; g_phase=0; g_dhigh=0; g_dlow=DBL_MAX; g_frozen=false; g_buy=false; g_mss=0; g_since=0; g_raid_extreme=0; g_fvg=false; g_done_today=false;}

bool HasPos(){const int mg=QM_FrameworkMagic(); for(int i=PositionsTotal()-1;i>=0;--i){ulong t=PositionGetTicket(i); if(t==0||!PositionSelectByTicket(t))continue; if(PositionGetString(POSITION_SYMBOL)!=_Symbol)continue; if((int)PositionGetInteger(POSITION_MAGIC)==mg)return true;} return false;}

// (1) HTF bias: +1 bullish / -1 bearish / 0 flat, from D1 EMA slope+position
int HTFBias()
  {
   const double ema=QM_EMA(_Symbol,PERIOD_D1,htf_bias_ema,1);
   const double c=iClose(_Symbol,PERIOD_D1,1);
   if(ema<=0||c<=0)return 0;
   return (c>ema)?1:((c<ema)?-1:0);
  }

// (2) Draw-on-liquidity: nearest opposing pool. For a LONG, the highest high of
// the last dol_lookback bars ABOVE entry (buy-side liquidity). For a SHORT, the
// lowest low BELOW entry (sell-side liquidity).
double DOL(const bool buy,const double entry)
  {
   const ENUM_TIMEFRAMES tf=(ENUM_TIMEFRAMES)_Period; double best=0;
   if(buy){ double hh=0; for(int i=1;i<=dol_lookback_bars;++i){double h=iHigh(_Symbol,tf,i); if(h>hh)hh=h;} if(hh>entry)best=hh; }
   else   { double ll=DBL_MAX; for(int i=1;i<=dol_lookback_bars;++i){double l=iLow(_Symbol,tf,i); if(l>0&&l<ll)ll=l;} if(ll<entry)best=ll; }
   return best;
  }

bool FindFVG(const bool buy)
  {
   const ENUM_TIMEFRAMES tf=(ENUM_TIMEFRAMES)_Period; const double atr=QM_ATR(_Symbol,tf,atr_fvg_period,1); if(atr<=0)return false;
   const double minw=atr*fvg_min_size, maxw=(fvg_max_size>0)?atr*fvg_max_size:0.0;
   for(int i=1;i<=fractal_lookback+5;++i){
      double l1=iLow(_Symbol,tf,i),h1=iHigh(_Symbol,tf,i),l3=iLow(_Symbol,tf,i+2),h3=iHigh(_Symbol,tf,i+2);
      if(l1<=0||h1<=0||l3<=0||h3<=0)continue; double glo=0,ghi=0,near=0,far=0; bool f=false;
      if(buy){ if(l1>h3){glo=h3;ghi=l1;near=l1;far=h3;f=true;} } else { if(h1<l3){glo=h1;ghi=l3;near=h1;far=l3;f=true;} }
      if(!f)continue; double w=ghi-glo; if(w<=0||w<minw)continue; if(maxw>0&&w>maxw)continue;
      if(ghi<g_dlow||glo>g_dhigh)continue;
      g_fvg=true; g_fvg_buy=buy; g_fvg_near=near; g_fvg_far=far; g_fvg_mid=(glo+ghi)*0.5; g_fvg_w=w; return true;}
   return false;
  }

bool FindFractal(const bool buy,double &lvl)
  {
   const ENUM_TIMEFRAMES tf=(ENUM_TIMEFRAMES)_Period; const int k=MathMax(1,fractal_strength);
   for(int c=2;c<=1+fractal_lookback;++c){ bool fr=true;
      if(buy){double cl=iLow(_Symbol,tf,c); if(cl<=0)return false; for(int s=1;s<=k&&fr;++s){double a=iLow(_Symbol,tf,c+s),b=iLow(_Symbol,tf,c-s); if(a<=0||b<=0||a<=cl||b<=cl)fr=false;} if(fr){lvl=cl;return true;}}
      else  {double ch=iHigh(_Symbol,tf,c); if(ch<=0)return false; for(int s=1;s<=k&&fr;++s){double a=iHigh(_Symbol,tf,c+s),b=iHigh(_Symbol,tf,c-s); if(a<=0||b<=0||a>=ch||b>=ch)fr=false;} if(fr){lvl=ch;return true;}}}
   return false;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period!=PERIOD_M5)return true;
   if(strategy_max_spread_points>0 && SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)>strategy_max_spread_points)return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type=QM_BUY; req.price=0; req.sl=0; req.tp=0; req.reason=""; req.symbol_slot=qm_magic_slot_offset; req.expiration_seconds=0;
   const ENUM_TIMEFRAMES tf=(ENUM_TIMEFRAMES)_Period;
   if(Bars(_Symbol,tf)<fractal_lookback+atr_fvg_period+10)return false;
   const int cutoff=NYC(cutoff_time),wend=NYC(window_end_time);
   const datetime bt=iTime(_Symbol,tf,1); if(bt<=0)return false;
   const long bday=DKEY(bt); const int bmin=BMIN(bt);
   if(bday!=g_daykey)RESET(bday);
   if(g_phase==4||g_done_today)return false;
   const double bh=iHigh(_Symbol,tf,1),bl=iLow(_Symbol,tf,1),bc=iClose(_Symbol,tf,1); if(bh<=0||bl<=0||bc<=0)return false;

   // Step 1: build + freeze day range at cutoff
   if(!g_frozen){ if(g_dhigh<=0||bh>g_dhigh)g_dhigh=bh; if(g_dlow>=DBL_MAX||bl<g_dlow)g_dlow=bl;
      if(cutoff>=0&&bmin>=cutoff&&g_dhigh>g_dlow){g_frozen=true;g_phase=1;} return false; }
   // only within killzone window
   if(wend>=0&&bmin>=wend&&g_phase<3){g_phase=4; return false;}

   const int bias=use_htf_bias?HTFBias():0;

   // Step 2: sweep (break + close back inside). (1) BIAS GATE: keep only the
   // setup direction that aligns with HTF bias.
   if(g_phase==1){
      const bool bhi=(bh>g_dhigh),blo=(bl<g_dlow),inside=(bc<=g_dhigh&&bc>=g_dlow);
      bool reg=false,rbuy=false; double raid=0;
      if(bhi&&inside){reg=true;rbuy=false;raid=bh;}      // high swept -> sell setup, raid wick = bar high
      else if(blo&&inside){reg=true;rbuy=true;raid=bl;}  // low swept -> buy setup, raid wick = bar low
      if(reg && use_htf_bias){ if((rbuy&&bias<=0)||(!rbuy&&bias>=0)) reg=false; } // (1) drop counter-bias setups
      if(reg){ g_buy=rbuy; g_raid_extreme=raid; g_since=0; double lvl=0; if(FindFractal(rbuy,lvl)&&lvl>0){g_mss=lvl;g_phase=2;} else g_phase=4; }
      return false; }

   // Step 3: MSS confirm
   if(g_phase==2){ g_since++;
      const bool conf=g_buy?(bc>g_mss):(bc<g_mss);
      if(conf){ if(FindFVG(g_buy))g_phase=3; else g_phase=4; }
      return false; }

   // Step 4: FVG midpoint touch -> enter (market) with raid-wick stop + DOL target
   if(g_phase==3&&g_fvg){
      const bool touched=(bh>=g_fvg_mid&&bl<=g_fvg_mid); if(!touched)return false;
      if(HasPos()){g_phase=4;return false;}
      const double atr=QM_ATR(_Symbol,tf,14,1); const double buf=stop_buffer_atr*atr;
      const double entry=g_fvg_mid;
      // (3) raid-wick stop
      const double sl=g_fvg_buy?(g_raid_extreme-buf):(g_raid_extreme+buf);
      if((g_fvg_buy&&sl>=entry)||(!g_fvg_buy&&sl<=entry)){g_phase=4;return false;}
      const double risk=MathAbs(entry-sl);
      // (2) DOL target, clamped to [min_rr, max_rr]
      double tp=0;
      if(target_draw_on_liquidity){ double dol=DOL(g_fvg_buy,entry);
         if(dol>0){ const double rr=MathAbs(dol-entry)/risk; if(rr<min_rr)tp=g_fvg_buy?entry+min_rr*risk:entry-min_rr*risk;
                    else if(rr>max_rr)tp=g_fvg_buy?entry+max_rr*risk:entry-max_rr*risk; else tp=dol; } }
      if(tp<=0)tp=g_fvg_buy?entry+min_rr*risk:entry-min_rr*risk; // fallback
      const double pt=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
      if(entry<=0||sl<=0||tp<=0||pt<=0||risk/pt<2.0){g_phase=4;return false;}
      req.type=g_fvg_buy?QM_BUY:QM_SELL; req.price=0; req.sl=QM_StopRulesNormalizePrice(_Symbol,sl); req.tp=QM_StopRulesNormalizePrice(_Symbol,tp);
      req.reason=g_fvg_buy?"SBv2_BUY":"SBv2_SELL"; req.symbol_slot=qm_magic_slot_offset;
      g_done_today=true; g_phase=4; return true; }
   return false;
  }

void Strategy_ManageOpenPosition(){}

bool Strategy_ExitSignal()
  {
   if(_Period!=PERIOD_M5)return false;
   const int close=NYC(closing_time); if(close<0)return false;
   return (BMIN(TimeCurrent())>=close);
  }

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,qm_magic_slot_offset,RISK_PERCENT,RISK_FIXED,PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,qm_friday_close_enabled,qm_friday_close_hour_broker,30,30,
                        qm_news_stale_max_hours,qm_news_min_impact,qm_rng_seed,qm_stress_reject_probability,
                        qm_news_temporal,qm_news_compliance)) return INIT_FAILED;
   g_dlow=DBL_MAX; return INIT_SUCCEEDED;
  }
void OnDeinit(const int reason){ QM_FrameworkShutdown(); }
void OnTick()
  {
   if(!QM_KillSwitchCheck())return;
   if(QM_FrameworkHandleFridayClose())return;
   if(Strategy_NoTradeFilter())return;
   if(Strategy_ExitSignal()){ const int mg=QM_FrameworkMagic(); for(int i=PositionsTotal()-1;i>=0;--i){ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t))continue; if(PositionGetInteger(POSITION_MAGIC)!=mg)continue; QM_TM_ClosePosition(t,QM_EXIT_STRATEGY);} }
   if(!QM_IsNewBar())return;
   QM_EquityStreamOnNewBar();
   QM_EntryRequest req; if(Strategy_EntrySignal(req)){ ulong tk=0; QM_TM_OpenPosition(req,tk); }
  }
void OnTimer(){ QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &t,const MqlTradeRequest &r,const MqlTradeResult &s){ QM_FrameworkOnTradeTransaction(t,r,s); }
double OnTester(){ QM_ChartUI_Refresh(); return QM_DefaultObjective(); }
