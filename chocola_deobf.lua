--[[
  Script deobfuscated from MoonVeil 2.0.20
  ─────────────────────────────────────────
  Architecture: two-layer obfuscation

  OUTER LAYER (this file)
    A custom Lua VM (MoonVeil runtime) with:
      • base-85 decoder (k / j / i functions)
      • XOR string decryptor (h / g functions)
      • custom bytecode deserialiser (m / l functions)
      • virtual machine execution loop (z / y / x functions)
      • constant-obfuscation helpers (N M G H J I L)

  INNER LAYER (15 157 bytes, see inner_payload.bin)
    MoonVeil custom bytecode.  Instruction format:
      16-bit big-endian word per instruction
      bits [4:0]  = opcode  (up to 32 unique opcodes)
      bits [15:5] = argument
    First bytes of payload: ff01560000eb0dc7

  Runtime API used (Roblox / Luau specific):
    table.create, getfenv, bit32.*, string.unpack

  Transformations applied:
    1. 0bXXX binary literals → decimal
    2. Small 0xNN hex literals → decimal
    3. x[2][x[3]] deref pattern → x[1]
    4. 290 VM constants resolved (T.K/T.F folding)
    5. T.i"…" base-85 strings → decoded UTF-8
    6. Top-level table split into labelled sections
--]]

-- ┌─────────────────────────────────────────────────────────────┐
-- │  MoonVeil runtime object  (read-only; executes inner code)  │
-- └─────────────────────────────────────────────────────────────┘
local MoonVeil = {}

-- ── Helper: create upvalue-box closure
MoonVeil.A = function(d, i)
  return function(g, f)
    local _, e, h, j g = {[3] = 1, [1] = g} g[2] = g f = {[3] = 1, [1] = f} f[2] = f _ = {[3] = 1, [1] = _} _[2] = _ _[1] = d:B{i[1]} j = {[3] = 1, [1] = j} j[2] = j j[1] = d:D{j} h = {[3] = 1, [1] = h} h[2] = h h[1] = d:C{i[2], i[3], j, i[4], _, i[5], f, i[6], i[7], i[8], i[9]} e = d:E{i[10], i[6], g, i[5], _, i[11], h, j, i[12]}
    return e
  end
end


-- ── Constant gen N:  K[d] = bxor(b, 0xd917) / bxor(c, 0x523)
MoonVeil.N = function(a, b, c, d) a.K[d] = a.a(b, 0xd917) / a.a(c, 0x523)
  return a.K[d]
end


-- ── Base-85 chunk decoder: 5 chars → 32-bit BE → 4 bytes
MoonVeil.k = function(d, p)
  return function(g)
    local c, o, a, h, l, f, _, j, n, k, e, b, m b = 233
    while true do
      if b > 162 then
        j, f, o, _ = 5, 0, 1, 1 b = (j ~= j or o > 0 and _ > j or (o <= 0 or o ~= o) and _ < j) and 147 or 51
      elseif b > 147 then
        _ = _ + o b = (o > 0 and _ > j or o <= 0 and _ < j or o ~= o) and 0x5d06 / b or 213 - b
      elseif b <= 51 then
        a = 85 a, n, m, l, c, h = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz!#$%&()*+-;<=>?@^_`{|}~", g, _, g.sub, f * a, _ l = l(n, h, m) h, n, a, k = true , 1, a.find, a b, a = 213 - b, a(k, l, n, h) c, e = 1, c + a f = e - c
      else
        j, o, _, e = p[2][1], f, p[1][1], 24 j = j(o, e) c, a, o, e = f, 16, p[3][1], p[2][1] e = e(c, a) c = 255 o = o(e, c) e, c, a, k = p[3][1], p[2][1], f, 8 c = c(a, k) a = 255 e = e(c, a) k, c, a = 255, p[3][1], f c = d.c(c(a, k)) _ = d.c(_(j, o, e, d.d(c)))
        return d.d(_)
      end
    end
  end
end


-- ── d = vararg unpacker: unpack(tbl[1], 1, tbl[2])
MoonVeil.d = (function()local function m(i,j,k)if j>k then return end return i[j],m(i,j+1,k)end return function(o)return m(o[1],1,o[2])end end)()

-- ── Helper: wrap varargs as {args, count}
MoonVeil.B = function(_, a)
  return function( ... )
    return { ... }, a[1][2][a[1][3]]("#", ... )
  end
end


-- ── Constant gen I:  F[d] = a.g(b, c)  [XOR decrypt]
MoonVeil.I = function(a, b, c, d) a.F[d] = a.g(b, c)
  return a.F[d]
end


-- ── XOR string decryptor (inner): byte-by-byte XOR with cycling key
MoonVeil.h = function(d, p)
  return function(g, f)
    local q, j, c, a, l, m, o, k, _, b, n, e b = 195
    repeat
      if b >= 81 then
        if b >= 126 then
          if b > 195 then
            if b <= 204 then
              b = e ~= e and 122 or b + - 129
            else
              b = e > 0 and b + - 131 or 204
            end
          elseif b > 194 then
            a, _, j, c = 1, "", 0, #g e, o = 1, c - a b = o ~= o and 194 or 249
          elseif b > 126 then
            return _
          else
            b = j < o and 194 or 15
          end
        elseif b >= 122 then
          if b <= 122 then
            b = j < o and 0x5c74 / b or 41
          else
            c = c(d.d(a)) b, _ = 0x1ec0 / b, _ .. c
          end
        elseif b <= 81 then
          k = k(l, n) n, l, m = f, p[3][1], #f m, q = 1, j % m b, q = b + - 23, q + m
        else
          b = j > o and 0x596c / b or 204
        end
      elseif b >= 46 then
        if b > 64 then
          b = e <= 0 and b + 47 or 116 - b
        elseif b >= 58 then
          if b > 58 then
            j = j + e b = e > 0 and 32 or b + - 56
          else
            b, l = 46, d.c(l(n, q))
          end
        else
          b, a = 123, d.c(a(k, d.d(l)))
        end
      elseif b < 32 then
        if b > 8 then
          b = e ~= e and b + 179 or 41
        else
          b = e <= 0 and 126 or 15
        end
      elseif b <= 32 then
        b = j > o and 194 or 8
      else
        b, n, a, c, l, k = 81, 1, p[2][1], p[1][1], g, p[3][1] n = j + n
      end
    until false
  end
end


-- ── VM executor
MoonVeil.x = function(d)
  local t, b, n, l, x, k, g, v, j, i, c, r, w, e, z, q, h, m, y, _, f, o, u g = d g = {[3] = 1, [1] = g} g[2] = g r = type r = {[3] = 1, [1] = r} r[2] = r _ = pcall _ = {[3] = 1, [1] = _} _[2] = _ j = error j = {[3] = 1, [1] = j} j[2] = j v, o = select, tonumber v = {[3] = 1, [1] = v} v[2] = v c = setmetatable c = {[3] = 1, [1] = c} c[2] = c z = getmetatable z = {[3] = 1, [1] = z} z[2] = z u, w = "vs", {} w.__mode = u y = w y = {[3] = 1, [1] = y} y[2] = y u = string w = u.unpack w = {[3] = 1, [1] = w} w[2] = w q = u m, u = q, q.byte q, i = m.char, table m = i.move m = {[3] = 1, [1] = m} m[2] = m t = i i = t.pack i = {[3] = 1, [1] = i} i[2] = i f = t t = f.create t = {[3] = 1, [1] = t} t[2] = t b = f f = b.insert f = {[3] = 1, [1] = f} f[2] = f b = getfenv b = {[3] = 1, [1] = b} b[2] = b n = bit32 h = n.bor h = {[3] = 1, [1] = h} h[2] = h e = n n, l = e.bxor, e e = l.band e = {[3] = 1, [1] = e} e[2] = e x = l l = x.btest l = {[3] = 1, [1] = l} l[2] = l k = x x = k.lshift x = {[3] = 1, [1] = x} x[2] = x k = d:y{w, h, x, e, l, t, f, g, b, v, c, y, m, r, z, i, _, j}
  return k
end


-- ── Constant gen H:  F[d] = bxor(b, 0xc0c5) / bxor(c, 0xf57d)
MoonVeil.H = function(a, b, c, d) a.F[d] = a.a(b, 0xc0c5) / a.a(c, 0xf57d)
  return a.F[d]
end


-- ── b = iterator adapter (pairs / __iter / callable)
MoonVeil.b = function(n, o, p)
  if type(n) ~= "function" then
    local k = getmetatable(n)
    if k ~= nil and k.__iter ~= nil then
      return k.__iter(n)
    elseif(k and k.__call) == nil and type(n) == "table" then
      return pairs(n)
    end
  end
  return n, o, p
end


-- ── c = vararg packer: returns {[1]={...}, [2]=n}
MoonVeil.c = function( ... )
  return {[1] = { ... }, [2] = select("#", ... )}
end


-- ── VM call dispatcher
MoonVeil.y = function(d, i)
  return function(g, f)
    local c, _, b, h, e, j b = 144
    while true do
      if b > 146 then
        if b > 168 then
          b, _ = 135, _() _ = {[3] = 1, [1] = _} _[2] = _ j[1] = {[3] = 1, [1] = j[1]} j[1][2] = j[1] j[1] = d:A{i[10], i[11], i[12], _, i[13], i[6], j, i[14], i[15], i[16], i[17], i[18]} h[1], c, e[1] = j[1], f, g
        else
          b, _ = 228, i[9][1]
        end
      elseif b > 144 then
        c = c() b, g = 168, c
      elseif b > 135 then
        _ = g j = _ j = {[3] = 1, [1] = j} j[2] = j h = 1 h = {[3] = 1, [1] = h} h[2] = h e = nil b, e = 146, {[3] = 1, [1] = e} e[2] = e e[1] = d:z{i[1], j, h, i[2], i[3], i[4], i[5], i[6], i[7], i[8], e} c = e[1]
      else
        h[1] = h[1](e[1], c)
        return h[1]
      end
    end
  end
end


-- ── Main VM execution loop (runs one bytecode function prototype)
MoonVeil.z = function(T, p)
  return function()
    local x, U, na, _, G, ka, y, R, oa, I, a, j, D, E, _a, ga, pa, i, s, J, k, ma, t, r, ia, Y, v, n, M, ca, K, z, A, O, ra, l, qa, c, d, aa, m, ja, H, ha, F, g, ea, la, P, S, e, da, q, sa, u, W, fa, o, V, f, B, C, w, b, ba, h, N, X, Q s = 247 repeat
    if s <= 496 then
      if s > 212 then
        if s < 345 then
          if s > 262 then
            if s >= 297 then
              if s > 321 then
                if s > 335 then
                  if s > 341 then
                    Y = 124 s = w <= Y and 0x16570 / s or 405 elseif s > 336 then
                      s = M > 0 and (849) or 880 else s = oa > 0 and 0x533 - s or 831 end
                    elseif s <= 334 then
                      if s >= 326 then
                        if s > 326 then
                          s, b, da, H, U = 884, p[3][1], "B", p[2][1], p[1][1]
                        else
                          ha = ha(W, F) s, W = 739, 7 W = H * W
                        end
                      else
                        s, C = 0x21d - s, 72
                      end
                    else
                      C = 68 s = ja >= C and (218) or 0x23c - s
                    end
                  elseif s <= 313 then
                    if s >= 311 then
                      if s > 312 then
                        C = 203 s = K > C and 0x46ea / s or 0x213 - s
                      elseif s <= 311 then
                        s = M > 0 and s + 460 or 0x348 - s
                      else
                        S = S(ba, e) b = not S s = b and (351) or 584 end
                      elseif s <= 297 then
                        fa = fa + C s = C > 0 and (870) or 689 else C = 185 s = R >= C and s + 448 or 0x20b - s
                      end
                    elseif s <= 320 then
                      if s <= 314 then
                        s = C ~= C and (850) or 708 else H = 0 s = da == H and (674) or 0x43940 / s
                      end
                    else
                      s = fa > 0 and s + 142 or 0x331 - s
                    end
                  elseif s >= 280 then
                    if s >= 291 then
                      if s > 294 then
                        s, Y[0xb55f] = 0x434 - s, M
                      elseif s >= 293 then
                        if s <= 293 then
                          na = na(x, ha, W) ha, x = 1, p[3][1] x = x + ha s, e, p[3][1] = 0x2b5 - s, na, x
                        else
                          da, s, b, U, H = "B", 726, p[3][1], p[1][1], p[2][1]
                        end
                      else
                        s = M ~= M and (998) or 454 end
                      elseif s > 287 then
                        s = M > U and 0x2f21c / s or 1001 elseif s < 282 then
                          s, b = 452 - s, T.c(b(S, ba))
                        elseif s <= 282 then
                          s, C = 218, 72
                        else
                          C = 206 s = d <= C and 505 - s or 0x7498 / s
                        end
                      elseif s <= 266 then
                        if s > 265 then
                          s, C = 218, 68
                        elseif s >= 264 then
                          if s <= 264 then
                            s = ba ~= ba and (28) or 152 else s, b = 0x3011f / s, b(S, ba, e) S = p[3][1] S = S + da U, p[3][1] = b, S
                          end
                        else
                          U = U(da, H, b) da, H = p[3][1], 2 da = da + H p[3][1], M = da, U s = m > H and s + 289 or s + 478
                        end
                      elseif s >= 271 then
                        if s <= 271 then
                          s, C = 489 - s, 68
                        else
                          s = da ~= da and (861) or 451 end
                        else
                          s, C = 218, 68
                        end
                      elseif s > 236 then
                        if s < 248 then
                          if s >= 244 then
                            if s > 246 then
                              ra, ea, j, f, r, s, J, _a = 209, 153, p[2][1], 250, p[1][1], 360, "B", p[3][1]
                            elseif s > 245 then
                              U = U(da, H, b) H, s, da = 1, 928, p[3][1] da = da + H M, p[3][1] = U, da
                            elseif s <= 244 then
                              s, C = 218, 218
                            else
                              b, s, da, U, H = p[3][1], 263, '>i2', p[1][1], p[2][1]
                            end
                          elseif s < 238 then
                            Y = 8 s = w < Y and (170) or 21 elseif s > 238 then
                              Y = 232 s = w > Y and s + - 82 or 26 else C = 217 s = B <= C and (218) or 394 end
                            elseif s >= 255 then
                              if s <= 260 then
                                if s >= 259 then
                                  if s > 259 then
                                    s, C = s + - 42, 185
                                  else
                                    w = w(C, Y) fa = not w s = fa and (137) or s + - 115
                                  end
                                else
                                  la = la + fa s = fa > 0 and 0x4ae - s or 695 end
                                else
                                  s = C < Y and (14) or 686 end
                                elseif s > 252 then
                                  s, C = 218, 68
                                elseif s < 249 then
                                  s, Y[0xc0ee] = 1075, M b, U, H, da = p[3][1], p[1][1], p[2][1], "B"
                                elseif s <= 249 then
                                  Y = 50 s = w < Y and 0x8c1 / s or 307 - s
                                else
                                  Y = 175 s = w <= Y and (132) or 196 end
                                elseif s > 223 then
                                  if s < 231 then
                                    if s > 226 then
                                      j = 0 s = J == j and s + - 119 or s + - 133
                                    elseif s >= 225 then
                                      if s > 225 then
                                        fa, G, la, qa, oa, Q = 1, 0, 0, 180, 4, 245 s = oa ~= oa and (13) or 0x223 - s
                                      else
                                        Y = 30 s = w > Y and (253) or 0x15969 / s
                                      end
                                    else
                                      Y = 74 s = w > Y and 255 - s or 259 - s
                                    end
                                  elseif s >= 234 then
                                    if s > 234 then
                                      s = G < la and 323 - s or 45 else U = 1 s = Y == U and 0x254 - s or 0x3645c / s
                                    end
                                  elseif s > 231 then
                                    s, Y[0x71bd] = 2940, M H, U, da, b = p[2][1], p[1][1], "B", p[3][1]
                                  else
                                    s = C > Y and (142) or 363 end
                                  elseif s >= 218 then
                                    if s <= 221 then
                                      if s >= 219 then
                                        if s > 219 then
                                          Y = 236 s = w >= Y and (515) or 0x258d8 / s
                                        else
                                          s = da <= 0 and 414 - s or s + 157
                                        end
                                      else
                                        sa, M, z = 232, {}, 93 M[0xdb48] = w U = 0 M[0x71bd] = U s, U = 0x2261c / s, 0 M[0x80eb] = U U = 0 M[0xc0ee] = U U = 0 M[377] = U U = 0 M[0xb55f] = U U = 0 M[0x3031] = U U = 0 M[0xe074] = U U = 0 M[0xa544] = U U = 0 M[0x220a] = U U = 0 M[0xf74e] = U Y, M, U = M, p[9][1], G da = Y
                                      end
                                    elseif s > 222 then
                                      s, la = 178, oa
                                    else
                                      Y = 128 s = w <= Y and 0x42c6 / s or 151 end
                                    elseif s < 216 then
                                      if s <= 213 then
                                        s, C = 218, 68
                                      else
                                        s = C < Y and 0x76b4 / s or 631 end
                                      elseif s <= 216 then
                                        s = H < b and (797) or 567 else Y = 118 s = w >= Y and (222) or 0x676a / s
                                      end
                                    elseif s >= 409 then
                                      if s >= 462 then
                                        if s > 479 then
                                          if s <= 493 then
                                            if s >= 490 then
                                              if s <= 490 then
                                                Y[0x80eb] = M H, s, b, U, da = p[2][1], 0x480 - s, p[3][1], p[1][1], "B"
                                              else
                                                U = U(da, H) M = not U s = M and (223) or 44 end
                                              elseif s > 481 then
                                                s, e = 0x66404 / s, e(na, T.d(x)) x, da, ha, na = ba, e, 128, p[7][1]
                                              else
                                                s, na = 545, na(x, T.d(ha)) H, W, ha, x = na, 128, e, p[7][1]
                                              end
                                            elseif s >= 495 then
                                              if s <= 495 then
                                                U = U(da, H, b) da, H = p[3][1], 2 s, da = s + 299, da + H p[3][1], M = da, U
                                              else
                                                s = fa ~= fa and 0x45630 / s or 770 end
                                              else
                                                s = C < Y and (7) or 538 end
                                              elseif s <= 470 then
                                                if s < 465 then
                                                  if s <= 462 then
                                                    s, b, da, U, H = s + 457, p[3][1], "B", p[1][1], p[2][1]
                                                  else
                                                    s = la > oa and s + - 450 or 496 end
                                                  elseif s <= 469 then
                                                    if s > 465 then
                                                      s = fa > 0 and (697) or 0x3db77 / s
                                                    else
                                                      s = j < _a and (85) or 745 end
                                                    else
                                                      s = da ~= da and 0x299 - s or 0x2b1 - s
                                                    end
                                                  elseif s >= 475 then
                                                    if s <= 475 then
                                                      s = S <= 0 and 0x190c8 / s or 0x41c0d / s
                                                    else
                                                      s, C = 56, C(Y, M, U) M, Y = 1, p[3][1] Y = Y + M w, p[3][1] = C, Y
                                                    end
                                                  elseif s > 471 then
                                                    da = da(H, b, S) b, H = 1, p[3][1] H = H + b s, U, p[3][1] = s + - 448, da, H
                                                  else
                                                    s, da, H, U, b = 197, "B", p[2][1], p[1][1], p[3][1]
                                                  end
                                                elseif s < 447 then
                                                  if s < 425 then
                                                    if s >= 422 then
                                                      if s > 422 then
                                                        s = H < b and (797) or 978 else s, C = 0x1675c / s, 161
                                                      end
                                                    elseif s <= 409 then
                                                      s, H, da, U, b = 683, p[2][1], "B", p[1][1], p[3][1]
                                                    else
                                                      M = 217 s = C <= M and 0x4aa60 / s or 435 end
                                                    elseif s <= 435 then
                                                      if s <= 430 then
                                                        if s > 425 then
                                                          s = _a > G and 0xe61e / s or 651 else s = S > 0 and (811) or s + 441
                                                        end
                                                      else
                                                        M = 218 s = C <= M and (334) or 409 end
                                                      else
                                                        M, s, Y = C, 0x4d1 - s, p[8][1]
                                                      end
                                                    elseif s >= 454 then
                                                      if s >= 456 then
                                                        if s <= 456 then
                                                          s, Y[0x80eb] = s + 324, M
                                                        else
                                                          s = G > la and (87) or 537 end
                                                        elseif s <= 454 then
                                                          s = M <= 0 and s + 0x220 or 484 - s
                                                        else
                                                          U = U(da, H, b) da, H = p[3][1], 1 s, da = 578, da + H M, p[3][1] = U, da
                                                        end
                                                      elseif s >= 450 then
                                                        if s > 450 then
                                                          s = da <= 0 and (861) or 1021 else s = oa <= 0 and s + - 214 or 45 end
                                                        elseif s <= 447 then
                                                          s = ba > 0 and (801) or 0x5bff5 / s
                                                        else
                                                          M = M(U, da, H) U, da = p[3][1], 1 U = U + da s, Y, p[3][1] = s + - 277, M, U
                                                        end
                                                      elseif s <= 376 then
                                                        if s <= 363 then
                                                          if s <= 356 then
                                                            if s >= 350 then
                                                              if s <= 351 then
                                                                if s <= 350 then
                                                                  s = j < _a and s + - 265 or 78 else s, C = 0x2588a / s, Y
                                                                end
                                                              else
                                                                s, C = 0x23e - s, 161
                                                              end
                                                            elseif s <= 345 then
                                                              C = 68 s = V <= C and (377) or 0x233 - s
                                                            else
                                                              s, C = s + - 130, 185
                                                            end
                                                          elseif s > 362 then
                                                            s = M <= 0 and 0x241 - s or 631 elseif s > 360 then
                                                              s, H, b, S, da = s + 338, "B", p[2][1], p[3][1], p[1][1]
                                                            elseif s <= 357 then
                                                              Y = 199 s = w > Y and 0x296 - s or 1005 else r = r(J, j, _a) s, J, j = 11, p[3][1], 1 J = J + j g, p[3][1] = r, J
                                                            end
                                                          elseif s > 370 then
                                                            if s > 373 then
                                                              S, s, b, ba, e = "B", 939, p[1][1], p[2][1], p[3][1]
                                                            elseif s > 371 then
                                                              s = fa > w and (223) or 314 else s = fa > w and 0x1a16 / s or s + 365
                                                            end
                                                          elseif s >= 369 then
                                                            if s <= 369 then
                                                              w = w(C, T.d(Y)) Y, s, C, M, _a = fa, 0x2f0 - s, p[7][1], 128, w
                                                            else
                                                              s, M = s + 0x272, M(U, da) U = 7 U = G * U
                                                            end
                                                          elseif s <= 365 then
                                                            Y[0x71bd] = M da, s, U, b, H = '>i2', s + 293, p[1][1], p[3][1], p[2][1]
                                                          else
                                                            s = C <= 0 and 0x397 - s or s + - 214
                                                          end
                                                        elseif s >= 392 then
                                                          if s < 400 then
                                                            if s > 394 then
                                                              s, H = 0x515 - s, H() Y[M] = H
                                                            elseif s < 393 then
                                                              s = M > 0 and 0x37b - s or s + - 101
                                                            elseif s <= 393 then
                                                              Y, ma = 28, 67 s = w > Y and s + 0x214 or 0x3e4 - s
                                                            else
                                                              ja, Y = 245, 69 s = w <= Y and 0x5a21a / s or 0x2d9 - s
                                                            end
                                                          elseif s < 405 then
                                                            if s <= 400 then
                                                              F, W, x, s, ha, na, O = e, p[6][1], H, s + - 201, p[5][1], p[4][1], 127
                                                            else
                                                              C = 141 s = ga < C and 0x323 - s or 0x26d - s
                                                            end
                                                          elseif s <= 405 then
                                                            s, C = 218, 72
                                                          else
                                                            s, H = 523, U[0xb55f] da = oa[H] U[0xb55f] = da
                                                          end
                                                        elseif s > 381 then
                                                          if s <= 387 then
                                                            if s > 383 then
                                                              s, C = 218, 68
                                                            else
                                                              C = C(Y, M) w = not C s = w and (87) or s + - 218
                                                            end
                                                          else
                                                            s, ha = 481, T.c(ha(W, F))
                                                          end
                                                        elseif s <= 379 then
                                                          if s <= 378 then
                                                            if s <= 377 then
                                                              s, Y[377] = s + 403, M
                                                            else
                                                              s, C = 218, 185
                                                            end
                                                          else
                                                            s, Y[0x71bd] = 455, M H, U, da, b = p[2][1], p[1][1], "B", p[3][1]
                                                          end
                                                        else
                                                          s = M <= 0 and (969) or 94 end
                                                        elseif s > 128 then
                                                          if s < 165 then
                                                            if s >= 147 then
                                                              if s < 155 then
                                                                if s <= 151 then
                                                                  if s < 149 then
                                                                    if s <= 147 then
                                                                      Y = 151 s = w >= Y and (164) or 146 else s = M <= 0 and 0x9778 / s or 0x18c98 / s
                                                                    end
                                                                  elseif s >= 150 then
                                                                    if s > 150 then
                                                                      s, C = 218, 68
                                                                    else
                                                                      Y = 43 s = w > Y and (182) or s + 0x208
                                                                    end
                                                                  else
                                                                    P, la, G, _a, oa, E = 142, 4, 0, 0, 1, 159 s = la ~= la and (87) or s + 187
                                                                  end
                                                                elseif s >= 153 then
                                                                  if s <= 153 then
                                                                    Y = 199 s = w >= Y and 510 - s or 0x183e1 / s
                                                                  else
                                                                    da, H, M, s, U = p[2][1], p[3][1], p[1][1], 448, "B"
                                                                  end
                                                                else
                                                                  W, x, ha, s, na = p[3][1], "B", p[2][1], 293, p[1][1]
                                                                end
                                                              elseif s >= 159 then
                                                                if s < 163 then
                                                                  if s > 159 then
                                                                    Y = 247 s = w <= Y and (207) or 0xbe0 / s
                                                                  else
                                                                    Y = 52 s = w >= Y and 0x1980f / s or s + 439
                                                                  end
                                                                elseif s <= 163 then
                                                                  s, C = 0x8ace / s, 141
                                                                else
                                                                  Y = 151 s = w <= Y and 0x48f - s or 0x389 - s
                                                                end
                                                              elseif s < 157 then
                                                                if s <= 155 then
                                                                  s, C = 373 - s, 68
                                                                else
                                                                  da = 0 s = U == da and (806) or 857 end
                                                                elseif s > 157 then
                                                                  Y = 36 s = w > Y and (313) or 0xf8ba / s
                                                                else
                                                                  s, G = 0x398 - s, "c" _a, G = G .. j, p[1][1] la, oa, fa = _a, p[2][1], p[3][1]
                                                                end
                                                              elseif s < 137 then
                                                                if s > 133 then
                                                                  if s >= 135 then
                                                                    if s > 135 then
                                                                      M, C, U, B, s, Y, v, h = p[2][1], p[1][1], p[3][1], 188, 577, "B", 221, 70
                                                                    else
                                                                      s = C > 0 and 0xc3a5 / s or s + 0x259
                                                                    end
                                                                  else
                                                                    da, s, U, b, H = T.F[ - 0x2cf9] or T:I('\x05_', ';', - 0x2cf9), 613, p[1][1], p[3][1], p[2][1]
                                                                  end
                                                                elseif s < 132 then
                                                                  if s <= 129 then
                                                                    Y = 157 s = w <= Y and 236 - s or 181 - s
                                                                  else
                                                                    C, s, w = fa, s + 0x2b2, p[8][1]
                                                                  end
                                                                elseif s <= 132 then
                                                                  Y = 172 s = w > Y and (900) or 747 else s, ba = 0x1d28a / s, T.c(ba(e, na))
                                                                end
                                                              elseif s > 142 then
                                                                if s >= 144 then
                                                                  if s <= 144 then
                                                                    _a = _a + la s = la > 0 and (559) or 876 else Y = 148 s = w > Y and (505) or 0x2476e / s
                                                                  end
                                                                else
                                                                  M = 141 s = C >= M and (808) or 509 end
                                                                elseif s < 140 then
                                                                  if s <= 137 then
                                                                    J = j s = u > pa and (229) or s + 271
                                                                  else
                                                                    j, J, _a, k, G = 0, 0, 4, 32, 1 s = _a ~= _a and 223 - s or s + 0x2ee
                                                                  end
                                                                elseif s >= 141 then
                                                                  if s <= 141 then
                                                                    Y = 83 s = w >= Y and (958) or 423 - s
                                                                  else
                                                                    s, fa = 273 - s, w
                                                                  end
                                                                else
                                                                  Y = 43 s = w < Y and (173) or 150 end
                                                                elseif s >= 190 then
                                                                  if s <= 198 then
                                                                    if s < 194 then
                                                                      if s <= 192 then
                                                                        if s >= 191 then
                                                                          if s <= 191 then
                                                                            Y = 145 s = w > Y and (988) or 167 else A, _a, G, la, d, I, c, s, j, n = 0, "B", p[2][1], p[3][1], 110, 55, 45, 911, p[1][1], 29
                                                                          end
                                                                        else
                                                                          Y = 206 s = w <= Y and 477 - s or 734 end
                                                                        else
                                                                          s, J = 72, ""
                                                                        end
                                                                      elseif s >= 196 then
                                                                        if s > 197 then
                                                                          Y = 190 s = w <= Y and s + 0x215 or 353 - s
                                                                        elseif s > 196 then
                                                                          U = U(da, H, b) H, da = 1, p[3][1] da = da + H p[3][1], M = da, U s = c < H and (523) or 0x28419 / s
                                                                        else
                                                                          Y = 180 s = w > Y and s + 0x240 or 0x317 - s
                                                                        end
                                                                      elseif s <= 194 then
                                                                        Y = 11 s = w <= Y and s + 154 or 0x2f5 - s
                                                                      else
                                                                        s = M < U and (351) or 0x23b - s
                                                                      end
                                                                    elseif s > 205 then
                                                                      if s > 209 then
                                                                        oa, w, C, fa, t, aa = 0, 4, 1, 0, 253, 246 s = w ~= w and 0xb8ac / s or s + 411
                                                                      elseif s > 207 then
                                                                        Y = 182 s = w <= Y and s + - 127 or 242 else Y = 242 s = w <= Y and (221) or 210 - s
                                                                      end
                                                                    elseif s > 202 then
                                                                      s = fa < w and (223) or s + 353
                                                                    elseif s > 201 then
                                                                      _, Y = 124, 132 s = w < Y and (249) or 209 elseif s <= 199 then
                                                                        W = W(F, O) F = 7 s, F = 0x24c - s, b * F
                                                                      else
                                                                        Y = 20 s = w <= Y and (59) or 0x58b9 / s
                                                                      end
                                                                    elseif s >= 176 then
                                                                      if s <= 181 then
                                                                        if s >= 178 then
                                                                          if s > 179 then
                                                                            s, oa = 893, oa(fa, T.d(w)) J, C, w, fa = oa, 128, la, p[7][1]
                                                                          elseif s <= 178 then
                                                                            oa, s, fa = p[8][1], 869, la
                                                                          else
                                                                            s, na, e, b, S, x, ba = 0x2a4d8 / s, H, p[6][1], p[4][1], Y, 127, p[5][1]
                                                                          end
                                                                        elseif s > 176 then
                                                                          _a = 0 s = j == _a and s + 16 or 157 else s, C = 218, 68
                                                                        end
                                                                      elseif s < 188 then
                                                                        s, C = 400 - s, 232
                                                                      elseif s > 188 then
                                                                        Y = 32 s = w <= Y and (225) or 0x74a6 / s
                                                                      else
                                                                        Y = 166 s = w >= Y and s + 64 or s + - 59
                                                                      end
                                                                    elseif s <= 171 then
                                                                      if s > 170 then
                                                                        M, U = nil , 2 s = Y == U and 305 - s or 83 elseif s > 167 then
                                                                          Y = 1 s = w > Y and (238) or s + - 137
                                                                        elseif s <= 165 then
                                                                          G = G + oa s = oa > 0 and s + 295 or 0x2be - s
                                                                        else
                                                                          s, C = 218, 185
                                                                        end
                                                                      elseif s > 173 then
                                                                        b, da, s, H, S, M, U = Y, p[5][1], 602, p[6][1], 127, p[4][1], oa
                                                                      elseif s <= 172 then
                                                                        da = da(H, T.d(b)) s, w, S, b, H = 0x25eb4 / s, da, 128, U, p[7][1]
                                                                      else
                                                                        s, C = 218, 148
                                                                      end
                                                                    elseif s >= 59 then
                                                                      if s <= 95 then
                                                                        if s < 80 then
                                                                          if s > 72 then
                                                                            if s > 77 then
                                                                              fa, s, C, w, oa = "B", 727, p[3][1], p[2][1], p[1][1]
                                                                            elseif s <= 74 then
                                                                              Y = 17 s = w < Y and 0x4482 / s or s + 127
                                                                            else
                                                                              Y = 124 s = w >= Y and 421 - s or s + 0x269
                                                                            end
                                                                          elseif s <= 68 then
                                                                            if s >= 62 then
                                                                              if s > 62 then
                                                                                C = 185 s = Q < C and 0x21b - s or 286 - s
                                                                              else
                                                                                la, oa, ga, q, s, _a, G = p[2][1], p[3][1], 169, 161, 788, p[1][1], "B"
                                                                              end
                                                                            else
                                                                              Y = 18 s = w >= Y and (10) or 213 end
                                                                            elseif s > 69 then
                                                                              G, _a = 0, {} _a[0xb17e] = G G = 0 _a[0xf388] = G G = 0 _a[0x3201] = G la = {} G = la _a[0x7baa] = G la = {} G = la _a[0x1788] = G la = {} G = la _a[0x2f57] = G _a[0x2050] = r _a[0x3e73] = J j = _a
                                                                              return j
                                                                            else
                                                                              s, G, K, la = 973, p[8][1], 21, _a
                                                                            end
                                                                          elseif s <= 86 then
                                                                            if s <= 83 then
                                                                              if s > 82 then
                                                                                U = 4 s = Y == U and (125) or s + 151
                                                                              elseif s > 80 then
                                                                                Y = 154 s = w <= Y and (48) or 188 else U, s, M, da, H = "B", 0x357 - s, p[1][1], p[2][1], p[3][1]
                                                                              end
                                                                            elseif s <= 85 then
                                                                              m, s, a, r = 132, 192, 211, J
                                                                            else
                                                                              Y = 198 s = w < Y and s + 13 or 153 end
                                                                            elseif s <= 94 then
                                                                              if s <= 91 then
                                                                                if s > 87 then
                                                                                  s, fa, M, oa, w, C, Y = 562, J, 127, p[4][1], p[5][1], p[6][1], la
                                                                                else
                                                                                  j = _a s = P >= E and 0x78fc / s or 177 end
                                                                                else
                                                                                  U = G[C] da, H = U[0xb55f], 0 s = da ~= H and (408) or 523 end
                                                                                else
                                                                                  da, S, s, b, H = p[1][1], p[3][1], 473, p[2][1], "B"
                                                                                end
                                                                              elseif s >= 110 then
                                                                                if s <= 122 then
                                                                                  if s >= 113 then
                                                                                    if s > 120 then
                                                                                      Y = 106 s = w <= Y and (105) or s + - 88
                                                                                    elseif s > 113 then
                                                                                      Y = 250 s = w > Y and (531) or 378 else Y = 24 s = w > Y and s + - 64 or s + 63
                                                                                    end
                                                                                  elseif s > 110 then
                                                                                    Y = 69 s = w < Y and (544) or s + 283
                                                                                  else
                                                                                    s, r = 149, ""
                                                                                  end
                                                                                elseif s < 125 then
                                                                                  w, U, s, C, M, da, Y = p[4][1], fa, 370, _a, p[6][1], 127, p[5][1]
                                                                                elseif s > 125 then
                                                                                  w, Y, s, fa, C, U, M = j, p[6][1], 0x374 - s, p[4][1], p[5][1], 127, oa
                                                                                else
                                                                                  da, S, b, H = 0, 1, 4, 0 s = b ~= b and (797) or 425 end
                                                                                elseif s >= 104 then
                                                                                  if s >= 106 then
                                                                                    if s > 106 then
                                                                                      Y = 156 s = w >= Y and 0x2cc - s or 267 else j = j + G s = G > 0 and (983) or s + 402
                                                                                    end
                                                                                  elseif s <= 104 then
                                                                                    Y = 229 s = w <= Y and (827) or 0x2de - s
                                                                                  else
                                                                                    ia, Y = 253, 104 s = w < Y and s + 0x247 or 0xd40d / s
                                                                                  end
                                                                                elseif s > 98 then
                                                                                  Y = 192 s = w <= Y and (198) or 0xd137 / s
                                                                                elseif s > 96 then
                                                                                  Y = 141 s = w <= Y and (27) or 191 else _a = "c" j, s, _a = _a .. J, 0x16c20 / s, p[1][1] oa, la, G = p[3][1], p[2][1], j
                                                                                end
                                                                              elseif s >= 28 then
                                                                                if s <= 44 then
                                                                                  if s <= 33 then
                                                                                    if s > 31 then
                                                                                      if s <= 32 then
                                                                                        Y = 229 s = w >= Y and (104) or 190 else s, C = s + 185, 72
                                                                                      end
                                                                                    elseif s >= 30 then
                                                                                      if s > 30 then
                                                                                        Y = 92 s = w <= Y and (141) or 0x13bd / s
                                                                                      else
                                                                                        ba, H, S, b = 1, 0, 4, 0 s = S ~= S and s + - 2 or 447 end
                                                                                      else
                                                                                        y, l, da = 61, 252, H s = i > ka and 0x6318 / s or 320 end
                                                                                      elseif s < 37 then
                                                                                        if s <= 34 then
                                                                                          s, C = 218, 161
                                                                                        else
                                                                                          Y = 66 s = w < Y and (159) or 111 end
                                                                                        elseif s <= 37 then
                                                                                          Y = 38 s = w > Y and s + 103 or 226 - s
                                                                                        else
                                                                                          fa = fa + C s = C > 0 and s + 0x370 or 0x7984 / s
                                                                                        end
                                                                                      elseif s < 52 then
                                                                                        if s > 48 then
                                                                                          s, C = s + 169, 68
                                                                                        elseif s <= 45 then
                                                                                          w, Y, s, M, C = p[1][1], p[2][1], 768, p[3][1], "B"
                                                                                        else
                                                                                          Y = 147 s = w > Y and 195 - s or 98 end
                                                                                        elseif s <= 56 then
                                                                                          if s >= 55 then
                                                                                            if s <= 55 then
                                                                                              Y, M, s, C, U = "B", p[2][1], s + 424, p[1][1], p[3][1]
                                                                                            else
                                                                                              M, U, C, Y, da, s, H = p[5][1], p[6][1], p[4][1], G, w, 0x8bc8 / s, 127
                                                                                            end
                                                                                          else
                                                                                            C = 232 s = _ >= C and 0x1ee0 / s or 218 end
                                                                                          else
                                                                                            Y, N = 93, 124 s = w > Y and s + 159 or 224 end
                                                                                          elseif s < 14 then
                                                                                            if s < 9 then
                                                                                              if s > 7 then
                                                                                                C, s, Y, fa, w = p[2][1], s + 0x3d6, p[3][1], p[1][1], "B"
                                                                                              elseif s >= 3 then
                                                                                                if s > 3 then
                                                                                                  C, Y, M = 1, _a, 1 s = Y ~= Y and (14) or 311 else Y = 244 s = w > Y and s + 419 or 0x316 - s
                                                                                                end
                                                                                              else
                                                                                                s, C = s + 217, 185
                                                                                              end
                                                                                            elseif s < 11 then
                                                                                              if s <= 9 then
                                                                                                X, Y = 7, 25 s = w <= Y and (74) or 46 - s
                                                                                              else
                                                                                                Y = 18 s = w <= Y and (260) or 244 end
                                                                                              elseif s <= 11 then
                                                                                                r, u, V, pa, D, R = 1, 130, 229, 102, 1, 25 s = g == r and (182) or 165 / s
                                                                                              else
                                                                                                s, _a, ca = 0x381 / s, G, 53
                                                                                              end
                                                                                            elseif s < 21 then
                                                                                              if s >= 18 then
                                                                                                if s > 18 then
                                                                                                  Y = 250 s = w < Y and 87 - s or 139 - s
                                                                                                else
                                                                                                  w, i, C, ka, Y, M = 0, 184, 0, 190, 4, 1 s = Y ~= Y and (142) or 341 end
                                                                                                elseif s <= 14 then
                                                                                                  U, Y, da, M = 4, 0, 1, 0 s = U ~= U and 365 - s or 0x245e / s
                                                                                                else
                                                                                                  la, j, G, _a = 1, 0, 4, 0 s = G ~= G and (137) or 1017 end
                                                                                                elseif s > 26 then
                                                                                                  Y = 138 s = w > Y and (345) or s + 487
                                                                                                elseif s <= 25 then
                                                                                                  if s > 21 then
                                                                                                    ba, da, b, s, e, H, S = U, p[4][1], p[5][1], 579, 127, w, p[6][1]
                                                                                                  else
                                                                                                    Y = 11 s = w >= Y and (194) or 1 end
                                                                                                  else
                                                                                                    o, Y = 81, 201 s = w <= Y and (86) or 0x340 / s
                                                                                                  end
                                                                                                elseif s < 0x308 then
                                                                                                  if s >= 0x278 then
                                                                                                    if s <= 0x2c4 then
                                                                                                      if s > 0x29e then
                                                                                                        if s <= 0x2b7 then
                                                                                                          if s > 0x2b0 then
                                                                                                            if s >= 0x2b6 then
                                                                                                              if s > 0x2b6 then
                                                                                                                s = fa <= 0 and (804) or 0x7a81e / s
                                                                                                              else
                                                                                                                C = 232 s = N < C and 0x24efc / s or 238 end
                                                                                                              else
                                                                                                                s = C <= 0 and 0x791d0 / s or 0x5c8 - s
                                                                                                              end
                                                                                                            elseif s >= 0x2ab then
                                                                                                              if s > 0x2ae then
                                                                                                                s, C = 0x249e0 / s, 72
                                                                                                              elseif s > 0x2ab then
                                                                                                                s = M ~= M and 0x2bc - s or s + - 0x250
                                                                                                              else
                                                                                                                U = U(da, H, b) da, H = p[3][1], 1 da = da + H p[3][1], s, M = da, s + - 304, U
                                                                                                              end
                                                                                                            elseif s > 0x2a2 then
                                                                                                              U = U(da, H, b) da, H = p[3][1], 1 da = da + H M, p[3][1] = U, da s = a >= H and 0x95ccd / s or 26 else s, U = 0x589 - s, ""
                                                                                                            end
                                                                                                          elseif s > 0x2bc then
                                                                                                            if s < 0x2c3 then
                                                                                                              s, C = 0x254f2 / s, 68
                                                                                                            elseif s <= 0x2c3 then
                                                                                                              s = C <= 0 and 0x23627 / s or 0x4f1 - s
                                                                                                            else
                                                                                                              s = C <= 0 and 0x92ec8 / s or 80 end
                                                                                                            elseif s > 0x2ba then
                                                                                                              s, da = s + 136, da(H, b, S) b, H = 1, p[3][1] H = H + b U, p[3][1] = da, H
                                                                                                            elseif s <= 0x2b9 then
                                                                                                              if s > 0x2b8 then
                                                                                                                s = la > oa and 0x38d - s or 539 else s, C = 218, 68
                                                                                                              end
                                                                                                            else
                                                                                                              s, M = 493, M(U, T.d(da)) da, H, oa, U = Y, 128, M, p[7][1]
                                                                                                            end
                                                                                                          elseif s >= 0x28f then
                                                                                                            if s < 0x296 then
                                                                                                              if s < 0x292 then
                                                                                                                if s <= 0x28f then
                                                                                                                  s, C = 0x22dc6 / s, 161
                                                                                                                else
                                                                                                                  Y = 52 s = w > Y and 0x5c11e / s or s + 110
                                                                                                                end
                                                                                                              elseif s <= 0x292 then
                                                                                                                U = U(da, H, b) H, da = 2, p[3][1] da = da + H M, p[3][1] = U, da s = q <= H and 0x2e4 - s or 0x51edc / s
                                                                                                              else
                                                                                                                H = U[0x3031] da = oa[H] s, U[0x3031] = 1007, da
                                                                                                              end
                                                                                                            elseif s >= 0x299 then
                                                                                                              if s >= 0x29c then
                                                                                                                if s <= 0x29c then
                                                                                                                  U = {} U[0xb17e] = r U[0xf388] = J U[0x3201] = j U[0x7baa] = G U[0x1788] = Y U[0x2f57] = w da = 0 U[0x2050] = da da = 0 U[0x3e73] = da M = U
                                                                                                                  return M
                                                                                                                else
                                                                                                                  s, C = 218, 185
                                                                                                                end
                                                                                                              else
                                                                                                                s = da > 0 and (500) or s + - 195
                                                                                                              end
                                                                                                            elseif s <= 0x296 then
                                                                                                              U = U(da, H, b) H, da = 1, p[3][1] da = da + H p[3][1], M = da, U s = v < H and 0x4e9 - s or 248 else s = la <= 0 and (839) or 0x2a0 - s
                                                                                                            end
                                                                                                          elseif s <= 0x286 then
                                                                                                            if s < 0x27e then
                                                                                                              if s > 0x278 then
                                                                                                                U = U(da, H, b) s, da, H = 917, p[3][1], 1 da = da + H p[3][1], M = da, U
                                                                                                              else
                                                                                                                H = H + S s = S > 0 and 0x5f2 - s or s + - 157
                                                                                                              end
                                                                                                            elseif s > 0x27f then
                                                                                                              M(U, da) M = 185 s = C < M and (143) or 0x42a - s
                                                                                                            elseif s > 0x27e then
                                                                                                              U = U(da, H) da = 7 s, da = 964, la * da
                                                                                                            else
                                                                                                              U = U(da, H, b) H, da = 2, p[3][1] da = da + H M, p[3][1] = U, da s = qa > H and s + 354 or s + - 0x26f
                                                                                                            end
                                                                                                          elseif s >= 0x289 then
                                                                                                            if s <= 0x289 then
                                                                                                              s, C = 218, 185
                                                                                                            else
                                                                                                              s = la ~= la and (839) or 0x69888 / s
                                                                                                            end
                                                                                                          else
                                                                                                            H = H(b, S, ba) s, b = 981, p[3][1] b = b + U p[3][1], M = b, H
                                                                                                          end
                                                                                                        elseif s <= 0x2e9 then
                                                                                                          if s > 0x2db then
                                                                                                            if s > 0x2e3 then
                                                                                                              if s > 0x2e7 then
                                                                                                                s = G ~= G and (85) or 78 elseif s > 0x2e5 then
                                                                                                                  H = p[10][1] da = H[U] w[C] = da s = l >= y and (511) or 111 else s, C = 0x3bf - s, 232
                                                                                                                end
                                                                                                              elseif s >= 0x2e1 then
                                                                                                                if s <= 0x2e1 then
                                                                                                                  s, b, da, U, H = s + 85, p[3][1], "B", p[1][1], p[2][1]
                                                                                                                else
                                                                                                                  s, x = 487, T.c(x(ha, W))
                                                                                                                end
                                                                                                              elseif s <= 0x2de then
                                                                                                                s, C = s + - 0x204, 68
                                                                                                              else
                                                                                                                s = C ~= C and 0x507 - s or 0x42200 / s
                                                                                                              end
                                                                                                            elseif s < 0x2d2 then
                                                                                                              if s >= 0x2ce then
                                                                                                                if s > 0x2ce then
                                                                                                                  s = fa < w and (18) or 0x8b0 / s
                                                                                                                else
                                                                                                                  s = da <= 0 and s + 85 or 0x8f90a / s
                                                                                                                end
                                                                                                              elseif s <= 0x2c7 then
                                                                                                                s, Y[377] = 780, M
                                                                                                              else
                                                                                                                s, Y[0x71bd] = 780, M
                                                                                                              end
                                                                                                            elseif s <= 0x2d7 then
                                                                                                              if s > 0x2d6 then
                                                                                                                oa = oa(fa, w, C) s, w, fa = 91, 1, p[3][1] fa = fa + w la, p[3][1] = oa, fa
                                                                                                              elseif s > 0x2d2 then
                                                                                                                U = U(da, H, b) H, da = 1, p[3][1] s, da = 614, da + H p[3][1], M = da, U
                                                                                                              else
                                                                                                                s = fa ~= fa and (13) or 0x309 - s
                                                                                                              end
                                                                                                            elseif s > 0x2d8 then
                                                                                                              s, C = 218, 185
                                                                                                            else
                                                                                                              M = 206 s = C <= M and 0x677 - s or 583 end
                                                                                                            elseif s < 0x2fb then
                                                                                                              if s >= 0x2ef then
                                                                                                                if s <= 0x2f3 then
                                                                                                                  if s > 0x2f1 then
                                                                                                                    Y[0xb55f] = M s = z > sa and (111) or 0x5ff - s
                                                                                                                  elseif s > 0x2ef then
                                                                                                                    C = 72 s = ia >= C and 0x3cb - s or 176 else s = j > _a and (85) or s + 262
                                                                                                                  end
                                                                                                                else
                                                                                                                  s, Y = 0x520 - s, Y(M, U) M = 7 M = _a * M
                                                                                                                end
                                                                                                              elseif s >= 0x2ec then
                                                                                                                if s > 0x2ec then
                                                                                                                  s = M > U and s + - 81 or 272 else s = fa ~= fa and 0x3c0 - s or 136 end
                                                                                                                else
                                                                                                                  Y = 166 s = w > Y and 0x4e2 - s or 507 end
                                                                                                                elseif s > 0x303 then
                                                                                                                  if s < 0x305 then
                                                                                                                    s, C = 218, 72
                                                                                                                  elseif s > 0x305 then
                                                                                                                    M = M(U, da, H) U, da = p[3][1], 1 s, U = 174, U + da Y, p[3][1] = M, U
                                                                                                                  else
                                                                                                                    s, C = s + - 0x22b, 185
                                                                                                                  end
                                                                                                                elseif s <= 0x300 then
                                                                                                                  if s >= 0x2ff then
                                                                                                                    if s <= 0x2ff then
                                                                                                                      s, C = 218, 185
                                                                                                                    else
                                                                                                                      w = w(C, Y, M) Y, C = 1, p[3][1] C = C + Y p[3][1], fa = C, w s = D < Y and (87) or 124 end
                                                                                                                    else
                                                                                                                      G = G(la, oa, fa) la = p[3][1] la = la + j J, p[3][1] = G, la s = f >= ea and s + - 0x2b3 or 0x3bd - s
                                                                                                                    end
                                                                                                                  elseif s > 0x302 then
                                                                                                                    s = C > Y and 0x2a2a / s or 0x63933 / s
                                                                                                                  else
                                                                                                                    s = fa <= 0 and s + - 197 or 55 end
                                                                                                                  elseif s <= 0x22e then
                                                                                                                    if s < 0x210 then
                                                                                                                      if s > 511 then
                                                                                                                        if s >= 0x209 then
                                                                                                                          if s >= 0x20e then
                                                                                                                            if s > 0x20e then
                                                                                                                              s, C = 0x46b - s, C(Y, T.d(M)) G, M, U, Y = C, w, 128, p[7][1]
                                                                                                                            else
                                                                                                                              s = G <= 0 and (350) or 78 end
                                                                                                                            elseif s <= 0x209 then
                                                                                                                              U = U(da, H, b) da, H = p[3][1], 1 da = da + H M, s, p[3][1] = U, 0x2e6d5 / s, da
                                                                                                                            else
                                                                                                                              da, H = U[0x3031], 0 s = da ~= H and 0x54251 / s or 1007 end
                                                                                                                            elseif s <= 0x203 then
                                                                                                                              if s > 0x202 then
                                                                                                                                Y = 236 s = w > Y and s + - 159 or 896 else Y = 134 s = w >= Y and 0x55a - s or 0x2201e / s
                                                                                                                              end
                                                                                                                            else
                                                                                                                              Y = 104 s = w <= Y and s + 184 or 0x5f0b5 / s
                                                                                                                            end
                                                                                                                          elseif s < 507 then
                                                                                                                            if s > 503 then
                                                                                                                              s, C = 0x2d3 - s, 161
                                                                                                                            elseif s >= 500 then
                                                                                                                              if s <= 500 then
                                                                                                                                s = M > U and 0x2ad8c / s or 470 else s, C = 218, 68
                                                                                                                              end
                                                                                                                            else
                                                                                                                              s = C > Y and (7) or 291 end
                                                                                                                            elseif s <= 509 then
                                                                                                                              if s >= 508 then
                                                                                                                                if s <= 508 then
                                                                                                                                  s = G <= 0 and 0x39abc / s or 0x4e5 - s
                                                                                                                                else
                                                                                                                                  M = 68 s = C <= M and 0x5bc - s or 0x3cb - s
                                                                                                                                end
                                                                                                                              else
                                                                                                                                s, C = 218, 161
                                                                                                                              end
                                                                                                                            elseif s <= 510 then
                                                                                                                              s, Y[0xe074] = 0x611e8 / s, M
                                                                                                                            else
                                                                                                                              C = C + M s = M > 0 and (835) or 0x541 - s
                                                                                                                            end
                                                                                                                          elseif s < 0x221 then
                                                                                                                            if s >= 0x21a then
                                                                                                                              if s < 0x21d then
                                                                                                                                if s > 0x21a then
                                                                                                                                  s = fa ~= fa and 0x597 - s or s + 286
                                                                                                                                else
                                                                                                                                  s = M ~= M and 0x221 - s or 0x238 - s
                                                                                                                                end
                                                                                                                              elseif s <= 0x21d then
                                                                                                                                s, C = 218, 161
                                                                                                                              else
                                                                                                                                s, C = 218, 161
                                                                                                                              end
                                                                                                                            elseif s >= 0x213 then
                                                                                                                              if s > 0x213 then
                                                                                                                                s = oa <= 0 and (986) or 930 else C = 68 s = h < C and 0x322b9 / s or 0x2ed - s
                                                                                                                              end
                                                                                                                            elseif s > 0x210 then
                                                                                                                              s = M ~= M and 0x5da - s or 381 else U = U(da, H, b) H, da = 1, p[3][1] s, da = s + 47, da + H p[3][1], M = da, U
                                                                                                                            end
                                                                                                                          elseif s > 0x228 then
                                                                                                                            if s >= 0x22c then
                                                                                                                              if s <= 0x22c then
                                                                                                                                s, C = s + 397, T.c(C(Y, M))
                                                                                                                              else
                                                                                                                                s = C ~= C and (223) or 80 end
                                                                                                                              else
                                                                                                                                M = 148 s = C <= M and (629) or 830 end
                                                                                                                              elseif s < 0x225 then
                                                                                                                                if s > 0x221 then
                                                                                                                                  s = da ~= da and 0x4be - s or 1021 else x = x(ha, W) na = not x s = na and (28) or 777 end
                                                                                                                                elseif s >= 0x227 then
                                                                                                                                  if s > 0x227 then
                                                                                                                                    s, Y[0xf74e] = 0x534 - s, M
                                                                                                                                  else
                                                                                                                                    s = fa < w and s + - 0x215 or 0x14b76 / s
                                                                                                                                  end
                                                                                                                                else
                                                                                                                                  s = la ~= la and (137) or 8 end
                                                                                                                                elseif s < 0x24b then
                                                                                                                                  if s <= 0x23e then
                                                                                                                                    if s >= 0x235 then
                                                                                                                                      if s <= 0x23d then
                                                                                                                                        if s <= 0x237 then
                                                                                                                                          if s <= 0x235 then
                                                                                                                                            M = 203 s = C <= M and (245) or 0x40f83 / s
                                                                                                                                          else
                                                                                                                                            s = S ~= S and 0x6e53b / s or s + 411
                                                                                                                                          end
                                                                                                                                        else
                                                                                                                                          s = la < oa and 0x1d19 / s or s + - 0x206
                                                                                                                                        end
                                                                                                                                      else
                                                                                                                                        s, C = 0x318 - s, 68
                                                                                                                                      end
                                                                                                                                    elseif s > 0x233 then
                                                                                                                                      s, Y[0x71bd] = s + - 36, M U, H, b, da = p[1][1], p[2][1], p[3][1], "B"
                                                                                                                                    elseif s <= 0x232 then
                                                                                                                                      if s > 0x22f then
                                                                                                                                        C = C(Y, M) Y = 7 s, Y = 955, j * Y
                                                                                                                                      else
                                                                                                                                        s = _a > G and 0x12b27 / s or 876 end
                                                                                                                                      else
                                                                                                                                        C = 232 s = X >= C and (83) or 218 end
                                                                                                                                      elseif s > 0x243 then
                                                                                                                                        if s < 0x248 then
                                                                                                                                          s, H, b, da, U = 681, p[2][1], p[3][1], "B", p[1][1]
                                                                                                                                        elseif s > 0x248 then
                                                                                                                                          s = M < U and 0x4e6 - s or 546 else M = M + da s = da > 0 and s + 349 or 0x665f0 / s
                                                                                                                                        end
                                                                                                                                      elseif s < 0x242 then
                                                                                                                                        if s <= 0x23f then
                                                                                                                                          s, Y[0x80eb] = 0x166408 / s, M b, U, H, da = p[3][1], p[1][1], p[2][1], "B"
                                                                                                                                        else
                                                                                                                                          C = C(Y, M, U) Y, M = p[3][1], 1 s, Y = 202, Y + M p[3][1], w = Y, C
                                                                                                                                        end
                                                                                                                                      elseif s > 0x242 then
                                                                                                                                        S = S(ba, e) ba = 7 s, ba = 280, C * ba
                                                                                                                                      else
                                                                                                                                        s, Y[0x80eb] = 3242, M b, H, U, da = p[3][1], p[2][1], p[1][1], "B"
                                                                                                                                      end
                                                                                                                                    elseif s <= 0x25c then
                                                                                                                                      if s >= 0x256 then
                                                                                                                                        if s < 0x25b then
                                                                                                                                          if s > 0x256 then
                                                                                                                                            H = H(b, S) b = 7 s, b = 929, fa * b
                                                                                                                                          else
                                                                                                                                            s, C = 0x1fd3c / s, 68
                                                                                                                                          end
                                                                                                                                        elseif s > 0x25b then
                                                                                                                                          Y = Y(M, U) C = not Y s = C and (13) or s + - 349
                                                                                                                                        else
                                                                                                                                          s, C = 218, 141
                                                                                                                                        end
                                                                                                                                      elseif s > 0x250 then
                                                                                                                                        s, C = 218, 68
                                                                                                                                      elseif s < 0x24f then
                                                                                                                                        s, C = 218, 68
                                                                                                                                      elseif s <= 0x24f then
                                                                                                                                        s = C < Y and (142) or 0xdb51 / s
                                                                                                                                      else
                                                                                                                                        s = ba <= 0 and 0x8ea70 / s or 152 end
                                                                                                                                      elseif s > 0x26f then
                                                                                                                                        if s < 0x276 then
                                                                                                                                          U, da, H, s, b = p[1][1], "B", p[2][1], 0x47e - s, p[3][1]
                                                                                                                                        elseif s <= 0x276 then
                                                                                                                                          s, C = s + - 412, 72
                                                                                                                                        else
                                                                                                                                          s = M ~= M and (142) or 0xea29 / s
                                                                                                                                        end
                                                                                                                                      elseif s >= 0x266 then
                                                                                                                                        if s > 0x266 then
                                                                                                                                          s = C > 0 and 0x3e4 - s or s + - 309
                                                                                                                                        else
                                                                                                                                          s, Y[0x71bd] = 0x817 - s, M U, da, H, b = p[1][1], "B", p[2][1], p[3][1]
                                                                                                                                        end
                                                                                                                                      elseif s > 0x261 then
                                                                                                                                        U = U(da, H, b) da, H = p[3][1], 8 s, da = 0x92d09 / s, da + H p[3][1], M = da, U
                                                                                                                                      else
                                                                                                                                        Y = 156 s = w > Y and 0x30063 / s or 0x4f0 - s
                                                                                                                                      end
                                                                                                                                    elseif s <= 0x387 then
                                                                                                                                      if s < 0x343 then
                                                                                                                                        if s <= 0x323 then
                                                                                                                                          if s >= 0x31a then
                                                                                                                                            if s <= 0x320 then
                                                                                                                                              if s <= 0x31d then
                                                                                                                                                if s <= 0x31b then
                                                                                                                                                  if s > 0x31a then
                                                                                                                                                    Y = Y(M) M, U, da = 1, C, 1 s = U ~= U and (668) or 790 else Y[0xa544] = M U, H, s, b, da = p[1][1], p[2][1], 638, p[3][1], '>i2'
                                                                                                                                                  end
                                                                                                                                                else
                                                                                                                                                  s, U = s + - 0x281, da
                                                                                                                                                end
                                                                                                                                              elseif s <= 0x31e then
                                                                                                                                                s, H = 981, H(b, S, ba) b = p[3][1] b = b + U p[3][1], M = b, H
                                                                                                                                              else
                                                                                                                                                s = S <= 0 and (424) or 978 end
                                                                                                                                              elseif s >= 0x322 then
                                                                                                                                                if s <= 0x322 then
                                                                                                                                                  s = _a < G and 0x1ad32 / s or s + - 253
                                                                                                                                                else
                                                                                                                                                  s = M < U and s + - 452 or 819 end
                                                                                                                                                else
                                                                                                                                                  s = b > S and 0x579c / s or 843 end
                                                                                                                                                elseif s >= 0x314 then
                                                                                                                                                  if s > 0x317 then
                                                                                                                                                    s = ba <= 0 and (832) or 264 elseif s > 0x316 then
                                                                                                                                                      s = C ~= C and 0x379e / s or 0x3b1 - s
                                                                                                                                                    elseif s > 0x314 then
                                                                                                                                                      s = da > 0 and 0x9075e / s or 272 else s, _a = 226, _a(G, la, oa) la, G = 1, p[3][1] G = G + la j, p[3][1] = _a, G
                                                                                                                                                    end
                                                                                                                                                  elseif s < 0x30c then
                                                                                                                                                    if s > 0x308 then
                                                                                                                                                      b = b + ba s = ba > 0 and s + 202 or 792 else ha, x, e, F, na, s, W = p[6][1], p[5][1], p[4][1], 127, da, 326, ba
                                                                                                                                                    end
                                                                                                                                                  elseif s <= 0x30c then
                                                                                                                                                    la = la + fa s = fa > 0 and (1136) or 0x101760 / s
                                                                                                                                                  else
                                                                                                                                                    s, C = 218, 206
                                                                                                                                                  end
                                                                                                                                                elseif s <= 0x336 then
                                                                                                                                                  if s >= 0x32c then
                                                                                                                                                    if s < 0x335 then
                                                                                                                                                      if s > 0x32c then
                                                                                                                                                        s = da ~= da and 0x462ed / s or 376 else s, Y[0x71bd] = s + - 0x236, M da, U, b, H = "B", p[1][1], p[3][1], p[2][1]
                                                                                                                                                      end
                                                                                                                                                    elseif s <= 0x335 then
                                                                                                                                                      w = w(C) M, Y, C = 1, fa, 1 s = Y ~= Y and 0x1673 / s or 392 else U = U(da, H, b) da, H = p[3][1], 1 da = da + H M, p[3][1] = U, da s = A > H and (13) or 713 end
                                                                                                                                                    elseif s > 0x328 then
                                                                                                                                                      s = H > b and (797) or 866 elseif s > 0x326 then
                                                                                                                                                        M = 148 s = C < M and 0x609 - s or 0x6d490 / s
                                                                                                                                                      elseif s > 0x324 then
                                                                                                                                                        M = "" s = aa >= t and (515) or 0xc109e / s
                                                                                                                                                      else
                                                                                                                                                        s = la < oa and (13) or 722 end
                                                                                                                                                      elseif s < 0x33e then
                                                                                                                                                        if s < 0x33b then
                                                                                                                                                          s = fa <= 0 and s + 67 or 136 elseif s > 0x33b then
                                                                                                                                                            s, Y[0xa544] = s + 0x6a9, M H, b, da, U = p[2][1], p[3][1], '>i2', p[1][1]
                                                                                                                                                          else
                                                                                                                                                            s, C = 0x415 - s, 185
                                                                                                                                                          end
                                                                                                                                                        elseif s < 0x340 then
                                                                                                                                                          if s <= 0x33e then
                                                                                                                                                            b, da, s, H, U = p[3][1], "B", 921, p[2][1], p[1][1]
                                                                                                                                                          else
                                                                                                                                                            s = oa ~= oa and (236) or s + - 381
                                                                                                                                                          end
                                                                                                                                                        elseif s > 0x340 then
                                                                                                                                                          s = M <= 0 and (494) or s + - 296
                                                                                                                                                        else
                                                                                                                                                          s = b < S and 0x35c - s or 0x35a00 / s
                                                                                                                                                        end
                                                                                                                                                      elseif s <= 0x365 then
                                                                                                                                                        if s > 0x352 then
                                                                                                                                                          if s > 0x35f then
                                                                                                                                                            if s < 0x362 then
                                                                                                                                                              b = "c" b, s, H = p[1][1], 265, b .. da ba, S, e = p[2][1], H, p[3][1]
                                                                                                                                                            elseif s > 0x362 then
                                                                                                                                                              oa = oa(fa) fa, w, C = 1, la, 1 s = w ~= w and (18) or 135 else s = S ~= S and (424) or 800 end
                                                                                                                                                            elseif s > 0x35c then
                                                                                                                                                              if s <= 0x35d then
                                                                                                                                                                s = M < U and (668) or 0x75a - s
                                                                                                                                                              else
                                                                                                                                                                s = M <= 0 and (591) or 95 end
                                                                                                                                                              elseif s <= 0x359 then
                                                                                                                                                                if s <= 0x358 then
                                                                                                                                                                  Y = 134 s = w <= Y and (773) or 387 else H = "c" da, H = H .. U, p[1][1] ba, s, S, b = p[3][1], 647, p[2][1], da
                                                                                                                                                                end
                                                                                                                                                              else
                                                                                                                                                                na = na(x, ha) e = not na s = e and 0xa756c / s or 632 end
                                                                                                                                                              elseif s >= 0x34b then
                                                                                                                                                                if s >= 0x34d then
                                                                                                                                                                  if s >= 0x351 then
                                                                                                                                                                    if s <= 0x351 then
                                                                                                                                                                      s = C > Y and 0x3df - s or s + 31
                                                                                                                                                                    else
                                                                                                                                                                      s = fa < w and 0x431 - s or 0x109a0 / s
                                                                                                                                                                    end
                                                                                                                                                                  else
                                                                                                                                                                    e = e(na, x, ha) x, na = 1, p[3][1] na = na + x s, p[3][1], ba = 776, na, e
                                                                                                                                                                  end
                                                                                                                                                                elseif s <= 0x34b then
                                                                                                                                                                  s = ba ~= ba and 0x726 - s or 0x59b - s
                                                                                                                                                                else
                                                                                                                                                                  C = C + M s = M > 0 and 0x433 - s or 0x4acc4 / s
                                                                                                                                                                end
                                                                                                                                                              elseif s < 0x345 then
                                                                                                                                                                if s <= 0x343 then
                                                                                                                                                                  s = C > Y and 0x34a - s or 834 else s, H = 798, T.F[ - 0x6eec] or T:I('\x15B', '+', - 0x6eec) H, da = p[1][1], H .. U S, b, ba = p[2][1], da, p[3][1]
                                                                                                                                                                end
                                                                                                                                                              elseif s <= 0x345 then
                                                                                                                                                                Y[0x71bd] = M s, b, H, U, da = 0x1b7c08 / s, p[3][1], p[2][1], p[1][1], "B"
                                                                                                                                                              else
                                                                                                                                                                s = _a < G and (137) or s + - 0x33f
                                                                                                                                                              end
                                                                                                                                                            elseif s <= 0x37c then
                                                                                                                                                              if s < 0x374 then
                                                                                                                                                                if s <= 0x36c then
                                                                                                                                                                  if s <= 0x367 then
                                                                                                                                                                    if s > 0x366 then
                                                                                                                                                                      s = C > Y and 0x375 - s or 0x1f78c / s
                                                                                                                                                                    else
                                                                                                                                                                      s = fa > w and 0x378 - s or s + - 181
                                                                                                                                                                    end
                                                                                                                                                                  else
                                                                                                                                                                    s = la <= 0 and (802) or 549 end
                                                                                                                                                                  else
                                                                                                                                                                    s = M ~= M and (591) or s + - 17
                                                                                                                                                                  end
                                                                                                                                                                elseif s < 0x37a then
                                                                                                                                                                  if s > 0x374 then
                                                                                                                                                                    s = G > 0 and (751) or 1013 else U = U(da, H, b) H, da = 1, p[3][1] s, da = 0x79b90 / s, da + H p[3][1], M = da, U
                                                                                                                                                                  end
                                                                                                                                                                elseif s > 0x37a then
                                                                                                                                                                  s = la < oa and (212) or 136 else s = H > b and 0x697 - s or 475 end
                                                                                                                                                                elseif s <= 0x382 then
                                                                                                                                                                  if s >= 0x381 then
                                                                                                                                                                    if s <= 0x381 then
                                                                                                                                                                      s, C = 0x2fbda / s, 232
                                                                                                                                                                    else
                                                                                                                                                                      b = b(S, T.d(ba)) Y, ba, s, e, S = b, H, 312, 128, p[7][1]
                                                                                                                                                                    end
                                                                                                                                                                  elseif s <= 0x37d then
                                                                                                                                                                    fa = fa(w, C) oa = not fa s = oa and 0x3d2 - s or 0x171c2 / s
                                                                                                                                                                  else
                                                                                                                                                                    s, C = 218, 68
                                                                                                                                                                  end
                                                                                                                                                                elseif s > 0x385 then
                                                                                                                                                                  H = H(b, S) da = not H s = da and 0x415 - s or 844 elseif s <= 0x384 then
                                                                                                                                                                    s, C = 0x2fe68 / s, 185
                                                                                                                                                                  else
                                                                                                                                                                    s, Y[0x71bd] = 495, M b, U, H, da = p[3][1], p[1][1], p[2][1], '>i2'
                                                                                                                                                                  end
                                                                                                                                                                elseif s < 0x3d5 then
                                                                                                                                                                  if s < 0x3a9 then
                                                                                                                                                                    if s <= 0x39b then
                                                                                                                                                                      if s >= 0x395 then
                                                                                                                                                                        if s < 0x399 then
                                                                                                                                                                          if s <= 0x395 then
                                                                                                                                                                            s, Y[0x80eb] = 0xafd - s, M U, H, b, da = p[1][1], p[2][1], p[3][1], '>i2' dF ",'�',0x7e87)else U=U(da,H,b)H,da=1,p[3][1]da=da+H p[3][1],M=da,U s=k>=H and(913)or 245end elseif s>0x399 then s,Y[0xc0ee]=0x6a7-s,M else U=U(da,H,b)H,da=1,p[3][1]da=da+H p[3][1],M=da,U s=ra>=H and s+-0x2b1 or s+-233 end elseif s<=0x390 then if s>0x38f then U=U(da,H,b)da,H=p[3][1],1 da=da+H s,p[3][1],M=812,da,U elseif s>0x38a then j=j(_a,G,la)_a,G=p[3][1],1 _a=_a+G p[3][1],s,J=_a,0x3cd-s,j else M=M+da s=da>0 and(289)or 0x773-s end else Y[0x71bd]=M b,U,da,s,H=p[3][1],p[1][1]," B ",0x8dc3c/s,p[2][1]end elseif s<=0x3a0 then if s<0x39f then if s>0x39c then C=141 s=ma>=C and(696)or 0x313b2/s else s=fa>w and s+-0x2bd or 0x65f-s end elseif s<=0x39f then M=203 s=C>=M and 0x7fdeb/s or 0x4289a/s else Y[0x80eb]=M b,s,U,H,da=p[3][1],0x380f60/s,p[1][1],p[2][1]," B "end elseif s>=0x3a2 then if s>0x3a2 then s=M>U and 0x4ff3b/s or 718else s=oa~=oa and 0x13c0e/s or 0x3cf-s end else s,da=s+-231,T.c(da(H,b))end elseif s>=0x3bf then if s<=0x3cb then if s<=0x3c8 then if s>0x3c4 then s,e=133,e(na,x)na=7 na=M*na elseif s<=0x3bf then U,s,H,b,da=p[1][1],912,p[2][1],p[3][1]," B "else s,M=527,T.c(M(U,da))end elseif s>0x3c9 then _a=_a(G,la,oa)G=p[3][1]s,G=149,G+J r,p[3][1]=_a,G else s=C<Y and 0x34fe/s or s+-0x36b end elseif s>=0x3d2 then if s<=0x3d2 then ha,s,x,na,e=p[3][1],845,p[2][1]," B ",p[1][1]else s=b>S and 0x6b14/s or 0x6eb-s end else G=G(la)la,fa,oa=1,1,_a s=oa~=oa and 0x4a1-s or 0x6f691/s end elseif s<0x3b6 then if s<=0x3af then if s>=0x3ab then if s>0x3ab then s=la>oa and 0x2fe3/s or 0x666-s else b=b(S,ba,e)S,ba=p[3][1],1 S=S+ba s,p[3][1],H=179,S,b end else s,C=218,72 end else s,M=s+34,0/0 end elseif s<=0x3bb then if s>0x3b9 then s,w=181,T.c(w(C,Y))elseif s>0x3b6 then fa=fa(w,T.d(C))j,Y,w,s,C=fa,128,p[7][1],259,oa else U=3 s=Y==U and(947)or 0x78b-s end else Y=83 s=w<=Y and s+-61 or 587end elseif s<=0x3f9 then if s>0x3e4 then if s>=0x3ed then if s<0x3f5 then if s<=0x3ed then C=206 s=o<C and(218)or s+-0x3bc else C=C+M s=M>0 and s+-136 or 148end elseif s>0x3f5 then s=la>0 and(430)or 651else s=G~=G and(350)or 0x82166/s end elseif s>=0x3e9 then if s<=0x3e9 then s=da<=0 and s+-415 or 0x60b-s else s,C=218,161 end else s=C<Y and s+-0x3df or 30end elseif s>0x3dc then if s<=0x3e3 then if s>0x3e0 then s=G>la and s+-0x38c or 0xc9ddd/s elseif s<=0x3de then fa=fa(w,C,Y)C,s,w=1,0x1ef00/s,p[3][1]w=w+C p[3][1],oa=w,fa else s,Y[0x220a]=780,M end else s,Y=0x59ba4/s,T.c(Y(M,U))end elseif s<=0x3da then if s>=0x3d7 then if s<=0x3d7 then s=j>_a and(85)or 508else s=G<la and 0x14f16/s or s+-56 end else oa[fa]=M s=I>n and(297)or 0x499-s end elseif s<=0x3db then s=b<S and(28)or 152else s,C=s+-0x302,185 end elseif s<=0x752 then if s<0x470 then if s<0x3ff then if s<=0x3fa then s,Y[0x220a]=780,M else s,H=0x6275f/s,p[11][1]end elseif s>0x3ff then U=U(da,H,b)H,da=1,p[3][1]da=da+H s,M,p[3][1]=377,U,da else s,C=s+-0x325,68 end elseif s>=0x5b1 then if s<=0x5b1 then U=U(da,H,b)H,da=1,p[3][1]da=da+H p[3][1],M=da,U s=ca>H and 0xae4ca/s or 505else s=la<oa and 0x826-s or 748end elseif s<=0x470 then s=la>oa and s+-0x39c or 1352else s=fa<=0 and(1874)or s+-0x25c end elseif s>0x9f8 then if s<=0xcaa then if s>0xb7c then s,U=755,U(da,H,b)H,da=1,p[3][1]da=da+H p[3][1],M=da,U else U=U(da,H,b)da,H=p[3][1],1 da=da+H p[3][1],s,M=da,456,U end else s,U=923,U(da,H,b)H,da=1,p[3][1]da=da+H M,p[3][1]=U,da end elseif s<=0x9e5 then if s>0x868 then U=U(da,H,b)H,da=2,p[3][1]s,da=s+-0x5eb,da+H p[3][1],M=da,U elseif s<=0x768 then s,U=828,U(da,H,b)da,H=p[3][1],2 da=da+H M,p[3][1]=U,da else U=U(da,H,b)H,da=1,p[3][1]s,da=0x9b840/s,da+H M,p[3][1]=U,da end else s,U=0x1bafc8/s,U(da,H,b)da,H=p[3][1],1 da=da+H M,p[3][1]=U,da end until false end end,J=function(a,b,c,d)a.F[d]=a.a(b,0xa56d)+a.a(c,0x1026)return a.F[d]end,i=function(d)local h,f,g,a,_ _=string g,f=_.char,_.gsub g={[3]=1,[1]=g}g[2]=g f={[3]=1,[1]=f}f[2]=f h=bit32 a,_=h.band,h.rshift _={[3]=1,[1]=_}_[2]=_ a={[3]=1,[1]=a}a[2]=a h=d:j{f,g,_,a}return h end,G=function(a,b,c,d)a.F[d]=a.a(b,0x64e)-a.a(c,0xcceb)return a.F[d]end,O=function(a,...)a.x,a.i,a.l,a.g=a:x(),a:i(),a:l(),a:g()return a:f()(...)end,m=function(d,p)return function(g)local q,b,s,j,c,u,o,t,k,a,_,i,h,v,f,l,m,r s=233 while true do if s>163 then if s<194 then if s<=188 then if s>170 then return r else q,m,u=v,1,p[6][1]u=u(q,m)v=u s=l and 79 or 0x9812/s end else m,q,i,u=g," > I2 ",_,p[5][1]u=u(q,m,i)q=2 f,t,m,_,i=5,u,#o,_+q,p[6][1]i=i(t,f)t,f,i,q=u,31,p[3][1],m-i i=i(t,f)t=3 f,t,i,s,m=q,o,p[4][1],362-s,i+t h,b=1,q+m b=b-h i=i(t,f,b)l=i end elseif s>229 then _=p[1][1]r=_[g]s=r and 188 or 40 elseif s>194 then c=c+k s=(k>0 and c>a or k<=0 and c<a or k~=k)and 194 or 304-s else v=#g s=_<=v and s+-31 or s+-129 end elseif s<79 then if s>65 then l,u,q,m=nil,p[3][1],v,1 u=u(q,m)q=0 s=u~=q and 80 or 90-s elseif s>=40 then if s>40 then v,c=p[7][1],j v=v(c)c=p[1][1]c[g]=v return v else s,_,o=0x1e50/s,1,{}o,j=" ",o end else q=1 q,u=#g,_+q s=u<=q and 207-s or s+155 end elseif s<87 then if s<=79 then q,m=#j,1 u=q+m j[u]=l m,s,u,q=-0x800,229,p[4][1],o..l u=u(q,m)o=u else u=#g s=_<=u and 87 or s+90 end elseif s<=87 then u,m,s,i,q=p[4][1],_,170,_,g u=u(q,m,i)l,u=u,1 _=_+u else c,v,a=g,p[2][1],_ v=v(c,a)c=1 k,_,a,c=1,_+c,8,1 s=(a~=a or k>0 and c>a or(k<=0 or k~=k)and c<a)and 194 or 75 end end end end,L=function(a,b,c,d)a.K[d]=a.g(b,c)return a.K[d]end,f=function(a,b)return a.x(a.l(a.i"{{dD20P79M6aN9uDgv4! 0 t5dt2MH & ~ 6 amivD + HP & 0 | PP${sEvB0nRK1nk4T812PE % U = {( + | 1 AcZB? SXA3jPHk7Xi * L2bw1D1_Lq + 2 H + S0 & i ^ k6nkNSXG7SC * pcw(qFbSF{{ | Eyz4GAZp9{(l ^ # ~ TaIF % 17 Q4 + tj591WoVA1@ 9 RJwG3u` vC | 7 A{! 4 BJwE * h0YE3m91j#e | 2` = ) 5 C | tKEdKyYD;
                                                                                                                                                                            YBrFqQu) 0? sxND;
+ cc7ce9 % Dl` Bi | 0 * > ABb6`$ cK;
                                                                                                                                                                            Y65Y9jm & O! eY & O#IUP$ mceIr0` CDmVZn | L8R(04 e | * $ Nwu26ir4VoB{s? oB < 1 * 0 Suh ~ 0 S % l14x9lG | C | 99 oB < ayAHN7D6iq - 01 L7F | 0 ih - ULB} f# & ig? W13 | | u6`(KwKNbQZ0AK) 0 j} % Nr3J8t | AqW61` < wv? VO > zxCO - cr) + atD@ * O7s6j44C6jDPZ | C | 9 EoB < r10skGG0S24_9` gSnCo(1 nCZIOoD;
                                                                                                                                                                            E@ 1 KM > #_n! iCI7 & 0 aa0znz > 0 zfOA0Rl) Z8Uo) a07C & Z5k#Oc | 2` W6A ^ } bTH ~ tf290DN$ Q2 + P;
& PpAcLLnY9 | 0 fA2 & PyMfL;
                                                                                                                                                                            3 + gC@ x? * Eg % $ F - $ EIj0U#`(oB{tKoB < - 5 L? jshGARirTv1Fq | A8zBDVJJQEmu5NApl? ^ 0 AM2k;
                                                                                                                                                                            8 i36U? l < ICIDb30N_ < 917 Ilw;
                                                                                                                                                                            3@ = QD + J) xECpaK1 > i0QU@! FFD = - vVKO6uC6#rX5ESv!) oB` hl6kI? O4nq` O?? 4 fp0U#hK6kf? gFd! YEDK7#NKq? eJUqS_(0 T44n0RYbk6ktFHpfx} v6#rpAD4YQ! 6 k_8 - 7 Z! pdAPB$ < 6 l3{9 C;
$ LJFPs4roZkTy6l6;
                                                                                                                                                                            pAQhZ > 0 Rw < KpeLLGE & ~ IDoB = W513(2 pJ ^ & J + Fy | CyKtG@ WKp7Nf < 3 bca01 %  = tfEg5L`# = Li;
                                                                                                                                                                            u#cZKnR{g! Wk54KsA6wpc & 5;
                                                                                                                                                                            YDgLj;
                                                                                                                                                                            tk = P0niO#GoU? y8{jbw! XXa - M_4hSP + & 4 D | 6 BlHDqR3ZD * s * pGBQ94CsW@} Tr < Z_14IELssljv13;
                                                                                                                                                                            StL ^ K0N098u{pf? 7 fC < df82CG & 23 IHPmL ^ cCU! vjE7K? bBZ2CLi#pi2q_RX7cIIRi) c7l6_YU{zWW#5 xeyI} q1A3I | o | 9 zfR ~ NIekCJR0DYEgnQZ14l + 7 qyt4iss ^ V) 157{) 2 RtjlK} sb6Hzfo? 15 YIdLJAAjH7md? E5t) 6 cSQ34I6 = ouMW9b# | 3 = PXM > 0 PMC -  = @ _NIXDEl ~ n@ XJs? VzRRcZ % OV0meOqyE > 9 x_0 ^ 2 | wXY$ 4 x ~ ;
                                                                                                                                                                            Kt}) 0 VoowZ2q * I8CJ$ gw0s % !} BPw0H0Vg{_DqjFQzzhE;
                                                                                                                                                                            Q#) Kx0w4f? O8_ & VHZ356K > txPCI}} c | 19 _N3nG4iQUW3X | 4#roDmws6CjS67$ 14?} E < W` fl > $? iqW << % JAXP < CICstO$ < W + & SF(6 UH_rZb7WQw2m | 0 i@(c;
                                                                                                                                                                            V | 5 pMc17 - tHm3uV;
                                                                                                                                                                            380` * T{92 BUsx(z03#5 < Spej(T2nh) 7) M(eLC0TCT % b{5 G + ` q * ! u > % U;
                                                                                                                                                                            7? s$ Q % ^ | mO ~ + 0} 13} JXUhncfE;
                                                                                                                                                                            0 iEpi * 70 I#W < yVu2 + 9;
                                                                                                                                                                            9 & p9Peq_oVn) vYWKJ? d2q(u

-- ── Entry point ─────────────────────────────────────────────────
MoonVeil:O(...)
