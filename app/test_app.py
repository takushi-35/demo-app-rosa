import pytest

from app import VERSION, app


@pytest.fixture
def client():
    app.config["TESTING"] = True
    with app.test_client() as client:
        yield client


def test_index(client):
    res = client.get("/")
    assert res.status_code == 200
    assert VERSION.encode() in res.data


def test_info(client):
    res = client.get("/api/info")
    assert res.status_code == 200
    assert res.get_json()["version"] == VERSION


def test_healthz(client):
    res = client.get("/healthz")
    assert res.status_code == 200
    assert res.get_json() == {"status": "ok"}
