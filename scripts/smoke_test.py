"""Exercise the deployed create, redirect, and delete paths from inside AKS."""

import json
import os
from urllib.error import HTTPError
from urllib.request import HTTPRedirectHandler, Request, build_opener, urlopen
from uuid import uuid4


class NoRedirectHandler(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


base_url = os.environ.get("SMOKE_TEST_BASE_URL", "http://url-shortener").rstrip("/")
destination = f"https://example.com/argocd-smoke-test/{uuid4()}"
request = Request(
    f"{base_url}/links",
    data=json.dumps({"destination_url": destination}).encode(),
    headers={"Content-Type": "application/json"},
    method="POST",
)

with urlopen(request, timeout=10) as response:
    if response.status != 201:
        raise RuntimeError(f"create returned HTTP {response.status}")
    code = json.load(response)["code"]

try:
    opener = build_opener(NoRedirectHandler)
    try:
        opener.open(f"{base_url}/{code}", timeout=10)
    except HTTPError as response:
        if response.code != 307 or response.headers.get("Location") != destination:
            raise RuntimeError(
                f"redirect returned HTTP {response.code} to "
                f"{response.headers.get('Location')!r}"
            ) from response
    else:
        raise RuntimeError("redirect endpoint did not return HTTP 307")
finally:
    delete_request = Request(f"{base_url}/links/{code}", method="DELETE")
    with urlopen(delete_request, timeout=10) as response:
        if response.status != 204:
            raise RuntimeError(f"cleanup returned HTTP {response.status}")

print("Smoke test passed: create, redirect, and delete")
