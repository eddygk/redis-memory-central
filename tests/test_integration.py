# /tests/test_integration.py
import os
import time
import pytest
import asyncio
import httpx
import redis

# --- Test Configuration ---
# Use environment variables or defaults
SERVER_IP = os.getenv("REDIS_MEMORY_IP", "10.10.20.85")
API_URL = f"http://{SERVER_IP}:8000"
REDIS_URL = f"redis://{SERVER_IP}:16379"

@pytest.fixture(scope="module")
def redis_client():
    """Provides a Redis client fixture."""
    try:
        r = redis.from_url(REDIS_URL, decode_responses=True)
        r.ping()
        return r
    except redis.exceptions.ConnectionError as e:
        pytest.fail(f"Could not connect to Redis at {REDIS_URL}: {e}")

@pytest.fixture(scope="module")
def api_client():
    """Provides an httpx async client."""
    with httpx.AsyncClient(base_url=API_URL, timeout=10) as client:
        yield client

@pytest.mark.asyncio
async def test_api_health(api_client: httpx.AsyncClient):
    """Tests if the API health endpoint is responsive and healthy."""
    response = await api_client.get("/v1/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert data["redis_connected"] is True

def test_redis_connection(redis_client: redis.Redis):
    """Tests the direct connection to Redis."""
    assert redis_client.ping() is True
    info = redis_client.info()
    assert "redis_version" in info

@pytest.mark.asyncio
async def test_memory_creation_and_search(api_client: httpx.AsyncClient):
    """Tests the full lifecycle: create, index, and search for a memory."""
    memory_id = f"pytest_memory_{int(time.time())}"
    memory_text = "This is an integration test memory."

    # 1. Create a long-term memory
    create_payload = {
        "memories": [{
            "id": memory_id,
            "text": memory_text,
            "memory_type": "semantic",
            "namespace": "pytest",
        }]
    }
    response = await api_client.post("/v1/long-term-memory", json=create_payload)
    assert response.status_code == 200, f"Failed to create memory: {response.text}"

    # Give a moment for the background worker to index the memory
    await asyncio.sleep(2) 

    # 2. Search for the memory
    search_payload = {
        "text": "integration test",
        "namespace": {"eq": "pytest"}
    }
    response = await api_client.post("/v1/long-term-memory/search", json=search_payload)
    assert response.status_code == 200
    results = response.json().get("results", [])
    assert len(results) > 0, "Search returned no results."

    # Verify the created memory is in the search results
    found_ids = [res["id"] for res in results]
    assert memory_id in found_ids, "Created memory was not found in search results."

@pytest.mark.asyncio
async def test_working_memory_lifecycle(api_client: httpx.AsyncClient):
    """Tests creating, retrieving, and checking a working memory session."""
    session_id = f"pytest_session_{int(time.time())}"

    # 1. Create/update a session
    session_payload = {
        "messages": [{"role": "user", "content": "Hello from pytest"}],
        "context": "Integration testing working memory"
    }
    response = await api_client.put(f"/v1/working-memory/{session_id}", json=session_payload)
    assert response.status_code == 200

    # 2. Retrieve the session
    response = await api_client.get(f"/v1/working-memory/{session_id}")
    assert response.status_code == 200
    data = response.json()
    assert data["context"] == "Integration testing working memory"
    assert len(data["messages"]) == 1
    assert data["messages"][0]["content"] == "Hello from pytest"