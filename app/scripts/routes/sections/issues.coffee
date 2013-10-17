define (require) ->
  App = require 'app'
  DS = require 'emberData'
  d3 = require 'd3'
  require 'bootstrapDropdown'

  App.Date = DS.Model.extend
    months: DS.attr()

  App.IssuesController = Ember.ArrayController.extend
    year: null,
    month: null,
    day: null,

    years: (() ->
      @getEach('id').map (id) -> id: id, text: id, key: 'year'
    ).property 'content'

    yearsChanged: (() ->
      @set 'year', @get('years.0')
    ).observes('content', 'years')

    months: (() ->
      now = new Date()
      fmt = d3.time.format('%B')
      year = @get 'year.id'
      if not year then return []
      d3.keys(@findProperty('id', year).get('months')).map (d) ->
        now.setMonth parseInt(d, 10) - 1
        id: d, text: fmt(now), key: 'month'
    ).property('content', 'year')

    monthsChanged: (() ->
      @set 'month', @get 'months.0'
    ).observes('content', 'months')

    days: (() ->
      year = @get 'year.id'
      month = @get 'month.id'
      unless year and month then return []
      @findProperty('id', year).get('months.%@.days'.fmt month).map (d) -> 
        id: d, text: d, key: 'day'
    ).property('content', 'year', 'month')

    daysChanged: (() ->
      @set 'day', @get 'days.0'
    ).observes('content', 'days')

    dateChanged: (() ->
      year = @get('year.id')
      month = @get('month.id')
      day = @get('day.id')
      if year and month and day
        @transitionToRoute 'issues.issue', @store.find 'issue', @get 'issueId'
    ).observes('issueId', 'year', 'month', 'day')

    issueId: (() ->
      [y, m, d] = [@get('year.id'), @get('month.id'), @get('day.id')]
      if y and m and d then '%@-%@-%@'.fmt y, m, d else null
    ).property('year', 'month', 'day')

    actions:
      changeDate: (date) -> @set date.key, date


  App.IssuesRoute = Ember.Route.extend
    model: () -> @store.findAll 'date'

    serialize: () ->
      subsection_name: @controllerFor('subsections').get 'active'
