define (require) ->
  App = require 'app'
  DS = require 'emberData'
  d3 = require 'd3'
  require 'bootstrapDropdown'

  # This is just so we can extract a pretty month name from a date object
  now = new Date()

  fmtMonth = (m) ->
    now.setMonth(parseInt(m, 10) - 1)
    d3.time.format('%B') now

  App.Subsection = DS.Model.extend
    dates: DS.attr()

  App.IssuesController = Ember.ObjectController.extend
    year: null,
    month: null,
    day: null,

    years: (() ->
      @get('dates')
        .getEach('year')
        .map (d) -> id: d, text: d, key: 'year'
    ).property 'dates'

    months: (() ->
      year = @get 'year.id'
      if not year then return []
      d3.keys(@get('dates').findProperty('year', year)?.months or {})
        .map (d) ->
          id: d, text: fmtMonth(d), key: 'month'
    ).property('dates', 'year')

    days: (() ->
      year = @get 'year.id'
      month = @get 'month.id'
      unless year and month then return []
      @get('dates').findProperty('year', year)
        .months[month].days.map (d) -> id: d, text: d, key: 'day'
    ).property('dates', 'year', 'month')

    transitionToNext: () ->
      @transitionToRoute 'issues.issue', @store.find 'issue', @get 'issueId'

    issueId: (() ->
      [y, m, d] = [@get('year.id'), @get('month.id'), @get('day.id')]
      if y and m and d then '%@-%@-%@'.fmt y, m, d else null
    ).property('year', 'month', 'day')

    actions:
      changeDate: (date) ->
        @set date.key, date
        if date.key is 'year'
          @set 'month', @get 'months.0'
          @set 'day', @get 'days.0'
        else if date.key is 'month'
          @set 'day', @get 'days.0'
        @transitionToNext()

  App.IssuesRoute = Ember.Route.extend

    afterModel: (model, transition) ->
      controller = @controllerFor 'issues'
      issueId = controller.get 'issueId'
      if issueId then return
      dates = model.get('dates')
      preferred = transition.params.issue_id or ''
      if preferred
        [y, m, d] = preferred.split '-'
      else
        y = '1860'
        months = dates.findProperty('year', y).months
        m = Ember.keys(months)[0]
        d = months[m].days[0]
      controller.set 'year', id: y, text: y, key: 'year'
      controller.set 'month', id: m, text: fmtMonth(m), key: 'month'
      controller.set 'day', id: d, text: d, key: 'day'
      next = @transitionTo 'issues.issue', @store
        .find 'issue', '%@-%@-%@'.fmt y, m, d
      next.params = transition.params
      next