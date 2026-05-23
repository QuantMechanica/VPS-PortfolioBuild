#ifndef QM_SEEDRNG_MQH
#define QM_SEEDRNG_MQH

// V5 Framework — Central seeded RNG.
//
// Created 2026-05-23 per pipeline rewrite (Q07 Multi-Seed + Q06 HARSH
// 10% trade rejection). Purpose: deterministic, reproducible randomness
// across every framework component that needs it. All randomness in V5
// EAs goes through this module — no direct MathRand/MathSrand calls.
//
// Q07 canonical seeds (framework/registry/multiseed_seeds.json):
//   42, 17, 99, 7, 2026
//
// Design notes:
// - MT5's MathRand() returns 0..32767. We compose two draws for a 30-bit
//   integer to get a finer-grained uniform.
// - State lives in module globals; QM_SeedReset(seed) reseeds the chain.
// - Calling code SHOULD pass a sub-stream tag (string) so different
//   consumers (trade-rejection, tie-breaking, jitter) don't fight over
//   the same RNG cursor. The tag is folded into the per-call seed.
// - Tester reproducibility: QM_SeedReset is called from QM_FrameworkInit
//   with the EA's qm_rng_seed input. Re-running the same setfile yields
//   identical sequences across all sub-streams.

#include "QM_Errors.mqh"
#include "QM_Logger.mqh"

uint g_qm_rng_state = 0xDEADBEEF;
bool g_qm_rng_initialized = false;

uint QM_RNG_HashTag(const string tag)
  {
   // Simple FNV-1a hash; small but adequate for sub-stream salting.
   uint h = 2166136261;
   const int n = StringLen(tag);
   for(int i = 0; i < n; ++i)
     {
      h ^= (uint)StringGetCharacter(tag, i);
      h *= 16777619;
     }
   return h;
  }

uint QM_RNG_NextRaw()
  {
   // 32-bit xorshift; cheap, deterministic, adequate for stress simulation.
   uint x = g_qm_rng_state;
   x ^= (x << 13);
   x ^= (x >> 17);
   x ^= (x << 5);
   g_qm_rng_state = x;
   return x;
  }

void QM_SeedReset(const uint seed)
  {
   g_qm_rng_state = (seed == 0) ? 0xDEADBEEF : seed;
   g_qm_rng_initialized = true;
   QM_LogEvent(QM_INFO, "RNG_SEED_SET",
               StringFormat("{\"seed\":%u}", seed));
  }

void QM_SeedAdvanceTag(const string tag)
  {
   // Mix the tag into the state so the next QM_RNG_NextRaw draws from
   // a sub-stream specific to this consumer. Cheap salt rotation.
   g_qm_rng_state ^= QM_RNG_HashTag(tag);
   QM_RNG_NextRaw();
  }

// Public draw API. Each call advances the global state.

double QM_RandUniform()
  {
   // Returns a uniform double in [0.0, 1.0).
   if(!g_qm_rng_initialized)
      QM_SeedReset(0xDEADBEEF);
   const uint r = QM_RNG_NextRaw();
   return (double)r / 4294967296.0;
  }

int QM_RandInt(const int lo, const int hi)
  {
   // Returns a uniform integer in [lo, hi] inclusive.
   if(hi <= lo)
      return lo;
   const double u = QM_RandUniform();
   const int span = hi - lo + 1;
   return lo + (int)(u * span);
  }

bool QM_RandBool(const double probability_true)
  {
   // Returns true with the given probability (0.0..1.0).
   const double p = (probability_true < 0.0) ? 0.0 : ((probability_true > 1.0) ? 1.0 : probability_true);
   return (QM_RandUniform() < p);
  }

// Tagged variants — advance via tag-salt before drawing. Use when a
// consumer wants its own sub-stream independent of other consumers.

double QM_RandUniformTagged(const string tag)
  {
   QM_SeedAdvanceTag(tag);
   return QM_RandUniform();
  }

bool QM_RandBoolTagged(const string tag, const double probability_true)
  {
   QM_SeedAdvanceTag(tag);
   return QM_RandBool(probability_true);
  }

#endif // QM_SEEDRNG_MQH
