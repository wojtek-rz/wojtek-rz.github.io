import "xterm/css/xterm.css";
import type { Instance } from "@wasmer/sdk";
import { Terminal } from '@xterm/xterm';
import { openpty } from "xterm-pty";

import url from "./emilia-lang-exe.wasm?url";

const decoder = new TextDecoder();

function connectStreams(instance: Instance, term) {
    const stdin = instance.stdin?.getWriter();
    term.onReadable(() => {
        const data = new Uint8Array(term.read());
        if (data) {
            stdin?.write(data);
        }
    });
    instance.stdout.pipeTo(new WritableStream({ write: chunk => term.write(decoder.decode(chunk)) }));
    instance.stderr.pipeTo(new WritableStream({ write: chunk => term.write(decoder.decode(chunk)) }));
}

async function main() {
    const { init, initializeLogger, runWasix } = await import("@wasmer/sdk");
    await init();
    const module = await WebAssembly.compileStreaming(fetch(url));

    const term = new Terminal({ cursorBlink: true, fontSize: 20, convertEol: true });
    term.resize(80, 50);
    term.open(document.getElementById("terminal")!);


    const { master, slave } = openpty();
    term.loadAddon(master);

    slave.write("Starting...\n");

    const instance = await runWasix(module, {
        program: "emilia-lang-exe",
        args: ["--repl"],
    });

    connectStreams(instance, slave);
}

main();