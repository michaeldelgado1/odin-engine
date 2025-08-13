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

Button :: struct {
  pos: rl.Rectangle,
  // TODO: Figure out if making this a
  //  cstring is worse than allocating every
  //  frame on the exit screen
  label: cstring,
  currentColor: rl.Color,
  baseColor: rl.Color,
  hoverColor: rl.Color,
  clickColor: rl.Color,
  onClick: proc(),
}

OverlayState :: struct {
  buttons: [dynamic]Button,
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
}

g: ^Game_Memory

rectDims := rl.Vector2 {
  22, 15,
}

exitOverlayUpdate :: proc() {
  if rl.IsKeyPressed(.E) {
    g.editorState.currentOverlay = .NoOverlay
  }

  if rl.IsKeyPressed(.T) {
    for button in g.exitOverlayState.buttons {
      button.onClick()
    }
  }

  if rl.IsMouseButtonPressed(.RIGHT) {
    fmt.println("Right Clicked in exit mode")
  }

  for &button in g.exitOverlayState.buttons {
    if rl.CheckCollisionPointRec(g.screenMouse, button.pos) {
      if rl.IsMouseButtonPressed(.LEFT) {
        button.onClick()
      } else {
        button.currentColor = button.hoverColor
      }
    } else {
        button.currentColor = button.baseColor
    }
  }

  evenSpaceHorizontal(g.exitOverlayState.buttons, f32(rl.GetScreenWidth()), g.uiCam.zoom)
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
  g.uiCam= ui_camera()
  g.gameCam= game_camera()
  g.worldMouse = rl.GetMousePosition()
  g.screenMouse = rl.GetScreenToWorld2D(g.worldMouse, g.uiCam)

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

  for button in g.exitOverlayState.buttons {
    rl.DrawRectangleRec(button.pos, button.currentColor)
    rl.DrawText(button.label, i32(button.pos.x) + ButtonPadding, i32(button.pos.y) + ButtonPadding, 12, rl.BLACK)
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
createExitButtons :: proc(allocator := context.allocator) -> [dynamic]Button {
  doublePad : f32 = ButtonPadding * 2
  yesButton : Button = {
    pos = { y = 30, height = 20 },
    label = "Yes",
    onClick = proc() {
      fmt.println("Yes Button Worked!")
    },
  }


  noButton : Button = {
    pos = { y = 30, width = 30, height = 20 },
    label = "No",
    onClick = proc() {
      fmt.println("No Button Worked!")
    },
  }

  maybeButton : Button = {
    pos = { y = 30, width = 30, height = 20 },
    label = "Maybe",
    onClick = proc() {
      fmt.println("Maybe Button Worked!")
    },
  }

  lastButton : Button = {
    pos = { y = 30, width = 30, height = 20 },
    label = "Last",
    onClick = proc() {
      fmt.println("Last Button Worked!")
    },
  }

  buttons := make([dynamic]Button, 0, allocator)
  append(&buttons, yesButton)
  append(&buttons, noButton)
  append(&buttons, maybeButton)
  append(&buttons, lastButton)

  // TODO: Calculate button height too
  for &button in buttons {
    button.pos.width = f32(rl.MeasureText(button.label, 12)) + doublePad
    button.baseColor = rl.GRAY
    button.hoverColor = rl.LIGHTGRAY
    button.currentColor = button.baseColor
  }

  return buttons
}

evenSpaceHorizontal :: proc(buttons: [dynamic]Button, width: f32, scale: f32) {
  scaledWidth := width / scale
  totalButtonSizes : f32

  for button in buttons {
    totalButtonSizes += (button.pos.width)
  }

  leftoverSpace := scaledWidth - totalButtonSizes
  spaceBetween := leftoverSpace / f32(len(buttons) + 1)

  for idx in 0..<len(buttons) {
    acrossButton : f32
    prevPos : f32
    prevIndex := idx - 1
    if prevIndex >= 0 {
      acrossButton = (buttons[prevIndex].pos.width)
      prevPos = buttons[prevIndex].pos.x
    }
    buttons[idx].pos.x = spaceBetween + prevPos + acrossButton
  }
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
  }

  gameArena : vmem.Arena
  allocator := vmem.arena_allocator(&gameArena)

  loadSettings(allocator)

  g.exitOverlayState.buttons = createExitButtons(allocator)


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
