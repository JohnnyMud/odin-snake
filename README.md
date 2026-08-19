# odin-snake

A Snake game written in [Odin](https://odin-lang.org/). It runs in a Unix terminal, and the same game logic can be compiled to WebAssembly for a browser.

## Requirements

- [Odin](https://odin-lang.org/docs/install/) installed and on your `PATH`
- A Unix-like terminal (macOS/Linux) — the terminal build uses raw input via POSIX
- For the WebAssembly build: LLVM’s `wasm-ld` on your `PATH` (Homebrew: `brew install lld`)

## Run (terminal)

```bash
odin run .
```

## WebAssembly

```bash
odin build . -target:js_wasm32 -no-entry-point -out:snake.wasm
cp "$(odin root)/core/sys/wasm/js/odin.js" .
```

Copy `snake.wasm` and `odin.js` to your site. `odin.runWasm` does not return the module exports, so instantiate with `odin.setupDefaultImports` and call the C ABI yourself:

| Export | Role |
|--------|------|
| `game_init()` | Reset the game and render the first board |
| `game_keydown(key)` | ASCII code for `w`/`a`/`s`/`d`/`r` (case-insensitive) |
| `game_tick()` | One 100ms step |
| `game_board_ptr()` | Pointer to the current ASCII board in WASM memory |
| `game_board_len()` | Byte length of that board |

```html
<pre id="snake" style="font-family: ui-monospace, monospace; line-height: 1.2;"></pre>
<script src="odin.js"></script>
<script>
async function main() {
  const pre = document.getElementById("snake");
  const mem = new odin.WasmMemoryInterface();
  const imports = odin.setupDefaultImports(mem);
  const bytes = await fetch("snake.wasm").then((r) => r.arrayBuffer());
  const { instance } = await WebAssembly.instantiate(bytes, imports);
  const e = instance.exports;
  mem.setExports(e);
  mem.setMemory(e.memory);

  const decoder = new TextDecoder();
  function draw() {
    const ptr = e.game_board_ptr();
    const len = e.game_board_len();
    pre.textContent = decoder.decode(new Uint8Array(e.memory.buffer, ptr, len));
  }

  e.game_init();
  draw();

  window.addEventListener("keydown", (ev) => {
    if (ev.key.length === 1) {
      e.game_keydown(ev.key.charCodeAt(0));
      draw();
    }
  });

  setInterval(() => {
    e.game_tick();
    draw();
  }, 100);
}
main();
</script>
```

Serve over HTTP (not `file://`) so `fetch("snake.wasm")` is allowed.

## Controls

| Key | Action        |
|-----|---------------|
| `W` | Move up       |
| `A` | Move left     |
| `S` | Move down     |
| `D` | Move right    |
| `R` | Replay after game over |

Eat `*` to grow and score points. Hit a wall or yourself and it’s game over — press `R` to play again.
