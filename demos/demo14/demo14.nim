import
  nimgame2/nimgame,
  nimgame2/settings,
  mainscene

game = newGame()
if game.init(w = 640, h = 480, title = "Nimgame 2: Demo 14 (TileMap 2)"):
  showInfo = true
  game.scene = newMainScene()
  game.run()

