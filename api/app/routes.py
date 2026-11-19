import socket

from flask import Blueprint, current_app, jsonify, request
from sqlalchemy import text

from .db import db
from .models import STATUSES, Task

bp = Blueprint("api", __name__)


def _error(msg, code):
    return jsonify(error=msg), code


@bp.get("/api/health")
def health():
    """Liveness + DB connectivity. Used by the Docker HEALTHCHECK."""
    try:
        db.session.execute(text("SELECT 1"))
        db_ok = True
    except Exception:  # noqa: BLE001 - report any DB failure as unhealthy
        db.session.rollback()
        db_ok = False
    body = {"status": "ok" if db_ok else "degraded", "database": db_ok,
            "version": current_app.config["APP_VERSION"], "container": socket.gethostname()}
    return jsonify(body), 200 if db_ok else 503


@bp.get("/api/tasks")
def list_tasks():
    q = Task.query.order_by(Task.id)
    status = request.args.get("status")
    if status:
        if status not in STATUSES:
            return _error(f"status must be one of {STATUSES}", 400)
        q = q.filter_by(status=status)
    return jsonify([t.to_dict() for t in q.all()])


@bp.post("/api/tasks")
def create_task():
    data = request.get_json(silent=True) or {}
    title = (data.get("title") or "").strip()
    if not title or len(title) > 200:
        return _error("title is required (max 200 chars)", 400)
    task = Task(title=title)
    db.session.add(task)
    db.session.commit()
    return jsonify(task.to_dict()), 201


@bp.patch("/api/tasks/<int:task_id>")
def update_task(task_id):
    task = db.session.get(Task, task_id)
    if not task:
        return _error("task not found", 404)
    data = request.get_json(silent=True) or {}
    if "status" in data:
        if data["status"] not in STATUSES:
            return _error(f"status must be one of {STATUSES}", 400)
        task.status = data["status"]
    if "title" in data:
        title = (data["title"] or "").strip()
        if not title:
            return _error("title cannot be empty", 400)
        task.title = title
    db.session.commit()
    return jsonify(task.to_dict())


@bp.delete("/api/tasks/<int:task_id>")
def delete_task(task_id):
    task = db.session.get(Task, task_id)
    if not task:
        return _error("task not found", 404)
    db.session.delete(task)
    db.session.commit()
    return "", 204


@bp.get("/api/stats")
def stats():
    rows = db.session.execute(text("SELECT status, COUNT(*) FROM tasks GROUP BY status")).all()
    counts = {s: 0 for s in STATUSES}
    counts.update({r[0]: r[1] for r in rows})
    return jsonify(counts)
