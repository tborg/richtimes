from flask import Blueprint, send_from_directory
from richtimes import app

dev_static = Blueprint('dev_static', __name__)


@dev_static.route('/<path:filename>')
def serve_static_resouce(filename):
    print filename
    try:
        return send_from_directory(app.root_path + '/../../app', filename)
    except Exception:
        return send_from_directory(app.root_path + '/../../.tmp', filename)
