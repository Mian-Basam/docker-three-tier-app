const NEXT = { todo: "doing", doing: "done", done: "todo" };
const api = (path, opts = {}) =>
  fetch(`/api${path}`, { headers: { "Content-Type": "application/json" }, ...opts })
    .then(r => (r.status === 204 ? null : r.json()));

async function render() {
  const tasks = await api("/tasks");
  document.querySelectorAll("section").forEach(sec => {
    const items = tasks.filter(t => t.status === sec.dataset.status);
    sec.querySelector(".count").textContent = `(${items.length})`;
    const ul = sec.querySelector("ul");
    ul.replaceChildren(...items.map(t => {
      const li = document.createElement("li");
      const label = document.createElement("span");
      label.textContent = t.title;
      const actions = document.createElement("span");
      actions.className = "actions";
      const move = Object.assign(document.createElement("button"), { textContent: `→ ${NEXT[t.status]}` });
      move.onclick = () => api(`/tasks/${t.id}`, { method: "PATCH", body: JSON.stringify({ status: NEXT[t.status] }) }).then(render);
      const del = Object.assign(document.createElement("button"), { textContent: "delete" });
      del.onclick = () => api(`/tasks/${t.id}`, { method: "DELETE" }).then(render);
      actions.append(move, del);
      li.append(label, actions);
      return li;
    }));
  });
}

async function health() {
  const pill = document.getElementById("health");
  try {
    const h = await api("/health");
    pill.textContent = h.database ? "API + DB healthy" : "DB unreachable";
    pill.className = `pill ${h.database ? "ok" : "bad"}`;
    document.getElementById("served-by").textContent = `API version ${h.version} · served by container ${h.container}`;
  } catch {
    pill.textContent = "API unreachable"; pill.className = "pill bad";
  }
}

document.getElementById("new-task").onsubmit = async e => {
  e.preventDefault();
  const input = document.getElementById("title");
  await api("/tasks", { method: "POST", body: JSON.stringify({ title: input.value }) });
  input.value = "";
  render();
};

render(); health(); setInterval(health, 10000);
