# Life

This program is a Morse code utility. It has three modes:

1. **Encode**: Convert regular text to Morse code.
2. **Decode**: Convert Morse code back to regular text.
3. **Transmit**: Pretend you're operating a telegraph.

It supports ASCII letters, numbers, and most punctuation. See [code.c](src/code.c) for the full list.

## Build

I use the [tup build system][1] for this project. On OS X, it's easy:

1. `brew install homebrew/fuse/tup`
2. `cd /path/to/morse`
3. `tup`
4. `bin/morse`

[1]: http://gittup.org/tup/

## Usage

The encode and decode modes operate on streams, so you can use them interactively or in pipelines.

```sh
$ morse -h
usage: morse [-e | -d | -t]
$ echo "The quick brown fox" | morse -e
- .... . / --.- ..- .. -.-. -.- / -... .-. --- .-- -. / ..-. --- -..-
$ echo "- .... . / --.- ..- .. -.-. -.-" | morse -d
THE QUICK
$ echo "- .... .. ... / .. ... / -- --- .-. ... . / -.-. --- -.. ." | morse -d
THIS IS MORSE CODE
```

## License

© 2016 Mitchell Kember

Life is available under the MIT License; see [LICENSE](LICENSE.md) for details.
