from calendar import timegm
from datetime import datetime
from dateutil.relativedelta import relativedelta
from flask import Blueprint, jsonify, request
from itertools import groupby
from richtimes import db
from richtimes.news import models
from functools import wraps
from sqlalchemy import distinct
from sqlalchemy.orm import aliased
news = Blueprint('news', __name__)
import json


def with_articles(fn):
    @wraps(fn)
    def handler(date, subsection_type, **kwargs):
        arts = models.Article.query.filter_by(date=date,
                                              subsection_type=subsection_type)
        kwargs
        return fn(date, subsection_type, arts, **kwargs)
    return handler


def calendar():
    first = models.PubData.query.order_by(models.PubData.timegm).first().date
    last = models.PubData.query.order_by(models.PubData.timegm.desc()).first().date
    date = issue_date_to_datetime(first)
    d = relativedelta(days=1)
    end = issue_date_to_datetime(last)
    dates = [date]
    while date <= end:
        date += d
        dates.append(date)
    return dates


def issue_date_to_datetime(date):
    [y, m, d] = map(int, date.split('-'))
    return datetime(y, m, d)


def date_to_timegm(date):
    return timegm(date.timetuple())


def date_range(q, start, end):
    return q.filter(models.PubData.timegm > date_to_timegm(start),
                    models.PubData.timegm < date_to_timegm(end))


def issues_y_m():
    o = {}
    for k, v in groupby(calendar(), lambda d: (d.year, d.month)):
        y = o.get(k[0], {})
        m = y.get(k[1], [])
        for date in v:
            time = date_to_timegm(date)
            m.append(models.PubData.query.filter(models.PubData.timegm == time))
        y[k[1]] = m
        o[k[0]] = y
    return o


@news.route('/v1/articles/<date>/<subsection_type>', methods=['GET'])
@with_articles
def articles(date, subsection_type, articles):
    return jsonify({'data': [a.to_json() for a in articles.all()]})


@news.route('/v1/related-articles', methods=['GET'])
def related_articles():
    """
    Fetch a set of articles related to the terms in your query.

    :param keywords:
    :param people:
    :param places:
    :param organizations:
    :param offset:
    """
    limit = min(request.values.get('limit', 10), 200)
    offset = request.values.get('offset', 0)
    q = models.Article.query

    def get_param(key):
        return filter(bool, request.values.get(key, '').split(';'))

    for p in get_param('people'):
        people = models.PersName.query.\
            filter(models.PersName.n == p).\
            subquery()
        q = q.join(aliased(models.PersName, people))
    for p in get_param('places'):
        places = models.PlaceName.query.\
            filter(models.PlaceName.reg == p).\
            subquery()
        q = q.join(aliased(models.PlaceName, places), models.Article.places)
    for o in get_param('organizations'):
        orgs = models.OrgName.query.\
            filter(models.OrgName.n == o).\
            subquery()
        q = q.join(aliased(models.OrgName, orgs), models.Article.orgs)
    for k in get_param('keywords'):
        keywords = models.RefString.query.\
            filter(models.RefString.reg == k)\
            .subquery()
        aliased_kw = aliased(models.RefString, keywords)
        q = q.join(aliased_kw)

    articles = q.\
        group_by(models.Article.date).\
        offset(offset).\
        limit(limit).all()

    return jsonify({'data': [a.to_json() for a in articles]})


@news.route('/v1/suggestions', methods=['GET'])
def suggestions():
    term = request.values.get('term')
    limit = 5

    def search(column):
        return db.session.query(distinct(column)).\
            filter(column.startswith(term)).\
            order_by(column).\
            limit(limit).all()

    def fmt(typ, n):
        return {'id': json.dumps({'type': typ, 'text': n}), 'text': n}

    people = search(models.PersName.n)
    places = search(models.PlaceName.reg)
    orgs = search(models.OrgName.n)
    kws = search(models.RefString.reg)

    ret = {'data': [{'text': 'people',
                     'children': [fmt('people', p) for p, in people]},
                    {'text': 'places',
                     'children': [fmt('places', p) for p, in places]},
                    {'text': 'organizations',
                     'children': [fmt('organizations', o) for o, in orgs]},
                    {'text': 'keywords',
                     'children': [fmt('keyowrds', k) for k, in kws]}]}

    return jsonify(ret)
