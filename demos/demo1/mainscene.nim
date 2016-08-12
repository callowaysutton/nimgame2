import
  sdl2/sdl_gfx_primitives as gfx,
  sdl2/sdl_gfx_primitives_font as gfx_font,
  nimgame2/nimgame,
  nimgame2/entity,
  nimgame2/graphic,
  nimgame2/scene,
  nimgame2/types,
  spaceman


const
  CountMin = 100
  CountMax = 50_000
  CountStep = 100
  CountStart = 500


type
  MainScene = ref object of Scene
    spacemanG: Graphic
    spacemanP: SpacemanPhysics
    spacemanCenter: Coord
    count: int

  SpacemanPhysics = ref object of Physics


method update*(physics: SpacemanPhysics, entity: Spaceman, elapsed: float) =
  physics.updatePhysics(entity, elapsed)

  # Screen collision
  if entity.pos.x < -MainScene(entity.scene).spacemanCenter.x:
    entity.vel.x *= -1
  if entity.pos.y < -MainScene(entity.scene).spacemanCenter.y:
    entity.vel.y *= -1
  if entity.pos.x >= game.size.w.float +
                     MainScene(entity.scene).spacemanCenter.x:
    entity.vel.x *= -1
  if entity.pos.y >= game.size.h.float +
                     MainScene(entity.scene).spacemanCenter.y:
    entity.vel.y *= -1


proc init*(scene: MainScene) =
  Scene(scene).init()
  scene.spacemanG = newGraphic()
  discard scene.spacemanG.load(game.renderer, "../assets/gfx/spaceman.png")
  scene.spacemanCenter.x = scene.spacemanG.w / 2
  scene.spacemanCenter.y = scene.spacemanG.h / 2
  scene.spacemanP = new SpacemanPhysics
  scene.count = CountStart
  for i in 1..scene.count:
    scene.list.add(newSpaceman(scene, scene.spacemanG, scene.spacemanP))


proc free*(scene: MainScene) =
  scene.spacemanG.free


proc newMainScene*(): MainScene =
  new result, free
  result.init()


method event*(scene: MainScene, event: Event) =
  if event.kind == KeyDown:
    case event.key.keysym.sym:
    of K_Escape:
      game.running = false
    of K_Up:
      if scene.count < CountMax:
        scene.count += CountStep
        for i in scene.list.len..scene.count-1:
          scene.list.add(newSpaceman(scene, scene.spacemanG, scene.spacemanP))
    of K_Down:
      if scene.count > CountMin:
        scene.count -= CountStep
        for i in scene.count..scene.list.high:
          discard scene.list.pop()
    else: discard


method render*(scene: MainScene, renderer: Renderer) =
  scene.renderScene(renderer)
  discard renderer.boxColor(
    x1 = 4, y1 = 60,
    x2 = 260, y2 = 84,
    0xCC000000'u32)
  discard renderer.stringColor(
    x = 8, y = 64, "Arrow Up - more entities", 0xFF0000FF'u32)
  discard renderer.stringColor(
    x = 8, y = 72, "Arrow Down - less entities", 0xFF0000FF'u32)


method update*(scene: MainScene, elapsed: float) =
  scene.updateScene(elapsed)
