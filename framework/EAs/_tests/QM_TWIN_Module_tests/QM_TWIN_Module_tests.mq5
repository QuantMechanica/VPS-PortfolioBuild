#property strict
#property version   "1.0"
#property description "Unit harness for QM5_12821 T-WIN modules"

#include <QM/QM_Common.mqh>
#include <QM/QM_CurrencyStrength.mqh>
#include <QM/QM_MTFCoherence.mqh>
#include <QM/QM_BasketBuilder.mqh>
#include <QM/QM_PullbackGate.mqh>
#include <QM/QM_BasketEquityStop.mqh>
#include <QM/QM_TWINWarmupGuard.mqh>

bool TestAssert(const bool condition, const string label)
  {
   if(condition)
      return true;
   PrintFormat("ASSERT_FAIL %s", label);
   return false;
  }

bool TestNear(const double actual, const double expected, const double eps, const string label)
  {
   if(MathAbs(actual - expected) <= eps)
      return true;
   PrintFormat("ASSERT_FAIL %s actual=%.8f expected=%.8f", label, actual, expected);
   return false;
  }

void BuildGbpStrongPerf(double &perf[])
  {
   ArrayResize(perf, QM_CSM_PAIR_COUNT);
   ArrayInitialize(perf, 0.0);
   perf[QM_CSM_PairSlot("GBPUSD.DWX")] = 1.0;
   perf[QM_CSM_PairSlot("EURGBP.DWX")] = -1.0;
   perf[QM_CSM_PairSlot("GBPJPY.DWX")] = 1.0;
   perf[QM_CSM_PairSlot("GBPCHF.DWX")] = 1.0;
   perf[QM_CSM_PairSlot("GBPAUD.DWX")] = 1.0;
   perf[QM_CSM_PairSlot("GBPNZD.DWX")] = 1.0;
   perf[QM_CSM_PairSlot("GBPCAD.DWX")] = 1.0;
  }

void InvertPerf(const double &src[], double &dst[])
  {
   ArrayResize(dst, QM_CSM_PAIR_COUNT);
   for(int i = 0; i < QM_CSM_PAIR_COUNT; ++i)
      dst[i] = -src[i];
  }

bool TestCurrencyStrength()
  {
   double perf[];
   BuildGbpStrongPerf(perf);

   QM_CSMReading reading;
   if(!TestAssert(QM_CSM_BuildFromPerf(perf, reading), "csm build succeeds"))
      return false;

   const int gbp = QM_CSM_CcyIndex("GBP");
   if(!TestNear(reading.strength[gbp], 7.0, 1e-9, "gbp strength"))
      return false;
   if(!TestNear(reading.zero_sum, 0.0, 1e-9, "zero sum"))
      return false;
   if(!TestNear(reading.normalized[gbp], 100.0, 1e-9, "gbp normalized"))
      return false;
   if(!TestNear(QM_CSM_ProbabilityRatio(reading, gbp), 1.0, 1e-9, "gbp probability 7 of 7"))
      return false;
   return TestAssert(QM_CSM_IsExhausted(reading, gbp, 95.0), "gbp exhausted");
  }

bool TestMtfCoherence()
  {
   double perf[];
   double inverse[];
   BuildGbpStrongPerf(perf);
   InvertPerf(perf, inverse);

   QM_CSMReading d1;
   QM_CSMReading w1;
   QM_CSMReading mn;
   QM_CSMReading bad_w1;
   QM_CSM_BuildFromPerf(perf, d1);
   QM_CSM_BuildFromPerf(perf, w1);
   QM_CSM_BuildFromPerf(perf, mn);
   QM_CSM_BuildFromPerf(inverse, bad_w1);

   const int gbp = QM_CSM_CcyIndex("GBP");
   QM_MTFCoherenceState state;
   if(!TestAssert(QM_MTFCoherence_Evaluate(d1, w1, mn, gbp, state), "mtf coherent"))
      return false;
   return TestAssert(!QM_MTFCoherence_Evaluate(d1, bad_w1, mn, gbp, state), "mtf contradiction rejects");
  }

bool TestBasketBuilder()
  {
   QM_BasketPlan plan;
   const int gbp = QM_CSM_CcyIndex("GBP");
   if(!TestAssert(QM_BasketBuilder_ModeC(gbp, 1, plan), "mode c gbp strong builds"))
      return false;
   if(!TestAssert(plan.leg_count == 7, "mode c has seven legs"))
      return false;
   if(!TestAssert(QM_BasketBuilder_HasLeg(plan, "GBPUSD.DWX", QM_BUY), "gbpusd buy"))
      return false;
   if(!TestAssert(QM_BasketBuilder_HasLeg(plan, "GBPCAD.DWX", QM_BUY), "gbpcad buy"))
      return false;
   if(!TestAssert(QM_BasketBuilder_HasLeg(plan, "GBPAUD.DWX", QM_BUY), "gbpaud buy"))
      return false;
   if(!TestAssert(QM_BasketBuilder_HasLeg(plan, "GBPNZD.DWX", QM_BUY), "gbpnzd buy"))
      return false;
   if(!TestAssert(QM_BasketBuilder_HasLeg(plan, "GBPCHF.DWX", QM_BUY), "gbpchf buy"))
      return false;
   if(!TestAssert(QM_BasketBuilder_HasLeg(plan, "GBPJPY.DWX", QM_BUY), "gbpjpy buy"))
      return false;
   return TestAssert(QM_BasketBuilder_HasLeg(plan, "EURGBP.DWX", QM_SELL), "eurgbp sell");
  }

bool TestPullbackGate()
  {
   QM_PullbackGateResult result;
   if(!TestAssert(QM_PullbackGate_Evaluate(100.20, 100.00, 1.00, QM_BUY, 0.25, 1.00, result), "pullback buy valid"))
      return false;
   if(!TestAssert(result.accepted && !result.extended, "pullback buy accepted"))
      return false;
   if(!TestAssert(QM_PullbackGate_Evaluate(101.20, 100.00, 1.00, QM_BUY, 0.25, 1.00, result), "extended buy valid"))
      return false;
   if(!TestAssert(!result.accepted && result.extended, "extended buy rejected"))
      return false;
   if(!TestAssert(QM_PullbackGate_Evaluate(99.80, 100.00, 1.00, QM_SELL, 0.25, 1.00, result), "pullback sell valid"))
      return false;
   if(!TestAssert(result.accepted && !result.extended, "pullback sell accepted"))
      return false;
   if(!TestAssert(QM_PullbackGate_Evaluate(98.70, 100.00, 1.00, QM_SELL, 0.25, 1.00, result), "extended sell valid"))
      return false;
   if(!TestAssert(!result.accepted && result.extended, "extended sell rejected"))
      return false;

   if(!TestAssert(QM_PullbackGate_EvaluateBar(100.50, 99.60, 100.05, 80, 100.0,
                                             100.00, 1.00, QM_BUY, 0.25, 1.00, 1.00, result),
                  "buy boundary bar valid"))
      return false;
   if(!TestAssert(result.accepted && result.boundary_touched && result.volume_confirmed, "buy boundary accepted"))
      return false;
   if(!TestNear(result.boundary_price, 99.75, 1e-9, "buy boundary price"))
      return false;
   if(!TestAssert(QM_PullbackGate_EvaluateBar(100.40, 99.60, 100.05, 140, 100.0,
                                             100.00, 1.00, QM_BUY, 0.25, 1.00, 1.00, result),
                  "high volume boundary bar valid"))
      return false;
   if(!TestAssert(!result.accepted && result.boundary_touched && !result.volume_confirmed, "high volume rejected"))
      return false;
   if(!TestAssert(QM_PullbackGate_EvaluateBar(100.40, 99.55, 99.95, 75, 100.0,
                                             100.00, 1.00, QM_SELL, 0.25, 1.00, 1.00, result),
                  "sell nonboundary bar valid"))
      return false;
   return TestAssert(!result.accepted && !result.boundary_touched, "sell requires upper boundary touch");
  }

bool TestBasketEquityStop()
  {
   QM_BasketEquityDecision decision;
   if(!TestAssert(QM_BasketEquityStop_Evaluate(-1000.0, 100000.0, 1.0, 15.0, decision), "equity stop eval"))
      return false;
   if(!TestAssert(decision.should_stop, "one pct stop fires"))
      return false;
   if(!TestNear(decision.stop_threshold, -1000.0, 1e-9, "stop threshold"))
      return false;
   if(!TestAssert(QM_BasketEquityStop_Evaluate(15000.0, 100000.0, 1.0, 15.0, decision), "equity tp eval"))
      return false;
   return TestAssert(decision.should_take_profit, "fifteen pct take profit fires");
  }

bool TestMtfWarmupGuard()
  {
   const datetime first_bar = D'2018.07.02 00:00';
   const datetime expected_ready = first_bar +
                                   (datetime)(QM_TWIN_MTF_WARMUP_MN_DAYS *
                                              QM_TWIN_SECONDS_PER_DAY);
   if(!TestAssert(QM_TWIN_MtfWarmupReadyTime(first_bar) == expected_ready,
                  "mtf warmup ready after one mn-equivalent period"))
      return false;
   if(!TestAssert(!QM_TWIN_MtfWarmupReady(first_bar,
                                          first_bar + (datetime)(30 * QM_TWIN_SECONDS_PER_DAY)),
                  "mtf warmup blocks immature mn window"))
      return false;
   if(!TestAssert(!QM_TWIN_MtfWarmupReady(first_bar,
                                          first_bar + (datetime)(28 * QM_TWIN_SECONDS_PER_DAY)),
                  "mtf warmup blocks four-week boundary before mn maturity"))
      return false;
   return TestAssert(QM_TWIN_MtfWarmupReady(first_bar, expected_ready),
                     "mtf warmup ready at maturity");
  }

int OnInit()
  {
   if(!TestCurrencyStrength())
      return INIT_FAILED;
   if(!TestMtfCoherence())
      return INIT_FAILED;
   if(!TestBasketBuilder())
      return INIT_FAILED;
   if(!TestPullbackGate())
      return INIT_FAILED;
   if(!TestBasketEquityStop())
      return INIT_FAILED;
   if(!TestMtfWarmupGuard())
      return INIT_FAILED;
   Print("QM_TWIN_Module_tests PASS");
   return INIT_SUCCEEDED;
  }

void OnTick()
  {
  }
