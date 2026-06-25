#property strict
#property version   "5.0"
#property description "QM5_1067 Carver Vol-Normalised FX Carry"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_1067 carver-carry-fx
// Source: Rob Carver blog / Systematic Trading ch.7
// Card: artifacts/cards_approved/QM5_1067_carver-carry-fx.md
// G0 APPROVED 2026-05-17
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1067;
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
// InpCarryBpsAnnual: annualised carry in bps (1bp=0.01%). 0=broker swap (=0 in DWX; set here for backtest).
// Positive=long base earns carry; negative=short earns carry. Card fallback: rate differential.
input double InpCarryBpsAnnual   = 100.0;
input int    InpEWMASpan         = 25;     // EWMA span for daily-return vol (bars)
input double InpForecastScalar   = 30.0;   // Carver forecast scalar
input double InpForecastCap      = 20.0;   // forecast cap ±
input double InpEntryForecast    = 2.0;    // min |forecast| to enter
input int    InpAtrPeriod        = 20;     // ATR period for emergency stop (D1 bars)
input double InpAtrSlMult        = 2.5;    // ATR multiplier for SL distance
input double InpSpreadCapPips    = 5.0;    // max spread pips for entry (0=off; DWX spread=0)

// -----------------------------------------------------------------------------
// File-scope carry/vol state (advanced once per closed D1 bar)
// -----------------------------------------------------------------------------
double g_ewma_var    = 0.0;
bool   g_ewma_seeded = false;
double g_forecast    = 0.0;

// Seed EWMA from closed-bar history — called once in OnInit.
// perf-allowed: bespoke EWMA-of-returns initialisation, no QM_* equivalent.
void SeedEWMA()
  {
   const double alpha = 2.0 / (InpEWMASpan + 1.0);
   const int warmup = InpEWMASpan * 3 + 1;
   g_ewma_var    = 0.0;
   g_ewma_seeded = false;
   for(int i = warmup; i >= 1; i--)
     {
      double c1 = iClose(_Symbol, PERIOD_D1, i);     // perf-allowed: EWMA seed in OnInit, not OnTick
      double c2 = iClose(_Symbol, PERIOD_D1, i + 1); // perf-allowed: EWMA seed in OnInit, not OnTick
      if(c1 <= 0.0 || c2 <= 0.0) continue;
      double ret = (c1 - c2) / c2;
      if(!g_ewma_seeded)
        { g_ewma_var = ret * ret; g_ewma_seeded = true; }
      else
         g_ewma_var = alpha * (ret * ret) + (1.0 - alpha) * g_ewma_var;
     }
  }

// Advance EWMA one step and recompute carry forecast.
// Called from Strategy_EntrySignal which runs only after QM_IsNewBar() == true.
// perf-allowed: bespoke EWMA-of-returns on new-bar gate, no QM_* equivalent.
void AdvanceState_OnNewBar()
  {
   double c1 = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: bespoke EWMA-of-returns, no QM_* equivalent
   double c2 = iClose(_Symbol, PERIOD_D1, 2); // perf-allowed: bespoke EWMA-of-returns, no QM_* equivalent
   if(c1 <= 0.0 || c2 <= 0.0) return;

   const double alpha = 2.0 / (InpEWMASpan + 1.0);
   double ret = (c1 - c2) / c2;

   if(!g_ewma_seeded)
     { g_ewma_var = ret * ret; g_ewma_seeded = true; }
   else
      g_ewma_var = alpha * (ret * ret) + (1.0 - alpha) * g_ewma_var;

   const double daily_vol = MathSqrt(g_ewma_var);
   const double ann_vol   = daily_vol * MathSqrt(256.0);
   if(ann_vol <= 0.0) { g_forecast = 0.0; return; }

   // Carry source: user InpCarryBpsAnnual first (required for DWX tester where swap=0).
   // Fallback to broker swap only if user left the override at 0.
   double carry_bps = InpCarryBpsAnnual;
   if(carry_bps == 0.0)
     {
      double swap_long = SymbolInfoDouble(_Symbol, SYMBOL_SWAP_LONG);
      double pt        = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double contract  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
      // Approximate annualised bps from swap points/lot/night (DWX tester: always 0).
      if(pt > 0.0 && contract > 0.0 && c1 > 0.0)
         carry_bps = (swap_long * pt / c1) * 365.0 * 10000.0;
     }

   const double carry_dec = carry_bps / 10000.0;
   double raw_carry = carry_dec / ann_vol;
   g_forecast = InpForecastScalar * raw_carry;
   g_forecast = MathMax(-InpForecastCap, MathMin(InpForecastCap, g_forecast));
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Spread guard (DWX: spread=0, never blocks in tester).
bool Strategy_NoTradeFilter()
  {
   if(InpSpreadCapPips > 0.0)
     {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(ask > 0.0 && bid > 0.0 && ask > bid)
        {
         double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         if(pt > 0.0)
           {
            int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
            double pip_pts = (digits >= 4) ? 10.0 : 1.0;
            double spread_pts = (ask - bid) / pt;
            if(spread_pts > InpSpreadCapPips * pip_pts)
               return true;
           }
        }
     }
   return false;
  }

// Advance EWMA state then check carry forecast threshold.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   AdvanceState_OnNewBar();

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(MathAbs(g_forecast) < InpEntryForecast)
      return false;

   bool go_long  = (g_forecast >  InpEntryForecast);
   bool go_short = (g_forecast < -InpEntryForecast);
   if(!go_long && !go_short) return false;

   req.type             = go_long ? QM_BUY : QM_SELL;
   req.price            = 0.0;
   req.symbol_slot      = qm_magic_slot_offset;
   req.reason           = StringFormat("carry_fx f=%.2f bps=%.0f", g_forecast, InpCarryBpsAnnual);
   req.expiration_seconds = 0;

   double entry_price = go_long
      ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
      : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   req.sl = QM_StopATR(_Symbol, req.type, entry_price, InpAtrPeriod, InpAtrSlMult);
   req.tp = 0.0;
   return true;
  }

// No active position management — carry exits via forecast sign flip.
void Strategy_ManageOpenPosition()
  {
  }

// Close when existing position direction contradicts current forecast sign.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) == 0)
      return false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      int pos_type = (int)PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY  && g_forecast < 0.0) return true;
      if(pos_type == POSITION_TYPE_SELL && g_forecast > 0.0) return true;
     }
   return false;
  }

// Defer central-bank news handling to framework qm_news_temporal.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line.
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
   SeedEWMA();
   QM_LogEvent(QM_INFO, "INIT_OK",
               StringFormat("{\"carry_bps\":%.1f,\"ewma_span\":%d}", InpCarryBpsAnnual, InpEWMASpan));
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
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
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
