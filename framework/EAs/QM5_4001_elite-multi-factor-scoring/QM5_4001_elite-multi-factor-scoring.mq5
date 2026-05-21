#property strict
#property version   "5.0"
#property description "QM5_4001 Elite Multi-Factor Scoring Quant"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_4001: The Multi-Factor Quant
// -----------------------------------------------------------------------------
// Scoring system combining 4 factors:
// 1. Trend: SMA 50 > SMA 200
// 2. Momentum: RSI (14) < 45 (for Long, seeking recovery)
// 3. Volatility: ATR Expansion (Current > 20-period MA of ATR)
// 4. Price Action: Recent Bar is Bullish
// Trade if Score >= 3.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 4001;
input int    qm_magic_slot_offset       = 0;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "Strategy Parameters"
input int    strategy_sma_fast          = 50;
input int    strategy_sma_slow          = 200;
input int    strategy_rsi_period        = 14;
input int    strategy_atr_period        = 14;
input int    strategy_atr_ma_period     = 20;
input int    strategy_score_threshold   = 3;
input double strategy_rr                = 1.5;
input int    strategy_spread_cap_points  = 25;

int CalculateScore(const int shift)
  {
   int score = 0;

   // Factor 1: Trend
   const double sma_50 = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_sma_fast, shift);
   const double sma_200 = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_sma_slow, shift);
   if(sma_50 > sma_200) score++;

   // Factor 2: RSI
   const double rsi = QM_RSI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_rsi_period, shift);
   if(rsi < 45) score++;

   // Factor 3: ATR Expansion
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, shift);
   double atr_sum = 0;
   for(int i = 0; i < strategy_atr_ma_period; ++i)
      atr_sum += QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, shift + i);
   const double atr_ma = atr_sum / strategy_atr_ma_period;
   if(atr > atr_ma) score++;

   // Factor 4: PA
   if(iClose(_Symbol, _Period, shift) > iOpen(_Symbol, _Period, shift)) score++;

   return score;
  }

bool HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic) return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(strategy_spread_cap_points > 0 && spread > strategy_spread_cap_points) return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(HasOpenPosition()) return false;

   const int score_1 = CalculateScore(1);

   if(score_1 >= strategy_score_threshold)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_StopATR(_Symbol, req.type, QM_EntryMarketPrice(req.type), strategy_atr_period, 1.5);
      req.tp = QM_TakeRR(_Symbol, req.type, QM_EntryMarketPrice(req.type), req.sl, strategy_rr);
      req.reason = StringFormat("SCORE_%d", score_1);
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   return false;
  }

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const int score_0 = CalculateScore(0);
      if(score_0 <= 1) return true;
     }
   return false;
  }

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT, QM_NEWS_OFF))
      return INIT_FAILED;
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason) { QM_FrameworkShutdown(); }

void OnTick()
  {
   if(!QM_KillSwitchCheck()) return;
   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;

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

   if(!QM_IsNewBar()) return;

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
     }
  }

void OnTimer() { QM_FrameworkOnTimer(); }
double OnTester() { QM_ChartUI_Refresh(); return QM_DefaultObjective(); }
