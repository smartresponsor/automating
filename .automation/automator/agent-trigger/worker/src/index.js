export default {
    async fetch(request, env, ctx) {
        const url = new URL(request.url);
        if (url.pathname === '/health') return json({ok: true, service: 'automate-agent-trigger'});

        if (url.pathname !== '/dispatch') return json({ok: false, code: 'NotFound'}, 404);
        if (request.method !== 'POST') return json({ok: false, code: 'MethodNotAllowed'}, 405);

        const debug = envStr(env, 'AUTOMATE_DEBUG', '0') === '1';
        const devMode = envStr(env, 'AUTOMATE_DEV_MODE', '0') === '1';

        const rawBody = await request.text();
        const ts = headerAny(request, ['X-AUTOMATE-Ts', 'X-AUTOMATER-Ts']);
        const kid = normalizeKid(headerAny(request, ['X-AUTOMATE-Kid', 'X-AUTOMATER-Kid']) || 'K1');
        const sig = headerAny(request, ['X-AUTOMATE-Signature', 'X-AUTOMATER-Signature']);

        if (!ts || !sig) return json({ok: false, code: 'MissingAuth', kid}, 400);

        const tsInt = parseInt(ts, 10);
        if (!Number.isFinite(tsInt)) return json({ok: false, code: 'BadTs', kid}, 400);

        const skew = parseInt(envStr(env, 'AUTOMATE_TS_SKEW_SEC', '300'), 10);
        const now = Math.floor(Date.now() / 1000);
        if (Math.abs(now - tsInt) > skew && !devMode) {
            return json({ok: false, code: 'TsSkew', kid, now, ts: tsInt}, 401);
        }

        const secret = resolveSecret(env, kid);
        if (!secret) return json({ok: false, code: 'MissingSecret', kid}, 500);

        const bodyHash = await sha256Hex(rawBody);
        const expected = await hmacSha256Hex(secret, `${tsInt}.${bodyHash}`);
        if (!timingSafeEqual(sig, expected)) {
            return json({ok: false, code: 'BadSignature', kid, ...(debug ? {expected, bodyHash, ts: tsInt} : {})}, 401);
        }

        let payload;
        try {
            payload = JSON.parse(rawBody);
        } catch {
            return json({ok: false, code: 'BadJson', kid}, 400);
        }

        const task = String(payload.task || '').trim();
        if (!task) return json({ok: false, code: 'MissingTask', kid}, 400);

        const allowed = parseAllowed(envStr(env, 'AUTOMATE_ALLOWED_TASK', envStr(env, 'AUTOMATER_ALLOWED_TASK', 'health')));
        if (!allowed.has(task)) return json({ok: false, code: 'TaskNotAllowed', kid, task}, 403);

        // GitHub workflow dispatch
        const ghOwner = envStr(env, 'GH_OWNER', '');
        const ghRepo = envStr(env, 'GH_REPO', '');
        const ghWorkflow = envStr(env, 'GH_WORKFLOW', '');
        const ghRef = envStr(env, 'GH_REF', 'master');
        const ghToken = envStr(env, 'GITHUB_TOKEN', '');

        if (!ghOwner || !ghRepo || !ghWorkflow || !ghToken) {
            return json({ok: false, code: 'MissingGhConfig'}, 500);
        }

        const dispatchBody = {
            ref: ghRef,
            inputs: {
                task,
                kid
            }
        };

        const resp = await fetch(`https://api.github.com/repos/${ghOwner}/${ghRepo}/actions/workflows/${ghWorkflow}/dispatches`, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${ghToken}`,
                'Accept': 'application/vnd.github+json',
                'User-Agent': 'automate-agent-trigger'
            },
            body: JSON.stringify(dispatchBody)
        });

        if (resp.status !== 204) {
            const text = await resp.text();
            return json({ok: false, code: 'GhDispatchFailed', status: resp.status, body: text}, 502);
        }

        return json({ok: true, task});
    }
};

function envStr(env, key, defVal) {
    const v = env[key];
    if (v === undefined || v === null) return defVal;
    const s = String(v);
    return s.trim();
}

function headerAny(request, keys) {
    for (const k of keys) {
        const v = request.headers.get(k);
        if (v) return v;
    }
    return null;
}

function normalizeKid(kid) {
    const s = String(kid).trim().toUpperCase();
    if (!/^K\d+$/.test(s)) return 'K1';
    return s;
}

function resolveSecret(env, kid) {
    // preferred
    const k = `AUTOMATE_TRIGGER_SECRET_${kid}`;
    const v = envStr(env, k, '');
    if (v) return v;

    // legacy compatibility
    const k2 = `AUTOMATER_TRIGGER_SECRET_${kid}`;
    const v2 = envStr(env, k2, '');
    if (v2) return v2;

    // fallback legacy flat
    const v3 = envStr(env, 'AUTOMATE_TRIGGER_SECRET', envStr(env, 'AUTOMATER_TRIGGER_SECRET', ''));
    if (v3) return v3;

    return '';
}

function parseAllowed(csv) {
    const set = new Set();
    String(csv || '').split(',').map(s => s.trim()).filter(Boolean).forEach(v => set.add(v));
    return set;
}

async function sha256Hex(text) {
    const data = new TextEncoder().encode(text);
    const buf = await crypto.subtle.digest('SHA-256', data);
    return buf2hex(buf);
}

async function hmacSha256Hex(secret, msg) {
    const key = await crypto.subtle.importKey(
        'raw',
        new TextEncoder().encode(secret),
        {name: 'HMAC', hash: 'SHA-256'},
        false,
        ['sign']
    );
    const sig = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(msg));
    return buf2hex(sig);
}

function buf2hex(buf) {
    const bytes = new Uint8Array(buf);
    let out = '';
    for (let i = 0; i < bytes.length; i++) out += bytes[i].toString(16).padStart(2, '0');
    return out;
}

function timingSafeEqual(a, b) {
    const aa = String(a || '');
    const bb = String(b || '');
    if (aa.length !== bb.length) return false;
    let res = 0;
    for (let i = 0; i < aa.length; i++) res |= aa.charCodeAt(i) ^ bb.charCodeAt(i);
    return res === 0;
}

function json(obj, status = 200) {
    return new Response(JSON.stringify(obj), {
        status,
        headers: {'content-type': 'application/json; charset=utf-8'}
    });
}
