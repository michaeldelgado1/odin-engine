/*
This file is the starting point of your game.

Some important procedures are:
- game_init_window: Opens the window
- game_init: Sets up the game state
- game_update: Run once per frame
- game_should_close: For stopping your game when close button is pressed
- game_shutdown: Shuts down game and frees memory
- game_shutdown_window: Closes window

The procs above are used regardless if you compile using the `build_release`
script or the `build_hot_reload` script. However, in the hot reload case, the
contents of this file is compiled as part of `build/hot_reload/game.dll` (or
.dylib/.so on mac/linux). In the hot reload cases some other procedures are
also used in order to facilitate the hot reload functionality:

- game_memory: Run just before a hot reload. That way game_hot_reload.exe has a
  pointer to the game's memory that it can hand to the new game DLL.
- game_hot_reloaded: Run after a hot reload so that the `g` global
  variable can be set to whatever pointer it was in the old DLL.

NOTE: When compiled as part of `build_release`, `build_debug` or `build_web`
then this whole package is just treated as a normal Odin package. No DLL is
created.
*/

package game

import "core:fmt"
import rl "vendor:raylib"
import vmem "core:mem/virtual"
import "core:encoding/json"
import "core:os"
import "core:strings"
import "ui"
import "rects"

PIXEL_WINDOW_HEIGHT :: 180

MAIN_MONITOR_NUMBER :: 0
SECOND_MONITOR_NUMBER :: 1
DUAL_MONITOR :: true

OverlayType :: enum int {
  None,
  ExitOverlay,
  DebugOverlay,
}

EditorState :: struct {
  expectedHash: string,
  currentOverlay: OverlayType,
}

OverlayHeading :: struct {
  pos: rl.Vector2,
  text: cstring,
  fontSize: i32,
}

OverlayState :: struct {
  heading: OverlayHeading,
}

ButtonId :: enum int {
  None,
  ExitYes,
  ExitNo,
  DebugHandle,
}

Game_Memory :: struct {
  editorState: EditorState,
  exitOverlayState: OverlayState,
  run: bool,
  rects: [dynamic]rl.Rectangle,
  gameArena: vmem.Arena,
  uiCam: rl.Camera2D,
  gameCam: rl.Camera2D,
  screenMouse: rl.Vector2,
  worldMouse: rl.Vector2,
  uiCtx: ui.UiContext,
  drawDebugHud: bool,
}

g: ^Game_Memory

rectDims := rl.Vector2 {
  22, 15,
}


exitOverlayUpdate :: proc() {
  if rl.IsKeyPressed(.E) {
    g.editorState.currentOverlay = .None
  }

  start := ButtonId.ExitYes
  end := int(ButtonId.ExitNo) + 1
  rects.evenSpaceHorizontal(g.uiCtx.button.rectangles[start:end], g.uiCtx.screenDims.x)
}

debugOverlayUpdate :: proc() {
  if rl.IsKeyPressed(.D) {
    g.editorState.currentOverlay = .None
  }
}

noOverlayUpdate :: proc() {
  if rl.IsKeyPressed(.E) {
    g.editorState.currentOverlay = .ExitOverlay
  }

  if rl.IsKeyPressed(.D) {
    g.editorState.currentOverlay = .DebugOverlay
  }

  if rl.IsMouseButtonPressed(.LEFT) {
    addGameRect()
  }

  if rl.IsMouseButtonPressed(.RIGHT) {
    for idx in 0..<len(g.rects) {
      if rl.CheckCollisionPointRec(g.screenMouse, g.rects[idx]) {
        unordered_remove(&g.rects, idx)
        break
      }
    }
  }

  if rl.IsKeyPressed(.S) {
    settingsData, _ := json.marshal(g.rects, allocator = context.temp_allocator)
    if !os.write_entire_file("settings.json", settingsData) {
      fmt.println("Couldn't write file!")
    }
  }

  if rl.IsKeyPressed(.R) {
    allocator := vmem.arena_allocator(&g.gameArena)
    loadSettings(allocator)
  }
}

update :: proc() {
  g.uiCam = ui_camera()
  g.gameCam = game_camera()
  g.worldMouse = rl.GetMousePosition()
  g.screenMouse = rl.GetScreenToWorld2D(g.worldMouse, g.uiCam)
  g.uiCtx.mousePos = g.screenMouse
  g.uiCtx.screenDims = {
    f32(rl.GetScreenWidth())/g.uiCam.zoom,
    f32(rl.GetScreenHeight())/g.uiCam.zoom,
  }

  // TODO: These cursors are weird and don't follow the OS theme on Linux
  // if g.uiState.hotButton != .None || g.uiState.activeButton != .None {
  //   rl.SetMouseCursor(.POINTING_HAND)
  // } else {
  //   rl.SetMouseCursor(.DEFAULT)
  // }

  // NOTE: This is useful to escape out of all overlays, so don't
  //  put this in a particular update function
  if rl.IsKeyPressed(.ESCAPE) {
    if g.editorState.currentOverlay != .None {
      g.editorState.currentOverlay = .None
    } else {
      g.run = false
    }
  }

  switch g.editorState.currentOverlay {
  case .None:
    noOverlayUpdate()
  case .ExitOverlay:
    exitOverlayUpdate()
  case .DebugOverlay:
    debugOverlayUpdate()
  }

  if rl.IsKeyPressed(.C) {
    // Center window on monitor
    // TODO: Doesn't work with multi monitor
    winWidth := rl.GetScreenWidth()
    winHeight := rl.GetScreenHeight()

    monWidth := rl.GetMonitorWidth(MAIN_MONITOR_NUMBER)
    monHeight := rl.GetMonitorHeight(MAIN_MONITOR_NUMBER)

    x := monWidth - winWidth
    y := monHeight - winHeight

    rl.SetWindowPosition((x/2), (y/2))
  }

  if rl.IsKeyPressed(.H) {
    g.drawDebugHud = !g.drawDebugHud
  }
}

draw :: proc() {
  rl.BeginDrawing()
  {
    rl.ClearBackground(rl.DARKGRAY)

    rl.BeginMode2D(g.gameCam)
    {
      for rect in g.rects {
        rl.DrawRectangleRec(rect, rl.GREEN)
      }
    }
    rl.EndMode2D()

    rl.BeginMode2D(g.uiCam)
    {
      switch g.editorState.currentOverlay {
      case .None:
        drawPlacementRect(g.uiCam)
      case .ExitOverlay:
        drawExitOverlay()
      case .DebugOverlay:
        drawDebugOverlay()
      }

      if g.drawDebugHud {
        drawDebugHud()
      }
    }
    rl.EndMode2D()
  }
  rl.EndDrawing()
}

breakTextIntoLines :: proc(text: string, font: rl.Font, fontSize: f32, spacing: f32, maxWidth: f32) -> ([dynamic]string, f32) {
  spaceSize := rl.MeasureTextEx(font, " ", fontSize, spacing)

  words := strings.split(text, " ", context.temp_allocator)
  wordCount := len(words)
  currentLine := make([dynamic]string, 0, wordCount, context.temp_allocator)
  result := make([dynamic]string, 0, wordCount, context.temp_allocator)
  currentLineWidth : f32 = 0
  totalLineHeight : f32 = spaceSize.y
  for word in words {
    wordSize := rl.MeasureTextEx(font, strings.clone_to_cstring(word, context.temp_allocator), fontSize, spacing).x
    // NOTE: spacing * 2 to measure on either side of a space between words
    currentLineWidth += wordSize
    if len(currentLine) > 0 {
      currentLineWidth += spaceSize.x + (spacing * 2)
    }

    if currentLineWidth > maxWidth {
      currentLineWidth = wordSize
      totalLineHeight += spaceSize.y + spacing
      lineString := strings.join(currentLine[:], " ", context.temp_allocator)
      append(&result, lineString)
      remove_range(&currentLine, 0, len(currentLine))
    }

    append(&currentLine, word)
  }

  if currentLineWidth > 0 {
    lastLine := strings.join(currentLine[:], " ", context.temp_allocator)
    append(&result, lastLine)
  }

  return result, totalLineHeight
}

drawWrappedText :: proc(text: string, startingPos: rl.Vector2, maxWidth: f32, font: rl.Font, fontSize: f32, textColor: rl.Color) -> f32 {
  spacing := ui.getFontSpacing(font, fontSize)
  // TODO: Maybe cache cstring
  textDims := rl.MeasureTextEx(font, strings.clone_to_cstring(text, context.temp_allocator), fontSize, spacing)

  if textDims.x < maxWidth {
    rl.DrawTextEx(font, strings.clone_to_cstring(text), startingPos, fontSize, spacing, textColor)
    return textDims.y
  }

  lines, height := breakTextIntoLines(text, font, fontSize, spacing, maxWidth)

  for idx in 0..<len(lines) {
    nextPos : rl.Vector2 = {
      startingPos.x,
      startingPos.y + ((textDims.y + spacing) * f32(idx)),
    }

    line := lines[idx]
    rl.DrawTextEx(font, strings.clone_to_cstring(line, context.temp_allocator), nextPos, fontSize, spacing, textColor)
  }

  return height
}

drawDebugHud :: proc() {
  rl.DrawText(fmt.ctprintf("Overlay State: %v", g.editorState.currentOverlay), 5, 5, 8, rl.WHITE)
  rl.DrawText(fmt.ctprintf("Screen Mouse Pos: %v", g.screenMouse), 5, 15, 8, rl.WHITE)
  rl.DrawText(fmt.ctprintf("World Mouse Pos: %v", g.worldMouse), 5, 25, 8, rl.WHITE)
}

drawPlacementRect :: proc(uiCamera: rl.Camera2D) {
  placementRect := rects.centerRectToPoint(g.screenMouse, rectDims)
  rl.DrawRectangleRec(placementRect, rl.Fade(rl.GREEN, .5))
}

drawExitOverlay :: proc() {
  winWidth := f32(rl.GetScreenWidth())
  winHeight := f32(rl.GetScreenHeight())
  bgColor := rl.Fade(rl.BLUE, .75)
  rl.DrawRectangleRec(rects.rectFromPosAndDims({ 0, 0 }, { winWidth, winHeight }), bgColor)

  rl.DrawText(g.exitOverlayState.heading.text, i32(g.exitOverlayState.heading.pos.x), i32(g.exitOverlayState.heading.pos.y), g.exitOverlayState.heading.fontSize, rl.WHITE)

  if drawButton(ButtonId.ExitYes, "Yes", &g.uiCtx) {
    fmt.println("Yes Was Pressed")
  }

  if drawButton(ButtonId.ExitNo, "No", &g.uiCtx) {
    fmt.println("No Was Pressed")
  }
}

drawDebugOverlay :: proc() {
  // TODO: Probably try using UI screen dims
  winWidth := f32(rl.GetScreenWidth())
  winHeight := f32(rl.GetScreenHeight())
  bgColor := rl.DARKBLUE
  rl.DrawRectangleRec(rects.rectFromPosAndDims({ 0, 0 }, { winWidth, winHeight }), bgColor)

  // pos : rl.Vector2 = { 2, 2 }
  // boundingBox := rects.rectFromPosAndDims(pos, { 220, 0 })
  // testString := "This is a message that fits within a text box"
  // height := drawWrappedText(testString, pos, boundingBox.width, g.uiCtx.font, 13, rl.WHITE)
  // boundingBox.height = height
  // rl.DrawRectangleLinesEx(boundingBox, .5, rl.YELLOW)
  if drawHoldButton(.DebugHandle, "", &g.uiCtx) {
    curY := g.uiCtx.button.rectangles[ButtonId.DebugHandle].y
    g.uiCtx.button.rectangles[ButtonId.DebugHandle] = rects.centerRectToPoint(g.screenMouse, { g.uiCtx.button.rectangles[ButtonId.DebugHandle].width, g.uiCtx.button.rectangles[ButtonId.DebugHandle].height })
    g.uiCtx.button.rectangles[ButtonId.DebugHandle].y = curY
  }
}

MaxRects :: 1024
loadSettings :: proc(allocator := context.allocator) {
  settingsData, _ := os.read_entire_file("settings.json", context.temp_allocator)
  tempArr : []rl.Rectangle
  err := json.unmarshal(settingsData, &tempArr, allocator = context.temp_allocator)
  if err != nil {
    fmt.println(err)
  }


  tempLen := len(tempArr)
  if tempLen > MaxRects {
    fmt.println("Tried to load a file with too many rectangles. Max:", MaxRects, "Recieved:", tempLen)
    return
  }

  rectLen := len(g.rects)
  if rectLen > 1 {
    remove_range(&g.rects, 0, len(g.rects))
  }

  for rect in tempArr {
    append(&g.rects, rect)
  }
}

addGameRect :: proc() {
  rectLen := len(g.rects)
  if rectLen >= MaxRects {
    fmt.println("You have exceeded the max allowed rectangles", MaxRects)
    return
  } else {
    append(&g.rects, rects.centerRectToPoint(g.screenMouse, rectDims))
  }
}

createExitButtonRects :: proc(ctx: ^ui.UiContext, allocator := context.allocator) {
  doublePad : f32 = ctx.button.padding * 2
  buttonY : f32 = g.exitOverlayState.heading.pos.y + 40
  fontSpacing := ui.getFontSpacing(ctx.font, ctx.button.fontSize)

  yesDims := rl.MeasureTextEx(ctx.font, "Yes", ctx.button.fontSize, fontSpacing)
  yesButton : rl.Rectangle = {
    y = buttonY,
    width = yesDims.x + doublePad,
    height = yesDims.y + doublePad,
  }

  noDims := rl.MeasureTextEx(ctx.font, "No", ctx.button.fontSize, fontSpacing)
  noButton : rl.Rectangle = {
    y = buttonY,
    width = noDims.x + doublePad,
    height = noDims.y + doublePad,
  }

  handlePos : rl.Rectangle = {
    g.uiCtx.screenDims.x / 2,
    g.uiCtx.screenDims.y / 2,
    doublePad,
    doublePad * 2,
  }

  ctx.button.rectangles[ButtonId.ExitYes] = yesButton
  ctx.button.rectangles[ButtonId.ExitNo] = noButton
  ctx.button.rectangles[ButtonId.DebugHandle] = handlePos
}

game_camera :: proc() -> rl.Camera2D {
  h := f32(rl.GetScreenHeight())

  return {
    zoom = h/PIXEL_WINDOW_HEIGHT,
  }
}

ui_camera :: proc() -> rl.Camera2D {
  return {
    zoom = f32(rl.GetScreenHeight())/PIXEL_WINDOW_HEIGHT,
  }
}

@(export)
game_init_window :: proc() {
  rl.SetConfigFlags({ .WINDOW_RESIZABLE, .VSYNC_HINT, .WINDOW_TOPMOST })
  rl.InitWindow(854, 480, "Odin + Raylib + Hot Reload template!")

  winWidth := rl.GetScreenWidth()
  monWidth := rl.GetMonitorWidth(MAIN_MONITOR_NUMBER)
  fmt.println("Mon Width: ", monWidth)
  x : i32 = monWidth - winWidth
  y : i32 = 0

  when ODIN_OS == .Windows{
    // NOTE: Windows doesn't take the bar height into consideration...
    y += 50
  }

  when DUAL_MONITOR {
    // NOTE: When setting the window pos, it counts both monitors
    //  I don't really have to do this check, because if there is no
    //  second monitor, the width is 0.
    secondMon := rl.GetMonitorWidth(SECOND_MONITOR_NUMBER)
    fmt.println("Second Mon Width: ", secondMon)
    x += secondMon
  }

  rl.SetWindowPosition(x, y)
  rl.SetTargetFPS(500)
  rl.SetExitKey(nil)
}

@(export)
game_init :: proc() {
  g = new(Game_Memory)

  g^ = Game_Memory {
    run = true,
    editorState = {
      currentOverlay = .None,
    },
    uiCam = ui_camera(),
    exitOverlayState = {
      heading = {
        pos = { 30, 30 },
        text = "Are you sure you want to exit?",
        fontSize = 17,
      },
    },
    uiCtx = {
      font = rl.GetFontDefault(),
      button = {
        fontSize = 12,
        colors = ui.DraculaColors,
        padding = 3,
      },
    },
  }

  g.uiCtx. screenDims = {
    f32(rl.GetScreenWidth())/g.uiCam.zoom,
    f32(rl.GetScreenHeight())/g.uiCam.zoom,
  }

  gameArena : vmem.Arena
  allocator := vmem.arena_allocator(&gameArena)

  g.rects = make([dynamic]rl.Rectangle, 0, 1024, allocator)
  loadSettings(allocator)

  g.uiCtx.button.rectangles = make([]rl.Rectangle, len(ButtonId), allocator) 
  createExitButtonRects(&g.uiCtx, allocator)


  g.gameArena = gameArena
  game_hot_reloaded(g)
}

@(export)
game_update :: proc() {
  update()
  draw()

  // Everything on temp allocator is valid until end-of-frame.
  free_all(context.temp_allocator)
}

@(export)
game_should_run :: proc() -> bool {
  when ODIN_OS != .JS {
    // Never run this proc in browser. It contains a 16 ms sleep on web!
    if rl.WindowShouldClose() {
      return false
    }
  }

  return g.run
}

@(export)
game_shutdown :: proc() {
  free(g)
}

@(export)
game_shutdown_window :: proc() {
  rl.CloseWindow()
}

@(export)
game_memory :: proc() -> rawptr {
  return g
}

@(export)
game_memory_size :: proc() -> int {
  return size_of(Game_Memory)
}

@(export)
game_hot_reloaded :: proc(mem: rawptr) {
  g = (^Game_Memory)(mem)

  // Here you can also set your own global variables. A good idea is to make
  // your global variables into pointers that point to something inside `g`.
}

@(export)
game_force_reload :: proc() -> bool {
  return rl.IsKeyPressed(.F5)
}

@(export)
game_force_restart :: proc() -> bool {
  return rl.IsKeyPressed(.F6)
}

// In a web build, this is called when browser changes size. Remove the
// `rl.SetWindowSize` call if you don't want a resizable game.
game_parent_window_size_changed :: proc(w, h: int) {
  rl.SetWindowSize(i32(w), i32(h))
}
