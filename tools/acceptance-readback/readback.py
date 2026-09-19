"""Review-stage GET-only collector. No cloud access on import or without --execute-reads."""
import argparse
import datetime
import fnmatch
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import stat
import subprocess
import urllib.error
import urllib.request
import uuid

ACCOUNT = 'd5c4856e9cb4dd41c12b39fb9df29726'
ZONE = 'fcb470ab1801e322f47cd76e3a11fee1'
APP = 'bdf850ac-8749-48f0-9568-c31390a8099c'
CONTAINER = 'a03286c5-d425-45b6-8d23-6c9a450b6bfb'
COMMIT = '0fdf8a1fe0ba747a491ed7dbd5de5ba2dbc93790'
TREE = 'e12015d367f5af7fb39e7d8df11287e8b3a9d765'
REPO = Path('/home/jes/commonplace-next-acceptance-access-1')
HOST = 'acceptance-next.commonplace.st'
NAME = 'commonplace-next-acceptance'
REALM = '9671868b-3a4b-4b9c-9fe5-a7f907119cdb'
CREDENTIAL = Path('/home/jes/.config/cloudflare/do-worker.env')
# Fixed endpoint paths; no arbitrary URL, method, credential path, or application probe.
SPECS = {
    'accounts': ('accounts', 'paged', 50),
    'zones': (f'zones?account.id={ACCOUNT}', 'paged', 50),
    'dns': (f'zones/{ZONE}/dns_records', 'paged', 100),
    'routes': (f'zones/{ZONE}/workers/routes', 'list', 1000),
    'workers': (f'accounts/{ACCOUNT}/workers/scripts', 'list', 1000),
    'containers': (f'accounts/{ACCOUNT}/containers/applications', 'paged', 100),
    'access_apps': (f'accounts/{ACCOUNT}/access/apps', 'paged', 100),
    'human_policies': (f'accounts/{ACCOUNT}/access/apps/{APP}/policies', 'paged', 100),
    'service_tokens': (f'accounts/{ACCOUNT}/access/service_tokens', 'paged', 100),
    'settings': (f'accounts/{ACCOUNT}/workers/scripts/commonplace-next/settings', 'object', 0),
}


class Refusal(Exception):
    """Only fixed local reason codes may reach a receipt."""


class Deadline(BaseException):
    """Must escape per-endpoint exception handling."""


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        raise Refusal('redirect_refused')


def source():
    def git(*args):
        return subprocess.check_output(['git', '-C', str(REPO), *args],
                                       text=True, stderr=subprocess.DEVNULL, timeout=5).strip()
    if (git('rev-parse', 'HEAD') != COMMIT or git('rev-parse', 'HEAD^{tree}') != TREE
            or git('branch', '--show-current') != 'work/acceptance-access-1'
            or git('status', '--porcelain', '--untracked-files=all')):
        raise Refusal('candidate_source_mismatch')
    return {'commit': COMMIT, 'tree': TREE, 'branch': 'work/acceptance-access-1', 'clean': True}


def credential():
    # Validate and read one descriptor; O_NONBLOCK avoids hanging on a substituted FIFO.
    fd = os.open(CREDENTIAL, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK | os.O_CLOEXEC)
    with os.fdopen(fd, 'r') as handle:
        st = os.fstat(handle.fileno())
        if not stat.S_ISREG(st.st_mode) or st.st_mode & 0o077 or st.st_uid != os.getuid():
            raise Refusal('credential_custody_permissions')
        content = handle.read(65537)
        after = os.fstat(handle.fileno())
        if len(content) > 65536 or (st.st_size, st.st_mtime_ns, st.st_ctime_ns) != (
                after.st_size, after.st_mtime_ns, after.st_ctime_ns):
            raise Refusal('credential_size_or_drift')
    values = [line.split('=', 1)[1].strip().strip('\"\'')
              for line in content.splitlines()
              if line.startswith('CLOUDFLARE_API_TOKEN=')]
    if len(values) != 1 or not values[0] or '\n' in values[0] or '\r' in values[0]:
        raise Refusal('credential_unavailable')
    return values[0]


class Transport:
    def __init__(self, token):
        self.token = token
        self.opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())

    def get(self, key, page=1):
        path, mode, limit = SPECS[key]
        if mode == 'paged':
            path += ('&' if '?' in path else '?') + f'page={page}&per_page={limit}'
        request = urllib.request.Request('https://api.cloudflare.com/client/v4/' + path,
                                         headers={'Authorization': 'Bearer ' + self.token}, method='GET')
        try:
            with self.opener.open(request, timeout=15) as response:
                raw = response.read(4 * 1024 * 1024 + 1)
                if len(raw) > 4 * 1024 * 1024:
                    raise Refusal('response_size_bound')
                return response.status, json.loads(raw)
        except Refusal:
            raise
        except Exception:
            # Never serialize exception messages, headers, URLs, response bodies or tracebacks.
            raise Refusal('transport_or_decode_failure') from None


def fetch(transport, key):
    _, mode, limit = SPECS[key]
    rows = []
    expected_total = None
    for page in range(1, 11):
        status, body = transport.get(key, page)
        if status != 200 or not isinstance(body, dict) or body.get('success') is not True:
            raise Refusal('unsuccessful_response')
        result = body.get('result')
        if mode == 'object':
            if not isinstance(result, dict):
                raise Refusal('invalid_object')
            return result, 1
        if not isinstance(result, list) or any(not isinstance(r, dict) for r in result):
            raise Refusal('invalid_list')
        if len(result) > limit:
            raise Refusal('page_size_bound')
        if mode == 'list':
            validate_ids(result)
            return result, 1
        info = body.get('result_info')
        # No inferred completeness from a short page. Missing pagination is a HOLD.
        if not isinstance(info, dict):
            raise Refusal('pagination_metadata_missing')
        total = info.get('total_count')
        if type(total) is not int or total < 0 or total > 1000 or info.get('page') != page:
            raise Refusal('pagination_metadata_invalid')
        if expected_total is not None and total != expected_total:
            raise Refusal('pagination_drift')
        expected_total = total
        rows.extend(result)
        if len(rows) == total:
            validate_ids(rows)
            return rows, page
        if not result or len(rows) > total:
            raise Refusal('pagination_incomplete')
    raise Refusal('pagination_bound')


def validate_ids(rows):
    ids = [r.get('id') for r in rows]
    if any(not isinstance(i, str) for i in ids) or len(set(ids)) != len(ids):
        raise Refusal('duplicate_or_missing_ids')


def match(pattern, value):
    if not isinstance(pattern, str) or len(pattern) > 1024:
        raise Refusal('invalid_match_field')
    # Only * has wildcard meaning on these surfaces; uncertain syntax is refused.
    if any(c in pattern for c in '?[]\\'):
        raise Refusal('unsupported_match_syntax')
    return fnmatch.fnmatchcase(value.lower(), pattern.lower())


def assess(key, rows):
    controls = {'accounts': ('id', ACCOUNT), 'zones': ('id', ZONE),
                'dns': ('name', 'beta-next.commonplace.st'),
                'routes': ('pattern', 'beta-next.commonplace.st/*'),
                'workers': ('id', 'commonplace-next'), 'containers': ('id', CONTAINER),
                'access_apps': ('id', APP),
                'human_policies': ('id', 'd41759c0-5604-47b7-a5da-4eafdd7dd6d9')}
    predicate = {
        'dns': lambda r: match(r['name'], HOST),
        # Compare the route host, conservatively refusing any path on the reserved host.
        'routes': lambda r: match(r['pattern'].split('://')[-1].split('/')[0], HOST),
        'workers': lambda r: r['id'] == NAME,
        'containers': lambda r: r['name'] == NAME,
        'access_apps': lambda r: r['name'] == NAME or any(
            match(d.split('://')[-1].split('/')[0], HOST)
            for d in [r['domain']] + r.get('self_hosted_domains', [])),
        'human_policies': lambda r: r['name'] == NAME,
        'service_tokens': lambda r: r['name'] in (NAME + '-g1-20260919', NAME + '-g2-20260919'),
    }.get(key, lambda r: False)
    collisions = sum(bool(predicate(r)) for r in rows)
    control = controls.get(key)
    positive = bool(control and any(r.get(control[0]) == control[1] for r in rows))
    return {'count': len(rows), 'collision_count': collisions,
            'positive_control': control[1] if positive else None,
            'verdict': 'HOLD_NO_KNOWN_CONTROL' if not positive else (
                'COLLISION' if collisions else 'CONTROLLED_NO_MATCH')}


def human(settings):
    bindings = settings.get('bindings')
    if not isinstance(bindings, list):
        raise Refusal('settings_bindings_missing')
    found = [b for b in bindings if isinstance(b, dict) and b.get('name') == 'COMMONPLACE_LOG_REALM_URL']
    result = {'organization_id': 'REQUIRED_PENDING_READBACK',
              'organization_reason': 'No reviewed read-only application organization endpoint; Access account/team is not application organization.',
              'realm_id': 'REQUIRED_PENDING_READBACK'}
    if len(found) != 1 or found[0].get('type') != 'plain_text':
        result['realm_reason'] = 'Binding absent, ambiguous or not public plain_text; no secret retrieval attempted.'
        return result
    # No query/userinfo/fragment; only the nonsecret realm UUID is emitted.
    value = found[0].get('text')
    matched = re.fullmatch(r'https://[a-z0-9.-]+/realms/([0-9a-f-]{36})/?', value or '')
    if not matched:
        raise Refusal('realm_public_value_invalid')
    realm = str(uuid.UUID(matched[1]))
    result.update(realm_id=realm, realm_collision=realm == REALM,
                  realm_basis='live Worker settings plain_text binding; not a runtime activation proof')
    return result


def collect(transport):
    report = {'reads': {}, 'human': {}, 'state': 'HOLD', 'provider_mutations': False,
              'lifetime_note': '300s is candidate configuration only; no Cloudflare JWT lifetime observation.'}
    for key in SPECS:
        try:
            rows, pages = fetch(transport, key)
            if key == 'settings':
                report['human'] = human(rows)
                report['reads'][key] = {'pages': pages, 'endpoint': 'GET /' + SPECS[key][0]}
            else:
                report['reads'][key] = dict(assess(key, rows), pages=pages, endpoint='GET /' + SPECS[key][0])
                if key in ('accounts', 'zones') and report['reads'][key]['positive_control'] is None:
                    break
        except Exception:
            report['reads'][key] = {'verdict': 'HOLD_READ_OR_SCHEMA_FAILURE', 'endpoint': 'GET /' + SPECS[key][0]}
            if key in ('accounts', 'zones'):
                break
    # There is intentionally no overall GREEN: human app org has no approved read surface.
    return report


def instrument_identity(loaded_sha256):
    try:
        post = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    except Exception:
        post = None
    return {'loaded_sha256': loaded_sha256, 'post_sha256': post,
            'unchanged': post == loaded_sha256}


def main(loaded_sha256):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--execute-reads', action='store_true')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if not args.execute_reads:
        parser.error('cloud reads held: explicit --execute-reads required after review')
    os.umask(0o077)
    # Exclusive creation before any credential read or request; never overwrite a receipt.
    with args.output.open('x') as output:
        report = {'state': 'HOLD', 'provider_mutations': False}
        def expired(*_):
            raise Deadline()
        signal.signal(signal.SIGALRM, expired)
        signal.alarm(180)
        try:
            before = source()
            report = collect(Transport(credential()))
            report['source'] = before
            report['source_unchanged'] = source() == before
        except (Exception, Deadline):
            report['fatal'] = 'HOLD_LOCAL_TRANSPORT_OR_DEADLINE_FAILURE'
        finally:
            signal.alarm(0)
            report['observed_at'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
            report['instrument'] = instrument_identity(loaded_sha256)
            if not report['instrument']['unchanged']:
                report['fatal'] = 'HOLD_INSTRUMENT_DRIFT'
            json.dump(report, output, indent=2)
            output.write('\n')
    print('HOLD: sanitized receipt written; no provisioning clearance')
    return 2


def frozen_entry(path):
    # The collected receipt binds exactly these compiled bytes, not a later path read.
    payload = Path(path).read_bytes()
    digest = hashlib.sha256(payload).hexdigest()
    namespace = {'__name__': 'readback_frozen', '__file__': str(path)}
    exec(compile(payload, str(path), 'exec'), namespace)
    return namespace['main'](digest)


if __name__ == '__main__':
    raise SystemExit(frozen_entry(Path(__file__).resolve()))
