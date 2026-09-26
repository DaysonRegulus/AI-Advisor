# backend/tests/test_endpoints.py

import pytest
from unittest.mock import MagicMock
from fastapi.testclient import TestClient
from main import app
from dependencies import get_current_user, get_supabase_client


@pytest.fixture
def client_with_mocks():
    """Sets up FastAPI TestClient with mocked authenticated user and Supabase client."""
    mock_user = MagicMock()
    mock_user.user.id = "user-123-uuid"
    
    mock_supabase = MagicMock()
    
    app.dependency_overrides[get_current_user] = lambda: mock_user
    app.dependency_overrides[get_supabase_client] = lambda: mock_supabase
    
    with TestClient(app) as client:
        yield client, mock_supabase
        
    app.dependency_overrides.clear()


def test_root_endpoint(client_with_mocks):
    client, _ = client_with_mocks
    response = client.get("/")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_award_xp_endpoint(client_with_mocks):
    client, mock_supabase = client_with_mocks
    
    # Mock user profile lookup
    mock_table = MagicMock()
    mock_supabase.table.return_value = mock_table
    mock_select = MagicMock()
    mock_table.select.return_value = mock_select
    mock_eq = MagicMock()
    mock_select.eq.return_value = mock_eq
    mock_single = MagicMock()
    mock_eq.single.return_value = mock_single
    mock_single.execute.return_value = MagicMock(data={
        "id": "user-123-uuid",
        "username": "tester",
        "level": 1,
        "xp_points": 10,
        "xp_to_next_level": 100
    })
    
    mock_update = MagicMock()
    mock_table.update.return_value = mock_update
    mock_update_eq = MagicMock()
    mock_update.eq.return_value = mock_update_eq
    mock_update_eq.execute.return_value = MagicMock(data=[{"id": "user-123-uuid"}])
    
    response = client.post(
        "/api/user/award-xp",
        json={"amount": 25, "event_name": "test_bonus"}
    )
    
    assert response.status_code == 200
    data = response.json()
    assert data["user_id"] == "user-123-uuid"
    assert data["level"] == 1
    assert data["xp_points"] == 35
    assert data["leveled_up"] is False


def test_tracker_log_water_awards_xp_cleanly(client_with_mocks):
    """
    Verifies that logging water successfully inserts and triggers award_xp
    without throwing any positional argument errors.
    """
    client, mock_supabase = client_with_mocks
    
    mock_table = MagicMock()
    mock_supabase.table.return_value = mock_table
    
    # Mock insert for water_logs and food_logs
    mock_insert = MagicMock()
    mock_table.insert.return_value = mock_insert
    mock_insert.execute.return_value = MagicMock(data=[{
        "id": "water-log-1",
        "user_id": "user-123-uuid",
        "amount_ml": 250,
        "created_at": "2026-09-26T12:00:00Z"
    }])
    
    # Mock profile lookup for award_xp
    mock_select = MagicMock()
    mock_table.select.return_value = mock_select
    mock_eq = MagicMock()
    mock_select.eq.return_value = mock_eq
    mock_single = MagicMock()
    mock_eq.single.return_value = mock_single
    mock_single.execute.return_value = MagicMock(data={
        "id": "user-123-uuid",
        "username": "tester",
        "level": 1,
        "xp_points": 0,
        "xp_to_next_level": 100
    })
    
    # Mock update for profile
    mock_update = MagicMock()
    mock_table.update.return_value = mock_update
    mock_update_eq = MagicMock()
    mock_update.eq.return_value = mock_update_eq
    mock_update_eq.execute.return_value = MagicMock(data=[{"id": "user-123-uuid"}])
    
    response = client.post(
        "/api/trackers/log-water",
        json={"amount_ml": 250}
    )
    
    assert response.status_code == 201
    assert response.json()["amount_ml"] == 250
