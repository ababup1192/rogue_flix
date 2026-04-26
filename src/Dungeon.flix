// Dungeon — room-and-corridor dungeon generation
//
// Algorithm:
//   1. Place random rectangular rooms (non-overlapping)
//   2. Connect each room to the next with L-shaped corridors
//   3. Player starts in the first room

mod Dungeon {

    def minRooms(): Int32 = 5
    def maxRooms(): Int32 = 7
    def roomMargin(): Int32 = 3
    def placementAttempts(): Int32 = 150

    /// Generate a dungeon with rooms and corridors.
    /// Returns a Set of (col, row) pairs representing floor tiles.
    pub def generate(cols: Int32, rows: Int32, seed: Int64): Set[(Int32, Int32)] =
        generateWithRetry(cols, rows, seed, 0)

    def generateWithRetry(cols: Int32, rows: Int32, seed: Int64, retry: Int32): Set[(Int32, Int32)] =
        let rooms = RandHandler.withSeed(seed, () ->
            placeRooms(cols, rows, maxRooms(), placementAttempts(), Nil));
        if (List.length(rooms) < minRooms() and retry < 20)
            generateWithRetry(cols, rows, seed + 97i64, retry + 1)
        else
            RandHandler.withSeed(seed, () -> {
                let rooms2 = placeRooms(cols, rows, maxRooms(), placementAttempts(), Nil);
                let floors = List.foldLeft((acc, room) -> carveRoom(acc, room), Set.empty(), rooms2);
                connectRooms(floors, rooms2)
            })

    /// Player starts at the center of the first room.
    pub def playerStartForRooms(cols: Int32, rows: Int32, seed: Int64): {col = Int32, row = Int32} =
        let actualSeed = findViableSeed(cols, rows, seed, 0);
        RandHandler.withSeed(actualSeed, () -> {
            let rooms = placeRooms(cols, rows, maxRooms(), placementAttempts(), Nil);
            match rooms {
                case Nil => {col = 1, row = 1}
                case r :: _ => roomCenter(r)
            }
        })

    def findViableSeed(cols: Int32, rows: Int32, seed: Int64, retry: Int32): Int64 =
        let rooms = RandHandler.withSeed(seed, () ->
            placeRooms(cols, rows, maxRooms(), placementAttempts(), Nil));
        if (List.length(rooms) < minRooms() and retry < 20)
            findViableSeed(cols, rows, seed + 97i64, retry + 1)
        else
            seed

    // ========================================================================
    // Room type: (x, y, w, h) — top-left corner and dimensions
    // ========================================================================

    type alias Room = {x = Int32, y = Int32, w = Int32, h = Int32}

    def roomCenter(r: Room): {col = Int32, row = Int32} =
        {col = r#x + r#w / 2, row = r#y + r#h / 2}

    // ========================================================================
    // Room placement
    // ========================================================================

    def placeRooms(cols: Int32, rows: Int32, maxRooms: Int32, attempts: Int32,
                   placed: List[Room]): List[Room] \ Rand =
        if (attempts <= 0 or List.length(placed) >= maxRooms) placed
        else {
            let w = Rand.nextInt(10) + 6;   // width  6..15
            let h = Rand.nextInt(10) + 6;   // height 6..15
            let x = Rand.nextInt(cols - w - 2) + 1;
            let y = Rand.nextInt(rows - h - 2) + 1;
            let room = {x = x, y = y, w = w, h = h};
            if (overlapsAny(room, placed))
                placeRooms(cols, rows, maxRooms, attempts - 1, placed)
            else
                placeRooms(cols, rows, maxRooms, attempts - 1, List.append(placed, room :: Nil))
        }

    def overlapsAny(room: Room, rooms: List[Room]): Bool =
        List.exists(other -> overlaps(room, other), rooms)

    def overlaps(a: Room, b: Room): Bool =
        let m = roomMargin();
        a#x - m < b#x + b#w and a#x + a#w + m > b#x and
        a#y - m < b#y + b#h and a#y + a#h + m > b#y

    // ========================================================================
    // Carving
    // ========================================================================

    def carveRoom(floors: Set[(Int32, Int32)], room: Room): Set[(Int32, Int32)] =
        List.range(room#y, room#y + room#h)
            |> List.foldLeft((acc, row) ->
                List.range(room#x, room#x + room#w)
                    |> List.foldLeft((acc2, col) -> Set.insert((col, row), acc2), acc),
                floors)

    def carveCorridor(floors: Set[(Int32, Int32)],
                      src: {col = Int32, row = Int32},
                      dst: {col = Int32, row = Int32}): Set[(Int32, Int32)] \ Rand =
        // L-shaped corridor: go horizontal first or vertical first
        let horizontalFirst = Rand.nextInt(2) == 0;
        if (horizontalFirst)
            // horizontal at src#row, then vertical at dst#col
            carveVLine(carveHLine(floors, src#row, src#col, dst#col), dst#col, src#row, dst#row)
        else
            // vertical at src#col, then horizontal at dst#row
            carveHLine(carveVLine(floors, src#col, src#row, dst#row), dst#row, src#col, dst#col)

    def carveHLine(floors: Set[(Int32, Int32)], row: Int32, x1: Int32, x2: Int32): Set[(Int32, Int32)] =
        let minX = Int32.min(x1, x2);
        let maxX = Int32.max(x1, x2);
        List.range(minX, maxX + 1)
            |> List.foldLeft((acc, col) -> Set.insert((col, row), acc), floors)

    def carveVLine(floors: Set[(Int32, Int32)], col: Int32, y1: Int32, y2: Int32): Set[(Int32, Int32)] =
        let minY = Int32.min(y1, y2);
        let maxY = Int32.max(y1, y2);
        List.range(minY, maxY + 1)
            |> List.foldLeft((acc, row) -> Set.insert((col, row), acc), floors)

    // ========================================================================
    // Room connection
    // ========================================================================

    def connectRooms(floors: Set[(Int32, Int32)], rooms: List[Room]): Set[(Int32, Int32)] \ Rand =
        match rooms {
            case Nil => floors
            case _ :: Nil => floors
            case a :: b :: rest =>
                let src = roomCenter(a);
                let dst = roomCenter(b);
                let newFloors = carveCorridor(floors, src, dst);
                connectRooms(newFloors, b :: rest)
        }
}
