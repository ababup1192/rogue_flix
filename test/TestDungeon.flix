// Tests for Dungeon — room-and-corridor dungeon generation

// ========================================================================
// Rand effect tests
// ========================================================================

@Test
def testRandNextIntBounded(): Unit \ Assert =
    let result = RandHandler.withSeed(42i64, () -> Rand.nextInt(4));
    Assert.assertTrue(result >= 0 and result < 4)

@Test
def testRandDeterministic(): Unit \ Assert =
    let a = RandHandler.withSeed(123i64, () -> (Rand.nextInt(100), Rand.nextInt(100)));
    let b = RandHandler.withSeed(123i64, () -> (Rand.nextInt(100), Rand.nextInt(100)));
    Assert.assertEq(expected = a, b)

@Test
def testRandDifferentSeeds(): Unit \ Assert =
    let a = RandHandler.withSeed(1i64, () -> Rand.nextInt(1000));
    let b = RandHandler.withSeed(2i64, () -> Rand.nextInt(1000));
    Assert.assertTrue(a != b)

// ========================================================================
// Dungeon generation tests
// ========================================================================

// Player start is inside the dungeon
@Test
def testDungeonPlayerStartIsFloor(): Unit \ Assert =
    let seed = 42i64;
    let floors = Dungeon.generate(50, 38, seed);
    let start = Dungeon.playerStartForRooms(50, 38, seed);
    Assert.assertTrue(Set.memberOf((start#col, start#row), floors))

// Boundary cells are never floors
@Test
def testDungeonBoundaryIsWall(): Unit \ Assert =
    let floors = Dungeon.generate(50, 38, 42i64);
    let topRowFloors = List.range(0, 50)
        |> List.exists(col -> Set.memberOf((col, 0), floors));
    Assert.assertFalse(topRowFloors);
    let leftColFloors = List.range(0, 38)
        |> List.exists(row -> Set.memberOf((0, row), floors));
    Assert.assertFalse(leftColFloors)

// Generated dungeon has a reasonable number of floor tiles
@Test
def testDungeonHasFloors(): Unit \ Assert =
    let floors = Dungeon.generate(50, 38, 42i64);
    let count = Set.size(floors);
    Assert.assertTrue(count > 30)

// Different seeds produce different dungeons
@Test
def testDungeonDifferentSeeds(): Unit \ Assert =
    let a = Dungeon.generate(50, 38, 1i64);
    let b = Dungeon.generate(50, 38, 2i64);
    Assert.assertTrue(a != b)

// Same seed produces same dungeon
@Test
def testDungeonDeterministic(): Unit \ Assert =
    let a = Dungeon.generate(50, 38, 42i64);
    let b = Dungeon.generate(50, 38, 42i64);
    Assert.assertEq(expected = a, b)

// All floor tiles are connected (every floor reachable from player start)
@Test
def testDungeonAllFloorsConnected(): Unit \ Assert =
    let seed = 42i64;
    let floors = Dungeon.generate(50, 38, seed);
    let start = Dungeon.playerStartForRooms(50, 38, seed);
    let startPos = (start#col, start#row);
    let visited = bfs(Set.insert(startPos, Set.empty()), startPos :: Nil, floors);
    Assert.assertEq(expected = Set.size(floors), Set.size(visited))

def bfs(visited: Set[(Int32, Int32)], queue: List[(Int32, Int32)],
         floors: Set[(Int32, Int32)]): Set[(Int32, Int32)] =
    match queue {
        case Nil => visited
        case (col, row) :: rest =>
            let neighbors = (col - 1, row) :: (col + 1, row) :: (col, row - 1) :: (col, row + 1) :: Nil;
            let unvisited = List.filter(pos ->
                Set.memberOf(pos, floors) and not Set.memberOf(pos, visited),
                neighbors);
            let newVisited = List.foldLeft((acc, pos) -> Set.insert(pos, acc), visited, unvisited);
            bfs(newVisited, List.append(rest, unvisited), floors)
    }
