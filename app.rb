require "sqlite3"
require "cgi"

sleep 10

# ── Database setup ────────────────────────────────────────────────────────────

DB = SQLite3::Database.new("todos.db")
DB.results_as_hash = true
DB.execute_batch <<~SQL
  CREATE TABLE IF NOT EXISTS todos (
    id        INTEGER PRIMARY KEY AUTOINCREMENT,
    title     TEXT    NOT NULL,
    done      INTEGER NOT NULL DEFAULT 0,
    created_at TEXT   NOT NULL DEFAULT (datetime('now'))
  );
SQL

# ── HTML template ─────────────────────────────────────────────────────────────

def html(todos)
  items = todos.map do |t|
    done = t["done"] == 1
    <<~HTML
      <li class="todo-item #{done ? "done" : ""}">
        <form method="post" action="/todos/#{t["id"]}/toggle">
          <button class="check-btn" type="submit" title="#{done ? "Unmark" : "Complete"}">#{done ? "&#10003;" : ""}</button>
        </form>
        <span class="todo-title">#{CGI.escapeHTML(t["title"])}</span>
        <form method="post" action="/todos/#{t["id"]}/delete">
          <button class="del-btn" type="submit" title="Delete">&#215;</button>
        </form>
      </li>
    HTML
  end.join

  remaining = todos.count { |t| t["done"] == 0 }
  total      = todos.size

  <<~HTML
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>do it.</title>
      <link rel="preconnect" href="https://fonts.googleapis.com">
      <link href="https://fonts.googleapis.com/css2?family=DM+Mono:wght@300;400;500&family=DM+Serif+Display&display=swap" rel="stylesheet">
      <style>
        *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

        :root {
          --bg:      #f5f2eb;
          --surface: #fffefb;
          --ink:     #1a1714;
          --muted:   #8c877e;
          --accent:  #c84b31;
          --line:    #ddd8cf;
          --done:    #b5b0a8;
          --radius:  2px;
        }

        body {
          background: var(--bg);
          color: var(--ink);
          font-family: "DM Mono", monospace;
          min-height: 100vh;
          display: flex;
          align-items: flex-start;
          justify-content: center;
          padding: 4rem 1.5rem 6rem;
        }

        .wrap {
          width: 100%;
          max-width: 520px;
        }

        /* ── header ── */
        header {
          margin-bottom: 3rem;
        }
        header h1 {
          font-family: "DM Serif Display", serif;
          font-size: clamp(2.8rem, 8vw, 4.2rem);
          font-weight: 400;
          letter-spacing: -0.02em;
          line-height: 1;
          color: var(--ink);
        }
        header h1 span {
          color: var(--accent);
        }
        .meta {
          margin-top: 0.6rem;
          font-size: 0.72rem;
          color: var(--muted);
          letter-spacing: 0.08em;
          text-transform: uppercase;
        }

        /* ── add form ── */
        .add-form {
          display: flex;
          gap: 0;
          margin-bottom: 2.5rem;
          border: 1.5px solid var(--ink);
          border-radius: var(--radius);
          overflow: hidden;
          background: var(--surface);
          box-shadow: 3px 3px 0 var(--ink);
          transition: box-shadow 0.15s;
        }
        .add-form:focus-within {
          box-shadow: 5px 5px 0 var(--accent);
          border-color: var(--accent);
        }
        .add-form input {
          flex: 1;
          padding: 0.85rem 1rem;
          border: none;
          background: transparent;
          font-family: "DM Mono", monospace;
          font-size: 0.88rem;
          color: var(--ink);
          outline: none;
        }
        .add-form input::placeholder { color: var(--muted); }
        .add-form button {
          padding: 0 1.2rem;
          background: var(--ink);
          color: var(--bg);
          border: none;
          font-family: "DM Mono", monospace;
          font-size: 1.3rem;
          cursor: pointer;
          transition: background 0.15s;
        }
        .add-form button:hover { background: var(--accent); }

        /* ── list ── */
        .todo-list {
          list-style: none;
          display: flex;
          flex-direction: column;
          gap: 0;
        }

        .todo-item {
          display: flex;
          align-items: center;
          gap: 0.75rem;
          padding: 0.85rem 0.25rem;
          border-bottom: 1px solid var(--line);
          transition: opacity 0.2s;
          animation: slide-in 0.2s ease;
        }
        @keyframes slide-in {
          from { opacity: 0; transform: translateY(-6px); }
          to   { opacity: 1; transform: translateY(0); }
        }
        .todo-item.done { opacity: 0.45; }
        .todo-item.done .todo-title {
          text-decoration: line-through;
          color: var(--done);
        }

        .check-btn {
          width: 22px;
          height: 22px;
          min-width: 22px;
          border: 1.5px solid var(--ink);
          background: transparent;
          cursor: pointer;
          font-size: 0.75rem;
          color: var(--ink);
          border-radius: var(--radius);
          display: flex;
          align-items: center;
          justify-content: center;
          transition: background 0.12s, border-color 0.12s;
        }
        .todo-item.done .check-btn {
          background: var(--ink);
          color: var(--bg);
        }
        .check-btn:hover { border-color: var(--accent); color: var(--accent); }

        .todo-title {
          flex: 1;
          font-size: 0.88rem;
          line-height: 1.4;
        }

        .del-btn {
          opacity: 0;
          background: none;
          border: none;
          cursor: pointer;
          font-size: 1rem;
          color: var(--muted);
          padding: 0 0.1rem;
          transition: color 0.12s, opacity 0.12s;
          line-height: 1;
        }
        .todo-item:hover .del-btn { opacity: 1; }
        .del-btn:hover { color: var(--accent); }

        /* ── empty state ── */
        .empty {
          text-align: center;
          padding: 3rem 0 1rem;
          font-size: 0.78rem;
          color: var(--muted);
          letter-spacing: 0.06em;
          text-transform: uppercase;
        }

        /* ── footer actions ── */
        .footer {
          display: flex;
          justify-content: flex-end;
          margin-top: 1.5rem;
        }
        .clear-btn {
          background: none;
          border: none;
          font-family: "DM Mono", monospace;
          font-size: 0.72rem;
          color: var(--muted);
          cursor: pointer;
          letter-spacing: 0.06em;
          text-transform: uppercase;
          text-decoration: underline;
          text-underline-offset: 3px;
          transition: color 0.12s;
        }
        .clear-btn:hover { color: var(--accent); }
      </style>
    </head>
    <body>
      <div class="wrap">
        <header>
          <h1>Just done doing it continuously, one more time! pretty pretty please<span>.</span></h1>
          <p class="meta">#{remaining} remaining &mdash; #{total} total</p>
        </header>

        <!-- Add form -->
        <form class="add-form" method="post" action="/todos">
          <input type="text" name="title" placeholder="what needs doing?" autocomplete="off" maxlength="200">
          <button type="submit">+</button>
        </form>

        <!-- Todo list -->
        <ul class="todo-list">
          #{items.empty? ? '<li class="empty">nothing here yet &mdash; add something above</li>' : items}
        </ul>

        #{total > 0 ? '<div class="footer"><form method="post" action="/todos/clear_done"><button class="clear-btn" type="submit">clear completed</button></form></div>' : ""}
      </div>
    </body>
    </html>
  HTML
end

# ── Router / Rack app ─────────────────────────────────────────────────────────

App = lambda do |env|
  req    = Rack::Request.new(env)
  path   = req.path_info
  method = req.request_method

  if method == "GET" && path == "/"
    todos = DB.execute("SELECT * FROM todos ORDER BY done ASC, id DESC")
    [200, { "content-type" => "text/html; charset=utf-8" }, [html(todos)]]

  elsif method == "POST" && path == "/todos"
    title = (req.params["title"] || "").strip
    if title.empty?
      [400, { "content-type" => "text/plain" }, ["title required"]]
    else
      DB.execute("INSERT INTO todos (title) VALUES (?)", [title])
      [302, { "location" => "/" }, []]
    end

  elsif method == "POST" && path.match?(%r{\A/todos/\d+/toggle\z})
    id = path[%r{\d+}].to_i
    DB.execute("UPDATE todos SET done = CASE WHEN done = 1 THEN 0 ELSE 1 END WHERE id = ?", [id])
    [302, { "location" => "/" }, []]

  elsif method == "POST" && path.match?(%r{\A/todos/\d+/delete\z})
    id = path[%r{\d+}].to_i
    DB.execute("DELETE FROM todos WHERE id = ?", [id])
    [302, { "location" => "/" }, []]

  elsif method == "POST" && path == "/todos/clear_done"
    DB.execute("DELETE FROM todos WHERE done = 1")
    [302, { "location" => "/" }, []]

  else
    [404, { "content-type" => "text/plain" }, ["not found"]]
  end
end

