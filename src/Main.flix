// Rogue — tile-based roguelike game in Flix

def main(): Unit \ IO =
    println("Rogue");
    discard run { Game.startGame() } with LwjglLayer.withLwjgl;
    println("Game ended.")
