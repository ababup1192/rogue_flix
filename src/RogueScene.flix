// RogueScene — scene construction and player APIs for the rogue game

mod RogueScene {
    pub def rootName(): String = "Root"
    pub def playerName(): String = "Player"

    // ========================================================================
    // Sprite Sheet Layout (npc.png: 240x128 = 15 columns x 8 rows, 16x16 each)
    // ========================================================================
    //
    // Each character: 3 columns (animation frames) x 4 rows (directions).
    // Characters tiled: 4 across x 2 down.
    // Using the first character (cols 0-2, rows 0-3):
    //   Row 0: facing down  (front view)
    //   Row 1: facing left
    //   Row 2: facing right
    //   Row 3: facing up    (back view)
    //
    // Idle frame = col 0 of each direction row.

    /// Returns (uvOffset, uvScale) for the idle frame of the given direction.
    ///
    /// STBImage flips the image vertically on load, so in UV space:
    ///   UV y=1.0 → top of original image (row 0)
    ///   UV y=0.0 → bottom of original image (row 7)
    ///
    /// We use negative uvScale.y so that screen-top → character-head (right-side up).
    pub def uvForDirection(dir: SceneTree.Direction): (Vec2D.Vec2, Vec2D.Vec2) =
        let frameW = 1.0f32 / 15.0f32;
        let frameH = 1.0f32 / 8.0f32;
        let uvScaleY = -1.0f32 * frameH;
        match dir {
            case SceneTree.Direction.Down  =>
                // Row 0: top edge = 8/8 = 1.0
                ({x = 0.0f32, y = 1.0f32},            {x = frameW, y = uvScaleY})
            case SceneTree.Direction.Left  =>
                // Row 1: top edge = 7/8
                ({x = 0.0f32, y = 7.0f32 * frameH},   {x = frameW, y = uvScaleY})
            case SceneTree.Direction.Right =>
                // Row 2: top edge = 6/8
                ({x = 0.0f32, y = 6.0f32 * frameH},   {x = frameW, y = uvScaleY})
            case SceneTree.Direction.Up    =>
                // Row 3: top edge = 5/8
                ({x = 0.0f32, y = 5.0f32 * frameH},   {x = frameW, y = uvScaleY})
        }

    // ========================================================================
    // Atlas UV Helpers
    // ========================================================================

    /// UV for floor tile (0,0) from atlas_floor-16x16.png (7 cols x 7 rows).
    pub def floorUV(): (Vec2D.Vec2, Vec2D.Vec2) =
        ({x = 0.0f32, y = 1.0f32}, {x = 1.0f32 / 7.0f32, y = -1.0f32 / 7.0f32})

    /// UV for wall tile from atlas_walls_low-16x16.png (12 cols x 4 rows).
    /// Atlas column encodes horizontal connectivity:
    ///   Col 0: isolated (thin center strip)
    ///   Col 1: extends right (wall/floor neighbor to the right)
    ///   Col 2: extends both (wall/floor neighbors on both sides)
    ///   Col 3: extends left  (wall/floor neighbor to the left)
    /// Atlas row encodes vertical connectivity (mortar cap placement):
    ///   Row 0: cap top, open bottom  (top of wall — no wall above)
    ///   Row 1: open top, open bottom (middle — walls above and below)
    ///   Row 2: open top, cap bottom  (bottom of wall — no wall below)
    ///   Row 3: cap top, cap bottom   (isolated — no walls above or below)
    def wallAtlasRow(col: Int32, row: Int32): Int32 =
        let wallAbove = isWallTile(col, row - 1);
        let wallBelow = isWallTile(col, row + 1);
        match (wallAbove, wallBelow) {
            case (false, false) => 3
            case (false, true)  => 0
            case (true,  true)  => 1
            case (true,  false) => 2
        }

    def wallAtlasUV(atlasCol: Int32, atlasRow: Int32): (Vec2D.Vec2, Vec2D.Vec2) =
        let colF = Int32.toFloat32(atlasCol);
        let rowF = Int32.toFloat32(atlasRow);
        ({x = colF / 12.0f32, y = 1.0f32 - rowF / 4.0f32}, {x = 1.0f32 / 12.0f32, y = -1.0f32 / 4.0f32})

    /// UV for the wall face layer (brick pattern with horizontal connectivity).
    pub def wallFaceUV(col: Int32, row: Int32): (Vec2D.Vec2, Vec2D.Vec2) =
        let extendLeft  = isWallTile(col - 1, row) or isFloor(col - 1, row);
        let extendRight = isWallTile(col + 1, row) or isFloor(col + 1, row);
        let atlasCol = match (extendLeft, extendRight) {
            case (false, false) => 0
            case (false, true)  => 1
            case (true,  true)  => 2
            case (true,  false) => 3
        };
        wallAtlasUV(atlasCol, wallAtlasRow(col, row))

    /// UV for the wall strip overlay (Col 0, fixed Row 1 — consistent mortar pattern).
    /// Always uses Row 1 ("open both") so that the strip edge pattern is
    /// uniform across all vertically adjacent wall tiles, eliminating the
    /// visual bumpiness caused by per-row mortar variation.
    pub def wallStripUV(_col: Int32, _row: Int32): (Vec2D.Vec2, Vec2D.Vec2) =
        wallAtlasUV(0, 1)

    // ========================================================================
    // Dungeon Layout — 3 rooms connected by corridors
    // ========================================================================
    //
    // Room 1 (top-left):      floor x=[2,6],  y=[2,6]
    // Room 2 (top-right):     floor x=[13,17], y=[2,6]
    // Room 3 (bottom-center): floor x=[7,11],  y=[11,15]
    // Corridor 1 (horizontal): y=4, x=[7,12]  (Room1 <-> Room2)
    // Corridor 2 (vertical):   x=9, y=[5,10]  (Corridor1 <-> Room3)

    def inRoom(col: Int32, row: Int32, x1: Int32, y1: Int32, x2: Int32, y2: Int32): Bool =
        col >= x1 and col <= x2 and row >= y1 and row <= y2

    pub def isFloor(col: Int32, row: Int32): Bool =
        inRoom(col, row, 2, 2, 6, 6) or
        inRoom(col, row, 13, 2, 17, 6) or
        inRoom(col, row, 7, 11, 11, 15) or
        (col >= 7 and col <= 12 and row == 4) or
        (col == 9 and row >= 5 and row <= 10)

    def hasAdjacentFloor(col: Int32, row: Int32): Bool =
        isFloor(col - 1, row - 1) or isFloor(col, row - 1) or isFloor(col + 1, row - 1) or
        isFloor(col - 1, row)     or                           isFloor(col + 1, row) or
        isFloor(col - 1, row + 1) or isFloor(col, row + 1) or isFloor(col + 1, row + 1)

    pub def isWallTile(col: Int32, row: Int32): Bool =
        not isFloor(col, row) and hasAdjacentFloor(col, row)

    /// Build StaticBody2D tiles for rooms and corridors, split into (floors, walls).
    pub def buildDungeonTiles(cols: Int32, rows: Int32, tileSz: Float32): (List[SceneTree.Node], List[SceneTree.Node]) =
        let (floorOff, floorSc) = floorUV();
        let tileShape = SceneTree.CollisionShapeData.RectShape({x = tileSz, y = tileSz});
        let floors = List.flatMap(row ->
            List.filterMap(col ->
                if (isFloor(col, row)) {
                    let px = Int32.toFloat32(col) * tileSz;
                    let py = Int32.toFloat32(row) * tileSz;
                    let sprite = SceneTree.sprite2D("TileSprite_${col}_${row}", Vec2D.zero(), {
                        size = {x = tileSz, y = tileSz},
                        color = {r = 1.0f32, g = 1.0f32, b = 1.0f32},
                        texture = "floor",
                        visible = true,
                        uvOffset = floorOff,
                        uvScale = floorSc
                    });
                    let shape = SceneTree.collisionShape2D("TileShape_${col}_${row}", tileShape);
                    Some(SceneTree.staticBody2D("Tile_${col}_${row}", {x = px, y = py},
                        {isSolid = false, destroyed = false}, sprite :: shape :: Nil))
                } else None
            , List.range(0, cols))
        , List.range(0, rows));
        let walls = List.flatMap(row ->
            List.filterMap(col ->
                if (isWallTile(col, row)) {
                    let px = Int32.toFloat32(col) * tileSz;
                    let py = Int32.toFloat32(row) * tileSz;
                    let (fOff, fSc) = wallFaceUV(col, row);
                    let face = SceneTree.sprite2D("TileFace_${col}_${row}", Vec2D.zero(), {
                        size = {x = tileSz, y = tileSz},
                        color = {r = 1.0f32, g = 1.0f32, b = 1.0f32},
                        texture = "wall",
                        visible = true,
                        uvOffset = fOff,
                        uvScale = fSc
                    });
                    let (sOff, sSc) = wallStripUV(col, row);
                    let strip = SceneTree.sprite2D("TileStrip_${col}_${row}", Vec2D.zero(), {
                        size = {x = tileSz, y = tileSz},
                        color = {r = 1.0f32, g = 1.0f32, b = 1.0f32},
                        texture = "wall",
                        visible = true,
                        uvOffset = sOff,
                        uvScale = sSc
                    });
                    let shape = SceneTree.collisionShape2D("TileShape_${col}_${row}", tileShape);
                    Some(SceneTree.staticBody2D("Tile_${col}_${row}", {x = px, y = py},
                        {isSolid = true, destroyed = false}, face :: strip :: shape :: Nil))
                } else None
            , List.range(0, cols))
        , List.range(0, rows));
        (floors, walls)

    // ========================================================================
    // Scene Building
    // ========================================================================

    pub def buildInitialScene(
        cols: Int32, rows: Int32,
        playerGridX: Int32, playerGridY: Int32,
        tileSz: Float32
    ): SceneTree.Node =
        let px = Int32.toFloat32(playerGridX) * tileSz;
        let py = Int32.toFloat32(playerGridY) * tileSz;
        let (uvOff, uvSc) = uvForDirection(SceneTree.Direction.Down);
        let (floorTiles, wallTiles) = buildDungeonTiles(cols, rows, tileSz);
        let floors = SceneTree.node2D("Floors", Vec2D.zero(), floorTiles);
        let walls = SceneTree.node2D("Walls", Vec2D.zero(), wallTiles);
        let half = tileSz / 2.0f32;
        let playerSprite = SceneTree.sprite2D("PlayerSprite",
            Vec2D.zero(),
            {
                size = {x = tileSz, y = tileSz},
                color = {r = 1.0f32, g = 1.0f32, b = 1.0f32},
                texture = "npc",
                visible = true,
                uvOffset = uvOff,
                uvScale = uvSc
            }
        );
        let playerRaycast = SceneTree.raycast2DNode("PlayerRaycast",
            {x = half, y = half},
            {direction = {x = 0.0f32, y = 1.0f32}, maxDistance = tileSz, enabled = true}
        );
        let player = SceneTree.node2D(playerName(),
            {x = px, y = py},
            playerSprite :: playerRaycast :: Nil
        );
        SceneTree.node2D(rootName(), Vec2D.zero(),
            floors :: walls :: player :: Nil
        )

    // ========================================================================
    // Player APIs
    // ========================================================================

    pub def setPlayerPosition(pos: Vec2D.Vec2, scene: SceneTree.Node): SceneTree.Node =
        SceneTree.setNodePosition(playerName(), pos, scene)

    pub def setPlayerFacing(dir: SceneTree.Direction, scene: SceneTree.Node): SceneTree.Node =
        let (uvOff, uvSc) = uvForDirection(dir);
        SceneTree.updateChildSprite(playerName(), sd ->
            {uvOffset = uvOff, uvScale = uvSc | sd},
            scene)
}
