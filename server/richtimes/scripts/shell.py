from richtimes import app, db


def make_shell_context():
    return {'app': app,
            'db': db}
