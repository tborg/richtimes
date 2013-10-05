from flask import Blueprint, send_from_directory
from richtimes import app

dev_static = Blueprint('dev_static', __name__)


@dev_static.route('/app/<path:filename>')
def serve_static_resouce(filename):
    print filename
    try:
        return send_from_directory(app.root_path + '/../../app', filename)
    except Exception as e:
        app.logger.error('not found', exc_info=e)
        return send_from_directory(app.root_path + '/../../.tmp', filename)
