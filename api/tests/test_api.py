def test_health_reports_db(client):
    r = client.get("/api/health")
    assert r.status_code == 200
    assert r.json["database"] is True


def test_create_list_update_delete(client):
    r = client.post("/api/tasks", json={"title": "Write runbook"})
    assert r.status_code == 201
    tid = r.json["id"]

    assert [t["title"] for t in client.get("/api/tasks").json] == ["Write runbook"]

    r = client.patch(f"/api/tasks/{tid}", json={"status": "done"})
    assert r.json["status"] == "done"

    assert client.get("/api/tasks?status=done").json[0]["id"] == tid
    assert client.get("/api/tasks?status=todo").json == []

    assert client.delete(f"/api/tasks/{tid}").status_code == 204
    assert client.get("/api/tasks").json == []


def test_stats(client):
    for title in ("a", "b", "c"):
        client.post("/api/tasks", json={"title": title})
    client.patch("/api/tasks/1", json={"status": "doing"})
    assert client.get("/api/stats").json == {"todo": 2, "doing": 1, "done": 0}


def test_validation(client):
    assert client.post("/api/tasks", json={}).status_code == 400
    assert client.post("/api/tasks", json={"title": "x" * 201}).status_code == 400
    tid = client.post("/api/tasks", json={"title": "ok"}).json["id"]
    assert client.patch(f"/api/tasks/{tid}", json={"status": "bogus"}).status_code == 400
    assert client.patch(f"/api/tasks/{tid}", json={"title": "  "}).status_code == 400
    assert client.get("/api/tasks?status=bogus").status_code == 400


def test_not_found(client):
    assert client.patch("/api/tasks/999", json={"status": "done"}).status_code == 404
    assert client.delete("/api/tasks/999").status_code == 404
