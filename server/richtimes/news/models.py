from richtimes import db
from richtimes.lib import tei
from lxml import etree, html


DATE_XP = '/TEI.2/teiHeader/fileDesc/sourceDesc/biblFull/publicationStmt/date'


class BaseIssueNode:
    """
    Abstract base class for a table representing a node in an issue.
    """
    _etree = None

    def get_etree(self):
        """
        Get an lxml.etree representation of this node in the issue.
        :return: instance of lxml.etree
        """
        if self._etree:
            return self._etree
        root = self.issue.get_etree()
        self._etree = root.xpath(self.xpath)[0]
        return self._etree

    def get_xml(self):
        """
        Get the string representation of this node in the issue.
        :return: The TEI.2-encoded representation of this node.
        """
        return etree.tostring(self.get_etree())


class PubData(db.Model):
    """
    This table holds basic publication data about each issue of the Richmond
    Daily Dispatch in the corpus. The most salient facets are probably year,
    month, and day.

    In addition to the metadata stored in the table, this class provides an
    accessor to an lxml.etree instance of the issue's TEI: `get_etree`. This is
    the preferred method for accessing the XML.
    """
    __bind_key__ = 'richtimes'
    id = db.Column(db.Integer(), primary_key=True)
    date = db.Column(db.String(10))
    year = db.Column(db.String(4))
    month = db.Column(db.String(2))
    day = db.Column(db.String(2))
    date_text = db.Column(db.String(50))
    filename = db.Column(db.String(100), unique=True)
    articles = db.relationship('Article', backref='issue', lazy='dynamic')
    # Hold a reference to the tree on the object for efficiency.
    _etree = None

    def __init__(self, filename):
        self.filename = filename
        tree = self.get_etree()
        self._parse(tree)

    def get_etree(self):
        """
        Get an etree instance of the issue.
        :return: An lxml.etree instance of the issue's TEI representation.
        """
        if self._etree:
            return self._etree
        from richtimes.scripts.shell import get_etree
        self._etree = get_etree(self.filename)
        return self._etree

    def _parse(self, tree):
        """
        Called when a PubData model is initialized; uses xpath to track down
        the metadata we're interested in from the teiHeader, and then indexes
        all of the child articles and their entities.
        :param tree: The lxml.etree instance of this issue.
        """
        date_el = self.get_etree().xpath(DATE_XP)[0]
        self.date = date_el.attrib['value']
        self.year, self.month, self.day = self.date.split('-')
        self.date_text = date_el.text

        def resolve_type(element):
            return element.attrib.get('type', '').lower().strip('. ')

        def index_entity(nodes, model, article):
            for n in nodes:
                m = model(n, article)
                if m.ok:
                    db.session.add(m)

        def get_html(article):
            return html.tostring(tei.build(etree.Element('article'), article))

        root = self.get_etree()
        for section in root.xpath('//div1'):
            section_type = resolve_type(section)
            if not section_type:
                continue
            for subsection in section.xpath('./div2'):
                subsection_type = resolve_type(subsection)
                if not subsection_type:
                    continue
                for article in subsection.xpath('./div3'):
                    article_type = resolve_type(article)
                    if article_type == 'ad-blank':
                        continue
                    a = Article(issue_id=self.id,
                                date=self.date,
                                section_type=section_type,
                                subsection_type=subsection_type,
                                article_type=article_type,
                                xpath=root.getpath(article),
                                content=get_html(article))
                    db.session.add(a)
                    db.session.flush()
                    index_entity(article.xpath('.//persName'), PersName, a)
                    index_entity(article.xpath('.//placeName'), PlaceName, a)
                    index_entity(article.xpath('.//orgName'), OrgName, a)
                    index_entity(article.xpath('.//rs'), RefString, a)


class Article(db.Model, BaseIssueNode):
    """
    This table represents articles of an issue, corresponding to a TEI.2
    `div3` element.
    """
    __bind_key__ = 'richtimes'
    id = db.Column(db.Integer, primary_key=True)
    issue_id = db.Column(db.Integer(), db.ForeignKey('pub_data.id'))
    date = db.Column(db.String(10), index=True)
    section_type = db.Column(db.String(200))
    subsection_type = db.Column(db.String(200), index=True)
    article_type = db.Column(db.String(200))
    xpath = db.Column(db.String(200))
    content = db.Column(db.UnicodeText)
    people = db.relationship('PersName',
                             backref='article',
                             lazy='dynamic')
    places = db.relationship('PlaceName',
                             backref='article',
                             lazy='dynamic')
    orgs = db.relationship('OrgName',
                           backref='article',
                           lazy='dynamic')
    ref_strings = db.relationship('RefString',
                                  backref='article',
                                  lazy='dynamic')

    def to_json(self):
        """
        Get a jsonifiable representation of this table.
        :return: A dictionary of this instance's attributes.
        """
        related = {'people': list(set([p.n for p in self.people.all()])),
                   'places': list(set([p.reg for p in self.places.all()])),
                   'organizations': list(set([o.n for o in self.orgs.all()])),
                   'keywords': list(set([k.reg for k in self.ref_strings.all()]))}
        return {'id': self.id,
                'date': self.date,
                'section': self.section_type,
                'subsection': self.subsection_type,
                'article_type': self.article_type,
                'xpath': self.xpath,
                'content': self.content,
                'related': related}


class BaseArticleEntity:
    ok = True
    date = db.Column(db.String(10))

    def __init__(self, element, article):
        self.article_id = article.id
        self.date = article.date
        for attr, required in self.attrib.iteritems():
            if isinstance(required, bool):
                dest = attr
            else:
                dest, required = required
            val = element.attrib.get(attr, '')
            if required and not val:
                self.ok = False
                return
            setattr(self, dest, val.lower().strip())

    def to_json(self):
        ret = {'article_id': self.article_id,
               'date': self.date}
        for k in self.attrib.keys():
            ret[k] = getattr(self, k)
        return ret


class PersName(BaseArticleEntity, db.Model):
    __bind_key__ = 'richtimes'
    """
    Represents a personal name occurring in the Richmond Dispatch.

    The primary key is the value of the `n` attribute of the `persName` tag.
    """
    id = db.Column(db.Integer(), primary_key=True)
    article_id = db.Column(db.Integer(), db.ForeignKey('article.id'))
    n = db.Column(db.String(100), index=True)
    reg = db.Column(db.String(200))
    element_id = db.Column(db.String(100))
    ok = True
    attrib = {'n': True,
              'id': ('element_id', False),
              'reg': True}


class PlaceName(BaseArticleEntity, db.Model):
    __bind_key__ = 'richtimes'
    id = db.Column(db.Integer(), primary_key=True)
    article_id = db.Column(db.Integer(), db.ForeignKey('article.id'))
    key = db.Column(db.String(100), index=True)
    reg = db.Column(db.String(200))
    ok = True
    attrib = {'key': True,
              'reg': True}


class OrgName(BaseArticleEntity, db.Model):
    __bind_key__ = 'richtimes'
    id = db.Column(db.Integer, primary_key=True)
    article_id = db.Column(db.Integer(), db.ForeignKey('article.id'))
    n = db.Column(db.String(100), index=True)
    type = db.Column(db.String(100), index=True)
    attrib = {'n': True,
              'type': True}


class RefString(BaseArticleEntity, db.Model):
    __bind_key__ = 'richtimes'
    id = db.Column(db.Integer, primary_key=True)
    article_id = db.Column(db.Integer(), db.ForeignKey('article.id'))
    reg = db.Column(db.String(200), index=True)
    type = db.Column(db.String(100), index=True)
    attrib = {'reg': True,
              'type': True}
