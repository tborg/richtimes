from richtimes import db
from lxml import etree, html


class BaseIssueNode():
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

    def get_json(self):
        """
        Converts an lxml.etree instance into a jsonifiable format recursively.
        This is not optimized to work on huge trees.
        :param node: The element tree to objectify
        :return: objectified xml.
        """
        node = self.get_etree()
        return node_to_json(node)


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
    id = db.Column(db.String(50), primary_key=True)
    year = db.Column(db.String(4))
    month = db.Column(db.String(2))
    day = db.Column(db.String(2))
    date_text = db.Column(db.String(50))
    filename = db.Column(db.String(50), unique=True)
    sections = db.relationship('Section', backref='issue', lazy='dynamic')
    subsections = db.relationship('Subsection', backref='issue',
                                  lazy='dynamic')
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
        the metadata we're interested in from the teiHeader.
        :param tree: The lxml.etree instance of this issue.
        """
        title_page = tree.xpath('/TEI.2/text/front/titlePage')[0]
        date_el = title_page.xpath('./docImprint/date')[0]
        self.id = date_el.attrib['value']
        self.year, self.month, self.day = self.id.split('-')
        self.date_text = date_el.text

    def to_json(self):
        """
        Get a jsonifiable representation of this table.
        :return: A dictionary of this instance's attributes.
        """
        subsections = {}
        for s in self.subsections.all():
            subsection_type = subsections.get(s.type_id, [])
            subsection_type.append(s.id)
            subsections[s.type_id] = subsection_type

        return {'id': self.id,
                'date_text': self.date_text,
                'subsections': subsections}

    def get_document_json(self):
        return [s.to_json() for s in self.sections.all()]

    def get_sections(self, section_types):
        """
        Save references to all of the sections in this issue.

        This should only be run once, when the database is being
        initialized.
        """
        root = self.get_etree()
        for e in root.xpath('//div1'):
            id = e.attrib.get('type', '').lower().strip()
            if not id:
                continue
            section_type = section_types.get(id)
            if not section_type:
                section_type = SectionType.query.get(id)
                if not section_type:
                    section_type = SectionType(id=id)
                    db.session.add(section_type)
                section_types[id] = section_type
            s = Section(issue_id=self.id,
                        xpath=root.getpath(e),
                        type_id=section_type.id)
            db.session.add(s)


class Section(db.Model, BaseIssueNode):
    """
    This table represents sections of an issue, corresponding to a TEI.2 `div2`
    element.
    """
    __bind_key__ = 'richtimes'
    id = db.Column(db.Integer, primary_key=True)
    xpath = db.Column(db.String(200))
    issue_id = db.Column(db.String(50), db.ForeignKey('pub_data.id'))
    type_id = db.Column(db.String(100), db.ForeignKey('section_type.id'))
    subsections = db.relationship('Subsection', backref='section',
                                  lazy='dynamic')

    def get_subsections(self, subsection_types):
        """
        Save a representation of all of the articles under this section in
        the document.

        This should only be run once, when the database is being initialized.
        """
        root = self.issue.get_etree()
        for e in root.xpath(self.xpath + '/div2'):
            id = e.attrib.get('type', '').lower().strip()
            if not id:
                continue
            subsection_type = subsection_types.get(id)
            if not subsection_type:
                subsection_type = SubsectionType.query.get(id)
                if not subsection_type:
                    subsection_type = SubsectionType(id=id)
                    db.session.add(subsection_type)
                subsection_types[id] = subsection_type
            s = Subsection(issue_id=self.issue.id,
                           section_id=self.id,
                           xpath=root.getpath(e),
                           type_id=id)
            db.session.add(s)

    def to_json(self):
        """
        Get a jsonifiable representation of this table.
        :return: A dictionary of this instance's attributes.
        """
        return {'id': self.id,
                'type': self.type_id,
                'subsections': [s.to_json() for s in self.subsections.all()]}


class SectionType(db.Model):
    """
    This table represents a type of section element.
    """
    __bind_key__ = 'richtimes'
    id = db.Column(db.String(100), primary_key=True)
    sections = db.relationship('Section', backref='type', lazy='dynamic')

    def to_json(self):
        """
        Includes the set of related subsection types.
        """
        subsection_types = set()
        for s in self.sections.all():
            for ss in s.subsections.all():
                subsection_types.add(ss.type_id)
        return {'id': self.id,
                'subsections': list(subsection_types)}


class Subsection(db.Model, BaseIssueNode):
    __bind_key__ = 'richtimes'
    id = db.Column(db.Integer, primary_key=True)
    xpath = db.Column(db.String(200))
    issue_id = db.Column(db.String(50), db.ForeignKey('pub_data.id'))
    section_id = db.Column(db.Integer, db.ForeignKey('section.id'))
    type_id = db.Column(db.String(100), db.ForeignKey('subsection_type.id'))
    articles = db.relationship('Article',
                               backref=db.backref('subsection', lazy='joined'),
                               lazy='dynamic')

    def get_articles(self, article_types):
        """
        Save a representation of all of the articles under this section in
        the document.

        This should only be run once, when the database is being initialized.
        """
        root = self.issue.get_etree()
        for e in root.xpath(self.xpath + '/div3'):
            id = e.attrib.get('type', '').lower().strip()
            if not id:
                continue
            article_type = article_types.get(id)
            if not article_type:
                article_type = ArticleType.query.get(id)
                if not article_type:
                    article_type = ArticleType(id=id)
                    db.session.add(article_type)
                article_types[id] = article_type
            s = Article(issue_id=self.issue.id,
                        section_id=self.section.id,
                        subsection_id=self.id,
                        xpath=root.getpath(e),
                        type_id=id)
            db.session.add(s)

    def to_json(self):
        articles = {}
        for a in self.articles.all():
            article_type = articles.get(a.type_id, [])
            article_type.append(a.id)
            articles[a.type_id] = article_type
        return {'id': self.id,
                'type': self.type_id,
                'articles': articles}


class SubsectionType(db.Model):
    """
    This table represents a type of section element.
    """
    __bind_key__ = 'richtimes'
    id = db.Column(db.String(100), primary_key=True)
    subsections = db.relationship('Subsection', backref='type', lazy='dynamic')

    def to_json(self):
        return {'id': self.id,
                'subsections': [s.id for s in self.subsections.all()]}


class Article(db.Model, BaseIssueNode):
    """
    This table represents articles of an issue, corresponding to a TEI.2
    `div3` element.
    """
    __bind_key__ = 'richtimes'
    id = db.Column(db.Integer, primary_key=True)
    xpath = db.Column(db.String(200))
    issue_id = db.Column(db.String(50), db.ForeignKey('pub_data.id'))
    section_id = db.Column(db.Integer, db.ForeignKey('section.id'))
    subsection_id = db.Column(db.Integer, db.ForeignKey('subsection.id'))
    type_id = db.Column(db.String(100), db.ForeignKey('article_type.id'))
    person_mentions = db.relationship('PersNameMention',
                                      backref='article',
                                      lazy='dynamic')
    place_mentions = db.relationship('PlaceNameMention',
                                     backref='article',
                                     lazy='dynamic')
    org_mentions = db.relationship('OrgMention',
                                   backref='article',
                                   lazy='dynamic')
    ref_string_metions = db.relationship('RefStringMention',
                                         backref='article',
                                         lazy='dynamic')

    def get_pers_names(self, pers_names, tags):
        tree = self.get_etree()
        for e in tree.xpath('.//persName'):
            id = e.attrib.get('n', '').lower().strip()
            if not id:
                continue
            pers_name = pers_names.get(id)
            if not pers_name:
                pers_name = PersName.query.get(id)
                if not pers_name:
                    pers_name = PersName(id=id)
                    db.session.add(pers_name)
                pers_names[id] = pers_name
            element_id = e.attrib.get('id')
            pers_name_mention = PersNameMention(element_id=element_id,
                                                article_id=self.id,
                                                person_id=id)
            db.session.add(pers_name_mention)
            db.session.flush()  # To get a reference to the mention's ID.
            if 'reg' not in e.attrib:
                continue
            tag_id = e.attrib['reg'].lower().strip()
            tag = tags.get(tag_id)
            if not tag:
                tag = PersNameTag.query.get(tag_id)
                if not tag:
                    tag = PersNameTag(id=tag_id)
                    db.session.add(tag)
                tags[tag_id] = tag
            assoc = PersNameMentionTag(tag_id=tag_id,
                                       mention_id=pers_name_mention.id)
            db.session.add(assoc)

    def get_place_names(self, place_names):
        tree = self.get_etree()
        root = self.issue.get_etree()
        for e in tree.xpath('.//placeName'):
            ids = e.attrib.get('key')
            regs = e.attrib.get('reg')
            if not ids or not regs:
                continue
            xpath = root.getpath(e)
            for id, reg in zip(ids.split(';'), regs.split(';')):
                id = id.strip().lower()
                place_name = place_names.get(id)
                reg = ','.join([x.strip().lower() for x in reg.split(',')])
                if not place_name:
                    place_name = PlaceName.query.get(id)
                    if not place_name:
                        place_name = PlaceName(id=id, reg=reg)
                        db.session.add(place_name)
                    place_names[id] = place_name
                # If they disagree, the longer reg is more specific.
                if len(reg) > place_name.reg:
                    place_name.reg = reg
                    db.session.add(place_name)
                place_name_mention = PlaceNameMention(xpath=xpath,
                                                      article_id=self.id,
                                                      place_name_id=id)
                db.session.add(place_name_mention)

    def get_org_names(self, org_types):
        tree = self.get_etree()
        root = self.issue.get_etree()
        for e in tree.xpath('.//orgName'):
            type_id = e.attrib.get('type', '').strip().lower()
            n = e.attrib.get('n', '').strip().lower()
            if not type_id or not n:
                continue
            org_type = org_types.get(type_id)
            if not org_type:
                org_type = OrgType.query.get(type_id)
                if not org_type:
                    org_type = OrgType(id=type_id)
                    db.session.add(org_type)
                org_types[type_id] = org_type
            org_name = OrgName.query.filter_by(name=n, type_id=type_id).first()
            if not org_name:
                org_name = OrgName(name=n, type_id=type_id)
                db.session.add(org_name)
                db.session.flush()
            org_mention = OrgMention(org_name_id=org_name.id,
                                     article_id=self.id,
                                     xpath=root.getpath(e))
            db.session.add(org_mention)

    def get_ref_strings(self, ref_string_types):
        tree = self.get_etree()
        root = self.issue.get_etree()
        for e in tree.xpath('.//rs'):
            type_id = e.attrib.get('type', '').strip().lower()
            if not type_id:
                continue
            ref_string_type = ref_string_types.get(type_id)
            if not ref_string_type:
                ref_string_type = RefStringType.query.get(type_id)
                if not ref_string_type:
                    ref_string_type = RefStringType(id=type_id)
                    db.session.add(ref_string_type)
                ref_string_types[type_id] = ref_string_type
            text = e.attrib.get('reg', '').strip().lower()
            if not text:
                text = ''.join(e.itertext())
                if not text:
                    continue
            ref_string = RefString.query.filter_by(type_id=type_id,
                                                   text=text).first()
            if not ref_string:
                ref_string = RefString(type_id=type_id, text=text)
                db.session.add(ref_string)
                db.session.flush()
            mention = RefStringMention(ref_string_id=ref_string.id,
                                       article_id=self.id,
                                       xpath=root.getpath(e))
            db.session.add(mention)

    def get_html(self):
        """
        Transforms the XML into some browser-ready content.

        Pre-defined transformations exist for certain tags; others are simply
        converted to `<span class="tei $tag">`.

        All attributes are prefixed with `data-tei-`.

        The only special context we're interested in holding during DOM parsing
        is whether or not we're in a table; in that case a `head` should be
        translated into a `tr>th` instead of an `h3`.
        """
        def attributes(node):
            attrs = {'class': 'tei {}'.format(node.tag)}
            for k, v in node.attrib.iteritems():
                attrs['data-tei-{}'.format(k)] = v
            return attrs

        def table(context, node):
            table = etree.SubElement(context, 'table', **attributes(node))
            table.text = node.text
            table.tail = node.tail
            thead = etree.SubElement(table, 'thead')
            tbody = etree.SubElement(table, 'tbody')
            for c in node.iterchildren(tag=etree.Element):
                if c.tag == 'head':
                    row = etree.SubElement(thead, 'tr', **attributes(c))
                    header = etree.SubElement(row, 'th')
                    header.text = c.text
                    header.tail = c.tail
                else:
                    row = etree.SubElement(tbody, 'tr', **attributes(c))
                    for cell in c.iterchildren():
                        col = etree.SubElement(row, 'td', **attributes(cell))
                        for _c in child_elements(cell):
                            build(col, _c)
                        col.text = cell.text
                        col.tail = cell.tail
            return table

        def identity(context, node):
            this = etree.SubElement(context, node.tag, **attributes(node))
            this.text = node.text
            this.tail = node.tail
            for c in node.iterchildren(tag=etree.Element):
                build(this, c)

        def head(context, node):
            this = etree.SubElement(context, 'h3', **attributes(node))
            this.text = node.text
            this.tail = node.tail
            for c in node.iterchildren(tag=etree.Element):
                build(this, c)
            return this

        # `list` is a reserved word ...
        def _list(context, node):
            this = etree.SubElement(context, 'ul', **attributes(node))
            this.text = node.text
            this.tail = node.tail
            for c in child_elements(node):
                li = etree.SubElement(this, 'li', **attributes(c))
                if c.tag is 'item':
                    li.text = c.text
                    li.tail = c.tail
                    for cc in child_elements(c):
                        build(li, cc)
                else:  # wrap non-list-item elements in a `li`.
                    build(li, c)
            return this

        def build(context, node):
            if node.tag in transforms:
                this = transforms[node.tag](context, node)
            else:
                this = etree.SubElement(context, 'span', **attributes(node))
                this.text = node.text
                this.tail = node.tail
                for c in node.iterchildren(tag=etree.Element):
                    build(this, c)
            return this

        transforms = {'table': table,
                      'p': identity,
                      'head': head,
                      'list': _list}

        root = etree.Element('article', id=str(self.id), type=self.type_id)
        return html.tostring(build(root, self.get_etree()))

    def to_json(self):
        """
        Get a jsonifiable representation of this table.
        :return: A dictionary of this instance's attributes.
        """
        return {'id': self.id,
                'type': self.type_id,
                'date': self.issue_id,
                'date_text': self.issue.date_text,
                'content': self.get_html()}


class ArticleType(db.Model):
    """
    This table represents a type of section element.
    """
    __bind_key__ = 'richtimes'
    id = db.Column(db.String(100), primary_key=True)
    articles = db.relationship('Article', backref='type', lazy='dynamic')

    def to_json(self):
        articles = {}
        for a in self.articles.all():
            date = articles.get(a.issue_id, [])
            date.append(a.id)
            articles[a.issue_id] = date
        return {'id': self.id,
                'articles': articles}


class PersName(db.Model):
    """
    Represents a personal name occurring in the Richmond Dispatch.

    The primary key is the value of the `n` attribute of the `persName` tag.
    """
    __bind_key__ = 'richtimes'
    id = db.Column(db.String(100), primary_key=True)
    mentions = db.relationship('PersNameMention',
                               backref='person',
                               lazy='dynamic')


class PersNameMention(db.Model):
    """
    Represents a mention of a personal name in the Richmond Dispatch.

    The primary key is the `id` attribute of the `persName` tag.
    """
    __bind_key__ = 'richtimes'
    id = db.Column(db.Integer, primary_key=True)
    # This unfortunately is not unique across documents.
    element_id = db.Column(db.String(100))
    article_id = db.Column(db.Integer, db.ForeignKey('article.id'))
    person_id = db.Column(db.String(100), db.ForeignKey('pers_name.id'))
    mention_tag_mentions = db.relationship('PersNameMentionTag',
                                           backref='mention',
                                           lazy='dynamic')


class PersNameTag(db.Model):
    """
    Represents a metadata tag associated with a `persName` element.
    """
    __bind_key__ = 'richtimes'
    id = db.Column(db.String(100), primary_key=True)
    mention_tag_mentions = db.relationship('PersNameMentionTag',
                                           backref='tag',
                                           lazy='dynamic')


class PersNameMentionTag(db.Model):
    """
    Associates a tag with a mention of a personal name.
    """
    __bind_key__ = 'richtimes'
    id = db.Column(db.Integer, primary_key=True)
    tag_id = db.Column(db.String(100), db.ForeignKey('pers_name_tag.id'))
    mention_id = db.Column(db.Integer, db.ForeignKey('pers_name_mention.id'))


class PlaceName(db.Model):
    __bind_key__ = 'richtimes'
    id = db.Column(db.String(20), primary_key=True)
    reg = db.Column(db.String(200))
    mentions = db.relationship('PlaceNameMention',
                               backref='place_name',
                               lazy='dynamic')


class PlaceNameMention(db.Model):
    __bind_key__ = 'richtimes'
    id = db.Column(db.Integer, primary_key=True)
    xpath = db.Column(db.String(200), primary_key=True)
    article_id = db.Column(db.Integer, db.ForeignKey('article.id'))
    place_name_id = db.Column(db.String(20), db.ForeignKey('place_name.id'))


class OrgName(db.Model):
    __bind_key__ = 'richtimes'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), index=True)
    type_id = db.Column(db.String(100), db.ForeignKey('org_type.id'))
    mentions = db.relationship('OrgMention',
                               backref='org_name',
                               lazy='dynamic')


class OrgType(db.Model):
    __bind_key__ = 'richtimes'
    id = db.Column(db.String(100), primary_key=True)
    orgs = db.relationship('OrgName', backref='type', lazy='dynamic')


class OrgMention(db.Model):
    __bind_key__ = 'richtimes'
    id = db.Column(db.Integer, primary_key=True)
    xpath = db.Column(db.String(200))
    article_id = db.Column(db.Integer, db.ForeignKey('article.id'))
    org_name_id = db.Column(db.Integer, db.ForeignKey('org_name.id'))


class RefString(db.Model):
    __bind_key__ = 'richtimes'
    id = db.Column(db.Integer, primary_key=True)
    text = db.Column(db.String(100))
    type_id = db.Column(db.String(100), db.ForeignKey('ref_string_type.id'))
    mentions = db.relationship('RefStringMention',
                               backref='ref_string',
                               lazy='dynamic')


class RefStringType(db.Model):
    __bind_key__ = 'richtimes'
    id = db.Column(db.String(100), primary_key=True)
    ref_strings = db.relationship('RefString', backref='type', lazy='dynamic')


class RefStringMention(db.Model):
    __bind_key__ = 'richtimes'
    id = db.Column(db.Integer, primary_key=True)
    xpath = db.Column(db.String(200))
    article_id = db.Column(db.Integer, db.ForeignKey('article.id'))
    ref_string_id = db.Column(db.Integer, db.ForeignKey('ref_string.id'))


def child_elements(node):
    """
    Return just the child elements. Skip entities and comments.
    """
    return node.iterchildren(tag=etree.Element)


def node_to_json(node):
    """
    Converts an lxml.etree instance into a jsonifiable format recursively.
    This is not optimized to work on huge trees.
    :param node: The element tree to objectify
    :return: objectified xml.
    """
    el = {'tag': node.tag, 'attrib': dict(node.attrib), 'text': node.text}
    children = [node_to_json(c) for c in child_elements(node)]
    if children:
        el['children'] = children
    return el
