# LLVM Life

For fun, I decided to implement [Conway's Game of Life][1] in [LLVM assembly][2]. It runs in the terminal, using a couple ANSI escape codes to clear the screen before each redraw.

[1]: https://en.wikipedia.org/wiki/Conway's_Game_of_Life
[2]: http://llvm.org/docs/LangRef.html

## Build

Just run `make`.

## Usage

The `life` executable takes two command-line arguments:

1. **Filename**: A text file containing the initial grid.
2. **Delay**: The number of milliseconds to delay between each update.

For example, `life grid.txt 250` would load "grid.txt" and advance to the next generation four times per second.

The grid file must have the following format:

- Every line has the same number of characters.
- Every line is terminated by a Unix-style line break.
- Live cells are represented by "X" characters.
- Dead cells are represented by "." characters (periods).

Try running `bin/life gosper.txt 100` :)

## License

© 2016 Mitchell Kember

LLVM Life is available under the MIT License; see [LICENSE](LICENSE.md) for details.
