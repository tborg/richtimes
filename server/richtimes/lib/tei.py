from lxml import etree


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
