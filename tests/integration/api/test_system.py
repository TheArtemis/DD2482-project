import pytest

pytestmark = [pytest.mark.anyio, pytest.mark.integration]


async def test_home_page(client):
    response = await client.get("/")
    assert response.status_code == 200
    assert "Make every link" in response.text


async def test_health_endpoints(client):
    assert (await client.get("/health/live")).json() == {"status": "ok"}
    assert (await client.get("/health/ready")).json() == {"status": "ok"}


async def test_version(client):
    response = await client.get("/version")
    assert response.status_code == 200
    assert "version" in response.json()


async def test_request_id_is_returned(client):
    response = await client.get(
        "/health/live", headers={"x-request-id": "test-request"}
    )
    assert response.headers["x-request-id"] == "test-request"
