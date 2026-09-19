import json
import hashlib
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import readback as r


class Fake:
    def __init__(self, pages):
        self.pages = pages
        self.calls = []

    def get(self, key, page):
        self.calls.append((key, page))
        return self.pages[page - 1]


def page(rows, total=None, number=1):
    return 200, {'success': True, 'result': rows, 'result_info': {
        'total_count': len(rows) if total is None else total, 'page': number}}


class Controls(unittest.TestCase):
    def test_controlled_absence_and_exact_collision(self):
        rows = [{'id': 'known', 'name': 'beta-next.commonplace.st'}]
        self.assertEqual(r.assess('dns', rows)['verdict'], 'CONTROLLED_NO_MATCH')
        rows.append({'id': 'new', 'name': r.HOST})
        self.assertEqual(r.assess('dns', rows)['verdict'], 'COLLISION')

    def test_wildcard_and_path_overlap(self):
        for key, rows, control in [
            ('dns', [{'name': '*.commonplace.st'}], {'name': 'beta-next.commonplace.st'}),
            ('routes', [{'pattern': '*commonplace.st/private/*'}], {'pattern': 'beta-next.commonplace.st/*'})]:
            self.assertEqual(r.assess(key, rows)['verdict'], 'HOLD_NO_KNOWN_CONTROL')
            self.assertEqual(r.assess(key, rows)['collision_count'], 1)
            self.assertEqual(r.assess(key, rows + [control])['verdict'], 'COLLISION')

    def test_empty_is_not_green(self):
        self.assertEqual(r.assess('service_tokens', [])['verdict'], 'HOLD_NO_KNOWN_CONTROL')

    def test_pagination_collects_second_page(self):
        f = Fake([page([{'id': 'a'}], 2), page([{'id': 'b'}], 2, 2)])
        self.assertEqual(len(r.fetch(f, 'dns')[0]), 2)
        self.assertEqual(len(f.calls), 2)

    def test_pagination_refusals(self):
        samples = [Fake([(200, {'success': True, 'result': []})]),
                   Fake([page([{'id': 'a'}], 2), page([], 2, 2)]),
                   Fake([page([{'id': 'a'}], 2), page([{'id': 'a'}], 2, 2)]),
                   Fake([page([{'id': 'a'}], 2), page([{'id': 'b'}], 3, 2)])]
        for fake in samples:
            with self.assertRaises(r.Refusal):
                r.fetch(fake, 'dns')

    def test_failed_positive_control_stops(self):
        fake = Fake([page([])])
        receipt = r.collect(fake)
        self.assertEqual(fake.calls, [('accounts', 1)])
        self.assertEqual(receipt['state'], 'HOLD')

    def test_errors_never_echo_secret(self):
        secret = 'CANARY_DO_NOT_EMIT'
        fake = Fake([(403, {'success': False, 'errors': [secret]})])
        self.assertNotIn(secret, json.dumps(r.collect(fake)))

    def test_secret_typed_binding_is_never_read(self):
        receipt = r.human({'bindings': [{'name': 'COMMONPLACE_LOG_REALM_URL',
                                        'type': 'secret_text', 'text': 'CANARY_DO_NOT_EMIT'}]})
        self.assertEqual(receipt['realm_id'], 'REQUIRED_PENDING_READBACK')
        self.assertNotIn('CANARY_DO_NOT_EMIT', json.dumps(receipt))

    def test_plain_realm_projection_and_collision(self):
        receipt = r.human({'bindings': [{'name': 'COMMONPLACE_LOG_REALM_URL',
            'type': 'plain_text', 'text': 'https://storage.example/realms/' + r.REALM},
            {'name': 'COMMONPLACE_LOG_REALM_CAPABILITY', 'text': 'CANARY_DO_NOT_EMIT'}]})
        self.assertTrue(receipt['realm_collision'])
        self.assertEqual(receipt['organization_id'], 'REQUIRED_PENDING_READBACK')
        self.assertNotIn('CANARY_DO_NOT_EMIT', json.dumps(receipt))

    def test_realm_query_and_ambiguity_refused(self):
        b = {'name': 'COMMONPLACE_LOG_REALM_URL', 'type': 'plain_text',
             'text': 'https://storage.example/realms/' + r.REALM + '?token=secret'}
        with self.assertRaises(r.Refusal):
            r.human({'bindings': [b]})
        self.assertEqual(r.human({'bindings': [b, b]})['realm_id'], 'REQUIRED_PENDING_READBACK')

    def test_redirect_is_refused(self):
        with self.assertRaises(r.Refusal):
            r.NoRedirect().redirect_request(None)

    def test_transport_only_get_fixed_api_no_proxy(self):
        class Response:
            status = 200
            def __enter__(self): return self
            def __exit__(self, *args): pass
            def read(self, bound): return b'{"success":true,"result":[]}'
        class Opener:
            def open(self, request, timeout):
                self.request = request
                return Response()
        op = Opener()
        with patch.object(r.urllib.request, 'build_opener', return_value=op) as build:
            transport = r.Transport('CANARY')
            transport.get('accounts')
        handlers = build.call_args.args
        self.assertEqual(len(handlers), 2)
        self.assertIsInstance(handlers[0], r.urllib.request.ProxyHandler)
        self.assertEqual(handlers[0].proxies, {})
        self.assertIsInstance(handlers[1], r.NoRedirect)
        with self.assertRaises(r.Refusal): handlers[1].redirect_request(None)
        self.assertEqual(op.request.method, 'GET')
        self.assertTrue(op.request.full_url.startswith('https://api.cloudflare.com/client/v4/accounts?'))
        self.assertIn('per_page=50', op.request.full_url)
        transport.get('zones')
        self.assertIn('per_page=50', op.request.full_url)
        for key in ('routes', 'workers'):
            transport.get(key)
            self.assertNotIn('?', op.request.full_url)
        self.assertIsNone(op.request.data)
        with self.assertRaises(KeyError): transport.get('https://untrusted.example')

    def test_unpaginated_lists_and_size_bounds(self):
        for key in ('routes', 'workers'):
            fake = Fake([(200, {'success': True, 'result': [{'id': 'a'}]})])
            self.assertEqual(r.fetch(fake, key), ([{'id': 'a'}], 1))
            too_many = [{'id': str(i)} for i in range(1001)]
            with self.assertRaises(r.Refusal):
                r.fetch(Fake([(200, {'success': True, 'result': too_many})]), key)
        for key, size in [('accounts', 51), ('zones', 51), ('dns', 101)]:
            with self.assertRaises(r.Refusal):
                r.fetch(Fake([page([{'id': str(i)} for i in range(size)])]), key)

    def test_credential_regular_descriptor_and_path_swap(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'credential'
            path.write_text('CLOUDFLARE_API_TOKEN=original\n'); path.chmod(0o600)
            original_fstat = os.fstat
            calls = []
            def swapping_fstat(fd):
                if not calls:
                    path.rename(path.with_suffix('.old'))
                    path.write_text('CLOUDFLARE_API_TOKEN=replacement\n'); path.chmod(0o600)
                calls.append(fd)
                return original_fstat(fd)
            with patch.object(r, 'CREDENTIAL', path), patch.object(r.os, 'fstat', side_effect=swapping_fstat):
                self.assertEqual(r.credential(), 'original')
            self.assertEqual(len(set(calls)), 1)
            path.unlink(); path.symlink_to(path.with_suffix('.old'))
            with patch.object(r, 'CREDENTIAL', path), self.assertRaises(OSError): r.credential()
            path.unlink(); os.mkfifo(path, 0o600)
            with patch.object(r, 'CREDENTIAL', path), self.assertRaises(r.Refusal): r.credential()
            path.unlink(); path.write_text('CLOUDFLARE_API_TOKEN=secret'); path.chmod(0o644)
            with patch.object(r, 'CREDENTIAL', path), self.assertRaises(r.Refusal): r.credential()

    def test_source_guard_explicit_untracked_and_updated_pin(self):
        self.assertEqual(r.COMMIT, '282a6ca9bd8d8d5b11474ecafdf59692ef0c3bcf')
        self.assertEqual(r.TREE, 'c447e8351c80f0f9ed4c0e4a49148c4831b389dd')
        for status in ('', '?? hidden-by-config'):
            with patch.object(r.subprocess, 'check_output', side_effect=[r.COMMIT, r.TREE, 'work/acceptance-access-1', status]) as call:
                if status:
                    with self.assertRaises(r.Refusal): r.source()
                else:
                    self.assertTrue(r.source()['clean'])
                self.assertIn('--untracked-files=all', call.call_args.args[0])

    def test_loaded_bytes_binding_and_post_drift(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'instrument.py'
            payload = b'def main(digest):\n    return digest\n'
            path.write_bytes(payload)
            digest = hashlib.sha256(payload).hexdigest()
            self.assertEqual(r.frozen_entry(path), digest)
            with patch.object(r, '__file__', str(path)):
                self.assertTrue(r.instrument_identity(digest)['unchanged'])
                path.write_text('changed after load')
                result = r.instrument_identity(digest)
                self.assertEqual(result['loaded_sha256'], digest)
                self.assertFalse(result['unchanged'])
                path.unlink()
                self.assertIsNone(r.instrument_identity(digest)['post_sha256'])


if __name__ == '__main__':
    # Defense in depth: all controls fail if any real socket is opened.
    with patch('socket.socket', side_effect=AssertionError('network forbidden in controls')):
        unittest.main()
