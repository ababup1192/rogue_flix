// FloorScene — dungeon floor layout and tile building

mod FloorScene {
    // ========================================================================
    // Dungeon Layout
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

    pub def buildFloorTiles(cols: Int32, rows: Int32, tileSz: Float32): List[SceneTree.Node] =
        let (floorOff, floorSc) = floorUV();
        let tileShape = SceneTree.CollisionShapeData.RectShape({x = tileSz, y = tileSz});
        List.range(0, rows)
            |> List.flatMap(row -> List.range(0, cols) |> List.map(col -> (col, row)))
            |> List.filterMap(match (col, row) ->
                if (isFloor(col, row))
                    Some(mkFloorTile(col, row, tileSz, floorOff, floorSc, tileShape))
                else 
                    None)
}
