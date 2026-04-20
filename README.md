# Native macOS WebKit Automator

> **Disclaimer:** This project is a proof-of-concept created strictly for educational purposes and security research. It demonstrates the technical differences between native WKWebView instances, standard headless browsers, and vanilla OpenSSL requests in the context of web automation and TLS fingerprinting. The author does not condone or support the use of this software to violate the Terms of Service of any platform. Use at your own risk.

A C++/Objective-C++ application that bridges native macOS UI authentication with headless network requests. By utilizing a native WebKit sandbox for initial session generation and `curl-impersonate` for subsequent requests, this tool illustrates how headless applications can successfully maintain standard consumer browser TLS signatures (JA3).

## Prerequisites
- **macOS** (Requires native `Cocoa` and `WebKit` frameworks)
- **`curl-impersonate-chrome`** (Required to simulate standard Google Chrome TLS cipher suites)

## Compilation
Because the code interfaces with native macOS UI elements, it must be compiled as an Objective-C++ file (`.mm`) and explicitly linked to Apple's UI frameworks:

```bash
clang++ -std=c++17 -O3 sandbox.mm -I/usr/local/include -L/usr/local/lib -lcurl-impersonate-chrome -framework Cocoa -framework WebKit -o sandbox
```

## Usage
Execute the compiled binary from the terminal:

```bash
./sandbox <email> <password>
```

### Execution Architecture:
1. **Native Browser Instantiation**: Spawns a native Safari `WKWebView` window. Unlike traditional headless automation frameworks (e.g., Puppeteer, Selenium), the native OS layer naturally passes standard JavaScript environment checks.
2. **Authentication**: The user logs in and completes any necessary security challenges (CAPTCHAs) natively within the sandbox.
3. **Session Extraction**: Once a successful authentication state is reached, the application extracts the active session cookies directly from the macOS native cookie store.
4. **Execution Handoff**: The graphical UI is immediately terminated, handing the state and execution flow back to the underlying C++ process.
5. **TLS Simulation**: `libcurl` utilizes the extracted cookies to query internal JSON endpoints. By leveraging `curl-impersonate-chrome` (compiled with BoringSSL), the HTTP/2 headers and TLS cipher suites are mathematically indistinguishable from a standard consumer browser, avoiding the handshake rejections commonly triggered by vanilla OpenSSL implementations.
6. **Output**: The application yields the raw JSON response directly to `stdout`.
