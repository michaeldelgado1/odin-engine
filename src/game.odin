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

PIXEL_WINDOW_HEIGHT :: 180

MAIN_MONITOR_NUMBER :: 0
SECOND_MONITOR_NUMBER :: 1
DUAL_MONITOR :: true

OverlayType :: enum int {
  NoOverlay,
  ExitOverlay,
  // OverlayCount?
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

Buttons :: enum int {
  None,
  ExitYes,
  ExitNo,
}

// Button [ colors, fontSize, hot, active ]
UiCtx :: struct {
  mousePos: rl.Vector2,
  buttonPositions: []rl.Rectangle,
  hotButton: Buttons,
  activeButton: Buttons,
  buttonFontSize: f32,
  buttonColors : ButtonColors,
  screenDims : rl.Vector2,
  font: rl.Font,
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
  uiState: UiCtx,
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

g: ^Game_Memory

rectDims := rl.Vector2 {
  22, 15,
}



exitOverlayUpdate :: proc() {
  if rl.IsKeyPressed(.E) {
    g.editorState.currentOverlay = .NoOverlay
  }

  if rl.IsMouseButtonPressed(.RIGHT) {
    fmt.println("Right Clicked in exit mode")
  }

  evenSpaceHorizontal(g.uiState.buttonPositions[1:], g.uiState.screenDims.x)
}

noOverlayUpdate :: proc() {
  if rl.IsKeyPressed(.E) {
    g.editorState.currentOverlay = .ExitOverlay
  }

  if rl.IsMouseButtonPressed(.LEFT) {
      append(&g.rects, centerRectToPoint(g.screenMouse, rectDims))
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

  if rl.IsKeyPressed(.C) {
    // Center window on monitor
    winWidth := rl.GetScreenWidth()
    winHeight := rl.GetScreenHeight()

    monWidth := rl.GetMonitorWidth(MAIN_MONITOR_NUMBER)
    monHeight := rl.GetMonitorHeight(MAIN_MONITOR_NUMBER)

    x := monWidth - winWidth
    y := monHeight - winHeight

    rl.SetWindowPosition((x/2), (y/2))
  }
}

update :: proc() {
  g.uiCam = ui_camera()
  g.gameCam = game_camera()
  g.worldMouse = rl.GetMousePosition()
  g.screenMouse = rl.GetScreenToWorld2D(g.worldMouse, g.uiCam)
  g.uiState.mousePos = g.screenMouse
  g.uiState.screenDims = {
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
    if g.editorState.currentOverlay != .NoOverlay {
      g.editorState.currentOverlay = .NoOverlay
    } else {
      g.run = false
    }
  }

  switch g.editorState.currentOverlay {
  case .NoOverlay:
    noOverlayUpdate()
  case .ExitOverlay:
    exitOverlayUpdate()
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
      case .NoOverlay:
        drawPlacementRect(g.uiCam)
      case .ExitOverlay:
        drawExitOverlay()
      }

      drawDebugHud()
    }
    rl.EndMode2D()
  }
  rl.EndDrawing()
}

drawDebugHud :: proc() {
  rl.DrawText(fmt.ctprintf("Overlay State: %v", g.editorState.currentOverlay), 5, 5, 8, rl.WHITE)
}

drawPlacementRect :: proc(uiCamera: rl.Camera2D) {
  placementRect := centerRectToPoint(g.screenMouse, rectDims)
  rl.DrawRectangleRec(placementRect, rl.Fade(rl.GREEN, .5))
}

drawExitOverlay :: proc() {
  winWidth := f32(rl.GetScreenWidth())
  winHeight := f32(rl.GetScreenHeight())
  bgColor := rl.Fade(rl.BLUE, .75)
  rl.DrawRectangleRec(rectFromPosAndDims({ 0, 0 }, { winWidth, winHeight }), bgColor)

  rl.DrawText(g.exitOverlayState.heading.text, i32(g.exitOverlayState.heading.pos.x), i32(g.exitOverlayState.heading.pos.y), g.exitOverlayState.heading.fontSize, rl.WHITE)

  if drawButton(.ExitYes, "Yes", &g.uiState) {
    fmt.println("Yes Was Pressed")
  }

  if drawButton(.ExitNo, "No", &g.uiState) {
    fmt.println("No Was Pressed")
  }
}

drawButton :: proc (buttonId: Buttons, label: cstring, ctx: ^UiCtx) -> bool {
  result : bool
  // TODO: Bug with active and clicking before hovering on button
  if ctx.activeButton == buttonId {
    if rl.IsMouseButtonReleased(.LEFT) {
      if ctx.hotButton == buttonId {
        result = true
      }
      ctx.activeButton = .None
    }
  } else if ctx.hotButton == buttonId && rl.IsMouseButtonDown(.LEFT) {
    ctx.activeButton = buttonId
  }

  buttonRect := ctx.buttonPositions[buttonId]
  // TODO: Maybe don't assume we have this global context?
  if rl.CheckCollisionPointRec(ctx.mousePos, buttonRect) {
    if ctx.activeButton == .None {
      ctx.hotButton = buttonId
    }
  } else if ctx.hotButton == buttonId {
    ctx.hotButton = .None
  }

  color := ctx.buttonColors.default
  if ctx.activeButton == buttonId {
    color = ctx.buttonColors.active
  } else if ctx.hotButton == buttonId {
    color = ctx.buttonColors.hot
  }

  rl.DrawRectangleRec(buttonRect, color)
  rl.DrawTextEx(ctx.font, label, { buttonRect.x + ButtonPadding, buttonRect.y + ButtonPadding }, f32(ctx.buttonFontSize), getFontSpacing(ctx.font, ctx.buttonFontSize), ctx.buttonColors.text)

  return result
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

loadSettings :: proc(allocator := context.allocator) {
  settingsData, _ := os.read_entire_file("settings.json", context.temp_allocator)
  tempArr : []rl.Rectangle
  err := json.unmarshal(settingsData, &tempArr, allocator = context.temp_allocator)
  if err != nil {
    fmt.println(err)
  }

  g.rects = make([dynamic]rl.Rectangle, 0, allocator)
  for rect in tempArr {
    append(&g.rects, rect)
  }
}

ButtonPadding :: 5
createExitButtonRects :: proc(ctx: ^UiCtx, allocator := context.allocator) {
  doublePad : f32 = ButtonPadding * 2
  buttonY : f32 = g.exitOverlayState.heading.pos.y + 40
  fontSpacing := getFontSpacing(ctx.font, ctx.buttonFontSize)

  yesDims := rl.MeasureTextEx(ctx.font, "Yes", ctx.buttonFontSize, fontSpacing)
  yesButton : rl.Rectangle = {
    y = buttonY,
    width = yesDims.x + doublePad,
    height = yesDims.y + doublePad,
  }

  noDims := rl.MeasureTextEx(ctx.font, "No", ctx.buttonFontSize, fontSpacing)
  noButton : rl.Rectangle = {
    y = buttonY,
    width = noDims.x + doublePad,
    height = noDims.y + doublePad,
  }

  ctx.buttonPositions[Buttons.ExitYes] = yesButton
  ctx.buttonPositions[Buttons.ExitNo] = noButton
}

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

// NOTE: This comes from raylib: https://github.com/raysan5/raylib/blob/d1b535c7b8c31ca29fa1c5872f79ec7ea153cd2f/src/rtext.c#L1160
DefaultFontSize :: 10
getFontSpacing :: proc(font: rl.Font, fontSize: f32) -> f32 {
  baselineSize := fontSize
  if fontSize < DefaultFontSize {
    baselineSize = DefaultFontSize
  }

  return baselineSize/DefaultFontSize
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
      currentOverlay = .NoOverlay,
    },
    exitOverlayState = {
      heading = {
        pos = { 30, 30 },
        text = "Are you sure you want to exit?",
        fontSize = 17,
      },
    },
    uiState = {
      buttonColors = DraculaColors,
      font = rl.GetFontDefault(),
      buttonFontSize = 12,
    },
  }

  gameArena : vmem.Arena
  allocator := vmem.arena_allocator(&gameArena)

  loadSettings(allocator)

  g.uiState.buttonPositions = make([]rl.Rectangle, len(Buttons), allocator) 
  createExitButtonRects(&g.uiState, allocator)


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
