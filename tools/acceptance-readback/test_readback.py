import json
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
        self.assertEqual(r.assess('dns', [{'name': '*.commonplace.st'}])['verdict'], 'COLLISION')
        self.assertEqual(r.assess('routes', [{'pattern': '*commonplace.st/private/*'}])['verdict'], 'COLLISION')

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
        with patch.object(r.urllib.request, 'build_opener', return_value=op):
            transport = r.Transport('CANARY')
            transport.get('accounts')
        self.assertEqual(op.request.method, 'GET')
        self.assertTrue(op.request.full_url.startswith('https://api.cloudflare.com/client/v4/accounts?'))
        self.assertIsNone(op.request.data)
        with self.assertRaises(KeyError): transport.get('https://untrusted.example')


if __name__ == '__main__':
    # Defense in depth: all controls fail if any real socket is opened.
    with patch('socket.socket', side_effect=AssertionError('network forbidden in controls')):
        unittest.main()
