/* ═══════════════════════════════════════════════════════════════
   YSLEM MARKET — CATALOGUE SOURCE
   Single source of truth for the storefront and the price index.
   Every item below is sourced from a real price/stock comparison
   between two competitor resellers; each product carries the
   winning (cheapest available) price and that reseller's real
   stock count. Nothing here is invented.

   Record shape
   ------------
   i   id                      s   shop id
   b   brand key (logo/color)  n   product name
   k   kind: FA | KEY | GIFT | LINK | METHOD | TOOL | SERVICE
   dur duration label          mo  billable months (null = one-off / lifetime)
   p   price EUR               w   retail EUR (0 = no comparison available)
   stock  number, or 'instock' for unmetered/auto-delivered items
   f   flag: hot | best | new  int configurator type
   D   full description override   d  extra description lines
   W   full warning override       w2 extra warning lines
   sp  extra specification pairs
   ═══════════════════════════════════════════════════════════════ */
(function (root) {

  var SHOPS = [
    { id: 'discord', name: 'Discord Shop',     blurb: 'Nitro, boosts and server extras.' },
    { id: 'ai',      name: 'AI Shop',          blurb: 'Chat assistants on paid tiers.' },
    { id: 'stream',  name: 'Streaming Shop',   blurb: 'Video and music, lifetime keys and accounts.' },
    { id: 'vpn',     name: 'VPN Shop',         blurb: 'Lifetime VPN access.' },
    { id: 'gaming',  name: 'Gaming Shop',      blurb: 'Accounts and currency across platforms.' },
    { id: 'tools',   name: 'Tools Shop',       blurb: 'Editing software and reseller supplies.' },
    { id: 'smm',     name: 'Social Shop',      blurb: 'Boosting services, per 1000.' }
  ];

  /* Brand tint used behind logos and on shop headers. */
  var BRANDS = {
    discord: '#5865F2', telegram: '#26A5E4', tiktok: '#FF0050', instagram: '#E4405F',
    twitter: '#ffffff', twitch: '#9146FF', roblox: '#E2231A', steam: '#66C0F4',
    openai: '#10a37f', claude: '#D97757', gemini: '#4285F4', netflix: '#E50914',
    spotify: '#1DB954', disney: '#0063e5', hbo: '#A020F0', crunchy: '#F47521',
    youtube: '#FF0000', prime: '#00A8E1', deezer: '#A238FF', nord: '#4687FF',
    express: '#DA3940', minecraft: '#62B47A', fortnite: '#8B5CF6', xbox: '#107C10',
    capcut: '#00D9E9', apple: '#F0F0F5', paramount: '#0064FF', valorant: '#FF4655',
    kick: '#53FC18', facebook: '#1877F2', dazn: '#F8FF13', cs2: '#DE9B35',
    fivem: '#F40552', accsupplier: '#8A97A8', sellauth: '#FF5FA8'
  };

  /* ── copy templates by kind ─────────────────────────────────── */
  var DESC = {
    FA: ['Full access account, credentials sent after payment.', 'Checked before listing.', 'Delivered within a minute of confirmation.', 'Open a ticket if something does not work.'],
    KEY: ['Applied to an account, delivered as a login key.', 'Checked before listing.', 'Delivered within a minute of confirmation.', 'Replacement handled through a ticket.'],
    GIFT: ['Delivered as a gift link you claim yourself.', 'Nothing is shared, no login required.', 'Delivered within a minute of confirmation.', 'Open a ticket if the link fails.'],
    LINK: ['Delivered as an activation link for your own account.', 'Nothing is shared, no login required.', 'Delivered within a minute of confirmation.', 'Open a ticket if the link fails.'],
    METHOD: ['Step by step method, delivered as text.', 'Written for the current version of the platform.', 'Delivered after payment confirmation.', 'Open a ticket if a step is unclear.'],
    TOOL: ['Delivered as a ready to run tool with instructions.', 'No installation is done for you.', 'Delivered after payment confirmation.', 'Open a ticket if something does not work.'],
    SERVICE: ['Ordered against a public profile or link.', 'No password or login required.', 'Started after payment confirmation.', 'Open a ticket if delivery stalls.']
  };
  var WARN = {
    FA: ['Is Full Access, revokes are possible.', 'Do not change the password, email or recovery options.', 'Warranty is void once the credentials are modified.'],
    KEY: ['Account must have no active plan of the same type.', 'Cancel any running trial before redeeming.', 'Never change the password on a shared account.'],
    GIFT: ['Claimed on your own account, no token login.', 'Record a screen video while claiming for warranty.', 'No replacement during a provider-wide revoke wave.'],
    LINK: ['The link works once, follow the steps exactly.', 'Account must have no active plan of the same type.', 'No replacement once the link has been opened.'],
    METHOD: ['The provider can patch the method at any time.', 'Lifetime refers to the method, not the outcome.', 'No replacement once the method is delivered.'],
    TOOL: ['Automating a user account breaks most terms of service.', 'Your account can be terminated for using it.', 'No replacement if your account is banned.'],
    SERVICE: ['Delivery is bot traffic, drops are expected.', 'The platform can purge it at any time.', 'Target must stay public for the whole delivery window.']
  };
  var TYPEN = { FA: 'Full Access', KEY: 'Login key', GIFT: 'Gift link', LINK: 'Activation link', METHOD: 'Method', TOOL: 'Tool', SERVICE: 'SMM service' };
  var SUPPORT = { FA: '7 days', KEY: 'Open ticket', GIFT: '15 days', LINK: '30 days', METHOD: 'Ticket only', TOOL: 'Ticket only', SERVICE: '48 hours' };

  function mk(o) {
    var desc = o.D || DESC[o.k].concat(o.d || []);
    var warn = o.W || WARN[o.k].concat(o.w2 || []);
    var sp = { Type: TYPEN[o.k], Duration: o.dur, Delivery: o.del || 'Instant', Support: o.sup || SUPPORT[o.k] };
    if (o.sp) { for (var key in o.sp) sp[key] = o.sp[key]; }
    return {
      id: o.i, shop: o.s, brand: o.b, name: o.n, kind: o.k, dur: o.dur,
      months: o.mo === undefined ? null : o.mo,
      price: o.p, retail: o.w || 0, flag: o.f || null,
      stock: o.stock === undefined ? null : o.stock, /* number, or 'instock' for unmetered availability */
      int: o.int || 'basic', smm: o.smm || null,
      opts: o.opts || null,
      desc: desc, warn: warn, sp: sp
    };
  }

  var RAW = [

    /* ════════ STREAMING SHOP ════════ */
    { i: 1, s: 'stream', b: 'netflix', n: 'Netflix Keys Lifetime (4K)', k: 'KEY', dur: 'Lifetime', p: 0.04, w: 0.10, stock: 198, f: 'hot',
      int: 'stream', opts: [['Standard', 0], ['4K', 0.05]],
      sp: { Plan: '4K Ultra HD' } },
    { i: 2, s: 'stream', b: 'netflix', n: 'Netflix FA 4K (Lifetime)', k: 'FA', dur: 'Lifetime', p: 0.63, w: 1.95, stock: 7,
      int: 'ai', sp: { Plan: 'Premium 4K' } },
    { i: 3, s: 'stream', b: 'disney', n: 'Disney+ Lifetime UHQ', k: 'KEY', dur: 'Lifetime', p: 0.13, w: 0.15, stock: 9,
      int: 'stream', opts: [['Standard', 0], ['Disney + Hulu', 0.20]],
      sp: { Plan: 'UHQ' } },
    { i: 4, s: 'stream', b: 'crunchy', n: 'Crunchyroll Lifetime Keys', k: 'KEY', dur: 'Lifetime', p: 0.15, stock: 27,
      int: 'stream', opts: [['Fan', 0], ['Mega Fan', 0.10]] },
    { i: 5, s: 'stream', b: 'hbo', n: 'HBO Max Lifetime', k: 'KEY', dur: 'Lifetime', p: 0.13, w: 0.14, stock: 12,
      int: 'stream', opts: [['Standard', 0], ['4K Ultimate', 0.15]] },
    { i: 6, s: 'stream', b: 'paramount', n: 'Paramount+ Lifetime', k: 'KEY', dur: 'Lifetime', p: 0.07, w: 0.15, stock: 240, f: 'best' },
    { i: 7, s: 'stream', b: 'dazn', n: 'DAZN NFA Lifetime', k: 'KEY', dur: 'Lifetime', p: 0.24, w: 0.25, stock: 25,
      d: ['No Full Access — sign in with the key on the DAZN app.'],
      sp: { Sport: 'Full DAZN catalogue' } },
    { i: 8, s: 'stream', b: 'prime', n: 'Prime Video Keys Lifetime', k: 'KEY', dur: 'Lifetime', p: 0.19, w: 0.29, stock: 43 },
    { i: 9, s: 'stream', b: 'spotify', n: 'Spotify Lifetime KEY', k: 'KEY', dur: 'Lifetime', p: 0.63, w: 1.30, stock: 60, f: 'hot',
      int: 'ownacct', label: 'Spotify account email' },
    { i: 10, s: 'stream', b: 'deezer', n: 'Deezer Premium Lifetime', k: 'KEY', dur: 'Lifetime', p: 0.06, w: 0.07, stock: 4,
      sp: { Plan: 'Premium HiFi' } },
    { i: 11, s: 'stream', b: 'apple', n: 'Apple Music+ FA (1 mois)', k: 'FA', dur: '1 month', mo: 1, p: 0.44, stock: 4 },

    /* ════════ AI SHOP ════════ */
    { i: 12, s: 'ai', b: 'openai', n: 'ChatGPT+ / Pro Lifetime', k: 'FA', dur: 'Lifetime', p: 1.24, w: 1.50, stock: 3, f: 'hot' },
    { i: 13, s: 'ai', b: 'gemini', n: 'Gemini Pro+ (Link 18 mois)', k: 'LINK', dur: '18 months', mo: 18, p: 0.80, w: 0.89, stock: 21 },
    { i: 14, s: 'ai', b: 'claude', n: 'Claude FA Unlimited (Daily)', k: 'FA', dur: '1 day', p: 3.74, stock: 27,
      d: ['Billed per day — pay only for the days you use it.'] },
    { i: 15, s: 'ai', b: 'claude', n: 'Claude FA Unlimited (Monthly)', k: 'FA', dur: '1 month', mo: 1, p: 5.00, stock: 7, f: 'best',
      d: ['Billed once for the full month, no daily top-ups needed.'] },

    /* ════════ DISCORD SHOP ════════ */
    { i: 16, s: 'discord', b: 'discord', n: '14x Server Boosts (1 semaine)', k: 'SERVICE', dur: '1 week', p: 1.57, stock: 11,
      d: ['Send your server invite link in the ticket message.'], sp: { Amount: '14 boosts' } },
    { i: 17, s: 'discord', b: 'discord', n: '14x Server Boosts (1 mois)', k: 'SERVICE', dur: '1 month', mo: 1, p: 2.49, stock: 'instock', f: 'best',
      d: ['Send your server invite link in the ticket message.'], sp: { Amount: '14 boosts' } },
    { i: 18, s: 'discord', b: 'discord', n: 'Nitro Promo (3 mois)', k: 'GIFT', dur: '3 months', mo: 3, p: 0.67, w: 0.75, stock: 8, f: 'hot',
      int: 'nitro' },
    { i: 19, s: 'discord', b: 'discord', n: 'Nitro Boost ID (1 mois)', k: 'GIFT', dur: '1 month', mo: 1, p: 0.35, stock: 2,
      int: 'nitro', d: ['Full Nitro with boosts included, on one gift link.'] },
    { i: 20, s: 'discord', b: 'discord', n: 'Discord Random Decoration Keys', k: 'KEY', dur: 'Lifetime', p: 1.99, stock: 3,
      d: ['A random profile decoration from the Discord shop catalogue.'],
      w2: ['The decoration is randomly assigned, it cannot be chosen.'] },

    /* ════════ GAMING SHOP ════════ */
    { i: 21, s: 'gaming', b: 'fortnite', n: 'Fortnite FA Accounts (3-10 skins)', k: 'FA', dur: 'Permanent', p: 0.19, w: 1.00, stock: 24, f: 'hot',
      sp: { Skins: '3-10' } },
    { i: 22, s: 'gaming', b: 'roblox', n: 'Roblox 2000+ Robux Account', k: 'FA', dur: 'Permanent', p: 3.60, w: 4.00, stock: 3,
      sp: { Robux: '2000+' } },
    { i: 23, s: 'gaming', b: 'cs2', n: 'CS2 Prime NFA Accounts', k: 'KEY', dur: 'Permanent', p: 1.88, stock: 24,
      d: ['No Full Access — Prime status applied, sign in with the key.'] },
    { i: 24, s: 'gaming', b: 'valorant', n: 'Valorant Account (1-1000 skins)', k: 'FA', dur: 'Permanent', p: 0.09, stock: 145,
      sp: { Skins: '1-1000' } },
    { i: 25, s: 'gaming', b: 'steam', n: 'Steam (avec jeux, Lifetime)', k: 'FA', dur: 'Lifetime', p: 0.03, w: 0.50, stock: 215, f: 'best' },
    { i: 26, s: 'gaming', b: 'xbox', n: 'Xbox Gamepass Ultimate (12 mois)', k: 'KEY', dur: '12 months', mo: 12, p: 2.50, stock: 10,
      sp: { Tier: 'Ultimate' } },
    { i: 27, s: 'gaming', b: 'minecraft', n: 'Minecraft FA', k: 'FA', dur: 'Permanent', p: 0.37, w: 3.95, stock: 4 },
    { i: 28, s: 'gaming', b: 'fivem', n: 'FiveM Ready FA (Rockstar)', k: 'FA', dur: 'Permanent', p: 0.02, stock: 158,
      d: ['Rockstar account pre-checked as ready for FiveM roleplay servers.'] },

    /* ════════ VPN SHOP ════════ */
    { i: 29, s: 'vpn', b: 'express', n: 'ExpressVPN Lifetime', k: 'KEY', dur: 'Lifetime', p: 0.13, w: 0.15, stock: 3, f: 'best',
      sp: { Platform: 'iOS / Android' } },
    { i: 30, s: 'vpn', b: 'nord', n: 'NordVPN Lifetime', k: 'FA', dur: 'Lifetime', p: 0.69, stock: 24 },

    /* ════════ SOCIAL SHOP ════════ */
    { i: 31, s: 'smm', b: 'tiktok', n: 'TikTok Services', k: 'SERVICE', dur: 'Per 1000', p: 0.02, stock: 'instock',
      int: 'smm', smm: { unit: 'followers', min: 100, max: 50000, step: 100, rate: 0.01, field: 'TikTok username', ph: '@yourhandle' } },
    { i: 32, s: 'smm', b: 'instagram', n: 'Instagram Boosting', k: 'SERVICE', dur: 'Per 1000', p: 0.02, stock: 'instock',
      int: 'smm', smm: { unit: 'followers', min: 100, max: 50000, step: 100, rate: 0.01, field: 'Instagram username', ph: '@yourhandle' } },
    { i: 33, s: 'smm', b: 'youtube', n: 'YouTube Boosting', k: 'SERVICE', dur: 'Per 1000', p: 0.02, stock: 'instock',
      int: 'smm', smm: { unit: 'views', min: 1000, max: 200000, step: 1000, rate: 0.01, field: 'Video link', ph: 'youtube.com/watch?v=...' } },
    { i: 34, s: 'smm', b: 'telegram', n: 'Telegram Boost', k: 'SERVICE', dur: 'Per 1000', p: 0.02, w: 1.15, stock: 'instock', f: 'hot',
      int: 'smm', smm: { unit: 'members', min: 100, max: 20000, step: 100, rate: 0.01, field: 'Channel link', ph: 't.me/yourchannel' } },
    { i: 35, s: 'smm', b: 'twitch', n: 'Twitch Boost', k: 'SERVICE', dur: 'Per 1000', p: 0.02, stock: 'instock',
      int: 'smm', smm: { unit: 'followers', min: 100, max: 20000, step: 100, rate: 0.01, field: 'Twitch channel', ph: 'twitch.tv/yourchannel' } },
    { i: 36, s: 'smm', b: 'facebook', n: 'Facebook Boost', k: 'SERVICE', dur: 'Per 1000', p: 0.02, stock: 'instock',
      int: 'smm', smm: { unit: 'likes', min: 100, max: 20000, step: 100, rate: 0.01, field: 'Page link', ph: 'facebook.com/yourpage' } },
    { i: 37, s: 'smm', b: 'twitter', n: 'X (Twitter) Boost', k: 'SERVICE', dur: 'Per 1000', p: 0.02, stock: 'instock',
      int: 'smm', smm: { unit: 'followers', min: 100, max: 50000, step: 100, rate: 0.01, field: 'X username', ph: '@yourhandle' } },
    { i: 38, s: 'smm', b: 'kick', n: 'Kick Boost', k: 'SERVICE', dur: 'Per 1000', p: 0.02, stock: 'instock',
      int: 'smm', smm: { unit: 'followers', min: 100, max: 20000, step: 100, rate: 0.01, field: 'Kick channel', ph: 'kick.com/yourchannel' } },

    /* ════════ TOOLS SHOP ════════ */
    { i: 39, s: 'tools', b: 'capcut', n: 'CapCut Pro Lifetime', k: 'KEY', dur: 'Lifetime', p: 0.13, w: 0.15, stock: 30 },
    { i: 40, s: 'tools', b: 'accsupplier', n: 'NFA Accs Supplier', k: 'SERVICE', dur: 'Per account', p: 1.88, w: 7.00, stock: 'instock',
      d: ['Bulk account supply for resellers — priced per account, no login required to order.'],
      sp: { Unit: 'Per account' } },
    { i: 41, s: 'tools', b: 'discord', n: 'Discord Tool & Bot SRC', k: 'TOOL', dur: 'Lifetime', p: 1.07, stock: 'instock',
      d: ['Source code for a Discord bot, delivered with setup instructions.'],
      sp: { Format: 'Source code' } },
    { i: 42, s: 'tools', b: 'sellauth', n: 'SellAuth Themes (Flame / Retro)', k: 'TOOL', dur: 'Lifetime', p: 1.25, stock: 50,
      d: ['Storefront theme for SellAuth — Flame and Retro styles included.'],
      sp: { Format: 'Storefront theme' } }
  ];

  var PRODUCTS = RAW.map(mk);

  root.YSLEM = { shops: SHOPS, brands: BRANDS, products: PRODUCTS };

  if (typeof module !== 'undefined' && module.exports) module.exports = root.YSLEM;

})(typeof window !== 'undefined' ? window : globalThis);
