// NOTE: This is annoying...
//  Odin allows you to use enums as an array index, but for some reason you can't pass one in as
//  an int... I've defined ButtonId as an int using ButtonId :: enum int
//  Why can't I do this??? Now I have to wrap all of these functions so I don't have to cast
//  the ID every time I want to draw a button!!!
package game

import "ui"

drawButton :: proc(buttonId: ButtonId, label: cstring, ctx: ^ui.UiContext) -> bool {
  return ui.drawButton(int(buttonId), label, ctx)
}

drawHoldButton :: proc(buttonId: ButtonId, label: cstring, ctx: ^ui.UiContext) -> bool {
  return ui.drawHoldButton(int(buttonId), label, ctx)
}

