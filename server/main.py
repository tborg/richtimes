import argparse


from richtimes import app
from richtimes.news.views import news
from flask import redirect, url_for

app.register_blueprint(news)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", type=str, default='127.0.0.1',
                        help="Host. Defaults to 127.0.0.1.")
    parser.add_argument("--port", type=int, default=5000,
                        help="Port. Defaults to 5000.")
    args = parser.parse_args()

    @app.route('/')
    def index():
        return redirect(url_for('static', filename='index.html'))

    app.run(debug=True, host=args.host, port=args.port)
