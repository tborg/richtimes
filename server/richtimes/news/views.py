from flask import Blueprint, jsonify, request
from richtimes.news import models
from sqlalchemy import not_

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


@news.route('/subsections/<subsection_id>')
def get_dates_for_subsection_type(subsection_id):
    subsection_type = models.SubsectionType.query.get(subsection_id)
    issue_ids = set()
    for ss in subsection_type.subsections.all():
        issue_ids.add(ss.issue_id)
    dates = {}
    filter = models.PubData.id.in_(list(issue_ids))
    issues = models.PubData.query.filter(filter).all()
    for i in issues:
        months = dates.get(i.year, {})
        days = months.get(i.month, {'days': []})
        days['days'].append(i.day)
        months[i.month] = days
        dates[i.year] = months
    dates = [{'year': k, 'months': v} for k, v in dates.iteritems()]
    return jsonify({'subsection': {'id': subsection_id, 'dates': dates}})


@news.route('/sections')
def get_section_types():
    section_types = models.SectionType.query\
        .filter(not_(models.SectionType.id.in_(IGNORE_SECTIONS)))\
        .all()
    return jsonify({'sections': [s.to_json() for s in section_types]})


@news.route('/sections/<section_id>')
def get_subsection_types(section_id):
    section_type = models.SectionType.query.get(section_id)
    return jsonify({'subsections': section_type.to_json()})


@news.route('/issues/<id>')
def get_issue(id):
    year, month, day = id.split('-')
    i = models.PubData.query.filter_by(year=year, month=month, day=day).first()
    return jsonify({'issue': i.to_json()})
