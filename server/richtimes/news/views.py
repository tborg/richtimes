from flask import Blueprint, jsonify, request
from richtimes.news import models

news = Blueprint('news', __name__)


IGNORE_SECTIONS = ['page-image', 'subscription', 'advertising']


def paginate(q, default=25):
    offset = int(request.values.get('offset', 0))
    if offset:
        q = q.offset(offset)
    limit = request.values.get('limit')
    if limit:
        q = q.limit(limit)
    return (q, offset)


@news.route('/dates')
def get_dates():
    return jsonify({'dates': [i.to_json() for i in models.PubData.query.all()]})


@news.route('/contentTypes')
def get_content_types():
    content_types = [t.to_json() for t in models.ArticleType.query.all()]
    return jsonify({'contentTypes': content_types})


@news.route('/sections')
def get_sections():
    date = request.values.get('date')
    if not date:
        return jsonify({'status_code': 400,
                        'error': 'Date is a required param.'})
    content_type = request.values.get('content_type')
    if not content_type:
        return jsonify({'status_code': 400,
                        'error': 'Content Type is a required param.'})
    article_type = models.ArticleType.query.get(content_type)
    if not article_type:
        return jsonify({'status_code': 404,
                        'error': 'No content type {}'.format(article_type)})
    sections = {}
    for a in article_type.articles.filter_by(issue_id=date).all():
        tid = a.subsection.type_id
        section = sections.get(tid, {'id': tid, 'articles': []})
        section['articles'].append(a.id)
        sections[tid] = section

    return jsonify({'sections': [v for k, v in sections.iteritems() if v]})


@news.route('/articles/<id>')
def get_article(id):
    article = models.Article.query.get(id)
    if not article:
        return jsonify({'status_code': 404, 'error': 'Article Not Found'})
    return jsonify({'article': article.to_json()})
