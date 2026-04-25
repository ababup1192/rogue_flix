// Breakout - Faithful LearnOpenGL Recreation in Flix

def main(): Unit \ IO =
    println("Breakout - LearnOpenGL Recreation");
    discard run {
        run { Game.startGame() } with LwjglLayer.withLwjgl
    } with Math.Random.runWithIO;
    println("Game ended.")
