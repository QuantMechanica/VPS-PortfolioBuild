#property strict
#property version   "5.0"
#property description "QuantMechanica V5 — QM5_9299 mql5-bears-ema"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9299 mql5-bears-ema
// Bear's Power (13) + EMA(13) trend-following system.
// Source: Mohamed Abdelmaaboud, MQL5 Articles 2022-08-10.
// Card:   artifacts/cards_approved/QM5_9299_mql5-bears-ema.md
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9299;
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
input int    strategy_bearspower_period = 13;   // Bear's Power oscillator period
input int    strategy_ema_period        = 13;   // EMA period for price-side filter
input int    strategy_atr_period        = 14;   // ATR period for initial stop
input double strategy_atr_sl_mult       = 2.0;  // ATR stop multiplier
input int    strategy_swing_bars        = 5;    // Swing low/high lookback bars

// -----------------------------------------------------------------------------
// Bears Power pooled reader — uses framework indicator pool, no file-scope handle.
// iBearsPower is not in QM_Indicators; follow QM_IndicatorsLookup/Register pattern.
// -----------------------------------------------------------------------------
double StrategyBearsPower(const string sym, const ENUM_TIMEFRAMES tf,
                          const int period, const int shift)
  {
   const string key = StringFormat("BEARSPOWER|%s|%d|%d", sym, (int)tf, period);
   int h = QM_IndicatorsLookup(key);
   if(h == INVALID_HANDLE)
     {
      h = iBearsPower(sym, tf, period);
      h = QM_IndicatorsRegister(key, h);
     }
   return QM_IndicatorReadBuffer(h, 0, shift);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No Trade Filter — framework handles news/spread; no extra session filter.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Trade Entry — closed-bar Bears Power sign + EMA price-side.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One active position per magic
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   // Closed-bar indicator reads (shift=1 = last fully closed bar)
   const double bp    = StrategyBearsPower(_Symbol, _Period, strategy_bearspower_period, 1);
   const double ema   = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read

   if(bp == 0.0 || ema <= 0.0 || close1 <= 0.0)
      return false;

   QM_OrderType side;
   if(bp > 0.0 && close1 > ema)
      side = QM_BUY;
   else if(bp < 0.0 && close1 < ema)
      side = QM_SELL;
   else
      return false;

   // Current market entry price
   const double entry = QM_OrderTypeIsBuy(side)
      ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
      : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // Stop loss: ATR(14)×2.0 or 5-bar swing extreme, whichever is closer to entry
   const double sl_atr       = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_sl_mult);
   const double sl_structure = QM_StopStructure(_Symbol, side, entry, strategy_swing_bars);

   double sl = sl_atr;
   if(sl_structure > 0.0)
     {
      if(QM_OrderTypeIsBuy(side))
         sl = MathMax(sl_atr, sl_structure);   // closer = higher price for longs
      else
         sl = MathMin(sl_atr, sl_structure);   // closer = lower price for shorts
     }
   if(sl <= 0.0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;
   const double sl_points = MathAbs(entry - sl) / point;
   if(sl_points < 1.0)
      return false;

   req.type         = side;
   req.price        = entry;
   req.sl           = sl;
   req.tp           = 0.0;   // exit driven by signal reversal
   req.reason       = "bears-ema";
   req.symbol_slot  = 0;

   return true;
  }

// Trade Management — no active trailing or BE; SL + signal-exit govern the trade.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close — exit when Bear's Power reverses sign or price crosses EMA.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE pos_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      const double bp    = StrategyBearsPower(_Symbol, _Period, strategy_bearspower_period, 1);
      const double ema   = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
      const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read

      if(bp == 0.0 || ema <= 0.0)
         return false;

      if(pos_type == POSITION_TYPE_BUY  && (bp < 0.0 || close1 < ema))
         return true;
      if(pos_type == POSITION_TYPE_SELL && (bp > 0.0 || close1 > ema))
         return true;
     }
   return false;
  }

// News Filter Hook — defer to framework two-axis filter.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{}");
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
