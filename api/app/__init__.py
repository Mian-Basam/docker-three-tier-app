import logging
import os
import time

from flask import Flask
from sqlalchemy import text
from sqlalchemy.exc import OperationalError

from .db import db
from .routes import bp


def _database_url():
    """Build the DB URL; password comes from a Docker secret file when available."""
    if os.getenv("DATABASE_URL"):
        return os.environ["DATABASE_URL"]
    password = os.getenv("DB_PASSWORD", "")
    pw_file = os.getenv("DB_PASSWORD_FILE")
    if pw_file and os.path.exists(pw_file):
        with open(pw_file) as fh:
            password = fh.read().strip()
    return (
        f"postgresql+psycopg2://{os.getenv('DB_USER', 'taskboard')}:{password}"
        f"@{os.getenv('DB_HOST', 'db')}:{os.getenv('DB_PORT', '5432')}/{os.getenv('DB_NAME', 'taskboard')}"
    )


def create_app(database_url=None):
    app = Flask(__name__)
    app.config["SQLALCHEMY_DATABASE_URI"] = database_url or _database_url()
    app.config["SQLALCHEMY_ENGINE_OPTIONS"] = {"pool_pre_ping": True}
    app.config["APP_VERSION"] = os.getenv("APP_VERSION", "dev")
    logging.basicConfig(level=os.getenv("LOG_LEVEL", "INFO"),
                        format="%(asctime)s %(levelname)s %(name)s: %(message)s")

    db.init_app(app)
    app.register_blueprint(bp)

    with app.app_context():
        _wait_for_db_and_create_tables(app)
    return app


def _wait_for_db_and_create_tables(app, attempts=10, delay=2):
    """The DB container may still be starting; retry instead of crashing."""
    for i in range(1, attempts + 1):
        try:
            db.session.execute(text("SELECT 1"))
            db.create_all()
            return
        except OperationalError:
            app.logger.warning("database not ready (attempt %d/%d)", i, attempts)
            db.session.rollback()
            time.sleep(delay)
    raise RuntimeError("database unavailable after retries")
