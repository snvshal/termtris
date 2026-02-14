use crossterm::{
    cursor::{Hide, MoveTo, Show},
    event::{read, Event, KeyCode, KeyEventKind},
    style::{Color, Stylize},
    terminal::{Clear, ClearType, EnterAlternateScreen, LeaveAlternateScreen},
    ExecutableCommand,
};
use rand::Rng;
use std::io::Write;
use std::time::Duration;

const WIDTH: usize = 10;
const HEIGHT: usize = 20;

#[derive(Clone, Copy, PartialEq, Eq)]
struct Piece {
    shape: [[bool; 4]; 4],
    color: Color,
}

const PIECES: [Piece; 7] = [
    Piece {
        shape: [
            [false, false, false, false],
            [true, true, true, true],
            [false, false, false, false],
            [false, false, false, false],
        ],
        color: Color::Cyan,
    },
    Piece {
        shape: [
            [false, false, false, false],
            [false, true, true, false],
            [false, true, true, false],
            [false, false, false, false],
        ],
        color: Color::Yellow,
    },
    Piece {
        shape: [
            [false, false, false, false],
            [false, true, false, false],
            [true, true, true, false],
            [false, false, false, false],
        ],
        color: Color::Magenta,
    },
    Piece {
        shape: [
            [false, false, false, false],
            [false, true, true, false],
            [true, true, false, false],
            [false, false, false, false],
        ],
        color: Color::Green,
    },
    Piece {
        shape: [
            [false, false, false, false],
            [true, true, false, false],
            [false, true, true, false],
            [false, false, false, false],
        ],
        color: Color::Red,
    },
    Piece {
        shape: [
            [false, false, false, false],
            [true, false, false, false],
            [true, true, true, false],
            [false, false, false, false],
        ],
        color: Color::Blue,
    },
    Piece {
        shape: [
            [false, false, false, false],
            [false, false, true, false],
            [true, true, true, false],
            [false, false, false, false],
        ],
        color: Color::DarkYellow,
    },
];

struct Game {
    board: [[Option<Color>; WIDTH]; HEIGHT],
    current_piece: Piece,
    current_x: i32,
    current_y: i32,
    next_piece: Piece,
    score: u32,
    lines: u32,
    level: u32,
    game_over: bool,
    paused: bool,
}

impl Game {
    fn new() -> Self {
        let mut rng = rand::thread_rng();
        let current_piece = PIECES[rng.gen_range(0..7)];
        let mut next_piece = PIECES[rng.gen_range(0..7)];
        while next_piece == current_piece {
            next_piece = PIECES[rng.gen_range(0..7)];
        }
        Game {
            board: [[None; WIDTH]; HEIGHT],
            current_piece,
            current_x: (WIDTH / 2) as i32 - 2,
            current_y: 0,
            next_piece,
            score: 0,
            lines: 0,
            level: 1,
            game_over: false,
            paused: false,
        }
    }

    fn rotate_piece(&mut self) {
        let mut new_shape = [[false; 4]; 4];
        for y in 0..4 {
            for x in 0..4 {
                new_shape[x][3 - y] = self.current_piece.shape[y][x];
            }
        }
        let old = self.current_piece.shape;
        self.current_piece.shape = new_shape;
        if !self.is_valid_position(0, 0) {
            self.current_piece.shape = old;
        }
    }

    fn is_valid_position(&self, dx: i32, dy: i32) -> bool {
        for y in 0..4 {
            for x in 0..4 {
                if self.current_piece.shape[y][x] {
                    let nx = self.current_x + x as i32 + dx;
                    let ny = self.current_y + y as i32 + dy;
                    if nx < 0 || nx >= WIDTH as i32 || ny >= HEIGHT as i32 {
                        return false;
                    }
                    if ny >= 0 && self.board[ny as usize][nx as usize].is_some() {
                        return false;
                    }
                }
            }
        }
        true
    }

    fn lock_piece(&mut self) {
        for y in 0..4 {
            for x in 0..4 {
                if self.current_piece.shape[y][x] {
                    let py = self.current_y + y as i32;
                    let px = self.current_x + x as i32;
                    if py >= 0 && py < HEIGHT as i32 && px >= 0 && px < WIDTH as i32 {
                        self.board[py as usize][px as usize] = Some(self.current_piece.color);
                    }
                }
            }
        }
        self.clear_lines();
        self.spawn_new_piece();
    }

    fn clear_lines(&mut self) {
        let mut cleared = 0;
        let mut y = HEIGHT;
        while y > 0 {
            y -= 1;
            if self.board[y].iter().all(|c| c.is_some()) {
                cleared += 1;
                for yy in (1..=y).rev() {
                    self.board[yy] = self.board[yy - 1];
                }
                self.board[0] = [None; WIDTH];
                y += 1;
            }
        }
        if cleared > 0 {
            let pts = match cleared {
                1 => 100,
                2 => 300,
                3 => 500,
                4 => 800,
                _ => 1000,
            };
            self.score += pts * self.level;
            self.lines += cleared;
            self.level = (self.lines / 10) + 1;
        }
    }

    fn spawn_new_piece(&mut self) {
        self.current_piece = self.next_piece;
        let mut rng = rand::thread_rng();
        self.next_piece = PIECES[rng.gen_range(0..7)];
        self.current_x = (WIDTH / 2) as i32 - 2;
        self.current_y = 0;
        if !self.is_valid_position(0, 0) {
            self.game_over = true;
        }
    }

    fn move_piece(&mut self, dx: i32, dy: i32) -> bool {
        if self.is_valid_position(dx, dy) {
            self.current_x += dx;
            self.current_y += dy;
            true
        } else if dy > 0 {
            self.lock_piece();
            false
        } else {
            false
        }
    }

    fn hard_drop(&mut self) {
        while self.is_valid_position(0, 1) {
            self.current_y += 1;
            self.score += 2;
        }
        self.lock_piece();
    }
}

fn draw_game(game: &Game) {
    print!("{}", Clear(ClearType::All));

    let term = crossterm::terminal::size().unwrap_or((80, 24));
    let tw = term.0 as usize;
    let th = term.1 as usize;

    // Layout dimensions
    let board_w = WIDTH * 2 + 2; // 22
    let board_h = HEIGHT + 2; // 22
    let side_w = 10; // 10
    let gap = 2; // 2
    let pad = 2; // 2

    let inner_w = board_w + gap + side_w; // 22 + 2 + 10 = 34
    let outer_w = inner_w + pad * 2; // 34 + 4 = 38

    let start_x = (tw.saturating_sub(outer_w)) / 2;
    let start_y = (th.saturating_sub(board_h + 4)) / 2;

    let outer_h = board_h + 4; // 22 + 4 = 26

    // === OUTER BORDER ===
    // Top
    print!("{}", MoveTo(start_x as u16, start_y as u16));
    print!("┌");
    for _ in 0..outer_w {
        print!("─");
    }
    print!("┐");

    // Title
    print!("{}", MoveTo(start_x as u16, (start_y + 1) as u16));
    print!("│");
    let title = "             TETRIS             ";
    let vis = &title[..outer_w.min(title.len())];
    let pl = (outer_w - vis.len()) / 2;
    print!(
        "{}{}{}",
        " ".repeat(pl),
        vis.with(Color::Cyan).bold(),
        " ".repeat(outer_w - vis.len() - pl)
    );
    print!("│");

    // Separator
    print!("{}", MoveTo(start_x as u16, (start_y + 2) as u16));
    print!("├");
    for _ in 0..outer_w {
        print!("─");
    }
    print!("┤");

    // === GAME BOARD ===
    let bx = start_x + pad;
    let by = start_y + 3;

    // Board top
    print!("{}", MoveTo(bx as u16, by as u16));
    print!("┌");
    for _ in 0..board_w - 2 {
        print!("─");
    }
    print!("┐");

    // Board rows
    for y in 0..HEIGHT {
        print!("{}", MoveTo(bx as u16, (by + 1 + y) as u16));
        print!("│");
        for x in 0..WIDTH {
            let mut f = game.board[y][x];
            if !game.game_over && !game.paused {
                for py in 0..4 {
                    for px in 0..4 {
                        if game.current_piece.shape[py][px]
                            && (game.current_y + py as i32) == y as i32
                            && (game.current_x + px as i32) == x as i32
                        {
                            f = Some(game.current_piece.color);
                        }
                    }
                }
            }
            match f {
                Some(c) => print!("{}", "██".with(c)),
                None => print!("  "),
            }
        }
        print!("│");
    }

    // Board bottom
    print!("{}", MoveTo(bx as u16, (by + board_h - 1) as u16));
    print!("└");
    for _ in 0..board_w - 2 {
        print!("─");
    }
    print!("┘");

    // === SIDE PANEL ===
    let sx = bx + board_w + gap;
    let sy = by;

    // NEXT box top
    print!("{}", MoveTo(sx as u16, sy as u16));
    print!("┌");
    for _ in 0..side_w - 2 {
        print!("─");
    }
    print!("┐");

    // NEXT label
    print!("{}", MoveTo(sx as u16, (sy + 1) as u16));
    print!("│  NEXT  │");

    // NEXT piece - 3 rows
    for row in 0..3 {
        print!("{}", MoveTo(sx as u16, (sy + 2 + row) as u16));
        print!("│");
        for col in 0..4 {
            match game.next_piece.shape[row][col] {
                true => print!("{}", "██".with(game.next_piece.color)),
                false => print!("  "),
            }
        }
        print!("│");
    }

    // NEXT box bottom
    print!("{}", MoveTo(sx as u16, (sy + 5) as u16));
    print!("└");
    for _ in 0..side_w - 2 {
        print!("─");
    }
    print!("┘");

    // STATS box
    let stats_y = sy + 7;
    print!("{}", MoveTo(sx as u16, stats_y as u16));
    print!("┌");
    for _ in 0..side_w - 2 {
        print!("─");
    }
    print!("┐");

    print!("{}", MoveTo(sx as u16, (stats_y + 1) as u16));
    print!("│{:8}│", format!("S:{}", game.score));

    print!("{}", MoveTo(sx as u16, (stats_y + 2) as u16));
    print!("│{:8}│", format!("L:{}", game.lines));

    print!("{}", MoveTo(sx as u16, (stats_y + 3) as u16));
    print!("│{:8}│", format!("L:{}", game.level));

    print!("{}", MoveTo(sx as u16, (stats_y + 4) as u16));
    print!("└");
    for _ in 0..side_w - 2 {
        print!("─");
    }
    print!("┘");

    // === OUTER VERTICAL BORDERS ===
    for y in 0..board_h {
        // Left border
        print!("{}", MoveTo(start_x as u16, (start_y + 3 + y) as u16));
        print!("│");
        // Right border
        print!(
            "{}",
            MoveTo((start_x + outer_w + 1) as u16, (start_y + 3 + y) as u16)
        );
        print!("│");
    }

    // Bottom border
    print!("{}", MoveTo(start_x as u16, (start_y + outer_h - 1) as u16));
    print!("└");
    for _ in 0..outer_w {
        print!("─");
    }
    print!("┘");

    // Status
    let msg_y = start_y + outer_h + 1;
    if game.game_over {
        print!("{}", MoveTo(start_x as u16, msg_y as u16));
        print!(
            "{}",
            "   GAME OVER! Press R to restart".with(Color::Red).bold()
        );
    } else if game.paused {
        print!("{}", MoveTo(start_x as u16, msg_y as u16));
        print!("{}", "   PAUSED".with(Color::Yellow).bold());
    }

    print!("{}", MoveTo(start_x as u16, (msg_y + 2) as u16));
    print!(
        "{}",
        "   arrows=move  space=hard  p=pause  q=quit".with(Color::DarkGrey)
    );

    std::io::stdout().flush().unwrap();
}

fn main() {
    let _ = std::io::stdout().execute(EnterAlternateScreen);
    let _ = std::io::stdout().execute(Hide);
    let _ = crossterm::terminal::enable_raw_mode();

    let mut game = Game::new();
    let mut last_drop = std::time::Instant::now();

    loop {
        let speed = 800u64
            .saturating_sub(((game.level - 1) * 50) as u64)
            .max(100);

        if let Ok(true) = crossterm::event::poll(Duration::from_millis(10)) {
            if let Ok(Event::Key(k)) = read() {
                if k.kind == KeyEventKind::Press {
                    match k.code {
                        KeyCode::Char('q') | KeyCode::Char('Q') => {
                            let _ = crossterm::terminal::disable_raw_mode();
                            let _ = std::io::stdout().execute(Show);
                            let _ = std::io::stdout().execute(LeaveAlternateScreen);
                            return;
                        }
                        KeyCode::Char('r') | KeyCode::Char('R') => {
                            if game.game_over {
                                game = Game::new();
                                last_drop = std::time::Instant::now();
                            }
                        }
                        KeyCode::Char('p') | KeyCode::Char('P') => {
                            if !game.game_over {
                                game.paused = !game.paused;
                            }
                        }
                        KeyCode::Left => {
                            if !game.game_over && !game.paused {
                                game.move_piece(-1, 0);
                            }
                        }
                        KeyCode::Right => {
                            if !game.game_over && !game.paused {
                                game.move_piece(1, 0);
                            }
                        }
                        KeyCode::Down => {
                            if !game.game_over && !game.paused {
                                game.move_piece(0, 1);
                            }
                        }
                        KeyCode::Up => {
                            if !game.game_over && !game.paused {
                                game.rotate_piece();
                            }
                        }
                        KeyCode::Char(' ') => {
                            if !game.game_over && !game.paused {
                                game.hard_drop();
                            }
                        }
                        _ => {}
                    }
                }
            }
        }

        if !game.game_over && !game.paused && last_drop.elapsed() > Duration::from_millis(speed) {
            game.move_piece(0, 1);
            last_drop = std::time::Instant::now();
        }

        draw_game(&game);
    }
}
