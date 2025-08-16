package ui

import rl "vendor:raylib"

UiContext :: struct {
  mousePos: rl.Vector2,
  button: Button,
  screenDims : rl.Vector2,
  font: rl.Font,
}

ButtonColors :: struct {
  default: rl.Color,
  hot: rl.Color,
  active: rl.Color,
  text: rl.Color,
}

DraculaColors : ButtonColors : {
  default = { 44, 47, 60, 255 },
  hot = { 53, 56, 72, 255 },
  active = { 84, 86, 105, 255 },
  text = { 248, 248, 242, 255 },
}

Button :: struct {
  colors: ButtonColors,
  padding: f32,
  fontSize: f32,
  hot: int,
  active: int,
  rectangles: []rl.Rectangle,
}

drawButton :: proc (buttonId: int, label: cstring, ctx: ^UiContext) -> bool {
  result : bool
  // TODO: Bug with active and clicking before hovering on button
  if ctx.button.active == buttonId {
    if rl.IsMouseButtonReleased(.LEFT) {
      // TODO: Figure out if I still need this
      if ctx.button.active == buttonId {
        result = true
      }
      ctx.button.active = 0
    }
  } else if ctx.button.hot == buttonId && rl.IsMouseButtonDown(.LEFT) {
    ctx.button.active = buttonId
  }

  buttonRect := ctx.button.rectangles[buttonId]
  if rl.CheckCollisionPointRec(ctx.mousePos, buttonRect) {
    if ctx.button.active == 0 {
      ctx.button.hot = buttonId
    }
  } else if ctx.button.hot == buttonId {
    ctx.button.hot = 0
  }

  color := ctx.button.colors.default
  if ctx.button.active == buttonId {
    color = ctx.button.colors.active
  } else if ctx.button.hot == buttonId {
    color = ctx.button.colors.hot
  }

  rl.DrawRectangleRounded(buttonRect, 0.4, 4, color)
  rl.DrawTextEx(ctx.font, label, { buttonRect.x + ctx.button.padding, buttonRect.y + ctx.button.padding }, f32(ctx.button.fontSize), getFontSpacing(ctx.font, ctx.button.fontSize), ctx.button.colors.text)

  return result
}

drawHoldButton :: proc (buttonId: int, label: cstring, ctx: ^UiContext) -> bool {
  result : bool
  // TODO: Bug with active and clicking before hovering on button
  if ctx.button.active == buttonId {
    result = true
    if rl.IsMouseButtonReleased(.LEFT) {
      ctx.button.active = 0
    }
  } else if ctx.button.hot == buttonId && rl.IsMouseButtonDown(.LEFT) {
    ctx.button.active = buttonId
  }

  buttonRect := ctx.button.rectangles[buttonId]
  if rl.CheckCollisionPointRec(ctx.mousePos, buttonRect) {
    if ctx.button.active == 0 {
      ctx.button.hot = buttonId
    }
  } else if ctx.button.hot == buttonId {
    ctx.button.hot = 0
  }

  color := ctx.button.colors.default
  if ctx.button.active == buttonId {
    color = ctx.button.colors.active
  } else if ctx.button.hot == buttonId {
    color = ctx.button.colors.hot
  }

  rl.DrawRectangleRounded(buttonRect, 0.4, 4, color)
  rl.DrawTextEx(ctx.font, label, { buttonRect.x + ctx.button.padding, buttonRect.y + ctx.button.padding }, f32(ctx.button.fontSize), getFontSpacing(ctx.font, ctx.button.fontSize), ctx.button.colors.text)

  return result
}

// NOTE: This comes from raylib: https://github.com/raysan5/raylib/blob/d1b535c7b8c31ca29fa1c5872f79ec7ea153cd2f/src/rtext.c#L1160
DefaultFontSize :: 10
getFontSpacing :: proc(font: rl.Font, fontSize: f32) -> f32 {
  baselineSize := fontSize
  if fontSize < DefaultFontSize {
    baselineSize = DefaultFontSize
  }

  return baselineSize/DefaultFontSize
}

