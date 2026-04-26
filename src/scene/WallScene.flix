// WallScene — dungeon wall layout, UV helpers, and tile building

mod WallScene {
    // ========================================================================
    // Wall Layout
    // ========================================================================

    def hasAdjacentFloor(col: Int32, row: Int32): Bool =
        FloorScene.isFloor(col - 1, row - 1) or FloorScene.isFloor(col, row - 1) or FloorScene.isFloor(col + 1, row - 1) or
        FloorScene.isFloor(col - 1, row)     or                                      FloorScene.isFloor(col + 1, row) or
        FloorScene.isFloor(col - 1, row + 1) or FloorScene.isFloor(col, row + 1) or FloorScene.isFloor(col + 1, row + 1)

    pub def isWallTile(col: Int32, row: Int32): Bool =
        not FloorScene.isFloor(col, row) and hasAdjacentFloor(col, row)

    // ========================================================================
    // Atlas UV Helpers
    // ========================================================================
    //
    // UV for wall tile from atlas_walls_low-16x16.png (12 cols x 4 rows).
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
        let extendLeft  = isWallTile(col - 1, row) or FloorScene.isFloor(col - 1, row);
        let extendRight = isWallTile(col + 1, row) or FloorScene.isFloor(col + 1, row);
        let atlasCol = match (extendLeft, extendRight) {
            case (false, false) => 0
            case (false, true)  => 1
            case (true,  true)  => 2
            case (true,  false) => 3
        };
        wallAtlasUV(atlasCol, wallAtlasRow(col, row))

    /// UV for the wall strip overlay (Col 0, fixed Row 1 — consistent mortar pattern).
    pub def wallStripUV(_col: Int32, _row: Int32): (Vec2D.Vec2, Vec2D.Vec2) =
        wallAtlasUV(0, 1)

    // ========================================================================
    // Tile Building
    // ========================================================================

    def mkWallTile(col: Int32, row: Int32, tileSz: Float32,
                    tileShape: SceneTree.CollisionShapeData): SceneTree.Node =
        let pos = Grid.toWorld({row = row, col = col}, tileSz);
        let (fOff, fSc) = wallFaceUV(col, row);
        let face = Sprite2D.init({
                name = "TileFace_${col}_${row}", pos = Vec2D.zero(),
                size = {x = tileSz, y = tileSz}, texture = "wall"
            })
            |> Sprite2D.uv(fOff, fSc);
        let (sOff, sSc) = wallStripUV(col, row);
        let strip = Sprite2D.init({
                name = "TileStrip_${col}_${row}", pos = Vec2D.zero(),
                size = {x = tileSz, y = tileSz}, texture = "wall"
            })
            |> Sprite2D.uv(sOff, sSc);
        let shape = SceneTree.collisionShape2D("TileShape_${col}_${row}", tileShape);
        StaticBody2D.init({
                name = "Tile_${col}_${row}", pos = pos,
                children = face :: strip :: shape :: Nil
            })

    pub def buildWallTiles(cols: Int32, rows: Int32, tileSz: Float32): List[SceneTree.Node] =
        let tileShape = SceneTree.CollisionShapeData.RectShape({x = tileSz, y = tileSz});
        List.range(0, rows)
            |> List.flatMap(row -> List.range(0, cols) |> List.map(col -> (col, row)))
            |> List.filterMap(match (col, row) ->
                if (isWallTile(col, row)) Some(mkWallTile(col, row, tileSz, tileShape))
                else None)
}
