// Grid — world <-> grid coordinate conversion

mod Grid {
    pub type alias GridPos = {row = Int32, col = Int32}

    /// Convert grid coordinates (row, col) to world pixel coordinates.
    /// x = col * tileSz, y = row * tileSz
    pub def toWorld(gridPos: GridPos, tileSz: Float32): Vec2D.Vec2 =
        {x = Int32.toFloat32(gridPos#col) * tileSz,
         y = Int32.toFloat32(gridPos#row) * tileSz}

    /// Convert world pixel coordinates to grid coordinates (row, col).
    /// row = y / tileSz, col = x / tileSz
    pub def fromWorld(worldPos: Vec2D.Vec2, tileSz: Float32): GridPos =
        {row = Float32.truncateToInt32(worldPos#y / tileSz),
         col = Float32.truncateToInt32(worldPos#x / tileSz)}
}
