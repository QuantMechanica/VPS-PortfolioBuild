#property strict
#property version   "5.0"
#property description "QM5_11537 Carter-T H1 EMA(75) + Bollinger-middle(20,2) + RSI(14) trend-state"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_11537
// Source: Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)",
//         System #11, self-published 2014. Source id 3001a121-97a0-5db0-b6ff-69b89a0fc07d.
// Card: cards_approved/QM5_11537_carter-t-h1-ema5s5-ema75-bb-rsi.md
//
// Mechanik (P2-simplified per card):
//   LONG  : close[1] > EMA(75) AND close[1] > BollingerMiddle(20,2) AND RSI(14)[1] > 50
//   SHORT : close[1] < EMA(75) AND close[1] < BollingerMiddle(20,2) AND RSI(14)[1] < 50
//   SL    : 5-bar swing low/high, capped at 40 pips (tighter of the two).
//   TP    : 2 x SL distance (2:1 RR).
//   No Friday entry. Spread cap 15 pips. Symbols EURUSD.DWX, GBPUSD.DWX. TF H1.
//
// The EMA(5,shift5) mentioned by the source is a visual SL aid only; the card's
// P2 simplification replaces it with the swing/40-pip stop, so it is NOT an
// entry filter here (task spec: "do NOT implement the EMA5-shift5").
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11537;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.5;
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
input int    strategy_ema_period        = 75;    // EMA trend filter (P3 sweeps 50/75/100)
input int    strategy_bb_period         = 20;    // Bollinger middle SMA period
input double strategy_bb_deviation      = 2.0;   // Bollinger deviation (mandatory arg; P3 sweeps 2/2.5)
input int    strategy_rsi_period        = 14;    // RSI confirmation period
input double strategy_rsi_threshold     = 50.0;  // RSI directional threshold
input int    strategy_swing_lookback    = 5;     // 5-bar swing low/high for SL structure
input int    strategy_sl_cap_pips       = 40;    // P2 cap on swing SL distance (pips)
input double strategy_rr                = 2.0;   // TP = RR x SL distance (2:1)
input int    strategy_max_spread_pips   = 15;    // Spread cap blocking fresh entries only

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// O(1) per-tick guard: block only a genuinely wide spread. The .DWX tester
// spread is always 0, so this never blocks in backtest (invariant #1); it only
// bites live / on real spread. Never gate on spread<=0.
bool Strategy_NoTradeFilter()
{
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_max_spread_pips);
   if(spread_cap <= 0.0)
      return true;
   if((ask - bid) > spread_cap)
      return true;

   return false;
}

// Trend-state entry. Caller guarantees QM_IsNewBar()==true, so the closed-bar
// reads at shift 1 are evaluated once per H1 bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   const int magic = QM_FrameworkMagic();
   if(QM_EntryHasOpenPosition(magic, _Symbol))
      return false;

   // No Friday entry (card filter). TimeCurrent() is broker time in the tester.
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day_of_week == 5)
      return false;

   if(strategy_ema_period <= 0 || strategy_bb_period <= 0 || strategy_rsi_period <= 0)
      return false;

   const double close1 = iClose(_Symbol, PERIOD_H1, 1); // perf-allowed: single closed-bar close behind the QM_IsNewBar gate; no framework price reader exists.
   const double ema1   = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_period, 1);
   const double mid1   = QM_BB_Middle(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_deviation, 1);
   const double rsi1   = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, 1);
   if(close1 <= 0.0 || ema1 <= 0.0 || mid1 <= 0.0 || rsi1 <= 0.0)
      return false;

   const bool long_sig  = (close1 > ema1) && (close1 > mid1) && (rsi1 > strategy_rsi_threshold);
   const bool short_sig = (close1 < ema1) && (close1 < mid1) && (rsi1 < strategy_rsi_threshold);
   if(long_sig == short_sig)   // neither fired (or contradictory) — no trade
      return false;

   const QM_OrderType side = long_sig ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // SL = 5-bar swing extreme (QM_StopStructure reads iLow/iHigh over shift
   // 1..lookback), then cap the DISTANCE at 40 pips: take the tighter of the
   // two (card P2 rule).
   const double cap_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
   if(cap_dist <= 0.0)
      return false;

   const double swing_price = QM_StopStructure(_Symbol, side, entry, strategy_swing_lookback);
   double sl_dist = cap_dist;
   if(swing_price > 0.0)
   {
      const double swing_dist = (side == QM_BUY) ? (entry - swing_price) : (swing_price - entry);
      if(swing_dist > 0.0)
         sl_dist = MathMin(swing_dist, cap_dist);
   }
   if(sl_dist <= 0.0)
      return false;

   const double sl = QM_StopRulesStopFromDistance(_Symbol, side, entry, sl_dist);
   if(sl <= 0.0)
      return false;
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_rr);
   if(tp <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;                       // market fill at bar open
   req.sl = sl;
   req.tp = tp;
   req.reason = long_sig ? "CARTER11_EMA75_BB_RSI_LONG" : "CARTER11_EMA75_BB_RSI_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
}

// No trailing / partial / break-even in the card — exits are the attached
// SL / TP bracket plus the framework Friday close.
void Strategy_ManageOpenPosition()
{
}

// No discretionary exit signal in the card (exits via SL / TP / Friday close).
bool Strategy_ExitSignal()
{
   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time)
{
   return false; // defer to QM_NewsAllowsTrade(...)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_11537_carter-t-h1-ema5s5-ema75-bb-rsi\"}");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
}

void OnTick()
{
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
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

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
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
