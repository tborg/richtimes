from flask import Flask
from flask_sqlalchemy import SQLAlchemy
import os
import logging
import logging.handlers

# Set up the Flask application object
app = Flask(__name__, template_folder='templates', static_folder=None,
            static_url_path='/static_null')
app.config.from_object('config.Config')
app.static_folder = os.path.realpath(os.path.join(app.root_path, "../static"))

db = SQLAlchemy(app)

# Initialize logging
formatter = logging.Formatter('%(asctime)s %(levelname)s: %(message)s')
disk = logging.handlers.TimedRotatingFileHandler('RESTServer.log', 'midnight')
disk.suffix = '%Y%m%d'
disk.setLevel(logging.DEBUG)
disk.setFormatter(formatter)
app.logger.addHandler(disk)
