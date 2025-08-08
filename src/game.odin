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
	some_number: int,
  editorState: EditorState,
	run: bool,
}

g: ^Game_Memory

game_camera :: proc() -> rl.Camera2D {
	w := f32(rl.GetScreenWidth())
	h := f32(rl.GetScreenHeight())

	return {
		zoom = h/PIXEL_WINDOW_HEIGHT,
		offset = { w/2, h/2 },
	}
}

ui_camera :: proc() -> rl.Camera2D {
	return {
		zoom = f32(rl.GetScreenHeight())/PIXEL_WINDOW_HEIGHT,
	}
}

update :: proc() {
	g.some_number += 1

	if rl.IsKeyPressed(.ESCAPE) {
		g.run = false
	}

  if rl.IsKeyPressed(.E) {
    if g.editorState.currentOverlay == OverlayType.NoOverlay {
      g.editorState.currentOverlay = .ExitOverlay
    } else {
      g.editorState.currentOverlay = .NoOverlay
    }
  }
}

draw :: proc() {
	rl.BeginDrawing()
  {
    rl.ClearBackground(rl.DARKGRAY)

    rl.BeginMode2D(game_camera())
    {
      rl.DrawRectangleV({20, 20}, {10, 10}, rl.GREEN)
      rl.DrawRectangleV({-30, -20}, {10, 10}, rl.GREEN)
    }
    rl.EndMode2D()

    rl.BeginMode2D(ui_camera())
    {
      rl.DrawText(fmt.ctprintf("some_number: %v", g.some_number), 5, 5, 8, rl.WHITE)
      rl.DrawText(fmt.ctprintf("Overlay State: %v", g.editorState.currentOverlay), 5, 20, 8, rl.WHITE)

      mousePos := rl.GetScreenToWorld2D(rl.GetMousePosition(), ui_camera())
      placementRect := centerRectToPoint(mousePos, { 10, 10})
      rl.DrawRectangleRec(placementRect, rl.Fade(rl.GREEN, .5))
    }
    rl.EndMode2D()
  }
	rl.EndDrawing()
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

@(export)
game_update :: proc() {
	update()
	draw()

	// Everything on tracking allocator is valid until end-of-frame.
	free_all(context.temp_allocator)
}

@(export)
game_init_window :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(1280, 720, "Odin + Raylib + Hot Reload template!")
	rl.SetWindowPosition(200, 200)
	rl.SetTargetFPS(500)
	rl.SetExitKey(nil)
}

@(export)
game_init :: proc() {
	g = new(Game_Memory)

	g^ = Game_Memory {
		some_number = 100,
    run = true,
    editorState = {
      currentOverlay = .ExitOverlay,
    },
	}

	game_hot_reloaded(g)
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
