// Scene tree — Godot-inspired node system with built-in physics engine

mod SceneTree {
    pub type alias SpriteData = {
        size = Vec2D.Vec2,
        color = Game.Vec3,
        texture = String,
        visible = Bool,
        uvOffset = Vec2D.Vec2,
        uvScale = Vec2D.Vec2
    }

    pub enum CollisionShapeData {
        case RectShape(Vec2D.Vec2)
        case CircleShape(Float32)
    }

    pub type alias KinematicBodyData = { velocity = Vec2D.Vec2 }
    pub type alias RigidBodyData = { velocity = Vec2D.Vec2, stuck = Bool }
    pub type alias StaticBodyData = { isSolid = Bool, destroyed = Bool }
    pub type alias AreaData = { velocity = Vec2D.Vec2 }
    pub type alias CharacterBodyData = { targetPos = Vec2D.Vec2, moveSpeed = Float32 }

    pub type alias CameraData = {
        offset = Vec2D.Vec2,
        zoom = Vec2D.Vec2,
        smoothingEnabled = Bool,
        smoothingSpeed = Float32,
        limitLeft = Float32,
        limitRight = Float32,
        limitTop = Float32,
        limitBottom = Float32,
        isCurrent = Bool,
        smoothedPos = Vec2D.Vec2
    }

    pub type alias RaycastData = {
        direction = Vec2D.Vec2,
        maxDistance = Float32,
        enabled = Bool
    }

    pub enum NodeKind {
        case Plain
        case Sprite(SpriteData)
        case Shape(CollisionShapeData)
        case Kinematic(KinematicBodyData)
        case Rigid(RigidBodyData)
        case Fixed(StaticBodyData)
        case Area(AreaData)
        case Raycast(RaycastData)
        case Character(CharacterBodyData)
        case Camera(CameraData)
    }

    pub enum Node {
        case MkNode(String, Vec2D.Vec2, NodeKind, List[Node])
    }

    pub enum Direction with Eq, ToString {
        case Up
        case Right
        case Down
        case Left
    }

    pub type alias BodyContact = {
        name = String,
        position = Vec2D.Vec2,
        kind = NodeKind,
        isSolid = Bool,
        group = String
    }

    pub type alias BodyInfo = {
        name = String,
        position = Vec2D.Vec2,
        shape = CollisionShapeData,
        isSolid = Bool,
        kind = NodeKind,
        group = String
    }

    pub type alias PhysicsConfig = {
        screenSize = Vec2D.Vec2,
        anchorPos = Vec2D.Vec2,
        anchorWidth = Float32
    }

    pub type alias CollisionEvent = {
        targetName = String,
        targetKind = NodeKind,
        targetGroup = String,
        targetPosition = Vec2D.Vec2,
        targetSize = Vec2D.Vec2,
        area = Node,
        areaGlobalPos = Vec2D.Vec2,
        areaRadius = Float32,
        direction = Direction,
        diff = Vec2D.Vec2
    }

    pub type alias OverlapEvent = {
        kinematicName = String,
        kinematicPos = Vec2D.Vec2,
        kinematicSize = Vec2D.Vec2,
        targetName = String,
        targetKind = NodeKind,
        targetGroup = String,
        targetPosition = Vec2D.Vec2,
        targetSize = Vec2D.Vec2
    }

    // Godot-inspired signals via algebraic effects
    pub eff OnCollision {
        def bodyEntered(nodeName: String, selfPos: Vec2D.Vec2, body: BodyContact): Unit
        def areaEntered(nodeName: String, selfPos: Vec2D.Vec2, body: BodyContact): Unit
    }

    pub eff OnRaycast {
        def rayHit(raycastName: String, hit: Option[RaycastHit]): Unit
    }

    type alias RigidBodyInfo = {
        name = String,
        node = Node,
        globalPos = Vec2D.Vec2,
        radius = Float32,
        stuck = Bool
    }

    // ========================================================================
    // Constructors (Godot vocabulary)
    // ========================================================================

    pub def node2D(name: String, pos: Vec2D.Vec2, children: List[Node]): Node =
        Node.MkNode(name, pos, NodeKind.Plain, children)

    pub def sprite2D(name: String, pos: Vec2D.Vec2, sd: SpriteData): Node =
        Node.MkNode(name, pos, NodeKind.Sprite(sd), Nil)

    pub def collisionShape2D(name: String, shape: CollisionShapeData): Node =
        Node.MkNode(name, Vec2D.zero(), NodeKind.Shape(shape), Nil)

    pub def kinematicBody2D(name: String, pos: Vec2D.Vec2, bd: KinematicBodyData, children: List[Node]): Node =
        Node.MkNode(name, pos, NodeKind.Kinematic(bd), children)

    pub def rigidBody2D(name: String, pos: Vec2D.Vec2, bd: RigidBodyData, children: List[Node]): Node =
        Node.MkNode(name, pos, NodeKind.Rigid(bd), children)

    pub def staticBody2D(name: String, pos: Vec2D.Vec2, bd: StaticBodyData, children: List[Node]): Node =
        Node.MkNode(name, pos, NodeKind.Fixed(bd), children)

    pub def area2D(name: String, pos: Vec2D.Vec2, ad: AreaData, children: List[Node]): Node =
        Node.MkNode(name, pos, NodeKind.Area(ad), children)

    pub def raycast2DNode(name: String, pos: Vec2D.Vec2, rd: RaycastData): Node =
        Node.MkNode(name, pos, NodeKind.Raycast(rd), Nil)

    pub def characterBody2D(name: String, pos: Vec2D.Vec2, cbd: CharacterBodyData, children: List[Node]): Node =
        Node.MkNode(name, pos, NodeKind.Character(cbd), children)

    pub def camera2DNode(name: String, pos: Vec2D.Vec2, cd: CameraData): Node =
        Node.MkNode(name, pos, NodeKind.Camera(cd), Nil)

    // ========================================================================
    // Basic Helpers
    // ========================================================================

    pub def nodeName(node: Node): String =
        let Node.MkNode(n, _, _, _) = node; n

    pub def nodeChildren(node: Node): List[Node] =
        let Node.MkNode(_, _, _, ch) = node; ch

    pub def nodePosition(node: Node): Vec2D.Vec2 =
        let Node.MkNode(_, p, _, _) = node; p

    pub def nodeKind(node: Node): NodeKind =
        let Node.MkNode(_, _, k, _) = node; k

    pub def appendChildren(node: Node, extra: List[Node]): Node =
        let Node.MkNode(n, p, k, ch) = node;
        Node.MkNode(n, p, k, List.append(ch, extra))

    // ========================================================================
    // Tree Search & Modification
    // ========================================================================

    pub def findNode(name: String, node: Node): Option[Node] =
        if (nodeName(node) == name) Some(node)
        else List.findMap(child -> findNode(name, child), nodeChildren(node))

    pub def mapNode(name: String, f: Node -> Node, node: Node): Node =
        if (nodeName(node) == name) f(node)
        else mapChildren(child -> mapNode(name, f, child), node)

    pub def removeChild(parentName: String, childName: String, root: Node): Node =
        mapNode(parentName, node -> {
            let Node.MkNode(n, p, k, children) = node;
            Node.MkNode(n, p, k, List.filter(child -> nodeName(child) != childName, children))
        }, root)

    def mapChildren(f: Node -> Node, node: Node): Node =
        let Node.MkNode(n, t, k, children) = node;
        Node.MkNode(n, t, k, List.map(f, children))

    // ========================================================================
    // Node Update Helpers
    // ========================================================================

    pub def updateKinematicBody(name: String, f: KinematicBodyData -> KinematicBodyData, root: Node): Node =
        mapNode(name, node -> match nodeKind(node) {
            case NodeKind.Kinematic(bd) =>
                let Node.MkNode(n, t, _, ch) = node;
                Node.MkNode(n, t, NodeKind.Kinematic(f(bd)), ch)
            case _ => node
        }, root)

    pub def updateRigidBody(name: String, f: RigidBodyData -> RigidBodyData, root: Node): Node =
        mapNode(name, node -> match nodeKind(node) {
            case NodeKind.Rigid(bd) =>
                let Node.MkNode(n, t, _, ch) = node;
                Node.MkNode(n, t, NodeKind.Rigid(f(bd)), ch)
            case _ => node
        }, root)

    pub def updateStaticBody(name: String, f: StaticBodyData -> StaticBodyData, root: Node): Node =
        mapNode(name, node -> match nodeKind(node) {
            case NodeKind.Fixed(bd) =>
                let Node.MkNode(n, t, _, ch) = node;
                Node.MkNode(n, t, NodeKind.Fixed(f(bd)), ch)
            case _ => node
        }, root)

    pub def updateSprite(name: String, f: SpriteData -> SpriteData, root: Node): Node =
        mapNode(name, node -> match nodeKind(node) {
            case NodeKind.Sprite(sd) =>
                let Node.MkNode(n, p, _, ch) = node;
                Node.MkNode(n, p, NodeKind.Sprite(f(sd)), ch)
            case _ => node
        }, root)

    pub def setNodePosition(name: String, pos: Vec2D.Vec2, root: Node): Node =
        mapNode(name, node -> {
            let Node.MkNode(n, _, k, ch) = node;
            Node.MkNode(n, pos, k, ch)
        }, root)

    pub def rigidBodyData(node: Node): Option[RigidBodyData] =
        match nodeKind(node) {
            case NodeKind.Rigid(bd) => Some(bd)
            case _ => None
        }

    pub def kinematicBodyData(node: Node): Option[KinematicBodyData] =
        match nodeKind(node) {
            case NodeKind.Kinematic(bd) => Some(bd)
            case _ => None
        }

    pub def staticBodyData(node: Node): Option[StaticBodyData] =
        match nodeKind(node) {
            case NodeKind.Fixed(bd) => Some(bd)
            case _ => None
        }

    pub def updateCharacterBody(name: String, f: CharacterBodyData -> CharacterBodyData, root: Node): Node =
        mapNode(name, node -> match nodeKind(node) {
            case NodeKind.Character(cbd) =>
                let Node.MkNode(n, t, _, ch) = node;
                Node.MkNode(n, t, NodeKind.Character(f(cbd)), ch)
            case _ => node
        }, root)

    pub def updateRaycast(name: String, f: RaycastData -> RaycastData, root: Node): Node =
        mapNode(name, node -> match nodeKind(node) {
            case NodeKind.Raycast(rd) =>
                let Node.MkNode(n, p, _, ch) = node;
                Node.MkNode(n, p, NodeKind.Raycast(f(rd)), ch)
            case _ => node
        }, root)

    pub def raycastData(node: Node): Option[RaycastData] =
        match nodeKind(node) {
            case NodeKind.Raycast(rd) => Some(rd)
            case _ => None
        }

    pub def characterBodyData(node: Node): Option[CharacterBodyData] =
        match nodeKind(node) {
            case NodeKind.Character(cbd) => Some(cbd)
            case _ => None
        }

    pub def findRectShape(children: List[Node]): Option[Vec2D.Vec2] =
        List.findMap(child -> match nodeKind(child) {
            case NodeKind.Shape(CollisionShapeData.RectShape(size)) => Some(size)
            case _ => None
        }, children)

    pub def findCircleShape(children: List[Node]): Option[Float32] =
        List.findMap(child -> match nodeKind(child) {
            case NodeKind.Shape(CollisionShapeData.CircleShape(r)) => Some(r)
            case _ => None
        }, children)

    /// Update the first Sprite child of the node named `parentName`.
    pub def updateChildSprite(parentName: String, f: SpriteData -> SpriteData, root: Node): Node =
        mapNode(parentName, node -> {
            let Node.MkNode(n, pos, kind, children) = node;
            let newChildren = mapFirstSprite(f, children);
            Node.MkNode(n, pos, kind, newChildren)
        }, root)

    def mapFirstSprite(f: SpriteData -> SpriteData, children: List[Node]): List[Node] =
        match children {
            case Nil => Nil
            case hd :: tl => match nodeKind(hd) {
                case NodeKind.Sprite(sd) =>
                    let Node.MkNode(n, p, _, ch) = hd;
                    Node.MkNode(n, p, NodeKind.Sprite(f(sd)), ch) :: tl
                case _ => hd :: mapFirstSprite(f, tl)
            }
        }

    /// Update both the Sprite size and CollisionShape of a body node's children.
    pub def updateChildSpriteAndShape(parentName: String, fSprite: SpriteData -> SpriteData,
        fShape: CollisionShapeData -> CollisionShapeData, root: Node): Node =
        mapNode(parentName, node -> {
            let Node.MkNode(n, pos, kind, children) = node;
            let newChildren = List.map(child -> match nodeKind(child) {
                case NodeKind.Sprite(sd) =>
                    let Node.MkNode(cn, cp, _, cch) = child;
                    Node.MkNode(cn, cp, NodeKind.Sprite(fSprite(sd)), cch)
                case NodeKind.Shape(shape) =>
                    let Node.MkNode(cn, cp, _, cch) = child;
                    Node.MkNode(cn, cp, NodeKind.Shape(fShape(shape)), cch)
                case _ => child
            }, children);
            Node.MkNode(n, pos, kind, newChildren)
        }, root)

    pub def globalPosition(name: String, node: Node): Option[Vec2D.Vec2] =
        globalPositionHelper(name, node, Vec2D.zero())

    def globalPositionHelper(name: String, node: Node, parentPos: Vec2D.Vec2): Option[Vec2D.Vec2] =
        let currentPos = Vec2D.add(parentPos, nodePosition(node));
        if (nodeName(node) == name) Some(currentPos)
        else List.findMap(child -> globalPositionHelper(name, child, currentPos), nodeChildren(node))

    // ========================================================================
    // Camera2D
    // ========================================================================

    pub def findCurrentCamera(node: Node): Option[(CameraData, Vec2D.Vec2)] =
        findCurrentCameraHelper(node, Vec2D.zero())

    def findCurrentCameraHelper(node: Node, parentPos: Vec2D.Vec2): Option[(CameraData, Vec2D.Vec2)] =
        let Node.MkNode(_, pos, kind, children) = node;
        let globalPos = Vec2D.add(parentPos, pos);
        match kind {
            case NodeKind.Camera(cd) =>
                if (cd#isCurrent) Some((cd, globalPos)) else None
            case _ =>
                List.findMap(child -> findCurrentCameraHelper(child, globalPos), children)
        }

    pub def updateCameraSmoothing(dt: Float32, root: Node): Node =
        updateCameraSmoothingHelper(dt, root, Vec2D.zero())

    def updateCameraSmoothingHelper(dt: Float32, node: Node, parentPos: Vec2D.Vec2): Node =
        let Node.MkNode(name, pos, kind, children) = node;
        let globalPos = Vec2D.add(parentPos, pos);
        match kind {
            case NodeKind.Camera(cd) =>
                if (cd#isCurrent) {
                    let newSmoothed = if (Vec2D.isZeroApprox(cd#smoothedPos) and not Vec2D.isZeroApprox(globalPos)) {
                        globalPos
                    } else if (cd#smoothingEnabled) {
                        let t = Float32.min(1.0f32, cd#smoothingSpeed * dt);
                        Vec2D.lerp(cd#smoothedPos, globalPos, t)
                    } else globalPos;
                    Node.MkNode(name, pos, NodeKind.Camera({smoothedPos = newSmoothed | cd}), children)
                } else node
            case _ =>
                Node.MkNode(name, pos, kind, List.map(child -> updateCameraSmoothingHelper(dt, child, globalPos), children))
        }

    // ========================================================================
    // Rendering: collectDrawables
    // ========================================================================

    pub def collectDrawables(node: Node, parentPos: Vec2D.Vec2): List[(SpriteData, Vec2D.Vec2)] =
        let Node.MkNode(_, pos, kind, children) = node;
        let globalPos = Vec2D.add(parentPos, pos);
        match kind {
            case NodeKind.Sprite(sd) =>
                if (sd#visible) (sd, globalPos) :: Nil else Nil
            case NodeKind.Fixed(bd) =>
                if (bd#destroyed) Nil
                else List.flatMap(child -> collectDrawables(child, globalPos), children)
            case NodeKind.Shape(_) => Nil
            case NodeKind.Raycast(_) => Nil
            case NodeKind.Camera(_) => Nil
            case _ =>
                List.flatMap(child -> collectDrawables(child, globalPos), children)
        }

    // ========================================================================
    // Engine: Direction helpers
    // ========================================================================

    pub def directionToVec(dir: Direction): Vec2D.Vec2 =
        match dir {
            case Direction.Up    => {x = 0.0f32, y = -1.0f32}
            case Direction.Down  => {x = 0.0f32, y = 1.0f32}
            case Direction.Left  => {x = -1.0f32, y = 0.0f32}
            case Direction.Right => {x = 1.0f32, y = 0.0f32}
        }

    pub def vectorDirection(target: Vec2D.Vec2): Direction =
        let dotUp    = target#y;
        let dotRight = target#x;
        let dotDown  = -1.0f32 * target#y;
        let dotLeft  = -1.0f32 * target#x;
        let (d0, v0) = (Direction.Up, dotUp);
        let (d1, v1) = if (dotRight > v0) (Direction.Right, dotRight) else (d0, v0);
        let (d2, v2) = if (dotDown > v1) (Direction.Down, dotDown) else (d1, v1);
        let (d3, _)  = if (dotLeft > v2) (Direction.Left, dotLeft) else (d2, v2);
        d3

    // ========================================================================
    // Engine: Collision Detection
    // ========================================================================

    pub def checkCircleRect(circlePos: Vec2D.Vec2, radius: Float32,
        rectPos: Vec2D.Vec2, rectSize: Vec2D.Vec2): Option[(Direction, Vec2D.Vec2)] =
        let ballCenter = Vec2D.add(circlePos, {x = radius, y = radius});
        let halfExtents = Vec2D.div(rectSize, 2.0f32);
        let aabbCenter = Vec2D.add(rectPos, halfExtents);
        let diff = Vec2D.sub(ballCenter, aabbCenter);
        let clamped = Vec2D.clampSymmetric(diff, halfExtents);
        let closest = Vec2D.add(aabbCenter, clamped);
        let difference = Vec2D.sub(closest, ballCenter);
        let distSq = Vec2D.lengthSquared(difference);
        if (distSq < radius * radius)
            Some((vectorDirection(difference), difference))
        else
            None

    pub def resolveCollision(pos: Vec2D.Vec2, vel: Vec2D.Vec2, radius: Float32,
        dir: Direction, diff: Vec2D.Vec2): (Vec2D.Vec2, Vec2D.Vec2) =
        let horizontal = (dir == Direction.Left) or (dir == Direction.Right);
        if (horizontal) {
            let penetration = radius - Float32.abs(diff#x);
            let newX = if (dir == Direction.Left) pos#x + penetration else pos#x - penetration;
            ({x = newX, y = pos#y}, {x = -1.0f32 * vel#x, y = vel#y})
        } else {
            let penetration = radius - Float32.abs(diff#y);
            let newY = if (dir == Direction.Up) pos#y - penetration else pos#y + penetration;
            ({x = pos#x, y = newY}, {x = vel#x, y = -1.0f32 * vel#y})
        }

    // ========================================================================
    // Engine: collectBodies
    // ========================================================================

    pub def collectBodies(node: Node): List[BodyInfo] =
        collectBodiesWithGroup(node, Vec2D.zero(), "")

    def extractShapes(name: String, globalPos: Vec2D.Vec2, isSolid: Bool, kind: NodeKind, group: String, children: List[Node]): List[BodyInfo] =
        List.filterMap(child -> match nodeKind(child) {
            case NodeKind.Shape(shape) => Some({
                name = name,
                position = globalPos,
                shape = shape,
                isSolid = isSolid,
                kind = kind,
                group = group
            })
            case _ => None
        }, children)

    def collectBodyShapes(name: String, globalPos: Vec2D.Vec2, isSolid: Bool, kind: NodeKind, group: String, children: List[Node]): List[BodyInfo] =
        let shapes = extractShapes(name, globalPos, isSolid, kind, group, children);
        let childBodies = List.flatMap(child -> collectBodiesWithGroup(child, globalPos, group), children);
        List.append(shapes, childBodies)

    def collectBodiesWithGroup(node: Node, parentPos: Vec2D.Vec2, group: String): List[BodyInfo] =
        let Node.MkNode(name, pos, kind, children) = node;
        let globalPos = Vec2D.add(parentPos, pos);
        match kind {
            case NodeKind.Fixed(bd) =>
                if (bd#destroyed) Nil
                else collectBodyShapes(name, globalPos, bd#isSolid, kind, group, children)
            case NodeKind.Kinematic(_) =>
                collectBodyShapes(name, globalPos, true, kind, group, children)
            case NodeKind.Area(_) =>
                collectBodyShapes(name, globalPos, false, kind, group, children)
            case NodeKind.Plain =>
                List.flatMap(child -> collectBodiesWithGroup(child, globalPos, name), children)
            case NodeKind.Rigid(_) =>
                List.flatMap(child -> collectBodiesWithGroup(child, globalPos, group), children)
            case NodeKind.Sprite(_) => Nil
            case NodeKind.Shape(_) => Nil
            case NodeKind.Raycast(_) => Nil
            case NodeKind.Camera(_) => Nil
            case NodeKind.Character(_) =>
                List.flatMap(child -> collectBodiesWithGroup(child, globalPos, group), children)
        }

    // ========================================================================
    // Engine: collectRigidBodies
    // ========================================================================

    pub def collectRigidBodies(root: Node): List[RigidBodyInfo] =
        collectRigidBodiesHelper(root, Vec2D.zero())

    def collectRigidBodiesHelper(node: Node, parentPos: Vec2D.Vec2): List[RigidBodyInfo] =
        let Node.MkNode(name, pos, kind, children) = node;
        let globalPos = Vec2D.add(parentPos, pos);
        match kind {
            case NodeKind.Rigid(bd) =>
                let radius = findCircleShape(children) |> Option.getWithDefault(12.5f32);
                {name = name, node = node, globalPos = globalPos, radius = radius, stuck = bd#stuck} :: Nil
            case _ =>
                List.flatMap(child -> collectRigidBodiesHelper(child, globalPos), children)
        }

    // ========================================================================
    // Engine: detectCollisions
    // ========================================================================

    pub def detectCollisions(root: Node): List[CollisionEvent] =
        detectCollisionsFromBodies(collectRigidBodies(root), collectBodies(root))

    def detectCollisionsFromBodies(rigids: List[RigidBodyInfo], bodies: List[BodyInfo]): List[CollisionEvent] =
        List.flatMap(rigid ->
            if (rigid#stuck) Nil
            else List.filterMap(body ->
                match body#shape {
                    case CollisionShapeData.RectShape(size) =>
                        checkCircleRect(rigid#globalPos, rigid#radius, body#position, size)
                            |> Option.map(match (dir, diff) -> {
                                targetName = body#name,
                                targetKind = body#kind,
                                targetGroup = body#group,
                                targetPosition = body#position,
                                targetSize = size,
                                area = rigid#node,
                                areaGlobalPos = rigid#globalPos,
                                areaRadius = rigid#radius,
                                direction = dir,
                                diff = diff
                            })
                    case _ => None
                }, bodies
            ), rigids
        )

    // ========================================================================
    // Engine: Rect-Rect (AABB) overlap for Kinematic-Area collisions
    // ========================================================================

    pub def checkRectRect(posA: Vec2D.Vec2, sizeA: Vec2D.Vec2,
        posB: Vec2D.Vec2, sizeB: Vec2D.Vec2): Bool =
        (posA#x + sizeA#x > posB#x) and (posA#x < posB#x + sizeB#x) and
        (posA#y + sizeA#y > posB#y) and (posA#y < posB#y + sizeB#y)

    pub def checkShapeOverlap(posA: Vec2D.Vec2, shapeA: CollisionShapeData,
                               posB: Vec2D.Vec2, shapeB: CollisionShapeData): Bool =
        match (shapeA, shapeB) {
            case (CollisionShapeData.RectShape(sizeA), CollisionShapeData.RectShape(sizeB)) =>
                checkRectRect(posA, sizeA, posB, sizeB)
            case (CollisionShapeData.CircleShape(radius), CollisionShapeData.RectShape(size)) =>
                not Option.isEmpty(checkCircleRect(posA, radius, posB, size))
            case (CollisionShapeData.RectShape(size), CollisionShapeData.CircleShape(radius)) =>
                not Option.isEmpty(checkCircleRect(posB, radius, posA, size))
            case (CollisionShapeData.CircleShape(rA), CollisionShapeData.CircleShape(rB)) =>
                let cA = Vec2D.add(posA, {x = rA, y = rA});
                let cB = Vec2D.add(posB, {x = rB, y = rB});
                Vec2D.lengthSquared(Vec2D.sub(cA, cB)) < (rA + rB) * (rA + rB)
        }

    def shapeSize(shape: CollisionShapeData): Vec2D.Vec2 =
        match shape {
            case CollisionShapeData.RectShape(size) => size
            case CollisionShapeData.CircleShape(r) => {x = 2.0f32 * r, y = 2.0f32 * r}
        }

    pub def detectKinematicAreaOverlaps(root: Node): List[OverlapEvent] =
        detectKinematicAreaOverlapsFromBodies(collectBodies(root))

    def detectKinematicAreaOverlapsFromBodies(bodies: List[BodyInfo]): List[OverlapEvent] =
        let kinBodies = List.filter(b -> match b#kind {
            case NodeKind.Kinematic(_) => true
            case _ => false
        }, bodies);
        let areaBodies = List.filter(b -> match b#kind {
            case NodeKind.Area(_) => true
            case _ => false
        }, bodies);
        List.flatMap(kb ->
            List.filterMap(ab ->
                if (checkShapeOverlap(kb#position, kb#shape, ab#position, ab#shape))
                    Some({
                        kinematicName = kb#name,
                        kinematicPos = kb#position,
                        kinematicSize = shapeSize(kb#shape),
                        targetName = ab#name,
                        targetKind = ab#kind,
                        targetGroup = ab#group,
                        targetPosition = ab#position,
                        targetSize = shapeSize(ab#shape)
                    })
                else None
            , areaBodies)
        , kinBodies)

    def detectAreaAreaOverlapsFromBodies(bodies: List[BodyInfo]): List[OverlapEvent] =
        let areaBodies = List.filter(b -> match b#kind {
            case NodeKind.Area(_) => true
            case _ => false
        }, bodies);
        List.flatMap(a ->
            List.filterMap(b ->
                if (a#name == b#name) None
                else if (checkShapeOverlap(a#position, a#shape, b#position, b#shape))
                    Some({
                        kinematicName = a#name,
                        kinematicPos = a#position,
                        kinematicSize = shapeSize(a#shape),
                        targetName = b#name,
                        targetKind = b#kind,
                        targetGroup = b#group,
                        targetPosition = b#position,
                        targetSize = shapeSize(b#shape)
                    })
                else None
            , areaBodies)
        , areaBodies)

    // ========================================================================
    // Engine: resolveDetectedCollisions (auto physics resolution)
    // ========================================================================

    def resolveDetectedCollisions(root: Node, events: List[CollisionEvent]): Node =
        List.foldLeft((currentRoot, event) ->
            match event#targetKind {
                case NodeKind.Area(_) => currentRoot
                case _ =>
                    let rigidName = nodeName(event#area);
                    let radius = findCircleShape(nodeChildren(event#area))
                        |> Option.getWithDefault(12.5f32);
                    let vel = rigidBodyData(event#area)
                        |> Option.map(bd -> bd#velocity)
                        |> Option.getWithDefault(Vec2D.zero());
                    let (newPos, newVel) = resolveCollision(
                        event#areaGlobalPos, vel, radius,
                        event#direction, event#diff);
                    currentRoot
                        |> setNodePosition(rigidName, newPos)
                        |> updateRigidBody(rigidName, bd -> {velocity = newVel | bd})
            }, root, events)

    def fireCollisionSignal(event: CollisionEvent): Unit \ OnCollision =
        let selfPosition = Vec2D.add(event#areaGlobalPos, {x = event#areaRadius, y = event#areaRadius});
        let halfSize = Vec2D.div(event#targetSize, 2.0f32);
        let bodyPosition = Vec2D.add(event#targetPosition, halfSize);
        let isSolid = match event#targetKind {
            case NodeKind.Fixed(bd) => bd#isSolid
            case _ => false
        };
        let body: BodyContact = {name = event#targetName, position = bodyPosition, kind = event#targetKind, isSolid = isSolid, group = event#targetGroup};
        match event#targetKind {
            case NodeKind.Area(_) => OnCollision.areaEntered(nodeName(event#area), selfPosition, body)
            case _ => OnCollision.bodyEntered(nodeName(event#area), selfPosition, body)
        }

    def fireOverlapSignal(event: OverlapEvent): Unit \ OnCollision =
        let selfCenter = Vec2D.add(event#kinematicPos, Vec2D.div(event#kinematicSize, 2.0f32));
        let bodyCenter = Vec2D.add(event#targetPosition, Vec2D.div(event#targetSize, 2.0f32));
        let body: BodyContact = {
            name = event#targetName,
            position = bodyCenter,
            kind = event#targetKind,
            isSolid = false,
            group = event#targetGroup
        };
        OnCollision.areaEntered(event#kinematicName, selfCenter, body)

    // ========================================================================
    // Engine: stepAndCollide (physics step + collision signals)
    // ========================================================================

    pub def stepAndCollide(node: Node, dt: Float32, config: PhysicsConfig): Node \ OnCollision =
        stepAndCollideFiltered(node, dt, config, _ -> true)

    pub def stepAndCollideFiltered(node: Node, dt: Float32, config: PhysicsConfig,
        shouldResolve: CollisionEvent -> Bool): Node \ OnCollision =
        let movedRoot = physicsStepNode(node, dt, config);
        let bodies = collectBodies(movedRoot);
        let rigids = collectRigidBodies(movedRoot);
        let rigidEvents = detectCollisionsFromBodies(rigids, bodies);
        let overlapEvents = detectKinematicAreaOverlapsFromBodies(bodies);
        let areaAreaEvents = detectAreaAreaOverlapsFromBodies(bodies);
        List.forEach(fireCollisionSignal, rigidEvents);
        List.forEach(fireOverlapSignal, overlapEvents);
        List.forEach(fireOverlapSignal, areaAreaEvents);
        let resolveEvents = List.filter(shouldResolve, rigidEvents);
        resolveDetectedCollisions(movedRoot, resolveEvents)

    // ========================================================================
    // Raycast2D
    // ========================================================================

    pub type alias RaycastHit = {
        name = String,
        position = Vec2D.Vec2,
        kind = NodeKind,
        group = String,
        isSolid = Bool,
        distance = Float32,
        point = Vec2D.Vec2
    }

    /// Ray-AABB intersection using slab method. Returns distance t >= 0 if hit.
    pub def rayIntersectRect(origin: Vec2D.Vec2, dir: Vec2D.Vec2,
        rectPos: Vec2D.Vec2, rectSize: Vec2D.Vec2): Option[Float32] =
        let bigVal = 1.0e30f32;
        let (txMin, txMax) = if (Float32.abs(dir#x) < 0.0001f32) {
            if (origin#x < rectPos#x or origin#x > rectPos#x + rectSize#x)
                (bigVal, -1.0f32 * bigVal)
            else
                (-1.0f32 * bigVal, bigVal)
        } else {
            let invDx = 1.0f32 / dir#x;
            let t1 = (rectPos#x - origin#x) * invDx;
            let t2 = (rectPos#x + rectSize#x - origin#x) * invDx;
            (Float32.min(t1, t2), Float32.max(t1, t2))
        };
        let (tyMin, tyMax) = if (Float32.abs(dir#y) < 0.0001f32) {
            if (origin#y < rectPos#y or origin#y > rectPos#y + rectSize#y)
                (bigVal, -1.0f32 * bigVal)
            else
                (-1.0f32 * bigVal, bigVal)
        } else {
            let invDy = 1.0f32 / dir#y;
            let t1 = (rectPos#y - origin#y) * invDy;
            let t2 = (rectPos#y + rectSize#y - origin#y) * invDy;
            (Float32.min(t1, t2), Float32.max(t1, t2))
        };
        let tMin = Float32.max(txMin, tyMin);
        let tMax = Float32.min(txMax, tyMax);
        if (tMin > tMax or tMax < 0.0f32)
            None
        else
            Some(Float32.max(tMin, 0.0f32))

    /// Ray-circle intersection. Returns distance t >= 0 if hit.
    def rayIntersectCircle(origin: Vec2D.Vec2, dir: Vec2D.Vec2,
        circlePos: Vec2D.Vec2, radius: Float32): Option[Float32] =
        let center = Vec2D.add(circlePos, {x = radius, y = radius});
        let oc = Vec2D.sub(origin, center);
        let a = Vec2D.dot(dir, dir);
        let b = 2.0f32 * Vec2D.dot(oc, dir);
        let c = Vec2D.dot(oc, oc) - radius * radius;
        let discriminant = b * b - 4.0f32 * a * c;
        if (discriminant < 0.0f32) None
        else {
            let sqrtD = Vec2D.sqrt32(discriminant);
            let t1 = (-1.0f32 * b - sqrtD) / (2.0f32 * a);
            let t2 = (-1.0f32 * b + sqrtD) / (2.0f32 * a);
            if (t1 >= 0.0f32) Some(t1)
            else if (t2 >= 0.0f32) Some(t2)
            else None
        }

    /// Raycast against a list of bodies. Returns the closest hit within maxDistance.
    pub def raycast2DFromBodies(origin: Vec2D.Vec2, direction: Vec2D.Vec2,
        maxDistance: Float32, bodies: List[BodyInfo]): Option[RaycastHit] =
        let epsilon = 0.001f32;
        let hits = List.filterMap(body ->
            let tOpt = match body#shape {
                case CollisionShapeData.RectShape(size) =>
                    rayIntersectRect(origin, direction, body#position, size)
                case CollisionShapeData.CircleShape(radius) =>
                    rayIntersectCircle(origin, direction, body#position, radius)
            };
            Option.flatMap(t ->
                if (t > epsilon and t <= maxDistance) {
                    let point = Vec2D.add(origin, Vec2D.mul(direction, t));
                    Some({
                        name = body#name,
                        position = body#position,
                        kind = body#kind,
                        group = body#group,
                        isSolid = body#isSolid,
                        distance = t,
                        point = point
                    })
                } else None
            , tOpt)
        , bodies);
        let init: Option[RaycastHit] = None;
        List.foldLeft((closest, hit) ->
            match closest {
                case None => Some(hit)
                case Some(c) => if (hit#distance < c#distance) Some(hit) else closest
            }
        , init, hits)

    /// Raycast against the entire scene tree.
    pub def raycast2D(origin: Vec2D.Vec2, direction: Vec2D.Vec2,
        maxDistance: Float32, root: Node): Option[RaycastHit] =
        raycast2DFromBodies(origin, direction, maxDistance, collectBodies(root))

    /// Collect all Raycast nodes from the tree with their global positions.
    pub def collectRaycastNodes(node: Node, parentPos: Vec2D.Vec2): List[(String, Vec2D.Vec2, RaycastData)] =
        let Node.MkNode(name, pos, kind, children) = node;
        let globalPos = Vec2D.add(parentPos, pos);
        match kind {
            case NodeKind.Raycast(rd) => (name, globalPos, rd) :: Nil
            case _ => List.flatMap(child -> collectRaycastNodes(child, globalPos), children)
        }

    /// Process all enabled Raycast nodes: cast rays and fire OnRaycast.rayHit.
    pub def processRaycasts(root: Node): Unit \ OnRaycast =
        let bodies = collectBodies(root);
        let raycasts = collectRaycastNodes(root, Vec2D.zero());
        List.forEach(match (name, origin, rd) ->
            if (rd#enabled) {
                let hit = raycast2DFromBodies(origin, rd#direction, rd#maxDistance, bodies);
                OnRaycast.rayHit(name, hit)
            } else ()
        , raycasts)

    def physicsStepNode(node: Node, dt: Float32, config: PhysicsConfig): Node =
        let Node.MkNode(name, pos, kind, children) = node;
        match kind {
            case NodeKind.Kinematic(bodyData) =>
                let newX = pos#x + bodyData#velocity#x * dt;
                let clampedX = Float32.max(0.0f32, Float32.min(config#screenSize#x - config#anchorWidth, newX));
                Node.MkNode(name, {x = clampedX, y = pos#y}, kind, children)
            case NodeKind.Rigid(bodyData) =>
                if (bodyData#stuck) {
                    let ballRadius = findCircleShape(children) |> Option.getWithDefault(12.5f32);
                    let bx = config#anchorPos#x + config#anchorWidth / 2.0f32 - ballRadius;
                    let by = config#anchorPos#y - ballRadius * 2.0f32;
                    Node.MkNode(name, {x = bx, y = by}, kind, children)
                } else {
                    let ballSize = findCircleShape(children) |> Option.map(r -> r * 2.0f32) |> Option.getWithDefault(25.0f32);
                    let newX = pos#x + bodyData#velocity#x * dt;
                    let newY = pos#y + bodyData#velocity#y * dt;
                    let vx0 = bodyData#velocity#x;
                    let vy0 = bodyData#velocity#y;
                    let (nx1, vx1) = if (newX <= 0.0f32) (0.0f32, Float32.abs(vx0)) else (newX, vx0);
                    let (nx2, vx2) = if (nx1 + ballSize >= config#screenSize#x) (config#screenSize#x - ballSize, -1.0f32 * Float32.abs(vx1)) else (nx1, vx1);
                    let (ny1, vy1) = if (newY <= 0.0f32) (0.0f32, Float32.abs(vy0)) else (newY, vy0);
                    let newBodyData = {velocity = {x = vx2, y = vy1} | bodyData};
                    Node.MkNode(name, {x = nx2, y = ny1}, NodeKind.Rigid(newBodyData), children)
                }
            case NodeKind.Area(ad) =>
                let newPos = {x = pos#x + ad#velocity#x * dt, y = pos#y + ad#velocity#y * dt};
                Node.MkNode(name, newPos, kind, children)
            case NodeKind.Plain =>
                Node.MkNode(name, pos, kind, List.map(child -> physicsStepNode(child, dt, config), children))
            case _ => node
        }

    // ========================================================================
    // Engine: stepCharacterBodies (grid-based moveToward interpolation)
    // ========================================================================

    pub def stepCharacterBodies(dt: Float32, root: Node): Node =
        let Node.MkNode(name, pos, kind, children) = root;
        match kind {
            case NodeKind.Character(cbd) =>
                if (Vec2D.isZeroApprox(Vec2D.sub(cbd#targetPos, pos))) root
                else {
                    let newPos = Vec2D.moveToward(pos, cbd#targetPos, cbd#moveSpeed * dt);
                    Node.MkNode(name, newPos, kind, children)
                }
            case NodeKind.Plain =>
                Node.MkNode(name, pos, kind, List.map(child -> stepCharacterBodies(dt, child), children))
            case _ => root
        }
}
