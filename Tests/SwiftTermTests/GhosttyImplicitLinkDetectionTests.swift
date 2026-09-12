//
//  GhosttyImplicitLinkDetectionTests.swift
//
//
//  Created by Codex on 2/26/26.
//

import Foundation
import Testing

@testable import SwiftTerm

final class GhosttyImplicitLinkDetectionTests: TerminalDelegate {
    func send(source: Terminal, data: ArraySlice<UInt8>) {
    }

    private func makeTerminal(for input: String) -> Terminal {
        let cols = max(256, input.count + 8)
        return Terminal(delegate: self, options: TerminalOptions(cols: cols, rows: 1))
    }

    private func assertImplicitMatch(input: String, expected: String) {
        let terminal = makeTerminal(for: input)
        terminal.feed(text: input)

        guard let expectedRange = input.range(of: expected) else {
            Issue.record("expected match not found in input: \(expected)")
            return
        }

        let expectedStart = input.distance(from: input.startIndex, to: expectedRange.lowerBound)
        let hitOffset = expectedStart + min(1, max(expected.count - 1, 0))
        let link = terminal.link(at: .buffer(Position(col: hitOffset, row: 0)), mode: .explicitAndImplicit)
        #expect(link == expected)
    }

    private func assertNoImplicitMatch(input: String) {
        let terminal = makeTerminal(for: input)
        terminal.feed(text: input)

        let colsToCheck = max(1, input.count)
        for col in 0..<colsToCheck {
            let link = terminal.link(at: .buffer(Position(col: col, row: 0)), mode: .explicitAndImplicit)
            #expect(link == nil)
        }
    }

    @Test func testGhosttyStyleImplicitPositiveCases() {
        let cases: [(String, String)] = [
            ("hello https://example.com world", "https://example.com"),
            ("https://example.com/foo(bar) more", "https://example.com/foo(bar)"),
            ("https://example.com/foo(bar)baz more", "https://example.com/foo(bar)baz"),
            ("Link inside (https://example.com) parens", "https://example.com"),
            ("Link period https://example.com. More text.", "https://example.com"),
            ("Link trailing comma https://example.com, more text.", "https://example.com"),
            ("Link in double quotes \"https://example.com\" and more", "https://example.com"),
            ("Link in single quotes 'https://example.com' and more", "https://example.com"),
            ("some file with https://google.com https://duckduckgo.com links.", "https://google.com"),
            ("and links in it. links https://yahoo.com mailto:test@example.com ssh://1.2.3.4", "https://yahoo.com"),
            ("also match http://example.com non-secure links", "http://example.com"),
            ("match tel://+12123456789 phone numbers", "tel://+12123456789"),
            ("match tel:+18005551234 tel links", "tel:+18005551234"),
            ("match with query url https://example.com?query=1&other=2 and more text.", "https://example.com?query=1&other=2"),
            ("url with dashes [mode 2027](https://github.com/contour-terminal/terminal-unicode-core) for better unicode support", "https://github.com/contour-terminal/terminal-unicode-core"),
            ("dot.http://example.com", "http://example.com"),
            ("weird characters https://example.com/~user/?query=1&other=2#hash and more", "https://example.com/~user/?query=1&other=2#hash"),
            ("square brackets https://example.com/[foo] and more", "https://example.com/[foo]"),
            ("[13]:TooManyStatements: TempFile#assign_temp_file_to_entity has approx 7 statements [https://example.com/docs/Too-Many-Statements.md]", "https://example.com/docs/Too-Many-Statements.md"),
            ("match ftp://example.com ftp links", "ftp://example.com"),
            ("match file://example.com file links", "file://example.com"),
            ("match ssh://example.com ssh links", "ssh://example.com"),
            ("match git://example.com git links", "git://example.com"),
            ("/tmp/test.txt http://www.google.com", "/tmp/test.txt"),
            ("match news:comp.infosystems.www.servers.unix news links", "news:comp.infosystems.www.servers.unix"),
            ("Serving HTTP on :: port 8000 (http://[::]:8000/)", "http://[::]:8000/"),
            ("IPv6 address https://[2001:db8::1]:8080/path", "https://[2001:db8::1]:8080/path"),
            ("IPv6 address https://[2001:db8::1]:8080(foo)", "https://[2001:db8::1]:8080"),
            ("../example.py", "../example.py"),
            ("../example.py ", "../example.py "),
            ("first time ../example.py contributor ", "../example.py"),
            ("src/config/url.zig", "src/config/url.zig"),
            ("app/folder/file.rb:1", "app/folder/file.rb:1"),
            ("lib/ghostty/terminal.zig:42:10", "lib/ghostty/terminal.zig:42:10"),
            ("~/foo/bar.txt", "~/foo/bar.txt"),
            ("$HOME/src/config/url.zig", "$HOME/src/config/url.zig"),
            ("foo/$BAR/baz", "foo/$BAR/baz"),
            (".foo/bar/$VAR", ".foo/bar/$VAR"),
            (".config/ghostty/config", ".config/ghostty/config"),
            ("loaded from .local/share/ghostty/state.db now", ".local/share/ghostty/state.db"),
            ("  - shared/src/foo/SomeItem.m:12, shared/src/", "shared/src/foo/SomeItem.m:12"),
            ("foo.local/share", "foo.local/share"),
            ("2024/report.txt", "2024/report.txt"),
            ("./spaces-end.   ", "./spaces-end.   "),
            ("./space middle", "./space middle")
        ]

        for (input, expected) in cases {
            assertImplicitMatch(input: input, expected: expected)
        }
    }

    @Test func testSchemeURLWithLongTrailingPunctuation() {
        let url = "https://example.com/a/b/c"
        let input = url + String(repeating: ".", count: 20)

        assertImplicitMatch(input: input, expected: url)
    }

    @Test func testGhosttyStyleImplicitNoMatchCases() {
        let noMatchCases = [
            "example.com",
            "www.example.com",
            "input/output",
            "foo/bar",
            "$10/bar",
            "$10/$20",
            "$10/bar.txt",
            "foo/bar,baz.txt",
            "foo$BAR/baz.txt",
            "foo~/bar.txt",
            "// foo bar",
            "//foo"
        ]

        for input in noMatchCases {
            assertNoImplicitMatch(input: input)
        }
    }

    @Test func testGhosttyStyleImplicitSpansWrappedRows() {
        let input = "https://example.com/this/is/a/wrapped/link"
        let terminal = Terminal(delegate: self, options: TerminalOptions(cols: 10, rows: 8))
        terminal.feed(text: input)

        let row0 = terminal.link(at: .buffer(Position(col: 2, row: 0)), mode: .explicitAndImplicit)
        #expect(row0 == input)

        let row1 = terminal.link(at: .buffer(Position(col: 2, row: 1)), mode: .explicitAndImplicit)
        #expect(row1 == input)

        let row2 = terminal.link(at: .buffer(Position(col: 2, row: 2)), mode: .explicitAndImplicit)
        #expect(row2 == input)
    }

    /// Feeds `url` split into fixed-width segments each terminated by a hard CRLF
    /// (the EMITTER wrapping the URL itself, e.g. Claude Code's login prompt), in a
    /// terminal WIDER than that width - so the continuation rows are hard lines, NOT
    /// autowrap (`isWrapped == false`). Returns the terminal and the row count.
    @discardableResult
    private func feedEmitterHardWrapped(_ url: String, wrapWidth: Int, cols: Int) -> (Terminal, Int) {
        let terminal = Terminal(delegate: self, options: TerminalOptions(cols: cols, rows: 24))
        var idx = url.startIndex
        var rows = 0
        while idx < url.endIndex {
            let end = url.index(idx, offsetBy: wrapWidth, limitedBy: url.endIndex) ?? url.endIndex
            terminal.feed(text: String(url[idx..<end]))
            idx = end
            rows += 1
            if idx < url.endIndex { terminal.feed(text: "\r\n") }
        }
        return (terminal, rows)
    }

    // A long OAuth URL that the CLI hard-wraps at a fixed width narrower than the
    // terminal must still resolve to the WHOLE URL from any of its rows. This is the
    // Claude Code login case (the wrap width does not reach the terminal's right edge,
    // so the rows are not `isWrapped` and do not meet the edge-continuation threshold).
    @Test func testGhosttyStyleImplicitSpansEmitterHardWrappedRows() {
        let url = "https://claude.com/cai/oauth/authorize?code=true&client_id=9d1c250a-e61b-44d9-88ed-5944d1962f5e&response_type=code&redirect_uri=https%3A%2F%2Fplatform.claude.com%2Foauth%2Fcode%2Fcallback&scope=org%3Acreate_api_key+user%3Aprofile+user%3Ainference+user%3Asessions%3Aclaude_code+user%3Amcp_servers+user%3Afile_upload&code_challenge=p8TxSlIdkqFwx3VeBrEOEXAP28sCUKWiPb9L9aYCsVU&code_challenge_method=S256&state=Q4Jy4J1LhRTQwvATMKUY4Ka_55VC16SDZ9MxcwcJvPo"
        // Two widths: cols just wider than the wrap (100), and a WIDE terminal (200)
        // whose `cols/2` would overshoot the fixed 74-col wrap - the fill-floor cap
        // must still fire there.
        for cols in [100, 200] {
            let (terminal, rows) = feedEmitterHardWrapped(url, wrapWidth: 74, cols: cols)
            // Precondition: these are hard lines, not autowrap continuations.
            for row in 1..<rows {
                #expect(terminal.buffer.lines[row].isWrapped == false)
            }
            // Tapping ANY row of the wrapped URL returns the complete URL.
            for row in 0..<rows {
                let link = terminal.link(at: .buffer(Position(col: 5, row: row)), mode: .explicitAndImplicit)
                #expect(link == url, "cols=\(cols) row \(row) resolved to \(link ?? "nil")")
            }
        }
    }

    // The emitter-hard-wrap group must NOT glue a following prose line onto the URL's
    // final row (a URL whose last segment is long, e.g. `...aaaEND`, followed by
    // `Paste code here...`). The URL rows resolve to the whole URL; the prose row does not.
    @Test func testGhosttyStyleImplicitEmitterWrapDoesNotSwallowTrailingProse() {
        let url = "https://ex.com/" + String(repeating: "a", count: 200) + "END"   // 74,74,70
        let terminal = Terminal(delegate: self, options: TerminalOptions(cols: 100, rows: 24))
        let rows = { () -> Int in
            var idx = url.startIndex, r = 0
            while idx < url.endIndex {
                let end = url.index(idx, offsetBy: 74, limitedBy: url.endIndex) ?? url.endIndex
                terminal.feed(text: String(url[idx..<end])); idx = end; r += 1
                if idx < url.endIndex { terminal.feed(text: "\r\n") }
            }
            return r
        }()
        terminal.feed(text: "\r\nPaste code here and continue onwards now please friend")

        for row in 0..<rows {
            #expect(terminal.link(at: .buffer(Position(col: 5, row: row)), mode: .explicitAndImplicit) == url)
        }
        // The prose row must not resolve to the URL (or an ex.com-prefixed corruption).
        let prose = terminal.link(at: .buffer(Position(col: 5, row: rows)), mode: .explicitAndImplicit)
        #expect(prose != url)
        #expect(!(prose?.hasPrefix("https://ex.com") ?? false))
    }

    // Even prose wrapped to EXACTLY the URL's width W must not be glued onto the URL:
    // prose has interior spaces, a URL fragment does not (the space-free guard).
    @Test func testGhosttyStyleImplicitEmitterWrapRejectsSameWidthProse() {
        let url = "https://ex.com/" + String(repeating: "a", count: 200) + "END"   // rows 74,74,70
        let (terminal, rows) = feedEmitterHardWrapped(url, wrapWidth: 74, cols: 100)
        var prose = "Paste the code shown above into your browser to finish sign in now okay!"
        while prose.count < 74 { prose += "x" }
        prose = String(prose.prefix(74))                 // width 74 == W, has interior spaces
        terminal.feed(text: "\r\n" + prose)

        for row in 0..<rows {
            #expect(terminal.link(at: .buffer(Position(col: 5, row: row)), mode: .explicitAndImplicit) == url)
        }
        let onProse = terminal.link(at: .buffer(Position(col: 5, row: rows)), mode: .explicitAndImplicit)
        #expect(onProse != url)
        #expect(!(onProse?.hasPrefix("https://ex.com") ?? false))
    }

    // A uniform-width NON-URL block (e.g. base64, no scheme) must NOT be grouped into a
    // spurious link by the emitter-hard-wrap path.
    @Test func testGhosttyStyleImplicitEmitterWrapRequiresScheme() {
        let block = String(repeating: "A", count: 60)
        let terminal = Terminal(delegate: self, options: TerminalOptions(cols: 100, rows: 24))
        terminal.feed(text: block + "\r\n" + block + "\r\n" + block)
        for row in 0..<3 {
            #expect(terminal.link(at: .buffer(Position(col: 5, row: row)), mode: .explicitAndImplicit) == nil)
        }
    }

    // A URL a CLI hard-wraps at a NARROW fixed width (e.g. a phone terminal wrapping at
    // ~20 cols) must still resolve to the whole URL - the wrap-width floor adapts down.
    @Test func testGhosttyStyleImplicitEmitterWrapNarrowWidth() {
        let url = "https://ex.com/" + String(repeating: "a", count: 80)
        let (terminal, rows) = feedEmitterHardWrapped(url, wrapWidth: 20, cols: 40)
        for row in 0..<rows {
            #expect(terminal.link(at: .buffer(Position(col: 3, row: row)), mode: .explicitAndImplicit) == url)
        }
    }

    // A wrapped URL whose CONTINUATION row happens to begin with an embedded bare-colon
    // sub-scheme (e.g. `tel:` inside a query) must NOT be treated as a new link and
    // truncated - only a real `<scheme>://` prefix marks a new URL.
    @Test func testGhosttyStyleImplicitEmitterWrapKeepsEmbeddedSubScheme() {
        // Build so a continuation row starts with "tel:".
        let url = "https://x.com/" + String(repeating: "a", count: 134) + "tel:+15550001112223334445556"
        let (terminal, rows) = feedEmitterHardWrapped(url, wrapWidth: 74, cols: 100)
        for row in 0..<rows {
            #expect(terminal.link(at: .buffer(Position(col: 3, row: row)), mode: .explicitAndImplicit) == url)
        }
    }

    // Guard against over-joining: two ADJACENT but INDEPENDENT URLs on hard lines must
    // NOT be stitched into one (the lower row starts a fresh scheme).
    @Test func testGhosttyStyleImplicitDoesNotJoinIndependentURLs() {
        let terminal = Terminal(delegate: self, options: TerminalOptions(cols: 100, rows: 24))
        terminal.feed(text: "https://example.com/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\r\n")
        terminal.feed(text: "https://evil.example.org/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")

        let top = terminal.link(at: .buffer(Position(col: 5, row: 0)), mode: .explicitAndImplicit)
        #expect(top == "https://example.com/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
        let bottom = terminal.link(at: .buffer(Position(col: 5, row: 1)), mode: .explicitAndImplicit)
        #expect(bottom == "https://evil.example.org/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
    }
}
