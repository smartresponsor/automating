// Copyright (c) 2025 Oleksandr Tishchenko / Marketing America Corp

function toHex(bytes) {
    const b = new Uint8Array(bytes);
    let out = '';
    for (let i = 0; i < b.length; i++) out += b[i].toString(16).padStart(2, '0');
    return out;
}

function constantTimeEqual(a, b) {
    if (typeof a !== 'string' || typeof b !== 'string') return false;
    if (a.length !== b.length) return false;
    let diff = 0;
    for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
    return diff === 0;
}

function envStr(env, key, def) {
    const v = env && env[key];
    if (typeof v !== 'string') return def;
    const s = v.trim();
    return s === '' ? def : s;
}

function envInt(env, key, def) {
    const v = envStr(env, key, '');
    if (!v) return def;
    const n = Number(v);
    return Number.isFinite(n) ? n : def;
}

function parseAllowedTask(env) {
    const raw = envStr(env, 'AUTOMATER_ALLOWED_TASK', 'scan,health,doctor,validate,plan,codex,pr');
    return raw.split(',').map((s) => s.trim()).filter(Boolean);
}

function json(status, obj) {
    return new Response(JSON.stringify(obj, null, 2), {
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
    });
}

function bad(status, code, message, extra) {
    return json(status, {ok: false, code, message, ...(extra || {})});
}

function pickKid(request) {
    const kidRaw = (request.headers.get('X-AUTOMATER-Kid') || 'K1').trim().toUpperCase();
    if (!/^K\d+$/.test(kidRaw)) return null;
    return kidRaw;
}

function pickSecret(env, kid) {
    const byKid = envStr(env, `AUTOMATER_TRIGGER_SECRET_${kid}`, '');
    if (byKid) return {secret: byKid, source: `AUTOMATER_TRIGGER_SECRET_${kid}`};

    const legacy = envStr(env, 'AUTOMATER_TRIGGER_SECRET', '');
    if (legacy) return {secret: legacy, source: 'AUTOMATER_TRIGGER_SECRET'};

    return {secret: '', source: ''};
}

async function sha256Hex(data) {
    const bytes = new TextEncoder().encode(data);
    const digest = await crypto.subtle.digest('SHA-256', bytes);
    return toHex(digest);
}

async function hmacSha256Hex(secret, data) {
    const key = await crypto.subtle.importKey(
        'raw',
        new TextEncoder().encode(secret),
        {name: 'HMAC', hash: 'SHA-256'},
        false,
        ['sign']
    );
    const sig = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(data));
    return toHex(sig);
}

export default {
    async fetch(request, env, ctx) {
        const url = new URL(request.url);

        if (url.pathname === '/health' || url.pathname === '/health/') {
            if (request.method !== 'GET') return bad(405, 'MethodNotAllowed', 'GET required');
            const repoName = envStr(env, 'GH_REPO', 'unknown');
            return json(200, {ok: true, service: `${repoName}-automater-trigger`});
        }

        if (url.pathname !== '/dispatch') {
            return bad(404, 'NotFound', 'Use /dispatch or /health');
        }

        if (request.method !== 'POST') {
            return bad(405, 'MethodNotAllowed', 'POST required');
        }

        const kid = pickKid(request);
        if (!kid) return bad(401, 'BadKid', 'Invalid X-AUTOMATER-Kid (expected K1, K2, ...)');

        const {secret, source} = pickSecret(env, kid);
        if (!secret) return bad(500, 'Misconfig', `Secret for ${kid} not configured`, {kid, secretSource: source});

        const tsHeader = request.headers.get('X-AUTOMATER-Timestamp') || '';
        const sigHeader = (request.headers.get('X-AUTOMATER-Signature') || '').toLowerCase();

        const ts = Number(tsHeader);
        if (!Number.isFinite(ts) || ts <= 0) {
            return bad(401, 'BadTimestamp', 'X-AUTOMATER-Timestamp required (unix seconds)');
        }

        const skew = envInt(env, 'AUTOMATER_TIME_SKEW_SEC', 300);
        const now = Math.floor(Date.now() / 1000);
        if (Math.abs(now - ts) > skew) {
            return bad(401, 'TimestampSkew', 'Timestamp outside allowed window');
        }

        const rawBody = await request.text(); // string-only protocol
        const bodyHash = await sha256Hex(rawBody);
        const signed = `${ts}.${bodyHash}`;
        const expected = (await hmacSha256Hex(secret, signed)).toLowerCase();

        if (!constantTimeEqual(expected, sigHeader)) {
            const debugEnabled = envStr(env, 'AUTOMATER_DEBUG', '0') === '1';
            if (debugEnabled) {
                return bad(403, 'BadSignature', 'Signature mismatch', {
                    kid,
                    secretSource: source,
                    debug: {
                        ts,
                        sig: sigHeader,
                        expected,
                        bodyHash,
                        signed,
                        secretSha256: await sha256Hex(secret),
                        rawBody,
                    },
                });
            }
            return bad(403, 'BadSignature', 'Signature mismatch', {kid});
        }

        // Verified; parse JSON and continue.
        let payload;
        try {
            payload = rawBody.trim() ? JSON.parse(rawBody) : {};
        } catch {
            return bad(400, 'BadJson', 'Body must be JSON');
        }

        return await handleAuthorized(env, payload);
    },
};

async function handleAuthorized(env, payload) {
    const task = String(payload?.task || '').trim();
    if (!task) return bad(400, 'BadTask', 'task is required');

    const allowed = parseAllowedTask(env);
    if (!allowed.includes(task)) return bad(400, 'BadTask', `task not allowed: ${task}`);

    const devMode = envStr(env, 'AUTOMATER_DEV_MODE', '0') === '1';

    const owner = envStr(env, 'GH_OWNER', '');
    const repo = envStr(env, 'GH_REPO', '');
    const workflow = envStr(env, 'GH_WORKFLOW', '');
    const token = envStr(env, 'GH_TOKEN', '');
    const refDefault = envStr(env, 'GH_REF', 'master');
    const ghApiVersion = envStr(env, 'GH_API_VERSION', '2022-11-28');

    const ref = String(payload?.ref || refDefault).trim() || refDefault;

    if (!owner || !repo || !workflow) {
        return bad(500, 'Misconfig', 'GH_OWNER/GH_REPO/GH_WORKFLOW must be set');
    }

    // Local dev: allow verifying signatures without GitHub token.
    if (!token) {
        if (devMode) return json(200, {
            ok: true,
            verified: true,
            dispatched: false,
            reason: 'AUTOMATER_DEV_MODE=1 and GH_TOKEN not set'
        });
        return bad(500, 'Misconfig', 'GH_TOKEN must be set');
    }

    const inputs = (payload && typeof payload.inputs === 'object' && payload.inputs) ? payload.inputs : {};
    inputs.task = task;

    const ghUrl = `https://api.github.com/repos/${owner}/${repo}/actions/workflows/${workflow}/dispatches`;

    const ghRes = await fetch(ghUrl, {
        method: 'POST',
        headers: {
            Accept: 'application/vnd.github+json',
            Authorization: `Bearer ${token}`,
            'X-GitHub-Api-Version': ghApiVersion,
            'User-Agent': `automater-${repo}-trigger`,
        },
        body: JSON.stringify({ref, inputs}),
    });

    if (ghRes.status === 204) {
        return json(200, {ok: true, verified: true, dispatched: true, repo: `${owner}/${repo}`, workflow, ref, task});
    }

    const text = await ghRes.text();
    return json(ghRes.status, {
        ok: false,
        verified: true,
        dispatched: false,
        status: ghRes.status,
        repo: `${owner}/${repo}`,
        workflow,
        ref,
        task,
        github: text.slice(0, 2000),
    });
}
