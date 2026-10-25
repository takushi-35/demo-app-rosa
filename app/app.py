import os
import socket

from flask import Flask, jsonify, render_template_string

VERSION = "v2"
MESSAGE = os.environ.get("APP_MESSAGE", "Hello Red Hat Customers!")
COLOR = os.environ.get("APP_COLOR", "#ee0000")

PAGE = """<!doctype html>
<html lang="ja">
<head><meta charset="utf-8"><title>ROSA CI/CD Demo</title>
<style>
  body { font-family: sans-serif; margin: 0; display: flex; align-items: center;
         justify-content: center; height: 100vh; background: {{ color }}; color: #fff; }
  .card { text-align: center; }
  h1 { font-size: 3rem; margin: 0 0 1rem; }
  p { font-size: 1.2rem; margin: .3rem; }
</style></head>
<body><div class="card">
  <h1>{{ message }}</h1>
  <p>Version: {{ version }}</p>
  <p>Pod: {{ hostname }}</p>
</div></body></html>"""

app = Flask(__name__)


@app.route("/")
def index():
    return render_template_string(
        PAGE, message=MESSAGE, color=COLOR, version=VERSION, hostname=socket.gethostname()
    )


@app.route("/api/info")
def info():
    return jsonify(version=VERSION, message=MESSAGE, hostname=socket.gethostname())


@app.route("/healthz")
def healthz():
    return jsonify(status="ok")


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "8080")))
