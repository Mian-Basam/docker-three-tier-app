import pytest

from app import create_app
from app.db import db


@pytest.fixture
def client():
    # SQLite in memory keeps unit tests fast; Postgres is covered by the e2e test.
    app = create_app("sqlite:///:memory:")
    with app.app_context():
        yield app.test_client()
        db.drop_all()
