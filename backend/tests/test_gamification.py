# backend/tests/test_gamification.py

import pytest
from unittest.mock import MagicMock
from services.gamification_service import calculate_next_level_xp, award_xp_to_user


def test_calculate_next_level_xp():
    """Verify that XP scaling follows the power curve."""
    assert calculate_next_level_xp(1) == 100
    assert calculate_next_level_xp(2) == int(100 * (2 ** 1.5))  # 282
    assert calculate_next_level_xp(3) == int(100 * (3 ** 1.5))  # 519
    assert calculate_next_level_xp(5) > calculate_next_level_xp(4)


def test_award_xp_no_level_up():
    """Test awarding XP without triggering a level-up."""
    mock_supabase = MagicMock()
    mock_table = MagicMock()
    mock_supabase.table.return_value = mock_table
    
    # Mock current profile: Level 1, 0 XP, needs 100 XP
    mock_select = MagicMock()
    mock_table.select.return_value = mock_select
    mock_eq = MagicMock()
    mock_select.eq.return_value = mock_eq
    mock_single = MagicMock()
    mock_eq.single.return_value = mock_single
    mock_single.execute.return_value = MagicMock(data={
        "id": "test-user-id",
        "username": "tester",
        "level": 1,
        "xp_points": 20,
        "xp_to_next_level": 100
    })
    
    # Mock update response
    mock_update = MagicMock()
    mock_table.update.return_value = mock_update
    mock_update_eq = MagicMock()
    mock_update.eq.return_value = mock_update_eq
    mock_update_eq.execute.return_value = MagicMock(data=[{"id": "test-user-id"}])
    
    result = award_xp_to_user(
        user_id="test-user-id",
        amount=30,
        event_name="water_log",
        supabase=mock_supabase
    )
    
    assert result["level"] == 1
    assert result["xp_points"] == 50
    assert result["leveled_up"] is False
    assert result["xp_to_next_level"] == 100


def test_award_xp_with_level_up():
    """Test awarding enough XP to trigger a level-up."""
    mock_supabase = MagicMock()
    mock_table = MagicMock()
    mock_supabase.table.return_value = mock_table
    
    mock_select = MagicMock()
    mock_table.select.return_value = mock_select
    mock_eq = MagicMock()
    mock_select.eq.return_value = mock_eq
    mock_single = MagicMock()
    mock_eq.single.return_value = mock_single
    mock_single.execute.return_value = MagicMock(data={
        "id": "test-user-id",
        "username": "tester",
        "level": 1,
        "xp_points": 80,
        "xp_to_next_level": 100
    })
    
    mock_update = MagicMock()
    mock_table.update.return_value = mock_update
    mock_update_eq = MagicMock()
    mock_update.eq.return_value = mock_update_eq
    mock_update_eq.execute.return_value = MagicMock(data=[{"id": "test-user-id"}])
    
    result = award_xp_to_user(
        user_id="test-user-id",
        amount=50,
        event_name="weekly_weight_log",
        supabase=mock_supabase
    )
    
    # 80 + 50 = 130 >= 100 -> Level 2, Remaining XP = 30
    assert result["level"] == 2
    assert result["xp_points"] == 30
    assert result["leveled_up"] is True
    assert result["xp_to_next_level"] == calculate_next_level_xp(2)


def test_award_xp_user_not_found():
    """Test error when user profile does not exist."""
    mock_supabase = MagicMock()
    mock_table = MagicMock()
    mock_supabase.table.return_value = mock_table
    
    mock_select = MagicMock()
    mock_table.select.return_value = mock_select
    mock_eq = MagicMock()
    mock_select.eq.return_value = mock_eq
    mock_single = MagicMock()
    mock_eq.single.return_value = mock_single
    mock_single.execute.return_value = MagicMock(data=None)
    
    with pytest.raises(ValueError, match="User profile not found"):
        award_xp_to_user(
            user_id="nonexistent-user",
            amount=25,
            event_name="test_event",
            supabase=mock_supabase
        )
