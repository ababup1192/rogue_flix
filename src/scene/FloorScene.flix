// FloorScene — dungeon floor tile building

mod FloorScene {

    pub def isFloor(floors: Set[(Int32, Int32)], col: Int32, row: Int32): Bool =
        Set.memberOf((col, row), floors)

    // ========================================================================
    // Atlas UV
    // ========================================================================

    /// UV for floor tile (0,0) from atlas_floor-16x16.png (7 cols x 7 rows).
    pub def floorUV(): (Vec2D.Vec2, Vec2D.Vec2) =
        ({x = 0.0f32, y = 1.0f32}, {x = 1.0f32 / 7.0f32, y = -1.0f32 / 7.0f32})

    // ========================================================================
    // Tile Building
    // ========================================================================

    def mkFloorTile(col: Int32, row: Int32, tileSz: Float32,
                     floorOff: Vec2D.Vec2, floorSc: Vec2D.Vec2,
                     tileShape: SceneTree.CollisionShapeData): SceneTree.Node =
        let pos = Grid.toWorld({row = row, col = col}, tileSz);
        let sprite = Sprite2D.init({
                name = "TileSprite_${col}_${row}", pos = Vec2D.zero(),
                size = {x = tileSz, y = tileSz}, texture = "floor"
            })
            |> Sprite2D.uv(floorOff, floorSc);
        let shape = SceneTree.collisionShape2D("TileShape_${col}_${row}", tileShape);
        StaticBody2D.init({
                name = "Tile_${col}_${row}", pos = pos,
                children = sprite :: shape :: Nil
            })
            |> StaticBody2D.isSolid(false)

    pub def buildFloorTiles(floors: Set[(Int32, Int32)], cols: Int32, rows: Int32, tileSz: Float32): List[SceneTree.Node] =
        let (floorOff, floorSc) = floorUV();
        let tileShape = SceneTree.CollisionShapeData.RectShape({x = tileSz, y = tileSz});
        List.range(0, rows)
            |> List.flatMap(row -> List.range(0, cols) |> List.map(col -> (col, row)))
            |> List.filterMap(match (col, row) ->
                if (isFloor(floors, col, row))
                    Some(mkFloorTile(col, row, tileSz, floorOff, floorSc, tileShape))
                else
                    None)
}
