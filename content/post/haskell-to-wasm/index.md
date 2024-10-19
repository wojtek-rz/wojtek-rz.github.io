---
title: "From Code to Execution: Running Haskell Programs on the Web"
description: "My journey on running Haskell programs on the web"
date: 2024-08-12
categories:
  - experiments
tags:
  - Haskell
  - Webassembly
  - Interpreters
  - Runtimes
  - Javascript
---

Have you ever had the feeling that you have written a cool script or program and you want to show it to the world? If so, then what would be the best way 
to show it to everyone? I always think about two aspects of a good demo. 
The first one is whether potential user can experience and play with your software.
The second one how much effort the potential user has to put in to load and configure 
your software.

One of the best ways to present your software is to embbed it inside web application. 
That way, there is no downloading the codebase (explicitely) and no configuration for the user.
Someone can just enter the website and start toying with your programs - great example is 
[huggingface](https://huggingface.co/) where we can play with the models from the frontend UI.

Here I focus on programs with command line interface to communicate with the world. 
Some time ago I created an interpreter of the programming language of my invention - [Emilia 
Programming Language](https://github.com/wojtek-rz/mim-projekty/tree/main/Programming%20languages%20and%20paradigms/Emilia%20Programming%20Language). It is written 
in Haskell and uses CLI to communicate with the world. The online demo can be found [here](https://wojteks-misc-files.pages.dev/) - note that it needs a couple of seconds to load (it's one of the downsides of Webassembly...).

I want to embed my Haskell interpreter on a website. I could do this by creating backend service on a "compute instance" in the cloud that would run the Emilia executable, but I would like to avoid that cost, to keep the demo as cheap as possible for me.

## Thing about WebAssembly

Actually there is a way to do all the computation on the client side. And I don't have to rewrite all interpreter to Javascript to do that. The answer is __WebAssembly__.

It is a low -evel programming code with assebmler-like instruction set designed for near-native performance. Web browsers implement WebAssembly interpreters and compilers, allowing for much faster execution than Javascript. 
Many programming language compilers and their extensions allow compilation to 
WebAssembly in addition to compilation to machine code. (Clang, Go, Haskell).

Note that this is only the concise tutorial of the steps I had to take in my project. 
If you're not fammilliar with WebAssembly you won't find detailed explanation of all the concepts here.

## Compiling Haskell to WebAssembly

The first thing I had to do was to compile haskell into wasm (WebAssembly), which 
is probably a thing only a handful of developers have done. Fortunately the creators 
of Haskell compiler (GHC) have created a GHC backend that compiles to wasm. The official 
tutorial is available [here](https://ghc.gitlab.haskell.org/ghc/doc/users_guide/wasm.html) and you can download the project [here](https://gitlab.haskell.org/ghc/ghc-wasm-meta).

After running the instalation script all the tools should be available inside 
`~/.ghc-wasm`. You should run `source ~/.ghc-wasm/env` to add the tools and 
environment variables to `PATH`. Then instead of `ghc`, `ghc-pkg`, `hsc2hs` you should use their alternative versions `wasm32-wasi-ghc`, `wasm32-wasi-ghc-pkg` 
and `wasm32-wasi-hsc2hs`. There is also wrapper for cabal that uses wasm backend for compiling and linking the code: `wasm32-wasi-cabal`.

My project was written with `cabal` building tool, so instead of `cabal build emilia-lang-exe` I write:
```
wasm32-wasi-cabal build emilia-lang-exe
```

Make sure that your project uses one thread for execution (rts -N option), 
otherwise the project won't compile.
{:.notice--warning}

Then you can find the compiled wasm binary inside by running `cabal list-bin exe:emilia-lang-exe`, and copy it to our current workplace.

As a result we obtained `emilia-lang-exe.wasm` binary file written in WebAssembly. 
You can run it with wasm runtime, a separate program, like `wasmtime` that 
came with the `wasm-ghc` and should be in your path.

```
wasmtime run emilia-lang-exe.wasm --help
```
```
Usage: emilia-lang-exe <file>
       emilia-lang-exe --repl
       emilia-lang-exe
If no file is provided, executable will read from stdin.
```

You can also run this file in the browser and this is what we are going to do.

## Running WebAssembly binary in the browser

Moderm browsers come with the wasm interpreter out of the box. But our CLI binary requires one more thing to run, that is IO interface, a way to communicate with the external world. This was build in the `wasmtime` interpreter that we already used. Along with some other useful things like: file operations, time and random utilities they create a set of functions called a __runtime__.

We need a bridge that would connect external world to our program.  The most established one is called [Wasmer](https://docs.wasmer.io/sdk/wasmer-js).

The easiest way is to create a node project with bundler, for example with Vite. 
After creating you have to install `wasmer-sdk`:
```
npm install -S @wasmer/sdk
```

Then you can import it inside main javascript (typescript) file, for example `index.ts` and use it. On the official website there is simple example of how to 
use Python binary:

```js
import { init, Wasmer } from "@wasmer/sdk";
 
await init();
 
const pkg = await Wasmer.fromRegistry("python/python@3.12");
const instance = await pkg.entrypoint.run({
    args: ["-c", "print('Hello, World!')"],
});
 
const { code, stdout } = await instance.wait();
console.log(`Python exited with ${code}: ${stdout}`);
```

In our use case we would like to emulate terminal in the browser. The program that would be executed inside it is `emilia-lang-exe` binary.

## Creating terminal frontend

There is altready javascript library that generates component with nice looking UI and handy functions and is 
calld [xterm](https://xtermjs.org/). To install the npm module:

```
npm install @xterm/xterm
```
Add to `index.html` file the following content:

```
<!doctype html>
<html lang="en">
 
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Wasmer Shell</title>
    <script type="module" defer src="index.ts"></script>
</head>
 
<body>
    <div id="terminal"></div>
</body>
 
</html>
```

It will load the `index.ts` file with our script.

Inside of it we would like to download the binary from url:

```js

import type { Instance } from "@wasmer/sdk";

// This will save in url variable path to static file with the wasm binary
import url from "./emilia-lang-exe.wasm?url";


const { init, initializeLogger, runWasix } = await import("@wasmer/sdk");
await init();
const module = await WebAssembly.compileStreaming(fetch(url));


const instance = await runWasix(module, {
    program: "emilia-lang-exe",
    args: ["--repl"],
});
```

To connect instances input and output to terminal's intput and output we need helper function:

```js
function connectStreams(instance: Instance, term: Terminal) {
    const stdin = instance.stdin?.getWriter();
    term.onData(bufforDoubleEnter(data => stdin?.write(encoder.encode(data)), term));
    instance.stdout.pipeTo(new WritableStream({ write: chunk => term.write(chunk) }));
    instance.stderr.pipeTo(new WritableStream({ write: chunk => term.write(chunk) }));
}
```

Initialization of the terminal addon:

```js
import "xterm/css/xterm.css";
import { Terminal } from '@xterm/xterm';
import { WebLinksAddon } from '@xterm/addon-web-links';

const term = new Terminal({ cursorBlink: true, convertEol: true });
term.open(document.getElementById("terminal")!);
term.loadAddon(new WebLinksAddon());

term.writeln("Starting...");
```

And to connect the instance to the terminal we our helper function:

```js
connectStreams(instance, term);
```

### Problems

After we put everything together we see some major problems. After presssing "Enter" the console is not creating the new line, nor it is sending the line to the 
interpreter. "Backspace" also doesn't work.

After some digging it appears that there exists something called [line discipline](https://en.wikipedia.org/wiki/Line_discipline) and it's main tasks include:

> For example, the standard line discipline processes the data it receives from the hardware driver and from applications writing to the device according to the requirements of a terminal on a Unix-like system. On input, it handles special characters such as the interrupt character (typically Control-C) and the erase and kill characters (typically backspace or delete, and Control-U, respectively) and, on output, it replaces all the LF characters with a CR/LF sequence.

Our problem can be solved by [xterm-pty](https://github.com/mame/xterm-pty?tab=readme-ov-file) module.

A PTY, or pseudoterminal, is an intermediate layer between a process and a terminal. It is not just a pipe, but provides several useful functionalities such as input echo, line editing, conversion, etc. PTY is essential for running real-world CUI programs.

Usually, xterm.js is used with node-pty. Because node-pty is a binding for the PTY functions provided by the operating system, it does not work on a browser. On the other hand, xterm-pty works on a browser because it has an own implementation of simple Linux-like line discipline.

To add it to our project we have to install the node module:
```
npm i xterm-pty
```
Then we add the following lines:
```js

import { openpty } from "xterm-pty";

const { master, slave } = openpty();
term.loadAddon(master);
slave.write("Starting...\n");

// instance initalization...

connectStreams(instance, slave);
```
## Hosting

After running
```
npm run build
```
to build the static website, the result can be available [here](https://wojteks-misc-files.pages.dev/).

The wasmer sdk library doesn't work out of the box. It uses javascript's `sharedArrayBuffer` to communicate between threads and most browsers block this functionality, unless the headers 
`Cross-Origin-Opener-Policy: same-origin` and  `Cross-Origin-Embedder-Policy: require-corp` are present.
{:.notice--warning}

All in all, it was a complicated trip, but every problem was solved in the end. 
I certainly learned a lot along the way.

Thanks for reading,
Wojtek

