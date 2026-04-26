// Rand — Elm-style random number generation via algebraic effects
//
// Usage:
//   RandHandler.withSeed(42i64, () -> {
//       let x = Rand.nextInt(10);   // 0..9
//       let y = Rand.nextInt(4);    // 0..3
//       (x, y)
//   })

pub eff Rand {
    def nextInt(bound: Int32): Int32
}

mod RandHandler {
    def lcg(seed: Int64): Int64 =
        seed * 6364136223846793005i64 + 1442695040888963407i64

    /// Convert a small non-negative Int64 (< Int32.maxValue) to Int32.
    def smallInt64ToInt32(v: Int64): Int32 =
        smallInt64Loop(0, v)

    def smallInt64Loop(i: Int32, target: Int64): Int32 =
        if (Int32.toInt64(i) >= target) i
        else smallInt64Loop(i + 1, target)

    pub def withSeed(seed: Int64, f: Unit -> a \ Rand): a = region rc {
        let s = Array.repeat(rc, 1, seed);
        run { f() } with handler Rand {
            def nextInt(bound, k) =
                let current = Array.get(0, s);
                let next = lcg(current);
                Array.put(next, 0, s);
                let b = Int32.toInt64(bound);
                let r = Int64.remainder(next, b);
                let v = if (r < 0i64) r + b else r;
                k(smallInt64ToInt32(v))
        }
    }
}
