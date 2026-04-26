// Node builders — pipe-based constructors: init creates Node, setters modify it
//
// Usage:
//   Sprite2D.init({name = "Foo", pos = ..., size = ..., texture = "bar"})
//       |> Sprite2D.uv(offset, scale)

// ========================================================================
// Sprite2D
// ========================================================================

mod Sprite2D {
    pub def init(req: {name = String, pos = Vec2D.Vec2, size = Vec2D.Vec2, texture = String}): SceneTree.Node =
        SceneTree.sprite2D(req#name, req#pos, {
            size = req#size,
            color = {r = 1.0f32, g = 1.0f32, b = 1.0f32},
            texture = req#texture,
            visible = true,
            uvOffset = Vec2D.zero(),
            uvScale = Vec2D.one()
        })

    pub def color(v: Game.Vec3, node: SceneTree.Node): SceneTree.Node =
        let SceneTree.Node.MkNode(n, p, kind, ch) = node;
        match kind {
            case SceneTree.NodeKind.Sprite(sd) =>
                SceneTree.Node.MkNode(n, p, SceneTree.NodeKind.Sprite({color = v | sd}), ch)
            case _ => node
        }

    pub def visible(v: Bool, node: SceneTree.Node): SceneTree.Node =
        let SceneTree.Node.MkNode(n, p, kind, ch) = node;
        match kind {
            case SceneTree.NodeKind.Sprite(sd) =>
                SceneTree.Node.MkNode(n, p, SceneTree.NodeKind.Sprite({visible = v | sd}), ch)
            case _ => node
        }

    pub def uv(offset: Vec2D.Vec2, scale: Vec2D.Vec2, node: SceneTree.Node): SceneTree.Node =
        let SceneTree.Node.MkNode(n, p, kind, ch) = node;
        match kind {
            case SceneTree.NodeKind.Sprite(sd) =>
                SceneTree.Node.MkNode(n, p, SceneTree.NodeKind.Sprite({uvOffset = offset, uvScale = scale | sd}), ch)
            case _ => node
        }
}

// ========================================================================
// AnimatedSprite2D
// ========================================================================

mod AnimatedSprite2D {
    pub def init(req: {name = String, pos = Vec2D.Vec2, size = Vec2D.Vec2, texture = String,
                       frameCount = Int32, frameWidth = Float32}): SceneTree.Node =
        SceneTree.animatedSprite2D(req#name, req#pos, {
            size = req#size,
            color = {r = 1.0f32, g = 1.0f32, b = 1.0f32},
            texture = req#texture,
            visible = true,
            uvOffset = Vec2D.zero(),
            uvScale = Vec2D.one(),
            frameCount = req#frameCount,
            frameWidth = req#frameWidth,
            currentFrame = 0,
            frameTimer = 0.0f32,
            fps = 6.0f32,
            playing = true
        })

    pub def color(v: Game.Vec3, node: SceneTree.Node): SceneTree.Node =
        let SceneTree.Node.MkNode(n, p, kind, ch) = node;
        match kind {
            case SceneTree.NodeKind.AnimatedSprite(asd) =>
                SceneTree.Node.MkNode(n, p, SceneTree.NodeKind.AnimatedSprite({color = v | asd}), ch)
            case _ => node
        }

    pub def uv(offset: Vec2D.Vec2, scale: Vec2D.Vec2, node: SceneTree.Node): SceneTree.Node =
        let SceneTree.Node.MkNode(n, p, kind, ch) = node;
        match kind {
            case SceneTree.NodeKind.AnimatedSprite(asd) =>
                SceneTree.Node.MkNode(n, p, SceneTree.NodeKind.AnimatedSprite({uvOffset = offset, uvScale = scale | asd}), ch)
            case _ => node
        }

    pub def fps(v: Float32, node: SceneTree.Node): SceneTree.Node =
        let SceneTree.Node.MkNode(n, p, kind, ch) = node;
        match kind {
            case SceneTree.NodeKind.AnimatedSprite(asd) =>
                SceneTree.Node.MkNode(n, p, SceneTree.NodeKind.AnimatedSprite({fps = v | asd}), ch)
            case _ => node
        }

    pub def playing(v: Bool, node: SceneTree.Node): SceneTree.Node =
        let SceneTree.Node.MkNode(n, p, kind, ch) = node;
        match kind {
            case SceneTree.NodeKind.AnimatedSprite(asd) =>
                SceneTree.Node.MkNode(n, p, SceneTree.NodeKind.AnimatedSprite({playing = v | asd}), ch)
            case _ => node
        }
}

// ========================================================================
// StaticBody2D
// ========================================================================

mod StaticBody2D {
    pub def init(req: {name = String, pos = Vec2D.Vec2, children = List[SceneTree.Node]}): SceneTree.Node =
        SceneTree.staticBody2D(req#name, req#pos,
            {isSolid = true, destroyed = false}, req#children)

    pub def isSolid(v: Bool, node: SceneTree.Node): SceneTree.Node =
        let SceneTree.Node.MkNode(n, p, kind, ch) = node;
        match kind {
            case SceneTree.NodeKind.Fixed(bd) =>
                SceneTree.Node.MkNode(n, p, SceneTree.NodeKind.Fixed({isSolid = v | bd}), ch)
            case _ => node
        }

    pub def destroyed(v: Bool, node: SceneTree.Node): SceneTree.Node =
        let SceneTree.Node.MkNode(n, p, kind, ch) = node;
        match kind {
            case SceneTree.NodeKind.Fixed(bd) =>
                SceneTree.Node.MkNode(n, p, SceneTree.NodeKind.Fixed({destroyed = v | bd}), ch)
            case _ => node
        }
}

// ========================================================================
// CharacterBody2D
// ========================================================================

mod CharacterBody2D {
    pub def init(req: {name = String, pos = Vec2D.Vec2, children = List[SceneTree.Node]}): SceneTree.Node =
        SceneTree.characterBody2D(req#name, req#pos,
            {targetPos = req#pos, moveSpeed = 0.0f32}, req#children)

    pub def moveSpeed(v: Float32, node: SceneTree.Node): SceneTree.Node =
        let SceneTree.Node.MkNode(n, p, kind, ch) = node;
        match kind {
            case SceneTree.NodeKind.Character(cbd) =>
                SceneTree.Node.MkNode(n, p, SceneTree.NodeKind.Character({moveSpeed = v | cbd}), ch)
            case _ => node
        }

    pub def targetPos(v: Vec2D.Vec2, node: SceneTree.Node): SceneTree.Node =
        let SceneTree.Node.MkNode(n, p, kind, ch) = node;
        match kind {
            case SceneTree.NodeKind.Character(cbd) =>
                SceneTree.Node.MkNode(n, p, SceneTree.NodeKind.Character({targetPos = v | cbd}), ch)
            case _ => node
        }
}

// ========================================================================
// Raycast2D
// ========================================================================

mod Raycast2D {
    pub def init(req: {name = String, pos = Vec2D.Vec2, direction = Vec2D.Vec2}): SceneTree.Node =
        SceneTree.raycast2DNode(req#name, req#pos,
            {direction = req#direction, maxDistance = 32.0f32, enabled = true})

    pub def maxDistance(v: Float32, node: SceneTree.Node): SceneTree.Node =
        let SceneTree.Node.MkNode(n, p, kind, ch) = node;
        match kind {
            case SceneTree.NodeKind.Raycast(rd) =>
                SceneTree.Node.MkNode(n, p, SceneTree.NodeKind.Raycast({maxDistance = v | rd}), ch)
            case _ => node
        }

    pub def enabled(v: Bool, node: SceneTree.Node): SceneTree.Node =
        let SceneTree.Node.MkNode(n, p, kind, ch) = node;
        match kind {
            case SceneTree.NodeKind.Raycast(rd) =>
                SceneTree.Node.MkNode(n, p, SceneTree.NodeKind.Raycast({enabled = v | rd}), ch)
            case _ => node
        }
}

// ========================================================================
// Camera2D
// ========================================================================

mod Camera2D {
    pub def init(req: {name = String, pos = Vec2D.Vec2}): SceneTree.Node =
        SceneTree.camera2DNode(req#name, req#pos, {
            offset = Vec2D.zero(),
            zoom = Vec2D.one(),
            smoothingEnabled = false,
            smoothingSpeed = 5.0f32,
            limitLeft = -10000000.0f32,
            limitRight = 10000000.0f32,
            limitTop = -10000000.0f32,
            limitBottom = 10000000.0f32,
            isCurrent = false,
            smoothedPos = Vec2D.zero()
        })

    pub def offset(v: Vec2D.Vec2, node: SceneTree.Node): SceneTree.Node =
        let SceneTree.Node.MkNode(n, p, kind, ch) = node;
        match kind {
            case SceneTree.NodeKind.Camera(cd) =>
                SceneTree.Node.MkNode(n, p, SceneTree.NodeKind.Camera({offset = v | cd}), ch)
            case _ => node
        }

    pub def zoom(v: Vec2D.Vec2, node: SceneTree.Node): SceneTree.Node =
        let SceneTree.Node.MkNode(n, p, kind, ch) = node;
        match kind {
            case SceneTree.NodeKind.Camera(cd) =>
                SceneTree.Node.MkNode(n, p, SceneTree.NodeKind.Camera({zoom = v | cd}), ch)
            case _ => node
        }

    pub def smoothingEnabled(v: Bool, node: SceneTree.Node): SceneTree.Node =
        let SceneTree.Node.MkNode(n, p, kind, ch) = node;
        match kind {
            case SceneTree.NodeKind.Camera(cd) =>
                SceneTree.Node.MkNode(n, p, SceneTree.NodeKind.Camera({smoothingEnabled = v | cd}), ch)
            case _ => node
        }

    pub def smoothingSpeed(v: Float32, node: SceneTree.Node): SceneTree.Node =
        let SceneTree.Node.MkNode(n, p, kind, ch) = node;
        match kind {
            case SceneTree.NodeKind.Camera(cd) =>
                SceneTree.Node.MkNode(n, p, SceneTree.NodeKind.Camera({smoothingSpeed = v | cd}), ch)
            case _ => node
        }

    pub def limits(l: Float32, r: Float32, t: Float32, b: Float32, node: SceneTree.Node): SceneTree.Node =
        let SceneTree.Node.MkNode(n, p, kind, ch) = node;
        match kind {
            case SceneTree.NodeKind.Camera(cd) =>
                SceneTree.Node.MkNode(n, p, SceneTree.NodeKind.Camera({limitLeft = l, limitRight = r, limitTop = t, limitBottom = b | cd}), ch)
            case _ => node
        }

    pub def makeCurrent(v: Bool, node: SceneTree.Node): SceneTree.Node =
        let SceneTree.Node.MkNode(n, p, kind, ch) = node;
        match kind {
            case SceneTree.NodeKind.Camera(cd) =>
                SceneTree.Node.MkNode(n, p, SceneTree.NodeKind.Camera({isCurrent = v | cd}), ch)
            case _ => node
        }
}
