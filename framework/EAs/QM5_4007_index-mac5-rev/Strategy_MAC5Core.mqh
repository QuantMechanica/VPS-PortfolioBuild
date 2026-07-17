#ifndef STRATEGY_MAC5_CORE_MQH
#define STRATEGY_MAC5_CORE_MQH

// Pure, broker-independent mechanics for SRC10_S01.  The caller supplies six
// valid completed D1 closes ordered newest first.  Close[0]..Close[4] map to
// broker series Close[1]..Close[5]; Close[5] is the card-required sixth
// completed-close validity guard and is deliberately not used in the driver.

enum Strategy_MAC5DeltaAction
  {
   STRATEGY_MAC5_ACTION_SKIP = 0,
   STRATEGY_MAC5_ACTION_RETAIN,
   STRATEGY_MAC5_ACTION_FLATTEN,
   STRATEGY_MAC5_ACTION_ENTER_LONG,
   STRATEGY_MAC5_ACTION_ENTER_SHORT,
   STRATEGY_MAC5_ACTION_FLIP_TO_LONG,
   STRATEGY_MAC5_ACTION_FLIP_TO_SHORT
  };

bool Strategy_MAC5ValidClose(const double value)
  {
   return (MathIsValidNumber(value) && value > 0.0);
  }

int Strategy_MAC5TargetFromCloses(const double &closes[],
                                  bool &valid,
                                  double &driver)
  {
   valid = false;
   driver = 0.0;
   if(ArraySize(closes) < 6)
      return 0;

   for(int i = 0; i < 6; ++i)
     {
      if(!Strategy_MAC5ValidClose(closes[i]))
         return 0;
     }

   const double r1 = MathLog(closes[0] / closes[1]);
   const double r2 = MathLog(closes[1] / closes[2]);
   const double r3 = MathLog(closes[2] / closes[3]);
   const double r4 = MathLog(closes[3] / closes[4]);
   if(!MathIsValidNumber(r1) || !MathIsValidNumber(r2) ||
      !MathIsValidNumber(r3) || !MathIsValidNumber(r4))
      return 0;

   driver = 4.0 * r1 + 3.0 * r2 + 2.0 * r3 + r4;
   if(!MathIsValidNumber(driver))
     {
      driver = 0.0;
      return 0;
     }

   const double scale = 4.0 * MathAbs(r1) + 3.0 * MathAbs(r2) +
                        2.0 * MathAbs(r3) + MathAbs(r4);
   const double tolerance = 32.0 * 2.2204460492503131e-16 *
                            MathMax(1.0, scale);
   valid = true;
   if(MathAbs(driver) <= tolerance)
      return 0;

   // Source-locked contrarian sign: positive MAC(5) -> short, negative -> long.
   return (driver > 0.0) ? -1 : 1;
  }

Strategy_MAC5DeltaAction Strategy_MAC5PlanDelta(const int current_direction,
                                                const int target_direction,
                                                const bool target_valid,
                                                const bool within_window,
                                                const bool entry_blocked)
  {
   const int current = (current_direction > 0) ? 1 :
                       ((current_direction < 0) ? -1 : 0);
   const int target = (target_direction > 0) ? 1 :
                      ((target_direction < 0) ? -1 : 0);

   if(!within_window || !target_valid || target == 0)
      return (current == 0) ? STRATEGY_MAC5_ACTION_SKIP
                            : STRATEGY_MAC5_ACTION_FLATTEN;

   if(current == target)
      return STRATEGY_MAC5_ACTION_RETAIN;

   if(current == 0)
     {
      if(entry_blocked)
         return STRATEGY_MAC5_ACTION_SKIP;
      return (target > 0) ? STRATEGY_MAC5_ACTION_ENTER_LONG
                          : STRATEGY_MAC5_ACTION_ENTER_SHORT;
     }

   // A prior attempt/exit/stop still mandates removal of the wrong target,
   // but cannot authorize a catch-up reverse entry.
   if(entry_blocked)
      return STRATEGY_MAC5_ACTION_FLATTEN;
   return (target > 0) ? STRATEGY_MAC5_ACTION_FLIP_TO_LONG
                       : STRATEGY_MAC5_ACTION_FLIP_TO_SHORT;
  }

bool Strategy_MAC5CoreSelfTest()
  {
   bool valid = false;
   double driver = 0.0;

   double rising[6] = {110.0, 108.0, 105.0, 103.0, 100.0, 98.0};
   if(Strategy_MAC5TargetFromCloses(rising, valid, driver) != -1 ||
      !valid || driver <= 0.0)
      return false;

   double falling[6] = {90.0, 92.0, 95.0, 97.0, 100.0, 102.0};
   if(Strategy_MAC5TargetFromCloses(falling, valid, driver) != 1 ||
      !valid || driver >= 0.0)
      return false;

   double flat[6] = {100.0, 100.0, 100.0, 100.0, 100.0, 100.0};
   if(Strategy_MAC5TargetFromCloses(flat, valid, driver) != 0 ||
      !valid || driver != 0.0)
      return false;

   double invalid[6] = {100.0, 99.0, 0.0, 97.0, 96.0, 95.0};
   if(Strategy_MAC5TargetFromCloses(invalid, valid, driver) != 0 || valid)
      return false;

   if(Strategy_MAC5PlanDelta(1, 1, true, true, false) !=
      STRATEGY_MAC5_ACTION_RETAIN)
      return false;
   if(Strategy_MAC5PlanDelta(1, -1, true, true, false) !=
      STRATEGY_MAC5_ACTION_FLIP_TO_SHORT)
      return false;
   if(Strategy_MAC5PlanDelta(-1, 1, true, true, true) !=
      STRATEGY_MAC5_ACTION_FLATTEN)
      return false;
   if(Strategy_MAC5PlanDelta(0, 1, true, true, false) !=
      STRATEGY_MAC5_ACTION_ENTER_LONG)
      return false;
   if(Strategy_MAC5PlanDelta(0, -1, true, true, true) !=
      STRATEGY_MAC5_ACTION_SKIP)
      return false;
   if(Strategy_MAC5PlanDelta(1, 1, true, false, false) !=
      STRATEGY_MAC5_ACTION_FLATTEN)
      return false;
   if(Strategy_MAC5PlanDelta(-1, 0, true, true, false) !=
      STRATEGY_MAC5_ACTION_FLATTEN)
      return false;
   if(Strategy_MAC5PlanDelta(0, 1, false, true, false) !=
      STRATEGY_MAC5_ACTION_SKIP)
      return false;

   return true;
  }

#endif // STRATEGY_MAC5_CORE_MQH
