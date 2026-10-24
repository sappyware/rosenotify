.pragma library

var ESCAPES = { n: "\n", t: "\t", r: "\r", b: "\b", f: "\f", '"': '"', "\\": "\\" }

function parse(text) {
    var root = {}
    var current = root
    var lines = text.split(/\r?\n/)
    var index = 0

    while (index < lines.length) {
        var line = stripComment(lines[index++]).trim()

        if (line === "")
            continue

        if (line.indexOf("[[") === 0) {
            current = pushTable(root, splitKey(line.slice(2, line.lastIndexOf("]]"))))
            continue
        }

        if (line[0] === "[") {
            current = ensureTable(root, splitKey(line.slice(1, line.lastIndexOf("]"))))
            continue
        }

        var equals = findEquals(line)

        if (equals < 0)
            throw new Error("line " + index + ": expected key = value")

        var raw = line.slice(equals + 1).trim()

        while (depth(raw) > 0 && index < lines.length)
            raw += "\n" + stripComment(lines[index++]).trim()

        assign(current, splitKey(line.slice(0, equals)), parseValue(raw))
    }

    return root
}

function scan(text, visit) {
    var quote = ""

    for (var i = 0; i < text.length; i++) {
        var ch = text[i]

        if (quote) {
            if (ch === "\\" && quote === '"')
                i++
            else if (ch === quote)
                quote = ""
        } else if (ch === '"' || ch === "'") {
            quote = ch
        } else if (visit(ch, i) === false) {
            return
        }
    }
}

function stripComment(text) {
    var end = text.length

    scan(text, function (ch, i) {
        if (ch === "#") {
            end = i
            return false
        }
    })

    return text.slice(0, end)
}

function findEquals(text) {
    var found = -1

    scan(text, function (ch, i) {
        if (ch === "=") {
            found = i
            return false
        }
    })

    return found
}

function depth(text) {
    var level = 0

    scan(text, function (ch) {
        if (ch === "[" || ch === "{")
            level++
        else if (ch === "]" || ch === "}")
            level--
    })

    return level
}

function splitKey(text) {
    var parts = []
    var buffer = ""
    var quote = ""

    for (var i = 0; i < text.length; i++) {
        var ch = text[i]

        if (quote) {
            if (ch === quote)
                quote = ""
            else
                buffer += ch
        } else if (ch === '"' || ch === "'") {
            quote = ch
        } else if (ch === ".") {
            parts.push(buffer.trim())
            buffer = ""
        } else {
            buffer += ch
        }
    }

    parts.push(buffer.trim())
    return parts
}

function ensureTable(root, path) {
    var node = root

    for (var i = 0; i < path.length; i++) {
        var key = path[i]

        if (node[key] === undefined)
            node[key] = {}

        node = Array.isArray(node[key]) ? node[key][node[key].length - 1] : node[key]
    }

    return node
}

function pushTable(root, path) {
    var parent = ensureTable(root, path.slice(0, -1))
    var key = path[path.length - 1]
    var table = {}

    if (!Array.isArray(parent[key]))
        parent[key] = []

    parent[key].push(table)
    return table
}

function assign(table, path, value) {
    ensureTable(table, path.slice(0, -1))[path[path.length - 1]] = value
}

function parseValue(text) {
    return readValue({ s: text, i: 0 })
}

function skipSpace(c) {
    while (c.i < c.s.length && /\s/.test(c.s[c.i]))
        c.i++
}

function readValue(c) {
    skipSpace(c)

    var ch = c.s[c.i]

    if (ch === '"')
        return readBasicString(c)

    if (ch === "'")
        return readLiteralString(c)

    if (ch === "[")
        return readArray(c)

    if (ch === "{")
        return readInline(c)

    return readScalar(c)
}

function readBasicString(c) {
    var out = ""
    c.i++

    while (c.i < c.s.length && c.s[c.i] !== '"') {
        var ch = c.s[c.i++]

        if (ch !== "\\") {
            out += ch
            continue
        }

        var escape = c.s[c.i++]

        if (escape === "u") {
            out += String.fromCharCode(parseInt(c.s.substr(c.i, 4), 16))
            c.i += 4
        } else {
            out += ESCAPES[escape] !== undefined ? ESCAPES[escape] : escape
        }
    }

    c.i++
    return out
}

function readLiteralString(c) {
    var end = c.s.indexOf("'", c.i + 1)

    if (end < 0)
        throw new Error("unterminated string")

    var out = c.s.slice(c.i + 1, end)
    c.i = end + 1
    return out
}

function readArray(c) {
    var list = []
    c.i++

    for (;;) {
        skipSpace(c)

        if (c.i >= c.s.length)
            throw new Error("unterminated array")

        if (c.s[c.i] === "]") {
            c.i++
            return list
        }

        if (c.s[c.i] === ",") {
            c.i++
            continue
        }

        list.push(readValue(c))
    }
}

function readInline(c) {
    var table = {}
    c.i++

    for (;;) {
        skipSpace(c)

        if (c.i >= c.s.length)
            throw new Error("unterminated inline table")

        if (c.s[c.i] === "}") {
            c.i++
            return table
        }

        if (c.s[c.i] === ",") {
            c.i++
            continue
        }

        var start = c.i

        while (c.i < c.s.length && c.s[c.i] !== "=")
            c.i++

        var path = splitKey(c.s.slice(start, c.i))
        c.i++
        assign(table, path, readValue(c))
    }
}

function readScalar(c) {
    var start = c.i

    while (c.i < c.s.length && !/[\s,\]}]/.test(c.s[c.i]))
        c.i++

    var token = c.s.slice(start, c.i)

    if (token === "")
        throw new Error("missing value")

    if (token === "true")
        return true

    if (token === "false")
        return false

    var number = Number(token.replace(/_/g, ""))
    return isNaN(number) ? token : number
}
