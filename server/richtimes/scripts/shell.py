from richtimes import app, db
from lxml import etree
from os import path
from build_pub_data import build_pub_data
from richtimes.news.models import PubData
from flask.ext.script import Command

def get_etree(fname):
    """
    Convenience method for opening XML files relative to the app root with
    lxml.etree.
    :param fname: The XML file's name (relative to the configured XML_DIR).
    :return: lxml.etree instance.
    """
    fpath = path.join(app.config['XML_DIR'], fname)
    tree = None
    parser = etree.XMLParser(load_dtd=True,
                             attribute_defaults=True,
                             recover=True)
    with app.open_resource(fpath) as f:
        tree = etree.parse(f, parser)
    return tree


def drop_and_rebuild_tables():
    """
    Drops all the tables in the database, and rebuilds them.

    THIS IS DANGEROUS! It would be better to use alembic for version control.
    """
    # Import all the models so that the db instance knows what to drop/build.
    from richtimes.news import models
    db.drop_all()
    db.create_all(bind='richtimes')


class Rebuild(Command):

    def run(self):
        drop_and_rebuild_tables()
        build_pub_data()


def make_shell_context():
    """
    The values in the return dict are available by key from the manage.py
    shell. For instance, you can just say "build_pub_data()" instead of having
    to import it.
    """
    return {'app': app,
            'db': db,
            'get_etree': get_etree,
            'build_pub_data': build_pub_data,
            'drop_and_rebuild_tables': drop_and_rebuild_tables,
            'PubData': PubData}
