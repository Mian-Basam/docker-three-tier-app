from datetime import datetime, timezone

from .db import db

STATUSES = ("todo", "doing", "done")


class Task(db.Model):
    __tablename__ = "tasks"

    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(200), nullable=False)
    status = db.Column(db.String(10), nullable=False, default="todo", index=True)
    created_at = db.Column(db.DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    def to_dict(self):
        return {"id": self.id, "title": self.title, "status": self.status,
                "created_at": self.created_at.isoformat() if self.created_at else None}
