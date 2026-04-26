// Tests for Grid module — world <-> grid coordinate conversion

@Test
def testGridToWorld(): Unit \ Assert =
    let pos = Grid.toWorld({row = 4, col = 4}, 32.0f32);
    Assert.assertEq(expected = (128.0f32, 128.0f32), (pos#x, pos#y))

@Test
def testGridFromWorld(): Unit \ Assert =
    let gp = Grid.fromWorld({x = 128.0f32, y = 128.0f32}, 32.0f32);
    Assert.assertEq(expected = (4, 4), (gp#row, gp#col))

@Test
def testGridRoundTrip(): Unit \ Assert =
    let original: Grid.GridPos = {row = 3, col = 7};
    let tileSz = 32.0f32;
    let result = Grid.fromWorld(Grid.toWorld(original, tileSz), tileSz);
    Assert.assertEq(expected = (original#row, original#col), (result#row, result#col))
