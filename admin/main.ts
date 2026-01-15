type SessionsResponse = {
  sessions: string[];
  selectedSession: string;
};

type OrdersResponse = {
  sessionName: string;
  orders: {
    orderId: string;
    drink: string;
    customerName: string;
    instructions: string;
    timestamp: string;
  }[];
};

type PopularResponse = {
  items: {
    drink: string;
    count: number;
  }[];
};

function setStatus(message: string, isError: boolean): void {
  const el = document.getElementById("status");
  if (!el) return;
  el.textContent = message;
  el.classList.toggle("status--error", isError);
  el.classList.toggle("status--success", !isError);
}

async function loadSessions(): Promise<void> {
  const list = document.getElementById("sessions-list");
  const currentLabel = document.getElementById("current-session");

  if (!list || !currentLabel) return;

  list.innerHTML = "";

  try {
    const res = await fetch("/api/sessions");
    if (!res.ok) {
      throw new Error(`Failed to load sessions (${res.status})`);
    }
    const data = (await res.json()) as SessionsResponse;

    currentLabel.textContent = data.selectedSession
      ? `Current: ${data.selectedSession}`
      : "Current: none";

    if (!data.sessions || data.sessions.length === 0) {
      const li = document.createElement("li");
      li.className = "empty-state";
      li.textContent = "No sessions yet.";
      list.appendChild(li);
      return;
    }

    for (const name of data.sessions) {
      const li = document.createElement("li");
      li.className = "session-item";

      const title = document.createElement("span");
      title.className = "session-item__name";
      title.textContent = name;

      const meta = document.createElement("div");
      meta.className = "session-item__meta";

      const viewButton = document.createElement("button");
      viewButton.className = "secondary-button";
      viewButton.textContent = "View orders";
      viewButton.addEventListener("click", () => {
        void loadOrders(name);
      });

      const switchButton = document.createElement("button");
      switchButton.className = "secondary-button";
      switchButton.textContent = "Make current";
      switchButton.addEventListener("click", () => {
        void switchSession(name);
      });

      meta.appendChild(viewButton);
      meta.appendChild(switchButton);

      li.appendChild(title);
      li.appendChild(meta);
      list.appendChild(li);
    }
  } catch (error) {
    console.error(error);
    setStatus("Could not load sessions.", true);
  }
}

async function createSession(): Promise<void> {
  const name = window.prompt("New session name:");
  if (!name) return;

  try {
    const res = await fetch("/api/session/create", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ sessionName: name }),
    });
    if (!res.ok) {
      const text = await res.text();
      throw new Error(text || `Failed to create session (${res.status})`);
    }
    setStatus(`Session created: ${name}`, false);
    await loadSessions();
  } catch (error) {
    console.error(error);
    setStatus("Could not create session.", true);
  }
}

async function switchSession(name: string): Promise<void> {
  try {
    const res = await fetch("/api/session/switch", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ sessionName: name }),
    });
    if (!res.ok) {
      const text = await res.text();
      throw new Error(text || `Failed to switch session (${res.status})`);
    }
    setStatus(`Selected session: ${name}`, false);
    await loadSessions();
  } catch (error) {
    console.error(error);
    setStatus("Could not switch session.", true);
  }
}

async function loadOrders(sessionName?: string): Promise<void> {
  const list = document.getElementById("orders-list");
  const label = document.getElementById("orders-session-label");

  if (!list || !label) return;

  list.innerHTML = "";

  const query = sessionName ? `?sessionName=${encodeURIComponent(sessionName)}` : "";

  try {
    const res = await fetch(`/api/orders${query}`);
    if (!res.ok) {
      const text = await res.text();
      throw new Error(text || `Failed to load orders (${res.status})`);
    }
    const data = (await res.json()) as OrdersResponse;

    label.textContent = `Session: ${data.sessionName}`;

    if (!data.orders || data.orders.length === 0) {
      const li = document.createElement("li");
      li.className = "empty-state";
      li.textContent = "No orders for this session.";
      list.appendChild(li);
      return;
    }

    for (const order of data.orders) {
      const li = document.createElement("li");

      const title = document.createElement("div");
      title.className = "order-title";
      title.textContent = `${order.drink} – ${order.orderId}`;

      const meta = document.createElement("div");
      meta.className = "order-meta";
      const t = new Date(order.timestamp);
      meta.textContent = `${t.toLocaleString()} • ${order.customerName || "Unknown"} • ${
        order.instructions || "No instructions"
      }`;

      li.appendChild(title);
      li.appendChild(meta);
      list.appendChild(li);
    }
  } catch (error) {
    console.error(error);
    setStatus("Could not load orders.", true);
  }
}

async function loadPopular(): Promise<void> {
  const list = document.getElementById("popular-list");
  if (!list) return;

  list.innerHTML = "";

  try {
    const res = await fetch("/api/popular");
    if (!res.ok) {
      const text = await res.text();
      throw new Error(text || `Failed to load popular items (${res.status})`);
    }

    const data = (await res.json()) as PopularResponse;
    if (!data.items || data.items.length === 0) {
      const li = document.createElement("li");
      li.className = "empty-state";
      li.textContent = "No data yet.";
      list.appendChild(li);
      return;
    }

    for (const item of data.items) {
      const li = document.createElement("li");

      const title = document.createElement("div");
      title.className = "order-title";
      title.textContent = item.drink;

      const meta = document.createElement("div");
      meta.className = "order-meta";
      meta.textContent = `${item.count} orders`;

      li.appendChild(title);
      li.appendChild(meta);
      list.appendChild(li);
    }
  } catch (error) {
    console.error(error);
    setStatus("Could not load popular items.", true);
  }
}

window.addEventListener("DOMContentLoaded", () => {
  const createBtn = document.getElementById("create-session");
  const refreshBtn = document.getElementById("refresh-sessions");

  if (createBtn) {
    createBtn.addEventListener("click", () => {
      void createSession();
    });
  }

  if (refreshBtn) {
    refreshBtn.addEventListener("click", () => {
      void loadSessions();
      void loadPopular();
    });
  }

  void loadSessions();
  void loadOrders();
  void loadPopular();
});

