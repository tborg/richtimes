from flask import Flask
from flask_sqlalchemy import SQLAlchemy
import logging
import logging.handlers
from pyelasticsearch import ElasticSearch

# Set up the Flask application object
app = Flask(__name__,
            template_folder='templates',
            static_folder="../../build/htdocs",
            static_url_path='/static')

app.config.from_object('config.Config')

db = SQLAlchemy(app)

# Initialize logging
formatter = logging.Formatter('%(asctime)s %(levelname)s: %(message)s')
disk = logging.handlers.TimedRotatingFileHandler('RESTServer.log', 'midnight')
disk.suffix = '%Y%m%d'
disk.setLevel(logging.DEBUG)
disk.setFormatter(formatter)
app.logger.addHandler(disk)

# Initialize elastic search
