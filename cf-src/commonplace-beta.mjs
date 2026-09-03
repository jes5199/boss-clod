// beta.commonplace.st — phase 1 target. Deployed by cf-deploy.sh, which writes its own provenance.
const HTML = `<!doctype html><meta charset=utf-8><title>commonplace beta</title>
<style>body{font:16px/1.6 system-ui,sans-serif;max-width:34rem;margin:12vh auto;padding:0 1.5rem;
color:#1a1a1a;background:#faf9f7}code{background:#eee7e0;padding:.1em .35em;border-radius:3px}
.m{color:#6b6560;font-size:.9em}</style>
<h1>commonplace &mdash; beta</h1>
<p>This is a deployed placeholder. It exists to prove the deployment path end to end:
a Worker, reachable over TLS, carrying its own provenance record.</p>
<p class=m>Deployed by <code>cf-deploy.sh</code> under commonplace-plan row 218.
Provenance: <code>cf-records/commonplace-beta.md</code>, and on the artifact itself as
<code>prov:*</code> tags.</p>`;
// ⛔ /access-check REPORTS THREE FIELDS AND NOTHING ELSE (ACCESS-1a brief §3.3):
//    assertion_present · kid · iss. NEVER `sub`, NEVER an email, NEVER any token bytes.
// ⭐ It exists as the EDGE-SIDE CONTROL for the claim the app's verifier will later depend on:
//    that Cloudflare Access actually delivers `Cf-Access-Jwt-Assertion` to the origin. Without it,
//    "the header arrives" would be an untested infrastructure assumption — which spec §9.1
//    explicitly forbids ("this behavior must not remain an untested infrastructure assumption").
// ⚠️ A `kid`/`iss` read here is NOT a verification. This Worker checks no signature and MUST NOT
//    be mistaken for one: spec §9.4, "No request is trusted merely because it contains a header
//    named Cf-Access-Jwt-Assertion." Reporting a forged header's `iss` is CORRECT behaviour here —
//    the arm that matters is whether a forged one reaches this code at all.
function inspectAssertion(req) {
  const raw = req.headers.get("cf-access-jwt-assertion");
  if (!raw) return { assertion_present: false, kid: null, iss: null };
  let kid = null, iss = null;
  try {
    const [h, p] = raw.split(".");
    const dec = (s) => JSON.parse(atob(s.replace(/-/g, "+").replace(/_/g, "/")));
    kid = dec(h).kid ?? null;
    iss = dec(p).iss ?? null;   // ⛔ ONLY iss is lifted out of the payload.
  } catch (_) {
    // A malformed header is a real observation, not an error: present but unparseable.
    return { assertion_present: true, kid: null, iss: null, parse: "malformed" };
  }
  return { assertion_present: true, kid, iss };
}

export default {
  fetch(req) {
    const u = new URL(req.url);
    if (u.pathname === "/healthz")
      return Response.json({ ok: true, service: "commonplace-beta", phase: 1 });
    if (u.pathname === "/access-check")
      return Response.json(inspectAssertion(req), {
        headers: { "cache-control": "no-store" },
      });
    return new Response(HTML, { headers: { "content-type": "text/html; charset=utf-8" } });
  },
};
