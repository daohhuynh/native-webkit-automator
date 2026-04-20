#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#include <iostream>
#include <string>

// Global variables
std::string g_json_result = "";
NSString *g_email = @"";
NSString *g_password = @"";

@interface AppDelegate : NSObject <NSApplicationDelegate, WKNavigationDelegate, WKScriptMessageHandler, NSWindowDelegate>
@property (strong) NSWindow *window;
@property (strong) WKWebView *webView;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    
    NSRect frame = NSMakeRect(0, 0, 450, 700);
    self.window = [[NSWindow alloc] initWithContentRect:frame
                                              styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable)
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    [self.window center];
    [self.window setTitle:@"Native OS Web Automation Sandbox"];
    self.window.delegate = self;
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];

    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    [config.userContentController addScriptMessageHandler:self name:@"interceptor"];
    
    // --- STAGE 1: THE WIRETAP ---
    NSString *wiretapJS = @"\n"
    "const originalFetch = window.fetch;\n"
    "window.fetch = async function(...args) {\n"
    "    const response = await originalFetch.apply(this, args);\n"
    "    let url = args[0] && typeof args[0] === 'string' ? args[0] : (args[0] && args[0].url ? args[0].url : '');\n"
    "    if (url.includes('orders') || url.includes('graphql')) {\n"
    "        response.clone().text().then(data => {\n"
    "            if (data && data.includes('{')) window.webkit.messageHandlers.interceptor.postMessage(data);\n"
    "        }).catch(e => {});\n"
    "    }\n"
    "    return response;\n"
    "};\n";

    WKUserScript *wiretapScript = [[WKUserScript alloc] initWithSource:wiretapJS injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO];
    [config.userContentController addUserScript:wiretapScript];

    self.webView = [[WKWebView alloc] initWithFrame:frame configuration:config];
    self.webView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.webView.navigationDelegate = self;
    
    [self.window.contentView addSubview:self.webView];

    // Force navigation to the orders page. If not logged in, TM will auto-redirect to the login page.
    NSURL *url = [NSURL URLWithString:@"https://target-application.example.com/dashboard"];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    [self.webView loadRequest:request];
}

// --- STAGE 2: THE AUTO-TYPER & REACT HIJACK ---
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    NSString *currentURL = webView.URL.absoluteString;
    
    // If we are on the login screen, inject the automation script
    if ([currentURL containsString:@"auth.example.com"] || [currentURL containsString:@"login"]) {
        std::cout << "[*] Login screen detected. Injecting React DOM bypass..." << std::endl;
        
        // This script bypasses React's Synthetic Events by invoking native setters
        NSString *autoFillJS = [NSString stringWithFormat:@"\n"
        "function setReactValue(selector, value) {\n"
        "    let el = document.querySelector(selector);\n"
        "    if (!el) return false;\n"
        "    let lastValue = el.value;\n"
        "    el.value = value;\n"
        "    let event = new Event('input', { bubbles: true });\n"
        "    let tracker = el._valueTracker;\n"
        "    if (tracker) { tracker.setValue(lastValue); }\n"
        "    el.dispatchEvent(event);\n"
        "    return true;\n"
        "}\n"
        "setTimeout(() => {\n"
        "    /* Fill Email */\n"
        "    if(setReactValue('input[type=\"email\"], input[name=\"email\"]', '%@')) {\n"
        "        /* Click Next/Submit */\n"
        "        setTimeout(() => {\n"
        "            let btn = document.querySelector('button[type=\"submit\"], #sign-in-button');\n"
        "            if (btn) btn.click();\n"
        "        }, 1000);\n"
        "    }\n"
        "    /* Fill Password (if it appears on same or next screen) */\n"
        "    setTimeout(() => {\n"
        "        if(setReactValue('input[type=\"password\"], input[name=\"password\"]', '%@')) {\n"
        "            setTimeout(() => {\n"
        "                let btn = document.querySelector('button[type=\"submit\"], #sign-in-button');\n"
        "                if (btn) btn.click();\n"
        "            }, 1000);\n"
        "        }\n"
        "}, 2500);\n"
        "}, 2000);\n", g_email, g_password];

        [self.webView evaluateJavaScript:autoFillJS completionHandler:nil];
    }
}

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if ([message.body isKindOfClass:[NSString class]]) {
        NSString *bodyStr = (NSString *)message.body;
        if ([bodyStr containsString:@"orders"] || [bodyStr containsString:@"id"]) {
            g_json_result = [bodyStr UTF8String];
            [NSApp stop:nil];
            NSEvent *event = [NSEvent otherEventWithType:NSEventTypeApplicationDefined location:NSMakePoint(0,0) modifierFlags:0 timestamp:0 windowNumber:0 context:nil subtype:0 data1:0 data2:0];
            [NSApp postEvent:event atStart:YES];
            [self.window close];
        }
    }
}

- (void)windowWillClose:(NSNotification *)notification {
    [NSApp stop:nil];
    NSEvent *event = [NSEvent otherEventWithType:NSEventTypeApplicationDefined location:NSMakePoint(0,0) modifierFlags:0 timestamp:0 windowNumber:0 context:nil subtype:0 data1:0 data2:0];
    [NSApp postEvent:event atStart:YES];
}
@end

int main(int argc, const char * argv[]) {
    if (argc < 3) {
        std::cerr << "[!] Usage: ./sandbox <email> <password>" << std::endl;
        return 1;
    }
    
    g_email = [NSString stringWithUTF8String:argv[1]];
    g_password = [NSString stringWithUTF8String:argv[2]];

    std::cout << "[*] Spawning Native OS WebKit Sandbox (Automated)..." << std::endl;
    
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        AppDelegate *delegate = [[AppDelegate alloc] init];
        [app setDelegate:delegate];
        [app run]; 
    }

    if (g_json_result.empty()) {
        std::cerr << "[!] FATAL: Window closed before network traffic was intercepted." << std::endl;
        return 1;
    }

    std::cout << "\n[+] PAYLOAD INTERCEPTED SUCCESSFULLY.\n";
    std::cout << "\n--- EXTRACTED JSON DATA ---\n";
    std::cout << g_json_result << std::endl;
    return 0;
}
