import sys
import unittest
from collections import deque
from decimal import Decimal
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from fastapi import HTTPException

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.core import config as config_module
from app.features.cashboxes.models import CashboxType
from app.features.ledger import service as ledger_service
from app.features.transfers import service as transfers_service
from app.features.transfers.models import TransferState, TransferType
from app.features.users.models import UserRole


class _FakeQuery:
    def __init__(self, result):
        self._result = result

    def filter(self, *args, **kwargs):
        return self

    def first(self):
        return self._result


class _FakeDB:
    def __init__(self, results):
        self._results = deque(results)

    def query(self, model):
        if not self._results:
            raise AssertionError(f"Unexpected query for {model}")
        return _FakeQuery(self._results.popleft())


class TransferPermissionTests(unittest.TestCase):
    def test_agent_cannot_make_direct_network_transfer(self):
        source = SimpleNamespace(type=CashboxType.accredited, manager_user_id="owner-1", id="cashbox-1")
        destination = SimpleNamespace(type=CashboxType.accredited, manager_user_id="owner-2", id="cashbox-2")
        performer = SimpleNamespace(
            role=UserRole.agent,
            id="agent-1",
            managed_cashboxes=[SimpleNamespace(id="agent-box", is_active=True, type=CashboxType.agent)],
        )

        with self.assertRaises(HTTPException) as ctx:
            transfers_service._validate_transfer_scope(source, destination, performer, TransferType.network_transfer)

        self.assertEqual(ctx.exception.status_code, 403)
        self.assertIn("direct transfer route", ctx.exception.detail)

    def test_accredited_must_transfer_from_owned_cashbox(self):
        source = SimpleNamespace(type=CashboxType.accredited, manager_user_id="other-user", id="source-box")
        destination = SimpleNamespace(type=CashboxType.accredited, manager_user_id="owner-2", id="destination-box")
        performer = SimpleNamespace(
            role=UserRole.accredited,
            id="owner-1",
            managed_cashboxes=[SimpleNamespace(id="owned-box", is_active=True, type=CashboxType.accredited)],
        )

        with self.assertRaises(HTTPException) as ctx:
            transfers_service._validate_transfer_scope(source, destination, performer, TransferType.network_transfer)

        self.assertEqual(ctx.exception.status_code, 403)
        self.assertIn("own accredited cashboxes", ctx.exception.detail)

    def test_accredited_topup_request_targets_owned_cashbox(self):
        source = SimpleNamespace(type=CashboxType.agent, manager_user_id="agent-1", id="agent-box")
        destination = SimpleNamespace(type=CashboxType.accredited, manager_user_id="owner-1", id="owned-box")
        performer = SimpleNamespace(
            role=UserRole.accredited,
            id="owner-1",
            managed_cashboxes=[SimpleNamespace(id="owned-box", is_active=True, type=CashboxType.accredited)],
        )

        transfers_service._validate_transfer_scope(source, destination, performer, TransferType.topup)

    def test_admin_can_move_balance_from_treasury_to_agent(self):
        source = SimpleNamespace(type=CashboxType.treasury, manager_user_id=None, id="treasury")
        destination = SimpleNamespace(type=CashboxType.agent, manager_user_id="agent-1", id="agent-box")
        performer = SimpleNamespace(role=UserRole.admin, id="admin-1", managed_cashboxes=[])

        transfers_service._validate_transfer_scope(source, destination, performer, TransferType.agent_funding)

    def test_accredited_support_request_requires_manual_review(self):
        performer = SimpleNamespace(role=UserRole.accredited)
        self.assertTrue(
            transfers_service._should_require_manual_review(
                performer,
                TransferType.topup,
                risk_requires_review=False,
            )
        )

    def test_posting_deducts_commission_from_sender_balance(self):
        transfer = SimpleNamespace(
            amount="700.00",
            commission_amount="14.00",
            from_cashbox_id="src",
            to_cashbox_id="dst",
            state=TransferState.initiated,
            review_required=True,
        )
        source = SimpleNamespace(id="src", type=CashboxType.accredited, balance="1500.00", is_active=True)
        destination = SimpleNamespace(id="dst", type=CashboxType.accredited, balance="50.00", is_active=True)
        treasury = SimpleNamespace(id="treasury", type=CashboxType.treasury, balance="100.00", is_active=True)

        with patch.object(transfers_service, "_get_locked_cashbox", side_effect=[source, destination]), patch.object(
            transfers_service, "_get_locked_treasury", return_value=treasury
        ):
            transfers_service._apply_transfer_posting(None, transfer)

        self.assertEqual(source.balance, transfers_service._q_money("786.00"))
        self.assertEqual(destination.balance, transfers_service._q_money("750.00"))
        self.assertEqual(treasury.balance, transfers_service._q_money("114.00"))
        self.assertEqual(transfer.state, TransferState.completed)
        self.assertFalse(transfer.review_required)

    def test_posting_checks_sender_balance_including_commission(self):
        transfer = SimpleNamespace(
            amount="700.00",
            commission_amount="14.00",
            from_cashbox_id="src",
            to_cashbox_id="dst",
            state=TransferState.initiated,
            review_required=True,
        )
        source = SimpleNamespace(id="src", type=CashboxType.accredited, balance="700.00", is_active=True)
        destination = SimpleNamespace(id="dst", type=CashboxType.accredited, balance="50.00", is_active=True)
        treasury = SimpleNamespace(id="treasury", type=CashboxType.treasury, balance="100.00", is_active=True)

        with patch.object(transfers_service, "_get_locked_cashbox", side_effect=[source, destination]), patch.object(
            transfers_service, "_get_locked_treasury", return_value=treasury
        ):
            with self.assertRaises(HTTPException) as ctx:
                transfers_service._apply_transfer_posting(None, transfer)

        self.assertEqual(ctx.exception.status_code, 400)
        self.assertIn("Insufficient source cashbox balance", str(ctx.exception.detail))

    def test_agent_topup_splits_gross_amount_into_net_and_fees(self):
        credited, commission, profit = (
            transfers_service._split_requested_amount_with_fees(
                Decimal("510.00"),
                Decimal("1.00"),
                Decimal("1.00"),
            )
        )

        self.assertEqual(credited, Decimal("500.00"))
        self.assertEqual(commission, Decimal("5.00"))
        self.assertEqual(profit, Decimal("5.00"))

    def test_accredited_network_transfer_splits_gross_amount(self):
        credited, commission, profit = (
            transfers_service._split_requested_amount_with_fees(
                Decimal("510.00"),
                Decimal("1.00"),
                Decimal("1.00"),
            )
        )

        self.assertEqual(credited, Decimal("500.00"))
        self.assertEqual(commission, Decimal("5.00"))
        self.assertEqual(profit, Decimal("5.00"))

    def test_treasury_funding_splits_gross_amount_with_treasury_fee_only(self):
        credited, commission, profit = (
            transfers_service._split_requested_amount_with_fees(
                Decimal("505.00"),
                Decimal("1.00"),
                Decimal("0.00"),
            )
        )

        self.assertEqual(credited, Decimal("500.00"))
        self.assertEqual(commission, Decimal("5.00"))
        self.assertEqual(profit, Decimal("0.00"))

    def test_commission_role_for_treasury_to_accredited_is_accredited(self):
        source = SimpleNamespace(type=CashboxType.treasury)
        destination = SimpleNamespace(type=CashboxType.accredited)
        role = transfers_service._determine_commission_role(
            source,
            destination,
            TransferType.topup,
        )
        self.assertEqual(role, UserRole.accredited)

    def test_commission_role_for_treasury_to_agent_is_agent(self):
        source = SimpleNamespace(type=CashboxType.treasury)
        destination = SimpleNamespace(type=CashboxType.agent)
        role = transfers_service._determine_commission_role(
            source,
            destination,
            TransferType.agent_funding,
        )
        self.assertEqual(role, UserRole.agent)

    def test_agent_funding_pending_review_is_for_admin_not_requesting_agent(self):
        transfer = SimpleNamespace(
            operation_type=TransferType.agent_funding,
            performed_by_id="agent-1",
        )
        source = SimpleNamespace(
            id="treasury-box",
            type=CashboxType.treasury,
            manager_user_id=None,
        )
        destination = SimpleNamespace(
            id="agent-box",
            type=CashboxType.agent,
            manager_user_id="agent-1",
        )
        admin = SimpleNamespace(role=UserRole.admin, managed_cashboxes=[])
        agent = SimpleNamespace(
            role=UserRole.agent,
            managed_cashboxes=[
                SimpleNamespace(
                    id="agent-box",
                    is_active=True,
                    type=CashboxType.agent,
                )
            ],
        )

        self.assertTrue(
            transfers_service._can_user_review_pending_transfer(
                admin, transfer, source, destination
            )
        )
        self.assertFalse(
            transfers_service._can_user_review_pending_transfer(
                agent, transfer, source, destination
            )
        )

    def test_topup_request_from_accredited_is_reviewed_by_source_agent(self):
        transfer = SimpleNamespace(
            operation_type=TransferType.topup,
            performed_by_id="accredited-1",
        )
        source = SimpleNamespace(
            id="agent-box",
            type=CashboxType.agent,
            manager_user_id="agent-1",
        )
        destination = SimpleNamespace(
            id="accredited-box",
            type=CashboxType.accredited,
            manager_user_id="accredited-1",
        )
        agent = SimpleNamespace(
            role=UserRole.agent,
            managed_cashboxes=[
                SimpleNamespace(
                    id="agent-box",
                    is_active=True,
                    type=CashboxType.agent,
                )
            ],
        )
        accredited = SimpleNamespace(
            role=UserRole.accredited,
            managed_cashboxes=[
                SimpleNamespace(
                    id="accredited-box",
                    is_active=True,
                    type=CashboxType.accredited,
                )
            ],
        )

        self.assertTrue(
            transfers_service._can_user_review_pending_transfer(
                agent, transfer, source, destination
            )
        )
        self.assertFalse(
            transfers_service._can_user_review_pending_transfer(
                accredited, transfer, source, destination
            )
        )

    def test_admin_initiated_agent_funding_is_reviewed_by_agent(self):
        transfer = SimpleNamespace(
            operation_type=TransferType.agent_funding,
            performed_by_id="admin-1",
        )
        source = SimpleNamespace(
            id="treasury-box",
            type=CashboxType.treasury,
            manager_user_id=None,
        )
        destination = SimpleNamespace(
            id="agent-box",
            type=CashboxType.agent,
            manager_user_id="agent-1",
        )
        admin = SimpleNamespace(role=UserRole.admin, managed_cashboxes=[])
        agent = SimpleNamespace(
            role=UserRole.agent,
            managed_cashboxes=[
                SimpleNamespace(
                    id="agent-box",
                    is_active=True,
                    type=CashboxType.agent,
                )
            ],
        )

        self.assertFalse(
            transfers_service._can_user_review_pending_transfer(
                admin, transfer, source, destination
            )
        )
        self.assertTrue(
            transfers_service._can_user_review_pending_transfer(
                agent, transfer, source, destination
            )
        )

    def test_admin_collection_from_agent_is_reviewed_by_agent(self):
        transfer = SimpleNamespace(
            operation_type=TransferType.agent_collection,
            performed_by_id="admin-1",
        )
        source = SimpleNamespace(
            id="agent-box",
            type=CashboxType.agent,
            manager_user_id="agent-1",
        )
        destination = SimpleNamespace(
            id="treasury-box",
            type=CashboxType.treasury,
            manager_user_id=None,
        )
        admin = SimpleNamespace(role=UserRole.admin, managed_cashboxes=[])
        agent = SimpleNamespace(
            role=UserRole.agent,
            managed_cashboxes=[
                SimpleNamespace(
                    id="agent-box",
                    is_active=True,
                    type=CashboxType.agent,
                )
            ],
        )

        self.assertFalse(
            transfers_service._can_user_review_pending_transfer(
                admin, transfer, source, destination
            )
        )
        self.assertTrue(
            transfers_service._can_user_review_pending_transfer(
                agent, transfer, source, destination
            )
        )

    def test_admin_collection_from_accredited_is_reviewed_by_accredited(self):
        transfer = SimpleNamespace(
            operation_type=TransferType.collection,
            performed_by_id="admin-1",
        )
        source = SimpleNamespace(
            id="accredited-box",
            type=CashboxType.accredited,
            manager_user_id="accredited-1",
        )
        destination = SimpleNamespace(
            id="treasury-box",
            type=CashboxType.treasury,
            manager_user_id=None,
        )
        admin = SimpleNamespace(role=UserRole.admin, managed_cashboxes=[])
        accredited = SimpleNamespace(
            role=UserRole.accredited,
            managed_cashboxes=[
                SimpleNamespace(
                    id="accredited-box",
                    is_active=True,
                    type=CashboxType.accredited,
                )
            ],
        )

        self.assertFalse(
            transfers_service._can_user_review_pending_transfer(
                admin, transfer, source, destination
            )
        )
        self.assertTrue(
            transfers_service._can_user_review_pending_transfer(
                accredited, transfer, source, destination
            )
        )


class LedgerPostingTests(unittest.TestCase):
    def test_commission_is_booked_to_revenue_account(self):
        transfer = SimpleNamespace(
            id="tx-1",
            from_cashbox_id="src",
            to_cashbox_id="dst",
            treasury_cashbox_id="treasury",
            amount="100.00",
            commission_amount="2.00",
            source_currency="SYP",
            destination_currency="SYP",
        )
        source_cashbox = SimpleNamespace(id="src", name="Source")
        destination_cashbox = SimpleNamespace(id="dst", name="Destination")
        treasury_cashbox = SimpleNamespace(id="treasury", name="Treasury")
        source_account = SimpleNamespace(id="src-account")
        destination_account = SimpleNamespace(id="dst-account")
        treasury_account = SimpleNamespace(id="treasury-account")
        captured = {}

        fake_db = _FakeDB([None, source_cashbox, destination_cashbox, treasury_cashbox])

        def _capture_entry(db, **kwargs):
            captured.update(kwargs)
            return "ok"

        with patch.object(ledger_service, "ensure_default_ledger_accounts"), patch.object(
            ledger_service,
            "ensure_cashbox_ledger_account",
            side_effect=[source_account, destination_account, treasury_account],
        ), patch.object(ledger_service, "create_ledger_entry", side_effect=_capture_entry):
            result = ledger_service.post_transfer_ledger_entry(fake_db, transfer, created_by_id="admin-1")

        self.assertEqual(result, "ok")
        lines = captured["lines"]
        self.assertEqual(len(lines), 3)
        self.assertEqual(lines[0].account_id, "dst-account")
        self.assertEqual(lines[1].account_id, "treasury-account")
        self.assertEqual(lines[2].account_id, "src-account")
        self.assertEqual(lines[2].credit, Decimal("102.00"))

    def test_zero_commission_skips_revenue_line(self):
        transfer = SimpleNamespace(
            id="tx-2",
            from_cashbox_id="src",
            to_cashbox_id="dst",
            treasury_cashbox_id="treasury",
            amount="100.00",
            commission_amount="0.00",
            source_currency="SYP",
            destination_currency="SYP",
        )
        source_cashbox = SimpleNamespace(id="src", name="Source")
        destination_cashbox = SimpleNamespace(id="dst", name="Destination")
        treasury_cashbox = SimpleNamespace(id="treasury", name="Treasury")
        source_account = SimpleNamespace(id="src-account")
        destination_account = SimpleNamespace(id="dst-account")
        treasury_account = SimpleNamespace(id="treasury-account")
        captured = {}

        fake_db = _FakeDB([None, source_cashbox, destination_cashbox, treasury_cashbox])

        def _capture_entry(db, **kwargs):
            captured.update(kwargs)
            return "ok"

        with patch.object(ledger_service, "ensure_default_ledger_accounts"), patch.object(
            ledger_service,
            "ensure_cashbox_ledger_account",
            side_effect=[source_account, destination_account, treasury_account],
        ), patch.object(ledger_service, "create_ledger_entry", side_effect=_capture_entry):
            result = ledger_service.post_transfer_ledger_entry(fake_db, transfer, created_by_id="admin-1")

        self.assertEqual(result, "ok")
        lines = captured["lines"]
        self.assertEqual(len(lines), 2)
        self.assertEqual(lines[0].account_id, "dst-account")
        self.assertEqual(lines[1].account_id, "src-account")


class ConfigTests(unittest.TestCase):
    def test_env_file_points_to_backend_dotenv(self):
        expected = config_module.BASE_DIR / ".env"
        self.assertEqual(config_module.Settings.Config.env_file, expected)
        self.assertEqual(expected.parent.name, "backend")


if __name__ == "__main__":
    unittest.main()
