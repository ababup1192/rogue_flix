// Tests for Vec2D module

// --- Arithmetic ---

@Test
def testVec2DAdd(): Unit \ Assert =
    let r = Vec2D.add({x = 1.0f32, y = 2.0f32}, {x = 3.0f32, y = 4.0f32});
    Assert.assertEq(expected = 4.0f32, r#x);
    Assert.assertEq(expected = 6.0f32, r#y)

@Test
def testVec2DSub(): Unit \ Assert =
    let r = Vec2D.sub({x = 5.0f32, y = 7.0f32}, {x = 2.0f32, y = 3.0f32});
    Assert.assertEq(expected = 3.0f32, r#x);
    Assert.assertEq(expected = 4.0f32, r#y)

@Test
def testVec2DMul(): Unit \ Assert =
    let r = Vec2D.mul({x = 3.0f32, y = 4.0f32}, 2.0f32);
    Assert.assertEq(expected = 6.0f32, r#x);
    Assert.assertEq(expected = 8.0f32, r#y)

@Test
def testVec2DDiv(): Unit \ Assert =
    let r = Vec2D.div({x = 6.0f32, y = 8.0f32}, 2.0f32);
    Assert.assertEq(expected = 3.0f32, r#x);
    Assert.assertEq(expected = 4.0f32, r#y)

@Test
def testVec2DNeg(): Unit \ Assert =
    let r = Vec2D.neg({x = 3.0f32, y = -4.0f32});
    Assert.assertEq(expected = -3.0f32, r#x);
    Assert.assertEq(expected = 4.0f32, r#y)

// --- Length ---

@Test
def testVec2DLengthSquared(): Unit \ Assert =
    Assert.assertEq(expected = 25.0f32, Vec2D.lengthSquared({x = 3.0f32, y = 4.0f32}))

@Test
def testVec2DLength345(): Unit \ Assert =
    let len = Vec2D.length({x = 3.0f32, y = 4.0f32});
    Assert.assertEq(expected = 5.0f32, len)

@Test
def testVec2DLengthZero(): Unit \ Assert =
    Assert.assertEq(expected = 0.0f32, Vec2D.length(Vec2D.zero()))

// --- Normalized ---

@Test
def testVec2DNormalized(): Unit \ Assert =
    let r = Vec2D.normalized({x = 3.0f32, y = 4.0f32});
    let len = Vec2D.length(r);
    Assert.assertTrue(Float32.abs(len - 1.0f32) < 0.001f32)

@Test
def testVec2DNormalizedDirection(): Unit \ Assert =
    let r = Vec2D.normalized({x = 0.0f32, y = 5.0f32});
    Assert.assertTrue(Float32.abs(r#x) < 0.001f32);
    Assert.assertTrue(Float32.abs(r#y - 1.0f32) < 0.001f32)

@Test
def testVec2DNormalizedZero(): Unit \ Assert =
    let r = Vec2D.normalized(Vec2D.zero());
    Assert.assertEq(expected = 0.0f32, r#x);
    Assert.assertEq(expected = 0.0f32, r#y)

// --- Dot ---

@Test
def testVec2DDotPerpendicular(): Unit \ Assert =
    Assert.assertEq(expected = 0.0f32, Vec2D.dot({x = 1.0f32, y = 0.0f32}, {x = 0.0f32, y = 1.0f32}))

@Test
def testVec2DDotParallel(): Unit \ Assert =
    Assert.assertEq(expected = 6.0f32, Vec2D.dot({x = 2.0f32, y = 0.0f32}, {x = 3.0f32, y = 0.0f32}))

@Test
def testVec2DDotGeneral(): Unit \ Assert =
    Assert.assertEq(expected = 11.0f32, Vec2D.dot({x = 1.0f32, y = 2.0f32}, {x = 3.0f32, y = 4.0f32}))

// --- Reflect & Bounce ---

// Reflect downward vector off horizontal surface (normal = up)
@Test
def testVec2DReflect(): Unit \ Assert =
    let v = {x = 1.0f32, y = 1.0f32};
    let n = {x = 0.0f32, y = -1.0f32};
    let r = Vec2D.reflect(v, n);
    Assert.assertTrue(Float32.abs(r#x - 1.0f32) < 0.001f32);
    Assert.assertTrue(Float32.abs(r#y - (-1.0f32)) < 0.001f32)

@Test
def testVec2DBounce(): Unit \ Assert =
    let v = {x = 1.0f32, y = 1.0f32};
    let n = {x = 0.0f32, y = -1.0f32};
    let r = Vec2D.bounce(v, n);
    Assert.assertTrue(Float32.abs(r#x - (-1.0f32)) < 0.001f32);
    Assert.assertTrue(Float32.abs(r#y - 1.0f32) < 0.001f32)

// --- Clamp ---

@Test
def testVec2DClamp(): Unit \ Assert =
    let v = {x = 5.0f32, y = -3.0f32};
    let r = Vec2D.clamp(v, {x = -2.0f32, y = -2.0f32}, {x = 2.0f32, y = 2.0f32});
    Assert.assertEq(expected = 2.0f32, r#x);
    Assert.assertEq(expected = -2.0f32, r#y)

@Test
def testVec2DClampSymmetric(): Unit \ Assert =
    let v = {x = 10.0f32, y = -5.0f32};
    let r = Vec2D.clampSymmetric(v, {x = 3.0f32, y = 3.0f32});
    Assert.assertEq(expected = 3.0f32, r#x);
    Assert.assertEq(expected = -3.0f32, r#y)

// --- Lerp ---

@Test
def testVec2DLerpZero(): Unit \ Assert =
    let a = {x = 0.0f32, y = 0.0f32};
    let b = {x = 10.0f32, y = 20.0f32};
    let r = Vec2D.lerp(a, b, 0.0f32);
    Assert.assertEq(expected = 0.0f32, r#x);
    Assert.assertEq(expected = 0.0f32, r#y)

@Test
def testVec2DLerpOne(): Unit \ Assert =
    let a = {x = 0.0f32, y = 0.0f32};
    let b = {x = 10.0f32, y = 20.0f32};
    let r = Vec2D.lerp(a, b, 1.0f32);
    Assert.assertEq(expected = 10.0f32, r#x);
    Assert.assertEq(expected = 20.0f32, r#y)

@Test
def testVec2DLerpHalf(): Unit \ Assert =
    let a = {x = 0.0f32, y = 0.0f32};
    let b = {x = 10.0f32, y = 20.0f32};
    let r = Vec2D.lerp(a, b, 0.5f32);
    Assert.assertEq(expected = 5.0f32, r#x);
    Assert.assertEq(expected = 10.0f32, r#y)

// --- Rotated ---

// Rotate (1, 0) by 90 degrees → (0, 1) approximately
@Test
def testVec2DRotated90(): Unit \ Assert =
    let pi = 3.14159265f32;
    let r = Vec2D.rotated({x = 1.0f32, y = 0.0f32}, pi / 2.0f32);
    Assert.assertTrue(Float32.abs(r#x) < 0.001f32);
    Assert.assertTrue(Float32.abs(r#y - 1.0f32) < 0.001f32)

// Rotate (1, 0) by 180 degrees → (-1, 0) approximately
@Test
def testVec2DRotated180(): Unit \ Assert =
    let pi = 3.14159265f32;
    let r = Vec2D.rotated({x = 1.0f32, y = 0.0f32}, pi);
    Assert.assertTrue(Float32.abs(r#x - (-1.0f32)) < 0.001f32);
    Assert.assertTrue(Float32.abs(r#y) < 0.001f32)

// --- Utility ---

@Test
def testVec2DIsNormalized(): Unit \ Assert =
    Assert.assertTrue(Vec2D.isNormalized({x = 1.0f32, y = 0.0f32}));
    Assert.assertFalse(Vec2D.isNormalized({x = 2.0f32, y = 0.0f32}))

@Test
def testVec2DIsZeroApprox(): Unit \ Assert =
    Assert.assertTrue(Vec2D.isZeroApprox(Vec2D.zero()));
    Assert.assertFalse(Vec2D.isZeroApprox({x = 1.0f32, y = 0.0f32}))

@Test
def testVec2DLimitLength(): Unit \ Assert =
    let v = {x = 6.0f32, y = 8.0f32};
    let r = Vec2D.limitLength(v, 5.0f32);
    let len = Vec2D.length(r);
    Assert.assertTrue(Float32.abs(len - 5.0f32) < 0.01f32)

@Test
def testVec2DLimitLengthNoOp(): Unit \ Assert =
    let v = {x = 1.0f32, y = 0.0f32};
    let r = Vec2D.limitLength(v, 5.0f32);
    Assert.assertEq(expected = 1.0f32, r#x);
    Assert.assertEq(expected = 0.0f32, r#y)

// --- Math helpers ---

@Test
def testVec2DSqrt32(): Unit \ Assert =
    Assert.assertEq(expected = 5.0f32, Vec2D.sqrt32(25.0f32))

@Test
def testVec2DSqrt32Zero(): Unit \ Assert =
    Assert.assertEq(expected = 0.0f32, Vec2D.sqrt32(0.0f32))
