import pytest

pytestmark = [pytest.mark.anyio, pytest.mark.integration]


async def create_link(client, destination="https://example.com/some/path"):
    response = await client.post("/links", json={"destination_url": destination})
    assert response.status_code == 201
    return response.json()


async def test_create_link(client):
    body = await create_link(client)

    assert len(body["code"]) == 7
    assert body["destination_url"] == "https://example.com/some/path"
    assert body["short_url"].endswith("/" + body["code"])
    assert body["created_at"]


async def test_create_rejects_non_http_url(client):
    response = await client.post(
        "/links", json={"destination_url": "javascript:alert(1)"}
    )

    assert response.status_code == 422


async def test_redirect_and_stats(client):
    link = await create_link(client, "https://example.org/destination?item=1")

    response = await client.get(f"/{link['code']}", follow_redirects=False)
    assert response.status_code == 307
    assert response.headers["location"] == "https://example.org/destination?item=1"

    stats = await client.get(f"/links/{link['code']}/stats")
    assert stats.status_code == 200
    assert stats.json()["redirect_count"] == 1
    assert stats.json()["is_active"] is True


async def test_delete_disables_redirect_but_preserves_stats(client):
    link = await create_link(client)

    response = await client.delete(f"/links/{link['code']}")
    assert response.status_code == 204
    redirect = await client.get(f"/{link['code']}", follow_redirects=False)
    assert redirect.status_code == 404

    stats = await client.get(f"/links/{link['code']}/stats")
    assert stats.status_code == 200
    assert stats.json()["is_active"] is False


async def test_unknown_link_returns_not_found(client):
    assert (await client.get("/links/not-found/stats")).status_code == 404
    assert (await client.delete("/links/not-found")).status_code == 404
    response = await client.get("/not-found", follow_redirects=False)
    assert response.status_code == 404
