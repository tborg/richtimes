from richtimes import db
from lxml import etree


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
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(200), unique=True)
    year = db.Column(db.Integer)
    month = db.Column(db.Integer)
    day = db.Column(db.Integer)
    volume = db.Column(db.String(10))
    filename = db.Column(db.String(50), unique=True)
    sections = db.relationship('Section', backref='issue', lazy='dynamic')
    subsections = db.relationship('SubSection', backref='issue',
                                  lazy='dynamic')
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
        bibl = tree.xpath('/TEI.2/teiHeader//biblFull')[0]
        date_string = bibl.xpath('.//date')[0].attrib['value']
        self.year, self.month, self.day = date_string.split('-')
        self.volume = bibl.xpath('.//idno')[0].text
        self.title = bibl.xpath('.//title')[0].text

    def to_json(self):
        """
        Get a jsonifiable representation of this table.
        :return: A dictionary of this instance's attributes.
        """
        return {'id': self.id,
                'title': self.title,
                'year': self.year,
                'month': self.month,
                'day': self.day,
                'volume': self.volume,
                'filename': self.filename,
                'sections': [s.id for s in self.sections.all()],
                'subsections': [s.id for s in self.subsections.all()]}

    def get_sections(self, section_types):
        """
        Save references to all of the sections in this issue.

        This should only be run once, when the database is being
        initialized.
        """
        root = self.get_etree()
        for e in root.xpath('//div2'):
            section_type_name = e.attrib.get('type', '').lower().strip()
            if not section_type_name:
                continue
            section_type = section_types.get(section_type_name)
            if not section_type:
                section_type = SectionType(id=section_type_name)
                db.session.add(section_type)
                section_types[section_type_name] = section_type
            s = Section(issue_id=self.id,
                        xpath=root.getpath(e),
                        type_id=section_type.id)
            db.session.add(s)


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


class Section(db.Model, BaseIssueNode):
    """
    This table represents sections of an issue, corresponding to a TEI.2 `div2`
    element.
    """
    __bind_key__ = 'richtimes'
    id = db.Column(db.Integer, primary_key=True)
    xpath = db.Column(db.String(200))
    issue_id = db.Column(db.Integer, db.ForeignKey('pub_data.id'))
    type_id = db.Column(db.String(100), db.ForeignKey('section_type.id'))
    subsections = db.relationship('SubSection', backref='section',
                                  lazy='dynamic')

    def get_subsections(self, subsection_types):
        """
        Save a representation of all of the subsections under this section in
        the document.

        This should only be run once, when the database is being initialized.
        """
        root = self.issue.get_etree()
        for e in root.xpath(self.xpath + '//div3'):
            subsection_type_name = e.attrib.get('type', '').lower().strip()
            if not subsection_type_name:
                continue
            subsection_type = subsection_types.get(subsection_type_name)
            if not subsection_type:
                subsection_type = SubSectionType(id=subsection_type_name)
                db.session.add(subsection_type)
                subsection_types[subsection_type_name] = subsection_type
            s = SubSection(issue_id=self.issue.id,
                           section_id=self.id,
                           xpath=root.getpath(e),
                           type_id=subsection_type_name)
            db.session.add(s)

    def to_json(self):
        """
        Get a jsonifiable representation of this table.
        :return: A dictionary of this instance's attributes.
        """
        return {'id': self.id,
                'xpath': self.xpath,
                'issue_id': self.issue_id,
                'type_id': self.type_id,
                'subsections': [s.id for s in self.subsections.all()]}


class SectionType(db.Model):
    """
    This table represents a type of section element.
    """
    __bind_key__ = 'richtimes'
    id = db.Column(db.String(100), primary_key=True)
    sections = db.relationship('Section', backref='type', lazy='dynamic')


class SubSection(db.Model, BaseIssueNode):
    """
    This table represents subsections of an issue, corresponding to a TEI.2
    `div3` element.
    """
    __bind_key__ = 'richtimes'
    id = db.Column(db.Integer, primary_key=True)
    xpath = db.Column(db.String(200))
    issue_id = db.Column(db.Integer, db.ForeignKey('pub_data.id'))
    section_id = db.Column(db.Integer, db.ForeignKey('section.id'))
    type_id = db.Column(db.String(100), db.ForeignKey('sub_section_type.id'))
    person_associations = db.relationship('PersNameMention',
                                          backref='subsection',
                                          lazy='dynamic')

    def get_pers_names(self, pers_names, tags):
        tree = self.get_etree()
        for e in tree.xpath('.//persName'):
            pers_name_id = e.attrib.get('n', '').lower().strip()
            if not pers_name_id:
                continue
            pers_name = pers_names.get(pers_name_id)
            if not pers_name:
                pers_name = PersName(id=pers_name_id)
                db.session.add(pers_name)
                pers_names[pers_name_id] = pers_name
            element_id = e.attrib.get('id')
            pers_name_mention = PersNameMention(element_id=element_id,
                                                subsection_id=self.id,
                                                person_id=pers_name_id)
            db.session.add(pers_name_mention)
            db.session.flush()  # To get a reference to the mention's ID.
            if 'reg' not in e.attrib:
                continue
            tag_id = e.attrib['reg'].lower().strip()
            tag = tags.get(tag_id)
            if not tag:
                tag = PersNameTag(id=tag_id)
                db.session.add(tag)
                tags[tag_id] = tag
            assoc = PersNameMentionTag(tag_id=tag_id,
                                       mention_id=pers_name_mention.id)
            db.session.add(assoc)

    def to_json(self):
        """
        Get a jsonifiable representation of this table.
        :return: A dictionary of this instance's attributes.
        """
        return {'id': self.id,
                'xpath': self.xpath,
                'issue_id': self.issue_id,
                'type_id': self.type_id}


class SubSectionType(db.Model):
    """
    This table represents a type of section element.
    """
    __bind_key__ = 'richtimes'
    id = db.Column(db.String(100), primary_key=True)
    subsections = db.relationship('SubSection', backref='type', lazy='dynamic')


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
    subsection_id = db.Column(db.Integer, db.ForeignKey('sub_section.id'))
    person_id = db.Column(db.String(100), db.ForeignKey('pers_name.id'))
    mention_tag_associations = db.relationship('PersNameMentionTag',
                                               backref='mention',
                                               lazy='dynamic')


class PersNameTag(db.Model):
    """
    Represents a metadata tag associated with a `persName` element.
    """
    __bind_key__ = 'richtimes'
    id = db.Column(db.String(100), primary_key=True)
    mention_tag_associations = db.relationship('PersNameMentionTag',
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
