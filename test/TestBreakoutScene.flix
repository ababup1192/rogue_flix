// Tests for BreakoutScene module APIs

// ========================================================================
// shakeOffset
// ========================================================================

@Test
def testShakeOffsetZeroTime(): Unit \ Assert =
    let offset = BreakoutScene.shakeOffset(0.0f32);
    Assert.assertEq(expected = 0.0f32, offset#x);
    Assert.assertEq(expected = 0.0f32, offset#y)

@Test
def testShakeOffsetNegativeTime(): Unit \ Assert =
    let offset = BreakoutScene.shakeOffset(-1.0f32);
    Assert.assertEq(expected = 0.0f32, offset#x);
    Assert.assertEq(expected = 0.0f32, offset#y)

@Test
def testShakeOffsetPositiveTime(): Unit \ Assert =
    let offset = BreakoutScene.shakeOffset(0.1f32);
    let nonZero = not (offset#x == 0.0f32 and offset#y == 0.0f32);
    Assert.assertTrue(nonZero)
