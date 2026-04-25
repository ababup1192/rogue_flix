// LWJGL rendering backend — handles Game.Game effect with OpenGL

mod LwjglLayer {
    import org.lwjgl.glfw.GLFW
    import org.lwjgl.glfw.Callbacks
    import org.lwjgl.glfw.GLFWKeyCallbackI
    import org.lwjgl.opengl.GL
    import org.lwjgl.opengl.GL11
    import org.lwjgl.opengl.GL13
    import org.lwjgl.opengl.GL15
    import org.lwjgl.opengl.GL20
    import org.lwjgl.opengl.GL30
    import org.lwjgl.stb.STBImage
    import org.lwjgl.system.MemoryStack
    import org.lwjgl.system.MemoryUtil
    import java.lang.Runtime
    import java.lang.Thread

    import java.lang.System

    // ============================================================================
    // Shader Sources (LearnOpenGL sprite shader)
    // ============================================================================

    def vertexShaderSource(): String =
        "#version 330 core\n" +
        "layout (location = 0) in vec4 vertex;\n" +
        "out vec2 TexCoords;\n" +
        "uniform mat4 model;\n" +
        "uniform mat4 projection;\n" +
        "void main() {\n" +
        "    TexCoords = vertex.zw;\n" +
        "    gl_Position = projection * model * vec4(vertex.xy, 0.0, 1.0);\n" +
        "}\n"

    def fragmentShaderSource(): String =
        "#version 330 core\n" +
        "in vec2 TexCoords;\n" +
        "out vec4 color;\n" +
        "uniform sampler2D image;\n" +
        "uniform vec3 spriteColor;\n" +
        "void main() {\n" +
        "    color = vec4(spriteColor, 1.0) * texture(image, TexCoords);\n" +
        "}\n"

    // ============================================================================
    // Shader Compilation
    // ============================================================================

    def compileShader(source: String, shaderType: Int32): Int32 \ IO =
        let shader = GL20.glCreateShader(shaderType);
        GL20.glShaderSource(shader, source);
        GL20.glCompileShader(shader);

        let success = GL20.glGetShaderi(shader, GL20.GL_COMPILE_STATUS);
        if (success == GL11.GL_FALSE) {
            let log = GL20.glGetShaderInfoLog(shader, 1024);
            println("Shader compilation error: ${log}");
            bug!("Shader failed")
        } else ();

        shader

    def createShaderProgram(vertexSrc: String, fragmentSrc: String): Int32 \ IO =
        let vs = compileShader(vertexSrc, GL20.GL_VERTEX_SHADER);
        let fs = compileShader(fragmentSrc, GL20.GL_FRAGMENT_SHADER);

        let program = GL20.glCreateProgram();
        GL20.glAttachShader(program, vs);
        GL20.glAttachShader(program, fs);
        GL20.glLinkProgram(program);

        let success = GL20.glGetProgrami(program, GL20.GL_LINK_STATUS);
        if (success == GL11.GL_FALSE) {
            let log = GL20.glGetProgramInfoLog(program, 1024);
            println("Shader linking error: ${log}");
            bug!("Linking failed")
        } else ();

        GL20.glDeleteShader(vs);
        GL20.glDeleteShader(fs);
        program

    // ============================================================================
    // Texture Loading
    // ============================================================================

    def loadTexture(path: String, alpha: Bool): Int32 \ IO =
        let stack = MemoryStack.stackPush();
        let w = stack.mallocInt(1);
        let h = stack.mallocInt(1);
        let c = stack.mallocInt(1);
        STBImage.stbi_set_flip_vertically_on_load(true);
        let channels = if (alpha) 4 else 3;
        let data = STBImage.stbi_load(path, w, h, c, channels);
        if (Object.isNull(data)) {
            discard MemoryStack.stackPop();
            bug!("Failed to load texture: ${path}")
        } else {
            let textureID = GL11.glGenTextures();
            GL11.glBindTexture(GL11.GL_TEXTURE_2D, textureID);
            let format = if (alpha) GL11.GL_RGBA else GL11.GL_RGB;
            GL11.glTexImage2D(GL11.GL_TEXTURE_2D, 0, format, w.get(0), h.get(0), 0, format, GL11.GL_UNSIGNED_BYTE, data);
            GL11.glTexParameteri(GL11.GL_TEXTURE_2D, GL11.GL_TEXTURE_WRAP_S, GL11.GL_REPEAT);
            GL11.glTexParameteri(GL11.GL_TEXTURE_2D, GL11.GL_TEXTURE_WRAP_T, GL11.GL_REPEAT);
            GL11.glTexParameteri(GL11.GL_TEXTURE_2D, GL11.GL_TEXTURE_MIN_FILTER, GL11.GL_LINEAR);
            GL11.glTexParameteri(GL11.GL_TEXTURE_2D, GL11.GL_TEXTURE_MAG_FILTER, GL11.GL_LINEAR);
            STBImage.stbi_image_free(data);
            discard MemoryStack.stackPop();
            textureID
        }

    /// Load all textures from manifest into a registry (Map-based, data-driven)
    def loadTextureRegistry(manifest: List[(String, String, Bool)]): Game.TextureRegistry \ IO =
        List.foldLeft((registry, entry) -> {
            let (name, path, alpha) = entry;
            let texId = loadTexture(path, alpha);
            println("  ${path} loaded");
            Map.insert(name, texId, registry)
        }, Map.empty(), manifest)

    // ============================================================================
    // Sprite Renderer
    // ============================================================================

    def initSpriteRenderer(): (Int32, Int32) \ IO =
        let vao = GL30.glGenVertexArrays();
        let vbo = GL15.glGenBuffers();

        let vertices = Array#{
            0.0f32, 1.0f32, 0.0f32, 1.0f32,
            1.0f32, 0.0f32, 1.0f32, 0.0f32,
            0.0f32, 0.0f32, 0.0f32, 0.0f32,
            0.0f32, 1.0f32, 0.0f32, 1.0f32,
            1.0f32, 1.0f32, 1.0f32, 1.0f32,
            1.0f32, 0.0f32, 1.0f32, 0.0f32
        } @ Static;

        GL30.glBindVertexArray(vao);
        GL15.glBindBuffer(GL15.GL_ARRAY_BUFFER, vbo);
        GL15.glBufferData(GL15.GL_ARRAY_BUFFER, vertices, GL15.GL_STATIC_DRAW);

        GL20.glEnableVertexAttribArray(0);
        GL20.glVertexAttribPointer(0, 4, GL11.GL_FLOAT, false, 16, 0i64);

        GL15.glBindBuffer(GL15.GL_ARRAY_BUFFER, 0);
        GL30.glBindVertexArray(0);

        (vao, vbo)

    def setProjectionMatrix(shader: Int32, width: Float32, height: Float32): Unit \ IO =
        GL20.glUseProgram(shader);

        let left = 0.0f32;
        let right = width;
        let bottom = height;
        let top = 0.0f32;

        let proj = Array#{
            2.0f32 / (right - left), 0.0f32, 0.0f32, 0.0f32,
            0.0f32, 2.0f32 / (top - bottom), 0.0f32, 0.0f32,
            0.0f32, 0.0f32, -1.0f32, 0.0f32,
            -1.0f32 * (right + left) / (right - left), -1.0f32 * (top + bottom) / (top - bottom), 0.0f32, 1.0f32
        } @ Static;

        let loc = GL20.glGetUniformLocation(shader, "projection");
        GL20.glUniformMatrix4fv(loc, false, proj)

    def drawSprite(shader: Int32, texture: Int32, vao: Int32, pos: Vec2D.Vec2, size: Vec2D.Vec2, color: Game.Vec3): Unit \ IO =
        GL20.glUseProgram(shader);

        let model = Array#{
            size#x, 0.0f32, 0.0f32, 0.0f32,
            0.0f32, size#y, 0.0f32, 0.0f32,
            0.0f32, 0.0f32, 1.0f32, 0.0f32,
            pos#x, pos#y, 0.0f32, 1.0f32
        } @ Static;

        let modelLoc = GL20.glGetUniformLocation(shader, "model");
        GL20.glUniformMatrix4fv(modelLoc, false, model);

        let colorLoc = GL20.glGetUniformLocation(shader, "spriteColor");
        GL20.glUniform3f(colorLoc, color#r, color#g, color#b);

        GL13.glActiveTexture(GL13.GL_TEXTURE0);
        GL11.glBindTexture(GL11.GL_TEXTURE_2D, texture);

        GL30.glBindVertexArray(vao);
        GL11.glDrawArrays(GL11.GL_TRIANGLES, 0, 6);
        GL30.glBindVertexArray(0)

    // ============================================================================
    // Rendering (SceneTree-based, generic — no changes needed for new entities)
    // ============================================================================

    def renderScene(scene: SceneTree.Node, registry: Game.TextureRegistry, shader: Int32, vao: Int32): Unit \ IO =
        GL11.glClearColor(0.0f32, 0.0f32, 0.0f32, 1.0f32);
        GL11.glClear(GL11.GL_COLOR_BUFFER_BIT);

        let drawables = SceneTree.collectDrawables(scene, Vec2D.zero());
        List.forEach(match (spriteData, globalPos) -> {
            match Map.get(spriteData#texture, registry) {
                case Some(texId) => drawSprite(shader, texId, vao, globalPos, spriteData#size, spriteData#color)
                case None => ()
            }
        }, drawables)

    // ============================================================================
    // LWJGL Handler for Game.Game effect
    // ============================================================================

    pub def withLwjgl(f: Unit -> a \ ef): a \ ef - Game.Game + IO =
        if (not GLFW.glfwInit()) {
            println("GLFW init failed");
            bug!("GLFW failed")
        } else ();

        // OpenGL 3.3 Core (LearnOpenGL standard)
        GLFW.glfwWindowHint(GLFW.GLFW_CONTEXT_VERSION_MAJOR, 3);
        GLFW.glfwWindowHint(GLFW.GLFW_CONTEXT_VERSION_MINOR, 3);
        GLFW.glfwWindowHint(GLFW.GLFW_OPENGL_PROFILE, GLFW.GLFW_OPENGL_CORE_PROFILE);
        GLFW.glfwWindowHint(GLFW.GLFW_OPENGL_FORWARD_COMPAT, GL11.GL_TRUE);
        GLFW.glfwWindowHint(GLFW.GLFW_RESIZABLE, GL11.GL_FALSE);

        let window = GLFW.glfwCreateWindow(Game.screenWidth(), Game.screenHeight(), "Breakout", MemoryUtil.NULL, MemoryUtil.NULL);
        GLFW.glfwMakeContextCurrent(window);
        GLFW.glfwSwapInterval(1);
        discard GL.createCapabilities();

        // Retina display support (macOS typically uses 2x scale)
        let retinaScale = 2;
        let fbWidth = Game.screenWidth() * retinaScale;
        let fbHeight = Game.screenHeight() * retinaScale;
        println("Using ${retinaScale}x scale for Retina display: ${fbWidth}x${fbHeight}");

        GL11.glViewport(0, 0, fbWidth, fbHeight);
        GL11.glEnable(GL11.GL_BLEND);
        GL11.glBlendFunc(GL11.GL_SRC_ALPHA, GL11.GL_ONE_MINUS_SRC_ALPHA);

        let shader = createShaderProgram(vertexShaderSource(), fragmentShaderSource());
        setProjectionMatrix(shader, Int32.toFloat32(Game.screenWidth()), Int32.toFloat32(Game.screenHeight()));

        let (vao, _vbo) = initSpriteRenderer();

        println("Loading textures...");
        let registry = loadTextureRegistry(Game.textureManifest());

        println("Loading levels...");

        let timeHolder = Array#{System.nanoTime()} @ Static;

        let result = run { f() } with handler Game.Game {
            def getInitialState(_, k) = {
                let state = run {
                    Game.initGame(Game.screenWidth(), Game.screenHeight())
                } with Fs.FileRead.runWithIO;
                println("Game ready! Press ESC or close window to exit.");
                k(state)
            }
            def render(scene, k) = {
                renderScene(scene, registry, shader, vao);
                GLFW.glfwSwapBuffers(window);
                k(())
            }
            def shouldClose(_, k) = {
                GLFW.glfwPollEvents();
                let escPressed = GLFW.glfwGetKey(window, 256) == 1;
                let windowClosing = GLFW.glfwWindowShouldClose(window);
                if (escPressed or windowClosing) {
                    println("Closing game...");
                    k(true)
                } else {
                    k(false)
                }
            }
            def getDeltaTime(_, k) = {
                let currentTime = System.nanoTime();
                let prev = Array.get(0, timeHolder);
                Array.put(currentTime, 0, timeHolder);
                let dtNanos = currentTime - prev;
                let dtf = Int64.toFloat32(dtNanos) / 1000000000.0f32;
                k(dtf)
            }
            def isKeyPressed(keyCode, k) = {
                k(GLFW.glfwGetKey(window, keyCode) == 1)
            }
        };

        Callbacks.glfwFreeCallbacks(window);
        GLFW.glfwDestroyWindow(window);
        GLFW.glfwTerminate();

        result
}
