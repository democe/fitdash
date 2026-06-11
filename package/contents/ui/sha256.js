.pragma library

// Self-contained SHA-256 for PKCE (S256) in pure QML/JS.
// The QML `Qt` global only offers Qt.md5/Qt.btoa, so we bundle SHA-256 here.
// Public-domain implementation (operates on UTF-8 bytes).

function _rotr(x, n) { return (x >>> n) | (x << (32 - n)); }

// Returns the SHA-256 digest of a byte array as an array of 32 bytes.
function sha256Bytes(bytes) {
    var K = [
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
    ];

    var h = [0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19];

    var msg = bytes.slice();
    var bitLen = msg.length * 8;
    msg.push(0x80);
    while (msg.length % 64 !== 56) {
        msg.push(0x00);
    }
    // 64-bit big-endian length. Length fits well within 32 bits for our inputs,
    // so the high word is always 0.
    for (var i = 7; i >= 0; i--) {
        msg.push((i < 4) ? ((bitLen >>> (i * 8)) & 0xff) : 0x00);
    }

    var w = new Array(64);
    for (var off = 0; off < msg.length; off += 64) {
        for (var t = 0; t < 16; t++) {
            w[t] = (msg[off + t * 4] << 24) | (msg[off + t * 4 + 1] << 16)
                 | (msg[off + t * 4 + 2] << 8) | (msg[off + t * 4 + 3]);
        }
        for (t = 16; t < 64; t++) {
            var s0 = _rotr(w[t - 15], 7) ^ _rotr(w[t - 15], 18) ^ (w[t - 15] >>> 3);
            var s1 = _rotr(w[t - 2], 17) ^ _rotr(w[t - 2], 19) ^ (w[t - 2] >>> 10);
            w[t] = (w[t - 16] + s0 + w[t - 7] + s1) | 0;
        }

        var a = h[0], b = h[1], c = h[2], d = h[3], e = h[4], f = h[5], g = h[6], hh = h[7];

        for (t = 0; t < 64; t++) {
            var S1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
            var ch = (e & f) ^ (~e & g);
            var temp1 = (hh + S1 + ch + K[t] + w[t]) | 0;
            var S0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
            var maj = (a & b) ^ (a & c) ^ (b & c);
            var temp2 = (S0 + maj) | 0;

            hh = g; g = f; f = e; e = (d + temp1) | 0;
            d = c; c = b; b = a; a = (temp1 + temp2) | 0;
        }

        h[0] = (h[0] + a) | 0; h[1] = (h[1] + b) | 0; h[2] = (h[2] + c) | 0; h[3] = (h[3] + d) | 0;
        h[4] = (h[4] + e) | 0; h[5] = (h[5] + f) | 0; h[6] = (h[6] + g) | 0; h[7] = (h[7] + hh) | 0;
    }

    var out = [];
    for (var i = 0; i < 8; i++) {
        out.push((h[i] >>> 24) & 0xff, (h[i] >>> 16) & 0xff, (h[i] >>> 8) & 0xff, h[i] & 0xff);
    }
    return out;
}

// UTF-8 encode an ASCII/Unicode string to a byte array.
function utf8Bytes(str) {
    var bytes = [];
    for (var i = 0; i < str.length; i++) {
        var c = str.charCodeAt(i);
        if (c < 0x80) {
            bytes.push(c);
        } else if (c < 0x800) {
            bytes.push(0xc0 | (c >> 6), 0x80 | (c & 0x3f));
        } else if (c < 0xd800 || c >= 0xe000) {
            bytes.push(0xe0 | (c >> 12), 0x80 | ((c >> 6) & 0x3f), 0x80 | (c & 0x3f));
        } else {
            // Surrogate pair.
            i++;
            var cp = 0x10000 + (((c & 0x3ff) << 10) | (str.charCodeAt(i) & 0x3ff));
            bytes.push(0xf0 | (cp >> 18), 0x80 | ((cp >> 12) & 0x3f),
                       0x80 | ((cp >> 6) & 0x3f), 0x80 | (cp & 0x3f));
        }
    }
    return bytes;
}

// Base64url-encode a byte array without padding.
function base64UrlNoPad(bytes) {
    var chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";
    var out = "";
    for (var i = 0; i < bytes.length; i += 3) {
        var b0 = bytes[i];
        var b1 = i + 1 < bytes.length ? bytes[i + 1] : 0;
        var b2 = i + 2 < bytes.length ? bytes[i + 2] : 0;
        var triplet = (b0 << 16) | (b1 << 8) | b2;
        out += chars[(triplet >> 18) & 0x3f];
        out += chars[(triplet >> 12) & 0x3f];
        if (i + 1 < bytes.length) out += chars[(triplet >> 6) & 0x3f];
        if (i + 2 < bytes.length) out += chars[triplet & 0x3f];
    }
    return out;
}

// PKCE S256 challenge: BASE64URL(SHA256(ASCII(verifier))), no padding.
function pkceChallenge(verifier) {
    return base64UrlNoPad(sha256Bytes(utf8Bytes(verifier)));
}
