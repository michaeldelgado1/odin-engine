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
// import sa "core:container/small_array"

PIXEL_WINDOW_HEIGHT :: 180

OverlayType :: enum int {
  NoOverlay,
  ExitOverlay,
  // OverlayCount?
}

EditorState :: struct {
  expectedHash: string,
  currentOverlay: OverlayType,
}

Game_Memory :: struct {
  editorState: EditorState,
  run: bool,
  rects: [dynamic]rl.Rectangle,
  gameArena: vmem.Arena,
  uiCam: rl.Camera2D,
  gameCam: rl.Camera2D,
}

g: ^Game_Memory


update :: proc() {
  mousePos := rl.GetScreenToWorld2D(rl.GetMousePosition(), g.uiCam)

  if rl.IsKeyPressed(.ESCAPE) {
    g.run = false
  }

  if rl.IsKeyPressed(.E) {
    switch g.editorState.currentOverlay {
    case .NoOverlay:
      g.editorState.currentOverlay = .ExitOverlay
    case .ExitOverlay:
      g.editorState.currentOverlay = .NoOverlay
    }
  }


  if rl.IsMouseButtonPressed(.LEFT) {
    append(&g.rects, centerRectToPoint(mousePos, rectDims))
  }

  if rl.IsMouseButtonPressed(.RIGHT) {
    for idx in 0..<len(g.rects) {
      if rl.CheckCollisionPointRec(mousePos, g.rects[idx]) {
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

    monWidth := rl.GetMonitorWidth(0)
    monHeight := rl.GetMonitorHeight(0)

    w := monWidth - winWidth
    h := monHeight - winHeight

    rl.SetWindowPosition((w/2), (h/2))
  }
}

draw :: proc() {
  g.uiCam= ui_camera()
  g.gameCam= game_camera()
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

      drawDebugTest()

      drawPlacementRect(g.uiCam)
    }
    rl.EndMode2D()
  }
  rl.EndDrawing()
}

drawDebugTest :: proc() {
  rl.DrawText(fmt.ctprintf("Overlay State: %v", g.editorState.currentOverlay), 5, 5, 8, rl.WHITE)
}

drawPlacementRect :: proc(uiCamera: rl.Camera2D) {
  mousePos := rl.GetScreenToWorld2D(rl.GetMousePosition(), uiCamera)
  placementRect := centerRectToPoint(mousePos, rectDims)
  rl.DrawRectangleRec(placementRect, rl.Fade(rl.GREEN, .5))
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

rectDims := rl.Vector2 {
  22, 15,
}

@(export)
game_update :: proc() {
  update()
  draw()

  // Everything on temp allocator is valid until end-of-frame.
  free_all(context.temp_allocator)
}

@(export)
game_init_window :: proc() {
  rl.SetConfigFlags({ .WINDOW_RESIZABLE, .VSYNC_HINT, .WINDOW_TOPMOST })
  rl.InitWindow(854, 480, "Odin + Raylib + Hot Reload template!")

  winWidth := rl.GetScreenWidth()
  monWidth := rl.GetMonitorWidth(0)
  w := monWidth - winWidth
  h : i32 = 0

  when ODIN_OS == .Windows{
    // NOTE: Windows doesn't take the bar height into consideration...
    h += 50
  }

  rl.SetWindowPosition(w, h)
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

  g.gameArena = gameArena
  game_hot_reloaded(g)
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
