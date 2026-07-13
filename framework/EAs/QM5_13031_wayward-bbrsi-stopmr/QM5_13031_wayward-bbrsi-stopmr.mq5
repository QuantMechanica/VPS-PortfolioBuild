#property strict
#property version   "5.1"
#property description "QM5_13031 Wayward BB+RSI Stop-Order Mean-Reversion (CapFree video 1+2 port)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_13031 wayward-bbrsi-stopmr
// -----------------------------------------------------------------------------
// Faithful port of the "Wayward Trading Bot" (Mr. CapFree, YouTube):
//   Video 1 (mtWN6oPIi1Y, full code shown): BB(20,2)-stretch + RSI(14) exhaustion
//     (50±filter=30 → <20/>80) + setup-candle range > ATR×mult, entry via STOP
//     order at ±order_dist×ATR (rebound confirmation), SL = 2×ATR from entry,
//     TP = BB middle, trailing SL 0.2×ATR, spread guard, session window.
//     Extraction: artifacts/research/71235187_wayward_bot_full_extraction_2026-07-07.md
//   Video 2 (nZwt57f8-oA, "Part 2"): higher-TF BB confluence (the declared-but-
//     unused higher_tf input of video 1, now implemented) + spike veto ("when
//     NOT to trade"). DD-halt controls of video 2 = framework KillSwitch domain.
// Bar-gated framework adaptation (documented deviations from the tick scalper):
//   - signals evaluated once per closed M15 bar (close1 vs bands at shift 1)
//   - pending-order trailing approximated by short expiration + fresh re-price
//     on the next signal bar
//   - spike filter (tick-jump pause) adapted as extreme-candle veto:
//     skip setups whose trigger candle range exceeds veto_mult×ATR (0 = off)
// No grid/martingale/averaging. No ML.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 13031;
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
input int    strategy_bb_period          = 20;    // video: BB_period
input double strategy_bb_deviation       = 2.0;   // video: BB_deviation
input int    strategy_rsi_period         = 14;    // video: RSI_period
input int    strategy_rsi_filter         = 30;    // video: 50±30 → <20 / >80
input int    strategy_atr_period         = 14;
input double strategy_candle_atr_mult    = 1.0;   // setup candle range > this×ATR
input double strategy_sl_atr             = 2.0;   // SL distance from entry
input double strategy_trail_atr          = 0.2;   // trailing SL distance
input double strategy_order_dist_atr     = 0.2;   // stop-order offset from price
input int    strategy_pending_expiry_bars = 2;    // pending lifetime (bars)
input int    strategy_max_spread_points  = 10;    // fail-open at 0 spread (.DWX)
input int    strategy_start_hour         = -1;    // -1 = session window off
input int    strategy_end_hour           = -1;

input group "Video-2 Filters"
input bool             strategy_use_htf_confluence = false;  // HTF BB must be broken too
input ENUM_TIMEFRAMES  strategy_htf                = PERIOD_H4;
input int              strategy_htf_bb_period      = 20;
input double           strategy_htf_bb_deviation   = 2.0;
input double           strategy_spike_veto_atr_mult = 0.0;   // >0: skip if candle range > this×ATR

// -----------------------------------------------------------------------------
// helpers
// -----------------------------------------------------------------------------

bool QM13031_HasOpenOrPending()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return true;
   const long magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(OrderGetInteger(ORDER_MAGIC) == magic && OrderGetString(ORDER_SYMBOL) == _Symbol)
         return true;
     }
   return false;
  }

bool QM13031_SpreadOk()
  {
   const int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread <= 0)
      return true;                       // .DWX zero-spread — fail-open
   return (spread <= strategy_max_spread_points);
  }

bool QM13031_SessionOk()
  {
   if(strategy_start_hour < 0 || strategy_end_hour < 0)
      return true;                       // window off (video default: inactive)
   MqlDateTime t;
   TimeToStruct(TimeCurrent(), t);
   if(strategy_start_hour <= strategy_end_hour)
      return (t.hour >= strategy_start_hour && t.hour < strategy_end_hour);
   return (t.hour >= strategy_start_hour || t.hour < strategy_end_hour);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
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

   if(strategy_bb_period <= 0 || strategy_bb_deviation <= 0.0 ||
      strategy_rsi_period <= 0 || strategy_atr_period <= 0 ||
      strategy_rsi_filter <= 0 || strategy_rsi_filter >= 50)
      return false;
   if(QM13031_HasOpenOrPending())
      return false;
   if(!QM13031_SpreadOk() || !QM13031_SessionOk())
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double high1  = iHigh(_Symbol, PERIOD_CURRENT, 1);
   const double low1   = iLow(_Symbol, PERIOD_CURRENT, 1);
   const double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   if(high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0)
      return false;
   const double range1 = high1 - low1;

   // setup candle must be LARGE (video: candle size > ATR×mult)…
   if(range1 <= strategy_candle_atr_mult * atr)
      return false;
   // …but not a violent spike (video 2 adaptation; 0 = off)
   if(strategy_spike_veto_atr_mult > 0.0 && range1 > strategy_spike_veto_atr_mult * atr)
      return false;

   const double bb_up  = QM_BB_Upper(_Symbol, PERIOD_CURRENT, strategy_bb_period, strategy_bb_deviation, 1);
   const double bb_mid = QM_BB_Middle(_Symbol, PERIOD_CURRENT, strategy_bb_period, strategy_bb_deviation, 1);
   const double bb_lo  = QM_BB_Lower(_Symbol, PERIOD_CURRENT, strategy_bb_period, strategy_bb_deviation, 1);
   const double rsi1   = QM_RSI(_Symbol, PERIOD_CURRENT, strategy_rsi_period, 1);
   if(bb_up <= 0.0 || bb_mid <= 0.0 || bb_lo <= 0.0 || rsi1 <= 0.0)
      return false;

   const double rsi_buy_max  = 50.0 - strategy_rsi_filter;   // default 20
   const double rsi_sell_min = 50.0 + strategy_rsi_filter;   // default 80

   double htf_up = 0.0, htf_lo = 0.0;
   if(strategy_use_htf_confluence)
     {
      htf_up = QM_BB_Upper(_Symbol, strategy_htf, strategy_htf_bb_period, strategy_htf_bb_deviation, 1);
      htf_lo = QM_BB_Lower(_Symbol, strategy_htf, strategy_htf_bb_period, strategy_htf_bb_deviation, 1);
      if(htf_up <= 0.0 || htf_lo <= 0.0)
         return false;
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(ask <= 0.0 || bid <= 0.0)
      return false;
   const int expiry = strategy_pending_expiry_bars * PeriodSeconds(PERIOD_CURRENT);

   // ---- BUY: price stretched BELOW lower band + RSI exhausted ----
   if(close1 < bb_lo && rsi1 < rsi_buy_max &&
      (!strategy_use_htf_confluence || close1 < htf_lo))
     {
      const double entry = NormalizeDouble(ask + strategy_order_dist_atr * atr, digits);
      const double sl    = NormalizeDouble(entry - strategy_sl_atr * atr, digits);
      const double tp    = NormalizeDouble(MathMax(bb_mid, entry + (entry - sl) * 0.1), digits);
      if(tp <= entry || sl >= entry)
         return false;
      req.type = QM_BUY_STOP;
      req.price = entry;
      req.sl = sl;
      req.tp = tp;
      req.expiration_seconds = expiry;
      req.reason = "WAYWARD_BB_RSI_LONG";
      return true;
     }

   // ---- SELL: price stretched ABOVE upper band + RSI exhausted ----
   if(close1 > bb_up && rsi1 > rsi_sell_min &&
      (!strategy_use_htf_confluence || close1 > htf_up))
     {
      const double entry = NormalizeDouble(bid - strategy_order_dist_atr * atr, digits);
      const double sl    = NormalizeDouble(entry + strategy_sl_atr * atr, digits);
      const double tp    = NormalizeDouble(MathMin(bb_mid, entry - (sl - entry) * 0.1), digits);
      if(tp >= entry || sl <= entry)
         return false;
      req.type = QM_SELL_STOP;
      req.price = entry;
      req.sl = sl;
      req.tp = tp;
      req.expiration_seconds = expiry;
      req.reason = "WAYWARD_BB_RSI_SHORT";
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   if(strategy_trail_atr <= 0.0)
      return;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr);
     }
  }

bool Strategy_ExitSignal()
  {
   return false;   // SL / TP(BB-middle) / trailing do the exits (video design)
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring
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
