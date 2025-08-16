package rects

import rl "vendor:raylib"

evenSpaceHorizontal :: proc(rects: []rl.Rectangle, width: f32) {
  totalButtonSizes : f32

  for rect in rects {
    totalButtonSizes += (rect.width)
  }

  leftoverSpace :=  width - totalButtonSizes
  spaceBetween := leftoverSpace / f32(len(rects) + 1)

  for idx in 0..<len(rects) {
    acrossButton : f32
    prevPos : f32
    prevIndex := idx - 1
    if prevIndex >= 0 {
      acrossButton = (rects[prevIndex].width)
      prevPos = rects[prevIndex].x
    }
    rects[idx].x = spaceBetween + prevPos + acrossButton
  }
}

centerRectToPoint :: proc(point: rl.Vector2, rectDims: rl.Vector2) -> rl.Rectangle {
  posOffset := rl.Vector2{
    (rectDims.x / 2),
    (rectDims.y / 2),
  }
  resultPos := rl.Vector2{
    point.x - posOffset.x,
    point.y - posOffset.y,
  }

  return {
    resultPos.x,
    resultPos.y,
    rectDims.x,
    rectDims.y,
  }
}

rectFromPosAndDims :: proc(pos: rl.Vector2, dims: rl.Vector2) -> rl.Rectangle {
  return {
    pos.x,
    pos.y,
    dims.x,
    dims.y,
  }
}

