# Native macOS WebKit Automator

**Bare-metal OS sandboxing, React state hijacking, and deterministic TLS execution.**

*Disclaimer: This project is a proof-of-concept created strictly for educational purposes and security research. It demonstrates the technical differences between native WKWebView instances, standard headless browsers, and vanilla OpenSSL requests in the context of web automation, heuristic evasion, and DOM state manipulation.*

This application is a C++/Objective-C++ execution engine that bridges native macOS UI threads with injected JavaScript payload workers. By directly instantiating a native WebKit sandbox, intercepting asynchronous network streams, reverse-engineering React's virtual DOM event system, and managing memory deterministically, the tool automates complex single-page applications (SPAs) without triggering the security heuristics that instantly flag traditional headless frameworks like Puppeteer or Selenium.

## Execution Architecture & Heuristic Bypass

Standard headless automation frameworks inject predictable global variables and exhibit distinct V8 execution footprints that are trivially flagged by enterprise Web Application Firewalls (WAFs) and bot-protection scripts. This engine bypasses these heuristics via OS-level native execution.

1. **Native OS Instantiation:** The C++ process spawns a native Safari `WKWebView` window via Apple's Cocoa API. Because this relies on the host OS's exact WebKit framework rather than a bundled Chromium binary, it naturally passes all JavaScript environment checks, CAPTCHA browser fingerprinting, and WebDriver detection algorithms.
2. **Asynchronous Fetch Wiretapping:** At document load (`WKUserScriptInjectionTimeAtDocumentStart`), the engine injects a low-level wiretap into the global `window.fetch` prototype. This intercepts, clones, and parses all GraphQL and REST API responses in real-time, piping the raw JSON data directly across the sandbox boundary back to the native C++ handler via `WKScriptMessageHandler`.
3. **Event Loop Teardown:** Once the target network payload is intercepted, the Objective-C++ delegate cleanly terminates the heavy macOS Cocoa event loop (`[NSApp stop:nil]`), posting a dummy event to unblock the main thread and handing the extracted data back to the highly efficient C++ `main()` execution flow.

## React SyntheticEvent Hijacking

Modern web applications utilizing React cannot be automated via standard DOM `.value` assignments, as React maintains an internal state representation (the Virtual DOM) that ignores standard JavaScript mutations. 

To achieve zero-friction automation, this engine utilizes a DOM bypass technique:
* **Native Setter Invocation:** The injected script bypasses React's `SyntheticEvent` wrappers by directly invoking the native HTML element setter (`_valueTracker.setValue()`).
* **Event Dispatching:** It forces a state sync by manually dispatching native `input` events with strict bubbling rules, tricking the React application into registering automated text injection as organic human keystrokes.

## Network & TLS Protocol Mechanics (JA3 Spoofing)

A massive vulnerability in standard programmatic web scraping is the TLS Client Hello packet. Vanilla `libcurl` or Python's `requests` utilize standard OpenSSL, which broadcasts cipher suites and HTTP/2 pseudo-headers in an order mathematically distinct from standard consumer browsers, resulting in immediate TCP handshake rejections by modern WAFs.

To solve this, the headless execution phase utilizes `curl-impersonate-chrome`:
* **BoringSSL Integration:** The engine is compiled against Google's BoringSSL (the exact cryptography library used by Chrome) rather than standard OpenSSL.
* **Exact Byte-Signatures:** The application perfectly replicates Chrome's TLS Client Hello, including exact cipher suite ordering, specific elliptic curve preferences, and the inclusion of GREASE bytes. 

## Systems Philosophy: Why C++ Over Python

While Python is the industry standard for web scraping (Selenium, Playwright), it is fundamentally incompatible with high-throughput, deterministic execution. This engine is built in C++ to exploit lower-level computer organization principles:

* **Garbage Collection (Non-Determinism):** Python relies on a cyclic Garbage Collector (GC). You cannot control exactly *when* the GC runs, resulting in arbitrary "stop-the-world" latency spikes that disrupt network timing. C++ has zero automatic garbage collection. Memory is manually controlled, completely flat, and deterministic, ensuring zero unexpected execution pauses during high-speed extraction.
* **Memory Layout & Cache-Line Saturation:** Python objects are essentially arrays of pointers scattered randomly across the heap. Traversing data in Python causes constant CPU cache misses because the processor must jump around RAM. C++ allows for contiguous memory allocation (Struct-of-Arrays). When the CPU fetches a 64-byte cache line, it pulls in exactly the data the algorithm needs next, resulting in a near 100% L1/L2 cache hit rate and allowing the hardware prefetcher to operate at maximum efficiency.
* **The Global Interpreter Lock (GIL):** Python's GIL prevents multiple native threads from executing bytecodes simultaneously, crippling true hardware parallelism. C++ provides bare-metal multithreading. This allows the engine to completely decouple the Cocoa UI thread from the headless network execution threads without heavy Inter-Process Communication (IPC) overhead.
* **Network & Hardware Proximity:** Python's `ssl` module heavily abstracts socket creation. C++ compiles directly to machine code, allowing direct integration with BoringSSL via linked libraries. This bare-metal access is strictly required to manipulate the exact byte-ordering of the TLS Client Hello handshake.

## Compilation & System Linkage

Because the engine bridges deep into native macOS UI elements and network frameworks, it must be compiled as an Objective-C++ file (`.mm`) and explicitly linked to Apple's native frameworks and the specialized BoringSSL curl build.

```bash
# Compile with aggressive optimizations and Apple framework linkage
clang++ -std=c++17 -O3 sandbox.mm -I/usr/local/include -L/usr/local/lib -lcurl-impersonate-chrome -framework Cocoa -framework WebKit -o sandbox

## Usage
Execute the compiled binary from the terminal:

```bash
./sandbox <email> <password>
```