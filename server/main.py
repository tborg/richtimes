import argparse

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", type=str, default='127.0.0.1',
                        help="Host. Defaults to 127.0.0.1.")
    parser.add_argument("--port", type=int, default=5000,
                        help="Port. Defaults to 5000.")
    args = parser.parse_args()

    from richtimes import app
    from dev_static import dev_static
    from flask import redirect

    app.register_blueprint(dev_static)

    @app.route('/')
    def index():
        return redirect('/app/index.html')

    app.run(debug=True, host=args.host, port=args.port)
