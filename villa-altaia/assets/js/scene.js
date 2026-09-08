/* ===========================================================================
   scene.js — le travelling.
   Un unique plan WebGL fixe derrière la page : cinq crêtes fractales prises
   dans un brouillard exponentiel, de la neige en suspension et des braises.
   La progression du scroll (0 → 1) pilote la caméra, la densité et la couleur
   du brouillard : on descend du bleu des sommets vers l'ambre du salon.
   ========================================================================== */
window.VillaScene = (function () {
  'use strict';

  var reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  /* — palette du travelling : froid en haut, chaud à l'intérieur ---------- */
  var COLD = { r: 0x2a / 255, g: 0x30 / 255, b: 0x38 / 255 };
  var WARM = { r: 0x24 / 255, g: 0x1a / 255, b: 0x13 / 255 };

  var api = { ready: false, setProgress: function () {}, resize: function () {} };

  function rng (seed) {
    var a = seed >>> 0;
    return function () {
      a |= 0; a = (a + 0x6d2b79f5) | 0;
      var t = Math.imul(a ^ (a >>> 15), 1 | a);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  function fractal (rnd, levels, rough) {
    var arr = [rnd(), rnd()], amp = 1, l, i, next;
    for (l = 0; l < levels; l++) {
      next = [];
      for (i = 0; i < arr.length - 1; i++) {
        next.push(arr[i]);
        next.push((arr[i] + arr[i + 1]) / 2 + (rnd() - 0.5) * amp);
      }
      next.push(arr[arr.length - 1]);
      arr = next; amp *= rough;
    }
    var mn = Math.min.apply(null, arr), mx = Math.max.apply(null, arr);
    return arr.map(function (v) { return (v - mn) / (mx - mn || 1); });
  }

  /* Une crête = bande triangulée : sommet fractal en haut, base plongeante.
     Les couleurs par sommet donnent la neige sans texture ni éclairage. */
  function ridgeMesh (THREE, opts) {
    var rnd = rng(opts.seed);
    var h = fractal(rnd, 7, 0.54);
    var N = h.length;
    var pos = new Float32Array(N * 2 * 3);
    var col = new Float32Array(N * 2 * 3);
    var idx = [];
    var rock = new THREE.Color(opts.rock);
    var snow = new THREE.Color(opts.snow);
    var i, x, y, t, c, k;

    for (i = 0; i < N; i++) {
      t = i / (N - 1);
      /* enveloppe : trois sommets dominants plutôt qu'un bruit uniforme */
      var env = Math.max(
        0.22,
        0.95 * Math.exp(-Math.pow(t - opts.p1, 2) / 0.016),
        1.00 * Math.exp(-Math.pow(t - opts.p2, 2) / 0.012),
        0.80 * Math.exp(-Math.pow(t - opts.p3, 2) / 0.020)
      );
      y = (0.30 + h[i] * 0.70) * env * opts.height;
      x = (t - 0.5) * opts.width;

      k = i * 6;
      pos[k] = x; pos[k + 1] = y; pos[k + 2] = 0;
      pos[k + 3] = x; pos[k + 4] = -opts.height * 1.2; pos[k + 5] = 0;

      /* la neige n'apparaît qu'au-dessus d'un seuil d'altitude */
      var snowiness = Math.min(1, Math.max(0, (y / opts.height - opts.snowline) * 3.2));
      c = rock.clone().lerp(snow, snowiness * opts.snowAmount);
      col[k] = c.r; col[k + 1] = c.g; col[k + 2] = c.b;
      c = rock.clone().multiplyScalar(0.55);
      col[k + 3] = c.r; col[k + 4] = c.g; col[k + 5] = c.b;

      if (i < N - 1) {
        var a = i * 2;
        idx.push(a, a + 1, a + 2, a + 1, a + 3, a + 2);
      }
    }

    var geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.BufferAttribute(pos, 3));
    geo.setAttribute('color', new THREE.BufferAttribute(col, 3));
    geo.setIndex(idx);

    var mat = new THREE.MeshBasicMaterial({
      vertexColors: true, fog: true, transparent: true, opacity: 1,
      side: THREE.DoubleSide, depthWrite: false
    });
    var mesh = new THREE.Mesh(geo, mat);
    mesh.position.z = opts.z;
    mesh.renderOrder = opts.order;
    return mesh;
  }

  /* Un point brut est un carré : on lui donne une texture ronde en dégradé,
     sans quoi la neige et les braises se lisent comme des pixels. */
  function dot (THREE) {
    var c = document.createElement('canvas');
    c.width = c.height = 64;
    var g = c.getContext('2d');
    var rg = g.createRadialGradient(32, 32, 0, 32, 32, 32);
    rg.addColorStop(0, 'rgba(255,255,255,1)');
    rg.addColorStop(0.35, 'rgba(255,255,255,0.55)');
    rg.addColorStop(1, 'rgba(255,255,255,0)');
    g.fillStyle = rg;
    g.fillRect(0, 0, 64, 64);
    var tex = new THREE.CanvasTexture(c);
    tex.needsUpdate = true;
    return tex;
  }

  function points (THREE, opts) {
    var rnd = rng(opts.seed);
    var pos = new Float32Array(opts.count * 3);
    var seed = new Float32Array(opts.count);
    for (var i = 0; i < opts.count; i++) {
      pos[i * 3] = (rnd() - 0.5) * opts.box[0];
      pos[i * 3 + 1] = (rnd() - 0.5) * opts.box[1];
      pos[i * 3 + 2] = (rnd() - 0.5) * opts.box[2];
      seed[i] = rnd();
    }
    var geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.BufferAttribute(pos, 3));
    var mat = new THREE.PointsMaterial({
      color: opts.color, size: opts.size, sizeAttenuation: true, map: opts.map,
      transparent: true, opacity: opts.opacity, depthWrite: false,
      blending: THREE.AdditiveBlending, fog: false
    });
    var p = new THREE.Points(geo, mat);
    p.userData = { seed: seed, box: opts.box, fall: opts.fall, drift: opts.drift };
    return p;
  }

  api.init = function (canvas) {
    if (reduce || !window.THREE || !canvas) return false;

    var THREE = window.THREE, gl;
    try {
      gl = new THREE.WebGLRenderer({
        canvas: canvas, antialias: false, alpha: true, powerPreference: 'high-performance'
      });
    } catch (e) { return false; }
    if (!gl.getContext()) return false;

    gl.setClearColor(0x000000, 0);
    gl.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.75));

    var scene = new THREE.Scene();
    scene.fog = new THREE.FogExp2(0x2a3038, 0.00085);

    var cam = new THREE.PerspectiveCamera(46, 1, 1, 6000);

    /* cinq plans successifs : la brume creuse la profondeur toute seule */
    var ridges = new THREE.Group();
    [
      { seed: 22,   z: -2600, width: 7200, height: 1150, rock: 0x6a727a, snow: 0xf2f4f6, snowline: 0.34, snowAmount: 1.0, p1: 0.16, p2: 0.46, p3: 0.82, order: 1 },
      { seed: 907,  z: -2050, width: 6200, height: 980,  rock: 0x525a63, snow: 0xe6eaee, snowline: 0.40, snowAmount: 0.95, p1: 0.28, p2: 0.62, p3: 0.90, order: 2 },
      { seed: 5150, z: -1500, width: 5200, height: 820,  rock: 0x3c434b, snow: 0xd2d8dd, snowline: 0.48, snowAmount: 0.8, p1: 0.10, p2: 0.44, p3: 0.76, order: 3 },
      { seed: 771,  z: -1000, width: 4400, height: 650,  rock: 0x2a3037, snow: 0xa9b1b8, snowline: 0.58, snowAmount: 0.55, p1: 0.34, p2: 0.70, p3: 0.94, order: 4 },
      { seed: 313,  z: -600,  width: 3800, height: 520,  rock: 0x171b1f, snow: 0x6d757d, snowline: 0.70, snowAmount: 0.30, p1: 0.22, p2: 0.58, p3: 0.86, order: 5 }
    ].forEach(function (o) { ridges.add(ridgeMesh(THREE, o)); });
    scene.add(ridges);

    var sprite = dot(THREE);
    var snow = points(THREE, {
      seed: 9, count: 2400, box: [3600, 1800, 2200], color: 0xdfe6ec,
      size: 9, opacity: 0.5, fall: 46, drift: 18, map: sprite
    });
    var ember = points(THREE, {
      seed: 4242, count: 700, box: [1800, 1100, 1200], color: 0xd99a5c,
      size: 11, opacity: 0, fall: -22, drift: 10, map: sprite
    });
    scene.add(snow); scene.add(ember);

    /* halo chaud : c'est la maison, en bas de la descente */
    var halo = new THREE.Mesh(
      new THREE.PlaneGeometry(1200, 1200),
      new THREE.MeshBasicMaterial({
        color: 0xd99a5c, transparent: true, opacity: 0,
        blending: THREE.AdditiveBlending, depthWrite: false, fog: false
      })
    );
    halo.position.set(120, -180, -900);
    halo.renderOrder = 6;
    scene.add(halo);

    var state = { p: 0, target: 0, mx: 0, my: 0, tmx: 0, tmy: 0, t: 0, visible: true };

    function size () {
      var w = window.innerWidth, h = window.innerHeight;
      gl.setSize(w, h, false);
      cam.aspect = w / h;
      cam.updateProjectionMatrix();
    }
    size();
    window.addEventListener('resize', size, { passive: true });

    var lerp = function (a, b, t) { return a + (b - a) * t; };
    var clamp01 = function (v) { return v < 0 ? 0 : v > 1 ? 1 : v; };
    /* rampe douce entre deux bornes de progression */
    var band = function (p, a, b) {
      var t = clamp01((p - a) / (b - a));
      return t * t * (3 - 2 * t);
    };

    function frame (ms) {
      requestAnimationFrame(frame);
      if (!state.visible) return;

      var dt = Math.min(0.05, (ms - state.t) / 1000) || 0.016;
      state.t = ms;

      /* lissage : le scroll pilote une cible, la caméra la rattrape */
      state.p = lerp(state.p, state.target, 0.075);
      state.mx = lerp(state.mx, state.tmx, 0.045);
      state.my = lerp(state.my, state.tmy, 0.045);

      var p = state.p;
      var descent = band(p, 0.00, 0.34);   // des sommets jusqu'au chalet
      var inside = band(p, 0.30, 0.58);    // franchissement du seuil
      var settle = band(p, 0.72, 1.00);    // la maison, puis le calme

      /* trajectoire : on descend et on avance, le regard se redresse */
      cam.position.z = lerp(1150, 60, descent) + settle * 140;
      cam.position.y = lerp(560, 40, descent) - inside * 60;
      cam.position.x = state.mx * 90;
      cam.lookAt(state.mx * 40, cam.position.y - 60 + state.my * 40 - lerp(120, 20, descent), -900);
      cam.fov = lerp(46, 38, inside) - settle * 2;
      cam.updateProjectionMatrix();

      /* atmosphère : le brouillard se réchauffe et se densifie en approchant */
      scene.fog.density = lerp(0.00042, 0.00105, descent) + inside * 0.0009;
      scene.fog.color.setRGB(
        lerp(COLD.r, WARM.r, inside),
        lerp(COLD.g, WARM.g, inside),
        lerp(COLD.b, WARM.b, inside)
      );

      ridges.children.forEach(function (m, i) {
        m.material.opacity = (1 - inside * 0.94) * (1 - settle * 0.3);
        m.position.y = -40 - i * 6 + inside * 30;
      });

      snow.material.opacity = 0.5 * (1 - inside * 0.9);
      ember.material.opacity = 0.34 * inside * (1 - settle * 0.45);
      halo.material.opacity = 0.14 * inside * (1 - settle * 0.5);
      halo.position.z = lerp(-1400, -520, descent);

      [snow, ember].forEach(function (sys) {
        if (sys.material.opacity <= 0.002) return;
        var arr = sys.geometry.attributes.position.array;
        var d = sys.userData;
        for (var i = 0, n = arr.length; i < n; i += 3) {
          arr[i + 1] -= d.fall * dt;
          arr[i] += Math.sin(ms * 0.0004 + arr[i + 2] * 0.01) * d.drift * dt;
          if (arr[i + 1] < -d.box[1] / 2) arr[i + 1] = d.box[1] / 2;
          if (arr[i + 1] > d.box[1] / 2) arr[i + 1] = -d.box[1] / 2;
          if (arr[i] > d.box[0] / 2) arr[i] -= d.box[0];
          if (arr[i] < -d.box[0] / 2) arr[i] += d.box[0];
        }
        sys.geometry.attributes.position.needsUpdate = true;
      });

      gl.render(scene, cam);
    }
    requestAnimationFrame(frame);

    document.addEventListener('visibilitychange', function () {
      state.visible = !document.hidden;
    });

    window.addEventListener('pointermove', function (e) {
      state.tmx = (e.clientX / window.innerWidth) * 2 - 1;
      state.tmy = (e.clientY / window.innerHeight) * 2 - 1;
    }, { passive: true });

    api.setProgress = function (v) { state.target = clamp01(v); };
    api.resize = size;
    api.ready = true;
    canvas.classList.add('is-ready');
    return true;
  };

  return api;
})();
