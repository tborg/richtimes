from richtimes import app, db
from lxml import etree
from os import path
from richtimes.news.models import PubData
from flask.ext.script import Command
from richtimes.news import models
import json
from glob import glob
from os.path import join


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
    db.drop_all()
    db.create_all(bind='richtimes')
    filenames = glob(join(app.root_path, app.config['XML_DIR'], '*.xml'))
    for f in filenames:
        print f
        issue = PubData(f)
        print issue.date_text
        db.session.add(issue)
        db.session.commit()


def build_repo(dir):
    for i in PubData.query.all():
        with open(join(app.root_path, dir,
                  '{}-{}.xml'.format(i.id, i.date)), 'w') as fout:
            fout.write(etree.tostring(i.get_etree(), pretty_print=True))


def build_index():
    """
    Constructs a JSON index.
    """
    def issues(data, article):
        issue = data.get(article.date, set())
        issue.add(article.subsection_type)
        data[article.date] = issue
        return issue

    def sections(data, article):
        if not article.subsection_type:
            return
        sections = data.get(article.subsection_type, set())
        sections.add(article.date)
        data[article.subsection_type] = sections
        return sections

    def jsonify(data):
        return json.dumps({k: list(v) for k, v in data.iteritems()})

    by_issue = {}
    by_section = {}
    basepath = path.join(app.root_path, app.config['JSON_DIR'])
    issues_path = path.join(basepath, 'issues.json')
    sections_path = path.join(basepath, 'sections.json')
    for article in models.Article.query.all():
        if article.article_type is 'ad-blank':
            continue
        print '\t\t\t\\/'
        issues(by_issue, article)
        sections(by_section, article)

    with open(path.join(issues_path), 'w') as fout:
        fout.write(jsonify(by_issue))
        print 'wrote ' + issues_path
    with open(path.join(sections_path), 'w') as fout:
        fout.write(jsonify(by_section))
        print 'wrote ' + sections_path


class Rebuild(Command):

    def run(self):
        drop_and_rebuild_tables()


class Index(Command):

    def run(self):
        build_index()


def make_shell_context():
    """
    The values in the return dict are available by key from the manage.py
    shell. For instance, you can just say "build_pub_data()" instead of having
    to import it.
    """
    return {'app': app,
            'db': db,
            'get_etree': get_etree,
            'drop_and_rebuild_tables': drop_and_rebuild_tables,
            'PubData': PubData,
            'build_index': build_index,
            'build_repo': build_repo}
