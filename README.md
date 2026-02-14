# Termtris

A Tetris clone for the terminal, written in Rust.

## Layout

```
┌──────────────────────────────────────┐
│              TETRIS                  │
├──────────────────────────────────────┤
│  ┌────────────────────┐  ┌────────┐  │
│  │                    │  │  NEXT  │  │
│  │   GAME BOARD       │  │ ████   │  │
│  │                    │  │   ██   │  │
│  │                    │  │        │  │
│  │                    │  │        │  │
│  │                    │  └────────┘  │
│  │                    │  ┌────────┐  │
│  │                    │  │ S:    0│  │
│  │                    │  │ L:    0│  │
│  │                    │  │ L:    1│  │
│  └────────────────────┘  └────────┘  │
└──────────────────────────────────────┘
```

### Game Structure

- **GAME BOARD**: The main play area where pieces fall. It is 10 cells wide and 20 cells tall.
- **NEXT**: Shows the next piece that will appear after the current piece lands.
- **S**: Score - points earned by clearing lines. More lines cleared at once yields higher points.
- **L**: Lines - total number of complete lines cleared.
- **L**: Level - current difficulty level. Increases every 10 lines cleared, making pieces fall faster.

## Controls

| Key   | Action                |
| ----- | --------------------- |
| ← / → | Move piece left/right |
| ↓     | Soft drop             |
| ↑     | Rotate piece          |
| Space | Hard drop             |
| P     | Pause/Resume          |
| Q     | Quit                  |

## Build & Run

```bash
cargo run --release
```

## Requirements

- Rust (latest stable)
- cargo

## License

MIT
