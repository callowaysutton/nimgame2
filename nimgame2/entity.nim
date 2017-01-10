# nimgame2/entity.nim
# Copyright (c) 2016-2017 Vladar
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# Vladar vladar4@gmail.com


import
  sdl2/sdl,
  graphic, types, utils

type
  Animation = object
    frames*: seq[int] ##  list of animation's frame indexes
    frameRate*: float ##  frame rate in frames per second
    flip*: Flip       ##  flip flag


  Sprite = ref object
    animationKeys*: seq[string] ##  list of animation names
    animations*: seq[Animation] ##  list of animations
    currentAnimation*: int      ##  index of currently playing animation
    currentFrame*: int          ##  incex of current frame
    cycles*: int                ##  animation cycles counter (`-1` for looping)
    time*: float                ##  animation timer
    playing*: bool              ##  animation playing flag
    frameSize*: Dim             ##  sprite frame dimensions
    offset*: Dim                ##  sprite graphic offset
    frames*: seq[Rect]          ##  frames' coordinates


  Collider* = ref object of RootObj
    parent*: Entity
    pos*: Coord

  BoxCollider* = ref object of Collider
    dim*: Dim

  CircleCollider* = ref object of Collider
    radius*: float

  LineCollider* = ref object of Collider
    pos2*: Coord

  PolyCollider* = ref object of Collider
    points*: seq[Coord]


  Entity* = ref object of RootObj
    parent*: Entity
    tags*: seq[string]            ##  list of entity tags
    dead*: bool                   ##  `true` if marked for removal
    graphic*: Graphic
    sprite*: Sprite
    logic*: Logic
    physics*: Physics
    collider*: Collider
    colliding*: seq[Entity]       ##  list of Entities currently colliding with
    pos*, vel*, acc*, drg*: Coord ##  position, velocity, acceleration, drag
    rot*: Angle                   ##  rotation angle in degrees
    rotVel*, rotAcc*, rotDrg*: Angle  ##  rotation velocity, acceleration, drag
    scale*: Scale                 ##  scale ratio
    center*: Coord                ##  center for drawing and rotating
    flip*: Flip                   ##  texture flip status

  Logic* = ref object of RootObj

  Physics* = ref object of RootObj


##########
# Sprite #
##########

proc initSprite*(entity: Entity,
                 frameSize: Dim,
                 offset: Dim = (0, 0)) =
  ##  Creeate a sprite for a given ``entity`` with attached Graphic.
  ##
  ##  ``frameSize`` Dimensions of one frame.
  ##
  ##  ``offset``  Offset from the edge of the texture.
  ##
  entity.sprite = new Sprite
  entity.sprite.animationKeys = @[]
  entity.sprite.animations = @[]
  entity.sprite.currentAnimation = -1
  entity.sprite.currentFrame = 0
  entity.sprite.cycles = 0
  entity.sprite.time = 0
  entity.sprite.playing = false
  entity.sprite.frameSize = frameSize
  entity.sprite.offset = offset
  entity.sprite.frames = @[]

  let
    cols = (entity.graphic.w - entity.sprite.offset.w) div
            entity.sprite.frameSize.w
    rows = (entity.graphic.h - entity.sprite.offset.h) div
            entity.sprite.frameSize.h

  for r in 0..(rows - 1):
    for c in 0..(cols - 1):
      entity.sprite.frames.add(Rect(
        x: entity.sprite.offset.w + entity.sprite.frameSize.w * c,
        y: entity.sprite.offset.h + entity.sprite.frameSize.h * r,
        w: entity.sprite.frameSize.w,
        h: entity.sprite.frameSize.h))


proc animationIndex*(entity: Entity, name: string): int {.inline.} =
  ##  ``Return`` index of the animation named ``name``.
  ##
  if entity.sprite == nil:
    return -1
  entity.sprite.animationKeys.find(name)


proc animation*(entity: Entity, name: string): var Animation =
  ##  ``Return`` animation named ``name``.
  ##
  let index = entity.animationIndex(name)
  if index < 0:
    return
  entity.sprite.animations[index]


proc animation*(entity: Entity, index: int): var Animation =
  ##  ``Return`` animation under given ``index``.
  ##
  if index < 0 or index >= entity.sprite.animations.len:
    return
  entity.sprite.animations[index]


template currentAnimation*(entity: Entity): var Animation =
  ##  ``Return`` current animation.
  ##
  entity.animation(entity.sprite.currentAnimation)


proc currentAnimationName*(entity: Entity): string =
  ##  ``Return`` name of the current animation.
  ##
  if entity.sprite.currentAnimation < 0:
    return ""
  return entity.sprite.animationKeys[entity.sprite.currentAnimation]


proc addAnimation*(entity: Entity,
                   name: string,
                   frames: openarray[int],
                   frameRate: float = 0.1,
                   flip: Flip = Flip.none): bool =
  ##  Add animation to the ``entity``.
  ##
  ##  ``name`` Name of the animation.
  ##
  ##  ``frames`` Array of animation frames' indexes.
  ##
  ##  ``frameRate`` Animation speed in frames per second.
  ##
  ##  ``flip``  Animation flip flag.
  ##
  result = true

  if entity.sprite == nil:
    return false

  if frames.len < 1:
    return false

  if entity.animationIndex(name) >= 0:
    return false

  for frame in frames:
    if frame < 0 or frame >= entity.sprite.frames.len:
      return false

  entity.sprite.animationKeys.add(name)
  entity.sprite.animations.add(Animation(
    frames: @frames, frameRate: frameRate, flip: flip))



proc play*(entity: Entity, anim: string, cycles = -1) =
  ##  Start playing the animation.
  ##
  ##  ``anim`` Name of the animation.
  ##
  ##  ``cycles`` Number of times to repeat the animation cycles.
  ##  `-1` for looping.
  ##
  if entity.sprite == nil:
    return
  if entity.animationIndex(anim) < 0:
    return
  entity.sprite.currentAnimation = entity.animationIndex(anim)
  entity.sprite.cycles = cycles
  entity.sprite.time = 0.0
  if cycles != 0:
    entity.sprite.playing = true


method update*(sprite: Sprite, entity: Entity, elapsed: float) {.base.} =
  if entity.sprite == nil:
    return
  if (entity.sprite.currentAnimation < 0) or (not entity.sprite.playing):
    return
  let frameRate = entity.currentAnimation.frameRate
  entity.sprite.time += elapsed
  while entity.sprite.time >= frameRate:
    entity.sprite.time -= frameRate
    inc entity.sprite.currentFrame  # next frame
    if entity.sprite.currentFrame >= entity.currentAnimation.frames.len:
      # Animation has ended
      if entity.sprite.cycles > 0:
        # Reduce cycles counter
        dec entity.sprite.cycles
        if entity.sprite.cycles == 0:
          # No more cycles left
          entity.sprite.playing = false
      # cycles <= 0 - animation either stopped or looped
      # Set current frame to first one of the current animation
      entity.sprite.currentFrame = 0


#########
# Logic #
#########

method update*(logic: Logic, entity: Entity, elapsed: float) {.base.} =
  discard


###########
# Physics #
###########


proc updatePhysics*(physics: Physics, entity: Entity, elapsed: float) =
  ##  Default physics procedure. Disabled by default.
  ##
  ##  Call it from your entity physics update method.
  ##

  # acceleration -> velocity
  entity.vel.x += entity.acc.x * elapsed
  entity.vel.y += entity.acc.y * elapsed

  # drag -> velocity
  let absx = entity.vel.x.abs
  if absx > 0.0:
    var dx = entity.drg.x * elapsed
    if dx > absx:
      entity.vel.x = 0.0
    else:
      entity.vel.x += (if entity.vel.x > 0.0: -dx else: dx)

  let absy = entity.vel.y.abs
  if absy > 0.0:
    var dy = entity.drg.y * elapsed
    if dy > absy:
      entity.vel.y = 0.0
    else:
      entity.vel.y += (if entity.vel.y > 0.0: -dy else: dy)

  # velocity -> position
  entity.pos = entity.pos + entity.vel * elapsed

  # rotation acceleration -> rotation velocity
  entity.rotVel += entity.rotAcc * elapsed

  # rotation drag -> rotation velocity
  let absr = entity.rotVel.abs
  if absr > 0.0:
    var dr = entity.rotDrg * elapsed
    if dr > absr:
      entity.rotVel = 0.0
    else:
      entity.rotVel += (if entity.rotVel > 0.0: -dr else: dr)

  # rotatiton velocity -> rotation
  entity.rot += entity.rotVel * elapsed


method update*(physics: Physics, entity: Entity, elapsed: float) {.base.} =
  discard


##########
# Entity #
##########


proc initEntity*(entity: Entity) =
  ##  Default entity initialization procedure.
  ##
  ##  Call it after creating a new entity.
  ##
  entity.parent = nil
  entity.tags = @[]
  entity.dead = false
  entity.graphic = nil
  entity.sprite = nil
  entity.logic = nil
  entity.physics = nil
  entity.collider = nil
  entity.colliding = @[]
  entity.pos = (0.0, 0.0)
  entity.vel = (0.0, 0.0)
  entity.acc = (0.0, 0.0)
  entity.drg = (0.0, 0.0)
  entity.rot = 0.0
  entity.rotVel = 0.0
  entity.rotAcc = 0.0
  entity.rotDrg = 0.0
  entity.scale = 1.0
  entity.center = (0.0, 0.0)
  entity.flip = Flip.none


proc newEntity*(): Entity =
  result = new Entity
  result.initEntity()


proc absRot*(entity: Entity): Angle =
  if entity.parent == nil:
    return entity.rot
  else:
    return entity.parent.absRot + entity.rot


proc absScale*(entity: Entity): Scale =
  if entity.parent == nil:
    return entity.scale
  else:
    return entity.parent.absScale * entity.scale


proc absPos*(entity: Entity): Coord =
  if entity.parent == nil:
    return entity.pos
  else:
    if entity.parent.absRot == 0:
      return entity.parent.absPos + entity.pos * entity.absScale
    else:
      return rotate(entity.pos * entity.absScale,
                    entity.parent.absPos,
                    entity.absRot)


proc centrify*(entity: Entity) =
  ##  Set ``center`` to the graphic's central point.
  ##
  if entity.graphic != nil:
    entity.center = entity.graphic.dim / 2


proc renderEntity*(entity: Entity) =
  ##  Default entity render procedure.
  ##
  ##  Call it from your entity render method.
  ##
  if not (entity.graphic == nil):
    if entity.sprite == nil:
      entity.graphic.draw(entity.absPos,
                          entity.absRot,
                          entity.absScale,
                          entity.center,
                          entity.flip)
    else: # entity.sprite != nil
      if entity.sprite.currentAnimation < 0:
        entity.graphic.draw(entity.absPos,
                            entity.absRot,
                            entity.absScale,
                            entity.center,
                            entity.flip,
                            entity.sprite.frames[entity.sprite.currentFrame])
      else:
        let anim = entity.currentAnimation
        entity.graphic.draw(entity.absPos,
                            entity.absRot,
                            entity.absScale,
                            entity.center,
                            Flip(entity.flip.cint xor anim.flip.cint),
                            entity.sprite.frames[
                              anim.frames[entity.sprite.currentFrame]])


method render*(entity: Entity) {.base.} =
  entity.renderEntity()


proc updateEntity*(entity: Entity, elapsed: float) =
  ##  Default entity update procedure.
  ##
  ##  Call it from your entity update method.
  ##
  if not(entity.sprite == nil):
    entity.sprite.update(entity, elapsed)
  if not(entity.logic == nil):
    entity.logic.update(entity, elapsed)
  if not(entity.physics == nil):
    entity.physics.update(entity, elapsed)


method update*(entity: Entity, elapsed: float) {.base.} =
  entity.updateEntity(elapsed)


method onCollide*(entity, target: Entity) {.base.} =
  ##  Called when ``entity`` collides with ``target``.
  ##
  discard
