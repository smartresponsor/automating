// Copyright (c) 2025 Oleksandr Tishchenko / Marketing America Corp
import test from "node:test";
import assert from "node:assert/strict";
import worker from "../src/index.js";

const enc = new TextEncoder();

async function sha256hex(raw) {
  const buf = enc.encode(raw);
  const digest = await crypto.subtle.digest("SHA-256", buf);
  return Array.from(new Uint8Array(digest)).map(b => b.toString(16).padStart(2, "0")).join("");
}

async function hmacHex(secret, data) {
  const key = await crypto.subtle.importKey(
    "raw",
    enc.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const sig = await crypto.subtle.sign("HMAC", key, enc.encode(data));
  return Array.from(new Uint8Array(sig)).map(b => b.toString(16).padStart(2, "0")).join("");
}

function jsonHeaders(extra = {}) {
  return { "content-type": "application/json; charset=utf-8", ...extra };
}

test("health returns ok", async () => {
  process.env.GH_OWNER = "o";
  process.env.GH_REPO = "r";
  process.env.GH_WORKFLOW = "automater-dispatch.yml";

  const req = new Request("https://example.test/health", { method: "GET" });
  const res = await worker.fetch(req, {}, {});
  assert.equal(res.status, 200);
  const j = await res.json();
  assert.equal(j.ok, true);
  assert.equal(typeof j.service, "string");
});

test("dispatch without timestamp is rejected", async () => {
  process.env.GH_OWNER = "o";
  process.env.GH_REPO = "r";
  process.env.GH_WORKFLOW = "automater-dispatch.yml";
  process.env.AUTOMATER_ALLOWED_TASK = "health";
  process.env.AUTOMATER_TRIGGER_SECRET_K1 = "s";
  process.env.AUTOMATER_DEV_MODE = "1";

  const body = JSON.stringify({ task: "health" });
  const req = new Request("https://example.test/dispatch", {
    method: "POST",
    headers: jsonHeaders({ "X-AUTOMATER-Kid": "K1", "X-AUTOMATER-Signature": "00" }),
    body
  });

  const res = await worker.fetch(req, {}, {});
  assert.equal(res.status, 401);
  const j = await res.json();
  assert.equal(j.ok, false);
  assert.equal(j.code, "BadTimestamp");
});

test("dispatch with valid signature verifies in dev mode", async () => {
  process.env.GH_OWNER = "o";
  process.env.GH_REPO = "r";
  process.env.GH_WORKFLOW = "automater-dispatch.yml";
  process.env.AUTOMATER_ALLOWED_TASK = "health";
  process.env.AUTOMATER_TRIGGER_SECRET_K1 = "mysecret";
  process.env.AUTOMATER_DEV_MODE = "1";
  process.env.AUTOMATER_DEBUG = "0";
  process.env.AUTOMATER_TIME_SKEW_SEC = "300";
  delete process.env.GH_TOKEN;

  const body = JSON.stringify({ task: "health", ref: "master", inputs: { kind: "fix" } });
  const ts = Math.floor(Date.now() / 1000).toString();
  const bodyHash = await sha256hex(body);
  const signed = `${ts}.${bodyHash}`;
  const sig = await hmacHex(process.env.AUTOMATER_TRIGGER_SECRET_K1, signed);

  const req = new Request("https://example.test/dispatch", {
    method: "POST",
    headers: jsonHeaders({
      "X-AUTOMATER-Kid": "K1",
      "X-AUTOMATER-Timestamp": ts,
      "X-AUTOMATER-Signature": sig
    }),
    body
  });

  const res = await worker.fetch(req, {}, {});
  assert.equal(res.status, 200);
  const j = await res.json();
  assert.equal(j.ok, true);
  assert.equal(j.verified, true);
  assert.equal(j.dispatched, false);
});
