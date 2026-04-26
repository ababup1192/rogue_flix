// WallScene — dungeon wall layout, UV helpers, and tile building
//
// Single-layer rendering using the high atlas (16x32 tiles).
// Each wall sprite is placed one tile above its cell position so the top half
// extends upward (cap / depth effect).  Rows r1 and r2 in the atlas have
// their top half cleared to transparent, so overlapping tiles compose cleanly.

mod WallScene {
    // ========================================================================
    // Wall Layout
    // ========================================================================

    def hasAdjacentFloor(floors: Set[(Int32, Int32)], col: Int32, row: Int32): Bool =
        FloorScene.isFloor(floors, col - 1, row - 1) or FloorScene.isFloor(floors, col, row - 1) or FloorScene.isFloor(floors, col + 1, row - 1) or
        FloorScene.isFloor(floors, col - 1, row)     or                                              FloorScene.isFloor(floors, col + 1, row) or
        FloorScene.isFloor(floors, col - 1, row + 1) or FloorScene.isFloor(floors, col, row + 1) or FloorScene.isFloor(floors, col + 1, row + 1)

    pub def isWallTile(floors: Set[(Int32, Int32)], col: Int32, row: Int32): Bool =
        not FloorScene.isFloor(floors, col, row) and hasAdjacentFloor(floors, col, row)

    // ========================================================================
    // Atlas UV Helpers
    // ========================================================================
    //
    // Atlas column encodes horizontal connectivity:
    //   Col 0: isolated (thin center strip)
    //   Col 1: extends right (wall/floor neighbor to the right)
    //   Col 2: extends both (wall/floor neighbors on both sides)
    //   Col 3: extends left  (wall/floor neighbor to the left)
    // Atlas row encodes vertical connectivity (mortar cap placement):
    //   Row 0: cap top, open bottom  (top of wall — no wall above)
    //   Row 1: open top, open bottom (middle — walls above and below)
    //   Row 2: open top, cap bottom  (bottom of wall — no wall below)
    //   Row 3: cap top, cap bottom   (isolated — no walls above or below)

    def wallHorizontalCol(floors: Set[(Int32, Int32)], col: Int32, row: Int32): Int32 =
        let extendLeft  = isWallTile(floors, col - 1, row) or FloorScene.isFloor(floors, col - 1, row);
        let extendRight = isWallTile(floors, col + 1, row) or FloorScene.isFloor(floors, col + 1, row);
        match (extendLeft, extendRight) {
            case (false, false) => 0
            case (false, true)  => 1
            case (true,  true)  => 2
            case (true,  false) => 3
        }

    def wallAtlasRow(floors: Set[(Int32, Int32)], col: Int32, row: Int32): Int32 =
        let wallAbove = isWallTile(floors, col, row - 1);
        let wallBelow = isWallTile(floors, col, row + 1);
        match (wallAbove, wallBelow) {
            case (false, true)  => 0
            case (true,  true)  => 1
            case (true,  false) => 2
            case (false, false) => 3
        }

    /// High atlas: atlas_walls_high-16x32.png (24 cols x 4 rows)
    def wallHighAtlasUV(atlasCol: Int32, atlasRow: Int32): (Vec2D.Vec2, Vec2D.Vec2) =
        let colF = Int32.toFloat32(atlasCol);
        let rowF = Int32.toFloat32(atlasRow);
        ({x = colF / 24.0f32, y = 1.0f32 - rowF / 4.0f32}, {x = 1.0f32 / 24.0f32, y = -1.0f32 / 4.0f32})

    /// UV for wall tile (high atlas, h+v connectivity).
    pub def wallUV(floors: Set[(Int32, Int32)], col: Int32, row: Int32): (Vec2D.Vec2, Vec2D.Vec2) =
        wallHighAtlasUV(wallHorizontalCol(floors, col, row), wallAtlasRow(floors, col, row))

    // ========================================================================
    // Tile Building
    // ========================================================================

    def mkWallTile(floors: Set[(Int32, Int32)], col: Int32, row: Int32, tileSz: Float32,
                    tileShape: SceneTree.CollisionShapeData): SceneTree.Node =
        let pos = Grid.toWorld({row = row, col = col}, tileSz);
        let (hOff, hSc) = wallUV(floors, col, row);
        let sprite = Sprite2D.init({
                name = "TileSprite_${col}_${row}",
                pos = {x = 0.0f32, y = -tileSz},
                size = {x = tileSz, y = tileSz * 2.0f32},
                texture = "wall_high"
            })
            |> Sprite2D.uv(hOff, hSc);
        let shape = SceneTree.collisionShape2D("TileShape_${col}_${row}", tileShape);
        StaticBody2D.init({
                name = "Tile_${col}_${row}", pos = pos,
                children = sprite :: shape :: Nil
            })

    /// Wall tiles (high atlas, 16x32) — collision + wall sprite.
    pub def buildWallTiles(floors: Set[(Int32, Int32)], cols: Int32, rows: Int32, tileSz: Float32): List[SceneTree.Node] =
        let tileShape = SceneTree.CollisionShapeData.RectShape({x = tileSz, y = tileSz});
        List.range(0, rows)
            |> List.flatMap(row -> List.range(0, cols) |> List.map(col -> (col, row)))
            |> List.filterMap(match (col, row) ->
                if (isWallTile(floors, col, row)) Some(mkWallTile(floors, col, row, tileSz, tileShape))
                else None)
}
